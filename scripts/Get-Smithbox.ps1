param([string]$Destination)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(-not $Destination){
 $root=if((Split-Path $PSScriptRoot -Leaf) -eq 'scripts'){Split-Path $PSScriptRoot}else{$PSScriptRoot}
 $Destination=Join-Path $root 'vendor\smithbox'
}
$Destination=[IO.Path]::GetFullPath($Destination)
if(Test-Path -LiteralPath $Destination){throw 'Destination already exists. Select another empty destination; existing Smithbox files are not overwritten.'}
$url='https://github.com/vawser/Smithbox/releases/download/2.2.6/Smithbox_2_2_6_2026_09_20_b.zip'
$expected='9A147C319DCCAD4B6DD2A5ADCC6F2BA3A5C11C40B079520C05260CB19994B3D7'
$parent=Split-Path $Destination
[void][IO.Directory]::CreateDirectory($parent)
$temp=Join-Path $parent ('.smithbox-download-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
try {
 [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
 $zip=Join-Path $temp 'smithbox.zip'
 Write-Output 'Downloading official Smithbox 2.2.6 (about 283 MiB)...'
 Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
 if((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $expected){throw 'SHA-256 mismatch. Download was not installed.'}
 $extract=Join-Path $temp 'extracted'
 Expand-Archive -LiteralPath $zip -DestinationPath $extract
 $candidate=@(Get-ChildItem -LiteralPath $extract -Filter 'Andre.SoulsFormats.dll' -File -Recurse)
 if($candidate.Count -ne 1){throw 'Unexpected Smithbox archive layout.'}
 $source=$candidate[0].Directory.FullName
 foreach($file in @('Smithbox.Vulkan.exe','Licenses\Smithbox\LICENSE.txt','Licenses\SoulsFormats\LICENSE.txt','Assets\PARAM\NR\Defs\NightBossMenuParam.xml')){if(-not (Test-Path -LiteralPath (Join-Path $source $file))){throw "Missing official archive component: $file"}}
 Move-Item -LiteralPath $source -Destination $Destination
 Write-Output "Installed official archive to: $Destination"
 Write-Output 'The configurator detects vendor/smithbox automatically. No executable was launched.'
}finally{
 # Delete only this freshly generated temporary directory, never the installation.
 $resolved=[IO.Path]::GetFullPath($temp)
 if($resolved.StartsWith([IO.Path]::GetFullPath($parent).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf).StartsWith('.smithbox-download-')){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
