#!/bin/bash

export pwsh_version=$(pwsh --version)

if [[ -z "$pwsh_version" ]]; then
	echo "Missing Powershell, installing"
	sudo ./Install-Pwsh.sh
else
	pwsh -file ./Update-Nextcloud.ps1 -appName files -Install
fi
