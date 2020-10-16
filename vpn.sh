#!/usr/bin/bash
# Script sets up an OpenVPN server 

easyRSA_WebPath="https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.4/EasyRSA-3.0.4.tgz"

# Require root privilage
if [ $EUID -ne 0 ]; then
    sudo $(pwd -L)/`basename "$0"` $@
    exit
fi

# Handle extends --server and --ca
if [ $# -eq 0 ]; then
    server=1
    ca=0
else
    for i in "$@"
    do
        case $i in
            -s|--server)
                server=1
                ca=0
            shift # past argument=value
            ;;
            -c|--ca)
                server=0
                ca=1
            shift
            ;;
        esac 
    done
fi

# Check internet connection
function checkConnection()
{
    local result=$1

    wget -q --tries=10 --timeout=20 --spider http://google.com
    if [[ $? -eq 0 ]]; then
        $result=0
    else
        $result=1
    fi
}

# Check if the OpenVPN is installed
function isOpenVPN()
{
    if [ $(whereis openvpn | awk '/:/ {print $2}') == "" ]; then
        installOpenVPN
    else
        echo $'OpenVPN installed'
    fi
}

function installOpenVPN()
{
    sudo apt install openvpn -y
}

# Check is the EasyRSA uploaded and save path
function isEasyRSA()
{
    if [ "$(find . -maxdepth 3 -type d -print | awk -F "/" '{for (i=1;i<=4;i++)print $i}' | grep "EasyRSA")" == "" ]; then
        uploadEasyRSA
        echo $pathToEasyRSA
    else
        pathToEasyRSA=$(find . -maxdepth 3 -name "EasyRSA*" -print | head -n 1)   
        echo $'EasyRSA installed'
    fi
}

function uploadEasyRSA()
{
    wget -P . $easyRSA_WebPath
    tar xvf EasyRSA-3.0.4.tgz           # Unzip
    rm EasyRSA-3.0.4.tgz                # Remove unnecessary .tgz file
    pathToEasyRSA=$(pwd)/EasyRSA-3.0.4
}

function readVars()
{
    echo $'Configurating certificate authority...\nPlease, enter the following information:'
    echo $'Coutry: '            && read -r COUNTRY
    echo $'Province: '          && read -r PROVINCE
    echo $'City: '              && read -r CITY
    echo $'Organization: '      && read -r ORG
    echo $'Email: '             && read -r EMAIL
    echo $'Organization Unit: ' && read -r OU

    VARS=($COUNTRY $PROVINCE $CITY $ORG $EMAIL $OU)
}

function replaceVars()
{
    OLD_VARS=("US" "California" "San Francisco" "Copyleft Certificate Co" "me@example.net" "My Organizational Unit")
    for i in $(seq 0 $[${#OLD_VARS[@]}-1]);
    do
        sed -i "/^#.*${OLD_VARS[i]}/s/^#//g" $pathToEasyRSA/vars            # Uncomment appropriate line
        sed -i "s/${OLD_VARS[i]}/${VARS[i]}/g" $pathToEasyRSA/vars          # Replace old variable
    done
}

function configEasyRSA()
{
    cp $pathToEasyRSA/vars.example $pathToEasyRSA/vars
    readVars
    replaceVars

}

function installInotifyTool()
{
    sudo apt install inotify-tools -y
}

function isInotifyTools()
{
    if [ $(whereis inotifywait | awk '/:/ {print $2}') == "" ]; then
        installInotifyTool
    else
        echo $'Inotify-tools installed'
    fi
}

# Wait for the server.req file if is not uploaded
function waitForReq()
{
    while read i; do if [ "$i" = server.req ]; then break; fi; done \
   < <(inotifywait  -e create,open --format '%f' --quiet /tmp --monitor)
}

function ca()
{
    # Check and install the OpenVPN
    isOpenVPN

    # Check and upload the EasyRSA
    isEasyRSA

    # Configure the EasyRSA variables
    configEasyRSA

    $pathToEasyRSA/easyrsa init-pki
    $pathToEasyRSA/easyrsa build-ca

    # Check and upload the Inotify-tools
    isInotifyTools

    echo "Waiting for the server.req file. Send it from server to the ~/tmp directory"
    waitForReq
    $pathToEasyRSA/easyrsa import-req /tmp/server.req server
}

function server()
{
    # Check and install the OpenVPN
    isOpenVPN

    # Check and upload the EasyRSA
    isEasyRSA

    cd $pathToEasyRSA
    ./easyrsa init-pki
    ./easyrsa gen-req server nopass
    
    cp ./pki/private/server.key /etc/openvpn/
    echo $'Sending files to CA\n' 
    echo "User (ca): "      && read -r USER
    echo "Address (ca): "   && read -r SERV_ADDR
    scp ./pki/reqs/server.req "$USER@$SERV_ADDR:/tmp"
}

if [ checkConnection ]; then
    if [ $server -eq 1 ]; then
        server
    else
        ca
    fi 

else
    echo "You are offline. Please check your internet connection and try again." 1>&2
    exit 1
fi