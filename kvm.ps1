param(
  [parameter(Position=0)]
  [string] $command,
  [switch] $verbosity = $false,
  [alias("g")][switch] $global = $false,
  [alias("p")][switch] $persistent = $false,
  [switch] $x86 = $false,
  [switch] $x64 = $false,
  [switch] $svr50 = $false,
  [switch] $svrc50 = $false,
  [parameter(Position=1, ValueFromRemainingArguments=$true)]
  [string[]]$args=@()
)

$userKrePath = $env:USERPROFILE + "\.kre"
$userKrePackages = $userKrePath + "\packages"
$globalKrePath = $env:ProgramFiles + "\KRE"
$globalKrePackages = $globalKrePath + "\packages"

$scriptPath = $myInvocation.MyCommand.Definition

function Kvm-Help {
@"
K Runtime Environment Version Manager - Build {{BUILD_NUMBER}}

USAGE: kvm <command> [options]

kvm upgrade [-x86][-x64] [-svr50][-svrc50] [-g|-global]
  install latest KRE from feed
  set 'default' alias to installed version
  add KRE bin to user PATH environment variable persistently
  -g|-global        install to machine-wide location

kvm install <semver>|<alias>|<nupkg> [-x86][-x64] [-svr50][-svrc50] [-g|-global]
  install requested KRE from feed
  add KRE bin to path of current command line
  -g|-global        install to machine-wide location

kvm use <semver>|<alias>|none [-x86][-x64] [-svr50][-svrc50] [-p|-persistent] [-g|-global]
  <semver>|<alias>  add KRE bin to path of current command line   
  none              remove KRE bin from path of current command line
  -p|-persistent    add KRE bin to PATH environment variables persistently
  -g|-global        combined with -p to change machine PATH instead of user PATH

kvm list
  list KRE versions installed 

kvm alias
  list KRE aliases which have been defined

kvm alias <alias>
  display value of named alias

kvm alias <alias> <semver> [-x86][-x64] [-svr50][-svrc50]
  set alias to specific version

"@ | Write-Host
}

function Kvm-Global-Setup {
    If (Needs-Elevation)
    {
        $arguments = "& '$scriptPath' setup $(Requested-Switches) -persistent"
        Start-Process "$psHome\powershell.exe" -Verb runAs -ArgumentList $arguments -Wait
        Write-Host "Setup complete"
        Kvm-Help
        break
    }

    $scriptFolder = [System.IO.Path]::GetDirectoryName($scriptPath)

    $kvmBinPath = "$userKrePath\bin"

    Write-Host "Copying file $kvmBinPath\kvm.ps1"
    md $kvmBinPath -Force | Out-Null
    copy "$scriptFolder\kvm.ps1" "$kvmBinPath\kvm.ps1"

    Write-Host "Copying file $kvmBinPath\kvm.cmd"
    copy "$scriptFolder\kvm.cmd" "$kvmBinPath\kvm.cmd"

    Write-Host "Adding $kvmBinPath to process PATH"
    Set-Path (Change-Path $env:Path $kvmBinPath ($kvmBinPath))

    Write-Host "Adding $kvmBinPath to user PATH"
    $userPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
    $userPath = Change-Path $userPath $kvmBinPath ($kvmBinPath)
    [Environment]::SetEnvironmentVariable("Path", $userPath, [System.EnvironmentVariableTarget]::User)

    Write-Host "Adding $globalKrePath;%USERPROFILE%\.kre to process KRE_HOME"
    $envKreHome = $env:KRE_HOME
    $envKreHome = Change-Path $envKreHome "%USERPROFILE%\.kre" ("%USERPROFILE%\.kre")
    $envKreHome = Change-Path $envKreHome $globalKrePath ($globalKrePath)
    $env:KRE_HOME = $envKreHome

    Write-Host "Adding $globalKrePath;%USERPROFILE%\.kre to machine KRE_HOME"
    $machineKreHome = [Environment]::GetEnvironmentVariable("KRE_HOME", [System.EnvironmentVariableTarget]::Machine)
    $machineKreHome = Change-Path $machineKreHome "%USERPROFILE%\.kre" ("%USERPROFILE%\.kre")
    $machineKreHome = Change-Path $machineKreHome $globalKrePath ($globalKrePath)
    [Environment]::SetEnvironmentVariable("KRE_HOME", $machineKreHome, [System.EnvironmentVariableTarget]::Machine)

    Write-Host "Press any key to continue ..."
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
}

