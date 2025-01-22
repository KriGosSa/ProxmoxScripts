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
source $SCRIPT_DIR/colors_format_icons.sh
# shellcheck disable=SC1091
source $SCRIPT_DIR/error_handler.sh
# shellcheck disable=SC1091
source $SCRIPT_DIR/message_spinner.sh

CONTAINER_ID=""
ROOTMAP_UNAME=""
LOGIN_UNAME=""
CONTAINER_MOUNT=""

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
  --test | -test)
    TEST=true
    ;;
  *)
    printf "***************************\n"
    printf "* Error: Invalid argument $1.*\n"
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
        echo -e "${CONTAINERID}${BOLD}${DGN}Container ID: ${BGN}$CONTAINER_ID${CL}"
      fi
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
      echo -e "${CONTAINERID}${BOLD}${DGN}Root will be mapoed to host user name: ${BGN}$ROOTMAP_UNAME${CL}"
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
      echo -e "${CONTAINERID}${BOLD}${DGN}Login User Name: ${BGN}$LOGIN_UNAME${CL}"
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
    echo -e "${CONTAINERID}${BOLD}${DGN}Login user ID: ${BGN}$LOGIN_UID${CL}"
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
    echo -e "${CONTAINERID}${BOLD}${DGN}Login user group ID: ${BGN}$LOGIN_GID${CL}"
  fi
else
  msg_error "Failed to determine group ID of login user on the host"
  exit
fi

while true; do
  if LOGIN_PW1=$(whiptail --backtitle "$WHIPTAIL_BACKTITLE" --passwordbox "\nSet Login Password" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH --title "Root password" 3>&1 1>&2 2>&3); then
    if [[ ! -z "$LOGIN_PW1" ]]; then
      if [[ "$LOGIN_PW1" == *" "* ]]; then
        whiptail --msgbox "Password cannot contain spaces. Please try again." $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH
      elif [ ${#LOGIN_PW1} -lt 5 ]; then
        whiptail --msgbox "Password must be at least 5 characters long. Please try again." $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH
      else
        if LOGIN_PW2=$(whiptail --backtitle "$WHIPTAIL_BACKTITLE" --passwordbox "\nVerify Root Password" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH --title "PASSWORD VERIFICATION" 3>&1 1>&2 2>&3); then
          if [[ "$LOGIN_PW1" == "$LOGIN_PW2" ]]; then
            LOGIN_PW="-password $LOGIN_PW1"
            echo -e "${VERIFYPW}${BOLD}${DGN}Login Password: ${BGN}********${CL}"
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
      echo -e "${CONTAINERID}${BOLD}${DGN}Folder to be mounted into container: ${BGN}$CONTAINER_MOUNT${CL}"
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
  adduser $ROOTMAP_UNAME --shell /bin/false --disabled-login --comment "root in container $CONTAINER_ID"

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
  mkdir $CONTAINER_MOUNT
fi
chown -c "$ROOTMAP_UNAME":"$LOGIN_UNAME" -R $CONTAINER_MOUNT

#cat << EOF >> /var/lib/lxc/100/config #var-config should be left untouched
#https://forum.proxmox.com/threads/lxc-id-mapping-issue.41181/post-198259
MAP_TO_INVALID_LOWER_UID=$((LOGIN_UID - 1))
MAP_TO_INVALID_LOWER_GID=$((LOGIN_GID - 1))
MAP_TO_INVALID_HIGHER_START_UID=$((LOGIN_UID + 1))
MAP_TO_INVALID_HIGHER_START_GID=$((LOGIN_GID + 1))
MAP_TO_INVALID_HIGHER_CNT_UID=$((65536 - $LOGIN_UID))
MAP_TO_INVALID_HIGHER_CNT_GID=$((65536 - $LOGIN_GID))
cat <<EOF >>"$LXC_CONFIG"
lxc.idmap: u 0 $ROOTMAP_UID 1
lxc.idmap: g 0 $ROOTMAP_GID 1
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

if [[ $TEST == true ]]; then
  echo "Testmode. Exiting."
  exit
fi

#sed -i '/TEXT_TO_BE_REPLACED/c\This line is removed by the admin.' /tmp/foo


msg_info "Starting LXC Container"
pct start "$CTID"
msg_ok "Started LXC Container"

lxc-attach -n "$CTID" -- bash -c "$(wget -qLO - https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/$var_install.sh)" || exit

exit #below add steps for docker
#sudo useradd unifi_mongo-express -u 1001 -U --shell /bin/false --disabled-login
#--disabled-login might not work
#-U - group ID as UID >same
#sudo useradd unifi_mongo -u 1002 -U --shell /bin/false

#below goes into container

#useradd -m chris -G sudo
#passwd chris



# Set Description in LXC
#pct set "$CTID" -description "$DESCRIPTION" #Can be HTML
