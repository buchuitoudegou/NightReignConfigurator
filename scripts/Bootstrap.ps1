param([ValidateSet('Configure','Launch','Dependencies')][string]$Action='Configure',[switch]$CheckOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$ProgressPreference='SilentlyContinue'
. (Join-Path $PSScriptRoot 'Download.ps1')
$mutex=$null;$locked=$false
try {
 $homeDir=$PSScriptRoot
 $data=Join-Path $homeDir 'data'
 $vendor=Join-Path $homeDir 'vendor'
 [void][IO.Directory]::CreateDirectory($data)
 $mutex=New-Object Threading.Mutex($false,'Local\NightreignConfiguratorBootstrap')
 $locked=$mutex.WaitOne(0)
 if(-not $locked){throw 'Another setup or launcher is running. Please use one window at a time.'}
 [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
 $deps=Get-Content -LiteralPath (Join-Path $homeDir 'dependencies.json') -Raw | ConvertFrom-Json
 $dependencyIndex=0
 foreach($dep in $deps){
  $dependencyIndex++
  $target=Join-Path $vendor $dep.Id
  $marker=Join-Path $target '.download-sha256'
  $entryMarker=Join-Path $target '.entry-path'
  if((Test-Path -LiteralPath $entryMarker) -and (Test-Path -LiteralPath $marker) -and ((Get-Content -LiteralPath $marker -Raw).Trim() -eq $dep.Sha256)){
   $installed=Join-Path $target ((Get-Content -LiteralPath $entryMarker -Raw).Trim())
   if(Test-Path -LiteralPath $installed -PathType Leaf){Write-Host "[$dependencyIndex/$($deps.Count)] $($dep.Id): already installed";continue}
  }
  if(Test-Path -LiteralPath $target){throw "Unmanaged or incomplete dependency folder: $target. Move it aside, then run setup again."}
  [void][IO.Directory]::CreateDirectory($vendor)
  $work=Join-Path $vendor ('.download-'+[Guid]::NewGuid().ToString('N'))
  [void][IO.Directory]::CreateDirectory($work)
  try {
   $zip=Join-Path $work 'download.zip'
   Write-Output ("Downloading {0} {1} from official GitHub..." -f $dep.Id,$dep.Version)
   Invoke-DownloadWithProgress -Uri $dep.Url -OutFile $zip -Label "[$dependencyIndex/$($deps.Count)] $($dep.Id) $($dep.Version)"
   Write-Host 'Verifying SHA-256...'
   if((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $dep.Sha256){throw "Checksum mismatch: $($dep.Id). Nothing installed."}
   $extract=Join-Path $work 'extracted'
   Write-Host 'Extracting archive, please wait...'
   Expand-Archive -LiteralPath $zip -DestinationPath $extract
   $entry=@(Get-ChildItem -LiteralPath $extract -Filter $dep.Entry -File -Recurse)
   if($entry.Count -ne 1){throw "Unexpected archive layout: $($dep.Id)"}
   # Keep the full archive, including sibling directories and license notices.
   # Normalize its root only when the entry is in a single enclosing directory.
   $source=$extract
   $children=@(Get-ChildItem -LiteralPath $extract -Force)
   if($children.Count -eq 1 -and $children[0].PSIsContainer){$source=$children[0].FullName}
   $relative=$entry[0].FullName.Substring($source.Length).TrimStart('\')
   # The user-facing configuration uses a recorded relative executable path.
   Set-Content -LiteralPath (Join-Path $source '.entry-path') -Value $relative -Encoding ascii
   Set-Content -LiteralPath (Join-Path $source '.download-sha256') -Value $dep.Sha256 -Encoding ascii
   Move-Item -LiteralPath $source -Destination $target
  }finally{
   $resolved=[IO.Path]::GetFullPath($work)
   if($resolved.StartsWith([IO.Path]::GetFullPath($vendor).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf).StartsWith('.download-')){Remove-Item -LiteralPath $resolved -Recurse -Force}
  }
 }
 if($Action -eq 'Dependencies'){Write-Output 'Dependencies are ready.';exit 0}
 $config=Join-Path $data 'config.json'
 $exe=Join-Path $homeDir 'Nightreign-Configurator.exe'
 if($Action -eq 'Configure' -or -not (Test-Path -LiteralPath $config)){
  Write-Output 'Opening setup. Verify game and Seamless paths, then generate your selection.'
  $p=Start-Process -FilePath $exe -ArgumentList '--configure' -WorkingDirectory $homeDir -PassThru
  $p.WaitForExit()
  if($Action -eq 'Configure'){exit 0}
 }
 if(-not (Test-Path -LiteralPath $config)){throw 'Setup was not completed. Run the setup CMD first.'}
 $cfg=Get-Content -LiteralPath $config -Raw | ConvertFrom-Json
 $pwsh=Join-Path (Join-Path $vendor 'powershell') ((Get-Content -LiteralPath (Join-Path $vendor 'powershell\.entry-path') -Raw).Trim())
 if($CheckOnly){& $pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $homeDir 'Launch.ps1') -CheckOnly}
 else{& $pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $homeDir 'Launch.ps1')}
 if($LASTEXITCODE -ne 0){throw 'Launch failed. See the message above.'}
}catch{[Console]::Error.WriteLine($_.Exception.Message);exit 1}
finally{if($locked){$mutex.ReleaseMutex()};if($null -ne $mutex){$mutex.Dispose()}}
