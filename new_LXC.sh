#!/bin/bash
#make script fail, when expandimg uninitialized variables
set -o nounset

#$0 returns relative or absolute path to the executed script
#dirname returns relative path to directory, where the $0 script exists
#$( dirname "$0" ) the dirname "$0" command returns relative path to directory of executed script,
#which is then used as argument for source command
#source loads content of specified file into current shell
SCRIPT_DIR=$(dirname "$0")
# shellcheck disable=SC1091
#source $SCRIPT_DIR/host_functions.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/colors_format_icons.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/error_handler.sh"
activate_err_handler
# shellcheck disable=SC1091
source "$SCRIPT_DIR/message_spinner.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/password_validation.sh"

CONTAINER_ID=""
ROOTMAP_UNAME=""
LOGIN_UNAME=""
CONTAINER_MOUNT=""
APPLICATION_TITLE=""
TEST=false

while [ $# -gt 0 ]; do
  case "$1" in
  --containerid=* | -containerid=*)
    CONTAINER_ID="${1#*=}"
    ;;
  --rootmapuname=* | -rootmapuname=*)
    ROOTMAP_UNAME="${1#*=}"
    ;;
  --loginuname=* | -loginuname=*)
    LOGIN_UNAME="${1#*=}"
    ;;
  --mount=* | -mount=*)
    CONTAINER_MOUNT="${1#*=}"
    ;;
  --apptitle=* | -apptitle=*)
    APPLICATION_TITLE="${1#*=}"
    ;;
  --test | -test)
    TEST=true
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

WHIPTAIL_BACKTITLE="Configure new LXC Container"
WHIPTAIL_HEIGHT=9
WHIPTAIL_WIDTH=58

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
#    if whiptail --backtitle "$WHIPTAIL_BACKTITLE" --defaultno --title "SSH DETECTED" --yesno "It's advisable to utilize the Proxmox shell rather than SSH, as there may be potential complications with variable retrieval. Proceed using SSH?" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH; then
#      whiptail --backtitle "$WHIPTAIL_BACKTITLE" --msgbox --title "Proceed using SSH" "You've chosen to proceed using SSH. If any issues arise, please run the script in the Proxmox shell before creating a repository issue." $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH
#    else
#      clear
#      echo "Exiting due to SSH usage. Please consider using the Proxmox shell."
#      exit
#    fi
#  fi

#Whiptail sends the user's input to stderr, 3>&1 1>&2 2>&3 switched stderr and stdout, so we can retrieve the value
if [ -z "$CONTAINER_ID" ]; then
  if CONTAINER_ID=$(whiptail --backtitle "$WHIPTAIL_BACKTITLE" --inputbox "Set Container ID" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH --title "CONTAINER ID" 3>&1 1>&2 2>&3); then
    if [ -z "$CONTAINER_ID" ]; then
      msg_error "Container ID is mandatory"
      exit
    else
      # Test if ID is valid
      if [ "$CONTAINER_ID" -lt "100" ]; then
        msg_error "ID cannot be less than 100."
        exit
      else
        echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Container ID: ${COLOR_BRIGHT_GREEN}$CONTAINER_ID${COLOR_RESET}"
      fi
    fi
  else
    exit
  fi
fi


if [ -z "$APPLICATION_TITLE" ]; then
  if APPLICATION_TITLE=$(whiptail --backtitle "$WHIPTAIL_BACKTITLE" --inputbox "Set Application Title" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH --title "CONTAINER ID" 3>&1 1>&2 2>&3); then
    if [ -z "$CONTAINER_ID" ]; then
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

if [ -z "$ROOTMAP_UNAME" ]; then
  if ROOTMAP_UNAME=$(whiptail --backtitle "$WHIPTAIL_BACKTITLE" --inputbox "Create user to map container root to (Naming convention: All small letters! Capitals not allowed lxc_<<container>>)" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH --title "Login User" 3>&1 1>&2 2>&3); then
    if [ -z "$ROOTMAP_UNAME" ]; then
      msg_error "Rootmap User is mandatory"
      exit
    else
      echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Root will be mapped to host user name: ${COLOR_BRIGHT_GREEN}$ROOTMAP_UNAME${COLOR_RESET}"
    fi
  else
    exit
  fi
fi

if [ -z "$LOGIN_UNAME" ]; then
  if LOGIN_UNAME=$(whiptail --backtitle "$WHIPTAIL_BACKTITLE" --inputbox "Set login user name (Naming convention: All small letters! Capitals not allowed. E.g. chris)" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH --title "Login User" 3>&1 1>&2 2>&3); then
    if [ -z "$LOGIN_UNAME" ]; then
      msg_error "Login User is mandatory"
      exit
    else
      echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Login User Name: ${COLOR_BRIGHT_GREEN}$LOGIN_UNAME${COLOR_RESET}"
    fi
  else
    exit
  fi
fi

if LOGIN_UID=$(getent passwd "$LOGIN_UNAME" | cut -f 3 -d ":"); then
  if [ -z "$LOGIN_UID" ]; then
    msg_error "Unable to determine User ID of login user on the host"
    exit
  else
    echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Login user ID: ${COLOR_BRIGHT_GREEN}$LOGIN_UID${COLOR_RESET}"
  fi
