#!/bin/bash
#make script fail, when expandimg uninitialized variables
set -o nounset

SPINNER_PID=""

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



#Create user on Proxmox Host. Naming convention: All small letters! Capitals not allowed lxc_<<container>>
#_<<compose-project>>_<<container>> for users in docker container
#  Example: lxc_docker_unifi_network_app

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
  
  if ! LOGIN_UID=$(getent passwd "chris" | cut -f 4 -d ":");
#  if [ -z "$LOGIN_UID" ]; then
    msg_error "Unable to determine ID of login user on the host"
    exit
  else
    echo "$LOGIN_UID"
  fi 

while true; do
    if LOGIN_PW1=$(whiptail --backtitle "$WHIPTAIL_BACKTITLE" --passwordbox "\nSet Root Password (login disabled)" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH --title "Root password" 3>&1 1>&2 2>&3); then
      if [[ ! -z "$ROOT_PW1" ]]; then
        if [[ "$ROOT_PW1" == *" "* ]]; then
          whiptail --msgbox "Password cannot contain spaces. Please try again." $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH
        elif [ ${#ROOT_PW1} -lt 5 ]; then
          whiptail --msgbox "Password must be at least 5 characters long. Please try again." $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH
        else
          if ROOT_PW2=$(whiptail --backtitle ""$WHIPTAIL_BACKTITLE"" --passwordbox "\nVerify Root Password" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH --title "PASSWORD VERIFICATION" 3>&1 1>&2 2>&3); then
            if [[ "$ROOT_PW1" == "$ROOT_PW2" ]]; then
              ROOT_PW="-password $ROOT_PW1"
              echo -e "${VERIFYPW}${BOLD}${DGN}Root Password: ${BGN}********${CL}"
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



  SPINNER_PID=""



  

  
  #TEMP_DIR=$(mktemp -d)
  #pushd $TEMP_DIR >/dev/null





# Test if ID is in use
if status "$CONTAINER_ID" &>/dev/null; then
  echo -e "ID '$CONTAINER_ID' does not exist."
  unset CONTAINER_ID
  msg_error "Cannot use ID that is not created"
  exit
fi

  LXC_CONFIG=/etc/pve/lxc/${CONTAINER_ID}.conf

if [[ "$1" == "test" ]]; then
  echo "Testmode. Exiting."
  exit
fi

echo "doppelter boden"
exit

sudo adduser $ROOTMAP_UNAME --shell /bin/false --disabled-login
  Full-Name Example: Network Application in Project Unifi in Docker LXC


Cat /etc/passwd   -> note down user id (first number) and group id (second number)

Create mount folder for compose-project in /data/docker
 sudo chown -c lxc_docker:chris -R unifi

Create mount folders for single containers
sudo chown -c <<container_user>>:chris -R <<folder>>

Lxc_docker_unifi_network_app

sudo chown -c Lxc_docker_unifi_network_app:chris -R network-application 

Allow root (executor of lxc) to map a process to a foreign id
echo "root:<<userid>>:1" >> /etc/subuid 
echo "root:<<groupid>>:1" >> /etc/subgid


sudo useradd unifi_mongo-express -u 1001 -U  --shell /bin/false --disabled-login
--disabled-login might not work 
-U -> same group ID as UID
sudo useradd unifi_mongo -u 1002 -U --shell /bin/false

#cat << EOF >> /var/lib/lxc/100/config #var-config should be left untouched 
#https://forum.proxmox.com/threads/lxc-id-mapping-issue.41181/post-198259
cat << EOF >> "$LXC_CONFIG"
lxc.idmap: u 0 $containerUserNo 1
lxc.idmap: g 0 $containerGroupNo 1
EOF

useradd -m chris -G sudo
passwd chris



  msg_info "Starting LXC Container"
  pct start "$CTID"
  msg_ok "Started LXC Container"

  lxc-attach -n "$CTID" -- bash -c "$(wget -qLO - https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/$var_install.sh)" || exit


  # Set Description in LXC
  pct set "$CTID" -description "$DESCRIPTION" #Can be HTML



 popd >/dev/null