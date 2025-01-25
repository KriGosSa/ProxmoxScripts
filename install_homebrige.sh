#!/bin/bash
msg_info "Installing Dependencies"
apt-get install -y curl
apt-get install -y sudo
apt-get install -y mc
 apt-get install -y avahi-daemon
 apt-get install -y gnupg2
msg_ok "Installed Dependencies"

msg_info "Setting up Homebridge Repository"
curl -sSf https://repo.homebridge.io/KEY.gpg | gpg --dearmor >/etc/apt/trusted.gpg.d/homebridge.gpg
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/homebridge.gpg] https://repo.homebridge.io stable main' >/etc/apt/sources.list.d/homebridge.list
msg_ok "Set up Homebridge Repository"

msg_info "Installing Homebridge"
 apt update
 apt-get install -y homebridge
msg_ok "Installed Homebridge"