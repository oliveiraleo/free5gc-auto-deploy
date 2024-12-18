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
HOSTNAME_CONTROL=1 # switch between updating of not the hostname
N3IWUE_VERSION=v1.0.1 # select the stable branch tag that will be used by the script
N3IWUE_STABLE_BRANCH_CONTROL=1 # switch between using the N3IWUE stable or nightly branch
N3IWUE_NIGHTLY_COMMIT='' # to be used to select which commit hash will be used by the script

# check the number of parameters
if [ $# -gt 2 ]; then
    echo "[ERROR] Too many parameters given! Check your input and try again"
    exit 2
fi
if [ $# -lt 1 ]; then
    echo "[ERROR] No parameter was given! Check your input and try again"
    exit 2
fi
# check the parameters and set the control vars accordingly
if [ $# -ne 0 ]; then
    while [ $# -gt 0 ]; do
        case $1 in
            -stable)
                echo "[INFO] The stable branch of N3IWUE will be cloned"
                ;;
            -stable341)
                N3IWUE_VERSION=v1.0.0
                echo "[INFO] The script will clone N3IWUE's version compatible with free5GC v3.4.1"
                ;;
            -nightly)
                N3IWUE_STABLE_BRANCH_CONTROL=0
                # N3IWUE_NIGHTLY_COMMIT=c2662c7 # commit with signaling fixes (for more info: https://github.com/free5gc/free5gc/issues/584)
                N3IWUE_NIGHTLY_COMMIT=578edc9 # latest commit as of (30th sep)
                echo "[INFO] The nightly branch of N3IWUE will be cloned"
                ;;
            -keep-hostname)
                HOSTNAME_CONTROL=0
                echo "[INFO] The script will not change the machine's hostname"
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
if [ $HOSTNAME_CONTROL -eq 1 ]; then
    echo "[INFO] Updating the hostname"
    sudo sed -i "1s/.*/n3iwue/" /etc/hostname
    HOSTS_LINE=$(grep -n '127.0.1.1' /etc/hosts | awk -F: '{print $1}' -)
    sudo sed -i ""$HOSTS_LINE"s/.*/127.0.1.1 n3iwue/" /etc/hosts
elif [ $HOSTNAME_CONTROL -eq 0 ]; then
    echo "[INFO] Hostname update skipped this time"
else
    echo "[ERROR] Script failed to set HOSTNAME_CONTROL variable"
    exit 1
fi

###################
# Download N3IWUE #
###################
echo "[INFO] Downloading N3IWUE"
if [ $N3IWUE_STABLE_BRANCH_CONTROL -eq 1 ]; then
    echo "[INFO] Cloning N3IWUE stable branch"
    echo "[INFO] Tag/release: $N3IWUE_VERSION"
    git clone -c advice.detachedHead=false -b $N3IWUE_VERSION https://github.com/free5gc/n3iwue.git # clones the stable version
    cd n3iwue
elif [ $N3IWUE_STABLE_BRANCH_CONTROL -eq 0 ]; then
    echo "[INFO] Cloning N3IWUE nightly branch"
    echo "[INFO] Commit: $N3IWUE_VERSION"
    git clone https://github.com/free5gc/n3iwue.git # clones the nightly build
    cd n3iwue
    git -c advice.detachedHead=false checkout $N3IWUE_NIGHTLY_COMMIT
else
    echo "[ERROR] Script failed to set N3IWUE_STABLE_BRANCH_CONTROL variable"
    exit 1
fi

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

if [ $HOSTNAME_CONTROL -eq 1 ]; then
    echo "[INFO] Reboot the machine to apply the new hostname"
fi
echo "[INFO] Don't forget to add the N3IWUE to free5GC via WebConsole"
echo "[INFO] See: https://free5gc.org/guide/n3iwue-installation/#3-use-webconsole-to-add-ue"
echo "[INFO] Auto deploy script done"
