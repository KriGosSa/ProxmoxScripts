
if ! LOGIN_GID_EXISTS=$(getent group "$CT_LOGIN_UNAME" ); then
  groupadd --gid "$CT_LOGIN_GID" "$CT_LOGIN_UNAME"
fi 
  
if ! ( useradd -m "$CT_LOGIN_UNAME" -u "$CT_LOGIN_UID" -g "$CT_LOGIN_GID" -G sudo -c "$CT_LOGIN_UNAME" ); then
msg_error "Failed to create login user in container"
fi

echo "$CT_LOGIN_UNAME:$CT_LOGIN_PW" | chpasswd




# This function sets up the Container OS by generating the locale, setting the timezone, and checking the network connection

  msg_info "Setting up Container OS"
  for ((i = RETRY_NUM; i > 0; i--)); do
    if [ "$(hostname -I)" != "" ]; then
      break
    fi
    echo 1>&2 -en "${CROSS}${RD} No Network! "
    sleep $RETRY_EVERY
  done
  if [ "$(hostname -I)" = "" ]; then
    echo 1>&2 -e "\n${CROSS}${RD} No Network After $RETRY_NUM Tries${CL}"
    echo -e "${NETWORK}Check Network Settings"
    exit 1
  fi
  rm -rf /usr/lib/python3.*/EXTERNALLY-MANAGED
  systemctl disable -q --now systemd-networkd-wait-online.service
  msg_ok "Set up Container OS"
  msg_ok "Network Connected: ${BL}$(hostname -I)"
exit
# This function checks the network connection by pinging a known IP address and prompts the user to continue if the internet is not connected
  set +e
  trap - ERR
  ipv4_connected=false
  ipv6_connected=false
  sleep 1
# Check IPv4 connectivity to Google, Cloudflare & Quad9 DNS servers.
  if ping -c 1 -W 1 1.1.1.1 &>/dev/null || ping -c 1 -W 1 8.8.8.8 &>/dev/null || ping -c 1 -W 1 9.9.9.9 &>/dev/null; then 
    msg_ok "IPv4 Internet Connected";
    ipv4_connected=true
  else
    msg_error "IPv4 Internet Not Connected";
  fi

# Check IPv6 connectivity to Google, Cloudflare & Quad9 DNS servers.
  if ping6 -c 1 -W 1 2606:4700:4700::1111 &>/dev/null || ping6 -c 1 -W 1 2001:4860:4860::8888 &>/dev/null || ping6 -c 1 -W 1 2620:fe::fe &>/dev/null; then
    msg_ok "IPv6 Internet Connected";
    ipv6_connected=true
  else
    msg_error "IPv6 Internet Not Connected";
  fi

# If both IPv4 and IPv6 checks fail, prompt the user
  if [[ $ipv4_connected == false && $ipv6_connected == false ]]; then
    read -r -p "No Internet detected,would you like to continue anyway? <y/N> " prompt
    if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
      echo -e "${INFO}${RD}Expect Issues Without Internet${CL}"
    else
      echo -e "${NETWORK}Check Network Settings"
      exit 1
    fi
  fi

  RESOLVEDIP=$(getent hosts github.com | awk '{ print $1 }')
  if [[ -z "$RESOLVEDIP" ]]; then msg_error "DNS Lookup Failure"; else msg_ok "DNS Resolved github.com to ${BL}$RESOLVEDIP${CL}"; fi
  set -e
  trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# This function updates the Container OS by running apt-get update and upgrade
  msg_info "Updating Container OS"
   apt-get update
   apt-get -o Dpkg::Options::="--force-confold" -y dist-upgrade
  rm -rf /usr/lib/python3.*/EXTERNALLY-MANAGED
  msg_ok "Updated Container OS"


# This function modifies the message of the day (motd) and SSH settings
  # Set terminal to 256-color mode
  grep -qxF "export TERM='xterm-256color'" /root/.bashrc || echo "export TERM='xterm-256color'" >> /root/.bashrc

  # Get the current private IP address
  IP=$(hostname -I | awk '{print $1}')  # Private IP

  # Get OS information (Debian / Ubuntu)
  if [ -f "/etc/os-release" ]; then
    OS_NAME=$(grep ^NAME /etc/os-release | cut -d= -f2 | tr -d '"')
  elif [ -f "/etc/debian_version" ]; then
    OS_NAME="Debian"
  fi

  # Set MOTD with application info, system details
  MOTD_FILE="/etc/motd"
  if [ -f "$MOTD_FILE" ]; then
    # Start MOTD with application info and link
    echo -e "\n${BOLD}${APPLICATION} LXC Container${CL}" > "$MOTD_FILE"

    # Add system information with icons
    echo -e "${TAB}${OS}${YW} OS: ${GN}${OS_NAME} ${CL}" >> "$MOTD_FILE"
    echo -e "${TAB}${HOSTNAME}${YW} Hostname: ${GN}$(hostname)${CL}" >> "$MOTD_FILE"
    echo -e "${TAB}${INFO}${YW} IP Address: ${GN}${IP}${CL}" >> "$MOTD_FILE"
  else
    echo "MotD file does not exist!" >&2
  fi

  # Disable default MOTD scripts
  chmod -x /etc/update-motd.d/*

msg_info "Cleaning up"
 apt-get -y autoremove
 apt-get -y autoclean
msg_ok "Cleaned"