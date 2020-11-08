#!/bin/bash
# Script written to facilitate selecting informations about active containers,
# created images and ???

# Check docker priveleges
dockerMember() {
    groups | awk -F " " '{{for (i=1; i<=len; i++) if ($i=="docker") {exit 0 } } exit 1}' len=$(groups |wc -w)
}

2smallprvlg() {
    printf 'Require sudo or docker group privilege to execute this script'
    exit 1
}

checkPrivilege() {
    dockerMember
    [ $? -eq 0 ] && printf true || 2smallprvlg
}

# Dispay info about images
imageInfo() {

    printf '\n
    ------------------------------------------------------------ \n
                            IMAGES INFO\n
    ------------------------------------------------------------ \n'

    # Number of images
    local imgNumber=$(docker image ls | tail -n +2 | wc -l)
    
    printf "
                            Number of images
                                | $imgNumber |
                            \n"

    printf "
                            Images list
    ------------------------------------------------------------ \n"
    # Images list and details (repo, tag, ID, created time, size)
    docker image ls 
}

logs() {
    printf '\n
    ------------------------------------------------------------ \n
                            Logs\n
    ------------------------------------------------------------ \n'
    docker container logs tutorial | tail -n $1
}

# Display info about containers
containerInfo() {

    printf '\n
    ------------------------------------------------------------ \n
                            CONTAINERS INFO\n
    ------------------------------------------------------------ \n'
    # Number of containers
    local contNumber=$(docker container ls | tail -n +2 | wc -l)

    printf "
                            Number of containers
                                | $contNumber |
                            \n"
    printf "
                            Containers list
    ------------------------------------------------------------ \n"
    # Containers list and their details (ID, img, command, created time, status and exposed ports)
    docker container ls 

    # Display logs. Only last 8 lines
    logs 8
}

# The hearth of the script
funcs=( 
        imageInfo
        containerInfo
    )

# Main loop
if [ checkPrivilege ]; then

    # Main loop
    for fun in ${funcs[@]}; do
        $fun
    done
fi
