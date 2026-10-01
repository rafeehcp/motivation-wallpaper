[CmdletBinding()]
param([switch]$HideCredits,[switch]$ShowCredits,[ValidateSet('Basic','Jev')][string]$QuoteScreening,[string]$DataDirectory="$env:USERPROFILE\Pictures\MotivationalWallpapers")
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WallpaperPreferences.ps1')

function Configure-MotivationWallpaper {
 if($HideCredits -and $ShowCredits){throw 'Choose either -HideCredits or -ShowCredits, not both.'}
 if($HideCredits -or $ShowCredits -or $QuoteScreening) {
  $updates=@{}
  if($HideCredits -or $ShowCredits){$updates.showCredits=[bool]$ShowCredits}
  if($QuoteScreening){$updates.quoteScreening=$QuoteScreening}
  Set-WallpaperPreferences $DataDirectory $updates
  Write-Output 'Wallpaper settings saved. Applies to future wallpapers.'
  return
 }
 Add-Type -AssemblyName System.Windows.Forms
 $form=New-Object Windows.Forms.Form
 try {
  $form.Text='Wallpaper settings';$form.ClientSize=New-Object Drawing.Size(470,240)
  $form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog'
  $form.MaximizeBox=$false;$form.MinimizeBox=$false
  $checkbox=New-Object Windows.Forms.CheckBox
  $checkbox.Text='Show source credits on wallpapers';$checkbox.AutoSize=$true
  $checkbox.Location=New-Object Drawing.Point(20,20)
  $checkbox.Checked=Get-WallpaperShowCredits $DataDirectory
  $label=New-Object Windows.Forms.Label
  $label.Text='Quote screening';$label.AutoSize=$true;$label.Location=New-Object Drawing.Point(20,60)
  $screening=New-Object Windows.Forms.ComboBox
  $screening.DropDownStyle='DropDownList';$screening.SetBounds(160,55,280,25)
  $screening.Items.AddRange(@('Basic checks (no key required)','Jev screening'))
  $screening.SelectedIndex=if((Get-WallpaperQuoteScreening $DataDirectory) -eq 'Jev'){1}else{0}
  $help=New-Object Windows.Forms.Label
  $help.Text='Jev requires a TypeSafe API key and may take longer.'
  $help.SetBounds(20,95,420,45)
  $note=New-Object Windows.Forms.Label
  $note.Text='Applies when the next wallpaper is created.';$note.AutoSize=$true
  $note.Location=New-Object Drawing.Point(20,150)
  $save=New-Object Windows.Forms.Button
  $save.Text='Save';$save.Location=New-Object Drawing.Point(285,190)
  $save.DialogResult=[Windows.Forms.DialogResult]::OK
  $cancel=New-Object Windows.Forms.Button
  $cancel.Text='Cancel';$cancel.Location=New-Object Drawing.Point(370,190)
  $cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel
  $form.Controls.AddRange(@($checkbox,$label,$screening,$help,$note,$save,$cancel))
  $form.AcceptButton=$save;$form.CancelButton=$cancel
  if($form.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
   Set-WallpaperPreferences $DataDirectory @{showCredits=[bool]$checkbox.Checked;quoteScreening=$(if($screening.SelectedIndex -eq 1){'Jev'}else{'Basic'})}
   Write-Output 'Wallpaper settings saved. Applies to future wallpapers.'
  }
 }finally{$form.Dispose()}
}
if($MyInvocation.InvocationName -ne '.'){Configure-MotivationWallpaper}
