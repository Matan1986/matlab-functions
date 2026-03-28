param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ScriptPath,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$RequiredOutputs,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

function Resolve-AbsolutePath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    try {
        $resolved = Resolve-Path -LiteralPath $PathValue -ErrorAction Stop
        $full = [System.IO.Path]::GetFullPath($resolved.Path)
    }
    catch {
        $full = [System.IO.Path]::GetFullPath($PathValue)
    }

    return ($full -replace '\\', '/')
}

function Get-Sha256HexFromBytes {
    param([byte[]]$Bytes)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash($Bytes)
    }
    finally {
        $sha.Dispose()
    }

    return ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
}

function Get-Sha256HexFromText {
    param([string]$Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    return Get-Sha256HexFromBytes -Bytes $bytes
}

function ConvertTo-RequiredOutputs {
    param([string]$InlineValue)

    $raw = $InlineValue
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $raw = $env:REQUIRED_OUTPUTS
    }

    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    $parts = $raw -split '[;,\r\n]'
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($p in $parts) {
        $trimmed = $p.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            $items.Add((Resolve-AbsolutePath -PathValue $trimmed))
        }
    }

    return $items | Sort-Object -Unique
}

function Get-OptionalParameterSummary {
    param([string[]]$ExtraArguments)

    if (-not $ExtraArguments -or $ExtraArguments.Count -eq 0) {
        return ''
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($a in $ExtraArguments) {
        if ([string]::IsNullOrWhiteSpace($a)) {
            continue
        }

        $trimmed = $a.Trim()
        if ($trimmed.Contains('=')) {
            $candidates.Add($trimmed)
        }
    }

    if ($candidates.Count -eq 0) {
        return ''
    }

    return (($candidates | Sort-Object -Unique) -join ';')
}

function Get-RepoRoot {
    $scriptDirectory = Split-Path -Parent $PSCommandPath
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $scriptDirectory '..'))
    return $candidate
}

$created = $false
$duplicate = $false

try {
    $repoRoot = Get-RepoRoot
    $fingerprintsDir = Join-Path $repoRoot 'runs\fingerprints'
    New-Item -ItemType Directory -Path $fingerprintsDir -Force | Out-Null

    $normalizedScriptPath = Resolve-AbsolutePath -PathValue $ScriptPath
    $requiredOutputsList = ConvertTo-RequiredOutputs -InlineValue $RequiredOutputs
    $optionalSummary = Get-OptionalParameterSummary -ExtraArguments $ExtraArgs

    $scriptBytes = [System.IO.File]::ReadAllBytes($normalizedScriptPath)
    $scriptHash = Get-Sha256HexFromBytes -Bytes $scriptBytes

    $fingerprintMaterial = @(
        "script_path=$normalizedScriptPath"
        "script_hash=$scriptHash"
        "required_outputs=$($requiredOutputsList -join '|')"
        "optional_parameters=$optionalSummary"
    ) -join "`n"

    $fingerprintHash = Get-Sha256HexFromText -Text $fingerprintMaterial
    $fingerprintFile = Join-Path $fingerprintsDir ("fingerprint_{0}.json" -f $fingerprintHash)

    if (Test-Path -LiteralPath $fingerprintFile) {
        $duplicate = $true
        $created = $false
    }
    else {
        $payload = [ordered]@{
            fingerprint = $fingerprintHash
            script_path = $normalizedScriptPath
            script_hash = $scriptHash
            fingerprint_valid = $true
            required_outputs = @($requiredOutputsList)
            timestamp = [DateTime]::UtcNow.ToString('o')
            duplicate_detected = $false
        }

        $json = $payload | ConvertTo-Json -Depth 4
        [System.IO.File]::WriteAllText($fingerprintFile, $json, [System.Text.Encoding]::UTF8)
        $created = $true
    }
}
catch {
    try {
        $repoRoot = Get-RepoRoot
        $fingerprintsDir = Join-Path $repoRoot 'runs\fingerprints'
        New-Item -ItemType Directory -Path $fingerprintsDir -Force | Out-Null

        $normalizedScriptPath = Resolve-AbsolutePath -PathValue $ScriptPath
        $requiredOutputsList = ConvertTo-RequiredOutputs -InlineValue $RequiredOutputs
        $optionalSummary = Get-OptionalParameterSummary -ExtraArguments $ExtraArgs

        $fallbackScriptHash = ''
        if ($normalizedScriptPath -and (Test-Path -LiteralPath $normalizedScriptPath)) {
            $fallbackScriptHash = Get-Sha256HexFromBytes -Bytes ([System.IO.File]::ReadAllBytes($normalizedScriptPath))
        }

        $fallbackMaterial = @(
            "script_path=$normalizedScriptPath"
            "script_hash=$fallbackScriptHash"
            "required_outputs=$($requiredOutputsList -join '|')"
            "optional_parameters=$optionalSummary"
            "error_marker=fallback"
        ) -join "`n"

        $fingerprintHash = Get-Sha256HexFromText -Text $fallbackMaterial
        $fingerprintFile = Join-Path $fingerprintsDir ("fingerprint_{0}.json" -f $fingerprintHash)

        if (-not (Test-Path -LiteralPath $fingerprintFile)) {
            $fingerprintValid = $true
            if ([string]::IsNullOrWhiteSpace($normalizedScriptPath)) {
                $fingerprintValid = $false
            }
            elseif (-not (Test-Path -LiteralPath $normalizedScriptPath)) {
                $fingerprintValid = $false
            }
            elseif ([string]::IsNullOrWhiteSpace($fallbackScriptHash)) {
                $fingerprintValid = $false
            }

            $payload = [ordered]@{
                fingerprint = $fingerprintHash
                script_path = $normalizedScriptPath
                script_hash = $fallbackScriptHash
                fingerprint_valid = $fingerprintValid
                required_outputs = @($requiredOutputsList)
                timestamp = [DateTime]::UtcNow.ToString('o')
                duplicate_detected = $false
            }

            $json = $payload | ConvertTo-Json -Depth 4
            [System.IO.File]::WriteAllText($fingerprintFile, $json, [System.Text.Encoding]::UTF8)
            $created = $true
        }
        else {
            $created = $false
        }

        $duplicate = $false
    }
    catch {
        $created = $false
        $duplicate = $false
    }
}
finally {
    Write-Output ("FINGERPRINT_CREATED={0}" -f ($(if ($created) { 'YES' } else { 'NO' })))
    Write-Output ("DUPLICATE_RUN_DETECTED={0}" -f ($(if ($duplicate) { 'YES' } else { 'NO' })))
}

exit 0