#!/bin/bash

# Source - https://stackoverflow.com/a
# Posted by tlrobinson, modified by community. See post 'Timeline' for change history
# Retrieved 2025-12-31, License - CC BY-SA 3.0

# get the absolute path of the executable
SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P) && SELF_PATH=$SELF_PATH/$(basename -- "$0")

if [[ -h $SELF_PATH ]]; then
# resolve symlinks
    while [[ -h $SELF_PATH ]]; do
        # 1) cd to directory of the symlink
        # 2) cd to the directory of where the symlink points
        # 3) get the pwd
        # 4) append the basename
        DIR=$(dirname -- "$SELF_PATH")
        SYM=$(readlink "$SELF_PATH")
        SELF_PATH=$(cd "$DIR" && cd "$(dirname -- "$SYM")" && pwd)/$(basename -- "$SYM")
        SCRIPT_PATH=$(cd "$DIR" && cd "$(dirname -- "$SYM")" && pwd)
    done
    
    else

    SCRIPT_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

fi
export pwsh_version=$(pwsh --version)

if [[ -z "$pwsh_version" ]]; then
	echo "Missing Powershell, installing"
	sudo "$SCRIPT_PATH/Install-Pwsh.sh"
else
	pwsh -file "$SCRIPT_PATH/Update-Nextcloud.ps1" -appName talk -Install
fi
