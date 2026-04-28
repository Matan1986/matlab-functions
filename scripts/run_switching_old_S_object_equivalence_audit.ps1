# Narrow audit: recover legacy S(I,T) candidates and compare to locked canonical S_long (Switching only).
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$CanonicalRunId = 'run_2026_04_03_000147_switching_canonical',
    [double]$NumericTolMaxAbs = 1e-6,
    [double]$NumericTolRmse = 1e-7
)

$ErrorActionPreference = 'Stop'

function Test-Finite([double]$x) { (-not [double]::IsNaN($x)) -and (-not [double]::IsInfinity($x)) }

function Get-Pearson([double[]]$a, [double[]]$b) {
    $n = [math]::Min($a.Length, $b.Length)
    if ($n -lt 2) { return [double]::NaN }
    $ma = ($a[0..($n - 1)] | Measure-Object -Average).Average
    $mb = ($b[0..($n - 1)] | Measure-Object -Average).Average
    $sxy = 0.0; $sxx = 0.0; $syy = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $da = $a[$i] - $ma; $db = $b[$i] - $mb
        $sxy += $da * $db; $sxx += $da * $da; $syy += $db * $db
    }
    if ($sxx -lt 1e-30 -or $syy -lt 1e-30) { return [double]::NaN }
    return $sxy / [math]::Sqrt($sxx * $syy)
}

function Normalize-MapRow([double]$tK, [double]$iMa, [double]$sPct) {
    [pscustomobject]@{
        key_t_round4 = [math]::Round($tK, 4)
        key_i_round6 = [math]::Round($iMa, 6)
        join_key     = ([string]([math]::Round($tK, 4)) + '|' + [string]([math]::Round($iMa, 6)))
        T_K          = $tK
        current_mA   = $iMa
        S_percent    = $sPct
    }
}

function Import-CanonicalLong([string]$path) {
    $rows = @(Import-Csv $path | ForEach-Object {
        Normalize-MapRow ([double]$_.T_K) ([double]$_.current_mA) ([double]$_.S_percent)
    })
    return $rows
}

function Import-EffectiveMap([string]$path) {
    $rows = @(Import-Csv $path | ForEach-Object {
        Normalize-MapRow ([double]$_.T_K) ([double]$_.current_mA) ([double]$_.S_percent)
    })
    return $rows
}

function Import-AlignmentSamples([string]$path) {
    # Typical columns: current_mA, T_K, S_percent[, channel, ...]
    $rows = @(Import-Csv $path | ForEach-Object {
        Normalize-MapRow ([double]$_.T_K) ([double]$_.current_mA) ([double]$_.S_percent)
    })
    return $rows
}

function Build-MeanByJoinKey([object[]]$rows) {
    $g = $rows | Group-Object join_key
    $out = @()
    foreach ($gg in $g) {
        $vals = @($gg.Group | ForEach-Object { [double]$_.S_percent })
        $m = ($vals | Measure-Object -Average).Average
        $one = $gg.Group[0]
        $out += [pscustomobject]@{
            join_key   = $gg.Name
            key_t_round4 = $one.key_t_round4
            key_i_round6 = $one.key_i_round6
            T_K        = [double]$one.T_K
            current_mA = [double]$one.current_mA
            S_percent  = [double]$m
            n_samples  = $vals.Count
        }
    }
    return $out
}

$canonicalPath = Join-Path $RepoRoot "results/switching/runs/$CanonicalRunId/tables/switching_canonical_S_long.csv"
if (-not (Test-Path $canonicalPath)) {
    $alt = Join-Path $RepoRoot "results_old/switching/runs/$CanonicalRunId/tables/switching_canonical_S_long.csv"
    if (Test-Path $alt) { $canonicalPath = $alt }
}
if (-not (Test-Path $canonicalPath)) { throw "Canonical S_long not found: switching_canonical_S_long.csv under run $CanonicalRunId" }

$effectiveObsDir = Join-Path $RepoRoot 'results_old/switching/runs/run_2026_03_13_152008_switching_effective_observables'
$sourcesPath = Join-Path $effectiveObsDir 'tables/switching_effective_sources.csv'
$defaultEffectiveMap = Join-Path $effectiveObsDir 'tables/switching_effective_switching_map.csv'
$defaultAlignment = Join-Path $RepoRoot 'results_old/switching/runs/run_2026_03_10_112659_alignment_audit/alignment_audit/switching_alignment_samples.csv'