else
  msg_error "Failed to determine User ID of login user on the host"
  exit
fi

if LOGIN_GID=$(getent passwd "$LOGIN_UNAME" | cut -f 4 -d ":"); then
  if [ -z "$LOGIN_GID" ]; then
    msg_error "Unable to determine Group ID of login user on the host"
    exit
  else
    echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Login user group ID: ${COLOR_BRIGHT_GREEN}$LOGIN_GID${COLOR_RESET}"
  fi
else
  msg_error "Failed to determine group ID of login user on the host"
  exit
fi

while true; do
  if LOGIN_PW1=$(whiptail --backtitle "$WHIPTAIL_BACKTITLE" --passwordbox "\nSet Login Password" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH --title "Login password" 3>&1 1>&2 2>&3); then
    if [[ -n "$LOGIN_PW1" ]]; then
      if [[ "$LOGIN_PW1" == *" "* ]]; then
        whiptail --msgbox "Password cannot contain spaces. Please try again." $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH
      elif ! validate_password "$LOGIN_PW1"; then
        whiptail --msgbox "Password must meat the complexity criteria. Please try again." $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH
      else
        if LOGIN_PW2=$(whiptail --backtitle "$WHIPTAIL_BACKTITLE" --passwordbox "\nVerify Login Password" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH --title "PASSWORD VERIFICATION" 3>&1 1>&2 2>&3); then
          if [[ "$LOGIN_PW1" == "$LOGIN_PW2" ]]; then
            LOGIN_PW="-password $LOGIN_PW1"
            echo -e "${ICON_PASSWORD}${FORMAT_BOLD}${COLOR_DARK_GREEN}Login Password: ${COLOR_BRIGHT_GREEN}********${COLOR_RESET}"
            break
          else
            whiptail --msgbox "Passwords do not match. Please try again." $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH
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
if status "$CONTAINER_ID" &>/dev/null; then
  echo -e "ID '$CONTAINER_ID' does not exist."
  unset CONTAINER_ID
  msg_error "Cannot use ID that is not created"
  exit
fi

if [ -z "$CONTAINER_MOUNT" ]; then
  if CONTAINER_MOUNT=$(whiptail --backtitle "$WHIPTAIL_BACKTITLE" --inputbox "Set directory to be mounted into container" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH --title "Login User" 3>&1 1>&2 2>&3); then
    if [ -z "$CONTAINER_MOUNT" ]; then
      msg_error "Data loss may happen, data should be stored outside container"
      exit
    else
      echo -e "${ICON_CONTAINER_ID}${FORMAT_BOLD}${COLOR_DARK_GREEN}Folder to be mounted into container: ${COLOR_BRIGHT_GREEN}$CONTAINER_MOUNT${COLOR_RESET}"
    fi
  else
    exit
  fi
fi

LXC_CONFIG=/etc/pve/lxc/${CONTAINER_ID}.conf
if [[ $TEST == true ]]; then
  LXC_CONFIG_TEST="${LXC_CONFIG}.test"
  if [ -d "$LXC_CONFIG_TEST" ]; then
    rm "$LXC_CONFIG_TEST"
  fi 
  cp "$LXC_CONFIG" "$LXC_CONFIG_TEST"
  LXC_CONFIG="$LXC_CONFIG_TEST"
fi

if ! ROOTMAP_UID=$(getent passwd "$ROOTMAP_UNAME" | cut -f 3 -d ":"); then
  adduser $ROOTMAP_UNAME --shell /bin/false --disabled-login --system --comment "root in container $CONTAINER_ID" --no-create-home

  ROOTMAP_UID=$(getent passwd "$ROOTMAP_UNAME" | cut -f 3 -d ":")
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
ROOTMAP_GID=$(getent passwd "$ROOTMAP_UNAME" | cut -f 4 -d ":")
if [ -z "$ROOTMAP_GID" ]; then
  msg_error "Unable to determine Group ID of rootmap user on the host after creation"
  exit
fi

# Create mount folder for compose-project in /data/docker
if [ ! -d "$CONTAINER_MOUNT" ]; then
  mkdir "$CONTAINER_MOUNT"
fi
chown -c "$ROOTMAP_UNAME":"$LOGIN_UNAME" -R "$CONTAINER_MOUNT"

#cat << EOF >> /var/lib/lxc/100/config #var-config should be left untouched
#https://forum.proxmox.com/threads/lxc-id-mapping-issue.41181/post-198259
MAP_TO_INVALID_LOWER_UID=$((LOGIN_UID - 1))
MAP_TO_INVALID_LOWER_GID=$((LOGIN_GID - 1))
MAP_TO_INVALID_HIGHER_START_UID=$((LOGIN_UID + 1))
MAP_TO_INVALID_HIGHER_START_GID=$((LOGIN_GID + 1))
MAP_TO_INVALID_HIGHER_CNT_UID=$((65535 - LOGIN_UID))
MAP_TO_INVALID_HIGHER_CNT_GID=$((65535 - LOGIN_GID))

