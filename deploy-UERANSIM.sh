#!/usr/bin/env bash

echo "Welcome to the UERANSIM auto deploy script"

sudo -v # caches credentials
if [ $? == 1 ]
then
    echo "[ERROR] Without root permission, you cannot install the tools and the updates"
    exit 1
fi
echo "[INFO] Exection started"

# Hostname update
echo "[INFO] Updating the hostname"
sudo sed -i "1s/.*/ueransim/" /etc/hostname
HOSTS_LINE=$(grep -n '127.0.1.1' /etc/hosts | awk -F: '{print $1}' -)
sudo sed -i ""$HOSTS_LINE"s/.*/127.0.1.1 ueransim/" /etc/hosts

#####################
# Download UERANSIM #
#####################
echo "[INFO] Downloading UERANSIM"
git clone https://github.com/aligungr/UERANSIM
cd UERANSIM
git -c advice.detachedHead=false checkout 3a96298 # disables the "You are in 'detached HEAD' state" warning

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
GNB_LINE=$(grep -n 'ngapIp: 127.0.0.1' ${CONFIG_FOLDER}free5gc-gnb.yaml | awk -F: '{print $1}' -)
GNB_LINE_AMF=$(grep -n 'amfConfigs:' ${CONFIG_FOLDER}free5gc-gnb.yaml | awk -F: '{print $1}' -)

# Increment the counter to point to the next line (where the IP is located)
GNB_LINE_AMF=$((GNB_LINE_AMF+1))

sed -i ""$GNB_LINE"s/.*/ngapIp: $IP_UE   # gNB's local IP address for N2 Interface (Usually same with local IP)/" ${CONFIG_FOLDER}free5gc-gnb.yaml
GNB_LINE=$((GNB_LINE+1)) # go to the next line
sed -i ""$GNB_LINE"s/.*/gtpIp: $IP_UE   # gNB's local IP address for N3 Interface (Usually same with local IP)/" ${CONFIG_FOLDER}free5gc-gnb.yaml
sed -i ""$GNB_LINE_AMF"s/.*/  - address: $IP_5GC/" ${CONFIG_FOLDER}free5gc-gnb.yaml

echo "[INFO] Reboot the machine to apply the new hostname"
echo "[INFO] Don't forget to add the UE to the free5gc via WebConsole"
echo "[INFO] See: https://free5gc.org/guide/5-install-ueransim/#4-use-webconsole-to-add-an-ue"
echo "[INFO] Auto deploy script done"
