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
# shellcheck source="/Volumes/DataExt/Chris/Cursor/Proxmox Scripts/ProxmoxScripts/error_handler.func"
source "$SCRIPT_DIR/error_handler.func"
activate_err_handler
# shellcheck source="/Volumes/DataExt/Chris/Cursor/Proxmox Scripts/ProxmoxScripts/message_spinner.func"
source "$SCRIPT_DIR/message_spinner.func"
# shellcheck source="/Volumes/DataExt/Chris/Cursor/Proxmox Scripts/ProxmoxScripts/password_validation.func"
source "$SCRIPT_DIR/password_validation.func"
# shellcheck source="/Volumes/DataExt/Chris/Cursor/Proxmox Scripts/ProxmoxScripts/usermap.func"
source "$SCRIPT_DIR/usermap.func"
# shellcheck source="/Volumes/DataExt/Chris/Cursor/Proxmox Scripts/ProxmoxScripts/exec_script_in_container.func"
source "$SCRIPT_DIR/exec_script_in_container.func"

containerId=""
rootmapUname=""
loginUname=""
containerMount=""
mountpointInContainer=""
applicationTitle=""
test=false
spinnerPid=""

while [ $# -gt 0 ]; do
  case "$1" in
  --containerid=* | -containerid=*)
    containerId="${1#*=}"
    ;;
  --rootmapuname=* | -rootmapuname=*)
    rootmapUname="${1#*=}"
    ;;
  --loginuname=* | -loginuname=*)
    loginUname="${1#*=}"
    ;;
  --mount=* | -mount=*)
    containerMount="${1#*=}"
    ;;
  --apptitle=* | -apptitle=*)
    applicationTitle="${1#*=}"
    ;;
  --test | -test)
    test=true
    ;;
  --mountpointincontainer=* | -mountpointincontainer=*)
    mountpointInContainer="${1#*=}"
    ;;
  *)
    printf "***************************\n"
    printf "* Error: Invalid argument %s.*\n" "$1"
    printf "***************************\n"
    #exit 1
    ;;
  esac
  shift
done

whiptailBacktitle="Configure new LXC Container"

# Check if the shell is using bash
# if [[ "$(basename "$SHELL")" != "bash" ]]; then
# $SHELL gives the default shell. If (as best practice) login for root is disabled by setting the default shell to /bin/false this is returning wrong results
bashtest=${BASH_VERSION:-} #Otherwise if variable is not set, we get an error (due to nounset)
if [[ -z "$bashtest" ]]; then
  clear
  msg_error "Your default shell is currently not set to Bash. To use these scripts, please switch to the Bash shell."
  echo -e "\nExiting..."
  sleep 2
  exit
fi

# Run as root only
if [[ "$(id -u)" -ne 0 ]]; then
  clear
  msg_error "Please run this script as root."
  echo -e "\nExiting..."
  sleep 2
  exit
fi

#We cannot test for SSh as SUDO will clear the variable SSH_CLIENT
# This function checks if the script is running through SSH and prompts the user to confirm if they want to proceed or exit.
#  if [ -n "${SSH_CLIENT:+x}" ]; then
#    if whiptail --backtitle "$whiptailBacktitle" --defaultno --title "SSH DETECTED" --yesno "It's advisable to utilize the Proxmox shell rather than SSH, as there may be potential complications with variable retrieval. Proceed using SSH?" $whiptailHeight $whiptailWidth; then
#      whiptail --backtitle "$whiptailBacktitle" --msgbox --title "Proceed using SSH" "You've chosen to proceed using SSH. If any issues arise, please run the script in the Proxmox shell before creating a repository issue." $whiptailHeight $whiptailWidth
#    else
#      clear
#      echo "Exiting due to SSH usage. Please consider using the Proxmox shell."
#      exit
#    fi
#  fi

