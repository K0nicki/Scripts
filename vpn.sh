#!/usr/bin/bash
# Script sets up an OpenVPN server

easyRSA_WebPath="https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.4/EasyRSA-3.0.4.tgz"

# Require root privilage
if [ $EUID -ne 0 ]; then
    sudo $(pwd -L)/$(basename "$0") $@
    exit
fi

# Handle extends --server and --ca
if [ $# -eq 0 ]; then
    printf "Use --server or --ca to determine appropriate mode\n"
    exit
else
    for i in "$@"; do
        case $i in
        -s | --server)
            server=1
            ca=0
            ;;
        -c | --ca)
            server=0
            ca=1
            ;;
        esac
    done
fi

# Check internet connection
function checkConnection() {
    local result=$1

    wget -q --tries=10 --timeout=20 --spider http://google.com
    if [[ $? -eq 0 ]]; then
        $result=0
    else
        $result=1
    fi
}

# Check if the OpenVPN is installed
function isOpenVPN() {
    if [ $(whereis openvpn | awk '/:/ {print $2}') == "" ]; then
        installOpenVPN
    else
        echo $'OpenVPN installed'
    fi
}

function installOpenVPN() {
    sudo apt install openvpn -y
}

# Check is the EasyRSA uploaded and save path
function isEasyRSA() {
    if [ "$(sudo find . -maxdepth 3 -type d -print | awk -F "/" '{for (i=1;i<=4;i++)print $i}' | grep "EasyRSA")" == "" ]; then
        uploadEasyRSA
    else
        pathToEasyRSA=$(sudo find . -maxdepth 3 -name "EasyRSA*" -print | head -n 1)
        echo $'EasyRSA installed'
    fi
}

function uploadEasyRSA() {
    sudo wget -P . $easyRSA_WebPath
    tar xvf EasyRSA-3.0.4.tgz # Unzip
    sudo rm EasyRSA-3.0.4.tgz # Remove unnecessary .tgz file
    pathToEasyRSA=$(pwd -L)/EasyRSA-3.0.4
}

function readVars() {
    printf $'Configurating certificate authority...\nPlease, enter the following information:\n'
    echo $'Coutry: ' && read -r COUNTRY
    echo $'Province: ' && read -r PROVINCE
    echo $'City: ' && read -r CITY
    echo $'Organization: ' && read -r ORG
    echo $'Email: ' && read -r EMAIL
    echo $'Organization Unit: ' && read -r OU

    VARS=($COUNTRY $PROVINCE $CITY $ORG $EMAIL $OU)
}

