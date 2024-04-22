#!/usr/bin/env bash

echo "Welcome to the free5GC auto deploy script"

sudo -v # cache credentials
if [ $? == 1 ] # check if credentials were successfully cached
then
    echo "[ERROR] Without root permission, you cannot change the hostname nor install packages"
    exit 1
fi

# Control variables (1 = true, 0 = false)
CONTROL_STABLE=1 # switch between using the free5GC stable branch or latest nightly
CONTROL_N3IWF=0 # prepare N3IWF configuration if 1 is set
FREE5GC_VERSION=v3.4.1 # select the stable branch tag that will be used by the script
FREE5GC_NIGHTLY_COMMIT=8bfdd81 # select which commit hash will be used by the script

# check the number of parameters
if [ $# -gt 2 ]; then
    echo "[ERROR] Too many parameters given! Check your input and try again"
    exit 2
fi
# check the parameters and set the control vars accordingly
if [ $# -ne 0 ]; then
    while [ $# -gt 0 ]; do
        case $1 in
            -nightly)
                CONTROL_STABLE=0
                echo "[INFO] The nightly branch will be cloned"
                ;;
            -n3iwf)
                CONTROL_N3IWF=1
                echo "[INFO] N3IWF will be configured during the execution"
                ;;
        esac
        shift
    done
fi

# Give some time for the user to abort before running
echo "[INFO] The execution will start in 3 seconds!"
echo -n "3 ... "
sleep 1
echo -n "2 ... "
sleep 1
echo "1 ..."
sleep 1
echo "[INFO] Execution started"

# check your go installation
go version # TODO if go isn't installed kill the script automatically
echo "[INFO] Go should have been previously installed, if not abort the execution"
echo "[INFO] The message above must not show a \"command not found\" error"
read -p "Press ENTER to continue or Ctrl+C to abort now"

# Hostname update
echo "[INFO] Updating the hostname"
sudo sed -i "1s/.*/free5gc/" /etc/hostname
HOSTS_LINE=$(grep -n '127.0.1.1' /etc/hosts | awk -F: '{print $1}' -)
sudo sed -i ""$HOSTS_LINE"s/.*/127.0.1.1 free5gc/" /etc/hosts

echo "[INFO] Updating the package database and installing system updates"
sudo apt update && sudo apt upgrade -y

# Install CP supporting packages
echo "[INFO] Installing DB"
sleep 2
sudo apt -y install mongodb wget git
sudo systemctl start mongodb


# Install UPF supporting packages
echo "[INFO] Installing UPF prerequisites"
sleep 2
sudo apt -y install gcc g++ cmake autoconf libtool pkg-config libmnl-dev libyaml-dev
echo "[INFO] Done"

#####################
# Configure host OS #
#####################
echo "[INFO] Configuring host OS"
sleep 2
ip a
echo ""
echo "Please, enter the 5GC's DN interface name (e.g. the interface that has internet access)"
echo -n "> "
read IFACENAME

echo "[INFO] Using $IFACENAME as interface name"

# warn the user before deleting the rules
# TODO Add a parameter to trigger this deletion
echo "[WARN] Firewall reset: ALL iptables rules will be DELETED now"
read -p "Press ENTER to continue or Ctrl+C to abort now"
# start to delete old rules
echo -n "[INFO] Removing all iptables rules, if any... "
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -F
sudo iptables -X
echo "[OK]"
echo -n "[INFO] Applying free5GC iptables rules... "
sudo iptables -t nat -A POSTROUTING -o $IFACENAME -j MASQUERADE
sudo iptables -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1400
sudo iptables -I FORWARD 1 -j ACCEPT
echo "[OK]"
echo -n "[INFO] Setting kernel net.ipv4.ip_forward flag... "
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
echo "[OK]"
echo -n "[INFO] Stopping and disabling the ufw firewall... "
sudo systemctl stop ufw
sudo systemctl disable ufw >/dev/null 2>&1
echo "[OK]"

########################
# Install free5GC's CP #
########################
echo "[INFO] Installing the 5GC"
sleep 3
if [ $CONTROL_STABLE -eq 1 ]; then
    echo "[INFO] Cloning free5GC stable branch"
    echo "[INFO] Tag/release: $FREE5GC_VERSION"
    if [[ $FREE5GC_VERSION = "v3.3.0" ]]; then
        echo "[WARN] Using an older release should be avoided"
        # v3.3.0
        git clone -c advice.detachedHead=false --recursive -b $FREE5GC_VERSION -j `nproc` https://github.com/free5gc/free5gc.git # clones the previous stable build
        cd free5gc
        sudo corepack enable # necessary to build webconsole on free5GC v3.3.0
        # Useful script
        echo "[INFO] Downloading reload_host_config script from source"
        curl -LOSs https://raw.githubusercontent.com/free5gc/free5gc/main/reload_host_config.sh
    
    elif [[ $FREE5GC_VERSION = "v3.4.1" ]]; then
        # v3.4.1
        git clone --recursive -b $FREE5GC_VERSION -j `nproc` https://github.com/free5gc/free5gc.git # clones the stable build
        cd free5gc
    else
        echo "[ERROR] Script failed to set FREE5GC_VERSION variable" #check your spelling, you must keep the "v" (e.g. v.3.4.1)
    fi
elif [ $CONTROL_STABLE -eq 0 ]; then
    echo "[INFO] Cloning free5GC nightly branch"
    echo "[INFO] Commit: $FREE5GC_NIGHTLY_COMMIT"
    echo "[WARN] Unless you know what you are doing, using the nightly branch should be avoided"
    git clone --recursive -j `nproc` https://github.com/free5gc/free5gc.git # clones the nightly build
    cd free5gc
    git -c advice.detachedHead=false checkout $FREE5GC_NIGHTLY_COMMIT # commit with the webconsole build and kill script fixes (among other updates)
else
    echo "[ERROR] Script failed to set CONTROL_STABLE variable"
fi
make # builds all the NFs
cd ..

########################################
# Install UPF / GTP-U 5G kernel module #
########################################
echo "[INFO] Installing the GTP kernel module"
echo "[INFO] Removing GTP's previous versions, if any"
rm -rf gtp5g #removes previous versions
git clone -c advice.detachedHead=false -b v0.8.7 https://github.com/free5gc/gtp5g.git
cd gtp5g
make
sudo make install
cd ..

# Install the WebConsole
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt update
sudo apt install -y nodejs

cd free5gc
make webconsole
cd ..

###############################
# Update the 5GC config files #
###############################
echo "[INFO] Updating configuration files"
ip address show $IFACENAME | grep "\binet\b"
# Reads the data network interface IP
echo "Please, type the 5GC's DN interface IP address" # TODO grab the IP automatically
echo -n "> "
read IP

# Prepare the N3IWF IPSec inner tunnel IP address
if [ $CONTROL_N3IWF -eq 1 ]; then
    # Get the first octet of the free5GC machine IP
    IP_FIRST_OCTET=${IP%%.*}
    echo "[DEBUG] free5GC machine DN interface IP 1st octet: $IP_FIRST_OCTET"

    IP_IPSEC_INNER="10.0.0.1" # default IP is 10.0.0.1 (Check it here: https://github.com/free5gc/free5gc/blob/main/config/n3iwfcfg.yaml#L36)
    IP_IPSEC_INNER_NET_ADDR="10.0.0.0/24"

    # If the UE IP belongs to the 10.x.x.x range, it will conflict with the IPSec tunnel address that will be added as the default route
    if [ ${IP_FIRST_OCTET} -eq 10 ]; then
        echo "[WARN] A conflicting IP address range for Nwu interface was detected"
        echo "[INFO] Using 172.16.x.x as IPSec tunnel address space instead of 10.x.x.x"

        IP_IPSEC_INNER="172.16.0.1" # update the IP address

        IP_NET_OCTETS=`echo "$IP_IPSEC_INNER" | cut -d . -f 1-3`
        IP_IPSEC_INNER_NET_ADDR="$IP_NET_OCTETS"".0/24" # update the network address

        echo "[DEBUG] New IPSec tunnel inner IP address: $IP_IPSEC_INNER"
        echo "[DEBUG] New IPSec tunnel IP addresses pool: $IP_IPSEC_INNER_NET_ADDR"
    fi
fi

CONFIG_FOLDER="./free5gc/config/"

# The vars below aim to find the correct line to replace the IP address. The commands get the line right above the one where the IP must be changed
AMF_LINE=$(grep -n 'ngapIpList:  # the IP list of N2 interfaces on this AMF' ${CONFIG_FOLDER}amfcfg.yaml | awk -F: '{print $1}' -)
SMF_LINE=$(grep -n 'endpoints: # the IP address of this N3/N9 interface on this UPF' ${CONFIG_FOLDER}smfcfg.yaml | awk -F: '{print $1}' -)
UPF_LINE=$(grep -n 'ifList:' ${CONFIG_FOLDER}upfcfg.yaml | awk -F: '{print $1}' -)
# Increment the counters to point to the next line (where the IP is located)
AMF_LINE=$((AMF_LINE+1))
SMF_LINE=$((SMF_LINE+1))
UPF_LINE=$((UPF_LINE+1))

# Update the IP on the config files
sed -i ""$AMF_LINE"s/.*/    - $IP/" ${CONFIG_FOLDER}amfcfg.yaml
sed -i ""$SMF_LINE"s/.*/              - $IP/" ${CONFIG_FOLDER}smfcfg.yaml
sed -i ""$UPF_LINE"s/.*/    - addr: $IP/" ${CONFIG_FOLDER}upfcfg.yaml

# N3IWF config
if [ $CONTROL_N3IWF -eq 1 ]; then
    N3IWF_LINE=$(grep -n '# --- N2 Interfaces ---' ${CONFIG_FOLDER}n3iwfcfg.yaml | awk -F: '{print $1}' -)
    N3IWF_LINE=$((N3IWF_LINE+3))
    sed -i ""$N3IWF_LINE"s/.*/        -  $IP/" ${CONFIG_FOLDER}n3iwfcfg.yaml
    N3IWF_LINE=$((N3IWF_LINE+5))
    sed -i ""$N3IWF_LINE"s/.*/  IKEBindAddress: $IP # Nwu interface  IP address (IKE) on this N3IWF/" ${CONFIG_FOLDER}n3iwfcfg.yaml
    N3IWF_LINE=$((N3IWF_LINE+1))
    sed -i ""$N3IWF_LINE"s/.*/  IPSecTunnelAddress: $IP_IPSEC_INNER # Tunnel IP address of XFRM interface on this N3IWF/" ${CONFIG_FOLDER}n3iwfcfg.yaml
    N3IWF_LINE=$((N3IWF_LINE+1))
    # using @ as the delimiter on the line below as $IP_IPSEC_INNER_NET_ADDR contains a slash that will break sed functionality
    sed -i ""$N3IWF_LINE"s@.*@  UEIPAddressRange: $IP_IPSEC_INNER_NET_ADDR # IP address pool allocated to UE in IPSec tunnel@" ${CONFIG_FOLDER}n3iwfcfg.yaml
    echo "[INFO] N3IWF configuration applied"
fi

echo "[INFO] Reboot the machine to apply the new hostname"
if [ $CONTROL_STABLE -eq 1 ]; then
    echo "[INFO] Don't forget to configure UERANSIM using the stable flag"
elif [ $CONTROL_STABLE -eq 0 ]; then
    echo "[INFO] Don't forget to configure UERANSIM using the nightly flag"
fi
echo "[INFO] Auto deploy script done"

