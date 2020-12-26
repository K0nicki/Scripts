#!/bin/bash
# Script written to facilitate selecting information about created images, 
# active containers, their logs and status

LOG_FILE_PATH=docker_logs/logs.log
LOG_PRECISION=15

# User-friendly output functions
center_printf() {
    printf "\t\t\t\t$1"
}

banner_print() {
    printf '\n'
    line_print
    center_printf "$1 INFO\n"
    line_print
    printf '\n'
}

number_print() {

    center_printf "Number of $1\n"
    center_printf "      | $2 |\n\n"
}

line_print() {
        for i in {1..60}; do printf '-'; done
        printf '\n'
}

# In case of executing script by non privileged user
toosmallprvlg() {
    printf 'Require sudo or docker group privilege to execute this script\n'
    exit 1
}

# If docker service is inactive, run it or exit
run_docker_service() {
    
    printf "Docker service seems to be inactive. Do you want to run it?\n[y/n]: "
    read -r answer

    if [ "$answer" == "y" ]; then
        echo "Starting docker service..."
        sudo systemctl start docker
        # sudo service docker start
        echo "Done"
    elif [ "$answer" == "n" ]; then
        echo "Cannot execute script without docker deamon. Please run it manually"
        exit 1
    else
        echo "Wrong key!"
        run_docker_service
    fi
}

# Check docker priveleges
checkPrivilege() {

    # Check if docker service is active
    if [ "$(systemctl status docker |grep -i active |awk '{print $2}')" != "active" ]; then
        run_docker_service
    fi

    # Check docker version, ignore all outputs
    docker version &>/dev/null
}

# Dispay info about images
imageInfo() {

    # Banner
    banner_print "IMAGES"

    # Number of images
    local imgNumber=$(docker image ls | tail -n +2 | wc -l)
    
    # Output
    number_print "images" "$imgNumber"
    center_printf "Images list\n"
    line_print

    # Images list and details (repo, tag, ID, created time, size)
    docker image ls 
}

# Collect logs
logs() {

    # Banner 
    line_print
    center_printf "$1 container logs\n"
    line_print

    # Logs
    docker container logs $1 | tail -n $2
    printf '\n'
}

# Create and clear log file
logs_location() {
    
    # Create dir for logs if don't exists yet
    mkdir -p $(dirname $LOG_FILE_PATH)

    # Clear logs file if exist
    >$LOG_FILE_PATH
}

# Display info about containers
containerInfo() {

    # Number of containers
    local contNumber=$(docker container ls -al | tail -n +2 | wc -l)
    local contNames=$(docker ps -al --format '{{.Names}}')

    # Banner
    banner_print "CONTAINERS"
    
    # Output
    number_print "containers" $contNumber
    center_printf "Containers list\n"
    line_print

    # Containers list and their details (ID, img, command, created time, status and exposed ports)
    docker container ls -al

    printf '\n'
    center_printf "Containers info\n"

    # Prepare location for logs
    logs_location

    # Display stats for each container
    for container in ${contNames[@]}; do
        line_print
        docker container stats $container --no-stream

        # Display logs. Only last 8 lines
        logs $container $LOG_PRECISION >>$LOG_FILE_PATH 2>&1
    done

}

help_info() {
    printf 'Usage: info_Docker.sh [OPTIONS]...
Print basic info about docker'\''s images and containers\n
-c, --container\t\tDisplay containers information and save logs into log file
-i, --images\t\tDisplay images information
'
}

# The hearth of the script
funcs=( 
        imageInfo
        containerInfo
    )

# Main loop
checkPrivilege
if [ $? -eq 0 ]; then
    if [ $# -eq 0 ]; then
        for fun in ${funcs[@]}; do
            $fun
        done
        printf "\n Created log file in $LOG_FILE_PATH\n"
    else

    # Parse arguments
        for i in $@; do
            case $i in
            -h | --help)
                help_info
            ;;
            -c | --container)
                containerInfo
            ;;
            -i | --images)
                imageInfo
            ;;
            *)
                printf 'Unknown option. Try --help\n'
                exit 1
            ;;
            esac
        doneP
else
    toosmallprvlg
fi
