#!/bin/bash
#$0 returns relative or absolute path to the executed script
#dirname returns relative path to directory, where the $0 script exists
#$( dirname "$0" ) the dirname "$0" command returns relative path to directory of executed script, 
#which is then used as argument for source command 
SCRIPT_DIR=$(dirname "$0")
if [[ -f "$SCRIPT_DIR/new_LXC.sh" ]]; then
    archivedir=$(mktemp -d archive_XXXXXXXXXXX)
    ls | grep -v '^archive' | xargs mv -t "$archivedir"
fi

pushd .. >/dev/null


if [[ -f "./main.tar.gz" ]]; then
    rm main.tar.gz
fi

wget https://github.com/KriGosSa/ProxmoxScripts/archive/refs/heads/main.tar.gz
tar -xvf main.tar.gz
pushd ProxmoxScripts-main/ >/dev/null

chmod +x new_LXC.sh
chmod +x update.sh

popd >/dev/null
popd >/dev/null