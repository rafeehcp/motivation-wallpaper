[CmdletBinding()]
param([switch]$HideCredits,[switch]$ShowCredits,[string]$DataDirectory="$env:USERPROFILE\Pictures\MotivationalWallpapers")
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WallpaperPreferences.ps1')

function Configure-MotivationWallpaper {
 if($HideCredits -and $ShowCredits){throw 'Choose either -HideCredits or -ShowCredits, not both.'}
 if($HideCredits -or $ShowCredits) {
  Set-WallpaperShowCredits $DataDirectory ([bool]$ShowCredits)
  if($ShowCredits){Write-Output 'Source credits will appear on future wallpapers.'}
  else{Write-Output 'Source credits will be hidden on future wallpapers.'}
  return
 }
 Add-Type -AssemblyName System.Windows.Forms
 $form=New-Object Windows.Forms.Form
 try {
  $form.Text='Wallpaper settings';$form.ClientSize=New-Object Drawing.Size(390,150)
  $form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog'
  $form.MaximizeBox=$false;$form.MinimizeBox=$false
  $checkbox=New-Object Windows.Forms.CheckBox
  $checkbox.Text='Show source credits on wallpapers';$checkbox.AutoSize=$true
  $checkbox.Location=New-Object Drawing.Point(20,20)
  $checkbox.Checked=Get-WallpaperShowCredits $DataDirectory
  $note=New-Object Windows.Forms.Label
  $note.Text='Applies when the next wallpaper is created.';$note.AutoSize=$true
  $note.Location=New-Object Drawing.Point(20,55)
  $save=New-Object Windows.Forms.Button
  $save.Text='Save';$save.Location=New-Object Drawing.Point(205,100)
  $save.DialogResult=[Windows.Forms.DialogResult]::OK
  $cancel=New-Object Windows.Forms.Button
  $cancel.Text='Cancel';$cancel.Location=New-Object Drawing.Point(290,100)
  $cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel
  $form.Controls.AddRange(@($checkbox,$note,$save,$cancel))
  $form.AcceptButton=$save;$form.CancelButton=$cancel
  if($form.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
   Set-WallpaperShowCredits $DataDirectory $checkbox.Checked
   Write-Output 'Wallpaper settings saved. Applies to future wallpapers.'
  }
 }finally{$form.Dispose()}
}
if($MyInvocation.InvocationName -ne '.'){Configure-MotivationWallpaper}
