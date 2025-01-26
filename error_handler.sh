#!/bin/bash
# This function is called when an error occurs. It receives the exit code, line number, and command that caused the error, and displays an error message.
error_handler() {
  if [ -n "$SPINNER_PID" ] && ps -p "$SPINNER_PID" > /dev/null; then kill "$SPINNER_PID" > /dev/null; fi
  printf "\e[?25h"
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
}

# This function enables error handling in the script by setting options and defining a trap for the ERR signal.
  set -Eeuo pipefail
  trap 'error_handler $LINENO "$BASH_COMMAND"' ERR