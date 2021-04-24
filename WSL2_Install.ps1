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

function Get-Kernel-Updated () {
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
function Get-WSLExistance ($distro) {
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

function Get-StoreDownloadLink ($distro) {
    # Uses $distro.StoreLink to get $distro.URI
    # Required when URI is not hard-coded
    #### Thanks to MattiasC85 for this excelent method of getting Microsoft Store download URIs ####
    # Source: https://github.com/MattiasC85/Scripts/blob/a1163b97875ed075927438505808622614a9961f/OSD/Download-AppxFromStore.ps1
    $wchttp=[System.Net.WebClient]::new()
    $URI = "https://store.rg-adguard.net/api/GetFiles"
    $myParameters = "type=url&url=$($distro.StoreLink)"
    $wchttp.Headers[[System.Net.HttpRequestHeader]::ContentType]="application/x-www-form-urlencoded"
    $HtmlResult = $wchttp.UploadString($URI, $myParameters)
    $Start=$HtmlResult.IndexOf("<p>The links were successfully received from the Microsoft Store server.</p>")
    if ($Start -eq -1) {
        write-host "Could not get Microsoft Store download URI, please check the StoreURL."
        exit
    }
    $TableEnd=($HtmlResult.LastIndexOf("</table>")+8)
    $SemiCleaned=$HtmlResult.Substring($start,$TableEnd-$start)
    $newHtml=New-Object -ComObject "HTMLFile"
    $src = [System.Text.Encoding]::Unicode.GetBytes($SemiCleaned)
    $newHtml.write($src)
    $ToDownload=$newHtml.getElementsByTagName("a") | Select-Object textContent, href
    $apxLinks = @()
    $ToDownload | Foreach-Object {
        if ($_.textContent -match '.appxbundle') {
            $apxLinks = $_
        }
    }
    $distro.URI = $apxLinks.href
    return $distro
}

function Check-Sideload (){
    # Return $true if sideloading is enabled
    $keyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    $Key = Get-Item -LiteralPath $keyPath
    $sideloadKeys = @("AllowAllTrustedApps", "AllowDevelopmentWithoutDevLicense")
    $return = $true
    function Test-RegProperty ($propertyname){
        if (($Key.GetValue($propertyname, $null)) -ne $null){
            return $true
        } else {
            return $false
        }
    }
    $sideloadKeys | ForEach-Object {
        if (!(Test-RegProperty ($_))){
            $return = $false
        } else {
            if (( (Get-ItemProperty -Path $keyPath -Name $_).$_ ) -ne 1 ){
                $return = $false
            }
        }
    }
    return $return
}
function Enable-Sideload () {
    # Allow sideloading of unsigned appx packages
    $keyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    if (!(Test-Path -Path $keyPath)){
        New-Item -Path $keyPath # In case the entire registry key was accidentally deleted
    }
    $Key = Get-Item -LiteralPath $keyPath
    $sideloadKeys = @("AllowAllTrustedApps", "AllowDevelopmentWithoutDevLicense")
    function Test-RegProperty ($propertyname){
        if (($Key.GetValue($propertyname, $null)) -ne $null){
            return $true
        } else {
            return $false
        }
    }
    $sideloadKeys | ForEach-Object {
        if (!(Test-RegProperty $_)){
            New-ItemProperty -Path $keyPath -Name $_ -Value "1" -PropertyType DWORD -Force | Out-Null
        } else {
            Set-ItemProperty -Path $keyPath -Name $_ -Value "1" -PropertyType DWORD -Force | Out-Null
        }
    }
}

function Select-Distro () {
    # See: https://docs.microsoft.com/en-us/windows/wsl/install-manual
    # You can also use https://store.rg-adguard.net to get Appx links from Windows Store links
    $distrolist = (
        [PSCustomObject]@{
            'Name' = 'Ubuntu 20.04'
            'URI' = 'https://aka.ms/wslubuntu2004'
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
        },
        [PSCustomObject]@{
            'Name' = 'Alpine'
            'StoreLink' = 'https://www.microsoft.com/en-us/p/alpine-wsl/9p804crf0395'
            'URI' = ''
            'AppxName' = 'AlpineWSL'
            'winpe' = 'Alpine.exe'
            'installed' = $false
        },
        [PSCustomObject]@{
            'Name' = 'Fedora Remix for WSL'
            'URI' = 'https://github.com/WhitewaterFoundry/Fedora-Remix-for-WSL/releases/download/31.5.0/Fedora-Remix-for-WSL_31.5.0.0_x64_arm64.appxbundle'
            'AppxName' = 'FedoraRemix'
            'winpe' = 'fedoraremix.exe'
            'installed' = $false
            'sideloadreqd' = $true
        }
        # [PSCustomObject]@{
        #     'Name' = 'Ubuntu 20.04'
        #     'URI' = 'https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64-wsl.rootfs.tar.gz'
        #     'AppxName' = '' # Leave blank for wsl --import install
        #     'winpe' = ''
        #     'installed' = $false
        # }
    )
    $distrolist | ForEach-Object { $_.installed = Get-WSLExistance($_) }
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
    function Import-WSL ($distro) {
        $distroinstall = "$env:LOCALAPPDATA\lxss"
        $wslname = $($distro.Name).Replace(" ", "-")
        $Filename = "$env:temp\" + $wslname + ".rootfs.tar.gz"
        Write-Host(" ...Downloading " + $distro.Name + ".")
        $client = New-Object net.WebClient
        $client.DownloadFile($distro.URI, $Filename)
        if (Test-Path $Filename){
            Write-Host(" ...Importing " + $distro.Name + ".")
            wsl.exe --import $wslname $distroinstall $Filename
        } else {
            Write-Host("ERROR: Cannot install $($distro.Name) missing rootfs.tar.gz package. (Download failed)") -ForegroundColor Red
        }
    }
    function Add-WSLAppx ($distro) {
        $Filename = "$env:temp\" + "$($distro.AppxName).appx"
        $abortInstall = $false
        if (($distro.sideloadreqd -eq $true) -and (!(Check-Sideload))){
            Write-Host ("Sideloading must be turned on in order to install $($distro.Name)")
            $allowEnable = (Read-Host ("Really enable sideloading? [Y/n]")).ToLower()
            if ($allowEnable.Length -gt 1){ $allowEnable = $allowEnable.Substring(0,1) }
            if (!($allowEnable -eq 'n')){
                Write-Host ("Enabling sideloading...")
                Enable-Sideload | Out-Null
            } else {
                $abortInstall = $true
            }
        }
        if ($abortInstall -eq $false) {
            Write-Host(" ...Downloading " + $distro.Name + ".")
            if ($distro.URI.Length -lt 2) {
                $distro = Get-StoreDownloadLink($distro) # Handle dynamic URIs
            }
            $client = New-Object net.WebClient
            $client.DownloadFile($distro.URI, $Filename)
            if (Test-Path $Filename) {
                Write-Host(" ...Beginning " + $distro.Name + " install.")
                Add-AppxPackage -Path $Filename
            } else {
                Write-Host("ERROR: Cannot install $($distro.Name) missing Appx package. (Download failed)") -ForegroundColor Red
            }
            Start-Sleep -Seconds 5
        } else {
            Write-Host("WARNING: Unable to install. Sideloading required, but not enabled.") -ForegroundColor Yellow
        }
    }
    if (Get-WSLExistance($distro)) {
        Write-Host(" ...Found an existing " + $distro.Name + " install")
    } else {
        if ($($distro.AppxName).Length -gt 1){
            Add-WSLAppx($distro)
        } else {
            Import-WSL($distro)
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
    if (!(Get-Kernel-Updated)) {
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
        if ($distro.sideloadreqd){
            if (Check-Sideload){
                Start-Process $distro.winpe
            }
        } else {
            Start-Process $distro.winpe
        }
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
