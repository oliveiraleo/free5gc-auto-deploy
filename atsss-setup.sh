#!/usr/bin/env bash

PID_LIST=()

echo "Welcome to the ATSSS setup script"

sudo -v # caches credentials
if [ $? == 1 ]
then
    echo "[ERROR] Without root permission, you cannot execute the simulated devices"
    exit 1
fi
echo "[INFO] Execution started"

echo "[INFO] Starting to run N3IWUE"
cd n3iwue/
./run.sh > /dev/null 2>&1 & # silences the output of the command and sends it to background
PID_LIST+=($!)
echo -n "[INFO] Standing by while N3IWUE goes up... "
sleep 10 # waits for the device to be completely up
echo "[OK]"
echo "[INFO] Starting to run 5G gNB"
cd ../UERANSIM
build/nr-gnb -c config/free5gc-gnb.yaml > /dev/null 2>&1 &
PID_LIST+=($!)
echo -n "[INFO] Standing by while gNB is setup... "
sleep 10
echo "[OK]"
echo "[INFO] Starting to run 5G UE"
sudo build/nr-ue -c config/free5gc-ue.yaml > /dev/null 2>&1 &
PID_LIST+=($!)
echo -n "[INFO] Standing by while UE is setup... "
sleep 3
echo "[OK]"
echo "[INFO] ATSSS devices are successfully running"
echo "TIP: Hit Ctrl+C to finish this script"
# echo "${PID_LIST[@]}" # DEBUG

function terminate()
{
    # echo "${PID_LIST[@]}" # DEBUG
    for ((i=${#PID_LIST[@]}-1;i>=0;i--)); do
        sudo kill -SIGTERM ${PID_LIST[i]}
    done
    # TODO remove the network interfaces so the script can be run multiple times

    wait ${PID_LIST}
    exit 0
}

trap terminate SIGINT

wait ${PID_LIST}
echo "[INFO] ATSSS setup script done"

