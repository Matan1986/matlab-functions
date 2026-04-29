param(
    [string]$RunId = ""
)

$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return (Split-Path $PSScriptRoot -Parent)
}

function Resolve-CanonicalRunDir {
    param(
        [string]$RunsRoot,
        [string]$RunId
    )

    if (-not (Test-Path $RunsRoot)) {
        throw "Runs root not found: $RunsRoot"
    }

    if ($RunId -and $RunId.Trim().Length -gt 0) {
        $candidate = Join-Path $RunsRoot $RunId
        if (-not (Test-Path $candidate)) {
            throw "Requested run_id not found under runs root: $RunId"
        }
        $sLong = Join-Path $candidate 'tables/switching_canonical_S_long.csv'
        if (-not (Test-Path $sLong)) {
            throw "Requested run_id does not contain switching_canonical_S_long.csv: $RunId"
        }
        return (Resolve-Path $candidate).Path
    }

    $candidates = Get-ChildItem $RunsRoot -Directory | Where-Object {
        $_.Name -like 'run_*_switching_canonical' -and
        (Test-Path (Join-Path $_.FullName 'tables/switching_canonical_S_long.csv'))
    }

    if (-not $candidates -or $candidates.Count -eq 0) {
        throw "No canonical switching runs with switching_canonical_S_long.csv were found under $RunsRoot"
    }

    $latest = $candidates |
        Sort-Object {
            (Get-Item (Join-Path $_.FullName 'tables/switching_canonical_S_long.csv')).LastWriteTimeUtc
        } -Descending |
        Select-Object -First 1

    return $latest.FullName
}

function To-DoubleOrNan {
    param([object]$Value)
    $out = 0.0
    if ([double]::TryParse([string]$Value, [ref]$out)) {
        return $out
    }
    return [double]::NaN
}

$repoRoot = Get-RepoRoot
$runsRoot = Join-Path $repoRoot 'results/switching/runs'
$runDir = Resolve-CanonicalRunDir -RunsRoot $runsRoot -RunId $RunId
$runName = Split-Path $runDir -Leaf
$tablesDir = Join-Path $runDir 'tables'

$sLongPath = Join-Path $tablesDir 'switching_canonical_S_long.csv'
$obsPath = Join-Path $tablesDir 'switching_canonical_observables.csv'
$phiPath = Join-Path $tablesDir 'switching_canonical_phi1.csv'
$p0Path = Join-Path $repoRoot 'tables/switching_P0_effective_observables_values.csv'

if (-not (Test-Path $sLongPath)) {
    throw "Missing canonical source table: $sLongPath"
}

$sLong = Import-Csv $sLongPath
if (-not $sLong -or $sLong.Count -eq 0) {
    throw "Canonical source table is empty: $sLongPath"
}

$obs = @()
if (Test-Path $obsPath) { $obs = Import-Csv $obsPath }
$phi = @()
if (Test-Path $phiPath) { $phi = Import-Csv $phiPath }

$sLongCols = @($sLong[0].PSObject.Properties.Name)
$requiredSourceCols = @('T_K','current_mA','S_percent')
foreach ($c in $requiredSourceCols) {
    if (-not ($sLongCols -contains $c)) {
        throw "Canonical S_long is missing required source column: $c"
    }
}

$identityCols = @('switching_channel_physical','channel_type') | Where-Object { $sLongCols -contains $_ }
$sourceCols = @($requiredSourceCols + $identityCols)

$sourceView = $sLong |
    Select-Object -Property $sourceCols |
    Sort-Object {[double]$_.T_K}, {[double]$_.current_mA}

$sourceOutPath = Join-Path $tablesDir 'switching_canonical_source_view.csv'
$sourceView | Export-Csv -Path $sourceOutPath -NoTypeInformation -Encoding UTF8

$ptcdfCols = @('S_model_pt_percent','PT_pdf','CDF_pt') | Where-Object { $sLongCols -contains $_ }
$ptcdfKeep = @('T_K','current_mA') + $identityCols + $ptcdfCols
$ptcdfView = foreach ($r in $sLong | Select-Object -Property $ptcdfKeep) {
    [pscustomobject]@{
        T_K = $r.T_K
        current_mA = $r.current_mA
        switching_channel_physical = $r.switching_channel_physical
        channel_type = $r.channel_type
        S_model_pt_percent = $r.S_model_pt_percent
        PT_pdf = $r.PT_pdf
        CDF_pt = $r.CDF_pt
        namespace_id = 'EXPERIMENTAL_PTCDF_DIAGNOSTIC'
        manuscript_safe = 'NO'
        forbidden_for_corrected_old_evidence = 'YES'
    }
}
$ptcdfOutPath = Join-Path $tablesDir 'switching_canonical_experimental_ptcdf_diagnostic_view.csv'
$ptcdfView | Export-Csv -Path $ptcdfOutPath -NoTypeInformation -Encoding UTF8

