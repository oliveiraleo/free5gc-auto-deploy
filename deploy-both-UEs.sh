#!/usr/bin/env bash

# Check shell type first
case "$-" in
    *i*)
        echo "Welcome to the UERANSIM + N3IWUE auto deploy script"
        echo "[INFO] Currently, this script will call the other two with few adjustments"
        ;;
    *)
        echo "[ERROR] This shell is not interactive"
        echo "[INFO] TIP: Try to run this script using the command below"
        echo "bash -i $0"
        exit 1
        ;;
esac

echo "[INFO] Downloading the scripts"
curl -LOOOSs https://github.com/oliveiraleo/free5gc-auto-deploy/raw/main/{deploy-UERANSIM.sh,install-go.sh,deploy-n3iwue.sh}
chmod +x deploy-UERANSIM.sh deploy-n3iwue.sh install-go.sh # gives execution permission to all scripts

echo "[INFO] Running the scripts"
echo "[INFO] Deploying UERANSIM"
./deploy-UERANSIM.sh -nightly -keep-hostname
echo "[INFO] Installing Go" # interactive shell required for this step
./install-go.sh && source ~/.bashrc
echo "[INFO] Deploying the N3IWUE"
./deploy-n3iwue.sh -keep-hostname

# Hostname update
echo "[INFO] Updating the hostname"
sudo sed -i "1s/.*/5g2ue/" /etc/hostname
HOSTS_LINE=$(grep -n '127.0.1.1' /etc/hosts | awk -F: '{print $1}' -)
sudo sed -i ""$HOSTS_LINE"s/.*/127.0.1.1 5g2ue/" /etc/hosts

echo "[INFO] Reboot the machine to apply the new hostname"
echo "[INFO] Don't forget to add the UEs to the free5gc via WebConsole"
echo "[INFO] Auto deploy script done"