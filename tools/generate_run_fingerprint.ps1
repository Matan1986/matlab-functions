param([string]$ScriptPath)

$repo = Get-Location
$fpDir = Join-Path $repo 'runs/fingerprints'

try {
  $h = Get-FileHash -LiteralPath $ScriptPath -Algorithm SHA256
  $inputBytes = [Text.Encoding]::UTF8.GetBytes($ScriptPath + $h.Hash)
  $sha = [Security.Cryptography.SHA256]::Create()
  $fp = ([BitConverter]::ToString($sha.ComputeHash($inputBytes))).Replace('-', '').ToLower()
  
  if (!(Test-Path $fpDir)) {
    New-Item -ItemType Directory -Path $fpDir -Force | Out-Null
  }
  
  $file = Join-Path $fpDir ('fingerprint_' + $fp + '.txt')
  
  if (Test-Path $file) {
    Write-Output 'DUPLICATE_RUN=YES'
  } else {
    @(
      ('SCRIPT_PATH=' + $ScriptPath),
      ('SCRIPT_CONTENT_HASH=' + $h.Hash),
      ('FINGERPRINT=' + $fp),
      ('CREATED_UTC=' + (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ'))
    ) | Set-Content -LiteralPath $file
    Write-Output 'DUPLICATE_RUN=NO'
  }
  
  Write-Output 'FINGERPRINT_CREATED=YES'
} catch {
  Write-Output 'FINGERPRINT_CREATED=NO'
  Write-Output 'DUPLICATE_RUN=NO'
}
