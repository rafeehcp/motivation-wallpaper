[CmdletBinding()]
param([string]$InstallDirectory="$env:LOCALAPPDATA\MotivationWallpaper",[switch]$NoSchedule,[ValidateSet('','Commons','Generated')][string]$BackgroundSource,[ValidateSet('','Basic','Jev')][string]$QuoteScreening)
$ErrorActionPreference='Stop'

function Get-WallpaperInstallPackage {
 return @{version='0.1.5';url='https://github.com/rafeehcp/motivation-wallpaper/releases/download/v0.1.5/motivation-wallpaper-v0.1.5.zip';sha256='6D8195A1BC31C760D70E8C180E8115D6D1EB1B7885B65E976B945E51880B49B1'}
}
function Invoke-WallpaperReleaseSetup([string]$Path,[hashtable]$Options) {
 $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$Path,'-InstallDirectory',$Options.InstallDirectory)
 if($Options.NoSchedule){$arguments+='-NoSchedule'}
 if($Options.BackgroundSource){$arguments+=@('-BackgroundSource',$Options.BackgroundSource)}
 if($Options.QuoteScreening){$arguments+=@('-QuoteScreening',$Options.QuoteScreening)}
 & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" @arguments
 if($LASTEXITCODE -ne 0){throw "Wallpaper setup failed (exit $LASTEXITCODE)."}
}
function Install-WallpaperRelease {
 if($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSEdition -ne 'Desktop'){throw 'Run this command in Windows PowerShell 5.1 (powershell.exe).'}
 [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
 $package=Get-WallpaperInstallPackage
 $temporaryRoot=[IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'
 $work=[IO.Path]::GetFullPath((Join-Path $temporaryRoot ('MotivationWallpaperInstall-'+[guid]::NewGuid().ToString('N'))))
 if(!$work.StartsWith($temporaryRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Invalid temporary installation directory.'}
 New-Item -ItemType Directory -Path $work|Out-Null
 try {
  Write-Host "Downloading Motivation Wallpaper v$($package.version)..."
  $archive=Join-Path $work 'release.zip'
  Invoke-WebRequest -Uri $package.url -OutFile $archive -UseBasicParsing -TimeoutSec 60
  if((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $package.sha256){throw 'Release checksum does not match. Installation stopped.'}
  $source=Join-Path $work 'release'
  Expand-Archive -LiteralPath $archive -DestinationPath $source
  $setup=Join-Path $source 'SetupMotivationWallpaper.ps1'
  if(!(Test-Path -LiteralPath $setup -PathType Leaf)){throw 'Release does not contain the setup script.'}
  Invoke-WallpaperReleaseSetup $setup @{InstallDirectory=$InstallDirectory;NoSchedule=[bool]$NoSchedule;BackgroundSource=$BackgroundSource;QuoteScreening=$QuoteScreening}
 }finally {
  # Only remove this invocation's verified temporary directory; never the installed app.
  if((Test-Path -LiteralPath $work) -and $work.StartsWith($temporaryRoot,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $work -Leaf) -match '^MotivationWallpaperInstall-[a-f0-9]{32}$') {
   try {
    $items=@(Get-Item -LiteralPath $work)+@(Get-ChildItem -LiteralPath $work -Recurse -Force)
    if(@($items|Where-Object{$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count -eq 0){Remove-Item -LiteralPath $work -Recurse -Force}
   }catch{Write-Verbose "Temporary installer files retained at $work."}
  }
 }
}
if($MyInvocation.InvocationName -ne '.'){Install-WallpaperRelease}
