# WSL2setup

Quickly get up and running with WSL2 on Windows 10 Build 2004.

## Quickstart

To quickly get up and running with WSL2, open a new PowerShell window as "Admin" and run the following one-liner:

```posh
iex ((New-Object System.Net.WebClient).DownloadString('https://git.io/JfKrM'))
```

You will have to run this one-liner twice.
* Once to install Windows pre-requisites
* Once after the computer re-boots to update the WSL2 kernel and install a WSL distro (Ubuntu 18.04 recommended)

## Prerequisites

You will need to have Windows 10 Build 2004 installed before you can use WSL2. If you do not already have Build 2004 or later installed, you can use [the Windows Update Assistant](https://go.microsoft.com/fwlink/?LinkID=799445) to upgrade to the latest 2004 build.

## Testing

This script is tested and working on bare-metal as well as a Hyper-V VM with nested virtualization turned on.

To turn on nested virtualization on Windows Server 2016+ or Windows 10 you can use the following command:
```posh
(Get-VM).Name # Get a list of VM names
Set-VMProcessor -VMName [TestVMName] -ExposeVirtualizationExtensions $true 
```

WSL2 on a KVM-based VM with nested virtualization, does not appear to work.