#Whiptail sends the user's input to stderr, 3>&1 1>&2 2>&3 switched stderr and stdout, so we can retrieve the value
if [ -z "$containerId" ]; then
  if containerId=$(whiptail --backtitle "$whiptailBacktitle" --inputbox "Set Container ID" "$whiptailHeight" "$whiptailWidth" --title "CONTAINER ID" 3>&1 1>&2 2>&3); then
    if [ -z "$containerId" ]; then
      msg_error "Container ID is mandatory"
      exit
    else
      # Test if ID is valid
      if [ "$containerId" -lt "100" ]; then
        msg_error "ID cannot be less than 100."
        exit
      else
        echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Container ID: ${COLOR_BRIGHT_GREEN}$containerId${COLOR_RESET}"
      fi
    fi
  else
    exit
  fi
fi


if [ -z "$applicationTitle" ]; then
  if applicationTitle=$(whiptail --backtitle "$whiptailBacktitle" --inputbox "Set Application Title" "$whiptailHeight" "$whiptailWidth" --title "CONTAINER ID" 3>&1 1>&2 2>&3); then
    if [ -z "$containerId" ]; then
      msg_info "No application title provided"
      exit
    fi
  else
    exit
  fi
fi

#Create user on Proxmox Host. Naming convention: All small letters! Capitals not allowed lxc_<<container>>
#_<<compose-project>>_<<container>> for users in docker container
#  Example: lxc_docker_unifi_network_app

if [ -z "$rootmapUname" ]; then
  if rootmapUname=$(whiptail --backtitle "$whiptailBacktitle" --inputbox "Create user to map container root to (Naming convention: All small letters! Capitals not allowed lxc_<<container>>)" "$whiptailHeight" "$whiptailWidth" --title "Login User" 3>&1 1>&2 2>&3); then
    if [ -z "$rootmapUname" ]; then
      msg_error "Rootmap User is mandatory"
      exit
    else
      echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Root will be mapped to host user name: ${COLOR_BRIGHT_GREEN}$rootmapUname${COLOR_RESET}"
    fi
  else
    exit
  fi
fi

if [ -z "$loginUname" ]; then
  if loginUname=$(whiptail --backtitle "$whiptailBacktitle" --inputbox "Set login user name (Naming convention: All small letters! Capitals not allowed. E.g. chris)" "$whiptailHeight" "$whiptailWidth" --title "Login User" 3>&1 1>&2 2>&3); then
    if [ -z "$loginUname" ]; then
      msg_error "Login User is mandatory"
      exit
    else
      echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Login User Name: ${COLOR_BRIGHT_GREEN}$loginUname${COLOR_RESET}"
    fi
  else
    exit
  fi
fi

if loginUserID=$(getent passwd "$loginUname" | cut -f 3 -d ":"); then
  if [ -z "$loginUserID" ]; then
    msg_error "Unable to determine User ID of login user on the host"
    exit
  else
    echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Login user ID: ${COLOR_BRIGHT_GREEN}$loginUserID${COLOR_RESET}"
  fi
else
  msg_error "Failed to determine User ID of login user on the host"
  exit
fi

if loginGroupID=$(getent passwd "$loginUname" | cut -f 4 -d ":"); then
  if [ -z "$loginGroupID" ]; then
    msg_error "Unable to determine Group ID of login user on the host"
    exit
  else
    echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Login user group ID: ${COLOR_BRIGHT_GREEN}$loginGroupID${COLOR_RESET}"
  fi
else
  msg_error "Failed to determine group ID of login user on the host"
  exit
fi

while true; do
  if LOGIN_PW1=$(whiptail --backtitle "$whiptailBacktitle" --passwordbox "\nSet Login Password" "$whiptailHeight" "$whiptailWidth" --title "Login password" 3>&1 1>&2 2>&3); then
    if [[ -n "$LOGIN_PW1" ]]; then
      if [[ "$LOGIN_PW1" == *" "* ]]; then
        whiptail --msgbox "Password cannot contain spaces. Please try again." "$whiptailHeight" "$whiptailWidth"
      elif ! validate_password "$LOGIN_PW1" "$test"; then
        whiptail --msgbox "Password must meat the complexity criteria. Please try again." "$whiptailHeight" "$whiptailWidth"
      else
        if LOGIN_PW2=$(whiptail --backtitle "$whiptailBacktitle" --passwordbox "\nVerify Login Password" "$whiptailHeight" "$whiptailWidth" --title "PASSWORD VERIFICATION" 3>&1 1>&2 2>&3); then
          if [[ "$LOGIN_PW1" == "$LOGIN_PW2" ]]; then
            LOGIN_PW="$LOGIN_PW1"
            echo -e "${ICON_PASSWORD}${FORMAT_BOLD}${COLOR_DARK_GREEN}Login Password: ${COLOR_BRIGHT_GREEN}********${COLOR_RESET}"
            break
          else
            whiptail --msgbox "Passwords do not match. Please try again." "$whiptailHeight" "$whiptailWidth"
          fi
        else
          exit_script
        fi
      fi
    fi
  else
    exit_script
  fi
