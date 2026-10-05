$ErrorActionPreference='Stop'
$path=Join-Path $env:USERPROFILE 'Pictures\MotivationalWallpapers\previous-wallpapers.json'
# Swaps the recorded wallpapers with the current ones, so a second restore switches back.
function Switch-WallpaperRestoreState($Desktop,$Path) {
 if(!(Test-Path -LiteralPath $Path)){throw 'No previous wallpaper state has been recorded.'}
 $state=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json
 $current=@{position=$Desktop.Position();wallpapers=@($state.wallpapers|ForEach-Object{@{monitor=$_.monitor;path=$Desktop.Get($_.monitor)}})}
 try{foreach($item in $state.wallpapers){$Desktop.Set($item.monitor,$item.path)};$Desktop.SetPosition($state.position)}
 catch{foreach($item in $current.wallpapers){try{$Desktop.Set($item.monitor,$item.path)}catch{}};try{$Desktop.SetPosition($current.position)}catch{};throw}
 $temporary=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
 [IO.File]::WriteAllText($temporary,(ConvertTo-Json -InputObject $current -Depth 5),(New-Object Text.UTF8Encoding($false)))
 [IO.File]::Replace($temporary,$Path,"$Path.previous")
}
if($MyInvocation.InvocationName -ne '.'){
 Add-Type -Path (Join-Path $PSScriptRoot 'MotivationWallpaper.cs') -ReferencedAssemblies System.Drawing
 $desktop=New-Object Motivation.Desktop
 try{Switch-WallpaperRestoreState $desktop $path}finally{$desktop.Dispose()}
}
