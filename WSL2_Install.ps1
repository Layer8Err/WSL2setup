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

# Check for Kernel Update Package
function Kernel-Updated () {
    Write-Host("Checking for Windows Subsystem for Linux Update...")
    $uninstall64 = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object { Get-ItemProperty $_.PSPath } | Select-Object DisplayName, Publisher, DisplayVersion, InstallDate
    if ($uninstall64.DisplayName -contains 'Windows Subsystem for Linux Update') {
        return $true 
    } else {
        return $false
    }
}
 
function Select-Distro () {
    # See: https://docs.microsoft.com/en-us/windows/wsl/install-manual
    $distrolist = (
        [PSCustomObject]@{
            'Name' = 'Ubuntu 20.04'
            'URI' = 'http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/ab88b198-af0e-4ecf-8d35-db6427cc3848?P1=1591927648&P2=402&P3=2&P4=JZJPCmzbk5oMnClzjPMkM3%2fS0pE5aaEuBN9S%2fVrLfSOnr4mEN%2bRxL%2fvICC06hiYFDbtaAtqUZ8Ib1PZ%2b6JvkLg%3d%3dc'
            'AppxName' = 'CanonicalGroupLimited.Ubuntu20.04onWindows'
            'winpe' = 'ubuntu2004.exe'
            'installed' = $false
        }, [PSCustomObject]@{
            'Name' = 'Ubuntu 18.04'
            'URI' = 'https://aka.ms/wsl-ubuntu-1804'
            'AppxName' = 'CanonicalGroupLimited.Ubuntu18.04onWindows'
            'winpe' = 'ubuntu1804.exe'
            'installed' = $false
        }, [PSCustomObject]@{
            'Name' = 'Ubuntu 16.04'
            'URI' = 'https://aka.ms/wsl-ubuntu-1604'
            'AppxName' = 'CanonicalGroupLimited.Ubuntu16.04onWindows'
            'winpe' = 'ubuntu1604.exe'
            'installed' = $false
        }, [PSCustomObject]@{
            'Name' = 'Debian'
            'URI' = 'https://aka.ms/wsl-debian-gnulinux'
            'AppxName' = 'TheDebianProject.DebianGNULinux'
            'winpe' = 'debian.exe'
            'installed' = $false
        }, [PSCustomObject]@{
            'Name' = 'Kali'
            'URI' = 'https://aka.ms/wsl-kali-linux-new'
            'AppxName' = 'KaliLinux'
            'winpe' = 'kali.exe'
            'installed' = $false
        }, [PSCustomObject]@{
            'Name' = 'OpenSUSE Leap 42'
            'URI' = 'https://aka.ms/wsl-opensuse-42'
            'AppxName' = 'openSUSELeap42'
            'winpe' = 'openSUSE-42.exe'
            'installed' = $false
        }, [PSCustomObject]@{
            'Name' = 'SUSE Linux Enterprise Server 12'
            'URI' = 'https://aka.ms/wsl-sles-12'
            'AppxName' = 'SUSELinuxEnterpriseServer12'
            'winpe' = 'SLES-12.exe'
            'installed' = $false
        }
    )
    $pkgs = (Get-AppxPackage).Name
    $distrolist | ForEach-Object {
        if ($pkgs -contains $_.AppxName) {
            $_.installed = $true
        }
    }
    Write-Host("+------------------------------------------------+")
    Write-Host("| Choose your Distro                             |")
    Write-Host("| Ubuntu 18.04 is recommended for Docker on WSL2 |")
    Write-Host("+------------------------------------------------+")
    For ($i = 0; $i -le ($distrolist.Length - 1); $i++) {
        $installedTxt = ""
        if (($distrolist.installed)[$i]) {
            $installedTxt = "(Installed)"
        }
        Write-Host(($i + 1).ToString() + " " + ($distrolist.Name)[$i] + " " + $installedTxt)
    }
    $distroChoice = Read-Host '>'
    $choiceNum = 0
    if (($distroChoice.Length -ne 0) -and ($distroChoice -match '^\d+$')) {
        if (($distroChoice -gt 0) -and ($distroChoice -le $distrolist.Length)) {
            $choiceNum = ($distroChoice - 1)
        }
    }
    $choice = $distrolist[$choiceNum]
    return $choice
}

function Install-Distro ($distro) {
    if ((Get-AppxPackage).Name -Contains $distro.AppxName) {
        Write-Host(" ...Found an existing " + $distro.Name + " install")
    } else {
        $Filename = "$($distro.AppxName).appx"
        $ProgressPreference = 'SilentlyContinue'
        Write-Host(" ...Downloading " + $distro.Name + ".")
        Invoke-WebRequest -Uri $distro.URI -OutFile $Filename -UseBasicParsing
        Write-Host(" ...Beginning " + $distro.Name + " install.")
        Add-AppxPackage -Path $Filename
        Start-Sleep -Seconds 5
    }
}

if ($rebootRequired) {
    shutdown /t 120 /r /c "Reboot required to finish installing WSL2"
    $cancelReboot = Read-Host 'Cancel reboot for now (you still need to reboot and rerun to finish installing WSL2) [y/N]'
    if ($cancelReboot.Length -ne 0){
        if ($cancelReboot.Substring(0,1).ToLower() -eq 'y'){
            shutdown /a
        }
    }
} else {
    if (!(Kernel-Updated)) {
        Write-Host(" ...WSL kernel update not installed.")
        Update-Kernel
    } else {
        Write-Host(" ...WSL update already installed.")
    }
    Write-Host("Setting WSL2 as the default...")
    wsl --set-default-version 2
    $distro = Select-Distro
    Install-Distro($distro)
    Start-Process $distro.winpe
}
