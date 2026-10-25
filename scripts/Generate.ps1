param([Parameter(Mandatory=$true)][string]$Request)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$mutex=$null; $locked=$false; $temp=$null
$dataHome=Join-Path $PSScriptRoot 'data'
try {
 $cfg=Get-Content -LiteralPath "$dataHome\config.json" -Raw | ConvertFrom-Json
 $req=Get-Content -LiteralPath $Request -Raw | ConvertFrom-Json
 $baseline="$dataHome\baseline\regulation.bin"
 if((Get-FileHash -LiteralPath $baseline).Hash -ne $cfg.BaselineHash){throw '原始副本校验失败，请恢复 baseline 文件。'}
 if((Get-FileHash -LiteralPath $cfg.GameRegulation).Hash -ne $cfg.BaselineHash){throw '游戏目录的参数文件已变化。可能已更新游戏，请重新核对原始基准和 Smithbox 版本，暂不生成。'}
 $output=[IO.Path]::GetFullPath([string]$req.Output)
 $gameDir=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($cfg.GameRegulation))+'\'
 if($output.StartsWith($gameDir,[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith("$dataHome\baseline\",[StringComparison]::OrdinalIgnoreCase)){throw '不能覆盖游戏原文件或只读基准，请选择模组目录。'}
 if([IO.Path]::GetFileName($output) -ne 'regulation.bin'){throw '输出文件名必须是 regulation.bin。'}
 $outputDir=[IO.Path]::GetDirectoryName($output)
 if(-not (Test-Path -LiteralPath $outputDir -PathType Container)){throw '输出文件夹不存在，请先选择有效的目录。'}
 for($dir=Get-Item -LiteralPath $outputDir;$null -ne $dir;$dir=$dir.Parent){if($dir.Attributes -band [IO.FileAttributes]::ReparsePoint){throw '输出目录包含链接，请选择实际文件夹。'}}
 if((Test-Path -LiteralPath $output) -and ((Get-Item -LiteralPath $output).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw '输出文件不能是链接。'}
 if(Get-Process -Name 'nightreign','Smithbox.Vulkan','Smithbox.OpenGL' -ErrorAction SilentlyContinue){throw '请先关闭游戏和 Smithbox，再生成参数，避免旧数据覆盖新文件。'}
 $ids=@($req.Bosses | ForEach-Object { [int]$_ } | Select-Object -Unique)
 if(@($ids | Where-Object {$_ -lt 0 -or $_ -gt 9}).Count){throw '未知夜王编号。'}
 if($req.Weighting -notin @('original','equal')){throw '未知概率模式。'}
 # Support older single-terrain requests as well as the new array.
 $terrainIds=@()
 if($req.PSObject.Properties.Name -contains 'Terrains'){
  $terrainIds=@($req.Terrains | ForEach-Object {[int]$_} | Select-Object -Unique)
 }elseif($req.PSObject.Properties.Name -contains 'Terrain'){
  if([int]$req.Terrain -ne 0){$terrainIds=@([int]$req.Terrain)}
 }
 if(@($terrainIds | Where-Object {$_ -lt 1 -or $_ -gt 5}).Count){throw '未知地形。'}
 $everdark=[bool]$req.Everdark
 $mutex=[Threading.Mutex]::new($false,'Local\NightreignRegulationConfigurator')
 $locked=$mutex.WaitOne(0)
 if(-not $locked){throw '另一个生成任务正在运行。'}
 [void][Reflection.Assembly]::LoadFrom((Join-Path $cfg.Smithbox 'Andre.SoulsFormats.dll'))
 function ReadParam($b,$name) {
  $file=$b.Files | Where-Object {[IO.Path]::GetFileNameWithoutExtension($_.Name) -eq $name}
  if(@($file).Count -ne 1){throw "缺失参数：$name"}
  $p=[SoulsFormats.PARAM]::Read($file.Bytes)
  $def=[SoulsFormats.PARAMDEF]::XmlDeserialize((Join-Path $cfg.Smithbox "Assets\PARAM\NR\Defs\$name.xml"),$true)
  $p.ApplyRegulationVersionedParamdef($def,[UInt64]$b.Version)
  return $p
 }
 $b=[SoulsFormats.SFUtil]::DecryptNightreignRegulation($baseline)
 if($b.Version -ne $cfg.Version){throw '基准参数版本不受支持。'}
 $boss=ReadParam $b 'NightBossMenuParam'; $map=ReadParam $b 'MapPatternSet'
 $entries=[ordered]@{'NightBossMenuParam'=$boss;'MapPatternSet'=$map}
 $fixedPattern=$null
 if($req.PSObject.Properties.Name -contains 'PatternId' -and $null -ne $req.PatternId){
  $fixedPattern=[int]$req.PatternId
  $flags=ReadParam $b 'LotResultMapPatternFlag'
  $sourceFlags=@($flags.Rows | Where-Object {$_['patternId'].Value -eq $fixedPattern})
  if(-not $sourceFlags.Count){throw '地图模板编号不存在。请填写 0–319 或 1000–1199。'}
  $patternBoss=[int]$sourceFlags[0]['targetBoss'].Value
  $patternSet=[int]$sourceFlags[0]['patternSetId'].Value
  $patternTerrain=[int]$sourceFlags[0]['rareMap'].Value
  if($ids.Count -and ($ids.Count -ne 1 -or $ids[0] -ne $patternBoss)){throw '固定模板与夜王选择冲突，请使用该模板对应的夜王。'}
  if($terrainIds.Count -and ($terrainIds.Count -ne 1 -or $terrainIds[0] -ne $patternTerrain)){throw '固定模板与地形选择冲突。'}
  $ids=@($patternBoss)
  $terrainIds=@()

 }
 $row=@{}; foreach($r in $boss.Rows){$row[$r.ID]=$r}
 $variants=@{0=10;1=11;2=12;3=13;4=14;5=15;6=16;8=18}
 $pool=@(if($ids.Count){$ids}else{0..9})
 if($everdark){$pool=@($pool | Where-Object {$variants.ContainsKey($_)})}
 if(-not $pool.Count){throw '所选夜王没有独立永夜版本。请取消固定永夜，或选择其他夜王。'}
 foreach($d in 1..5) {
  $field="depth${d}ChanceWeight"
  foreach($id in 0..9) {
   $normal=[int]$row[$id][$field].Value
   $variant=if($variants.ContainsKey($id)){$row[$variants[$id]]}else{$null}
   $ew=if($null -ne $variant){[int]$variant[$field].Value}else{0}
   $total=$normal+$ew
   if($id -notin $pool){$normal=0;$ew=0}
   elseif($ids.Count -gt 0 -and $req.Weighting -eq 'equal'){
    if($everdark){$normal=0;$ew=1000}
    else{$normal=[int][Math]::Round(1000.0*$normal/$total);$ew=1000-$normal}
   } elseif($everdark){$normal=0;$ew=$total}
   $row[$id][$field].Value=[int16]$normal
   if($null -ne $variant){$variant[$field].Value=[int16]$ew}
  }
 }
 if($terrainIds.Count -gt 0) {
  foreach($r in $map.Rows) {
   $chosen=(($r.ID % 10) -in $terrainIds) -and $r['patternCount'].Value -gt 0
   foreach($field in @('weight','chaosMatchWeight')){
    if(-not $chosen){$r[$field].Value=0}
   }
  }
  foreach($id in $pool){
   $valid=@($map.Rows | Where-Object {([int][Math]::Floor(($_.ID % 1000)/10)) -eq $id -and $_['chaosMatchWeight'].Value -gt 0})
   if(-not $valid.Count){throw "所选地形没有夜王 $id 的有效地图方案，未生成。"}
  }
 }
 if($null -ne $fixedPattern){
  foreach($r in $map.Rows){foreach($field in @('weight','chaosMatchWeight')){$r[$field].Value=if($r.ID -eq $patternSet){10000}else{0}}}
 }
 foreach($entry in $entries.GetEnumerator()) {
  ($b.Files | Where-Object {[IO.Path]::GetFileNameWithoutExtension($_.Name) -eq $entry.Key}).Bytes=[Memory[byte]]::new($entry.Value.Write())
 }
 $stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
 $temp=Join-Path $outputDir ('.regulation-'+[Guid]::NewGuid().ToString('N')+'.tmp')
 $allDefault=($ids.Count -eq 0 -and -not $everdark -and $terrainIds.Count -eq 0 -and $null -eq $fixedPattern)
 if($allDefault){Copy-Item -LiteralPath $baseline -Destination $temp}
 else{[SoulsFormats.SFUtil]::EncryptNightreignRegulation($temp,$b,$b.Compression)}
 $check=[SoulsFormats.SFUtil]::DecryptNightreignRegulation($temp)
 $orig=[SoulsFormats.SFUtil]::DecryptNightreignRegulation($baseline)
 if($check.Files.Count -ne $orig.Files.Count -or $check.Version -ne $orig.Version){throw '文件结构验证失败。'}
 $changes=[Collections.Generic.List[object]]::new()
 foreach($entry in $entries.GetEnumerator()){
  $actual=ReadParam $check $entry.Key; $expected=$entry.Value; $old=ReadParam $orig $entry.Key
  if($actual.Rows.Count -ne $expected.Rows.Count){throw '参数行数验证失败。'}
  $oldRows=@{};foreach($r in $old.Rows){$oldRows[$r.ID]=$r}
  for($i=0;$i -lt $actual.Rows.Count;$i++){
   $a=$actual.Rows[$i];$e=$expected.Rows[$i];$o=$oldRows[$a.ID]
   if($a.ID -ne $e.ID -or $a.Cells.Count -ne $e.Cells.Count){throw '参数结构验证失败。'}
   for($j=0;$j -lt $a.Cells.Count;$j++){
    if($a.Cells[$j].Value -cne $e.Cells[$j].Value){throw '参数回读验证失败。'}
    if($null -eq $o -or $a.Cells[$j].Value -cne $o.Cells[$j].Value){$changes.Add([pscustomobject]@{Param=$entry.Key;ID=$a.ID;Field=$a.Cells[$j].Def.InternalName;Before=$(if($null -ne $o){$o.Cells[$j].Value}else{$null});After=$a.Cells[$j].Value})}
   }
   $oldRows.Remove($a.ID)
  }
  foreach($id in $oldRows.Keys){$changes.Add([pscustomobject]@{Param=$entry.Key;ID=$id;Field='RemovedRow';Before='Present';After=$null})}
 }
 for($i=0;$i -lt $orig.Files.Count;$i++){
  $a=$orig.Files[$i];$z=$check.Files[$i]
  if($a.Name -ne $z.Name){throw '参数目录验证失败。'}
  if([IO.Path]::GetFileNameWithoutExtension($a.Name) -notin @($entries.Keys)){
   if([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($a.Bytes.ToArray())) -ne [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($z.Bytes.ToArray()))){throw '发现无关参数被修改。'}
  }
 }
 $hash=(Get-FileHash -LiteralPath $temp).Hash
 if($allDefault -and $hash -ne $cfg.BaselineHash){throw '原版还原校验失败。'}
 $backup=$null
 if(Test-Path -LiteralPath $output){$backup=$output+'.backup-'+$stamp;[IO.File]::Replace($temp,$output,$backup)}else{[IO.File]::Move($temp,$output)}
 $temp=$null
 $hostSettings=[ordered]@{PatternId=$fixedPattern;Output=$output;Hash=$hash;GeneratedUtc=[DateTime]::UtcNow.ToString('o')}
 $hostTemp=Join-Path $dataHome ('host-selection-'+[Guid]::NewGuid().ToString('N')+'.tmp')
 $hostSettings | ConvertTo-Json | Set-Content -LiteralPath $hostTemp -Encoding utf8
 [IO.File]::Move($hostTemp,(Join-Path $dataHome 'host-selection.json'),$true)
 $report=[ordered]@{Success=$true;Output=$output;Backup=$backup;Hash=$hash;Version=$b.Version;ChangedFields=$changes.Count;Bosses=$pool;Everdark=$everdark;Terrains=$terrainIds;PatternId=$fixedPattern;PatternMode=$(if($null -ne $fixedPattern){'host-runtime-selection'}else{'random'});OriginalRestored=$allDefault}
 try{
  $logs=Join-Path $dataHome 'logs';[void][IO.Directory]::CreateDirectory($logs)
  $changes | Export-Csv -LiteralPath (Join-Path $logs "$stamp-changes.csv") -Encoding utf8BOM -NoTypeInformation
  $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $logs "$stamp.json") -Encoding utf8
 }catch{$report['LogWarning']='文件已生成，但日志保存失败。'}
 $report | ConvertTo-Json -Compress -Depth 5
} catch {
 [Console]::Error.WriteLine($_.Exception.Message)
 exit 1
} finally {
 if($temp -and (Test-Path -LiteralPath $temp)){Remove-Item -LiteralPath $temp -Force}
 if($locked){$mutex.ReleaseMutex()};if($null -ne $mutex){$mutex.Dispose()}
}
