#!/usr/bin/env bash

echo "Welcome to the free5GC auto deploy script"

sudo -v # cache credentials
if [ $? == 1 ] # check if credentials were successfully cached
then
    echo "[ERROR] Without root permission, you cannot change the hostname nor install packages"
    exit 1
fi

# Control variables (1 = true, 0 = false)
FREE5GC_STABLE_BRANCH_CONTROL=1 # switch between using the free5GC stable branch or latest nightly
FREE5GC_VERSION=v3.4.3 # select the stable branch tag that will be used by the script
FREE5GC_NIGHTLY_COMMIT=a39de62 # select which commit hash will be used by the script
N3IWF_CONFIGURATION_CONTROL=0 # prepare N3IWF configuration if 1 is set
N3IWF_STABLE_BRANCH_CONTROL=1 # switch between using the N3IWF stable or nightly branch
N3IWF_NIGHTLY_COMMIT=9fe155e # select which commit hash will be used by the script
TNGF_CONFIGURATION_CONTROL=0 # prepare N3IWF configuration if 1 is set
FIREWALL_RULES_CONTROL=0 # deletes all firewall rules if 1 is set
UBUNTU_VERSION=20 # Ubuntu version where the script is running
GTP5G_VERSION=v0.8.10 # select the version tag that will be used to clone the GTP-U module

function ver { printf "%03d%03d%03d" $(echo "$1" | tr '.' ' '); } # util. to compare versions

# check the number of parameters
if [ $# -gt 3 ]; then
    echo "[ERROR] Too many parameters given! Check your input and try again"
    exit 2
fi
# check the parameters and set the control vars accordingly
if [ $# -ne 0 ]; then
    while [ $# -gt 0 ]; do
        case $1 in
            -nightly)
                FREE5GC_STABLE_BRANCH_CONTROL=0
                echo "[INFO] The nightly branch of free5GC will be cloned"
                ;;
            -n3iwf)
                N3IWF_CONFIGURATION_CONTROL=1
                echo "[INFO] N3IWF will be configured during the execution"
                ;;
            -n3iwf-nightly)
                N3IWF_CONFIGURATION_CONTROL=1
                N3IWF_STABLE_BRANCH_CONTROL=0
                echo "[INFO] N3IWF will be configured during the execution"
                echo "[INFO] The nightly branch of N3IWF will be cloned"
                ;;
            -tngf)
                # verify if the stable version is set to be deployed and if FREE5GC_VERSION >= v3.4.3, else deploy nightly version
                FREE5GC_VERSION_FLOAT=${FREE5GC_VERSION#?} # stripping leading 'v' to compare only digits
                if [ $FREE5GC_STABLE_BRANCH_CONTROL -eq 1 ]; then
                    if [ $(ver $FREE5GC_VERSION_FLOAT) -gt $(ver 3.4.2) ]; then
                        TNGF_CONFIGURATION_CONTROL=1
                        echo "[INFO] TNGF will be configured during the execution"
                    else
                        echo "[ERROR] free5GC $FREE5GC_VERSION was selected, however it doesn't contain TNGF"
                        echo "[INFO] Please, select any version >= v3.4.3 or drop the TNGF parameter"
                        # TODO Fix the input "./deploy-free5gc.sh -tngf -nightly" (perhaps applying some arg/param sorting?)
                        echo "[INFO] If using nightly version, please, put the TNGF parameter after the nightly one"
                        exit 1
                    fi
                elif [ $FREE5GC_STABLE_BRANCH_CONTROL -eq 0 ]; then
                    TNGF_CONFIGURATION_CONTROL=1
                    echo "[INFO] TNGF will be configured during the execution"
                fi
                ;;
            -reset-firewall)
                FIREWALL_RULES_CONTROL=1
                echo "[INFO] Firewall rules will be cleaned during the execution"
                ;;
            # -only-setup-n3iwf)
            # TODO add a parameter to update the N3IWF configs separately (i.e. without running everything else)
            # ;;
            *)
                echo "[ERROR] Some input parameter wasn't found. Check your input and try again"
                exit 1
                ;;
        esac
        shift
    done
