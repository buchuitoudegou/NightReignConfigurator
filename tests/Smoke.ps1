param(
 [Parameter(Mandatory)][string]$GameExe,
 [Parameter(Mandatory)][string]$SeamlessDll,
 [Parameter(Mandatory)][string]$Me3,
 [Parameter(Mandatory)][string]$Smithbox,
 [Parameter(Mandatory)][string]$PowerShell
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$test=Join-Path $root ('dist\smoke-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($test)
Copy-Item -Path "$root\scripts\*.ps1" -Destination $test
$request=Join-Path $test 'setup.json'
@{GameExe=$GameExe;SeamlessDll=$SeamlessDll;Me3=$Me3;Smithbox=$Smithbox;PowerShell=$PowerShell} | ConvertTo-Json | Set-Content -LiteralPath $request -Encoding utf8
& $PowerShell -NoProfile -File "$test\Setup.ps1" -Request $request
if($LASTEXITCODE -ne 0){throw 'Setup failed'}
$cfg=Get-Content -LiteralPath "$test\data\config.json" -Raw | ConvertFrom-Json
$patterns=@(Get-Content -LiteralPath "$test\data\patterns.json" -Raw | ConvertFrom-Json)
if($patterns.Count -ne 520 -or @($patterns | Where-Object {$_.Id -eq 88}).Count -ne 1){throw 'Pattern extraction mismatch'}
$gen=Join-Path $test 'request.json'
foreach($id in @($null,88)){
 @{Bosses=@();Everdark=$false;Terrains=@();Weighting='original';Output=$cfg.Output;PatternId=$id} | ConvertTo-Json | Set-Content -LiteralPath $gen -Encoding utf8
 & $PowerShell -NoProfile -File "$test\Generate.ps1" -Request $gen
 if($LASTEXITCODE -ne 0){throw 'Generate failed'}
 if($null -eq $id -and (Get-FileHash -LiteralPath $cfg.Output).Hash -ne $cfg.BaselineHash){throw 'Default output mismatch'}
}
& $PowerShell -NoProfile -File "$test\Launch.ps1" -CheckOnly
if($LASTEXITCODE -ne 0){throw 'Launch preparation failed'}
@{Bosses=@();Everdark=$false;Terrains=@();Weighting='original';Output=$cfg.GameRegulation;PatternId=$null} | ConvertTo-Json | Set-Content -LiteralPath $gen -Encoding utf8
& $PowerShell -NoProfile -File "$test\Generate.ps1" -Request $gen
if($LASTEXITCODE -eq 0){throw 'Game file protection failed'}
if((Get-FileHash -LiteralPath $cfg.GameRegulation).Hash -ne $cfg.BaselineHash){throw 'Game file changed'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $root 'dist\Nightreign-Configurator-preview.zip'))
try{if($zip.Entries.Count -ne 9 -or @($zip.Entries | Where-Object {$_.FullName -match '(?i)(data/|\.bin$|\.ini$|\.dll$|config\.json)'}).Count){throw 'Package inventory failed'}}finally{$zip.Dispose()}
Write-Output "PASS: setup, 520 patterns, exact vanilla restore, template 88 validated generation, launch preparation, original protection, release inventory. Local test artifacts: $test"
