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

function Set-WallpaperPreferences([string]$Folder,[hashtable]$Updates) {
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
  foreach($name in $Updates.Keys){$settings[$name]=$Updates[$name]}
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

function Get-WallpaperQuoteScreening([string]$Folder) {
 $path=Join-Path $Folder 'settings.json'
 if(!(Test-Path -LiteralPath $path)){return 'Basic'}
 try {
  $settings=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json -ErrorAction Stop
  if($settings -isnot [pscustomobject]){return 'Basic'}
  $property=$settings.PSObject.Properties['quoteScreening']
  if($null -ne $property -and $property.Value -is [string] -and $property.Value -in @('Basic','Jev')){return [string]$property.Value}
 }catch{}
 return 'Basic'
}
function Set-WallpaperShowCredits([string]$Folder,[bool]$ShowCredits) {
 Set-WallpaperPreferences $Folder @{showCredits=$ShowCredits}
}
function Set-WallpaperQuoteScreening([string]$Folder,[ValidateSet('Basic','Jev')][string]$QuoteScreening) {
 Set-WallpaperPreferences $Folder @{quoteScreening=$QuoteScreening}
}
function Get-WallpaperBackgroundSource([string]$Folder) {
 $path=Join-Path $Folder 'settings.json'
 if(!(Test-Path -LiteralPath $path)){return 'Commons'}
 try {
  $settings=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json -ErrorAction Stop
  if($settings -isnot [pscustomobject]){return 'Commons'}
  $property=$settings.PSObject.Properties['backgroundSource']
  if($null -ne $property -and $property.Value -is [string] -and $property.Value -in @('Commons','Generated')){return [string]$property.Value}
 }catch{}
 return 'Commons'
}
function Set-WallpaperBackgroundSource([string]$Folder,[ValidateSet('Commons','Generated')][string]$BackgroundSource) {
 Set-WallpaperPreferences $Folder @{backgroundSource=$BackgroundSource}
}
function Set-WallpaperCredentials {
 Add-Type -AssemblyName System.Windows.Forms
 $names=@('TYPESAFE_API_KEY')
 foreach($name in $names) {
  if([Environment]::GetEnvironmentVariable($name,'User')){continue}
  $form=New-Object Windows.Forms.Form
  try {
   $form.Text="Motivation Wallpaper - $name";$form.Width=520;$form.Height=200;$form.StartPosition='CenterScreen'
   $label=New-Object Windows.Forms.Label;$label.Text="Enter $name. Saved in your Windows user environment.";$label.SetBounds(20,20,460,40);$form.Controls.Add($label)
   $box=New-Object Windows.Forms.TextBox;$box.UseSystemPasswordChar=$true;$box.SetBounds(20,65,460,25);$form.Controls.Add($box)
   $save=New-Object Windows.Forms.Button;$save.Text='Save key';$save.SetBounds(360,105,120,30);$save.DialogResult=[Windows.Forms.DialogResult]::OK;$form.Controls.Add($save);$form.AcceptButton=$save
   if($form.ShowDialog() -ne [Windows.Forms.DialogResult]::OK){throw 'Credential setup cancelled.'}
   $value=$box.Text.Trim();if(!$value){throw "No $name entered."}
   [Environment]::SetEnvironmentVariable($name,$value,'User');$box.Clear();$value=$null
  }finally{$form.Dispose()}
 }
}
# Settings shortcuts are owned by an installation when they run its settings launcher.
# Earlier development builds ran the settings script through powershell.exe instead.
function Test-WallpaperShortcutOwner([string]$Path,[string]$SettingsPath) {
 $shell=New-Object -ComObject WScript.Shell
 try {
  $link=$shell.CreateShortcut($Path)
  $launcher=Join-Path ([IO.Path]::GetDirectoryName($SettingsPath)) 'MotivationWallpaperSettings.exe'
  return [string]::Equals([string]$link.TargetPath,$launcher,[StringComparison]::OrdinalIgnoreCase) -or ([string]$link.Arguments).Contains('-File "'+$SettingsPath+'"')
 }finally{[Runtime.InteropServices.Marshal]::ReleaseComObject($shell)|Out-Null}
}
