#!/bin/bash
# Install docker environment


# ----------------------------------------------------------
#                       Prerequisites
# ----------------------------------------------------------

# Start with nothing
sudo apt-get remove docker docker-engine docker.io containerd runc

# Update and install necessary packages
sudo apt-get update

sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

# Add Docker's official GPG key:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Set up the stable repository
# Get distro name
. /etc/os-release
os_release=$(cat /etc/os-release | grep "ID" | head -n 1 | awk -F '=' '{print $2}')
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/"$os_release" \
   $(lsb_release -cs) \
   stable"


# ----------------------------------------------------------
#                       Docker Engine
# ----------------------------------------------------------

# Install the latest Docker Engine version
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli docker.io containerd.io

printf 'If you want to not entering sudo command each time when user docker use this:\n
sudo usermod -aG docker USER_NAME\n'
