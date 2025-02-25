#!/bin/bash

#make script fail, when expandimg uninitialized variables
set -o nounset

#$0 returns relative or absolute path to the executed script
#dirname returns relative path to directory, where the $0 script exists
#$( dirname "$0" ) the dirname "$0" command returns relative path to directory of executed script,
#which is then used as argument for source command
#source loads content of specified file into current shell
SCRIPT_DIR=$(dirname "$0")
# shellcheck source="/Volumes/DataExt/Chris/Cursor/Proxmox Scripts/ProxmoxScripts/colors_format_icons.func"
source "$SCRIPT_DIR/colors_format_icons.func"
# shellcheck source="/Volumes/DataExt/Chris/Cursor/Proxmox Scripts/ProxmoxScripts/install.func"
source "$SCRIPT_DIR/install.func"

# Using whiptail to create a menu
scriptCount=3
CHOICE=$(whiptail --title "Proxmox helper scripts - Script Selector" --menu "Choose an option" "$whiptailHeight" "$whiptailWidth" $scriptCount \
"1" "Install / Update helper scripts" \
"2" "Complete the setup of a new lxc container" \
"3" "Install homebridge in an lxc container" 3>&1 1>&2 2>&3)

# Execute the corresponding script based on user input using bash
case $CHOICE in
    1)
        pushd "$SCRIPT_DIR" >/dev/null
        install_script true
        popd >/dev/null
        ;;
    2)
        bash "$SCRIPT_DIR/new_lxc.sh"
        ;;
    3)
        bash "$SCRIPT_DIR/install_homebridge.sh"
        ;;
    *)
        echo "Invalid choice"
        ;;
esac