else
    echo "[INFO] N3IWF will NOT be configured during the execution"
    echo "[INFO] TNGF will NOT be configured during the execution"
    echo "[INFO] Firewall rules will NOT be cleaned during the execution"
    # TODO check for the control variables state and adjust these info messages accordingly
fi

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

# check Ubuntu version
lsb_release -sr | grep "^22"  >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo "[INFO] Ubuntu 22.04 LTS detected. Adjusting the database installation accordingly"
    UBUNTU_VERSION=22
elif [[ $? -eq 1 ]]; then
    echo "[INFO] Ubuntu 20.04 LTS detected, continuing..."
    UBUNTU_VERSION=20
else
    echo "[ERROR] Script failed to set UBUNTU_VERSION variable or a unsuported version is being used"
    exit 1
fi

# Install CP supporting packages
echo "[INFO] Installing DB"
if [[ $UBUNTU_VERSION -eq 20 ]]; then
    sudo apt -y install mongodb wget git
    sudo systemctl start mongodb
elif [[ $UBUNTU_VERSION -eq 22 ]]; then
    sudo apt -y install gnupg curl
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
       sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
        sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    sudo apt update
    sudo apt install -y mongodb-org
    sudo systemctl start mongod
else
    echo "[ERROR] Script failed to setup the data base"
    exit 1
fi

# Install UPF supporting packages
echo "[INFO] Installing UPF prerequisites"
sudo apt -y install gcc g++ cmake autoconf libtool pkg-config libmnl-dev libyaml-dev
echo "[INFO] Done"

#####################
# Configure host OS #
#####################
echo "[INFO] Configuring host OS"
ip a
echo ""
echo "Please, enter the 5GC's DN interface name (e.g. the interface that has internet access)"
echo -n "> "
read IFACENAME

echo "[INFO] Using $IFACENAME as interface name"

# warn the user before deleting the rules
if [ $FIREWALL_RULES_CONTROL -eq 1 ]; then
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
fi
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
if [ $FREE5GC_STABLE_BRANCH_CONTROL -eq 1 ]; then
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
    
    elif [[ $FREE5GC_VERSION = "v3.4.1" || $FREE5GC_VERSION = "v3.4.2" || $FREE5GC_VERSION = "v3.4.3" ]]; then
        # v3.4.x
        git clone -c advice.detachedHead=false --recursive -b $FREE5GC_VERSION -j `nproc` https://github.com/free5gc/free5gc.git # clones the stable build
        cd free5gc
    else
        echo "[ERROR] Script failed to set FREE5GC_VERSION variable" #check your spelling, you must keep the "v" (e.g. v.3.4.1 and up)
        exit 1
    fi
elif [ $FREE5GC_STABLE_BRANCH_CONTROL -eq 0 ]; then
    echo "[INFO] Cloning free5GC nightly branch"
    echo "[INFO] Commit: $FREE5GC_NIGHTLY_COMMIT"
    echo "[WARN] Unless you know what you are doing, using the nightly branch should be avoided"
    git clone --recursive -j `nproc` https://github.com/free5gc/free5gc.git # clones the nightly build
    cd free5gc
    git -c advice.detachedHead=false checkout $FREE5GC_NIGHTLY_COMMIT # commit with the webconsole build and kill script fixes (among other updates)
else
    echo "[ERROR] Script failed to set FREE5GC_STABLE_BRANCH_CONTROL variable"
    exit 1
fi

if [ $N3IWF_STABLE_BRANCH_CONTROL -eq 0 ]; then
    echo "[INFO] Installing N3IWF nightly"
    echo "[INFO] Cloning N3IWF nightly branch"
    echo "[INFO] Commit: $N3IWF_NIGHTLY_COMMIT"
    cd NFs/n3iwf/
    git -c advice.detachedHead=false checkout $N3IWF_NIGHTLY_COMMIT
    cd ../../
fi

make # builds all the NFs
cd ..

