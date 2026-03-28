$ErrorActionPreference = 'Stop'

$repo = 'C:/Dev/matlab-functions'

function Get-Quantile {
    param(
        [double[]]$Values,
        [double]$Q
    )
    if ($null -eq $Values -or $Values.Count -eq 0) {
        return [double]::NaN
    }
    $s = $Values | Sort-Object
    $n = $s.Count
    if ($n -eq 1) {
        return [double]$s[0]
    }
    $pos = ($n - 1) * $Q
    $lo = [math]::Floor($pos)
    $hi = [math]::Ceiling($pos)
    if ($lo -eq $hi) {
        return [double]$s[$lo]
    }
    return [double]$s[$lo] + ($pos - $lo) * ([double]$s[$hi] - [double]$s[$lo])
}

$maps = Get-ChildItem -Path ($repo + '/results/switching/runs') -Recurse -File -Filter 'map_pair_metrics.csv' |
    Sort-Object LastWriteTime -Descending

$tablesDir = $null
foreach ($m in $maps) {
    $d = $m.DirectoryName
    if ((Test-Path ($d + '/observable_pair_by_temperature.csv')) -and ((Get-ChildItem $d -File -Filter 'variant_observables_*.csv').Count -gt 0)) {
        $tablesDir = $d
        break
    }
}

if (-not $tablesDir) {
    throw 'No complete robustness input set found.'
}

$map = Import-Csv ($tablesDir + '/map_pair_metrics.csv')
$pairByT = Import-Csv ($tablesDir + '/observable_pair_by_temperature.csv')
$varFiles = Get-ChildItem $tablesDir -File -Filter 'variant_observables_*.csv'

$vars = @()
foreach ($vf in $varFiles) {
    $vars += Import-Csv $vf.FullName
}

$vdict = @{}
foreach ($r in $vars) {
    $k = $r.variant + '|' + ([double]$r.T_K)
    if (-not $vdict.ContainsKey($k)) {
        $vdict[$k] = [pscustomobject]@{
            variant = $r.variant
            T = [double]$r.T_K
            I = [double]$r.I_peak
            S = [double]$r.S_peak
            W = [double]$r.width
        }
    }
}

$pairKeys = @{}
foreach ($r in $map) {
    $k = $r.variant_a + '||' + $r.variant_b
    if (-not $pairKeys.ContainsKey($k)) {
        $pairKeys[$k] = [pscustomobject]@{ a = $r.variant_a; b = $r.variant_b }
    }
}

