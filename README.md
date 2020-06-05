# WSL2setup

Quickly get up and running with WSL2 on Windows 10 Build 2004.

## Quickstart

To quickly get up and running with WSL2, open a new PowerShell window as "Admin" and run the following one-liner:

```posh
iex ((New-Object System.Net.WebClient).DownloadString('https://git.io/JfKrM'))
```

You will have to run this one-liner twice.
* Once to install Windows pre-requisites
* Once after the computer re-boots to update the WSL2 kernel and install Ubuntu 18.04 LTS

## Prerequisites

You will need to have Windows 10 Build 2004 installed before you can use WSL2. If you do not already have Build 2004 or later installed, you can use [the Windows Update Assistant](https://go.microsoft.com/fwlink/?LinkID=799445) to upgrade to the latest 2004 build.