done



# Test if ID is in use
if status "$containerId" &>/dev/null; then
  echo -e "ID '$containerId' does not exist."
  unset containerId
  msg_error "Cannot use ID that is not created"
  exit
fi

if [ -z "$containerMount" ]; then
  if containerMount=$(whiptail --backtitle "$whiptailBacktitle" --inputbox "Set directory to be mounted into container (e.g. /data/homebridge or /data/docker/uinifi)" "$whiptailHeight" "$whiptailWidth" --title "Mount folder" 3>&1 1>&2 2>&3); then
    
    if [ -z "$containerMount" ]; then
      msg_error "Data loss may happen, data should be stored outside container"
      exit
    else
      echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Folder to be mounted into container: ${COLOR_BRIGHT_GREEN}$containerMount${COLOR_RESET}"
    fi
  else
    exit
  fi
fi

if [ -z "$mountpointInContainer" ]; then
  if mountpointInContainer=$(whiptail --backtitle "$whiptailBacktitle" --inputbox "Mount external folder in which path in the container?" "$whiptailHeight" "$whiptailWidth" --title "Mount folder" 3>&1 1>&2 2>&3); then
    
    if [ -z "$mountpointInContainer" ]; then
      msg_error "Mount point in container must be specified"
      exit
    else
      echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Mount point in container: ${COLOR_BRIGHT_GREEN}$mountpointInContainer${COLOR_RESET}"
    fi
  else
    exit
  fi
fi

LXC_CONFIG=/etc/pve/lxc/${containerId}.conf
if [[ $test == true ]]; then
  LXC_CONFIG_TEST="${LXC_CONFIG}.test"
  if [ -d "$LXC_CONFIG_TEST" ]; then
    rm "$LXC_CONFIG_TEST"
  fi 
  cp "$LXC_CONFIG" "$LXC_CONFIG_TEST"
  LXC_CONFIG="$LXC_CONFIG_TEST"
fi

if ! ROOTMAP_UID=$(getent passwd "$rootmapUname" | cut -f 3 -d ":"); then
  adduser "$rootmapUname" --shell /bin/false --disabled-login --system --comment "root in container $containerId" --no-create-home

  ROOTMAP_UID=$(getent passwd "$rootmapUname" | cut -f 3 -d ":")
  if [ -z "$ROOTMAP_UID" ]; then
    msg_error "Unable to determine User ID of rootmap user on the host after creation"
    exit
  fi
else
  if [ -z "$ROOTMAP_UID" ]; then
    msg_error "Rootmap user already exists but unable to determine User ID"
    exit
  fi
fi
ROOTMAP_GID=$(getent passwd "$rootmapUname" | cut -f 4 -d ":")
if [ -z "$ROOTMAP_GID" ]; then
  msg_error "Unable to determine Group ID of rootmap user on the host after creation"
  exit
fi

# Create mount folder for compose-project in /data/docker
if [ ! -d "$containerMount" ]; then
  mkdir "$containerMount"
fi
chown -c "$rootmapUname":"$loginUname" -R "$containerMount"

# Map the external folder into the container
msg_progress "Mapping external folder into container"
if ! pct set "$containerId" -mp0 "$containerMount,mp=$mountpointInContainer"; then
  msg_error "Failed to map folder into container"
  exit
