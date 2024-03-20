#!/usr/bin/env bash

echo "Welcome to the free5GC auto deploy script"

sudo -v # caches credentials
if [ $? == 1 ]
then
    echo "[ERROR] Without root permission, you cannot change the hostname nor install packages"
    exit 1
fi
# Give some time for the user to abort before running
echo "[INFO] The execution will start in 3 seconds!"
echo -n "3 ... "
sleep 1
echo -n "2 ... "
sleep 1
echo "1 ..."
sleep 1
echo "[INFO] Exection started"

# check your go installation
go version
echo "[INFO] Go should have been previously installed, if not abort the execution"
echo "[INFO] The message above must not show a \"command not found\" error"
read -p "Press ENTER to continue or Ctrl+C to abort now"

# Hostname update
echo "[INFO] Updating the hostname"
sudo sed -i "1s/.*/free5gc/" /etc/hostname
HOSTS_LINE=$(grep -n '127.0.1.1' /etc/hosts | awk -F: '{print $1}' -)
sudo sed -i ""$HOSTS_LINE"s/.*/127.0.1.1 free5gc/" /etc/hosts

echo "[INFO] Updating the package databse and installing system updates"
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
echo -n "[INFO] Applying iptables rules... "
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
# git clone --recursive -b v3.4.0 -j `nproc` https://github.com/free5gc/free5gc.git # clones the stable build
git clone --recursive -b v3.3.0 -j `nproc` https://github.com/free5gc/free5gc.git # clones the stable build
# git clone --recursive -j `nproc` https://github.com/free5gc/free5gc.git # clones the nightly build
cd free5gc
# git -c advice.detachedHead=false checkout 8bfdd81 # commit with the webconsole build and kill script fixes (among other updates)
sudo corepack enable # necessary to build webconsole on free5GC v3.3.0
make # builds all the NFs
cd ..

########################################
# Install UPF / GTP-U 5G kernel module #
########################################
echo "[INFO] Installing the GTP kernel module"
sleep 2
git clone -c advice.detachedHead=false -b v0.8.5 https://github.com/free5gc/gtp5g.git
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
echo "Please, type the 5GC's DN interface IP address"
echo -n "> "
read IP

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

echo "[INFO] Reboot the machine to apply the new hostname"
echo "[INFO] Don't forget to configure UERANSIM's machine too"
echo "[INFO] Auto deploy script done"

