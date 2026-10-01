$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
. (Join-Path $PSScriptRoot 'WallpaperStorage.ps1')
$folder=[IO.Path]::GetFullPath((Join-Path $env:TEMP ('WallpaperStorageTests-'+[guid]::NewGuid().ToString('N'))))
New-Item -ItemType Directory -Path $folder|Out-Null
function Assert($Condition,$Message){if(!$Condition){throw "FAIL: $Message"};Write-Host "PASS: $Message"}
function New-Background($Root,$Age=90){
 $path=Join-Path $Root ('generated_'+[guid]::NewGuid().ToString('N')+'.png')
 Set-Content -LiteralPath $path -Value 'fixture';(Get-Item -LiteralPath $path).LastWriteTime=(Get-Date).AddDays(-$Age)
 return $path
}
function New-Run($Root,$Date,$Background){
 $path=Join-Path $Root ($Date.ToString('yyyyMMdd_HHmmss_fff')+'_wallpaper')
 New-Item -ItemType Directory -Path $path|Out-Null
 $output=Join-Path $path 'monitor_0.png';Set-Content -LiteralPath $output -Value 'fixture'
 @{background=@{path=$Background};outputs=@(@{path=$output})}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $path 'details.json')
 Set-Content -LiteralPath (Join-Path $path 'preview.html') -Value 'fixture'
 foreach($file in Get-ChildItem -LiteralPath $path){$file.LastWriteTime=$Date}
 (Get-Item -LiteralPath $path).LastWriteTime=$Date
 return $path
}
try {
 $runs=@();$backgrounds=@()
 for($i=0;$i -lt 36;$i++){
  $backgrounds+=New-Background $folder
  $date=if($i -eq 35){Get-Date}else{(Get-Date).AddDays(-90+$i)}
  $runs+=New-Run $folder $date $backgrounds[$i]
 }
 $orphan=New-Background $folder
 $fresh=New-Background $folder 1
 $explicit=New-Background $folder
 $unrelated=Join-Path $folder 'holiday.png';Set-Content -LiteralPath $unrelated 'fixture';(Get-Item $unrelated).LastWriteTime=(Get-Date).AddDays(-90)
 foreach($name in @('history.json','previous-wallpapers.json','wallpaper.log','commons-metadata.json')){Set-Content -LiteralPath (Join-Path $folder $name) -Value 'fixture'}
 $result=Remove-OldWallpaperData $folder @((Join-Path $runs[0] 'monitor_0.png'),(Join-Path $runs[1] 'monitor_0.png'),$explicit)
 Assert ($result.removedRuns -eq 4) 'Only runs older than 30 days outside the newest 30 are removed'
 Assert ((Test-Path $runs[0]) -and (Test-Path $runs[1]) -and (Test-Path $backgrounds[0]) -and (Test-Path $backgrounds[1])) 'Active and restore files protect their run folders and source backgrounds'
 Assert (!(Test-Path $runs[2]) -and !(Test-Path $backgrounds[2]) -and !(Test-Path $orphan)) 'Deleted runs release unreferenced old source images'
 Assert ((Test-Path $runs[6]) -and (Test-Path $backgrounds[6]) -and (Test-Path $fresh) -and (Test-Path $explicit)) 'Recent, retained, and explicitly protected source images survive'
 Assert ((Test-Path $unrelated) -and (Test-Path (Join-Path $folder 'history.json')) -and (Test-Path (Join-Path $folder 'wallpaper.log'))) 'Unrelated images, JSON state, and logs are preserved'

 $editedRoot=Join-Path $folder 'edited';New-Item -ItemType Directory $editedRoot|Out-Null
 $editedBackground=New-Background $editedRoot
 $editedRuns=@();for($i=0;$i -lt 31;$i++){$editedRuns+=New-Run $editedRoot (Get-Date).AddDays(-90+$i) $editedBackground}
 $editedOutput=Join-Path $editedRuns[0] 'monitor_0.png'
 Set-Content -LiteralPath $editedOutput -Value 'recently edited'
 (Get-Item -LiteralPath $editedRuns[0]).LastWriteTime=(Get-Date).AddDays(-90)
 $result=Remove-OldWallpaperData $editedRoot
 Assert ((Test-Path $editedOutput) -and (Test-Path $editedBackground) -and $result.removedRuns -eq 0) 'Recently edited output and its background survive even when the run directory is old'

 $unsafe=Join-Path $folder 'unsafe';New-Item -ItemType Directory $unsafe|Out-Null
 $unsafeBackground=New-Background $unsafe
 $unsafeRuns=@();for($i=0;$i -lt 31;$i++){$unsafeRuns+=New-Run $unsafe (Get-Date).AddDays(-90+$i) $unsafeBackground}
 $note=Join-Path $unsafeRuns[0] 'my-notes.txt';Set-Content -LiteralPath $note 'personal'
 $unreferenced=New-Background $unsafe
 $result=Remove-OldWallpaperData $unsafe
 Assert ((Test-Path $note) -and (Test-Path $unreferenced) -and $result.skipped -gt 0) 'Unexpected run content prevents directory removal and fails closed for source cleanup'
 Remove-Item -LiteralPath $note
 Set-Content -LiteralPath (Join-Path $unsafeRuns[0] 'details.json') -Value '{broken'
 $result=Remove-OldWallpaperData $unsafe
 Assert ((Test-Path $unsafeRuns[0]) -and (Test-Path $unreferenced)) 'Unreadable metadata retains both the run and potentially referenced backgrounds'

 $outside=Join-Path $folder 'outside';New-Item -ItemType Directory $outside|Out-Null
 $outsideFile=Join-Path $outside 'precious.txt';Set-Content -LiteralPath $outsideFile 'personal'
 $linkedRoot=Join-Path $folder 'linked-root'
 New-Item -ItemType Junction -Path $linkedRoot -Target $outside|Out-Null
 $result=Remove-OldWallpaperData $linkedRoot
 Assert ((Test-Path $outsideFile) -and !(Test-WallpaperStoragePath $linkedRoot $folder)) 'Linked roots are rejected without traversing their target'
 # Remove junction itself with the nonrecursive .NET API, leaving its target intact.
 [IO.Directory]::Delete($linkedRoot)
 $linkedRun=Join-Path $unsafe '20000101_010101_001_preview'
 New-Item -ItemType Junction -Path $linkedRun -Target $outside|Out-Null
 $result=Remove-OldWallpaperData $unsafe
 Assert ((Test-Path $outsideFile) -and (Test-Path $linkedRun)) 'Linked run directories remain untouched'
 [IO.Directory]::Delete($linkedRun)

 $linkedChild=Join-Path $unsafeRuns[1] 'monitor_1.png'
 New-Item -ItemType Junction -Path $linkedChild -Target $outside|Out-Null
 $result=Remove-OldWallpaperData $unsafe
 Assert ((Test-Path $outsideFile) -and (Test-Path $linkedChild)) 'Reparse points inside a run are rejected without deleting their target'
 [IO.Directory]::Delete($linkedChild)

 $failureRoot=Join-Path $folder 'failure';New-Item -ItemType Directory $failureRoot|Out-Null
 $failureBackground=New-Background $failureRoot
 $failureRuns=@();for($i=0;$i -lt 31;$i++){$failureRuns+=New-Run $failureRoot (Get-Date).AddDays(-90+$i) $failureBackground}
 $script:blockedPath=Join-Path $failureRuns[0] 'monitor_0.png'
 function Remove-Item($LiteralPath,[switch]$Force,$ErrorAction){
  if($LiteralPath -eq $script:blockedPath){throw 'Simulated file in use.'}
  Microsoft.PowerShell.Management\Remove-Item -LiteralPath $LiteralPath -Force:$Force -ErrorAction Stop
 }
 try{$result=Remove-OldWallpaperData $failureRoot}finally{Microsoft.PowerShell.Management\Remove-Item Function:\Remove-Item}
 Assert ($result.skipped -gt 0 -and (Test-Path $script:blockedPath) -and (Test-Path $failureBackground)) 'A removal failure remains nonfatal and preserves the surviving run background'
 $result=Remove-OldWallpaperData ([char]0)
 Assert ($result.skipped -eq 1) 'Invalid paths produce a nonfatal diagnostic rather than throwing'
 Write-Host 'Wallpaper storage tests passed.'
}finally {
 # The fixture path is generated under TEMP and all junctions must be gone first.
 if([IO.Path]::GetDirectoryName($folder) -ne [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')){throw 'Unsafe fixture cleanup root.'}
 $links=@(Get-ChildItem -LiteralPath $folder -Recurse -Force|Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint})
 if(!$links.Count){Remove-Item -LiteralPath $folder -Recurse -Force}
}