else
  msg_ok "Successfully mapped folder into container"
fi

#cat << EOF >> /var/lib/lxc/100/config #var-config should be left untouched
#https://forum.proxmox.com/threads/lxc-id-mapping-issue.41181/post-198259
MAP_TO_INVALID_LOWER_UID=$(( loginUserID- 1))
MAP_TO_INVALID_LOWER_GID=$((loginGroupID - 1))
MAP_TO_INVALID_HIGHER_START_UID=$((loginUserID + 1))
MAP_TO_INVALID_HIGHER_START_GID=$((loginGroupID + 1))
MAP_TO_INVALID_HIGHER_CNT_UID=$((65535 - loginUserID))
MAP_TO_INVALID_HIGHER_CNT_GID=$((65535 - loginGroupID))



# Check root mapping and add if needed
map_id 0 "$ROOTMAP_UID" u 1
map_id 0 "$ROOTMAP_GID" g 1
map_id "$loginUserID" "$loginUserID" u 1
map_id "$loginGroupID" "$loginGroupID" g 1
map_id 1 100000 u $MAP_TO_INVALID_LOWER_UID
map_id 1 100000 g $MAP_TO_INVALID_LOWER_GID
map_id $MAP_TO_INVALID_HIGHER_START_UID 10$MAP_TO_INVALID_HIGHER_START_UID u $MAP_TO_INVALID_HIGHER_CNT_UID
map_id $MAP_TO_INVALID_HIGHER_START_UID 10$MAP_TO_INVALID_HIGHER_START_GID g $MAP_TO_INVALID_HIGHER_CNT_GID


SUBUID="/etc/subuid"
if [[ $test == true ]]; then
  SUBUID_TEST="./subuid.test"
  if [ -d "$SUBUID_TEST" ]; then
    rm "$SUBUID_TEST"
  fi 
  cp "$SUBUID" "$SUBUID_TEST"
  SUBUID="$SUBUID_TEST"
fi


SUBGID="/etc/subgid"
if [[ $test == true ]]; then
  SUBGID_TEST="./subgid.test"
  if [ -d "$SUBGID_TEST" ]; then
    rm "$SUBGID_TEST"
  fi 
  cp "$SUBGID" "$SUBGID_TEST"
  SUBGID="$SUBGID_TEST"
fi



#Allow root (executor of lxc) to map a process to a foreign id
if ! grep -Fxq "root:$ROOTMAP_UID:1" "$SUBUID"; then
  echo "root:$ROOTMAP_UID:1" >>"$SUBUID"
fi

if ! grep -Fxq "root:$ROOTMAP_GID:1" "$SUBGID"; then
  echo "root:$ROOTMAP_GID:1" >>"$SUBGID"
fi



#sed -i '/TEXT_TO_BE_REPLACED/c\This line is removed by the admin.' /tmp/foo

if pct status "$containerId" | grep -Fq "stopped"; then
msg_progress "Starting LXC Container"
pct start "$containerId"
msg_ok "Started LXC Container"
else
msg_progress "Rebooting LXC Container"
pct reboot "$containerId"
msg_ok "Rebooted LXC Container"
fi

export CT_LOGIN_UNAME=$loginUname
export CT_loginUserID=$loginUserID
export CT_loginGroupID=$loginGroupID
export CT_LOGIN_PW=$LOGIN_PW
export CT_APPLICATION_TITLE=$applicationTitle


#IN_CONTAINER="set -o nounset
#  $(<"$SCRIPT_DIR/colors_format_icons.func")"
#IN_CONTAINER="$IN_CONTAINER
#  $(<"$SCRIPT_DIR/error_handler.func")
#    activate_err_handler"
#IN_CONTAINER="$IN_CONTAINER
#  $(<"$SCRIPT_DIR"/message_spinner.func)"
#IN_CONTAINER="$IN_CONTAINER
#  $(<"$SCRIPT_DIR"/setup_in_new_container.func)"

#lxc-attach -n "$containerId" -- bash -c "$IN_CONTAINER" param1 "$containerId"
exec_in_lxc "setup_in_new_container.func" "$containerId"