########################################
# Install UPF / GTP-U 5G kernel module #
########################################
echo "[INFO] Configuring the GTP kernel module"
echo "[INFO] Removing GTP's previous versions, if any"
rm -rf gtp5g #removes previous versions
echo "[INFO] Installing the GTP kernel module"
echo "[INFO] Release: $GTP5G_VERSION"
git clone -c advice.detachedHead=false -b $GTP5G_VERSION https://github.com/free5gc/gtp5g.git
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
if [ $N3IWF_CONFIGURATION_CONTROL -eq 1 ] || [ $TNGF_CONFIGURATION_CONTROL -eq 1 ]; then
    # Get the first octet of the free5GC machine IP
    IP_FIRST_OCTET=${IP%%.*}
    echo "[DEBUG] free5GC machine DN interface IP 1st octet: $IP_FIRST_OCTET"

    IP_IPSEC_INNER="10.0.0.1" # default IP is 10.0.0.1 (Check it here: https://github.com/free5gc/free5gc/blob/main/config/n3iwfcfg.yaml#L36 or https://github.com/free5gc/free5gc/blob/main/config/tngfcfg.yaml#L36)
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
    else
        echo "[DEBUG] No conflicting IP address found"
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
if [ $N3IWF_CONFIGURATION_CONTROL -eq 1 ]; then
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

# TNGF config
if [ $TNGF_CONFIGURATION_CONTROL -eq 1 ]; then
    TNGF_LINE=$(grep -n 'AMFSCTPAddresses:' ${CONFIG_FOLDER}tngfcfg.yaml | awk -F: '{print $1}' -)
    TNGF_LINE=$((TNGF_LINE+2))
    sed -i ""$TNGF_LINE"s/.*/        - $IP/" ${CONFIG_FOLDER}tngfcfg.yaml
    # TNGF_LINE=$(grep -n '# --- Bind Interfaces ---' ${CONFIG_FOLDER}tngfcfg.yaml | awk -F: '{print $1}' -)
    TNGF_LINE=$((TNGF_LINE+5))
    sed -i ""$TNGF_LINE"s/.*/  IKEBindAddress: $IP  # IP address of Nwu interface (IKE) on this TNGF/" ${CONFIG_FOLDER}tngfcfg.yaml
    TNGF_LINE=$((TNGF_LINE+1))
    sed -i ""$TNGF_LINE"s/.*/  RadiusBindAddress: $IP # IP address of Nwu interface (IKE) on this TNGF/" ${CONFIG_FOLDER}tngfcfg.yaml
    TNGF_LINE=$((TNGF_LINE+1))
    sed -i ""$TNGF_LINE"s/.*/  IPSecInterfaceAddress: $IP_IPSEC_INNER # IP address of IPSec virtual interface (IPsec tunnel enpoint on this TNGF)/" ${CONFIG_FOLDER}tngfcfg.yaml
    TNGF_LINE=$((TNGF_LINE+1))
    sed -i ""$TNGF_LINE"s/.*/  IPSecTunnelAddress: $IP_IPSEC_INNER # Tunnel IP address of XFRM interface on this TNGF/" ${CONFIG_FOLDER}tngfcfg.yaml
    TNGF_LINE=$((TNGF_LINE+1))
    # using @ as the delimiter on the line below as $IP_IPSEC_INNER_NET_ADDR contains a slash that will break sed functionality
    sed -i ""$TNGF_LINE"s@.*@  UEIPAddressRange: $IP_IPSEC_INNER_NET_ADDR # IP address allocated to UE in IPSec tunnel@" ${CONFIG_FOLDER}tngfcfg.yaml
    echo "[INFO] TNGF configuration applied"
fi

echo "[INFO] Reboot the machine to apply the new hostname"
if [ $FREE5GC_STABLE_BRANCH_CONTROL -eq 1 ]; then
    echo "[INFO] Don't forget to configure UERANSIM using the stable flag"
elif [ $FREE5GC_STABLE_BRANCH_CONTROL -eq 0 ]; then
    echo "[INFO] Don't forget to configure UERANSIM using the nightly flag"
fi
echo "[INFO] Auto deploy script done"

