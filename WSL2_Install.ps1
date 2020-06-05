# Install WSL
# This script needs to be run as a priviledged user

Write-Host("Checking for Windows Subsystem Linux...")
$rebootRequired = $false
if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -ne 'Enabled'){
    Write-Host(" ...Installing Windows Subsystem Linux.")
    $wslinst = Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux
    if ($wslinst.Restartneeded -eq $true){
        $rebootRequired = $true
    }
} else {
    Write-Host(" ...Windows Subsystem Linux already installed.")
}

Write-Host("Checking for Virtual Machine Platform...")
if ((Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State -ne 'Enabled'){
    Write-Host(" ...Installing Virtual Machine Platform.")
    $vmpinst = Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName VirtualMachinePlatform
    if ($vmpinst.RestartNeeded -eq $true){
        $rebootRequired = $true
    }
} else {
    Write-Host(" ...Virtual Machine Platform already installed.")
}

function Update-Kernel () {
    Write-Host("Updating WSL2 kernel component...")
    Write-Host(" ...Downloading WSL2 Kernel Update.")
    $kernelURI = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi'
    $kernelUpdate = ((PWD).Path) + '\wsl_update_x64.msi'
    (New-Object System.Net.WebClient).DownloadFile($kernelURI, $kernelUpdate)
    Write-Host(" ...Installing WSL2 Kernel Update.")
    msiexec /i $kernelUpdate /qn
    Start-Sleep -Seconds 120
    Write-Host(" ...Cleaning up Kernel Update installer.")
    Remove-Item -Path $kernelUpdate
}

# Install Ubuntu 18.04 LTS
function Install-Ubuntu () {
    if ((Get-AppxPackage).Name -contains 'CanonicalGroupLimited.Ubuntu18.04onWindows'){
        Write-Host(" ...Found an existing Ubuntu 18.04 LTS install")
    } else {
        Write-Host("Installing Ubuntu 18.04 LTS...")
        $URL = 'https://aka.ms/wsl-ubuntu-1804'
        $Filename = "$(Split-Path $URL -Leaf).appx"
        $ProgressPreference = 'SilentlyContinue'
        Write-Host(" ...Downloading Ubuntu 18.04 LTS.")
        Invoke-WebRequest -Uri $URL -OutFile $Filename -UseBasicParsing
        #Invoke-Item $FileName # Attempt to open Windows Store for Ubuntu install
        Write-Host(" ...Beginning Ubuntu 18.04 LTS install.")
        Add-AppxPackage -Path $FileName # Attempt to silently install Ubuntu 18.04
        Start-Sleep -Seconds 120
    }
}

if ($rebootRequired){
    shutdown /t 120 /r /c "Reboot required to finish installing WSL2"
    $cancelReboot = Read-Host 'Cancel reboot for now (you still need to reboot and rerun to finish installing WSL2) [y/N]'
    if ($cancelReboot.Length -ne 0){
        if ($cancelReboot.Substring(0,1).ToLower() -eq 'y'){
            shutdown /a
        }
    }
} else {
    Update-Kernel # Reboot is probably needed after Kernel update
    Write-Host("Setting WSL2 as the default...")
    wsl --set-default-version 2
    Install-Ubuntu
    Write-Host("Please make sure that Ubuntu 18.04 LTS has been installed from the Windows Store")
    Write-Host("You will need to launch Ubuntu 18.04 and complete initial setup.")
    $finishedInstall = Read-Host 'Press ENTER once Ubuntu 18.04 LTS has been installed'
    Write-Host("Setting Ubuntu-18.04 to use WSL2...")
    Start-Sleep -Seconds 10
    wsl --set-version Ubuntu-18.04 2
}

