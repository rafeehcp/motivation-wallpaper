[CmdletBinding()]
param([switch]$HideCredits,[switch]$ShowCredits,[ValidateSet('Basic','Jev')][string]$QuoteScreening,[ValidateSet('Commons','Generated')][string]$BackgroundSource,[string]$DataDirectory="$env:USERPROFILE\Pictures\MotivationalWallpapers")
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WallpaperPreferences.ps1')

$script:settingsXaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Wallpaper Settings" SizeToContent="WidthAndHeight" ResizeMode="CanMinimize" WindowStartupLocation="CenterScreen"
 Background="#F3F3F3" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="14" Foreground="#1B1B1B">
 <Window.Resources>
  <SolidColorBrush x:Key="Accent" Color="#005FB8"/>
  <SolidColorBrush x:Key="AccentHover" Color="#196EBF"/>
  <SolidColorBrush x:Key="Muted" Color="#8A8A8A"/>
  <SolidColorBrush x:Key="Secondary" Color="#5F5F5F"/>
  <FontFamily x:Key="Icons">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>
  <Style x:Key="Toggle" TargetType="CheckBox">
   <Setter Property="Cursor" Value="Hand"/>
   <Setter Property="Template"><Setter.Value>
    <ControlTemplate TargetType="CheckBox">
     <Grid Width="40" Height="20" Background="Transparent">
      <Border x:Name="Track" CornerRadius="10" Background="{StaticResource Accent}"/>
      <Ellipse x:Name="Knob" Width="12" Height="12" Fill="White" HorizontalAlignment="Right" Margin="0,0,4,0"/>
     </Grid>
     <ControlTemplate.Triggers>
      <Trigger Property="IsChecked" Value="False">
       <Setter TargetName="Track" Property="Background" Value="White"/>
       <Setter TargetName="Track" Property="BorderBrush" Value="{StaticResource Muted}"/>
       <Setter TargetName="Track" Property="BorderThickness" Value="1"/>
       <Setter TargetName="Knob" Property="Fill" Value="{StaticResource Secondary}"/>
       <Setter TargetName="Knob" Property="HorizontalAlignment" Value="Left"/>
       <Setter TargetName="Knob" Property="Margin" Value="4,0,0,0"/>
      </Trigger>
     </ControlTemplate.Triggers>
    </ControlTemplate>
   </Setter.Value></Setter>
  </Style>
  <Style x:Key="Segment" TargetType="RadioButton">
   <Setter Property="Cursor" Value="Hand"/>
   <Setter Property="Foreground" Value="#1B1B1B"/>
   <Setter Property="Template"><Setter.Value>
    <ControlTemplate TargetType="RadioButton">
     <Border x:Name="Bg" CornerRadius="6" Padding="14,7" Background="Transparent">
      <ContentPresenter HorizontalAlignment="Center"/>
     </Border>
     <ControlTemplate.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bg" Property="Background" Value="#DADADA"/></Trigger>
      <Trigger Property="IsChecked" Value="True">
       <Setter TargetName="Bg" Property="Background" Value="{StaticResource Accent}"/>
       <Setter Property="Foreground" Value="White"/>
      </Trigger>
     </ControlTemplate.Triggers>
    </ControlTemplate>
   </Setter.Value></Setter>
  </Style>
  <Style x:Key="Action" TargetType="Button">
   <Setter Property="Cursor" Value="Hand"/>
   <Setter Property="Foreground" Value="#1B1B1B"/>
   <Setter Property="Template"><Setter.Value>
    <ControlTemplate TargetType="Button">
     <Border x:Name="Bg" CornerRadius="6" Padding="14,9" Background="White" BorderBrush="#E0E0E0" BorderThickness="1">
      <ContentPresenter HorizontalAlignment="Center"/>
     </Border>
     <ControlTemplate.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bg" Property="Background" Value="#F6F6F6"/></Trigger>
      <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Bg" Property="Opacity" Value="0.5"/></Trigger>
     </ControlTemplate.Triggers>
    </ControlTemplate>
   </Setter.Value></Setter>
  </Style>
  <Style x:Key="Primary" TargetType="Button">
   <Setter Property="Cursor" Value="Hand"/>
   <Setter Property="Foreground" Value="White"/>
   <Setter Property="Template"><Setter.Value>
    <ControlTemplate TargetType="Button">
     <Border x:Name="Bg" CornerRadius="6" Padding="18,9" Background="{StaticResource Accent}">
      <ContentPresenter HorizontalAlignment="Center"/>
     </Border>
     <ControlTemplate.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bg" Property="Background" Value="{StaticResource AccentHover}"/></Trigger>
      <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Bg" Property="Opacity" Value="0.5"/></Trigger>
     </ControlTemplate.Triggers>
    </ControlTemplate>
   </Setter.Value></Setter>
  </Style>
 </Window.Resources>
 <Grid Width="760" Height="430">
  <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="300"/></Grid.ColumnDefinitions>
  <Grid Margin="20">
   <Border CornerRadius="10" Background="#DCDCDC">
    <TextBlock x:Name="Empty" Text="No wallpaper preview" Foreground="{StaticResource Secondary}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
   </Border>
   <Border CornerRadius="10"><Border.Background><ImageBrush x:Name="Shot" Stretch="UniformToFill"/></Border.Background></Border>
   <Border CornerRadius="0,0,10,10" VerticalAlignment="Bottom" Padding="16,12">
    <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#00000000" Offset="0"/><GradientStop Color="#CC000000" Offset="1"/></LinearGradientBrush></Border.Background>
    <DockPanel>
     <Button x:Name="NewWallpaper" Style="{StaticResource Primary}" DockPanel.Dock="Right"><StackPanel Orientation="Horizontal"><TextBlock FontFamily="{StaticResource Icons}" Text="&#xE72C;" Margin="0,2,8,0"/><TextBlock Text="New wallpaper"/></StackPanel></Button>
     <StackPanel VerticalAlignment="Center" TextElement.Foreground="White">
      <TextBlock Text="Current wallpaper" FontWeight="SemiBold"/>
      <TextBlock x:Name="Caption" FontSize="12" Foreground="#D6D6D6" TextTrimming="CharacterEllipsis"/>
     </StackPanel>
    </DockPanel>
   </Border>
  </Grid>
  <DockPanel Grid.Column="1" Margin="0,24,24,20">
   <TextBlock DockPanel.Dock="Top" Text="Wallpaper Settings" FontFamily="Segoe UI Variable Display, Segoe UI" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,20"/>
   <TextBlock x:Name="Status" DockPanel.Dock="Bottom" FontSize="12" Foreground="{StaticResource Secondary}" TextWrapping="Wrap" Margin="2,12,0,0"/>
   <StackPanel>
    <TextBlock Text="BACKGROUND" FontSize="11" Foreground="{StaticResource Secondary}" Margin="0,0,0,6"/>
    <Border Background="#E6E6E6" CornerRadius="8" Padding="3"><UniformGrid Columns="2">
     <RadioButton x:Name="Photos" GroupName="Background" Style="{StaticResource Segment}" Content="Photos" ToolTip="Reviewed CC0 photos from Wikimedia Commons"/>
     <RadioButton x:Name="Generated" GroupName="Background" Style="{StaticResource Segment}" Content="Generated" ToolTip="Original artwork created offline"/>
    </UniformGrid></Border>
    <TextBlock Text="QUOTE SCREENING" FontSize="11" Foreground="{StaticResource Secondary}" Margin="0,18,0,6"/>
    <Border Background="#E6E6E6" CornerRadius="8" Padding="3"><UniformGrid Columns="2">
     <RadioButton x:Name="Basic" GroupName="Screening" Style="{StaticResource Segment}" Content="Basic" ToolTip="Format checks only, no key required"/>
     <RadioButton x:Name="Jev" GroupName="Screening" Style="{StaticResource Segment}" Content="Jev" ToolTip="Needs a TypeSafe API key and may take longer"/>
    </UniformGrid></Border>
    <DockPanel Margin="0,20,0,0">
     <CheckBox x:Name="Credits" Style="{StaticResource Toggle}" DockPanel.Dock="Right" VerticalAlignment="Center"/>
     <TextBlock Text="Show source credits" VerticalAlignment="Center"/>
    </DockPanel>
    <Border Height="1" Background="#E0E0E0" Margin="0,22,0,16"/>
    <Button x:Name="Swap" Style="{StaticResource Action}" Margin="0,0,0,8"><StackPanel Orientation="Horizontal"><TextBlock FontFamily="{StaticResource Icons}" Text="&#xE8AB;" Margin="0,2,10,0"/><TextBlock Text="Swap with previous"/></StackPanel></Button>
    <Button x:Name="OpenFolder" Style="{StaticResource Action}"><StackPanel Orientation="Horizontal"><TextBlock FontFamily="{StaticResource Icons}" Text="&#xE838;" Margin="0,2,10,0"/><TextBlock Text="Open wallpaper folder"/></StackPanel></Button>
   </StackPanel>
  </DockPanel>
 </Grid>
