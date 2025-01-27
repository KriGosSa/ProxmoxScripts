#!/bin/bash
# This function is called when an error occurs. It receives the exit code, line number, and command that caused the error, and displays an error message.
error_handler() {
  if [ -n "$SPINNER_PID" ] && ps -p "$SPINNER_PID" > /dev/null; then kill "$SPINNER_PID" > /dev/null; fi
  printf "\e[?25h"
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${COLOR_RED}[ERROR]${COLOR_RESET} in line ${COLOR_RED}$line_number${COLOR_RESET}: exit code ${COLOR_RED}$exit_code${COLOR_RESET}: while executing command ${COLOR_YELLOW}$command${COLOR_RESET}"
  echo -e "\n$error_message\n"
}

# This function enables error handling in the script by setting options and defining a trap for the ERR signal.
function activate_err_handler() {
  set -Eeuo pipefail
  trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
} 