function Kvm-Global-Upgrade {
    $persistent = $true
    If (Needs-Elevation) {
        $arguments = "& '$scriptPath' upgrade -global $(Requested-Switches)"
        Start-Process "$psHome\powershell.exe" -Verb runAs -ArgumentList $arguments -Wait
        break
    }
    $version = Kvm-Find-Latest (Requested-Platform "svr50") (Requested-Architecture "x86")
    Kvm-Global-Install $version
    Kvm-Alias-Set "default" $version
}

function Kvm-Upgrade {
    $persistent = $true
    $version = Kvm-Find-Latest (Requested-Platform "svr50") (Requested-Architecture "x86")
    Kvm-Install $version
    Kvm-Alias-Set "default" $version
}

function Kvm-Find-Latest {
param(
    [string] $platform,
    [string] $architecture
)
    Write-Host "Determining latest version"

    $url = "https://www.myget.org/F/aspnetvnext/api/v2/GetUpdates()?packageIds=%27KRE-$platform-$architecture%27&versions=%270.0%27&includePrerelease=true&includeAllVersions=false"

    $wc = New-Object System.Net.WebClient
    $wc.Credentials = new-object System.Net.NetworkCredential("aspnetreadonly", "4d8a2d9c-7b80-4162-9978-47e918c9658c")
    [xml]$xml = $wc.DownloadString($url)

    $version = Select-Xml "//d:Version" -Namespace @{d='http://schemas.microsoft.com/ado/2007/08/dataservices'} $xml 

    return $version
}

function Kvm-Install-Latest {
    Kvm-Install (Kvm-Find-Latest (Requested-Platform "svr50") (Requested-Architecture "x86"))
}

function Do-Kvm-Download {
param(
  [string] $kreFullName,
  [string] $kreFolder
)
    $parts = $kreFullName.Split(".", 2)

    $url = "https://www.myget.org/F/aspnetvnext/api/v2/package/" + $parts[0] + "/" + $parts[1]
    $kreFile = "$kreFolder\$kreFullName.nupkg"

    If (Test-Path $kreFolder) {
      Write-Host "$kreFullName already installed."
      return;
    }

    Write-Host "Downloading" $kreFullName "from https://www.myget.org/F/aspnetvnext/api/v2/"

    md $kreFolder -Force | Out-Null

    $wc = New-Object System.Net.WebClient
    $wc.Credentials = new-object System.Net.NetworkCredential("aspnetreadonly", "4d8a2d9c-7b80-4162-9978-47e918c9658c")
    $wc.DownloadFile($url, $kreFile)

    Do-Kvm-Unpack $kreFile $kreFolder
}

