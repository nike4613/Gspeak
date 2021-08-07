
Set-Location $PSScriptRoot

if (-not (Test-Path .\build -PathType Container)) {
  New-Item .\build -ItemType Container
}

if (-not (Get-Command MSBuild.exe)) {
  # We need to find VS
  if (-not (Get-Command Get-VSSetupInstance)) {
    # We don't have Get-VSSetupInstance to be able to find VS, so need to get it
    if (-not (Test-Path .\build\vssetup -PathType Container)) {
      # VSSetup isn't downloaded
      if ((Read-Host "VSSetup not found; download it? Note that not downloading it means that you either need to`n
      1. manually load it before running the script, or`n
      2. extract a release archive from https://github.com/Microsoft/vssetup.powershell/releases into build\vssetup. [y/n]:") -ne "y") {
        Write-Error "Cannot continue without VSSetup; aborting"
        return 1
      }

      # lets download and extract it
      Invoke-WebRequest "https://github.com/microsoft/vssetup.powershell/releases/download/2.2.16/VSSetup.zip" -OutFile .\build\vssetup.zip
      Expand-Archive .\build\vssetup.zip .\build\vssetup
    }

    Import-Module .\build\vssetup\Microsoft.VisualStudio.Setup.PowerShell.dll
  }

  # find and initialize dev shell
  $vspath = Get-VSSetupInstance -All `
              | Select-VSSetupInstance -Require Microsoft.VisualStudio.Workload.NativeDesktop -Latest `
              | Select-Object -ExpandProperty InstallationPath
  &"$vspath\Common7\Tools\Launch-VSDevShell.ps1"
  Set-Location $PSScriptRoot
}

MSBuild ".\Client Plugin\Gspeak.sln" -p:Configuration=Release -p:Platform=x86
MSBuild ".\Client Plugin\Gspeak.sln" -p:Configuration=Release -p:Platform=x64

if (-not (Test-Path .\build\tsplug -PathType Container)) {
  New-Item .\build\tsplug -ItemType Container
} else {
  Remove-Item -Recursive .\build\tsplug\*
}

New-Item .\build\tsplug\plugins -ItemType Container
Copy-Item .\tsplugin.ini .\build\tsplug\package.ini
Copy-Item '.\Client Plugin\Release\Win32\Gspeak\gspeak_win32.dll' .\build\tsplug\plugins\
Copy-Item '.\Client Plugin\Release\x64\Gspeak\gspeak_win64.dll' .\build\tsplug\plugins\
Compress-Archive .\build\tsplug\* .\build\gspeak.ts3_plugin -Force

if (-not (Get-Command iscc)) {
  Write-Error "Inno Setup compiler not present; can't build installer!"
  return 1
}

iscc /Obuild\ /Qp .\install_bin.iss
