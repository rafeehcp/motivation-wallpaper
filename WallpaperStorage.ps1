# Conservative retention for artifacts owned by this tool. Never follows links.
function Test-WallpaperStoragePath($Path,$Root) {
 $full=[IO.Path]::GetFullPath($Path).TrimEnd('\')
 if($Root){$base=[IO.Path]::GetFullPath($Root).TrimEnd('\');if(!$full.StartsWith($base+'\',[StringComparison]::OrdinalIgnoreCase)){return $false}}
 $current=$full
 while($current){
  if(Test-Path -LiteralPath $current){$item=Get-Item -LiteralPath $current -Force -ErrorAction Stop;if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){return $false}}
  $parent=[IO.Path]::GetDirectoryName($current);if($parent -eq $current){break};$current=$parent
 }
 return $true
}
function Read-WallpaperStorageRun($Directory,$Root) {
 if(!(Test-WallpaperStoragePath $Directory.FullName $Root)){throw 'Linked run directory.'}
 $files=@(Get-ChildItem -LiteralPath $Directory.FullName -Force -ErrorAction Stop)
 if(!$files.Count){throw 'Missing run metadata.'}
 foreach($file in $files){
  if($file.PSIsContainer -or $file.Name -notmatch '^(?:details\.json(?:\.previous)?|preview\.html|monitor_\d+\.png)$' -or !(Test-WallpaperStoragePath $file.FullName $Directory.FullName)){throw 'Unexpected run content.'}
 }
 $detailsPath=Join-Path $Directory.FullName 'details.json'
 $details=Get-Content -LiteralPath $detailsPath -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop
 if(!$details.PSObject.Properties['background'] -or !$details.background.PSObject.Properties['path'] -or !([string]$details.background.path) -or !$details.PSObject.Properties['outputs'] -or !@($details.outputs).Count){throw 'Incomplete run metadata.'}
 foreach($output in @($details.outputs)){
  if(!$output.PSObject.Properties['path']){throw 'Missing output path.'}
  $outputPath=[IO.Path]::GetFullPath([string]$output.path)
  if([IO.Path]::GetDirectoryName($outputPath) -ne $Directory.FullName -or [IO.Path]::GetFileName($outputPath) -notmatch '^monitor_\d+\.png$' -or !(Test-Path -LiteralPath $outputPath -PathType Leaf)){throw 'Invalid output path.'}
 }
 return @{directory=$Directory;files=$files;background=[IO.Path]::GetFullPath([string]$details.background.path)}
}
function Remove-OldWallpaperData($Folder,$ProtectedPaths=@()) {
 $result=@{removedRuns=0;removedBackgrounds=0;skipped=0}
 try {
  $root=[IO.Path]::GetFullPath($Folder).TrimEnd('\')
  if(!(Test-Path -LiteralPath $root -PathType Container) -or !(Test-WallpaperStoragePath $root $null)){return $result}
  $protected=@{}
  foreach($path in @($ProtectedPaths)){if($path){$protected[[IO.Path]::GetFullPath([string]$path).TrimEnd('\')]=$true}}
  $cutoff=(Get-Date).AddDays(-30)
  $children=@(Get-ChildItem -LiteralPath $root -Force -ErrorAction Stop)
  $runs=@($children|Where-Object {$_.PSIsContainer -and $_.Name -match '^\d{8}_\d{6}_\d{3}_(?:preview|wallpaper)$'}|Sort-Object Name -Descending)
  $survivorBackgrounds=@{};$protectAllBackgrounds=$false
  for($index=0;$index -lt $runs.Count;$index++){
   $directory=$runs[$index];$run=$null
   try {
    # Retain recently modified files even when their parent directory's timestamp
    # did not change (for example, an edited wallpaper PNG).
    $created=[datetime]::ParseExact($directory.Name.Substring(0,19),'yyyyMMdd_HHmmss_fff',[Globalization.CultureInfo]::InvariantCulture)
    $run=Read-WallpaperStorageRun $directory $root
    $keep=$index -lt 30 -or $created -ge $cutoff -or $directory.LastWriteTime -ge $cutoff -or @($run.files|Where-Object {$_.LastWriteTime -ge $cutoff}).Count -gt 0
    foreach($path in $protected.Keys){if($path -eq $directory.FullName -or $path.StartsWith($directory.FullName+'\',[StringComparison]::OrdinalIgnoreCase)){$keep=$true}}
    if(!$keep){
     # Revalidate immediately before removal. Remove individual files and the empty
     # directory, never recursively delete a computed path.
     $run=Read-WallpaperStorageRun $directory $root
     foreach($file in $run.files){if(!(Test-WallpaperStoragePath $file.FullName $directory.FullName)){throw 'Run changed during cleanup.'};Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop}
     if(!(Test-WallpaperStoragePath $directory.FullName $root)){throw 'Run changed during cleanup.'}
     # Directory.Delete(false) refuses nonempty directories without PowerShell's
     # interactive recursive-removal confirmation if new files appeared.
     [IO.Directory]::Delete($directory.FullName,$false)
     $result.removedRuns++
    }else{$survivorBackgrounds[$run.background]=$true}
   }catch{
    $result.skipped++;Write-Verbose ('Wallpaper storage skipped a run: '+$_.Exception.Message)
    if($run){$survivorBackgrounds[$run.background]=$true}else{$protectAllBackgrounds=$true}
   }
  }
  if(!$protectAllBackgrounds){
   foreach($file in $children){
    if($file.PSIsContainer -or $file.Name -notmatch '^(?:generated_[a-fA-F0-9]{32}\.png|commons_[a-fA-F0-9]{64}_\d+x\d+\.(?:jpg|png))$' -or $file.LastWriteTime -ge $cutoff -or $protected.ContainsKey($file.FullName) -or $survivorBackgrounds.ContainsKey($file.FullName)){continue}
    try{if(!(Test-WallpaperStoragePath $file.FullName $root)){throw 'Linked background.'};Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop;$result.removedBackgrounds++}
    catch{$result.skipped++;Write-Verbose ('Wallpaper storage skipped a background: '+$_.Exception.Message)}
   }
  }
 }catch{$result.skipped++;Write-Verbose ('Wallpaper storage cleanup skipped: '+$_.Exception.Message)}
 return $result
}
