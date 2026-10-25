param([Parameter(Mandatory)][string]$Request)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
try {
 if([Environment]::Version.Major -lt 10){throw '需要基于 .NET 10 的 PowerShell。请安装合适的 pwsh 并重新选择。'}
 $cfg=Get-Content -LiteralPath $Request -Raw | ConvertFrom-Json -AsHashtable
 foreach($key in 'GameExe','SeamlessDll','Me3','PowerShell') {
  $cfg[$key]=[IO.Path]::GetFullPath([string]$cfg[$key])
  if(-not (Test-Path -LiteralPath $cfg[$key] -PathType Leaf)){throw "找不到 $key，请重新选择。"}
 }
 foreach($pair in @(@('GameExe','nightreign.exe'),@('SeamlessDll','nrsc.dll'),@('Me3','me3.exe'),@('PowerShell','pwsh.exe'))){if([IO.Path]::GetFileName($cfg[$pair[0]]) -ne $pair[1]){throw "请为 $($pair[0]) 选择 $($pair[1])。"}}
 if([string]::IsNullOrWhiteSpace([string]$cfg.Smithbox)){$cfg.Smithbox=Join-Path $PSScriptRoot 'vendor\smithbox'}
 $cfg.Smithbox=[IO.Path]::GetFullPath([string]$cfg.Smithbox)
 $cfg.GameRegulation=Join-Path (Split-Path $cfg.GameExe) 'regulation.bin'
 $cfg.SeamlessIni=Join-Path (Split-Path $cfg.SeamlessDll) 'nrsc_settings.ini'
 if(-not (Test-Path -LiteralPath $cfg.SeamlessIni -PathType Leaf)){throw 'nrsc.dll 旁没有 nrsc_settings.ini，请先完成无缝联机安装。'}
 $cfg.BaselineHash='876A3CA279A4561D0C69F81FE5E510C75C59AB9A8A201694F8CF4A42C91E0268'
 $cfg.Version='10350000'
 if((Get-FileHash -LiteralPath $cfg.GameRegulation).Hash -ne $cfg.BaselineHash){throw '当前仅验证过 1.03.5 原始参数。此文件不匹配，未保存配置；请勿用旧参数覆盖新版游戏。'}
 [void][Reflection.Assembly]::LoadFrom((Join-Path $cfg.Smithbox 'Andre.SoulsFormats.dll'))
 $b=[SoulsFormats.SFUtil]::DecryptNightreignRegulation($cfg.GameRegulation)
 if($b.Version -ne $cfg.Version){throw '参数版本不匹配。'}
 $patterns=@()
 foreach($name in 'NightBossMenuParam','MapPatternSet','LotResultMapPatternFlag'){
  $file=@($b.Files | Where-Object {[IO.Path]::GetFileNameWithoutExtension($_.Name) -eq $name})
  if($file.Count -ne 1){throw "缺少参数 $name"}
  $p=[SoulsFormats.PARAM]::Read($file[0].Bytes)
  $def=[SoulsFormats.PARAMDEF]::XmlDeserialize((Join-Path $cfg.Smithbox "Assets\PARAM\NR\Defs\$name.xml"),$true)
  $p.ApplyRegulationVersionedParamdef($def,[UInt64]$b.Version)
  if($name -eq 'LotResultMapPatternFlag'){
   $patterns=@($p.Rows | ForEach-Object {[ordered]@{Id=[int]$_['patternId'].Value;Boss=[int]$_['targetBoss'].Value;Terrain=[int]$_['rareMap'].Value;Set=[int]$_['patternSetId'].Value}} | Sort-Object -Property {$_['Id']} -Unique)
  }
 }
 $data=Join-Path $PSScriptRoot 'data'
 foreach($dir in 'baseline','generated','requests','logs','history','runtime'){[void][IO.Directory]::CreateDirectory((Join-Path $data $dir))}
 $baseline=Join-Path $data 'baseline\regulation.bin'
 if(Test-Path -LiteralPath $baseline){if((Get-FileHash -LiteralPath $baseline).Hash -ne $cfg.BaselineHash){throw '已有基准副本校验失败。请在退出程序后移走 data/baseline 再配置。'}}else{Copy-Item -LiteralPath $cfg.GameRegulation -Destination $baseline}
 $cfg.Output=Join-Path $data 'generated\regulation.bin'
 if(-not (Test-Path -LiteralPath $cfg.Output)){Copy-Item -LiteralPath $baseline -Destination $cfg.Output}
 $cfg.SchemaVersion=1
 $patterns | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $data 'patterns.json') -Encoding utf8
 $temp=Join-Path $data 'config.json.tmp'
 $cfg | ConvertTo-Json | Set-Content -LiteralPath $temp -Encoding utf8
 [IO.File]::Move($temp,(Join-Path $data 'config.json'),$true)
 @{Success=$true;Patterns=$patterns.Count} | ConvertTo-Json -Compress
}catch{[Console]::Error.WriteLine($_.Exception.Message);exit 1}
