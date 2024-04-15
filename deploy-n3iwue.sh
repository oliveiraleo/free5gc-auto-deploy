#!/usr/bin/env bash

echo "Welcome to the N3IWUE auto deploy script"

sudo -v # caches credentials
if [ $? == 1 ]
then
    echo "[ERROR] Without root permission, you cannot install the tools and the updates"
    exit 1
fi
echo "[INFO] Execution started"

# check your go installation
go version
echo "[INFO] Go should have been previously installed, if not abort the execution"
echo "[INFO] The message above must not show a \"command not found\" error"
read -p "Press ENTER to continue or Ctrl+C to abort now"

# Hostname update
echo "[INFO] Updating the hostname"
sudo sed -i "1s/.*/n3iwue/" /etc/hostname
HOSTS_LINE=$(grep -n '127.0.1.1' /etc/hosts | awk -F: '{print $1}' -)
sudo sed -i ""$HOSTS_LINE"s/.*/127.0.1.1 n3iwue/" /etc/hosts

###################
# Download N3IWUE #
###################
echo "[INFO] Downloading N3IWUE"
git clone -c advice.detachedHead=false -b v1.0.0 https://github.com/free5gc/n3iwue.git # downloads the stable version
cd n3iwue

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

echo "[INFO] Updating configuration files"

CONFIG_FOLDER="./n3iwue/config/"

# The var below aim to find the correct line to replace the IP address
N3IWF_LINE=$(grep -n 'N3IWFInformation:' ${CONFIG_FOLDER}n3ue.yaml | awk -F: '{print $1}' -)
N3UE_LINE=$(grep -n 'IPSecIfaceName: ens38 # Name of Nwu interface (IKE) on this N3UE' ${CONFIG_FOLDER}n3ue.yaml | awk -F: '{print $1}' -)

# Increment the counter to point to the next line (where the IP is located)
N3IWF_LINE=$((N3IWF_LINE+1))

# Update the IP on the config files
sed -i ""$N3IWF_LINE"s/.*/        IPSecIfaceAddr: $IP_5GC # IP address of Nwu interface (IKE) on N3IWF/" ${CONFIG_FOLDER}n3ue.yaml
sed -i ""$N3UE_LINE"s/.*/        IPSecIfaceName: $IFACENAME # Name of Nwu interface (IKE) on this N3UE/" ${CONFIG_FOLDER}n3ue.yaml
N3UE_LINE=$((N3UE_LINE+1)) # go to the next line
sed -i ""$N3UE_LINE"s/.*/        IPSecIfaceAddr: $IP_UE # IP address of Nwu interface (IKE) on this N3UE/" ${CONFIG_FOLDER}n3ue.yaml

# TODO update IPsecInnerAddr too

echo "[INFO] Reboot the machine to apply the new hostname"
echo "[INFO] Don't forget to add the N3IWUE to free5GC via WebConsole"
echo "[INFO] See: https://free5gc.org/guide/n3iwue-installation/#3-use-webconsole-to-add-ue"
echo "[WARN] Don't forget to adjust the IPs on run.sh scritpt to capture pacts correctly on the .pcap"
echo "[INFO] The warning above only applies if you want to use N3IWUE's packet dump embedded functionality"
echo "[INFO] Auto deploy script done"
