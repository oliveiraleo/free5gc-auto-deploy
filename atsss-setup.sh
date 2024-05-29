#!/usr/bin/env bash

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
echo -n "[INFO] Standing by while N3IWUE goes up... "
sleep 10 # waits for the device to be completely up
echo "[OK]"
echo "[INFO] Starting to run 5G gNB"
cd ../UERANSIM
build/nr-gnb -c config/free5gc-gnb.yaml > /dev/null 2>&1 &
echo -n "[INFO] Standing by while gNB is setup... "
sleep 10
echo "[OK]"
echo "[INFO] Starting to run 5G UE"
sudo build/nr-ue -c config/free5gc-ue.yaml > /dev/null 2>&1 &
echo -n "[INFO] Standing by while UE is setup... "
sleep 3
echo "[OK]"
echo "[INFO] ATSSS setup script done"

# TODO save the PIDs so it's possible to kill the processes later easily