# Function to check and handle ID mappings
check_id_mapping() {
    local map_uid="$1"
    local map_gid="$2"
    local target_uid="$3"
    local target_gid="$4"
    
    local existing_uid=$(grep "^lxc.idmap: u $map_uid" "$LXC_CONFIG" | awk '{print $4}')
    local existing_gid=$(grep "^lxc.idmap: g $map_gid" "$LXC_CONFIG" | awk '{print $4}')

    if [ -n "$existing_uid" ] || [ -n "$existing_gid" ]; then
        if [ "$existing_uid" != "$target_uid" ] || [ "$existing_gid" != "$target_gid" ]; then
            msg_warning "Existing mapping found with different target IDs:"
            [ "$existing_uid" != "$target_uid" ] && echo -e "User ID: Existing=$existing_uid, Intended=$target_uid"
            [ "$existing_gid" != "$target_gid" ] && echo -e "Group ID: Existing=$existing_gid, Intended=$target_gid"
            if ! whiptail --backtitle "$WHIPTAIL_BACKTITLE" --defaultno --title "DIFFERENT MAPPING" --yesno "Do you want to continue with the existing mapping?" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH; then
                msg_error "Aborted due to different mapping"
                exit 1
            fi
        fi
        return 1  # Mapping exists
    fi
    return 0  # No mapping exists
}

# Check root mapping and add if needed
if check_id_mapping 0 0 "$ROOTMAP_UID" "$ROOTMAP_GID"; then
    cat <<EOF >>"$LXC_CONFIG"
lxc.idmap: u 0 $ROOTMAP_UID 1
lxc.idmap: g 0 $ROOTMAP_GID 1
EOF
fi

# Add remaining mappings
cat <<EOF >>"$LXC_CONFIG"
lxc.idmap: u 1 100000 $MAP_TO_INVALID_LOWER_UID
lxc.idmap: g 1 100000 $MAP_TO_INVALID_LOWER_GID
lxc.idmap: u $LOGIN_UID $LOGIN_UID 1
lxc.idmap: g $LOGIN_GID $LOGIN_GID 1
lxc.idmap: u $MAP_TO_INVALID_HIGHER_START_UID 10$MAP_TO_INVALID_HIGHER_START_UID $MAP_TO_INVALID_HIGHER_CNT_UID
lxc.idmap: g $MAP_TO_INVALID_HIGHER_START_UID 10$MAP_TO_INVALID_HIGHER_START_GID $MAP_TO_INVALID_HIGHER_CNT_GID
EOF


SUBUID="/etc/subuid"
if [[ $TEST == true ]]; then
  SUBUID_TEST="./subuid.test"
  if [ -d "$SUBUID_TEST" ]; then
    rm "$SUBUID_TEST"
  fi 
  cp "$SUBUID" "$SUBUID_TEST"
  SUBUID="$SUBUID_TEST"
fi


SUBGID="/etc/subgid"
if [[ $TEST == true ]]; then
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

if pct status 102 | grep -Fq "stopped"; then
msg_progress "Starting LXC Container"
pct start "$CONTAINER_ID"
msg_ok "Started LXC Container"
else
msg_progress "Rebooting LXC Container"
pct reboot "$CONTAINER_ID"
msg_ok "Rebooted LXC Container"
fi

export CT_LOGIN_UNAME=$LOGIN_UNAME
export CT_LOGIN_UID=$LOGIN_UID
export CT_LOGIN_GID=$LOGIN_GID
export CT_LOGIN_PW=$LOGIN_PW
export CT_APPLICATION_TITLE=$APPLICATION_TITLE


#IN_CONTAINER="set -o nounset
#  $(envsubst < "$SCRIPT_DIR/colors_format_icons.sh")"
#IN_CONTAINER="$IN_CONTAINER
#  $(envsubst < "$SCRIPT_DIR/error_handler.sh")"
#IN_CONTAINER+="
#  trap 'error_handler "'$LINENO "$BASH_COMMAND"'"' ERR"
#IN_CONTAINER="$IN_CONTAINER
#  $(envsubst < $SCRIPT_DIR/message_spinner.sh)"
#IN_CONTAINER="$IN_CONTAINER
#  $(envsubst < $SCRIPT_DIR/setup_in_new_container.sh)"

IN_CONTAINER="set -o nounset
  $(<"$SCRIPT_DIR/colors_format_icons.sh")"
IN_CONTAINER="$IN_CONTAINER
  $(<"$SCRIPT_DIR/error_handler.sh")
    activate_err_handler"
#IN_CONTAINER+="
#  trap 'error_handler "'$LINENO "$BASH_COMMAND"'"' ERR"
IN_CONTAINER="$IN_CONTAINER
  $(<$SCRIPT_DIR/message_spinner.sh)"
IN_CONTAINER="$IN_CONTAINER
  $(<$SCRIPT_DIR/setup_in_new_container.sh)"


# lxc-attach -n "$CONTAINER_ID" -- bash -c "$(cat)" param1 "$CONTAINER_ID"
lxc-attach -n "$CONTAINER_ID" -- bash -c "$IN_CONTAINER" param1 "$CONTAINER_ID"