$kappaMap = @{}
if ($obs -and $obs.Count -gt 0) {
    foreach ($o in $obs) {
        $k = "{0}|{1}" -f [string]$o.T_K, [string]$o.switching_channel_physical
        if ($o.PSObject.Properties.Name -contains 'kappa1') {
            $kappaMap[$k] = $o.kappa1
        }
    }
}

$phiMap = @{}
if ($phi -and $phi.Count -gt 0) {
    foreach ($p in $phi) {
        $k = "{0}|{1}" -f [string]$p.current_mA, [string]$p.switching_channel_physical
        if ($p.PSObject.Properties.Name -contains 'Phi1') {
            $phiMap[$k] = $p.Phi1
        }
    }
}

$modeBaseCols = @('T_K','current_mA') + $identityCols + @('residual_percent','S_model_full_percent')
$modeBaseCols = $modeBaseCols | Where-Object { $sLongCols -contains $_ }
$modeView = foreach ($r in $sLong | Select-Object -Property $modeBaseCols) {
    $kappaKey = "{0}|{1}" -f [string]$r.T_K, [string]$r.switching_channel_physical
    $phiKey = "{0}|{1}" -f [string]$r.current_mA, [string]$r.switching_channel_physical

    $kappaVal = $null
    if ($kappaMap.ContainsKey($kappaKey)) { $kappaVal = $kappaMap[$kappaKey] }
    $phiVal = $null
    if ($phiMap.ContainsKey($phiKey)) { $phiVal = $phiMap[$phiKey] }

    $kappaNum = To-DoubleOrNan $kappaVal
    $phiNum = To-DoubleOrNan $phiVal
    $mode1 = [double]::NaN
    if (-not [double]::IsNaN($kappaNum) -and -not [double]::IsNaN($phiNum)) {
        $mode1 = $kappaNum * $phiNum
    }

    $residualNum = To-DoubleOrNan $r.residual_percent
    $residualAfter = [double]::NaN
    if (-not [double]::IsNaN($residualNum) -and -not [double]::IsNaN($mode1)) {
        $residualAfter = $residualNum - $mode1
    }

    [pscustomobject]@{
        T_K = $r.T_K
        current_mA = $r.current_mA
        switching_channel_physical = $r.switching_channel_physical
        channel_type = $r.channel_type
        residual_percent = $r.residual_percent
        S_model_full_percent = $r.S_model_full_percent
        kappa1 = $kappaVal
        Phi1 = $phiVal
        mode1_reconstruction_percent = $mode1
        residual_after_mode1_percent = $residualAfter
        namespace_id = 'DIAGNOSTIC_MODE_ANALYSIS'
        manuscript_safe = 'NO'
        forbidden_for_corrected_old_evidence = 'YES'
    }
}
$modeOutPath = Join-Path $tablesDir 'switching_canonical_diagnostic_mode_analysis_view.csv'
$modeView | Export-Csv -Path $modeOutPath -NoTypeInformation -Encoding UTF8

$effectiveRows = @()
$effectiveStatus = 'BLOCKED'
$effectiveNote = 'Validated effective observables not proven for selected canonical run.'
if (Test-Path $p0Path) {
    $p0 = Import-Csv $p0Path
    $p0Cols = @($p0[0].PSObject.Properties.Name)
    $hasRunLink = ($p0Cols -contains 'canonical_run_id')
    $rowsForRun = @()
    if ($hasRunLink) {
        $rowsForRun = $p0 | Where-Object { [string]$_.canonical_run_id -eq $runName }
    }

    if ($rowsForRun.Count -gt 0) {
        $effectiveStatus = 'VALIDATED'
        $effectiveNote = 'Matched rows found in switching_P0_effective_observables_values.csv for selected run id.'
        $effectiveRows = foreach ($e in $rowsForRun) {
            [pscustomobject]@{
                T_K = $e.T_K
                I_peak_mA = $e.I_peak_mA
                S_peak = $e.S_peak
                W_I_mA = $e.W_I_mA
                width_chosen_mA = $e.width_chosen_mA
                width_method = $e.width_method
                canonical_run_id = $e.canonical_run_id
                canonical_s_source = $e.canonical_s_source
                validation_status = 'VALIDATED'
                manuscript_safe_as_effective_observable = 'YES_CONDITIONAL'
                notes = 'Use as canonical effective observable only with matching run-link provenance.'
            }
        }
    } elseif ($obs -and $obs.Count -gt 0) {
        $effectiveStatus = 'PARTIAL'
        $effectiveNote = 'Using run observables I_peak/S_peak only; width/W validation linkage not proven for this run.'
        $effectiveRows = foreach ($o in $obs) {
            [pscustomobject]@{
                T_K = $o.T_K
                I_peak_mA = $o.I_peak
                S_peak = $o.S_peak
                W_I_mA = ''
                width_chosen_mA = ''
                width_method = ''
                canonical_run_id = $runName
                canonical_s_source = $sLongPath
                validation_status = 'PARTIAL'
                manuscript_safe_as_effective_observable = 'NO'
                notes = 'Do not treat as canonical evidence until width/W validation provenance is proven.'
            }
        }
    }
}

