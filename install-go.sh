#!/usr/bin/env bash

echo "Welcome to the Go installer script"

# Control variables
GO_LANG_VERSION=1.21.8

##############
# Install Go #
##############
echo "[INFO] Installing Go $GO_LANG_VERSION"
echo "[INFO] Downloading the package from source"
# Install Go
wget -nc https://dl.google.com/go/go$GO_LANG_VERSION.linux-amd64.tar.gz
echo "[INFO] Extracting and installing package contents"
sudo tar -C /usr/local -zxf go$GO_LANG_VERSION.linux-amd64.tar.gz
echo "[INFO] Updating envitonment vars"
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo "[INFO] Don't forget to reload the bash env using"
echo "source ~/.bashrc"
sleep 0.1 # wait for the file to be writen
echo "[INFO] Go installation finished"
