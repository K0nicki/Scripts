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
    server=1
    ca=0
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
    if [ "$(find . -maxdepth 3 -type d -print | awk -F "/" '{for (i=1;i<=4;i++)print $i}' | grep "EasyRSA")" == "" ]; then
        uploadEasyRSA
        echo $pathToEasyRSA
    else
        pathToEasyRSA=$(find . -maxdepth 3 -name "EasyRSA*" -print | head -n 1)
        echo $'EasyRSA installed'
    fi
}

function uploadEasyRSA() {
    wget -P . $easyRSA_WebPath
    tar xvf EasyRSA-3.0.4.tgz # Unzip
    rm EasyRSA-3.0.4.tgz      # Remove unnecessary .tgz file
    pathToEasyRSA=$(pwd)/EasyRSA-3.0.4
}

function readVars() {
    echo $'Configurating certificate authority...\nPlease, enter the following information:'
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
    readVars
    replaceVars

}

function installInotifyTool() {
    sudo apt install inotify-tools -y
}

function isInotifyTools() {
    if [ $(whereis inotifywait | awk '/:/ {print $2}') == "" ]; then
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
    while read i; do if [ "$i" = ca.crt ]; then break; fi; done \
        < <(inotifywait -e create,open --format '%f' --quiet /tmp --monitor)

    while read i; do if [ "$i" = server.crt ]; then break; fi; done \
        < <(inotifywait -e create,open --format '%f' --quiet /tmp --monitor)
}

function waitForCaReq() {
    while read i; do if [ "$i" = "$clientName".req ]; then break; fi; done \
        < <(inotifywait -e create,open --format '%f' --quiet /tmp --monitor)
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

    echo "Waiting for the server.req file. Send it from server to the ~/tmp directory"
    waitForReq
    $pathToEasyRSA/easyrsa import-req /tmp/server.req server
    $pathToEasyRSA/easyrsa sign-req server server

    echo $'Sending files to CA\n'
    echo "User (server): " && read -r USER_SERV
    echo "Address (server): " && read -r SERV_ADDR
    scp $pathToEasyRSA/pki/issued/server.crt "$USER_SERV@$SERV_ADDR:/tmp" # Transfer the signed certificate and the ca.crt file
    scp $pathToEasyRSA/pki/ca.crt "$USER_SERV@$SERV_ADDR:/tmp"

    waitForCaReq
    $pathToEasyRSA/easyrsa import-req /tmp/"$clientName".req "$clientName"
    $pathToEasyRSA/easyrsa sign-req client "$clientName"

    scp $pathToEasyRSA/pki/"$clientName".req.crt "$USER_SERV@$SERV_ADDR:/tmp"
}

function waitForServerCrt() {
    while read i; do if [ "$i" = "$clientName".req ]; then break; fi; done \
        < <(inotifywait -e create,open --format '%f' --quiet /tmp --monitor)
}

function generateKeyPair() {
    mkdir -p ~/client-configs/keys
    # chmod -R 700 ~/client-configs
    # chown for starting user?
    cd $pathToEasyRSA
    echo "Write client name: "
    read -r clientName
    ./easyrsa gen-req "$clientName" nopass
    cp pki/private/"$clientName".key ~/client-configs/keys/
    scp ./pki/reqs/"$clientName".req "$USER_CA@$CA_ADDR:/tmp"

    waitForServerCrt
    cp /tmp/"$clientName".crt ~/client-configs/keys/
    cp ./ta.key ~/client-configs/keys/
    cp /etc/openvpn/ca.crt ~/client-configs/keys/
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
    sed -i 's/^;user/user/g' file
    sed -i 's/^;group/group/g' file
}

# Tell UFW to allow forwarded packets by default
function allowForward() {
    match="DEFAULT_FORWARD_POLICY"
    change='DEFAULT_FORWARD_POLICY="ACCEPT"'

    sed -i "s/^$match.*$/$change/" /etc/ufw/before.rules
}

function addNatRules() {
    txt="#START OPENVPN RULES \
    \n# NAT table rules \
    \n*nat \
    \n:POSTROUTING ACCEPT [0:0] \
    \n# Allow traffic from OpenVPN client to $dev \
    \n-A POSTROUTING -s 10.8.0.0/8 -o $dev -j MASQUERADE \
    \nCOMMIT \
    \n# END OPENVPN RULES \
    \n"

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
    dev=$(sed -n -e 's/^.*dev //p' file | awk -F " " '{print $1}')

    editUFW
}

function automaticStart() {
    echo "Should the OpenVPN service start automatically? yes/no" && read -r answer
    EXIT=0
    while [ $EXIT -ne 1 ]; do
        if [ $answer == "yes" ] || [ $answer == "y" ]; then
            systemctl enable openvpn@server
            EXIT=1
        elif [ $answer == "no" ] || [ $answer == "n" ]; then
            EXIT=1
        else
            echo "Don't understand. Press yes/no" && read -r answer
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

    printf "\nWrite your server IP address"
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
        sed -e "/${unCommentLines[i]}/s/^;//" -i $BASE_CONF
    done

}

function comment() {

    commentLines=("tls-auth" "ca" "cert" "key")
    for i in $(seq 0 $((${#commentLines[@]} - 1))); do
        sed -e "/${commentLines[i]}/s/^/#/" -i $BASE_CONF
    done
}

function addKeyDirection() {
    sed -i '/auth SHA256/a key-direction 1' $BASE_CONF

}

function dnsResolv() {
    printf "
    \n; script-security 2
    ; up /etc/openvpn/update-resolv-conf
    ; down /etc/openvpn/update-resolv-conf" >>$BASE_CONF

    printf "
    \n; script-security 2
    ; up /etc/openvpn/update-systemd-resolved
    ; down /etc/openvpn/update-systemd-resolved
    ; down-pre
    ; dhcp-option DOMAIN-ROUTE ." >>$BASE_CONF
}

function createClientConfFile() {
    printf "Creating configuration file for client..."
    # Create separate dir for client config file
    mkdir -p ~/client-configs/files
    BASE_CONF=~/client-configs/base.conf
    cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf $BASE_CONF

    getServerIp
    sed -i "s/^remote.*/remote $SERVER_IP 1194/" $BASE_CONF

    comment
    unComment

    sed -i '/^cipher.*/a auth SHA256' $BASE_CONF

    addKeyDirection

    dnsResolv

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
    echo $'Sending files to CA\n'
    echo "User (ca): " && read -r USER_CA
    echo "Address (ca): " && read -r CA_ADDR
    scp ./pki/reqs/server.req "$USER_CA@$CA_ADDR:/tmp"

    echo "Waiting for the ca.crt and server.crt files. Send them from CA to the server's ~/tmp directory"
    waitForCrt
    cp /tmp/{server.crt,ca.crt} /etc/openvpn/

    ./easyrsa gen-dh
    openvpn --genkey --secret ta.key

    cp ./ta.key /etc/openvpn/
    cp ./pki/dh.pem /etc/openvpn/

    generateKeyPair

    configServer
    configNetworking

    runService
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
