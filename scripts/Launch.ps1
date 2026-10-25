param([switch]$CheckOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
try {
 $data=Join-Path $PSScriptRoot 'data'
 $cfg=Get-Content -LiteralPath (Join-Path $data 'config.json') -Raw | ConvertFrom-Json
 if(Get-Process -Name nightreign,nrsc_launcher -ErrorAction SilentlyContinue){throw '请先退出游戏，再从此入口启动。'}
 $source=$cfg.Output
 $selection=Join-Path $data 'host-selection.json'
 if(Test-Path -LiteralPath $selection){$selected=Get-Content -LiteralPath $selection -Raw | ConvertFrom-Json;$source=$selected.Output;if((Get-FileHash -LiteralPath $source).Hash -ne $selected.Hash){throw '生成文件已变化，请重新生成。'}}
 foreach($file in @($cfg.GameExe,$cfg.Me3,$cfg.SeamlessDll,$cfg.SeamlessIni,$source)){if(-not (Test-Path -LiteralPath $file -PathType Leaf)){throw "缺少启动文件：$file"}}
 if((Get-FileHash -LiteralPath $cfg.GameRegulation).Hash -ne $cfg.BaselineHash){throw '游戏原始参数已变化，请重新核对版本。'}
 $runtime=Join-Path $data 'runtime'
 $mod=Join-Path $runtime 'mod'
 [void][IO.Directory]::CreateDirectory($mod)
 for($dir=Get-Item -LiteralPath $mod;$null -ne $dir;$dir=$dir.Parent){if($dir.Attributes -band [IO.FileAttributes]::ReparsePoint){throw '运行目录不能包含链接。'}}
 $staged=Join-Path $mod 'regulation.bin'
 if((Test-Path -LiteralPath $staged) -and ((Get-Item -LiteralPath $staged).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw '运行参数不能是链接。'}
 Copy-Item -LiteralPath $source -Destination $staged -Force
 if((Get-FileHash -LiteralPath $staged).Hash -ne (Get-FileHash -LiteralPath $source).Hash){throw '暂存文件校验失败。'}
 # JSON-escaped Windows paths are valid TOML basic strings.
 $packagePath=ConvertTo-Json -InputObject $mod -Compress
 $dllPath=ConvertTo-Json -InputObject ([string]$cfg.SeamlessDll) -Compress
 $profile=Join-Path $runtime 'nightreign.me3'
 @"
profileVersion = "v1"
start_online = false
[[supports]]
game = "nightreign"
[[packages]]
id = "custom-regulation"
path = $packagePath
[[natives]]
path = $dllPath
load_early = true
optional = false
enabled = true
"@ | Set-Content -LiteralPath $profile -Encoding utf8NoBOM
 if($CheckOnly){@{Success=$true;CheckOnly=$true;StagedHash=(Get-FileHash -LiteralPath $staged).Hash} | ConvertTo-Json -Compress;exit 0}
 if(-not (Get-Process -Name steam -ErrorAction SilentlyContinue)){throw '请先启动 Steam 并登录。'}
 Push-Location (Split-Path $cfg.GameExe)
 try{& $cfg.Me3 launch --game nightreign --exe $cfg.GameExe --profile $profile --online false;if($LASTEXITCODE -ne 0){throw "ME3 启动失败，退出码 $LASTEXITCODE"}}finally{Pop-Location}
 if((Get-FileHash -LiteralPath $cfg.GameRegulation).Hash -ne $cfg.BaselineHash){throw '启动后原始文件校验不一致，请检查其他工具。'}
}catch{[Console]::Error.WriteLine($_.Exception.Message);exit 1}
