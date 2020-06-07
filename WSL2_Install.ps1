# Install WSL
# This script needs to be run as a priviledged user

Write-Host("Checking for Windows Subsystem for Linux...")
$rebootRequired = $false
if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -ne 'Enabled'){
    Write-Host(" ...Installing Windows Subsystem for Linux.")
    $wslinst = Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux
    if ($wslinst.Restartneeded -eq $true){
        $rebootRequired = $true
    }
} else {
    Write-Host(" ...Windows Subsystem for Linux already installed.")
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
    $kernelUpdate = ((Get-Location).Path) + '\wsl_update_x64.msi'
    (New-Object System.Net.WebClient).DownloadFile($kernelURI, $kernelUpdate)
    Write-Host(" ...Installing WSL2 Kernel Update.")
    msiexec /i $kernelUpdate /qn
    Start-Sleep -Seconds 5
    Write-Host(" ...Cleaning up Kernel Update installer.")
    Remove-Item -Path $kernelUpdate
}
 
function Select-Distro () {
    # See: https://docs.microsoft.com/en-us/windows/wsl/install-manual
    $distrolist = ([PSCustomObject]@{
            'Name' = 'Ubuntu 18.04'
            'URI' = 'https://aka.ms/wsl-ubuntu-1804'
            'AppxName' = 'CanonicalGroupLimited.Ubuntu18.04onWindows'
            'winpe' = 'ubuntu1804.exe'
        }, [PSCustomObject]@{
            'Name' = 'Ubuntu 16.04'
            'URI' = 'https://aka.ms/wsl-ubuntu-1604'
            'AppxName' = 'CanonicalGroupLimited.Ubuntu16.04onWindows'
            'winpe' = 'ubuntu1604.exe'
        }, [PSCustomObject]@{
            'Name' = 'Debian'
            'URI' = 'https://aka.ms/wsl-debian-gnulinux'
            'AppxName' = 'TheDebianProject.DebianGNULinux'
            'winpe' = 'debian.exe'
        }, [PSCustomObject]@{
            'Name' = 'Kali'
            'URI' = 'https://aka.ms/wsl-kali-linux-new'
            'AppxName' = 'KaliLinux'
            'winpe' = 'kali.exe'
        }, [PSCustomObject]@{
            'Name' = 'OpenSUSE Leap 42'
            'URI' = 'https://aka.ms/wsl-opensuse-42'
            'AppxName' = 'openSUSELeap42'
            'winpe' = 'openSUSE-42.exe'
        }, [PSCustomObject]@{
            'Name' = 'SUSE Linux Enterprise Server 12'
            'URI' = 'https://aka.ms/wsl-sles-12'
            'AppxName' = 'SUSELinuxEnterpriseServer12'
            'winpe' = 'SLES-12.exe'
        }
    )
    Write-Host("Choose your Distro")
    Write-Host("Ubuntu 18.04 is currently recommended for Docker on WSL2")
    For ($i = 0; $i -le ($distrolist.Length - 1); $i++){
        Write-Host(($i + 1).ToString() + " " + ($distrolist.Name)[$i])
    }
    $distroChoice = Read-Host '>'
    $choiceNum = 0
    if (($distroChoice.Length -ne 0) -and ($distroChoice -match '^\d+$')){
        if (($distroChoice -gt 0) -and ($distroChoice -le $distrolist.Length)){
            $choiceNum = ($distroChoice - 1)
        }
    }
    $choice = $distrolist[$choiceNum]
    return $choice
}

function Install-Distro ($distro) {
    if ((Get-AppxPackage).Name -Contains $distro.AppxName){
        Write-Host("...Found an existing " + $distro.Name + " install")
    } else {
        $Filename = "$(Split-Path $distro.URI -Leaf).appx"
        $ProgressPreference = 'SilentlyContinue'
        Write-Host(" ...Downloading " + $distro.Name + ".")
        Invoke-WebRequest -Uri $distro.URI -OutFile $Filename -UseBasicParsing
        Write-Host(" ...Beginning " + $distro.Name + " install.")
        Add-AppxPackage -Path $Filename
        Start-Sleep -Seconds 5
    }
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
        Start-Sleep -Seconds 5
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
    Update-Kernel
    Write-Host("Setting WSL2 as the default...")
    wsl --set-default-version 2
    $distro = Select-Distro
    Install-Distro($distro)
    Start-Process $distro.winpe
}
