#!/bin/bash
# Script collects data about memory usage, logins, command history


LOG_FILE_PATH=/var/log/sysInfo.log                                 # Path to log file
SCRIPT_NAME="$(basename $0)"

isCron() {
    if [ $(whereis cron | awk '/:/ {print $2}') == "" ]; then
        sudo apt install cron -y
    fi
}

memInfo() {
    local file=${1}
    printf '
    \n
    # ----------------------------------------------------------------------
    #                           MEMORY INFO
    # ----------------------------------------------------------------------
    \n' >>$file
    df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }' >>$file
}

commandInfo() {
    local file=${1}
    printf '
    \n
    # ----------------------------------------------------------------------
    #                           COMMAND HISTORY
    # ----------------------------------------------------------------------
    \n' >>$file
    cat .bash_history | tail -n 15 >>$file                        # List of last used commands
}

loginInfo() {
    local file=${1}
    printf '
    \n
    # ----------------------------------------------------------------------
    #                           REVIEW LOGINS
    # ----------------------------------------------------------------------
    \n' >>$file
    last -n 15 >>$file                                            # List of last 15 logins
}

cronTime() {

    local my_privilege="0 6     "
    local privilege="$(cat /etc/crontab | grep cron.daily | awk -F "root" '{print $1}')"

    if [ "$privilege" != "$my_privilege" ]; then

        # Substitute wrong update time in crontab
        sed -i "s/$privilege/$my_privilege/" /etc/crontab
    fi
}


# Require root privilege
if [ $EUID -ne 0 ]; then
    sudo $(pwd -L)/$(basename "$0")
    exit 1
fi

# Clear log file
if [ -e $LOG_FILE_PATH ]; then
    >$LOG_FILE_PATH
fi


# The hearth of the script
funcs=( 
        memInfo 
        commandInfo 
        loginInfo
    )

# Check if cron is already instaleld
isCron

# Main loop
for i in ${funcs[@]}; do
    $i $LOG_FILE_PATH
done

# Update script always at 6am every day
cronTime

# If log file doesn't exist or if there are any changes 
# copy script into cron.daily dir
if [ ! $([ -e /etc/cron.daily/"$SCRIPT_NAME" ]) ] || [ $(cmp $0 /etc/cron.daily/"$SCRIPT_NAME") != "" ]; then
    cp $0 /etc/cron.daily/ 
    chmod +x /etc/cron.daily/"$SCRIPT_NAME" 
fi