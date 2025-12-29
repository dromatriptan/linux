#!/bin/bash

export mint_version="24.04"
apt-get update
apt-get install -y wget
wget -q https://packages.microsoft.com/config/ubuntu/$mint_version/packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
apt-get update
apt-get install -y powershell