$rows = @()
foreach ($pk in $pairKeys.Keys) {
    $pa = $pairKeys[$pk].a
    $pb = $pairKeys[$pk].b

    $temps = @($pairByT |
        Where-Object { $_.variant_a -eq $pa -and $_.variant_b -eq $pb } |
        ForEach-Object { [double]$_.T_K } |
        Sort-Object -Unique)

    $x = @()
    $y = @()
    $sref = @()
    $tvec = @()

    foreach ($t in $temps) {
        $ka = $pa + '|' + $t
        $kb = $pb + '|' + $t
        if ((-not $vdict.ContainsKey($ka)) -or (-not $vdict.ContainsKey($kb))) {
            continue
        }

        $ra = $vdict[$ka]
        $rb = $vdict[$kb]

        $xo = @([double]$ra.I, [double]$ra.S, [double]$ra.W)
        $yo = @([double]$rb.I, [double]$rb.S, [double]$rb.W)
        $sr = 0.5 * ([double]$ra.S + [double]$rb.S)

        for ($i = 0; $i -lt 3; $i++) {
            if ((-not [double]::IsNaN($xo[$i])) -and (-not [double]::IsInfinity($xo[$i])) -and (-not [double]::IsNaN($yo[$i])) -and (-not [double]::IsInfinity($yo[$i])) -and (-not [double]::IsNaN($sr)) -and (-not [double]::IsInfinity($sr))) {
                $x += $xo[$i]
                $y += $yo[$i]
                $sref += $sr
                $tvec += $t
            }
        }
    }

    if ($x.Count -lt 3) {
        $rows += [pscustomobject]@{
            pair = ($pa + ' vs ' + $pb)
            rmse_before = [double]::NaN
            rmse_scale = [double]::NaN
            rmse_affine = [double]::NaN
            reduction_scale = [double]::NaN
            reduction_affine = [double]::NaN
            dominant_region = 'NA'
            dominant_temperature_range = 'NA'
        }
        continue
    }

    $e0 = @()
    for ($i = 0; $i -lt $x.Count; $i++) {
        $e0 += ([double]$y[$i] - [double]$x[$i])
    }
    $rmse0 = [math]::Sqrt((($e0 | ForEach-Object { $_ * $_ } | Measure-Object -Sum).Sum) / $x.Count)

    $den = ($x | ForEach-Object { $_ * $_ } | Measure-Object -Sum).Sum
    if ($den -gt 0) {
        $num = 0.0
        for ($i = 0; $i -lt $x.Count; $i++) {
            $num += [double]$x[$i] * [double]$y[$i]
        }
        $a = $num / $den
    }
    else {
        $a = 1.0
    }

    $es = @()
    for ($i = 0; $i -lt $x.Count; $i++) {
        $es += ([double]$y[$i] - $a * [double]$x[$i])
    }
    $rmses = [math]::Sqrt((($es | ForEach-Object { $_ * $_ } | Measure-Object -Sum).Sum) / $x.Count)

    $mx = ($x | Measure-Object -Average).Average
    $my = ($y | Measure-Object -Average).Average
    $numab = 0.0
    $denab = 0.0
    for ($i = 0; $i -lt $x.Count; $i++) {
        $numab += ([double]$x[$i] - $mx) * ([double]$y[$i] - $my)
        $denab += ([double]$x[$i] - $mx) * ([double]$x[$i] - $mx)
    }
    if ($denab -gt 0) {
        $aa = $numab / $denab
    }
    else {
        $aa = 0.0
    }
    $bb = $my - $aa * $mx

    $ea = @()
    for ($i = 0; $i -lt $x.Count; $i++) {
        $ea += ([double]$y[$i] - ($aa * [double]$x[$i] + $bb))
    }
    $rmsea = [math]::Sqrt((($ea | ForEach-Object { $_ * $_ } | Measure-Object -Sum).Sum) / $x.Count)

    if ($rmse0 -gt 0) {
        $redS = ($rmse0 - $rmses) / $rmse0
        $redA = ($rmse0 - $rmsea) / $rmse0
    }
    else {
        $redS = [double]::NaN
        $redA = [double]::NaN
    }

    $q1 = Get-Quantile ($sref | ForEach-Object { [double]$_ }) (1.0 / 3.0)
    $q2 = Get-Quantile ($sref | ForEach-Object { [double]$_ }) (2.0 / 3.0)

    $sseTot = ($e0 | ForEach-Object { $_ * $_ } | Measure-Object -Sum).Sum
    $sseLow = 0.0
    $sseMid = 0.0
    $sseHigh = 0.0
    for ($i = 0; $i -lt $e0.Count; $i++) {
        $ee = [double]$e0[$i] * [double]$e0[$i]
        $ss = [double]$sref[$i]
        if ($ss -le $q1) {
            $sseLow += $ee
        }
        elseif ($ss -ge $q2) {
            $sseHigh += $ee
        }
        else {
            $sseMid += $ee
        }
    }

    if ($sseTot -gt 0) {
        $fLow = $sseLow / $sseTot
        $fMid = $sseMid / $sseTot
        $fHigh = $sseHigh / $sseTot
    }
    else {
        $fLow = 0.0
        $fMid = 0.0
        $fHigh = 0.0
    }

    $dom = 'near_peak'
    $m = $fHigh
    if ($fMid -gt $m) {
        $m = $fMid
        $dom = 'transition'
    }
    if ($fLow -gt $m) {
        $dom = 'low_signal'
    }

    $tempMap = @{}
    for ($i = 0; $i -lt $tvec.Count; $i++) {
        $tt = [double]$tvec[$i]
        $ee = [double]$e0[$i] * [double]$e0[$i]
        if (-not $tempMap.ContainsKey($tt)) {
            $tempMap[$tt] = 0.0
        }
        $tempMap[$tt] += $ee
    }

    $top = @($tempMap.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 2)
    if ($top.Count -eq 0) {
        $domT = 'NA'
    }
    else {
        $tvals = @($top | ForEach-Object { [double]$_.Key })
        $tmin = ($tvals | Measure-Object -Minimum).Minimum
        $tmax = ($tvals | Measure-Object -Maximum).Maximum
        if ($tmin -eq $tmax) {
            $domT = ('{0} K' -f $tmin)
        }
        else {
            $domT = ('{0}-{1} K' -f $tmin, $tmax)
        }
    }

    $rows += [pscustomobject]@{
        pair = ($pa + ' vs ' + $pb)
        rmse_before = $rmse0
        rmse_scale = $rmses
        rmse_affine = $rmsea
        reduction_scale = $redS
        reduction_affine = $redA
        dominant_region = $dom
        dominant_temperature_range = $domT
    }
}