if (-not $effectiveRows -or $effectiveRows.Count -eq 0) {
    $effectiveRows = @(
        [pscustomobject]@{
            T_K = ''
            I_peak_mA = ''
            S_peak = ''
            W_I_mA = ''
            width_chosen_mA = ''
            width_method = ''
            canonical_run_id = $runName
            canonical_s_source = $sLongPath
            validation_status = $effectiveStatus
            manuscript_safe_as_effective_observable = 'NO'
            notes = $effectiveNote
        }
    )
}

$effectiveOutPath = Join-Path $tablesDir 'switching_canonical_effective_observables_view.csv'
$effectiveRows | Export-Csv -Path $effectiveOutPath -NoTypeInformation -Encoding UTF8

$blockedMarkerPath = Join-Path $repoRoot 'tables/switching_corrected_old_namespace_blocked_marker.csv'
$blockedMarker = @(
    [pscustomobject]@{
        namespace_id = 'CORRECTED_CANONICAL_OLD_ANALYSIS'
        authoritative_artifacts_exist = 'NO'
        build_blocked = 'YES'
        reason = 'Authoritative corrected-old artifacts do not exist yet; use separated source/diagnostic views and contracts first.'
        source_file_to_read_first = 'docs/switching_governance_persistence_manifest.md'
        updated_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
    }
)
$blockedMarker | Export-Csv -Path $blockedMarkerPath -NoTypeInformation -Encoding UTF8

$sourceForbidden = @('S_model_pt_percent','residual_percent','PT_pdf','CDF_pt','S_model_full_percent','kappa1','Phi1')
$sourceViewCols = @($sourceView[0].PSObject.Properties.Name)
$sourceHasForbidden = ($sourceForbidden | Where-Object { $sourceViewCols -contains $_ }).Count -gt 0

$diagViewsMarkedUnsafe = 'YES'
if (($ptcdfView | Where-Object { $_.manuscript_safe -ne 'NO' }).Count -gt 0) { $diagViewsMarkedUnsafe = 'NO' }
if (($modeView | Where-Object { $_.manuscript_safe -ne 'NO' }).Count -gt 0) { $diagViewsMarkedUnsafe = 'NO' }

$runtimeStatusPath = Join-Path $repoRoot 'tables/switching_canonical_output_separation_runtime_status.csv'
$runtimeStatus = @(
    [pscustomobject]@{status_key='SELECTED_CANONICAL_RUN_ID';status_value=$runName;details='Canonical run used by splitter.'},
    [pscustomobject]@{status_key='SOURCE_VIEW_CREATED';status_value='YES';details=$sourceOutPath},
    [pscustomobject]@{status_key='SOURCE_VIEW_DIAGNOSTIC_COLUMNS_REMOVED';status_value=$(if($sourceHasForbidden){'NO'}else{'YES'});details='Source view excludes model/PT/CDF/residual/phi/kappa columns.'},
    [pscustomobject]@{status_key='DIAGNOSTIC_VIEWS_CREATED';status_value='YES';details='PT/CDF diagnostic view and mode-analysis view written.'},
    [pscustomobject]@{status_key='DIAGNOSTIC_VIEWS_MARKED_NOT_MANUSCRIPT_SAFE';status_value=$diagViewsMarkedUnsafe;details='Diagnostic views explicitly labeled manuscript_safe=NO.'},
    [pscustomobject]@{status_key='EFFECTIVE_OBSERVABLE_VIEW_STATUS';status_value=$effectiveStatus;details=$effectiveNote},
    [pscustomobject]@{status_key='CORRECTED_OLD_NAMESPACE_REMAINS_BLOCKED';status_value='YES';details='Blocked marker table written.'},
    [pscustomobject]@{status_key='PHYSICS_LOGIC_CHANGED';status_value='NO';details='Post-run split only.'},
    [pscustomobject]@{status_key='FILES_DELETED';status_value='NO';details='No deletions or renames performed.'}
)
$runtimeStatus | Export-Csv -Path $runtimeStatusPath -NoTypeInformation -Encoding UTF8

Write-Output "Canonical output separation complete for run: $runName"
Write-Output "Source view: $sourceOutPath"
Write-Output "Effective observables view: $effectiveOutPath"
Write-Output "PT/CDF diagnostic view: $ptcdfOutPath"
Write-Output "Mode diagnostic view: $modeOutPath"
Write-Output "Corrected-old blocked marker: $blockedMarkerPath"
Write-Output "Runtime status: $runtimeStatusPath"
