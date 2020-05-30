# Install WSL
# This script needs to be run as a priviledged user
#dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
$wslinst = Enable-WindowsOptionalFeature -Online  -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux

# Enable Virtual Machine Platform
#dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
$vmpinst = Enable-WindowsOptionalFeature -Online  -NoRestart -FeatureName VirtualMachinePlatform

# At this point a reboot is probably necessary

function Test-RebootRequired {
    if (($wslinst.RestartNeeded -eq $true) -or ($vmpinst.RestartNeeded -eq $true)) {
        return $true
    } else {
        return $false
    }
}

# Install Latest WSL2 Kernel
function Update-Kernel () {
    $kernelURI = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi'
    $kernelUpdate = ((PWD).Path) + '\wsl_update_x64.msi'
    (New-Object System.Net.WebClient).DownloadFile($kernelURI, $kernelUpdate)
    msiexec /i $kernelUpdate /qn
}

# Install Ubuntu 18.04 LTS
function Install-Ubuntu () {
    $URL = 'https://aka.ms/wsl-ubuntu-1804'
    $Filename = "$(Split-Path $URL -Leaf).appx"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $URL -OutFile $Filename -UseBasicParsing
    Invoke-Item $FileName
}

if (Test-RebootRequired){
    shutdown /t 120 /r /c "Reboot required to finish installing WSL2"
    $cancelReboot = Read-Host 'Cancel reboot for now (you still need to reboot and rerun to finish installing WSL2) [y/N]'
    if ($cancelReboot.Substring(0,1).ToLower() -eq 'y'){
        shutdown /a
    }
} else {
    Update-Kernel
    Start-Sleep -Seconds 200
    Install-Ubuntu
    wsl --set-default-version 2 # Set WSL2 as the default
}
