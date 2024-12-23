#!/usr/bin/env bash

echo "Welcome to the UERANSIM auto deploy script"

sudo -v # caches credentials
if [ $? == 1 ]
then
    echo "[ERROR] Without root permission, you cannot install the tools and the updates"
    exit 1
fi
echo "[INFO] Execution started"

# Control variables (1 = true, 0 = false)
CONTROL_HOSTNAME=1 # switch between updating of not the hostname
CONTROL_STABLE=0 # switch between using the free5GC stable branch or latest nightly
UERANSIM_VERSION=v3.2.6 # select the stable branch tag that will be used by the script
UERANSIM_NIGHTLY_COMMIT='' # to be used to select which commit hash will be used by the script

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
                CONTROL_STABLE=1
                echo "[INFO] The stable branch will be cloned"
                ;;
            -nightly33)
                CONTROL_STABLE=0
                UERANSIM_NIGHTLY_COMMIT=392b714 # last commit before new SUPI/IMSI fix one (useful to be used with free5GC v3.3.0)
                echo "[INFO] The nightly branch to be used with free5GC v3.3.0 or below will be cloned"
                ;;
            -nightly)
                CONTROL_STABLE=0
                # UERANSIM_NIGHTLY_COMMIT=e4c492d # commit with the new SUPI/IMSI fix (useful to be used with free5GC v3.4.0 or later)
                # UERANSIM_NIGHTLY_COMMIT=2134f6b # commit with the EAP-AKA' fix
                UERANSIM_NIGHTLY_COMMIT=01e3785 # commit with the Rel-17 ASN and NGAP files
                echo "[INFO] The nightly branch to be used with free5GC v3.4.0 or later will be cloned"
                ;;
            -keep-hostname)
                echo "[INFO] The script will not change the machine's hostname"
                CONTROL_HOSTNAME=0
        esac
        shift
    done
fi

# Hostname update
if [ $CONTROL_HOSTNAME -eq 1 ]; then
    echo "[INFO] Updating the hostname"
    sudo sed -i "1s/.*/ueransim/" /etc/hostname
    HOSTS_LINE=$(grep -n '127.0.1.1' /etc/hosts | awk -F: '{print $1}' -)
    sudo sed -i ""$HOSTS_LINE"s/.*/127.0.1.1 ueransim/" /etc/hosts
elif [ $CONTROL_HOSTNAME -eq 0 ]; then
    echo "[INFO] Hostname update skipped this time"
else
    echo "[ERROR] Script failed to set CONTROL_HOSTNAME variable"
    exit 1
fi

#####################
# Download UERANSIM #
#####################
echo "[INFO] Downloading UERANSIM"
if [ $CONTROL_STABLE -eq 1 ]; then
    echo "[INFO] Cloning UERANSIM stable branch"
    echo "[INFO] Tag/release: $UERANSIM_VERSION"
    git clone -c advice.detachedHead=false -b $UERANSIM_VERSION https://github.com/aligungr/UERANSIM # clones the stable build
    cd UERANSIM
elif [ $CONTROL_STABLE -eq 0 ]; then
    # first check if commit was correctly set 
    if [ -z "$UERANSIM_NIGHTLY_COMMIT" ]; then
        echo "[ERROR] Script failed to set UERANSIM_NIGHTLY_COMMIT variable"
        exit 1
    fi
    echo "[INFO] Cloning UERANSIM nightly branch"
    echo "[INFO] Commit: $UERANSIM_NIGHTLY_COMMIT"
    git clone https://github.com/aligungr/UERANSIM
    cd UERANSIM
    git -c advice.detachedHead=false checkout $UERANSIM_NIGHTLY_COMMIT # clones the nightly build
else
    echo "[ERROR] Script failed to set CONTROL_STABLE variable"
    exit 1
fi

##########################
# Install required tools #
##########################
echo "[INFO] Downloading and installing UERANSIM prerequisites"
sudo apt update && sudo apt upgrade -y
sudo apt install -y make g++ libsctp-dev lksctp-tools iproute2
sudo snap install cmake --classic

##################
# Build UERANSIM #
##################
echo "[INFO] Building UERANSIM"
make
cd ..

################################
# Update UERANSIM config files #
################################
echo "[INFO] Updating configuration files"
# Reads the data network interface IP
echo "Please, type the 5GC's DN interface IP address"
echo -n "> "
read IP_5GC
ip a
echo "Please, now enter the UERANSIM's N2/N3 interface IP address (e.g. IP that communicates with 5GC)"
echo -n "> "
read IP_UE

CONFIG_FOLDER="./UERANSIM/config/"

# The var below aim to find the correct line to replace the IP address
GNB_LINE=$(grep -n 'ngapIp:' ${CONFIG_FOLDER}free5gc-gnb.yaml | awk -F: '{print $1}' -)
GNB_LINE_AMF=$(grep -n 'amfConfigs:' ${CONFIG_FOLDER}free5gc-gnb.yaml | awk -F: '{print $1}' -)

# Increment the counter to point to the next line (where the IP is located)
GNB_LINE_AMF=$((GNB_LINE_AMF+1))

sed -i ""$GNB_LINE"s/.*/ngapIp: $IP_UE   # gNB's local IP address for N2 Interface (Usually same with local IP)/" ${CONFIG_FOLDER}free5gc-gnb.yaml
GNB_LINE=$((GNB_LINE+1)) # go to the next line
sed -i ""$GNB_LINE"s/.*/gtpIp: $IP_UE   # gNB's local IP address for N3 Interface (Usually same with local IP)/" ${CONFIG_FOLDER}free5gc-gnb.yaml
sed -i ""$GNB_LINE_AMF"s/.*/  - address: $IP_5GC/" ${CONFIG_FOLDER}free5gc-gnb.yaml

if [ $CONTROL_HOSTNAME -eq 1 ]; then
    echo "[INFO] Reboot the machine to apply the new hostname"
fi
echo "[INFO] Don't forget to add the UE to the free5gc via WebConsole"
echo "[INFO] See: https://free5gc.org/guide/5-install-ueransim/#4-use-webconsole-to-add-an-ue"
echo "[INFO] Auto deploy script done"
