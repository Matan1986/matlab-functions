# Phase 6C — Mapping execution (read-only inputs; writes output tables + report only)
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..') | Select-Object -ExpandProperty Path
if (-not (Test-Path (Join-Path $root 'tables'))) {
  $root = (Get-Location).Path
}

function Get-Suffix([string]$analysisId) {
  if ($analysisId -match '^A6A1_(\d+)$') { return [int]$Matches[1] }
  return $null
}

function Get-IntervalScore {
  param([int]$aMin, [int]$aMax, [int]$bMin, [int]$bMax)
  $lo = [Math]::Max($aMin, $bMin)
  $hi = [Math]::Min($aMax, $bMax)
  $inter = if ($lo -le $hi) { $hi - $lo + 1 } else { 0 }
  $lenA = $aMax - $aMin + 1
  $lenB = $bMax - $bMin + 1
  $union = $lenA + $lenB - $inter
  if ($union -le 0) { return 0 }
  return [double]$inter / [double]$union
}

$cleanPath = Join-Path $root 'tables\phase6A4_unit_mapping_clean.csv'
$lostPath = Join-Path $root 'tables\phase6_mapping_lost_ids.csv'
$relPath = Join-Path $root 'tables\phase6_mapping_relationship_analysis.csv'
$clusterPath = Join-Path $root 'tables\phase6_cluster_comparison.csv'
$refinedPath = Join-Path $root 'tables\phase6A4_unit_mapping_refined.csv'
$unitsPath = Join-Path $root 'tables\phase6A4_analysis_units_refined.csv'

$clean = Import-Csv $cleanPath
$lost = Import-Csv $lostPath
$relMap = @{}
Import-Csv $relPath | ForEach-Object { $relMap[$_.analysis_id] = $_ }
$clusterRows = Import-Csv $clusterPath
$clusterByAU = @{}
foreach ($r in $clusterRows) { $clusterByAU[$r.AU_cluster] = $r }
$refined = Import-Csv $refinedPath
$validUnits = @{}
Import-Csv $unitsPath | ForEach-Object { $validUnits[$_.analysis_unit_id] = $true }

# Canonical rows for nearest-neighbor (all A6A4_* from clean, including NOISE)
$canon = New-Object System.Collections.Generic.List[object]
foreach ($row in $clean) {
  $u = $row.analysis_unit_id
  if ($u -match '^A6A4_') {
    $s = Get-Suffix $row.analysis_id
    if ($null -ne $s) { [void]$canon.Add([pscustomobject]@{ Unit = $u; Suffix = $s }) }
  }
}

# Per-unit min/max suffix for interval overlap (refined)
$unitMin = @{}
$unitMax = @{}
foreach ($row in $refined) {
  $u = $row.analysis_unit_id
  $s = Get-Suffix $row.analysis_id
  if ($null -eq $s) { continue }
  if (-not $unitMin.ContainsKey($u)) { $unitMin[$u] = $s; $unitMax[$u] = $s }
  else {
    if ($s -lt $unitMin[$u]) { $unitMin[$u] = $s }
    if ($s -gt $unitMax[$u]) { $unitMax[$u] = $s }
  }
}

function Get-Candidates([int]$n) {
  $dMin = [int]::MaxValue
  foreach ($c in $canon) {
    $d = [Math]::Abs($n - $c.Suffix)
    if ($d -lt $dMin) { $dMin = $d }
  }
  $units = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($c in $canon) {
    if ([Math]::Abs($n - $c.Suffix) -eq $dMin) { [void]$units.Add($c.Unit) }
  }
  $sorted = [string[]]($units | Sort-Object)
  return @{ Distance = $dMin; Units = $sorted }
}

$ambiguous = New-Object System.Collections.Generic.List[object]
$mapped = New-Object System.Collections.Generic.List[object]
$nearestCount = 0
$fallbackCount = 0
$ruleViolation = $false

