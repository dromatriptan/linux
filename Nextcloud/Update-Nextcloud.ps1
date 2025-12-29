param(
    [Parameter(ParametersetName = "Default", Position = 1, Mandatory = $true)]
    [ValidateSet("talk", "files", ignorecase = $true)]
    [Parameter(ParametersetName = "InstallAction", Position = 2)]
    [Parameter(ParametersetName = "UninstallAction", Position = 2)]
    [String]$appName,
    [Parameter(ParametersetName = "InstallAction", Position = 2)]
    [Switch]$Install,
    [Parameter(ParametersetName = "UninstallAction", Position = 2)]
    [Switch]$Uninstall
)
function SearchForApps {
    param([Parameter(Position = 1, Mandatory = $true)][String]$searchTerm)
    [Array]$installations = @()
    $searchResults = flatpak list | Where-Object { $_ -match $searchTerm }
    ForEach ($result in $searchResults) {
        $installations += [PSCustomObject]@{
            name         = ($result -split "\s+")[0]
            id           = ($result -split "\s+")[1]
            version      = ($result -split "\s+")[2]
            branch       = ($result -split "\s+")[3]
            installation = ($result -split "\s+")[4]
        }
    }
    return $installations
}
function UninstallApp {
    param([Parameter(Position = 1, Mandatory = $true)][String]$app)
    
    [bool]$uninstalled = $false

    if ($app -like 'talk') {
        $installations = SearchForApps -searchTerm $app
        if ($installations.Count -eq 0) {
            Write-Host "Could not find any flatpak-based applications by that search term (i.e., $app)"
        }
        foreach ($installation in $installations) {
            Write-Host "vvvvvvvvvvvvvvvvvvvv Application Information vvvvvvvvvvvvvvvvvvvv"
            flatpak info $installation.id
            Write-Host "^^^^^^^^^^^^^^^^^^^^ Application Information ^^^^^^^^^^^^^^^^^^^^"

            Write-Host "Attempting to uninstall, please wait ..."
            flatpak kill com.nextcloud.talk
            flatpak uninstall --assumeyes $installation.id

            $applications = SearchForApp -searchTerm $installation.id
            if ($applications.Count -eq 0) { $uninstalled = $true }
            else { $uninstalled = $false }
        }
    }
    elseif ($app -like 'files') {
        Write-Host "Stopping Nextcloud Files client ..." -NoNewline
        Get-Process | Where-Object -Property CommandLine -match "Nextcloud-" | Sort-Object -Property Id | Select-Object -ExpandProperty Id | ForEach-Object { Stop-Process -id $_ }
        Write-Host "done." -ForegroundColor Green
        Write-Host "Removing Nextcloud Files client from Startup ..." -NoNewline
        $autostarts = Get-ChildItem -Path "${env:HOME}/.config/autostart"
        foreach ($autostart in $autostarts) {
            $content = Get-Content -Path $autostart.FullName | Where-Object { $_ -like "Exec=*Nextcloud*.AppImage*" }
            if ($null -ne $content) {
                Remove-Item -Path $autoStart.FullName -ErrorAction SilentlyContinue -ErrorVariable RemovalError
            }
        }
        if (-not $RemovalError) {
            Write-Host "done." -ForegroundColor Green
            Write-Host "Deleting AppImage files in `"$filePath`" ..." -NoNewline
            $filePath = "${env:HOME}/Nextcloud"
            $files = Get-ChildItem -Path $filePath -Filter "Nextcloud-*.AppImage" -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                Remove-Item -Path $f.FullName -ErrorAction SilentlyContinue -ErrorVariable UninstallError
            }
            if (-not $UninstallError) {
                $uninstalled = $true
                Write-Host "done." -ForegroundColor Green
            } else {
                $uninstalled = $false
                Write-Host "failed." -ForegroundColor Red
            }
        } else {
            $uninstalled = $false
            Write-Host "failed to remove from Startup, exiting."
        }
    }
    return $uninstalled
}
function InstallApp {
    param([Parameter(Position = 1, Mandatory = $true)][String]$app)

    [bool]$installed = $false
    if ($app -like 'talk') {
        $filePath = "${env:HOME}/Downloads"
        $fileName = "Nextcloud.Talk-linux-x64-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').flatpak"
        $requestParams = @{
            Uri           = 'https://github.com/nextcloud-releases/talk-desktop/releases/latest/download/Nextcloud.Talk-linux-x64.flatpak'
            OutFile       = "$filePath/$fileName"
            ErrorAction   = "SilentlyContinue"
            ErrorVariable = "DownloadError"
        }
        Write-Host "Downloading latest Nextcloud Talk to `"$filePath/$fileName`", please wait ..." -NoNewline
        Invoke-WebRequest @requestParams
        if (-not $DownloadError) {
            Write-Host "done." -ForegroundColor Green
            if (Test-Path -Path "$filePath/$fileName" -PathType Leaf) {
                flatpak kill com.nextcloud.talk
                flatpak install --assumeyes --reinstall --user "$filePath/$fileName"
            }
            $applications = SearchForApps -searchTerm $app
            if ($applications.Count -gt 0) {
                $installed = $true
                Write-Host "Cleaning up ..." -NoNewline
                Remove-Item -Path "$filePath/$fileName" -ErrorAction SilentlyContinue -ErrorVariable RemovalError
                if (-not $RemovalError) { Write-Host "done." -ForegroundColor Green } else { Write-Host "failed. Please remove `"$filePath/$fileName`" manually." -ForegroundColor Red }
                Start-Process -FilePath "flatpak" -ArgumentList "run --user com.nextcloud.talk" -PassThru | Out-Null
            }
            else {
                $installed = $false
            }
        }
        else {
            $installed = $false
            Write-Host "failed." -ForegroundColor Red
        }
    }
    elseif ($app -like 'files') {
        Write-Host "Identifying latest Nextcloud files version, please wait ..."
        $filePath = "${env:HOME}/Nextcloud"
        $response = invoke-webrequest -uri "https://api.github.com/repos/nextcloud-releases/desktop/releases/latest" -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $json = ConvertFrom-Json $response.content                                                                  
            $link = $json.assets | Where-Object { $_.content_type -Match "application" -and $_.name -match "AppImage" } | Select-Object -ExpandProperty browser_download_url -ErrorAction SilentlyContinue
            $fileName = $json.assets | Where-Object { $_.content_type -Match "application" -and $_.name -match "AppImage" } | Select-Object -ExpandProperty name -ErrorAction SilentlyContinue
            if ($null -ne $link -and $null -ne $fileName) {
                Write-Host "Found `"$fileName`" at `"$link`", attempting to download ..." -NoNewline
                if (Test-Path -Path "$filePath/$fileName" -PathType Leaf) {
                    Rename-Item -Path "$filePath/$fileName" -NewName $fileName.Replace('AppImage', 'AppImage_archived') -ErrorAction SilentlyContinue
                }
                $requestParams = @{
                    Uri           = $link
                    OutFile       = "$filePath/$fileName"
                    ErrorAction   = "SilentlyContinue"
                    ErrorVariable = "DownloadError"
                }
                Invoke-WebRequest @requestParams
                if (-not $DownloadError) {
                    Write-Host "done." -ForegroundColor Green

                    # Make executable
                    chmod 755 "$filePath/$fileName"

                    Write-Host "Updating Startup Applications Applet ..." -NoNewline
                    # Find the autostart file responsible for Nextcloud Files
                    $autoStartFileName = $null
                    $autostarts = Get-ChildItem -Path "${env:HOME}/.config/autostart"
                    foreach ($autostart in $autostarts) {
                        $content = Get-Content -Path $autostart.FullName | Where-Object { $_ -like "Exec=*Nextcloud*.AppImage*" }
                        if ($null -ne $content) {
                            $autoStartFileName = $autoStart.Name
                            Copy-Item -Path $autoStart.FullName -Destination "${env:HOME}/.config/autostart/$($autoStart.Name.Replace('desktop','desktop_archived'))"
                        }
                    }
                    
                    if ($null -eq $autoStartFileName) {
                        # Create one if we don't find one
                        Write-Host "Nextcloud files client not starting up at logon, creating one now ..." -NoNewline
                        $autoStartFileName = "Nextcloud.desktop"
                        $newContent = "[Desktop Entry]`r`nName=Nextcloud`r`nGenericName=File Synchronizer`r`nExec=`"${env:HOME}/Nextcloud/$fileName`" --background`r`nTerminal=false`r`nIcon=Nextcloud`r`nCategories=Network`r`nType=Application`r`nStartupNotify=false`r`nX-GNOME-Autostart-enabled=true`r`nX-GNOME-Autostart-Delay=10"
                    }
                    else {
                        # Update the one that's already there.
                        Write-Host "Found Nextcloud files startup entry [$autostartFileName], updating ..." -NoNewline
                        [Array]$newContent = @()
                        $currentContent = Get-Content -Path "${env:HOME}/.config/autostart/$autoStartFileName" -ErrorAction SilentlyContinue
                        foreach ($line in $currentContent) {
                            if ($line -match "Exec=") { $newContent += "Exec=`"$filePath/$fileName`" --background" }
                            else { $newContent += $line }
                        }
                    }
                    Out-File -FilePath "${env:HOME}/.config/autostart/$autoStartFileName" -InputObject $newContent -Force -ErrorAction SilentlyContinue -ErrorVariable OverwriteFailed
                    if (-not $OverwriteFailed) {
                        $installed = $true
                        Write-Host "done." -ForegroundColor Green
                        Write-Host "Cleaning up ..." -NoNewline
                        Remove-Item -Path "$filePath/$($fileName.Replace('AppImage', 'AppImage_archived'))" -ErrorAction SilentlyContinue -ErrorVariable RemovalError
                        Remove-Item -Path "${env:HOME}/.config/autostart/$($autoStartFileName.Replace('desktop','desktop_archived'))" -ErrorAction SilentlyContinue -ErrorVariable RemovalError
                        if (-not $RemovalError) {
                            Write-Host "done." -ForegroundColor Green
                        }
                        else {
                            Write-Host "failed. Please remove the following files manually:"
                            Write-Host "* `t${env:HOME}/.config/autostart/$($autoStartFileName.Replace('desktop','desktop_archived'))"
                            Write-Host "* `t$filePath/$($fileName.Replace('AppImage', 'AppImage_archived'))"
                        }
                        Get-Process | Where-Object -Property CommandLine -match "Nextcloud-" | Sort-Object -Property Id | Select-Object -ExpandProperty Id | ForEach-Object { Stop-Process -id $_ }
                        Start-Process -FilePath "$filePath/$fileName" -PassThru | Out-Null
                    }
                    else {
                        $installed = $false
                        Write-Host "failed to update Autostart, exiting." -ForegroundColor Red
                    }
                }
                else {
                    $installed = $false
                    Write-Host "Failed to download, exiting." -ForegroundColor Red
                }
            }
            else {
                $installed = $false
                Write-Host "Failed to identify latest version, exiting." -ForegroundColor Red
            }
        }
        else {
            $installed = $false
            Write-Host "Communication with Github failed, exiting." -ForegroundColor Red
        }
    }
    return $installed
}

if ($Uninstall) {
    $uninstalled = UninstallApp -app $appName
    if ($uninstalled) { Write-Host "Uninstall succeeded." -ForegroundColor Green } else { Write-Host "Uninstall failed." -ForegroundColor Red }
}
elseif ($Install) {
    $installed = InstallApp -app $appName
    if ($installed) { Write-Host "Installation succeeded." -ForegroundColor Green } else { Write-Host "Installation failed." -ForegroundColor Red }
}