$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Install.ps1')
function Assert($Condition,$Message){if(!$Condition){throw "FAIL: $Message"};Write-Output "PASS: $Message"}
$testRoot=Join-Path $env:TEMP ('WallpaperReleaseInstallerTests-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $testRoot|Out-Null
$fixture=Join-Path $testRoot 'fixture';New-Item -ItemType Directory $fixture|Out-Null
'# Fixture setup'|Set-Content (Join-Path $fixture 'SetupMotivationWallpaper.ps1')
$script:archive=Join-Path $testRoot 'valid.zip'
Compress-Archive -Path (Join-Path $fixture '*') -DestinationPath $script:archive
$script:checksum=(Get-FileHash $script:archive -Algorithm SHA256).Hash
$script:setupCalls=0;$script:work='';$script:downloadFails=$false;$script:setupFails=$false
function Get-WallpaperInstallPackage {return @{version='fixture';url='https://example.invalid/release.zip';sha256=$script:checksum}}
function Invoke-WebRequest($Uri,$OutFile,[switch]$UseBasicParsing,$TimeoutSec) {
 $script:work=Split-Path $OutFile -Parent
 if($script:downloadFails){throw 'Fixture download failure'}
 Copy-Item -LiteralPath $script:archive -Destination $OutFile
}
function Invoke-WallpaperReleaseSetup($Path,$Options) {
 $script:setupCalls++;$script:options=$Options
 if(!(Test-Path -LiteralPath $Path)){throw 'Missing extracted setup'}
 if($script:setupFails){throw 'Fixture setup failure'}
}
$InstallDirectory=Join-Path $testRoot 'App with spaces';$NoSchedule=$true;$BackgroundSource='Generated'
Install-WallpaperRelease
Assert ($script:setupCalls -eq 1 -and $script:options.InstallDirectory -eq $InstallDirectory -and $script:options.NoSchedule -and $script:options.BackgroundSource -eq 'Generated' -and !$script:options.QuoteScreening) 'Verified release forwards options and preserves default screening'
Assert (!(Test-Path -LiteralPath $script:work)) 'Successful installation removes its temporary extraction'
$QuoteScreening='Jev';Install-WallpaperRelease
Assert ($script:setupCalls -eq 2 -and $script:options.QuoteScreening -eq 'Jev') 'Explicit Jev option reaches setup'
$script:checksum='0'*64;$failed=$false
try{Install-WallpaperRelease}catch{$failed=$_.Exception.Message -like '*checksum*'}
Assert ($failed -and $script:setupCalls -eq 2 -and !(Test-Path -LiteralPath $script:work)) 'Checksum mismatch prevents execution and cleans temporary files'
$script:checksum=(Get-FileHash $script:archive -Algorithm SHA256).Hash
$script:downloadFails=$true;$failed=$false
try{Install-WallpaperRelease}catch{$failed=$_.Exception.Message -like '*download failure*'}
Assert ($failed -and $script:setupCalls -eq 2 -and !(Test-Path -LiteralPath $script:work)) 'Download failure never invokes setup'
$script:downloadFails=$false;$script:setupFails=$true;$failed=$false
try{Install-WallpaperRelease}catch{$failed=$_.Exception.Message -like '*setup failure*'}
Assert ($failed -and !(Test-Path -LiteralPath $script:work)) 'Setup errors remain visible while temporary files are cleaned'
$script:setupFails=$false
'# Missing setup fixture'|Set-Content (Join-Path $fixture 'other.txt')
$script:archive=Join-Path $testRoot 'missing.zip';Compress-Archive -LiteralPath (Join-Path $fixture 'other.txt') -DestinationPath $script:archive
$script:checksum=(Get-FileHash $script:archive -Algorithm SHA256).Hash;$failed=$false;$before=$script:setupCalls
try{Install-WallpaperRelease}catch{$failed=$_.Exception.Message -like '*setup script*'}
Assert ($failed -and $script:setupCalls -eq $before) 'Incomplete archive rejected before setup'
# The README command pipes the script into iex, where param() declares plain
# variables instead of binding parameters. Run it in a child process so those
# constrained variables cannot leak into this session.
$piped=& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -Command "function Invoke-WebRequest{throw 'Fixture download failure'};try{Get-Content -LiteralPath '$(Join-Path $PSScriptRoot 'Install.ps1')' -Raw|Invoke-Expression}catch{`$_.Exception.Message}" 2>&1|Out-String
Assert ($piped -like '*download failure*') 'Piped iex installation reaches download with default options'
Write-Output "Installer fixtures: $testRoot"
