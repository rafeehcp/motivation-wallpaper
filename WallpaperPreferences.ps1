function Get-WallpaperShowCredits([string]$Folder) {
 $path=Join-Path $Folder 'settings.json'
 if(!(Test-Path -LiteralPath $path)){return $true}
 try {
  $settings=Get-Content -LiteralPath $path -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop
  if($settings -isnot [pscustomobject]){return $true}
  $property=$settings.PSObject.Properties['showCredits']
  if($null -eq $property -or $property.Value -isnot [bool]){return $true}
  return [bool]$property.Value
 }catch{return $true}
}

function Set-WallpaperShowCredits([string]$Folder,[bool]$ShowCredits) {
 New-Item -ItemType Directory -Path $Folder -Force -ErrorAction Stop|Out-Null
 $path=Join-Path $Folder 'settings.json'
 $lock=$null;$temporary=$null
 try {
  $lock=[IO.File]::Open((Join-Path $Folder 'settings.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
  $settings=[ordered]@{}
  if(Test-Path -LiteralPath $path) {
   try {
    $existing=Get-Content -LiteralPath $path -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop
    if($existing -isnot [pscustomobject]){throw 'Expected a JSON object.'}
    foreach($property in $existing.PSObject.Properties){$settings[$property.Name]=$property.Value}
   }catch{throw "Cannot update settings.json because it is not a valid JSON object. Repair or rename it first; the existing file has been preserved."}
  }
  $settings['showCredits']=$ShowCredits
  if(Get-Command Save-Json -CommandType Function -ErrorAction SilentlyContinue){Save-Json $path $settings}
  else {
   $temporary=Join-Path $Folder ('settings.'+[guid]::NewGuid().ToString('N')+'.tmp')
   [IO.File]::WriteAllText($temporary,(ConvertTo-Json -InputObject $settings -Depth 100),(New-Object Text.UTF8Encoding($false)))
   if(Test-Path -LiteralPath $path){[IO.File]::Replace($temporary,$path,"$path.previous")}
   else{[IO.File]::Move($temporary,$path)}
  }
 }finally {
  if($null -ne $lock){$lock.Dispose()}
  if($temporary -and (Test-Path -LiteralPath $temporary)){Remove-Item -LiteralPath $temporary -Force}
 }
}
