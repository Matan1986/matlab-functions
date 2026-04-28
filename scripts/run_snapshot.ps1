$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot = 'C:\Dev\matlab-functions'
$outDir   = 'L:\My Drive\For agents\snapshot'
$finalZip = Join-Path $outDir 'auto\snapshot_repo.zip'
$finalDir = Split-Path -Path $finalZip -Parent

$tempRoot = 'C:\temp'
if (-not (Test-Path -LiteralPath $tempRoot)) {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
}

$runId     = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$stageRoot = Join-Path 'C:' ("s_" + $runId)
$tmpZip    = $null
$lockStream = $null
$lockFile = Join-Path $tempRoot 'snapshot.lock'

if (Test-Path -LiteralPath $lockFile) {
    $lockAgeMinutes = ((Get-Date) - (Get-Item -LiteralPath $lockFile).LastWriteTime).TotalMinutes
    if ($lockAgeMinutes -gt 30) {
        Write-Warning ("Removing stale snapshot lock older than 30 minutes: " + $lockFile)
        Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
    }
}

try {
    $lockStream = [System.IO.File]::Open(
        $lockFile,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
}
catch {
    throw "Snapshot already running (lock exists)"
}

Write-Output "=== SNAPSHOT START [$runId] ==="

function Copy-ModuleItems {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [string[]]$DirNames = @(),

        [string[]]$FileNames = @(),

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$ModuleStage
    )

    $destRoot = Join-Path $ModuleStage $ModuleName
    New-Item -ItemType Directory -Path $destRoot -Force | Out-Null

    foreach ($d in $DirNames) {
        $src = Join-Path $RepoRoot $d
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $destRoot $d) -Recurse -Force
        }
    }

    foreach ($f in $FileNames) {
        $src = Join-Path $RepoRoot $f
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $destRoot $f) -Force
        }
    }
}

function Get-ArchiveSourceItems {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir
    )

    $items = Get-ChildItem -LiteralPath $SourceDir -Force |
             Sort-Object FullName |
             Select-Object -ExpandProperty FullName
    if (-not $items -or $items.Count -eq 0) {
        throw "Archive source is empty: $SourceDir"
    }

    return @($items)
}

function Test-ZipReadable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath
    )

    if (-not (Test-Path -LiteralPath $ZipPath)) {
        throw "Zip not found: $ZipPath"
    }

    $zipObj = $null
    try {
        $zipObj = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        if ($null -eq $zipObj) {
            throw "Failed to open zip: $ZipPath"
        }
    }
    finally {
        if ($null -ne $zipObj) {
            $zipObj.Dispose()
        }
    }
}

function Get-ZipEntriesNormalized {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath
    )

    $zipObj = $null
    try {
        $zipObj = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        return @(
            $zipObj.Entries | ForEach-Object {
                $_.FullName -replace '\\','/'
            }
        )
    }
    finally {
        if ($null -ne $zipObj) {
            $zipObj.Dispose()
        }
    }
}

function Assert-JsonHasRequiredFields {
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonPath,

        [Parameter(Mandatory = $true)]
        [string[]]$RequiredFields
    )

    if (-not (Test-Path -LiteralPath $JsonPath)) {
        throw "JSON file not found: $JsonPath"
    }

    if ((Get-Item -LiteralPath $JsonPath).Length -le 2) {
        throw "JSON file is empty or too small: $JsonPath"
    }

    $obj = $null
    try {
        $obj = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "JSON is invalid: $JsonPath"
    }

    foreach ($field in $RequiredFields) {
        $prop = $obj.PSObject.Properties[$field]
        if ($null -eq $prop) {
            throw "Required JSON field missing in $JsonPath : $field"
        }

        $value = $prop.Value
        if ($null -eq $value) {
            throw "Required JSON field is null in $JsonPath : $field"
        }

        if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
            throw "Required JSON field is empty in $JsonPath : $field"
        }

        if ($value -is [System.Array] -and $value.Count -eq 0) {
            throw "Required JSON array is empty in $JsonPath : $field"
        }
    }
}

