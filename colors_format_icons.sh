#!/bin/bash
# This function sets various color variables using ANSI escape codes for formatting text in the terminal.
  # Colors
  COLOR_YELLOW=$(echo "\033[33m")
  COLOR_BRIGHT_YELLOW=$(echo "\033[93m")
  COLOR_BLUE=$(echo "\033[36m")
  COLOR_RED=$(echo "\033[01;31m")
  COLOR_BRIGHT_GREEN=$(echo "\033[4;92m")
  COLOR_GREEN=$(echo "\033[1;92m")
  COLOR_DARK_GREEN=$(echo "\033[32m")
  COLOR_ORANGE=$(echo "\033[38;5;214m")

  # Formatting
  COLOR_RESET=$(echo "\033[m")
  FORMAT_UNDERLINE=$(echo "\033[4m")
  FORMAT_BOLD=$(echo "\033[1m")
  BUFFER_CLEAR="\\r\\033[K"
  SPACE_HOLD=" "
  INDENT="  "
  whiptailHeight=12
  whiptailWidth=72

  # Icons
  ICON_CHECKMARK="${INDENT}✔️${INDENT}${COLOR_RESET}"
  ICON_CROSS="${INDENT}✖️${INDENT}${COLOR_RESET}"
  ICON_INFO="${INDENT}💡${INDENT}${COLOR_RESET}"
  ICON_OS="${INDENT}🖥️${INDENT}${COLOR_RESET}"
  ICON_OS_VERSION="${INDENT}🌟${INDENT}${COLOR_RESET}"
  ICON_CONTAINER="${INDENT}📦${INDENT}${COLOR_RESET}"
  ICON_DISK="${INDENT}💾${INDENT}${COLOR_RESET}"
  ICON_CPU="${INDENT}🧠${INDENT}${COLOR_RESET}"
  ICON_RAM="${INDENT}🛠️${INDENT}${COLOR_RESET}"
  ICON_SEARCH="${INDENT}🔍${INDENT}${COLOR_RESET}"
  ICON_PASSWORD="${INDENT}🔐${INDENT}${COLOR_RESET}"
  ICON_CONTAINER_ID="${INDENT}🆔${INDENT}${COLOR_RESET}"
  ICON_HOSTNAME="${INDENT}🏠${INDENT}${COLOR_RESET}"
  ICON_BRIDGE="${INDENT}🌉${INDENT}${COLOR_RESET}"
  ICON_NETWORK="${INDENT}📡${INDENT}${COLOR_RESET}"
  ICON_GATEWAY="${INDENT}🌐${INDENT}${COLOR_RESET}"
  ICON_IPV6_DISABLED="${INDENT}🚫${INDENT}${COLOR_RESET}"
  ICON_DEFAULT="${INDENT}⚙️${INDENT}${COLOR_RESET}"
  ICON_MAC_ADDRESS="${INDENT}🔗${INDENT}${COLOR_RESET}"
  ICON_VLAN="${INDENT}🏷️${INDENT}${COLOR_RESET}"
  ICON_SSH="${INDENT}🔑${INDENT}${COLOR_RESET}"
  ICON_LAUNCH="${INDENT}🚀${INDENT}${COLOR_RESET}"
  ICON_ADVANCED="${INDENT}🧩${INDENT}${COLOR_RESET}"
  ICON_EXCLAMATION="${INDENT}❗${INDENT}${COLOR_RESET}"