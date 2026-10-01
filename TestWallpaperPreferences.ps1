$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
. (Join-Path $PSScriptRoot 'WallpaperPreferences.ps1')
$testRoot=Join-Path $env:TEMP ('WallpaperPreferencesTests-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot|Out-Null
function Assert($Condition,$Message){if(!$Condition){throw "FAIL: $Message"};Write-Output "PASS: $Message"}
try {
 $path=Join-Path $testRoot 'settings.json'
 Assert (Get-WallpaperShowCredits $testRoot) 'Missing settings show source credits by default'
 Set-WallpaperShowCredits $testRoot $false
 Assert (!(Get-WallpaperShowCredits $testRoot)) 'Hidden credit preference persists as a Boolean'
 $parsed=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
 Assert ($parsed.showCredits -is [bool] -and !$parsed.showCredits) 'Settings JSON stores false without string conversion'
 '{"showCredits":false,"other":{"value":"preserved"}}'|Set-Content -LiteralPath $path
 Set-WallpaperShowCredits $testRoot $true
 $parsed=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
 Assert ((Get-WallpaperShowCredits $testRoot) -and $parsed.other.value -eq 'preserved') 'Toggling credits preserves unrelated settings'
 Assert (Test-Path -LiteralPath "$path.previous") 'Atomic updates retain the previous settings file'
 foreach($invalid in @('{"showCredits":"false"}','[]','null','{broken')) {
  [IO.File]::WriteAllText($path,$invalid)
  Assert (Get-WallpaperShowCredits $testRoot) 'Invalid or absent Boolean preference keeps source credits visible'
 }
 $before=[IO.File]::ReadAllText($path);$rejected=$false
 try{Set-WallpaperShowCredits $testRoot $false}catch{$rejected=$_.Exception.Message -like '*preserved*'}
 Assert ($rejected -and [IO.File]::ReadAllText($path) -ceq $before) 'Malformed settings are rejected without overwriting data'
 Remove-Item -LiteralPath $path
 . (Join-Path $PSScriptRoot 'ConfigureMotivationWallpaper.ps1') -DataDirectory $testRoot -HideCredits -ShowCredits
 $rejected=$false
 try{Configure-MotivationWallpaper}catch{$rejected=$_.Exception.Message -like '*either*'}
 Assert ($rejected -and !(Test-Path -LiteralPath $path)) 'Conflicting options fail before creating settings or opening a dialog'
 $ShowCredits=$false;Configure-MotivationWallpaper|Out-Null
 Assert (!(Get-WallpaperShowCredits $testRoot)) 'Command-line hide option saves the preference without a dialog'
 $HideCredits=$false;$ShowCredits=$true;Configure-MotivationWallpaper|Out-Null
 Assert (Get-WallpaperShowCredits $testRoot) 'Command-line show option restores visible credits'
}finally {
 $resolved=[IO.Path]::GetFullPath($testRoot)
 $temporaryRoot=[IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'
 if($resolved.StartsWith($temporaryRoot,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'WallpaperPreferencesTests-*') {
  Remove-Item -LiteralPath $resolved -Recurse -Force
 }
}