function replaceVars() {
    OLD_VARS=("US" "California" "San Francisco" "Copyleft Certificate Co" "me@example.net" "My Organizational Unit")
    for i in $(seq 0 $((${#OLD_VARS[@]} - 1))); do
        sed -i "/^#.*${OLD_VARS[i]}/s/^#//g" $pathToEasyRSA/vars   # Uncomment appropriate line
        sed -i "s/${OLD_VARS[i]}/${VARS[i]}/g" $pathToEasyRSA/vars # Replace old variable
    done
}

function configEasyRSA() {
    cp $pathToEasyRSA/vars.example $pathToEasyRSA/vars

    # Modify file
    readVars
    replaceVars

}

function installInotifyTool() {
    sudo apt install inotify-tools -y
}

function isInotifyTools() {
    if [ "$(whereis inotifywait | awk '/:/ {print $2}')" == "" ]; then
        installInotifyTool
    else
        echo $'Inotify-tools installed'
    fi
}

# Wait for the server.req file if is not uploaded
function waitForReq() {
    while read i; do if [ "$i" = server.req ]; then break; fi; done \
        < <(inotifywait -e create,open --format '%f' --quiet /tmp --monitor)
}

function waitForCrt() {

    while read i; do if [ "$i" == ca.crt ]; then break; fi; done \
        < <(inotifywait -e create,open --format '%f' --quiet /tmp --monitor)

    while read i; do if [ "$i" == server.crt ]; then break; fi; done \
        < <(inotifywait -e create,open --format '%f' --quiet /tmp --monitor)
}

function waitForCaReq() {

    rm /tmp/server.req

    while read i; do if [[ "$i" =~ /*.req$ ]]; then break; fi; done \
        < <(inotifywait -e create,open --format '%f' --quiet /tmp --monitor)
}

function finishCA() {
    printf "\nCA machine has been configured!\n"
}

function waitForServerCrt() {

    printf "\nWaiting for the client .crt file. Send them from CA to the server's /tmp directory"

    while read i; do if [ "$i" == "$CLIENT_NAME".crt ]; then break; fi; done \
        < <(inotifywait -e create,open --format '%f' --quiet /tmp --monitor)
}

function sendCLIENT_NAME() {
    printf "$CLIENT_NAME" >CLIENT_NAME.conf
    scp ./CLIENT_NAME.conf "$USER_CA@$CA_ADDR:/tmp"
    rm ./CLIENT_NAME.conf
}

function generateKeyPair() {

    mkdir -p ./client-configs/keys

    # chmod -R 700 /client-configs
    #? chown for starting user?

    printf "Write client name: \n"
    read -r CLIENT_NAME
    ./easyrsa gen-req "$CLIENT_NAME" nopass
    cp pki/private/"$CLIENT_NAME".key ./client-configs/keys/

    # Send client name and .req file to CA machine
    sendCLIENT_NAME
    scp ./pki/reqs/"$CLIENT_NAME".req "$USER_CA@$CA_ADDR:/tmp"

    waitForServerCrt
    cp /tmp/"$CLIENT_NAME".crt ./client-configs/keys/
    cp ./ta.key ./client-configs/keys/
    cp /etc/openvpn/ca.crt ./client-configs/keys/
}

function configServer() {
    cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/
    gzip -d /etc/openvpn/server.conf.gz
    serverConf=/etc/openvpn/server.conf

    # Add an auth directive below the section on cryptographic ciphers
    sed -i '/^cipher.*/a auth SHA256' $serverConf

    # Change the Diffie-Hellman key
    sed -i 's/^dh.*/dh dh.pem/g' $serverConf

    # Remove comments
    sed -i 's/^;user/user/g' $serverConf
    sed -i 's/^;group/group/g' $serverConf
}

# Tell UFW to allow forwarded packets by default
function allowForward() {
    match="DEFAULT_FORWARD_POLICY"
    change='DEFAULT_FORWARD_POLICY="ACCEPT"'

    sed -i "s/^$match.*$/$change/" /etc/default/ufw
}

function addNatRules() {

    txt="#START OPENVPN RULES\n# NAT table rules\n*nat\n:POSTROUTING ACCEPT [0:0]\n# Allow traffic from OpenVPN client to $dev\n-A POSTROUTING -s 10.8.0.0/8 -o $dev -j MASQUERADE\nCOMMIT\n# END OPENVPN RULES\n"
    match="# Don't delete these required lines"

    sed -i "/$match/ i $txt" /etc/ufw/before.rules
}

function editUFW() {
    addNatRules
    allowForward

    # Open ports for VPN
    ufw allow 1194/udp
    ufw allow OpenSSH

    # Restart Firewall
    ufw disable
    ufw enable
}

function configNetworking() {

    # uncomment portforwarding
    sed -i 's/^#net.ipv4.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf

    # Get public interface name
    ip route | grep default >file
    dev="$(sed -n -e 's/^.*dev //p' file | awk -F " " '{print $1}' | head -n 1)"
    rm file

    editUFW
}

function automaticStart() {
    printf "Should the OpenVPN service start automatically? yes/no\n" && read -r answer
    EXIT=0
    while [ $EXIT -ne 1 ]; do
        if [ $answer == "yes" ] || [ $answer == "y" ]; then
            systemctl enable openvpn@server
            EXIT=1
        elif [ $answer == "no" ] || [ $answer == "n" ]; then
            EXIT=1
        else
            printf "Don't understand. Press yes/no\n" && read -r answer
        fi
    done
}

function runService() {
    systemctl start openvpn@server
    automaticStart
}

function getServerIp() {
    # Show ip interfaces and addresses
    printf "\n"
    ip a

    printf "\nWrite your server IP address: "
    exit=0
    while [ $exit -ne 1 ]; do
        read SERVER_IP
        if [ $"(echo $SERVER_IP | grep -Po '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$')" != "" ]; then
            exit=1
        else
            printf "Incorrect IP address. Try again:\n"
        fi
    done
}

function unComment() {

    unCommentLines=("user" "group")
    for i in $(seq 0 $((${#unCommentLines[@]} - 1))); do
        sed -e "/${unCommentLines[i]}/s/^;//" -i $BASE_CONFIG
    done

}

function comment() {

    commentLines=("tls-auth" "ca" "cert" "key")
    for i in $(seq 0 $((${#commentLines[@]} - 1))); do
        sed -e "/${commentLines[i]}/s/^/#/" -i $BASE_CONFIG
    done
}

function addKeyDirection() {

    sed -i '/auth SHA256/a key-direction 1' $BASE_CONFIG

}

function dnsResolv() {
    printf "
    \n; script-security 2
    ; up /etc/openvpn/update-resolv-conf
    ; down /etc/openvpn/update-resolv-conf" >>$BASE_CONFIG

    printf "
    \n; script-security 2
    ; up /etc/openvpn/update-systemd-resolved
    ; down /etc/openvpn/update-systemd-resolved
    ; down-pre
    ; dhcp-option DOMAIN-ROUTE ." >>$BASE_CONFIG
}

function prepareClientConfFile() {
    printf "Creating configuration file for client..."
    # Create separate dir for client config file
    mkdir -p ./client-configs/files
    BASE_CONFIG=./client-configs/base.conf
    cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf $BASE_CONFIG

    getServerIp
    sed -i "s/^remote.*/remote $SERVER_IP 1194/" $BASE_CONFIG

    comment
    unComment

    sed -i '/^cipher.*/a auth SHA256' $BASE_CONFIG

    addKeyDirection

    dnsResolv

}

function createConfigScript() {
    CONFIG_SCRIPT_PATH=./client-configs/make_config.sh
    touch $CONFIG_SCRIPT_PATH
    printf '#!/bin/bash

    # First argument: Client identifier

    KEY_DIR=./keys
    OUTPUT_DIR=./files
    BASE_CONFIG=./base.conf
    
    cat ${BASE_CONFIG} \
        <(echo -e "<ca>") \
        ${KEY_DIR}/ca.crt \
        <(echo -e "</ca>\n<cert>") \
        ${KEY_DIR}/${1}.crt \
        <(echo -e "</cert>\n<key>") \
        ${KEY_DIR}/${1}.key \
        <(echo -e "</key>\n<tls-auth>") \
        ${KEY_DIR}/ta.key \
        <(echo -e "</tls-auth>") \
        > ${OUTPUT_DIR}/${1}.ovpn' >$CONFIG_SCRIPT_PATH

    # Make it an executable file
    chmod +x $CONFIG_SCRIPT_PATH
}

function createConfigFile() {

    printf "\nPLease, enter the client identifier. It will be also a client configuration file name:\n"
    cd $(dirname $CONFIG_SCRIPT_PATH)
    ./make_config.sh $CLIENT_NAME
}

function finishServ() {
    printf "\n
    Congratulations! You have just finished your OpenVPN configuration!\n \
    Now send the $CLIENT_NAME.ovpn configuration file to your device.\n \
    It is located in the $pathToEasyRSA/"$(dirname "${CONFIG_SCRIPT_PATH}")"/files\n"
}

function ca() {
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

    printf "Waiting for the server.req file. Send it from server to the /tmp directory\n"
    waitForReq
    $pathToEasyRSA/easyrsa import-req /tmp/server.req server
    $pathToEasyRSA/easyrsa sign-req server server

    printf $'Sending files to CA\n'
    echo "User (server): " && read -r USER_SERV
    echo "IP address (server): " && read -r SERV_ADDR

    # Transfer the signed certificate and the ca.crt file
    scp ./pki/ca.crt "$USER_SERV@$SERV_ADDR:/tmp"
    scp ./pki/issued/server.crt "$USER_SERV@$SERV_ADDR:/tmp"

    printf "Waiting for the req file. Send them from server to the CA's /tmp directory\n"
    waitForCaReq

    CLIENT_NAME=$(cat /tmp/CLIENT_NAME.conf)
    rm /tmp/CLIENT_NAME.conf
    $pathToEasyRSA/easyrsa import-req /tmp/"$CLIENT_NAME".req "$CLIENT_NAME"
    $pathToEasyRSA/easyrsa sign-req client "$CLIENT_NAME"

    scp ./pki/issued/"$CLIENT_NAME".crt "$USER_SERV@$SERV_ADDR:/tmp"

    # Display summary
    finishCA
}

function server() {
    # Check and install the OpenVPN
    isOpenVPN

    # Check and upload the EasyRSA
    isEasyRSA

    cd $pathToEasyRSA
    ./easyrsa init-pki
    ./easyrsa gen-req server nopass

    cp ./pki/private/server.key /etc/openvpn/
    printf $'Sending files to CA\n'
    echo "User (ca): " && read -r USER_CA
    echo "Address (ca): " && read -r CA_ADDR
    scp ./pki/reqs/server.req "$USER_CA@$CA_ADDR:/tmp"

    printf "Waiting for the ca.crt and server.crt files. Send them from CA to the server's /tmp directory\n"
    waitForCrt
    cp /tmp/{server.crt,ca.crt} /etc/openvpn/

    ./easyrsa gen-dh
    openvpn --genkey --secret ta.key

    cp ./ta.key /etc/openvpn/
    cp ./pki/dh.pem /etc/openvpn/

    generateKeyPair

    configServer
    #configNetworking

    # Start the OpenVPN service
    runService

    # Prepare the environment
    prepareClientConfFile

    # Create client config script
    createConfigScript

    # Create client config file
    createConfigFile

    # Display summary
    finishServ
}

if [ checkConnection ]; then
    if [ $server -eq 1 ]; then
        server
    else
        ca
    fi
else
    printf "You are offline. Please check your internet connection and try again.\n" 1>&2
    exit 1
fi


# ---------------------------------------------------------------------------
#                               TODO LIST:
# ---------------------------------------------------------------------------
# [ ] Should validate all user's input
# [ ] Imoa the IP dev shouldn't be select in this way. Get it from user?
# [ ] Dont ask about client nickname, just get it from $CLIENT_NAME
# ---------------------------------------------------------------------------
