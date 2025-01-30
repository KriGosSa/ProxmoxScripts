#!/bin/bash
# This function displays a spinner.
SPINNER_PID=""
function spinner() {
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local spin_i=0
  local interval=0.1
  printf "\e[?25l" 

  local color="${COLOR_BRIGHT_YELLOW}"

  while true; do
    printf "\r ${color}%s${COLOR_RESET}" "${frames[spin_i]}"
    spin_i=$(( (spin_i + 1) % ${#frames[@]} ))
    sleep "$interval"
  done
}

# This function displays a prpgress message with a yellow color.
function msg_info() {
  local msg="$1"
  echo -e "${COLOR_YELLOW}${SPACE_HOLD}${msg}${SPACE_HOLD}"
}

# This function displays an informational message with a yellow color.
function msg_progress() {
  local msg="$1"
  echo -ne "${INDENT}${COLOR_YELLOW}${SPACE_HOLD}${msg}${SPACE_HOLD}"
  spinner &
  SPINNER_PID=$!
}

# This function displays a success message with a green color.
function msg_ok() {
  if [ -n "$SPINNER_PID" ] && ps -p "$SPINNER_PID" > /dev/null; then kill "$SPINNER_PID" > /dev/null; fi
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BUFFER_CLEAR}${ICON_CHECKMARK}${COLOR_GREEN}${msg}${COLOR_RESET}"
}

# This function displays a error message with a red color.
function msg_error() {
  if [ -n "$SPINNER_PID" ] && ps -p "$SPINNER_PID" > /dev/null; then kill "$SPINNER_PID" > /dev/null; fi
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BUFFER_CLEAR}${ICON_CROSS}${COLOR_RED}${msg}${COLOR_RESET}"
}