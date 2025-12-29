# linux

Bash Scripts and PowerShell to automate the boring stuff when manual stuff irks me enough to do something abotut it.

## Nextcloud

I got tired of having to manually download Nextcloud files and talk clients every time an update was announced. The primary script here is the `ps1` file. The `sh` scripts call `Update-Nextcloud.ps1` with the appropriate command-line parameters to update each respective client.

This was a stream-of-consciousness exercise and so feel free to make them your own by modifying accordingly.

### Update-Files.sh

Checks to see if you have PowerShell and if not, will call `Install-Pwsh.sh` as sudo to install.
Calls `Update-Nextcloud.ps1 -AppName files -Install` to update Nextcloud Files.

### Update-Talk.sh

Checks to see if you have PowerShell and if not, will call `Install-Pwsh.sh` as sudo to install.
Calls `Update-Nextcloud.ps1 -AppName talk -Install` to update Nextcloud Talk.

### Install-Pwsh.sh

The installation method is derived from Microsoft's learn article here: https://learn.microsoft.com/en-us/powershell/scripting/install/install-debian?view=powershell-7.5#installation-on-debian-11-or-12-via-the-package-repository

I run Mint and so I couldn't be bothered to try and programmatically figure out how to map my Mint version to the equivalent Ubuntu LTS distribution; this is why you'll see a static variable defined instead of using `lsb_release` or `/etc/sources` tactics.

### Update-Nextcloud.ps1

Examples:

* `pwsh -file ./Update-Nextcloud.ps1 -appName talk -Install` will update Nextcloud Talk
* `pwsh -file ./Update-Nextcloud.ps1 -appName files -Install` will update Nextcloud Files

**Notes:**

* Talk
  * Terminates running instances of the Talk client (uses `flatpak kill`)
  * Downloads latest client
  * Installs at the user-context
  * Deletes the download before exiting
  * Re-starts the talk client on your behalf

* Files
  * Downloads the latest AppImage from Nextcloud's Github repository
  * Adds executable permission to the AppImage file
  * Adds/Updates Autostart entry
  * Restarts the Files client accordingly
