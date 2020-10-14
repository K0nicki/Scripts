#!/bin/bash
# Update, upgrade and remove unnecessary files

# Update and upgrade, save logs
apt update && apt upgrade -y > file

if [ $(cat file | grep "autoremove" -c) -gt 0 ]; then
	
	# Remove unnecessary files
	apt autoremove -y
fi

# Remove logs
rm file
