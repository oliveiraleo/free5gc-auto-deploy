#!/usr/bin/env bash

WLAN_IFACE_NAME="wlp3s0"

echo "Welcome to the TNGFUE auto deploy script"

sudo -v # caches credentials
if [ $? == 1 ]
then
    echo "[ERROR] Without root permission, you cannot install the tools and the updates"
    exit 1
fi
echo "[INFO] Execution started"

# Control variables (1 = true, 0 = false)
CONTROL_HOSTNAME=1 # switch between updating or not the hostname
CONTROL_STABLE=0 # switch between using the TNGFUE stable branch or latest nightly
# TNGFUE_VERSION=TODO # select the stable branch tag that will be used by the script
TNGFUE_NIGHTLY_COMMIT='' # to be used to select which commit hash will be used by the script

# check the number of parameters
if [ $# -gt 2 ]; then
    echo "[ERROR] Too many parameters given! Check your input and try again"
    exit 2
elif [ $# -lt 1 ]; then
    echo "[ERROR] No parameter was given! Check your input and try again"
    exit 2
fi
# check the parameters and set the control vars accordingly
if [ $# -ne 0 ]; then
    while [ $# -gt 0 ]; do
        case $1 in
            -stable)
                CONTROL_STABLE=1
                # echo "[INFO] The stable branch will be cloned"
                echo "[ERROR] No stable branch/tag available!"
                ;;
            -nightly)
                CONTROL_STABLE=0
                TNGFUE_NIGHTLY_COMMIT=63823f7 # commit with the new execution flow (automated scripts)
                echo "[INFO] The nightly branch will be cloned"
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

#######################
# TNGFUE Installation #
#######################
echo "[INFO] Downloading TNGFUE"
# TODO implement stable branch clone when released on upstream repo
git clone https://github.com/free5gc/tngfue.git
cd tngfue
git -c advice.detachedHead=false checkout $TNGFUE_NIGHTLY_COMMIT # clones the nightly build
echo "[INFO] Running the prepare.sh script"
./prepare.sh

if [ $CONTROL_HOSTNAME -eq 1 ]; then
    echo "[INFO] Reboot the machine to apply the new hostname"
fi
echo "[INFO] Don't forget to add the TNGFUE to free5GC via WebConsole"
echo "[INFO] See: https://free5gc.org/guide/TNGF/tngfue-installation/#2-use-webconsole-to-add-ue"
echo "[INFO] Auto deploy script done"