</Window>
'@

function Import-WallpaperDesktopType {
 if(!('Motivation.Desktop' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'MotivationWallpaper.cs') -ReferencedAssemblies System.Drawing}
}
function Get-CurrentWallpaperPath {
 Import-WallpaperDesktopType
 $desktop=New-Object Motivation.Desktop
 try{$monitors=@($desktop.Monitors());if(!$monitors.Count){return ''};return [string]$desktop.Get($monitors[0].Id)}finally{$desktop.Dispose()}
}
function Get-WallpaperCaption([string]$Path) {
 $details=Join-Path ([IO.Path]::GetDirectoryName($Path)) 'details.json'
 if(Test-Path -LiteralPath $details){
  try {
   $run=Get-Content -LiteralPath $details -Raw|ConvertFrom-Json
   $count=@($run.outputs).Count
   return "$count $(if($count -eq 1){'monitor'}else{'monitors'})  |  $((([string]$run.theme) -split ':')[0])"
  }catch{}
 }
 return 'Set outside Motivation Wallpaper'
}
function Show-SettingsMessage([string]$Message) {
 [Windows.MessageBox]::Show($script:settingsUi.Window,$Message,'Wallpaper Settings','OK','Warning')|Out-Null
}
function Update-SettingsPreview {
 $ui=$script:settingsUi
 try{$path=Get-CurrentWallpaperPath}catch{$path=''}
 $ui.CurrentPath=$path
 if($path -and (Test-Path -LiteralPath $path -PathType Leaf)){
  # OnLoad reads the file now, so the wallpaper image is never left locked.
  $image=New-Object Windows.Media.Imaging.BitmapImage
  $image.BeginInit();$image.UriSource=[Uri]$path;$image.CacheOption='OnLoad';$image.DecodePixelWidth=900;$image.EndInit()
  $ui.Shot.ImageSource=$image;$ui.Caption.Text=Get-WallpaperCaption $path
 }else{$ui.Shot.ImageSource=$null;$ui.Caption.Text='No wallpaper image found'}
}
function Save-SettingsChange([hashtable]$Updates) {
 try{Set-WallpaperPreferences $script:settingsUi.DataDirectory $Updates;$script:settingsUi.Status.Text='Saved. Applies to the next wallpaper.'}
 catch{Show-SettingsMessage $_.Exception.Message}
}
# Picks the message to show when a background action leaves the wallpaper unchanged:
# the first error line without its script-path prefix, else the last line of output.
function Get-SettingsActionMessage([string]$Errors,[string]$Output) {
 $line=@($Errors -split "`r?`n"|Where-Object{$_.Trim()})|Select-Object -First 1
 if($line){return ($line -replace '^.*?\.ps1 : ','').Trim()}
 return [string](@($Output -split "`r?`n"|Where-Object{$_.Trim()})|Select-Object -Last 1)
}
# Runs a script without a console and refreshes the preview when it exits.
function Start-SettingsAction([string]$ScriptPath,[string]$Arguments,[string]$Busy,[string]$Success,[string]$Failure) {
 $ui=$script:settingsUi
 $ui.Before=$ui.CurrentPath;$ui.Success=$Success;$ui.Failure=$Failure
 $start=New-Object Diagnostics.ProcessStartInfo("$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe",('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$ScriptPath+'" '+$Arguments))
 $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 $ui.Process=[Diagnostics.Process]::Start($start)
 # Read both streams as they arrive, so a full pipe can never stall the script.
 $ui.Output=$ui.Process.StandardOutput.ReadToEndAsync();$ui.Errors=$ui.Process.StandardError.ReadToEndAsync()
 $ui.NewWallpaper.IsEnabled=$false;$ui.Swap.IsEnabled=$false;$ui.Status.Text=$Busy
 $ui.Timer=New-Object Windows.Threading.DispatcherTimer
 $ui.Timer.Interval=[TimeSpan]::FromMilliseconds(500)
 $ui.Timer.add_Tick({
  $ui=$script:settingsUi
  if(!$ui.Process.HasExited -or !$ui.Output.IsCompleted -or !$ui.Errors.IsCompleted){return}
  $ui.Timer.Stop();Update-SettingsPreview
  $ui.NewWallpaper.IsEnabled=$true;$ui.Swap.IsEnabled=Test-Path -LiteralPath $ui.RestoreState
  if($ui.Process.ExitCode -eq 0 -and $ui.CurrentPath -ne $ui.Before){$ui.Status.Text=$ui.Success;return}
  $message=Get-SettingsActionMessage $ui.Errors.Result $ui.Output.Result
  $ui.Status.Text=if($message){$message}else{$ui.Failure}
 })
 $ui.Timer.Start()
}
function New-WallpaperSettingsWindow([string]$Folder,[string]$Icon=(Join-Path $PSScriptRoot 'MotivationWallpaper.ico')) {
 Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
 $window=[Windows.Markup.XamlReader]::Parse($script:settingsXaml)
 # RestoreMotivationWallpaper.ps1 always reads the default data folder.
 $ui=@{Window=$window;DataDirectory=$Folder;CurrentPath='';RestoreState=(Join-Path $env:USERPROFILE 'Pictures\MotivationalWallpapers\previous-wallpapers.json')}
 foreach($name in 'Shot','Caption','Empty','Status','Photos','Generated','Basic','Jev','Credits','NewWallpaper','Swap','OpenFolder'){$ui[$name]=$window.FindName($name)}
 $script:settingsUi=$ui
 # Show saved values before wiring handlers, so loading never writes settings.
 $ui.Photos.IsChecked=(Get-WallpaperBackgroundSource $Folder) -eq 'Commons';$ui.Generated.IsChecked=!$ui.Photos.IsChecked
 $ui.Jev.IsChecked=(Get-WallpaperQuoteScreening $Folder) -eq 'Jev';$ui.Basic.IsChecked=!$ui.Jev.IsChecked
 $ui.Credits.IsChecked=Get-WallpaperShowCredits $Folder
 $ui.Swap.IsEnabled=Test-Path -LiteralPath $ui.RestoreState
 $ui.Photos.add_Checked({Save-SettingsChange @{backgroundSource='Commons'}})
 $ui.Generated.add_Checked({Save-SettingsChange @{backgroundSource='Generated'}})
 $ui.Basic.add_Checked({Save-SettingsChange @{quoteScreening='Basic'}})
 $ui.Jev.add_Checked({
  try{Set-WallpaperCredentials}
  catch{$script:settingsUi.Basic.IsChecked=$true;Show-SettingsMessage 'Jev screening needs a TypeSafe API key. Quote screening stays on Basic.';return}
  Save-SettingsChange @{quoteScreening='Jev'}
 })
 $ui.Credits.add_Checked({Save-SettingsChange @{showCredits=$true}})
 $ui.Credits.add_Unchecked({Save-SettingsChange @{showCredits=$false}})
 $ui.NewWallpaper.add_Click({
  Start-SettingsAction (Join-Path $PSScriptRoot 'SetMotivationWallpaper.ps1') ('-DataDirectory "'+$script:settingsUi.DataDirectory+'"') 'Creating a new wallpaper...' 'New wallpaper applied.' 'Wallpaper unchanged. See wallpaper.log in the wallpaper folder.'
 })
 $ui.Swap.add_Click({
  Start-SettingsAction (Join-Path $PSScriptRoot 'RestoreMotivationWallpaper.ps1') '' 'Swapping wallpapers...' 'Swapped. Swap again to switch back.' 'The previous wallpaper could not be restored. Its image files may have been removed.'
 })
 $ui.OpenFolder.add_Click({
  New-Item -ItemType Directory -Path $script:settingsUi.DataDirectory -Force|Out-Null
  Start-Process -FilePath "$env:SystemRoot\explorer.exe" -ArgumentList ('"'+$script:settingsUi.DataDirectory+'"')
 })
 # Setup draws the icon next to this script. OnLoad reads it now, so the file is never left locked.
 if(Test-Path -LiteralPath $Icon){$window.Icon=[Windows.Media.Imaging.BitmapFrame]::Create([Uri]$Icon,[Windows.Media.Imaging.BitmapCreateOptions]::None,[Windows.Media.Imaging.BitmapCacheOption]::OnLoad)}
 # Loading the desktop interface compiles C#, so it waits until the window is visible.
 $window.add_ContentRendered({Update-SettingsPreview})
 return $window
}

function Configure-MotivationWallpaper {
 if($HideCredits -and $ShowCredits){throw 'Choose either -HideCredits or -ShowCredits, not both.'}
 if($HideCredits -or $ShowCredits -or $QuoteScreening -or $BackgroundSource) {
  $updates=@{}
  if($HideCredits -or $ShowCredits){$updates.showCredits=[bool]$ShowCredits}
  if($QuoteScreening){$updates.quoteScreening=$QuoteScreening}
  if($BackgroundSource){$updates.backgroundSource=$BackgroundSource}
  Set-WallpaperPreferences $DataDirectory $updates
  Write-Output 'Wallpaper settings saved. Applies to future wallpapers.'
  return
 }
 (New-WallpaperSettingsWindow $DataDirectory).ShowDialog()|Out-Null
}
if($MyInvocation.InvocationName -ne '.'){Configure-MotivationWallpaper}
