#!/bin/bash
# Update, upgrade and remove unnecessary files

# If not root, run it as root
if [ $EUID -ne 0 ]; then
    sudo $(pwd -L)/update.sh
    exit
fi

# Update and upgrade
apt update && apt upgrade -y
apt autoremove -y
apt clean

# Remove package configuration files
apt purge -y $(dpkg -l | awk '/^rc/ { print $2 }')