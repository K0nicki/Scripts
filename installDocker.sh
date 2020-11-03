#!/bin/bash
# Install docker and other dependencies


# ----------------------------------------------------------
#                       Prerequisites
# ----------------------------------------------------------

# Start with nothing
sudo apt-get remove docker docker-engine docker.io containerd runc

# Update and install necessary packages
sudo apt-get update

sudo apt-get 
    install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

# Add Docker's official GPG key:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Set up the stable repository
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"


# ----------------------------------------------------------
#                       Docker Engine
# ----------------------------------------------------------

# Install the latest Docker Engine version
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io