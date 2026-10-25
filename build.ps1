param([switch]$Package,[string]$BundleSmithbox)
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$out=Join-Path $root 'dist\Nightreign-Configurator'
[void][IO.Directory]::CreateDirectory($out)
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not (Test-Path -LiteralPath $csc)){throw '.NET Framework C# compiler not found.'}
$refs=@('/r:System.Windows.Forms.dll','/r:System.Drawing.dll','/r:System.Core.dll','/r:System.Web.Extensions.dll')
& $csc /nologo /target:winexe /platform:x64 /optimize+ "/out:$out\Nightreign-Configurator.exe" @refs "$root\src\Program.cs" "$root\src\SetupDialog.cs"
if($LASTEXITCODE -ne 0){throw 'Configurator compilation failed.'}
& $csc /nologo /target:winexe /platform:x64 /optimize+ "/out:$out\Host-Pattern-Controller.exe" @refs "$root\src\HostPatternController.cs"
if($LASTEXITCODE -ne 0){throw 'Controller compilation failed.'}
foreach($name in 'Generate.ps1','Setup.ps1','Launch.ps1','Get-Smithbox.ps1','Download.ps1','Bootstrap.ps1','dependencies.json','一键配置.cmd','启动游戏.cmd'){Copy-Item -LiteralPath "$root\scripts\$name" -Destination $out -Force}
foreach($name in 'README.md','DETAILS.md','THIRD_PARTY.md','CHANGELOG.md','快速开始.txt'){Copy-Item -LiteralPath "$root\$name" -Destination $out -Force}
if($BundleSmithbox){
 & "$root\scripts\Bundle-Smithbox.ps1" -Source $BundleSmithbox -Destination (Join-Path $out 'vendor\smithbox')
}
if($Package){
 # Explicit allowlist: never recurse over a working installation containing user data.
 $names=@('Nightreign-Configurator.exe','Host-Pattern-Controller.exe','Generate.ps1','Setup.ps1','Launch.ps1','Get-Smithbox.ps1','Download.ps1','Bootstrap.ps1','dependencies.json','一键配置.cmd','启动游戏.cmd','README.md','DETAILS.md','THIRD_PARTY.md','CHANGELOG.md','快速开始.txt')
 $zip=Join-Path $root 'dist\Nightreign-Configurator-preview.zip'
 Compress-Archive -LiteralPath @($names | ForEach-Object {Join-Path $out $_}) -DestinationPath $zip -Force
 Copy-Item -LiteralPath $zip -Destination (Join-Path $root 'dist\Nightreign-Configurator-v0.1.1-preview-win-x64.zip') -Force
 Write-Output $zip
 if($BundleSmithbox){
  $bundled=Join-Path $root 'dist\Nightreign-Configurator-with-Smithbox-preview.zip'
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $manifest=Get-Content -LiteralPath (Join-Path $out 'vendor\smithbox\bundle-manifest.json') -Raw | ConvertFrom-Json
  $relative=@($names)+@('vendor/smithbox/bundle-manifest.json')+@($manifest.Files | ForEach-Object {'vendor/smithbox/'+$_.File})
  $stream=[IO.File]::Open($bundled,[IO.FileMode]::Create)
  $archive=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
  try{foreach($name in $relative){[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $out $name),$name)}}finally{$archive.Dispose();$stream.Dispose()}
  Write-Output $bundled
 }
}
Write-Output $out
