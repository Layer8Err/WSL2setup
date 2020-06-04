# Install WSL
# This script needs to be run as a priviledged user
#dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
Write-Host("Installing/Verifying Windows Subsystem Linux...")
$wslinst = Enable-WindowsOptionalFeature -Online  -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux

# Enable Virtual Machine Platform
#dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
Write-Host("Installing/Verifying Virtual Machine Platform...")
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
    Write-Host("Downloading WSL2 Kernel Update...")
    $kernelURI = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi'
    $kernelUpdate = ((PWD).Path) + '\wsl_update_x64.msi'
    (New-Object System.Net.WebClient).DownloadFile($kernelURI, $kernelUpdate)
    Write-Host("Installing WSL2 Kernel Update...")
    msiexec /i $kernelUpdate /qn
    Start-Sleep -Seconds 200
    Write-Host("Cleaning up Kernel Update installer...")
    Remove-Item -Path $kernelUpdate
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
    #Update-Kernel
    Start-Sleep -Seconds 200
    Write-Host("Installing Ubuntu 18.04 LTS......please follow prompts to complete install.")
    Install-Ubuntu
    Write-Host("Please make sure that Ubuntu 18.04 LTS has been installed from the Windows Store")
    $finishedInstall = Read-Host 'Press ENTER once Ubuntu 18.04 LTS has been installed'
    Write-Host("Setting WSL2 as the default...")
    wsl --set-default-version 2
    Write-Host("Setting Ubuntu-18.04 to use WSL2...")
    Start-Sleep -Seconds 10
    wsl --set-version Ubuntu-18.04 2
}

