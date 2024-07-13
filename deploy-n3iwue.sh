#!/usr/bin/env bash

echo "Welcome to the N3IWUE auto deploy script"

sudo -v # caches credentials
if [ $? == 1 ]
then
    echo "[ERROR] Without root permission, you cannot install the tools and the updates"
    exit 1
fi
echo "[INFO] Execution started"

# Control variables (1 = true, 0 = false)
CONTROL_HOSTNAME=1 # switch between updating of not the hostname
CONTROL_VERSION=0 # switch between n3iwue versions (0 = first release, 1 = latest release)

# check the number of parameters
if [ $# -gt 2 ]; then
    echo "[ERROR] Too many parameters given! Check your input and try again"
    exit 2
fi
# if [ $# -lt 1 ]; then
#     echo "[ERROR] No parameter was given! Check your input and try again"
#     exit 2
# fi
# check the parameters and set the control vars accordingly
# NOTE this part was reused because in the future the script may support more parameters
if [ $# -ne 0 ]; then
    while [ $# -gt 0 ]; do
        case $1 in
            -keep-hostname)
                echo "[INFO] The script will not change the machine's hostname"
                CONTROL_HOSTNAME=0
                ;;
            -latest)
                echo "[INFO] The script will clone N3IWUE's version compatible with free5GC v3.4.2"
                CONTROL_VERSION=1
                ;;
        esac
        shift
    done
fi

# check your go installation
go version
echo "[INFO] Go should have been previously installed, if not abort the execution"
echo "[INFO] The message above must not show a \"command not found\" error"
read -p "Press ENTER to continue or Ctrl+C to abort now"

# Hostname update
if [ $CONTROL_HOSTNAME -eq 1 ]; then
    echo "[INFO] Updating the hostname"
    sudo sed -i "1s/.*/n3iwue/" /etc/hostname
    HOSTS_LINE=$(grep -n '127.0.1.1' /etc/hosts | awk -F: '{print $1}' -)
    sudo sed -i ""$HOSTS_LINE"s/.*/127.0.1.1 n3iwue/" /etc/hosts
elif [ $CONTROL_HOSTNAME -eq 0 ]; then
    echo "[INFO] Hostname update skipped this time"
else
    echo "[ERROR] Script failed to set CONTROL_HOSTNAME variable"
    exit 1
fi

###################
# Download N3IWUE #
###################
echo "[INFO] Downloading N3IWUE"
# echo "[INFO] Tag/release: TODO"
if [ $CONTROL_VERSION -eq 0 ]; then
    git clone -c advice.detachedHead=false -b v1.0.0 https://github.com/free5gc/n3iwue.git # downloads the first stable version
elif [ $CONTROL_VERSION -eq 1 ]; then
    git clone -c advice.detachedHead=false -b v1.0.1 https://github.com/free5gc/n3iwue.git # downloads the latest stable version
else
    echo "[ERROR] Script failed to set CONTROL_STABLE variable"
    exit 1
fi
cd n3iwue
# TODO add a way to clone the nigthly version too

##########################
# Install required tools #
##########################
echo "[INFO] Downloading and installing N3IWUE prerequisites"
sudo apt update && sudo apt upgrade -y
sudo apt install -y make libsctp-dev lksctp-tools iproute2

#################
# Build N3IWUE #
#################
echo "[INFO] Building N3IWUE"
make
cd ..

###############################
# Update N3IWUE config files #
###############################
echo "[INFO] Reading information required to update configuration files"
# Reads the 5GC data network interface IP
echo "Please, type the 5GC's DN interface IP address"
echo -n "> "
read IP_5GC
ip a
echo ""
echo "Please, enter the N3IWUE's Nwu interface name (e.g. the interface that communicates with 5GC)"
echo -n "> "
read IFACENAME
ip address show $IFACENAME | grep "\binet\b"
echo ""
# Reads the Nwu interface IP
echo "Please, now enter the N3IWUE's Nwu interface IP address (e.g. IP that communicates with 5GC)"
echo -n "> "
read IP_UE
# Reads the N3IWUE DN interface IP
echo "Please, now enter the N3IWUE's DN interface IP address (e.g. IP that N3WIUE will get from the 5GC)"
echo "TIP: If deploying only one N3IWUE to connect to the 5GC and unsure, then the IP should be 10.60.0.1"
echo -n "> "
read IP_DN_UE

# Get the first octet of the UE machine IP
IP_FIRST_OCTET=${IP_UE%%.*}
echo "[DEBUG] UE machine interface IP 1st octet: $IP_FIRST_OCTET"

IP_IPSEC_INNER="10.0.0.1" # default IP is 10.0.0.1 (Check it here: https://github.com/free5gc/n3iwue/blob/main/config/n3ue.yaml)

# If the UE IP belongs to the 10.x.x.x range, it will conflict with the IPSec tunnel address that will be added as the default route
if [ ${IP_FIRST_OCTET} -eq 10 ]; then
    echo "[WARN] A conflicting IP address range for Nwu interface was detected"
    echo "[INFO] Using 172.16.x.x as IPSec tunnel address space instead of 10.x.x.x"

    # To use the same host part from UE Nwu interface IP the on the IPSec tunnel, uncomment the lines below
    # IP_THIRD_FOURTH_OCTETS=`echo "$IP_UE" | cut -d . -f 3-4`
    # echo "[DEBUG] UE machine interface IP 3rd and 4th octets: $IP_THIRD_FOURTH_OCTETS"

    # Concatenates the new range with the host part of the IP address
    # IP_IPSEC_INNER="172.16.""$IP_THIRD_FOURTH_OCTETS" # update the IP address

    IP_IPSEC_INNER="172.16.0.1" # update the IP address

    echo "[DEBUG] New IPSec tunnel inner IP address: $IP_IPSEC_INNER"
fi

echo "[INFO] Updating configuration files"

CONFIG_FOLDER="./n3iwue/config/"
BASE_FOLDER="./n3iwue/"

# The var below aim to find the correct line to replace the IP address
N3IWF_LINE=$(grep -n 'N3IWFInformation:' ${CONFIG_FOLDER}n3ue.yaml | awk -F: '{print $1}' -)
N3UE_LINE=$(grep -n 'IPSecIfaceName: ens38 # Name of Nwu interface (IKE) on this N3UE' ${CONFIG_FOLDER}n3ue.yaml | awk -F: '{print $1}' -)
N3UE_RUN_SCRIPT_IPSEC_LINE=$(grep -n 'N3UE_IPSec_iface_addr=' ${BASE_FOLDER}run.sh | awk -F: '{print $1}' -)

# Increment the counter to point to the next line (where the IP is located)
N3IWF_LINE=$((N3IWF_LINE+1))

# Update the IP on the config files
sed -i ""$N3IWF_LINE"s/.*/        IPSecIfaceAddr: $IP_5GC # IP address of Nwu interface (IKE) on N3IWF/" ${CONFIG_FOLDER}n3ue.yaml
N3IWF_LINE=$((N3IWF_LINE+1)) # go to the next line
sed -i ""$N3IWF_LINE"s/.*/        IPsecInnerAddr: $IP_IPSEC_INNER # IP address of IPsec tunnel enpoint on N3IWF/" ${CONFIG_FOLDER}n3ue.yaml

sed -i ""$N3UE_LINE"s/.*/        IPSecIfaceName: $IFACENAME # Name of Nwu interface (IKE) on this N3UE/" ${CONFIG_FOLDER}n3ue.yaml
N3UE_LINE=$((N3UE_LINE+1)) # go to the next line
sed -i ""$N3UE_LINE"s/.*/        IPSecIfaceAddr: $IP_UE # IP address of Nwu interface (IKE) on this N3UE/" ${CONFIG_FOLDER}n3ue.yaml

# Update the IP on the run script file
sed -i ""$N3UE_RUN_SCRIPT_IPSEC_LINE"s/.*/    N3UE_IPSec_iface_addr=$IP_5GC/" ${BASE_FOLDER}run.sh
N3UE_RUN_SCRIPT_IPSEC_LINE=$((N3UE_RUN_SCRIPT_IPSEC_LINE+1)) # go to the next line
sed -i ""$N3UE_RUN_SCRIPT_IPSEC_LINE"s/.*/    N3IWF_IPsec_inner_addr=$IP_IPSEC_INNER/" ${BASE_FOLDER}run.sh
N3UE_RUN_SCRIPT_IPSEC_LINE=$((N3UE_RUN_SCRIPT_IPSEC_LINE+1)) # go to the next line
sed -i ""$N3UE_RUN_SCRIPT_IPSEC_LINE"s/.*/    UE_DN_addr=$IP_DN_UE/" ${BASE_FOLDER}run.sh

if [ $CONTROL_HOSTNAME -eq 1 ]; then
    echo "[INFO] Reboot the machine to apply the new hostname"
fi
echo "[INFO] Don't forget to add the N3IWUE to free5GC via WebConsole"
echo "[INFO] See: https://free5gc.org/guide/n3iwue-installation/#3-use-webconsole-to-add-ue"
echo "[INFO] Auto deploy script done"
