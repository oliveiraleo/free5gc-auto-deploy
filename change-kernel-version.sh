#!/usr/bin/env bash

OLD_KERNEL_VERSION=$(uname -r)
NEW_KERNEL_VERSION="5.15.0-116-generic"

# TODO add a way to change new kernel version via param/args
# TODO compare kernel versions before running
echo "[INFO] Currently installed kernel version: $OLD_KERNEL_VERSION"
echo "[INFO] Kernel version to be installed: $NEW_KERNEL_VERSION"

echo "[INFO] Updating system package lists"
sudo apt update
echo "[INFO] Installing kernel $NEW_KERNEL_VERSION"
sudo apt install linux-image-$NEW_KERNEL_VERSION linux-headers-$NEW_KERNEL_VERSION -y
echo "[INFO] Updating GRUB and initramfs"
sudo update-initramfs -u -k all && sudo update-grub

echo "[INFO] Reinstalling the GTP-U kernel module"
cd gtp5g/
#TODO if command above fails, clone gtp again, install then remove the new clone
make
sudo make install
echo "[INFO] Installation finished, reboot to be able to use the new kernel version"
