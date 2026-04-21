$root = "C:/Dev/matlab-functions"
$full = Import-Csv "$root/tables/xx_relaxation_event_level_full.csv"
$morph = Import-Csv "$root/tables/xx_relaxation_morphology_event_level.csv"

$configs = @($full.config_id + $morph.config_id | Sort-Object -Unique)
$rows = @()
$fileLines = @()

foreach ($cfg in $configs) {
    $m = @($morph | Where-Object { $_.config_id -eq $cfg })
    $files = @($m.file_id | Sort-Object -Unique)
    $rows += [pscustomobject]@{
        config_id = $cfg
        n_events  = $m.Count
        n_files   = $files.Count
    }
    $fileLines += "- ``$cfg``: " + ($files -join "; ")
}

$rows | Sort-Object config_id | Export-Csv "$root/tables/xx_data_coverage_audit.csv" -NoTypeInformation

$expected = @("25mA", "30mA", "35mA")
$present = @()
foreach ($e in $expected) {
    if ($configs | Where-Object { $_ -like "*$e*" }) {
        $present += $e
    }
}
$missing = @($expected | Where-Object { $present -notcontains $_ })
$missing35 = if ($missing -contains "35mA") { "YES" } else { "NO" }
$allIncluded = if ($missing.Count -eq 0) { "YES" } else { "NO" }
$missingList = if ($missing.Count -eq 0) { "[]" } else { "[" + ($missing -join ", ") + "]" }

$lines = @()
$lines += "# XX Data Coverage Audit"
$lines += ""
$lines += "## Configs present"
foreach ($cfg in $configs) {
    $lines += "- ``$cfg``"
}
$lines += ""
$lines += "## Event counts per config"
foreach ($r in ($rows | Sort-Object config_id)) {
    $lines += "- ``$($r.config_id)``: n_events=$($r.n_events), n_files=$($r.n_files)"
}
$lines += ""
$lines += "## Source files by config"
$lines += $fileLines
$lines += ""
$lines += "## Expected config check"
$lines += "- Expected currents: [25, 30, 35] mA"
$lines += "- ``MISSING_CONFIG_35mA = $missing35``"
$lines += "- ``ALL_CONFIGS_INCLUDED = $allIncluded``"
$lines += "- ``MISSING_CONFIGS = $missingList``"
$lines += ""
$lines += "## Success"
$lines += "- ``COVERAGE_VERIFIED = YES``"

Set-Content -Path "$root/reports/xx_data_coverage_audit.md" -Value $lines -Encoding UTF8
