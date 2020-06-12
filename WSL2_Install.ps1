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

function Kernel-Updated () {
    # Check for Kernel Update Package
    Write-Host("Checking for Windows Subsystem for Linux Update...")
    $uninstall64 = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object { Get-ItemProperty $_.PSPath } | Select-Object DisplayName, Publisher, DisplayVersion, InstallDate
    if ($uninstall64.DisplayName -contains 'Windows Subsystem for Linux Update') {
        return $true 
    } else {
        return $false
    }
}

$pkgs = (Get-AppxPackage).Name

function Get-WSLlist {
    $wslinstalls = New-Object Collections.Generic.List[String]
    $(wsl -l) | ForEach-Object { if ($_.Length -gt 1){ $wslinstalls.Add($_) } }
    $wslinstalls = $wslinstalls | Where-Object { $_ -ne 'Windows Subsystem for Linux Distributions:' }
    return $wslinstalls
}
function Check-Existance ($distro) {
    # Check for the existence of a distro
    # return Installed as Bool
    $wslImport = $false
    if (($distro.AppxName).Length -eq 0){ $wslImport = $true }
    $installed = $false
    if ( $wslImport -eq $false ){
        if ($pkgs -match $distro.AppxName) {
            $installed = $true
        }
    } else {
        if (Get-WSLlist -contains ($distro.Name).Replace("-", " ")){
            $installed = $true
        }
    }
    return $installed
}
 
function Select-Distro () {
    # See: https://docs.microsoft.com/en-us/windows/wsl/install-manual
    # You can also use fiddler to get URIs...
    # ToDo: Add Alpine: https://www.microsoft.com/en-us/p/alpine-wsl/9p804crf0395
    $distrolist = (
        [PSCustomObject]@{
            'Name' = 'Ubuntu 20.04'
            'URI' = 'http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/ab88b198-af0e-4ecf-8d35-db6427cc3848?P1=1591927648&P2=402&P3=2&P4=JZJPCmzbk5oMnClzjPMkM3%2fS0pE5aaEuBN9S%2fVrLfSOnr4mEN%2bRxL%2fvICC06hiYFDbtaAtqUZ8Ib1PZ%2b6JvkLg%3d%3dc'
            'AppxName' = 'CanonicalGroupLimited.Ubuntu20.04onWindows'
            'winpe' = 'ubuntu2004.exe'
            'installed' = $false
        },
        [PSCustomObject]@{
            'Name' = 'Ubuntu 18.04'
            'URI' = 'https://aka.ms/wsl-ubuntu-1804'
            'AppxName' = 'CanonicalGroupLimited.Ubuntu18.04onWindows'
            'winpe' = 'ubuntu1804.exe'
            'installed' = $false
        },
        [PSCustomObject]@{
            'Name' = 'Ubuntu 16.04'
            'URI' = 'https://aka.ms/wsl-ubuntu-1604'
            'AppxName' = 'CanonicalGroupLimited.Ubuntu16.04onWindows'
            'winpe' = 'ubuntu1604.exe'
            'installed' = $false
        },
        [PSCustomObject]@{
            'Name' = 'Debian'
            'URI' = 'https://aka.ms/wsl-debian-gnulinux'
            'AppxName' = 'TheDebianProject.DebianGNULinux'
            'winpe' = 'debian.exe'
            'installed' = $false
        },
        [PSCustomObject]@{
            'Name' = 'Kali'
            'URI' = 'https://aka.ms/wsl-kali-linux-new'
            'AppxName' = 'KaliLinux'
            'winpe' = 'kali.exe'
            'installed' = $false
        },
        [PSCustomObject]@{
            'Name' = 'OpenSUSE Leap 42'
            'URI' = 'https://aka.ms/wsl-opensuse-42'
            'AppxName' = 'openSUSELeap42'
            'winpe' = 'openSUSE-42.exe'
            'installed' = $false
        },
        [PSCustomObject]@{
            'Name' = 'SUSE Linux Enterprise Server 12'
            'URI' = 'https://aka.ms/wsl-sles-12'
            'AppxName' = 'SUSELinuxEnterpriseServer12'
            'winpe' = 'SLES-12.exe'
            'installed' = $false
        }
        # [PSCustomObject]@{
        #     'Name' = 'Fedora Remix for WSL'
        #     'URI' = 'https://github.com/WhitewaterFoundry/Fedora-Remix-for-WSL/releases/download/31.5.0/Fedora-Remix-for-WSL_31.5.0.0_x64_arm64.appxbundle'
        #     'AppxName' = 'FedoraRemix'
        #     'winpe' = 'fedora.exe'
        #     'installed' = $false
        #     'sideloadreqd' = $true # Sideloading not supported by this script... yet
        # },
        # [PSCustomObject]@{
        #     'Name' = 'Ubuntu 20.04'
        #     'URI' = 'https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64-wsl.rootfs.tar.gz'
        #     'AppxName' = '' # Leave blank for wsl --import install
        #     'winpe' = ''
        #     'installed' = $false
        # }
    )
    $distrolist | ForEach-Object { $_.installed = Check-Existance($_) }
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
    function WSL-Import ($distro) {
        $distroinstall = "$env:LOCALAPPDATA\lxss"
        $wslname = $($distro.Name).Replace(" ", "-")
        $Filename = $wslname + ".rootfs.tar.gz"
        Write-Host(" ...Downloading " + $distro.Name + ".")
        Invoke-WebRequest -Uri $distro.URI -OutFile $Filename -UseBasicParsing
        wsl.exe --import $wslname $distroinstall $Filename
    }
    function WSL-AppxAdd ($distro) {
        # ToDo: Check if sideloading is required
        $Filename = "$($distro.AppxName).appx"
        $ProgressPreference = 'SilentlyContinue'
        Write-Host(" ...Downloading " + $distro.Name + ".")
        Invoke-WebRequest -Uri $distro.URI -OutFile $Filename -UseBasicParsing
        Write-Host(" ...Beginning " + $distro.Name + " install.")
        Add-AppxPackage -Path $Filename
        Start-Sleep -Seconds 5
    }
    if (Check-Existance($distro)) {
        Write-Host(" ...Found an existing " + $distro.Name + " install")
    } else {
        if ($($distro.AppxName).Length -gt 1){
            WSL-AppxAdd($distro)
        } else {
            WSL-Import($distro)
        }
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
    if ($distro.AppxName.Length -gt 1) {
        Start-Process $distro.winpe
    } else {
        $wslselect = ""
        Get-WSLlist | ForEach-Object {
            if ($_ -match $distro.Name){
                $wslselect = $_
            }
        }
        if ($wslselect -ne "") {
            wsl -d $wslselect
        } else {
            Write-Host("Run 'wsl -l' to list WSL Distributions")
            Write-Host("Run 'wsl -d <distroname>' to start WSL Distro")
        }
    }
}
