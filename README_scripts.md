# Scripts  
(☞ﾟヮﾟ)☞ _The repository was created to facilitate ***my*** and visitior's lives_ ☜(ﾟヮﾟ☜)


## Contents:
### Shell:
  ------ SERVERS ------ 
   - [update.sh](https://github.com/K0nicki/Scripts/blob/master/update.sh) - Simple script for updating and upgrading server. Additionaly it removes unnecessary files connected with update
   - [vpn.sh](https://github.com/K0nicki/Scripts/blob/master/vpn.sh) - The script configures and starts OpenVPN service. Demand separate CA machine and connection between them. It works in two modes: Server and CA
   - [maintance.sh](https://github.com/K0nicki/Scripts/blob/master/maintance.sh) - This script collects system data. Futhermore it uses crone in order to recursively update data
   - [.bash_aliases](https://github.com/K0nicki/Scripts/blob/master/.bash_aliases) - It is not script but this file contains some useful aliases for better using Linux command line, settings for colorful prompt and cute images that will be displayed when the terminal session starts 
   
   ------ DOCKER ------ 
   - [installDocker.sh](https://github.com/K0nicki/Scripts/blob/master/installDocker.sh) - Install Docker environment
   - [info_Docker.sh](https://github.com/K0nicki/Scripts/blob/master/info_Docker.sh) - Display Docker images and containers information. Save containeers logs into the file.
   
### PowerShell:
   - [send.ps1](https://github.com/K0nicki/Scripts/blob/master/send.ps1) - Automate sending sripts to server. You can change the extension of sending files ("--ext" option) and server address ("--addr", format: USER@ADDRESS:PATH). In case of no input files, it sends all files with matching extension in workdir
   - [ssh_key.ps1](https://github.com/K0nicki/Scripts/blob/master/ssh_key.ps1) - Create a public-private key pair. Send the former into the remote server in order to establish secure shell connection without entering password
   
### Python:
   - [unixFF.sh](https://github.com/K0nicki/Scripts/blob/master/unixFF.sh) - Change file format of given as parameters files. If there is no input files, it change FF all files in workdir with specified extension (.sh by default). You can change the extension with "-ext" option
   - [script.sh](https://github.com/K0nicki/Scripts/blob/master/script.sh) - Display given parameters

### Ansible:
   - [Ansible](https://github.com/K0nicki/Scripts/tree/master/Ansible) - Very simple configuration for Ansible. It was created to easily updating servers and coping my scripts to these machines. One command updates the entire topology!