foreach ($row in ($lost | Sort-Object { $_.analysis_id })) {
  $aid = $row.analysis_id
  $src = $row.original_unit_id
  $n = Get-Suffix $aid
  if ($null -eq $n) {
    $ruleViolation = $true
    [void]$ambiguous.Add([pscustomobject]@{
        analysis_id = $aid
        candidate_units = ''
        reason = 'no_valid_candidate'
      })
    continue
  }
  $auCluster = $src
  if (-not $relMap.ContainsKey($aid)) {
    $ruleViolation = $true
    [void]$ambiguous.Add([pscustomobject]@{
        analysis_id = $aid
        candidate_units = ''
        reason = 'no_valid_candidate'
      })
    continue
  }

  $info = Get-Candidates $n
  $dMin = $info.Distance
  $cands = $info.Units
  $candStr = ($cands -join '|')

  if ($cands.Count -eq 0) {
    [void]$ambiguous.Add([pscustomobject]@{
        analysis_id = $aid
        candidate_units = $candStr
        reason = 'no_valid_candidate'
      })
    continue
  }

  # Single candidate
  if ($cands.Count -eq 1) {
    $u = $cands[0]
    if ($u -eq 'A6A4_NOISE') {
      $cr = $clusterByAU[$auCluster]
      if ($null -eq $cr -or [string]::IsNullOrWhiteSpace($cr.closest_A6A4_cluster)) {
        [void]$ambiguous.Add([pscustomobject]@{
            analysis_id = $aid
            candidate_units = 'A6A4_NOISE'
            reason = 'fallback_missing'
          })
        continue
      }
      $target = $cr.closest_A6A4_cluster.Trim()
      if (-not $validUnits.ContainsKey($target)) {
        $ruleViolation = $true
        [void]$ambiguous.Add([pscustomobject]@{
            analysis_id = $aid
            candidate_units = $target
            reason = 'fallback_missing'
          })
        continue
      }
      $fallbackCount++
      $distOut = $cr.similarity_score
      [void]$mapped.Add([pscustomobject]@{
          analysis_id = $aid
          analysis_unit_id = $target
          source_unit_id = $src
          mapping_method = 'fallback'
          distance = $distOut
        })
      continue
    }
    if (-not $validUnits.ContainsKey($u)) {
      $ruleViolation = $true
      [void]$ambiguous.Add([pscustomobject]@{
          analysis_id = $aid
          candidate_units = $u
          reason = 'no_valid_candidate'
        })
      continue
    }
    $nearestCount++
    [void]$mapped.Add([pscustomobject]@{
        analysis_id = $aid
        analysis_unit_id = $u
        source_unit_id = $src
        mapping_method = 'nearest'
        distance = [string]$dMin
      })
    continue
  }

  # Multiple candidates — tie-break by cluster interval score (max score wins)
  if (-not $unitMin.ContainsKey($auCluster)) {
    [void]$ambiguous.Add([pscustomobject]@{
        analysis_id = $aid
        candidate_units = $candStr
        reason = 'no_valid_candidate'
      })
    continue
  }
  $aMin = $unitMin[$auCluster]
  $aMax = $unitMax[$auCluster]

  $scores = @{}
  foreach ($cu in $cands) {
    if (-not $unitMin.ContainsKey($cu)) {
      $scores[$cu] = -1
      continue
    }
    $bMin = $unitMin[$cu]
    $bMax = $unitMax[$cu]
    $scores[$cu] = Get-IntervalScore $aMin $aMax $bMin $bMax
  }
  $maxScore = ($scores.Values | Measure-Object -Maximum).Maximum
  $winners = [string[]]($cands | Where-Object { $scores[$_] -eq $maxScore } | Sort-Object)

  if ($winners.Count -ne 1) {
    [void]$ambiguous.Add([pscustomobject]@{
        analysis_id = $aid
        candidate_units = $candStr
        reason = 'tie'
      })
    continue
  }
  $w = $winners[0]
  if (-not $validUnits.ContainsKey($w)) {
    $ruleViolation = $true
    [void]$ambiguous.Add([pscustomobject]@{
        analysis_id = $aid
        candidate_units = $candStr
        reason = 'no_valid_candidate'
      })
    continue
  }
  $nearestCount++
  [void]$mapped.Add([pscustomobject]@{
      analysis_id = $aid
      analysis_unit_id = $w
      source_unit_id = $src
      mapping_method = 'nearest'
      distance = [string]$dMin
    })
}

# Build reintegrated output: clean rows + new mappings
$outRows = New-Object System.Collections.Generic.List[object]
foreach ($row in $clean) {
  [void]$outRows.Add([pscustomobject]@{
      analysis_id = $row.analysis_id
      analysis_unit_id = $row.analysis_unit_id
      source_unit_id = ''
      mapping_method = ''
      distance = ''
    })
}
foreach ($m in ($mapped | Sort-Object analysis_id)) {
  [void]$outRows.Add($m)
}

$totalLost = $lost.Count
$totalMapped = $mapped.Count
$ambigCount = $ambiguous.Count

$refinedIds = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($r in $refined) { [void]$refinedIds.Add($r.analysis_id) }
$totalUniverse = $refinedIds.Count
$canonicalOnly = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($r in $clean) { [void]$canonicalOnly.Add($r.analysis_id) }
$coverageAfter = [math]::Round(($canonicalOnly.Count + $totalMapped) / [double]$totalUniverse, 6)

$ready = if ($ruleViolation) { 'NO' } else { 'YES' }

$reintPath = Join-Path $root 'tables\phase6A4_unit_mapping_reintegrated.csv'
$ambigPath = Join-Path $root 'tables\phase6_mapping_ambiguous.csv'
$statusPath = Join-Path $root 'tables\phase6_mapping_execution_status.csv'

$outRows | Export-Csv -Path $reintPath -NoTypeInformation -Encoding UTF8
if ($ambiguous.Count -eq 0) {
  Set-Content -Path $ambigPath -Value '"analysis_id","candidate_units","reason"' -Encoding utf8
} else {
  $ambiguous | Sort-Object analysis_id | Export-Csv -Path $ambigPath -NoTypeInformation -Encoding UTF8
}
[pscustomobject]@{
  TOTAL_LOST_IDS = $totalLost
  TOTAL_MAPPED = $totalMapped
  AMBIGUOUS_COUNT = $ambigCount
  COVERAGE_AFTER_MAPPING = $coverageAfter
  READY_FOR_AUDIT = $ready
} | Export-Csv -Path $statusPath -NoTypeInformation -Encoding UTF8

Write-Host "TOTAL_LOST_IDS=$totalLost TOTAL_MAPPED=$totalMapped AMBIGUOUS=$ambigCount NEAREST=$nearestCount FALLBACK=$fallbackCount COVERAGE=$coverageAfter READY=$ready"