$summaryPath = $repo + '/tables/rmse_closure_summary.csv'
$rows | Export-Csv -NoTypeInformation -Encoding ASCII $summaryPath

$valid = @($rows | Where-Object { (-not [double]::IsNaN([double]$_.reduction_scale)) -and (-not [double]::IsInfinity([double]$_.reduction_scale)) -and (-not [double]::IsNaN([double]$_.reduction_affine)) -and (-not [double]::IsInfinity([double]$_.reduction_affine)) })
if ($valid.Count -gt 0) {
    $medS = Get-Quantile (@($valid | ForEach-Object { [double]$_.reduction_scale })) 0.5
    $medAffExtra = Get-Quantile (@($valid | ForEach-Object { [double]$_.reduction_affine - [double]$_.reduction_scale })) 0.5
    $lowFrac = (@($valid | Where-Object { $_.dominant_region -eq 'low_signal' }).Count) / [double]$valid.Count
}
else {
    $medS = [double]::NaN
    $medAffExtra = [double]::NaN
    $lowFrac = [double]::NaN
}

$mostly = if ((-not [double]::IsNaN($medS)) -and (-not [double]::IsInfinity($medS)) -and $medS -ge 0.60) { 'YES' } else { 'NO' }
$struct = if ((-not [double]::IsNaN($medS)) -and (-not [double]::IsInfinity($medS)) -and $medS -lt 0.40) { 'YES' } else { 'NO' }
$lowloc = if ((-not [double]::IsNaN($lowFrac)) -and (-not [double]::IsInfinity($lowFrac)) -and $lowFrac -ge 0.50) { 'YES' } else { 'NO' }
$affNeed = if ((-not [double]::IsNaN($medAffExtra)) -and (-not [double]::IsInfinity($medAffExtra)) -and $medAffExtra -ge 0.05) { 'YES' } else { 'NO' }
$pres = if ($mostly -eq 'YES' -and $struct -eq 'NO') { 'YES' } else { 'NO' }

$status = [pscustomobject]@{
    EXECUTION_STATUS = 'SUCCESS'
    INPUT_FOUND = 'YES'
    ERROR_MESSAGE = ''
    N_T = $valid.Count
    MAIN_RESULT_SUMMARY = ('pairs={0}; median_scale_reduction={1}; median_affine_extra={2}; source={3}' -f $valid.Count, ([math]::Round($medS, 6)), ([math]::Round($medAffExtra, 6)), $tablesDir.Replace('\\', '/'))
    RMSE_IS_MOSTLY_SCALE = $mostly
    RMSE_IS_STRUCTURAL = $struct
    RMSE_IS_LOW_SIGNAL_LOCALIZED = $lowloc
    AFFINE_CLOSURE_NEEDED = $affNeed
    STRUCTURE_PRESERVED_AFTER_RESCALING = $pres
}

$status | Export-Csv -NoTypeInformation -Encoding ASCII ($repo + '/tables/rmse_closure_status.csv')

Write-Output ('RMSE_IS_MOSTLY_SCALE=' + $mostly)
Write-Output ('RMSE_IS_STRUCTURAL=' + $struct)
Write-Output ('RMSE_IS_LOW_SIGNAL_LOCALIZED=' + $lowloc)
Write-Output ('AFFINE_CLOSURE_NEEDED=' + $affNeed)
Write-Output ('STRUCTURE_PRESERVED_AFTER_RESCALING=' + $pres)
Write-Output 'EXECUTION_STATUS=SUCCESS'