function Do-Kvm-Unpack {
param(
  [string] $kreFile,
  [string] $kreFolder
)
    Write-Host "Installing to" $kreFolder

    [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($kreFile, $kreFolder)

    If (Test-Path ($kreFolder + "\[Content_Types].xml")) {
        Remove-Item ($kreFolder + "\[Content_Types].xml")
    }
    If (Test-Path ($kreFolder + "\_rels\")) {
        Remove-Item ($kreFolder + "\_rels\") -Force -Recurse
    }
    If (Test-Path ($kreFolder + "\package\")) {
        Remove-Item ($kreFolder + "\package\") -Force -Recurse
    }
}

function Kvm-Global-Install {
param(
  [string] $versionOrAlias
)
    If (Needs-Elevation) {
        $arguments = "& '$scriptPath' install -global $versionOrAlias $(Requested-Switches)"
        Start-Process "$psHome\powershell.exe" -Verb runAs -ArgumentList $arguments -Wait
        Kvm-Global-Use $versionOrAlias
        break
    }

    $kreFullName = Requested-VersionOrAlias $versionOrAlias
    $kreFolder = "$globalKrePackages\$kreFullName"
    Do-Kvm-Download $kreFullName $kreFolder
    Kvm-Use $versionOrAlias
}

function Kvm-Install {
param(
  [string] $versionOrAlias
)
    if ($versionOrAlias.EndsWith(".nupkg"))
    {
        $kreFullName = [System.IO.Path]::GetFileNameWithoutExtension($versionOrAlias)
        $kreFolder = "$userKrePackages\$kreFullName"
        $kreFile = "$kreFolder\$kreFullName.nupkg"

        if (Test-Path($kreFolder)) {
          Write-Host "Target folder '$kreFolder' already exists"
        } else {
          md $kreFolder -Force | Out-Null
          copy $versionOrAlias $kreFile
          Do-Kvm-Unpack $kreFile $kreFolder
        }

        $kreBin = "$kreFolder\bin"
        Write-Host "Adding" $kreBin "to process PATH"
        Set-Path (Change-Path $env:Path $kreBin ($globalKrePackages, $userKrePackages))
    }
    else
    {
        $kreFullName = Requested-VersionOrAlias $versionOrAlias

        $kreFolder = "$userKrePackages\$kreFullName"

        Do-Kvm-Download $kreFullName $kreFolder
        Kvm-Use $versionOrAlias
    }
}

function Kvm-List {
  $kreHome = $env:KRE_HOME
  if (!$kreHome) {
    $kreHome = $env:ProgramFiles + "\KRE;%USERPROFILE%\.kre"
  }
  $items = @()
  foreach($portion in $kreHome.Split(';')) {
    $path = [System.Environment]::ExpandEnvironmentVariables($portion)
    if (Test-Path("$path\packages")) {
      $items += Get-ChildItem ("$path\packages\KRE-*") | List-Parts
    }
  }
  $items | Sort-Object Version, Runtime, Architecture | Format-Table -AutoSize -Property @{name="Active";expression={$_.Active};alignment="center"}, "Version", "Runtime", "Architecture", "Location"
}

filter List-Parts {
  $hasBin = Test-Path($_.FullName+"\bin") 
  if (!$hasBin) {
    return
  }
  $active = $false
  foreach($portion in $env:Path.Split(';')) {
    if ($portion.StartsWith($_.FullName)) {
      $active = $true
    }
  }
  $parts1 = $_.Name.Split('.', 2)
  $parts2 = $parts1[0].Split('-', 3)
  return New-Object PSObject -Property @{
    Active = if($active){"*"}else{""}
    Version = $parts1[1]
    Runtime = $parts2[1]
    Architecture = $parts2[2]
    Location = $_.Parent.FullName
  }
}

function Kvm-Global-Use {
param(
  [string] $versionOrAlias
)
    If (Needs-Elevation) {
        $arguments = "& '$scriptPath' use -global $versionOrAlias $(Requested-Switches)"
        if ($persistent) {
          $arguments = $arguments + " -persistent"
        }
        Start-Process "$psHome\powershell.exe" -Verb runAs -ArgumentList $arguments -Wait
        break
    }

    if ($versionOrAlias -eq "none") {
      Write-Host "Removing KRE from process PATH"
      Set-Path (Change-Path $env:Path "" ($globalKrePackages, $userKrePackages))

      if ($persistent) {  
          Write-Host "Removing KRE from machine PATH"
          $machinePath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
          $machinePath = Change-Path $machinePath "" ($globalKrePackages, $userKrePackages)
          [Environment]::SetEnvironmentVariable("Path", $machinePath, [System.EnvironmentVariableTarget]::Machine)
      }
      return;
    }

    $kreFullName = Requested-VersionOrAlias $versionOrAlias

    $kreBin = Locate-KreBinFromFullName $kreFullName
    if ($kreBin -eq $null) {
      Write-Host "Cannot find $kreFullName, do you need to run 'kvm install $versionOrAlias'?"
      return
    } 

    Write-Host "Adding" $kreBin "to process PATH"
    Set-Path (Change-Path $env:Path $kreBin ($globalKrePackages, $userKrePackages))

    if ($persistent) {
        Write-Host "Adding $kreBin to machine PATH"
        $machinePath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
        $machinePath = Change-Path $machinePath $kreBin ($globalKrePackages, $userKrePackages)
        [Environment]::SetEnvironmentVariable("Path", $machinePath, [System.EnvironmentVariableTarget]::Machine)
    }
}

function Kvm-Use {
param(
  [string] $versionOrAlias
)
    if ($versionOrAlias -eq "none") {
      Write-Host "Removing KRE from process PATH"
      Set-Path (Change-Path $env:Path "" ($globalKrePackages, $userKrePackages))

      if ($persistent) {  
          Write-Host "Removing KRE from user PATH"
          $userPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
          $userPath = Change-Path $userPath "" ($globalKrePackages, $userKrePackages)
          [Environment]::SetEnvironmentVariable("Path", $userPath, [System.EnvironmentVariableTarget]::User)
      }
      return;
    }

    $kreFullName = Requested-VersionOrAlias $versionOrAlias

    $kreBin = Locate-KreBinFromFullName $kreFullName
    if ($kreBin -eq $null) {
      Write-Host "Cannot find $kreFullName, do you need to run 'kvm install $versionOrAlias'?"
      return
    } 

    Write-Host "Adding" $kreBin "to process PATH"
    Set-Path (Change-Path $env:Path $kreBin ($globalKrePackages, $userKrePackages))

    if ($persistent) {  
        Write-Host "Adding $kreBin to user PATH"
        $userPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
        $userPath = Change-Path $userPath $kreBin ($globalKrePackages, $userKrePackages)
        [Environment]::SetEnvironmentVariable("Path", $userPath, [System.EnvironmentVariableTarget]::User)
    }
}

function Kvm-Alias-List {
    md ($userKrePath + "\alias\") -Force | Out-Null

    Get-ChildItem ($userKrePath + "\alias\") | Select @{label='Alias';expression={$_.BaseName}}, @{label='Name';expression={Get-Content $_.FullName }} | Format-Table -AutoSize
}

function Kvm-Alias-Get {
param(
  [string] $name
)
    md ($userKrePath + "\alias\") -Force | Out-Null
    Write-Host "Alias '$name' is set to" (Get-Content ($userKrePath + "\alias\" + $name + ".txt"))
}

function Kvm-Alias-Set {
param(
  [string] $name,
  [string] $value
)
    $kreFullName = "KRE-" + (Requested-Platform "svr50") + "-" + (Requested-Architecture "x86") + "." + $value

    Write-Host "Setting alias '$name' to '$kreFullName'"
    md ($userKrePath + "\alias\") -Force | Out-Null
    $kreFullName | Out-File ($userKrePath + "\alias\" + $name + ".txt") ascii
}

function Locate-KreBinFromFullName() {
param(
  [string] $kreFullName
)
  $kreHome = $env:KRE_HOME
  if (!$kreHome) {
    $kreHome = $env:ProgramFiles + ";%USERPROFILE%\.kre"
  }
  foreach($portion in $kreHome.Split(';')) {
    $path = [System.Environment]::ExpandEnvironmentVariables($portion)
    $kreBin = "$path\packages\$kreFullName\bin"
    if (Test-Path "$kreBin") {
      return $kreBin
    }
  }
  return $null
}

function Requested-VersionOrAlias() {
param(
  [string] $versionOrAlias
)
    If (Test-Path ($userKrePath + "\alias\" + $versionOrAlias + ".txt")) {
        $aliasValue = Get-Content ($userKrePath + "\alias\" + $versionOrAlias + ".txt")
        $parts = $aliasValue.Split('.', 2)
        $pkgVersion = $parts[1]
        $parts =$parts[0].Split('-', 3)
        $pkgPlatform = Requested-Platform $parts[1]
        $pkgArchitecture = Requested-Architecture $parts[2]
    } else {
        $pkgVersion = $versionOrAlias
        $pkgPlatform = Requested-Platform "svr50"
        $pkgArchitecture = Requested-Architecture "x86"
    }
    return "KRE-" + $pkgPlatform + "-" + $pkgArchitecture + "." + $pkgVersion
}

function Requested-Platform() {
param(
  [string] $default
)
    if ($svr50 -and $svrc50) {
        Throw "This command cannot accept both -svr50 and -svrc50"
    } 
    if ($svr50) {
        return "svr50"
    }
    if ($svrc50) {
        return "svrc50"
    }
    return $default
}

function Requested-Architecture() {
param(
  [string] $default
)
    if ($x86 -and $x64) {
        Throw "This command cannot accept both -x86 and -x64"
    } 
    if ($x86) {
        return "x86"
    }
    if ($x64) {
        return "x64"
    }
    return $default
}

function Change-Path() {
param(
  [string] $existingPaths,
  [string] $prependPath,
  [string[]] $removePaths
)
    $newPath = $prependPath
    foreach($portion in $existingPaths.Split(';')) {
      $skip = $portion -eq ""
      foreach($removePath in $removePaths) {
        if ($portion.StartsWith($removePath)) {
          $skip = $true
        }      
      }
      if (!$skip) {
        $newPath = $newPath + ";" + $portion
      }
    }
    return $newPath
}

function Set-Path() {
param(
  [string] $newPath
)
  md $userKrePath -Force | Out-Null
  $env:Path = $newPath
@"
SET "PATH=$newPath"
"@ | Out-File ($userKrePath + "\run-once.cmd") ascii
}

function Needs-Elevation() {
    $user = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $elevated = $user.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    return -NOT $elevated
}

function Requested-Switches() {
  $arguments = ""
  if ($x86) {$arguments = "$arguments -x86"}
  if ($x64) {$arguments = "$arguments -x64"}
  if ($svr50) {$arguments = "$arguments -svr50"}
  if ($svrc50) {$arguments = "$arguments -svrc50"}
  return $arguments
}

 try {
   if ($global) {
    switch -wildcard ($command + " " + $args.Count) {
      "setup 0"           {Kvm-Global-Setup}
      "upgrade 0"         {Kvm-Global-Upgrade}
#      "install 0"         {Kvm-Global-Install-Latest}
      "install 1"         {Kvm-Global-Install $args[0]}
#      "list 0"            {Kvm-Global-List}
      "use 1"             {Kvm-Global-Use $args[0]}
      default             {Write-Host 'Unknown command, or global switch not supported'; Kvm-Help;}
    }
   } else {
    switch -wildcard ($command + " " + $args.Count) {
      "setup 0"           {Kvm-Global-Setup}
      "upgrade 0"         {Kvm-Upgrade}
#      "install 0"         {Kvm-Install-Latest}
      "install 1"         {Kvm-Install $args[0]}
      "list 0"            {Kvm-List}
      "use 1"             {Kvm-Use $args[0]}
      "alias 0"           {Kvm-Alias-List}
      "alias 1"           {Kvm-Alias-Get $args[0]}
      "alias 2"           {Kvm-Alias-Set $args[0] $args[1]}
      "help 0"              {Kvm-Help}
      " 0"              {Kvm-Help}
      default             {Write-Host 'Unknown command'; Kvm-Help;}
    }
   }
  }
  catch {
    Write-Host $_ -ForegroundColor Red ;
  }
