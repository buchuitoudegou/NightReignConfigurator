param([Parameter(Mandatory)][string]$Source,[Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference='Stop'
# Explicit minimal runtime list. Never copy a whole working Smithbox installation.
$files=@(
 'Andre.SoulsFormats.dll',
 'DotNext.dll',
 'DotNext.Unsafe.dll',
 'BouncyCastle.Cryptography.dll',
 'CommunityToolkit.HighPerformance.dll',
 'ZstdNet.dll',
 'libzstd.dll',
 'Assets\PARAM\NR\Defs\NightBossMenuParam.xml',
 'Assets\PARAM\NR\Defs\MapPatternSet.xml',
 'Assets\PARAM\NR\Defs\LotResultMapPatternFlag.xml',
 'Licenses\Smithbox\LICENSE.txt',
 'Licenses\SoulsFormats\LICENSE.txt'
)
foreach($name in $files){if(-not (Test-Path -LiteralPath (Join-Path $Source $name) -PathType Leaf)){throw "Missing Smithbox component: $name"}}
# Destination is a dedicated build output; reject unexpected files instead of including stale dependencies.
if(Test-Path -LiteralPath $Destination){
 $prefix=[IO.Path]::GetFullPath($Destination).TrimEnd('\')+'\'
 foreach($f in Get-ChildItem -LiteralPath $Destination -File -Recurse){$relative=$f.FullName.Substring($prefix.Length);if($relative -notin ($files+@('bundle-manifest.json'))){throw "Unexpected file in bundle directory: $relative"}}
}
$manifest=@()
foreach($name in $files){
 $src=Join-Path $Source $name;$dst=Join-Path $Destination $name
 [void][IO.Directory]::CreateDirectory((Split-Path $dst))
 Copy-Item -LiteralPath $src -Destination $dst -Force
 $manifest+=@{File=$name.Replace('\','/');SHA256=(Get-FileHash -LiteralPath $dst).Hash;Bytes=(Get-Item -LiteralPath $dst).Length}
}
@{Kind='Smithbox parameter runtime subset';Upstream='https://github.com/vawser/Smithbox';SourceRevision='Unverified: resolve exact corresponding source before public redistribution';Files=$manifest} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Destination 'bundle-manifest.json') -Encoding utf8
