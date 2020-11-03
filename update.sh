#!/bin/bash
# Update, upgrade and remove unnecessary files

# Require root privilage
if [ $EUID -ne 0 ]; then
    sudo $(pwd -L)/`basename "$0"`
    exit
fi

# Update and upgrade
apt update -y
apt upgrade -y
apt autoremove -y
apt clean

# Remove package configuration files
apt purge -y $(dpkg -l | awk '/^rc/ { print $2 }')