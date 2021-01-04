#!/bin/bash
# Install docker environment

# Require root privilage
if [ $EUID -ne 0 ]; then
    sudo $(pwd -L)/`basename "$0"`
    exit
fi

# Get distro name
. /etc/os-release
os_release=$(cat /etc/os-release | grep "ID" | head -n 1 | awk -F '=' '{print $2}')

# ----------------------------------------------------------
#                       Prerequisites
# ----------------------------------------------------------

# Start with nothing
apt-get remove docker docker-engine docker.io containerd runc

# Update and install necessary packages
apt-get update

apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

# Add Docker's official GPG key:
curl -fsSL https://download.docker.com/linux/"$os_release"/gpg | sudo apt-key add -

# Set up the stable repository
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/"$os_release" \
   $(lsb_release -cs) \
   stable"

# ----------------------------------------------------------
#                       Docker Engine
# ----------------------------------------------------------

# Install the latest Docker Engine version
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io

# Create docker group
addgroup docker 

printf 'If you want to not entering sudo command each time when user docker use this:
sudo usermod -aG docker USER_NAME\n'
