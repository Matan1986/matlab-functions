$ErrorActionPreference = "Stop"

$repoStatePath = "docs/repo_state.json"
$corePath = "docs/model/repo_state_description.json"
$extendedPath = "docs/model/repo_state_full_description.json"
$claimsDir = "claims"

$minimalOutPath = "docs/context_bundle.json"
$fullOutPath = "docs/context_bundle_full.json"

$state = Get-Content -Raw $repoStatePath | ConvertFrom-Json
$core = Get-Content -Raw $corePath | ConvertFrom-Json
$extended = Get-Content -Raw $extendedPath | ConvertFrom-Json

$claims = @()
if (Test-Path -LiteralPath $claimsDir) {
    $claimFiles = Get-ChildItem -LiteralPath $claimsDir -File -Filter *.json | Sort-Object Name
    foreach ($claimFile in $claimFiles) {
        $claim = Get-Content -Raw $claimFile.FullName | ConvertFrom-Json
        $claims += [ordered]@{
            claim_id = [string]$claim.claim_id
            statement = [string]$claim.statement
            status = [string]$claim.status
            role = [string]$claim.role
            confidence = [string]$claim.confidence
        }
    }
}

$timestamp = (Get-Date).ToString("o")

$minimalBundle = [ordered]@{
    version = 1
    generated_at = $timestamp
    claims = $claims
    state = $state
    model = [ordered]@{
        core = $core
    }
}

$fullBundle = [ordered]@{
    version = 1
    generated_at = $timestamp
    claims = $claims
    state = $state
    model = [ordered]@{
        core = $core
        extended = $extended
    }
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($minimalOutPath, ($minimalBundle | ConvertTo-Json -Depth 100), $utf8NoBom)
[System.IO.File]::WriteAllText($fullOutPath, ($fullBundle | ConvertTo-Json -Depth 100), $utf8NoBom)

Write-Output "Context bundles updated successfully"
