# Shared downloader for Windows PowerShell 5.1 and PowerShell 7.
function Invoke-DownloadWithProgress {
 param([Parameter(Mandatory)][string]$Uri,[Parameter(Mandatory)][string]$OutFile,[string]$Label='Download')
 $ProgressPreference='Continue'
 Add-Type -AssemblyName System.Net.Http
 $client=New-Object Net.Http.HttpClient
 $cancel=New-Object Threading.CancellationTokenSource
 $response=$null;$inputStream=$null;$outputStream=$null
 $watch=[Diagnostics.Stopwatch]::StartNew()
 $lastTime=0.0;$lastBytes=0L;$received=0L;$speed=0.0;$total=0L;$lastLog=-5.0
 try {
  $client.DefaultRequestHeaders.UserAgent.ParseAdd('NightreignConfigurator/0.1.1')
  $cancel.CancelAfter(45000)
  $task=$client.GetAsync($Uri,[Net.Http.HttpCompletionOption]::ResponseHeadersRead,$cancel.Token)
  Write-Progress -Id 1 -Activity $Label -Status 'Connecting...' -PercentComplete -1
  $response=$task.GetAwaiter().GetResult()
  [void]$response.EnsureSuccessStatusCode()
  if($null -ne $response.Content.Headers.ContentLength){$total=[long]$response.Content.Headers.ContentLength}
  $inputStream=$response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
  $outputStream=[IO.File]::Open($OutFile,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  $buffer=New-Object byte[] 131072
  while($true){
   $cancel.CancelAfter(45000)
   $read=$inputStream.ReadAsync($buffer,0,$buffer.Length,$cancel.Token)
   do {
    $ready=$read.Wait(250)
    $now=$watch.Elapsed.TotalSeconds
    if(($now-$lastTime) -ge 0.5){
     $speed=($received-$lastBytes)/($now-$lastTime)
     $lastBytes=$received;$lastTime=$now
     $size=if($total -gt 0){'{0:N1}/{1:N1} MiB' -f ($received/1MB),($total/1MB)}else{'{0:N1} MiB / unknown' -f ($received/1MB)}
     $eta=if($speed -gt 0 -and $total -gt 0 -and $received -ge 1MB -and $now -ge 1){[TimeSpan]::FromSeconds([Math]::Max(0,($total-$received)/$speed)).ToString('hh\:mm\:ss')}else{'--:--:--'}
     $percent=if($total -gt 0){[int][Math]::Min(99,100.0*$received/$total)}else{-1}
     $status='{0} | {1:N2} MiB/s | ETA {2}' -f $size,($speed/1MB),$eta
     Write-Progress -Id 1 -Activity $Label -Status $status -PercentComplete $percent
     # Redirected output has no live console progress UI; keep useful periodic logs.
     if([Console]::IsOutputRedirected -and ($now-$lastLog) -ge 5){Write-Host "$Label : $status";$lastLog=$now}
    }
   }while(-not $ready)
   $count=$read.GetAwaiter().GetResult()
   if($count -eq 0){break}
   $outputStream.Write($buffer,0,$count);$received+=$count
  }
  if($total -gt 0 -and $received -ne $total){throw 'Download ended before the expected file size was received.'}
  $average=$received/[Math]::Max(0.001,$watch.Elapsed.TotalSeconds)
  Write-Host ('{0}: 100% | {1:N1} MiB | average {2:N2} MiB/s | {3:N1}s' -f $Label,($received/1MB),($average/1MB),$watch.Elapsed.TotalSeconds)
 }finally{
  Write-Progress -Id 1 -Activity $Label -Completed
  if($null -ne $outputStream){$outputStream.Dispose()}
  if($null -ne $inputStream){$inputStream.Dispose()}
  if($null -ne $response){$response.Dispose()}
  $cancel.Dispose();$client.Dispose();$watch.Stop()
 }
}