$canonicalRows = Import-CanonicalLong $canonicalPath

# --- Inventory: all candidate artifacts (glob + column/T/current coverage)
$invDetail = @()
foreach ($nm in @('switching_effective_switching_map.csv', 'switching_alignment_samples.csv', 'switching_full_scaling_parameters.csv')) {
    $prod = switch ($nm) {
        'switching_alignment_samples.csv' { 'switching_alignment_audit.m / alignment pipeline' }
        'switching_effective_switching_map.csv' { 'switching_effective_observables.m (buildMapLongTable)' }
        'switching_full_scaling_parameters.csv' { 'switching_full_scaling_collapse.m (parameters only; not S map)' }
        Default { 'unknown' }
    }
    $hintBase = switch ($nm) {
        'switching_full_scaling_parameters.csv' { 'width/peak tables; use for lineage, not S(I,T)' }
        'switching_effective_switching_map.csv' { 'long S map T_K,current_mA,S_percent' }
        Default { '' }
    }
    $searchRoots = @(Join-Path $RepoRoot 'results_old'; Join-Path $RepoRoot 'results'; Join-Path $RepoRoot 'tables'; Join-Path $RepoRoot '30_runs_evidence'; Join-Path $RepoRoot 'Switching')
    $foundFiles = @()
    foreach ($base in $searchRoots) {
        if (-not (Test-Path $base)) { continue }
        $foundFiles += @(Get-ChildItem -LiteralPath $base -Recurse -Filter $nm -ErrorAction SilentlyContinue)
    }
    foreach ($fi in $foundFiles) {
        try {
            $runId = ''
            if ($fi.FullName -match 'runs[/\\]([^/\\]+)[/\\]') { $runId = $Matches[1] }
            $rel = try { $fi.FullName.Substring($RepoRoot.Length).TrimStart('\') } catch { '' }
            $t = Import-Csv $fi.FullName
            $cols = if ($t.Count -gt 0) { (($t[0].PSObject.Properties.Name) -join ';') } else { '' }
            $tk = @(); $ci = @()
            if ($t.Count -gt 0) {
                if ($t[0].PSObject.Properties.Name -contains 'T_K') {
                    $tk = @($t | ForEach-Object { [double]$_.T_K })
                }
                if ($t[0].PSObject.Properties.Name -contains 'current_mA') {
                    $ci = @($t | ForEach-Object { [double]$_.current_mA })
                }
            }
            $ch = if ($nm -eq 'switching_alignment_samples.csv') {
                ($(if (($t.Count -gt 0) -and ($t[0].PSObject.Properties.Name -contains 'channel')) { 'channel column present' } else { 'no channel column' })) + '; metricType often P2P_percent'
            } else { $hintBase }
            $invDetail += [pscustomobject]@{
                artifact_filename = $nm
                path_relative_to_repo = $rel
                absolute_path = $fi.FullName
                inferred_source_run = $runId
                producer_pipeline = $prod
                columns = $cols
                n_rows = $t.Count
                T_K_min = if ($tk.Count) { ($tk | Measure-Object -Minimum).Minimum } else { '' }
                T_K_max = if ($tk.Count) { ($tk | Measure-Object -Maximum).Maximum } else { '' }
                n_distinct_T = if ($tk.Count) { @($tk | Sort-Object -Unique).Count } else { 0 }
                current_mA_min = if ($ci.Count) { ($ci | Measure-Object -Minimum).Minimum } else { '' }
                current_mA_max = if ($ci.Count) { ($ci | Measure-Object -Maximum).Maximum } else { '' }
                n_distinct_current = if ($ci.Count) { @($ci | Sort-Object -Unique).Count } else { 0 }
                channel_sign_normalization_hints = [string]$ch
            }
        } catch {}
    }
}
$invDetail | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_S_object_inventory.csv')

# --- Primary old long-map candidate
$oldMapPath = $defaultEffectiveMap
if (-not (Test-Path $oldMapPath)) {
    $any = @(Get-ChildItem -LiteralPath $RepoRoot -Recurse -Filter 'switching_effective_switching_map.csv' -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($any) { $oldMapPath = $any.FullName }
}

$alignmentPathForCompare = $defaultAlignment
if (Test-Path $sourcesPath) {
    $sr = Import-Csv $sourcesPath
    $al = $sr | Where-Object { $_.role -eq 'alignment_switching_map' } | Select-Object -First 1
    if ($al -and $al.source_file) {
        $p = [string]$al.source_file
        if (-not (Test-Path $p)) {
            $leaf = Split-Path $p -Leaf
            $try = @(Get-ChildItem -LiteralPath $RepoRoot -Recurse -Filter $leaf -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'alignment' } | Select-Object -First 1)
            if ($try) { $alignmentPathForCompare = $try.FullName }
        }
        else { $alignmentPathForCompare = $p }
    }
}

$oldRowsFromMap = @()
$oldRowsFromAlignMean = @()
if (Test-Path $oldMapPath) {
    $oldRowsFromMap = @(Import-EffectiveMap $oldMapPath)
}
if (Test-Path $alignmentPathForCompare) {
    $ar = @(Import-AlignmentSamples $alignmentPathForCompare)
    $oldRowsFromAlignMean = @(Build-MeanByJoinKey $ar)
}

# --- Grid overlap: canonical vs old effective map
$oldForOverlap = $oldRowsFromMap
$overlapKeys = @{}
foreach ($r in $canonicalRows) { $overlapKeys[$r.join_key] = $true }
$nCanonKeys = $overlapKeys.Count
$oldKeys = @{}
foreach ($r in $oldForOverlap) { $oldKeys[$r.join_key] = $true }
$nOldKeys = $oldKeys.Count
$intersect = 0
foreach ($k in $oldKeys.Keys) { if ($overlapKeys.ContainsKey($k)) { $intersect++ } }
$onlyCanon = $nCanonKeys - $intersect
$onlyOld = $nOldKeys - $intersect

$cTset = @($canonicalRows | ForEach-Object { $_.key_t_round4 } | Sort-Object -Unique)
$oTset = @($oldForOverlap | ForEach-Object { $_.key_t_round4 } | Sort-Object -Unique)
$oTHash = @{}
foreach ($x in $oTset) { $oTHash[[string][double]$x] = $true }
$overlapT = 0
foreach ($x in $cTset) { if ($oTHash.ContainsKey([string][double]$x)) { $overlapT++ } }

$overlapRows = @(
    [pscustomobject]@{
        comparison_pair = 'canonical_S_long_vs_old_effective_switching_map'
        canonical_table = $canonicalPath
        old_table = $oldMapPath
        n_keys_canonical = $nCanonKeys
        n_keys_old = $nOldKeys
        n_keys_intersection = $intersect
        n_keys_only_canonical = $onlyCanon
        n_keys_only_old = $onlyOld
        overlap_fraction_of_canonical = if ($nCanonKeys -gt 0) { [math]::Round($intersect / $nCanonKeys, 8) } else { 'NaN' }
        distinct_T_K_canonical = $cTset.Count
        distinct_T_K_old_map = $oTset.Count
        distinct_T_K_overlap = $overlapT
    }
)
$overlapRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_vs_canonical_S_grid_overlap.csv')

# --- Numeric diff on intersection (effective map vs canonical)
$canonByKey = @{}
foreach ($r in $canonicalRows) { $canonByKey[$r.join_key] = [double]$r.S_percent }

$diffRows = @()
$sa = New-Object System.Collections.Generic.List[double]
$sb = New-Object System.Collections.Generic.List[double]
if ($oldForOverlap.Count -gt 0) {
    foreach ($r in $oldForOverlap) {
        $k = $r.join_key
        if (-not $canonByKey.ContainsKey($k)) { continue }
        $sc = [double]$canonByKey[$k]
        $so = [double]$r.S_percent
        $d = $so - $sc
        $diffRows += [pscustomobject]@{
            join_key = $k
            T_K = $r.key_t_round4
            current_mA = $r.key_i_round6
            S_percent_canonical = $sc
            S_percent_old_effective_map = $so
            delta_S_old_minus_canonical = [math]::Round($d, 14)
        }
        [void]$sa.Add($sc); [void]$sb.Add($so)
    }
}
$maxAbs = [double]::NaN
$rmse = [double]::NaN
$meanAbs = [double]::NaN
$nP = $diffRows.Count
if ($nP -gt 0) {
    $sse = 0.0
    $sumAbs = 0.0
    $maxAbs = 0.0
    foreach ($dr in $diffRows) {
        $dv = [double]$dr.delta_S_old_minus_canonical
        if (-not (Test-Finite $dv)) { continue }
        $ad = [math]::Abs($dv)
        if ($ad -gt $maxAbs) { $maxAbs = $ad }
        $sumAbs += $ad
        $sse += $ad * $ad
    }
    $meanAbs = $sumAbs / $nP
    $rmse = [math]::Sqrt($sse / $nP)
    if ((Test-Finite $maxAbs) -and ($maxAbs -lt 1e-10)) { $rmse = 0.0; $meanAbs = 0.0 }
}
$rPearson = if ($sa.Count -ge 2) { Get-Pearson @($sa.ToArray()) @($sb.ToArray()) } else { [double]::NaN }
if (-not (Test-Finite $rPearson) -and ($sa.Count -ge 1) -and ($sa.Count -eq $sb.Count)) {
    $ident = $true
    for ($ii = 0; $ii -lt $sa.Count; $ii++) {
        if ([math]::Abs($sa[$ii] - $sb[$ii]) -gt 1e-12) { $ident = $false; break }
    }
    if ($ident) { $rPearson = 1.0 }
}

# Alignment mean-by-(T,I) vs canonical (reconstruction check)
$sa2 = New-Object System.Collections.Generic.List[double]
$sb2 = New-Object System.Collections.Generic.List[double]
$maxAbsA = [double]::NaN
$rmseA = [double]::NaN
$rPA = [double]::NaN
$nPA = 0
if ($oldRowsFromAlignMean.Count -gt 0) {
    $adsA = New-Object System.Collections.Generic.List[double]
    foreach ($r in $oldRowsFromAlignMean) {
        $k = $r.join_key
        if (-not $canonByKey.ContainsKey($k)) { continue }
        $sc = [double]$canonByKey[$k]
        $so = [double]$r.S_percent
        [void]$sa2.Add($sc); [void]$sb2.Add($so)
        [void]$adsA.Add([math]::Abs($so - $sc))
    }
    $nPA = $adsA.Count
    if ($nPA -gt 0) {
        $maxAbsA = ($adsA.ToArray() | Measure-Object -Maximum).Maximum
        $sseA = 0.0
        foreach ($a in $adsA) { $sseA += $a * $a }
        $rmseA = [math]::Sqrt($sseA / $nPA)
        $rPA = if ($sa2.Count -ge 2) { Get-Pearson @($sa2.ToArray()) @($sb2.ToArray()) } else { [double]::NaN }
    }
}

$diffSummary = @(
    [pscustomobject]@{
        comparison = 'old_effective_switching_map_vs_canonical_S_percent'
        n_paired_rows = $nP
        max_abs_delta_S = if (Test-Finite $maxAbs) { [math]::Round($maxAbs, 14) } else { 'NaN' }
        rmse_delta_S = if (Test-Finite $rmse) { [math]::Round($rmse, 14) } else { 'NaN' }
        mean_abs_delta_S = if (Test-Finite $meanAbs) { [math]::Round($meanAbs, 14) } else { 'NaN' }
        pearson_S_old_vs_S_canon = if (Test-Finite $rPearson) { [math]::Round($rPearson, 12) } else { 'NaN' }
        sign_scale_note = if ((Test-Finite $rPearson) -and ($rPearson -lt -0.9)) { 'possible sign inversion' } elseif ((Test-Finite $rPearson) -and ($rPearson -gt 0.999) -and ($maxAbs -lt $NumericTolMaxAbs)) { 'consistent with same S object' } else { 'review max_abs and correlation' }
    }
)
if (($oldRowsFromAlignMean.Count -gt 0) -and ($nPA -gt 0)) {
    $diffSummary += [pscustomobject]@{
        comparison = 'alignment_samples_mean_by_T_I_vs_canonical_S_percent'
        n_paired_rows = $nPA
        max_abs_delta_S = if (Test-Finite $maxAbsA) { [math]::Round($maxAbsA, 14) } else { 'NaN' }
        rmse_delta_S = if (Test-Finite $rmseA) { [math]::Round($rmseA, 14) } else { 'NaN' }
        mean_abs_delta_S = [math]::Round(($adsA.ToArray() | Measure-Object -Average).Average, 14)
        pearson_S_old_vs_S_canon = if (Test-Finite $rPA) { [math]::Round($rPA, 12) } else { 'NaN' }
        sign_scale_note = 'mean S_percent over duplicate alignment rows per join key'
    }
}
$diffSummary | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_vs_canonical_S_numeric_diff.csv')

# --- Verdicts / classification
$foundMap = Test-Path $oldMapPath
$foundAlign = (Test-Path $alignmentPathForCompare) -or (($invDetail | Where-Object { $_.artifact_filename -eq 'switching_alignment_samples.csv' }).Count -gt 0)
$foundAnyS = $foundMap -or $foundAlign

$gridMatch = ($onlyCanon -eq 0) -and ($onlyOld -eq 0) -and ($intersect -gt 0)
$numericMatch = (Test-Finite $maxAbs) -and (($maxAbs -le $NumericTolMaxAbs -and (Test-Finite $rmse) -and ($rmse -le $NumericTolRmse)) -or (($nP -gt 0) -and ($maxAbs -eq 0)))
if (-not (Test-Finite $maxAbs)) { $numericMatch = $false }

$equiv = if ($gridMatch -and $numericMatch) {
    'numerically_equivalent_within_tolerance'
}
elseif (($intersect -eq $nOldKeys) -and ($numericMatch)) {
    'canonical_supergrid_legacy_subset_identical_on_overlap'
}
elseif ($gridMatch -and -not $numericMatch) {
    'same_join_key_grid_but_different_S_values'
}
elseif (-not $gridMatch -and ($intersect -gt 0) -and -not $numericMatch) {
    'different_grid_or_support_partial_overlap_numeric_mismatch'
}
elseif (-not $gridMatch -and ($intersect -gt 0)) {
    'different_grid_partial_overlap_review_overlap_rows'
}
elseif (-not $foundAnyS) {
    'cannot_verify_old_S_missing'
}
else {
    'cannot_classify'
}

$equivRows = @(
    [pscustomobject]@{ verdict_key = 'OLD_S_OBJECT_EQUIVALENCE_AUDIT_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'OLD_S_OBJECT_FOUND'; verdict_value = if ($foundAnyS) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'OLD_ALIGNMENT_SAMPLES_FOUND'; verdict_value = if ($foundAlign) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'OLD_EFFECTIVE_SWITCHING_MAP_FOUND'; verdict_value = if ($foundMap) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'OLD_S_RECONSTRUCTED'; verdict_value = if ($oldRowsFromAlignMean.Count -gt 0) { 'YES_MEAN_BY_T_I_FROM_ALIGNMENT' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'OLD_AND_CANONICAL_S_GRID_MATCH'; verdict_value = if ($gridMatch) { 'YES' } elseif (($intersect -eq $nOldKeys) -and ($nOldKeys -gt 0)) { 'LEGACY_GRID_SUBSET_OF_CANONICAL' } elseif ($intersect -gt 0) { 'PARTIAL' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'OLD_AND_CANONICAL_S_NUMERICALLY_MATCH'; verdict_value = if ($numericMatch) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'OLD_AND_CANONICAL_S_EQUIVALENT'; verdict_value = if (($gridMatch) -and ($numericMatch)) { 'YES' } elseif (($intersect -eq $nOldKeys) -and ($numericMatch)) { 'YES_ON_LEGACY_COVERAGE' } elseif (($gridMatch) -and (Test-Finite $maxAbs) -and ($maxAbs -lt 1e-9)) { 'YES_FP_LEVEL' } elseif (($intersect -gt 0) -and (Test-Finite $rPearson) -and ($rPearson -gt 0.9999) -and (Test-Finite $maxAbs) -and ($maxAbs -lt 1e-5)) { 'PARTIAL' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'OLD_ANALYSIS_CAN_BE_VALIDATED_AS_RECIPES_ON_CANONICAL_S'; verdict_value = if (($gridMatch) -and ($numericMatch)) { 'YES' } elseif (($intersect -eq $nOldKeys) -and ($numericMatch)) { 'YES' } elseif (($intersect -gt 0) -and (Test-Finite $rPearson) -and ($rPearson -gt 0.999) -and (Test-Finite $maxAbs) -and ($maxAbs -lt 1e-5)) { 'PARTIAL' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'LEGACY_ARTIFACT_RECOVERY_REQUIRED'; verdict_value = if (-not $foundAnyS) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'PROVENANCE_MISMATCH_BLOCKS_OLD_ANALYSIS_VALIDATION'; verdict_value = if ($equiv -eq 'same_join_key_grid_but_different_S_values' -or $equiv -eq 'different_grid_or_support_partial_overlap_numeric_mismatch') { 'YES' } elseif ($equiv -eq 'cannot_verify_old_S_missing') { 'PARTIAL' } elseif (($intersect -eq $nOldKeys) -and ($numericMatch)) { 'NO' } else { 'PARTIAL' } }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_EVIDENCE_USED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'equivalence_classification'; verdict_value = $equiv }
)

$equivRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_S_equivalence_status.csv')

# --- Report
$rp = Join-Path $RepoRoot 'reports/switching_old_S_object_equivalence_audit.md'
$lines = @()
$lines += '# Switching old S object recovery and equivalence audit'
$lines += ''
$lines += '## Scope'
$lines += '- **Switching only.** Locked canonical run **`' + $CanonicalRunId + '`**.'
$lines += '- Canonical table: **`switching_canonical_S_long.csv`**.'
$lines += '- Legacy artifacts used **only** for recovery and numeric equivalence checks.'
$lines += ''
$lines += '## Canonical vs old effective map'
$lines += ('- **Canonical path:** `' + $canonicalPath + '`')
$lines += ('- **Primary old long-map candidate:** `' + $oldMapPath + '` (`switching_effective_observables` export).')
$lines += ('- **Alignment samples used for lineage cross-check:** `' + $alignmentPathForCompare + '`')
$lines += ('- **Paired rows (same T_K/current join key):** **' + [string]$nP + '**, **max |delta S|** **' + [string]$maxAbs + '**, **RMSE(delta)** **' + [string]$rmse + '**, **Pearson(S_old,S_canon)** **' + [string]$rPearson + '**.')
$lines += ('- **Equivalence class:** **`' + $equiv + '`**')
$lines += ''
$lines += '## Implication'
if (($gridMatch) -and ($numericMatch)) {
    $lines += '- Paired **`S_percent`** matches canonical within tolerance on the full shared grid: old pipelines that only apply **recipes/metrics** to this **S(I,T)** can be checked against the **canonical S object** without redoing the full legacy analysis.'
}
elseif (($intersect -eq $nOldKeys) -and $numericMatch) {
    $lines += '- On the **full legacy `switching_effective_switching_map` join grid**, **`S_percent`** matches canonical. The canonical run may add **extra (T, I) keys**; old analysis that only used the legacy map is still **the same S object** on the shared set.'
}
elseif ($foundAnyS -and -not $numericMatch) {
    $lines += '- Resolve **provenance** (which S build, sign, and channel) if legacy and canonical **S** differ on paired keys before treating old narratives as validated on the locked map.'
}
else {
    $lines += '- Restore legacy **`switching_alignment_samples.csv`** / **`switching_effective_switching_map.csv`** if files are missing; do not infer failure of the old analysis from absence of files alone.'
}
$lines += ''
$lines += '## Outputs'
$lines += '- `tables/switching_old_S_object_inventory.csv`'
$lines += '- `tables/switching_old_vs_canonical_S_grid_overlap.csv`'
$lines += '- `tables/switching_old_vs_canonical_S_numeric_diff.csv`'
$lines += '- `tables/switching_old_S_equivalence_status.csv`'
$lines += ''
$lines += '## Verdict table'
foreach ($er in $equivRows) {
    $lines += ('- **' + $er.verdict_key + '** = `' + $er.verdict_value + '`')
}
$lines | Set-Content -Encoding UTF8 $rp

Write-Host "Equivalence audit written: $rp"
