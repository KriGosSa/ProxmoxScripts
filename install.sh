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
source "$SCRIPT_DIR/install.func"

install_script