try {
    # --- PRECHECKS ---
    if (-not (Test-Path -LiteralPath $repoRoot)) {
        throw "Repository root not found: $repoRoot"
    }

    if (-not (Test-Path -LiteralPath $finalDir)) {
        New-Item -ItemType Directory -Path $finalDir -Force | Out-Null
    }

    if (Test-Path -LiteralPath $stageRoot) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }

    # --- STAGING ---
    $moduleStage = Join-Path $stageRoot 'm'
    $metaStage   = Join-Path $stageRoot 'META'
    $payload     = Join-Path $stageRoot 'payload'

    New-Item -ItemType Directory -Path $stageRoot   -Force | Out-Null
    New-Item -ItemType Directory -Path $moduleStage -Force | Out-Null
    New-Item -ItemType Directory -Path $metaStage   -Force | Out-Null
    New-Item -ItemType Directory -Path $payload     -Force | Out-Null

    # --- MODULE DEFINITIONS ---
    $unifiedDirs = @(
        'Aging',
        'Switching',
        'Relaxation ver3',
        'analysis'
    )

    $experimentalDirs = @(
        'AC HC MagLab ver8',
        'ARPES ver1',
        'FieldSweep ver3',
        'MH ver1',
        'MT ver2',
        'PS ver4',
        'Resistivity MagLab ver1',
        'Resistivity ver6',
        'Susceptibility ver1',
        'zfAMR ver11'
    )

    $visualizationCandidates = @(
        'GUIs',
        'General ver2',
        'github_repo'
    )

    $visualizationDirs = @(
        $visualizationCandidates | Where-Object {
            Test-Path -LiteralPath (Join-Path $repoRoot $_)
        }
    )

    $allRootDirs = Get-ChildItem -LiteralPath $repoRoot -Directory -Force |
        Select-Object -ExpandProperty Name

    $coreDirs = @(
        $allRootDirs | Where-Object {
            ($_ -notin $unifiedDirs) -and
            ($_ -notin $experimentalDirs) -and
            ($_ -notin $visualizationDirs)
        }
    )

    $rootFiles = Get-ChildItem -LiteralPath $repoRoot -File -Force |
        Select-Object -ExpandProperty Name

    # --- BUILD MODULE STAGING ---
    Copy-ModuleItems -ModuleName 'unified_stack' `
                     -DirNames $unifiedDirs `
                     -FileNames @() `
                     -RepoRoot $repoRoot `
                     -ModuleStage $moduleStage

    Copy-ModuleItems -ModuleName 'experimental_pipelines' `
                     -DirNames $experimentalDirs `
                     -FileNames @() `
                     -RepoRoot $repoRoot `
                     -ModuleStage $moduleStage

    Copy-ModuleItems -ModuleName 'core_infra' `
                     -DirNames $coreDirs `
                     -FileNames $rootFiles `
                     -RepoRoot $repoRoot `
                     -ModuleStage $moduleStage

    $includeVisualization = $visualizationDirs.Count -gt 0
    if ($includeVisualization) {
        Copy-ModuleItems -ModuleName 'visualization_stack' `
                         -DirNames $visualizationDirs `
                         -FileNames @() `
                         -RepoRoot $repoRoot `
                         -ModuleStage $moduleStage
    }

    $moduleNames = @(
        'core_infra',
        'unified_stack',
        'experimental_pipelines'
    )

    if ($includeVisualization) {
        $moduleNames += 'visualization_stack'
    }

    # --- ZIP MODULES ---
    foreach ($m in $moduleNames) {
        $zipPath = Join-Path $stageRoot ("$m.zip")
        $srcPath = Join-Path $moduleStage $m

        if (-not (Test-Path -LiteralPath $srcPath)) {
            throw "Module staging path missing: $srcPath"
        }

        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force
        }

        $moduleItems = Get-ArchiveSourceItems -SourceDir $srcPath

        Compress-Archive -LiteralPath $moduleItems `
                         -DestinationPath $zipPath `
                         -CompressionLevel Optimal `
                         -Force

        if (-not (Test-Path -LiteralPath $zipPath)) {
            throw "Module zip not created: $zipPath"
        }

        $moduleZipSize = (Get-Item -LiteralPath $zipPath).Length
        if ($moduleZipSize -le 0) {
            throw "Module zip is empty: $zipPath"
        }

        Test-ZipReadable -ZipPath $zipPath
    }

    # --- META BUILD ---
    $now = (Get-Date).ToString('o')

    $manifest = [ordered]@{
        schema_version   = '1.0'
        generated_by     = 'snapshot_system_v1'
        timestamp        = $now
        source_path      = $repoRoot
        output_path      = $finalZip
        included_modules = $moduleNames
    }

    $snapshotInfo = [ordered]@{
        created_at   = $now
        module_count = $moduleNames.Count
        modules      = @()
    }

    foreach ($m in $moduleNames) {
        $zipPath = Join-Path $stageRoot ("$m.zip")

        $snapshotInfo.modules += [ordered]@{
            module     = $m
            zip_name   = (Split-Path -Path $zipPath -Leaf)
            size_bytes = (Get-Item -LiteralPath $zipPath).Length
        }
    }

    $manifestPath     = Join-Path $metaStage 'manifest.json'
    $snapshotInfoPath = Join-Path $metaStage 'snapshot_info.json'

    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $snapshotInfo | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $snapshotInfoPath -Encoding UTF8

    Assert-JsonHasRequiredFields -JsonPath $manifestPath -RequiredFields @(
        'schema_version',
        'generated_by',
        'timestamp',
        'source_path',
        'output_path',
        'included_modules'
    )

    Assert-JsonHasRequiredFields -JsonPath $snapshotInfoPath -RequiredFields @(
        'created_at',
        'module_count',
        'modules'
    )

    # --- BUILD PAYLOAD ---
    foreach ($m in $moduleNames) {
        $srcZip  = Join-Path $stageRoot ("$m.zip")
        $destZip = Join-Path $payload ("$m.zip")

        Copy-Item -LiteralPath $srcZip -Destination $destZip -Force
    }

    $payloadMeta = Join-Path $payload 'META'
    New-Item -ItemType Directory -Path $payloadMeta -Force | Out-Null

    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $payloadMeta 'manifest.json') -Force
    Copy-Item -LiteralPath $snapshotInfoPath -Destination (Join-Path $payloadMeta 'snapshot_info.json') -Force

    # --- CREATE TMP ZIP ---
    $finalBaseName = [System.IO.Path]::GetFileNameWithoutExtension($finalZip)
    $tmpZip = Join-Path $finalDir ($finalBaseName + "_$runId.tmp.zip")

    if (Test-Path -LiteralPath $tmpZip) {
        Remove-Item -LiteralPath $tmpZip -Force
    }

    $payloadItems = Get-ArchiveSourceItems -SourceDir $payload

    Compress-Archive -LiteralPath $payloadItems `
                     -DestinationPath $tmpZip `
                     -CompressionLevel Optimal `
                     -Force

    if (-not (Test-Path -LiteralPath $tmpZip)) {
        throw "Temporary zip was not created."
    }

    $zipSize = (Get-Item -LiteralPath $tmpZip).Length
    if ($zipSize -lt 1MB) {
        throw "Zip too small ($zipSize bytes)"
    }

    Test-ZipReadable -ZipPath $tmpZip

    # --- FAST VALIDATION ---
    Write-Output "Fast validation..."

    $entries = Get-ZipEntriesNormalized -ZipPath $tmpZip

    $required = @(
        'core_infra.zip',
        'unified_stack.zip',
        'experimental_pipelines.zip',
        'META/manifest.json',
        'META/snapshot_info.json'
    )

    $missing = @()

    foreach ($r in $required) {
        if ($entries -notcontains $r) {
            $missing += $r
        }
    }

    if ($includeVisualization -and ($entries -notcontains 'visualization_stack.zip')) {
        $missing += 'visualization_stack.zip'
    }

    if ($missing.Count -gt 0) {
        throw ("Validation failed: " + ($missing -join ', '))
    }

    # --- ATOMIC REPLACE ---
    Move-Item -LiteralPath $tmpZip -Destination $finalZip -Force

    Write-Output "=== SNAPSHOT SUCCESS ==="
    Write-Output "Snapshot created: $finalZip"

    Write-Output "Building snapshot_simple bundles..."
    try {
        .\scripts\build_snapshot_simple.ps1
    }
    catch {
        Write-Warning ("snapshot_simple build failed: " + $_.Exception.Message)
    }
}
finally {
    if ($lockStream) {
        $lockStream.Close()
    }
    if (Test-Path $lockFile) {
        Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    }

    if ($null -ne $tmpZip -and (Test-Path -LiteralPath $tmpZip)) {
        try {
            Remove-Item -LiteralPath $tmpZip -Force
        }
        catch {
            Write-Warning "Temporary zip cleanup failed: $tmpZip"
        }
    }

    if (Test-Path -LiteralPath $stageRoot) {
        try {
            Remove-Item -LiteralPath $stageRoot -Recurse -Force
        }
        catch {
            Write-Warning "Cleanup failed: $stageRoot"
        }
    }
}

Write-Output "Updating context bundles..."
try {
.\scripts\update_context.ps1
}
catch {
Write-Warning "Context update failed"
}
