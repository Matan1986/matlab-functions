param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
$ErrorActionPreference = 'Stop'

function To-DoubleOrNaN($v) {
    if ($null -eq $v) { return [double]::NaN }
    if ($v -is [double] -or $v -is [single] -or $v -is [int] -or $v -is [long] -or $v -is [decimal]) { return [double]$v }
    $s = [string]$v
    if ([string]::IsNullOrWhiteSpace($s)) { return [double]::NaN }
    $x = 0.0
    if ([double]::TryParse($s, [ref]$x)) { return [double]$x }
    if ([double]::TryParse($s.Replace(',', '.'), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$x)) { return [double]$x }
    return [double]::NaN
}
function Is-Finite([double]$x) { return (-not [double]::IsNaN($x)) -and (-not [double]::IsInfinity($x)) }
function Mean-Of([double[]]$arr) { $c=@($arr|Where-Object{Is-Finite $_}); if($c.Count -eq 0){return [double]::NaN}; [double](($c|Measure-Object -Average).Average) }
function Std-Of([double[]]$arr) { $c=@($arr|Where-Object{Is-Finite $_}); if($c.Count -lt 2){return [double]::NaN}; $m=Mean-Of $c; $ss=0.0; foreach($v in $c){$ss+=($v-$m)*($v-$m)}; [math]::Sqrt($ss/[math]::Max(1,$c.Count-1)) }
function Resolve-ColumnName($sampleRow, [string[]]$candidates) {
    $names=@($sampleRow.PSObject.Properties.Name)
    foreach($c in $candidates){ foreach($n in $names){ if($n -eq $c){ return $n } } }
    foreach($c in $candidates){ foreach($n in $names){ if($n.Trim().ToLowerInvariant() -eq $c.Trim().ToLowerInvariant()){ return $n } } }
    return $null
}
function Interp-Linear([double[]]$x,[double[]]$y,[double]$xq){
    $n=$x.Count; if($n -lt 2){return [double]::NaN}
    if($xq -le $x[0]){return $y[0]}; if($xq -ge $x[$n-1]){return $y[$n-1]}
    for($k=1;$k -lt $n;$k++){
        if($xq -le $x[$k]){ $dx=$x[$k]-$x[$k-1]; if([math]::Abs($dx)-le 1e-15){return $y[$k]}; $t=($xq-$x[$k-1])/$dx; return $y[$k-1]+$t*($y[$k]-$y[$k-1]) }
    }
    return [double]::NaN
}
function Domain-Mask([double]$t,[string]$domain){
    switch($domain){ 'primary' {return $t -lt 31.5}; 'low_primary' {return $t -lt 20.0}; 'high_primary' {return $t -ge 20.0 -and $t -lt 31.5}; 'diag_high' {return $t -ge 31.5}; default {return $false} }
}
function Evaluate-Collapse($curves,[string]$domain,[int]$gridN=101){
    $sub=@($curves|Where-Object{Domain-Mask ([double]$_.T_K) $domain})
    $byT=@{}
    foreach($c in $sub){ $k=[string]([int][math]::Round([double]$c.T_K)); if(-not $byT.ContainsKey($k)){$byT[$k]=@()}; $byT[$k]+=$c }
    $keys=@($byT.Keys|Sort-Object {[double]$_})
    if($keys.Count -lt 2){ return [pscustomobject]@{metric=[double]::NaN;n_curves=0;x_min=[double]::NaN;x_max=[double]::NaN;rmse_by_T=@{}} }

    $mins=@(); $maxs=@(); $interp=@{}
    foreach($k in $keys){
        $cv=$byT[$k][0]
        if(($cv.x -isnot [double[]]) -or ($cv.y -isnot [double[]])){ continue }
        $x=[double[]]$cv.x; $y=[double[]]$cv.y
        if($x.Count -lt 4 -or $y.Count -lt 4){ continue }
        $allFinite = $true
        for($m=0;$m -lt $x.Count;$m++){ if((-not (Is-Finite ([double]$x[$m]))) -or (-not (Is-Finite ([double]$y[$m])))){ $allFinite=$false; break } }
        if(-not $allFinite){ continue }
        $mins += ($x|Measure-Object -Minimum).Minimum
        $maxs += ($x|Measure-Object -Maximum).Maximum
    }
    if($mins.Count -lt 2 -or $maxs.Count -lt 2){ return [pscustomobject]@{metric=[double]::NaN;n_curves=0;x_min=[double]::NaN;x_max=[double]::NaN;rmse_by_T=@{}} }

    $xMin=[double](($mins|Measure-Object -Maximum).Maximum)
    $xMax=[double](($maxs|Measure-Object -Minimum).Minimum)
    if(-not (Is-Finite $xMin) -or -not (Is-Finite $xMax) -or $xMax -le $xMin){ return [pscustomobject]@{metric=[double]::NaN;n_curves=0;x_min=$xMin;x_max=$xMax;rmse_by_T=@{}} }

    $gN=[int][math]::Min([math]::Max(21,$gridN),101)
    $grid=New-Object double[] $gN
    $xMinVal=[double]$xMin
    $xMaxVal=[double]$xMax
    $range=[double]($xMaxVal-$xMinVal)
    for($gi=0;$gi -lt $gN;$gi++){ $grid[$gi]=[double]($xMinVal + $range*$gi/[math]::Max(1,$gN-1)) }

    foreach($k in $keys){
        $cv=$byT[$k][0]
        if(($cv.x -isnot [double[]]) -or ($cv.y -isnot [double[]])){ continue }
        $x=[double[]]$cv.x; $y=[double[]]$cv.y
        if($x.Count -lt 4 -or $y.Count -lt 4){ continue }
        $vals=New-Object double[] $gN
        for($gi=0;$gi -lt $gN;$gi++){ $vals[$gi]=Interp-Linear $x $y $grid[$gi] }
        $interp[$k]=$vals
    }
    $keys2=@($interp.Keys|Sort-Object {[double]$_})
    if($keys2.Count -lt 2){ return [pscustomobject]@{metric=[double]::NaN;n_curves=$keys2.Count;x_min=$xMin;x_max=$xMax;rmse_by_T=@{}} }

    $pointMean=New-Object double[] $gN
    $pointStd=New-Object double[] $gN
    for($gi=0;$gi -lt $gN;$gi++){
        $vals=@(); foreach($k in $keys2){ $vals += [double]$interp[$k][$gi] }
        $pointMean[$gi]=Mean-Of $vals
        $pointStd[$gi]=Std-Of $vals
    }
    $rmseByT=@{}
    foreach($k in $keys2){
        $vals=$interp[$k]; $ss=0.0; $n=0
        for($gi=0;$gi -lt $gN;$gi++){ if((Is-Finite $vals[$gi]) -and (Is-Finite $pointMean[$gi])){ $d=$vals[$gi]-$pointMean[$gi]; $ss+=$d*$d; $n++ } }
        $rmseByT[$k]=if($n -gt 0){[math]::Sqrt($ss/$n)}else{[double]::NaN}
    }
    [pscustomobject]@{metric=(Mean-Of $pointStd);n_curves=$keys2.Count;x_min=$xMin;x_max=$xMax;rmse_by_T=$rmseByT}
}

$tablesDir=Join-Path $RepoRoot 'tables'
$reportsDir=Join-Path $RepoRoot 'reports'
if(-not (Test-Path $tablesDir)){New-Item -ItemType Directory -Path $tablesDir -Force|Out-Null}
if(-not (Test-Path $reportsDir)){New-Item -ItemType Directory -Path $reportsDir -Force|Out-Null}
$outCandidates=Join-Path $tablesDir 'switching_gauge_definition_atlas_candidates.csv'
$outMetrics=Join-Path $tablesDir 'switching_gauge_definition_atlas_metrics.csv'
$outBest=Join-Path $tablesDir 'switching_gauge_definition_atlas_best_by_regime.csv'
$outAblation=Join-Path $tablesDir 'switching_gauge_definition_atlas_component_ablation.csv'
$outStatus=Join-Path $tablesDir 'switching_gauge_definition_atlas_status.csv'
$outDebug=Join-Path $tablesDir 'switching_gauge_definition_atlas_debug_curve_counts.csv'
$outReport=Join-Path $reportsDir 'switching_gauge_definition_atlas.md'

$inS=Join-Path $RepoRoot 'results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv'
$inP0=Join-Path $tablesDir 'switching_P0_effective_observables_values.csv'
$inP0m=Join-Path $tablesDir 'switching_P0_old_collapse_freeze_metrics.csv'
$inP1=Join-Path $tablesDir 'switching_P1_asymmetry_LR_values.csv'
$inP2=Join-Path $tablesDir 'switching_P2_T22_crossover_metrics.csv'

$verdict=@{GAUGE_DEFINITION_ATLAS_COMPLETE='NO';CANONICAL_S_USED='NO';I0_CANDIDATES_TESTED='NO';W_CANDIDATES_TESTED='NO';S0_CANDIDATES_TESTED='NO';HIGH_T_INSTABILITY_REDUCED_BY_I0='NO';HIGH_T_INSTABILITY_REDUCED_BY_W='NO';HIGH_T_INSTABILITY_REDUCED_BY_S0='NO';HIGH_T_INSTABILITY_REDUCED_BY_COMBINED_GAUGE='NO';BEST_PRIMARY_GAUGE_FOUND='NO';BEST_HIGH_PRIMARY_GAUGE_FOUND='NO';BALANCED_STABILIZED_GAUGE_FOUND='NO';OLD_GAUGE_RETAINED_AS_BASELINE='YES';T22_INCLUDED_IN_PRIMARY_DOMAIN='YES';ABOVE_31P5_DIAGNOSTIC_ONLY='YES';X_CANON_CLAIMED='NO';UNIQUE_W_CLAIMED='NO';UNIQUE_S0_CLAIMED='NO';SAFE_TO_WRITE_SCALING_CLAIM='NO';CROSS_MODULE_SYNTHESIS_PERFORMED='NO';BASELINE_OLD_GAUGE_FINITE='NO';VALID_PRIMARY_CURVES_GT_ZERO='NO';FINITE_METRICS_WRITTEN='NO';ATLAS_DEBUG_PASS_COMPLETE='NO'}
$debugRows=@()

try {
    foreach($p in @($inS,$inP0,$inP0m,$inP1,$inP2)){ if(-not (Test-Path $p)){ throw "Missing required input: $p" } }
    $verdict.CANONICAL_S_USED='YES'

    $sCsv=@(Import-Csv $inS)
    if($sCsv.Count -eq 0){ throw 'Canonical S_long is empty.' }
    $colT=Resolve-ColumnName $sCsv[0] @('T_K','T','temperature_K')
    $colI=Resolve-ColumnName $sCsv[0] @('current_mA','I_mA','current','I')
    $colS=Resolve-ColumnName $sCsv[0] @('S_percent','S','S_pct')
    if($null -eq $colT -or $null -eq $colI -or $null -eq $colS){ throw "Missing required S columns: T=$colT I=$colI S=$colS" }

    $raw=@($sCsv|ForEach-Object{ [pscustomobject]@{T_K=To-DoubleOrNaN $_.$colT; I=To-DoubleOrNaN $_.$colI; S=To-DoubleOrNaN $_.$colS} }|Where-Object{(Is-Finite $_.T_K)-and(Is-Finite $_.I)-and(Is-Finite $_.S)})
    $debugRows += [pscustomobject]@{stage='raw_summary';T_K=[double]::NaN;reason="raw_rows=$($raw.Count)";n_points=$raw.Count}

    $groupByTI=$raw|Group-Object{ "$([double]$_.T_K)|$([double]$_.I)" }
    $dedup=@(); foreach($g in $groupByTI){ $f=$g.Group[0]; $dedup += [pscustomobject]@{T_K=[double]$f.T_K; I=[double]$f.I; S=(Mean-Of @($g.Group|ForEach-Object{[double]$_.S}))} }
    $byT=$dedup|Group-Object{[double]$_.T_K}
    $temps=@($byT|ForEach-Object{[double]$_.Name}|Sort-Object)
    if($temps.Count -lt 6){ throw 'Insufficient temperature coverage after dedup.' }
    foreach($tg in $byT){ $debugRows += [pscustomobject]@{stage='byT_counts';T_K=[double]$tg.Name;reason='group_rows';n_points=$tg.Count} }

    $p0Tbl=@(Import-Csv $inP0|ForEach-Object{ [pscustomobject]@{T_K=To-DoubleOrNaN $_.T_K; I_peak_old=To-DoubleOrNaN $_.I_peak_mA; W_FWHM_crossing=$(if(Is-Finite (To-DoubleOrNaN $_.width_chosen_mA)){To-DoubleOrNaN $_.width_chosen_mA}else{To-DoubleOrNaN $_.W_I_mA}); S_peak_old=To-DoubleOrNaN $_.S_peak} }|Where-Object{Is-Finite $_.T_K})
    $p0ByT=@{}; foreach($r in $p0Tbl){$p0ByT[[string]([int][math]::Round($r.T_K))]=$r}

    $perT=@{}
    foreach($tk in $temps){
        $slice=@(($byT|Where-Object{[double]$_.Name -eq $tk}).Group|Sort-Object I)
        if($slice.Count -lt 4){ continue }
        $xArr=@($slice|ForEach-Object{[double]$_.I})
        $yArr=@($slice|ForEach-Object{[double]$_.S})
        $n=$xArr.Count
        $idx=0; $sPk=$yArr[0]
        for($m=1;$m -lt $n;$m++){ if($yArr[$m] -gt $sPk){$sPk=$yArr[$m];$idx=$m} }
        $iPk=$xArr[$idx]
        $half=0.5*$sPk; $left=[double]::NaN; $right=[double]::NaN
        for($m=$idx;$m -ge 1;$m--){ $y1=[double]$yArr[$m-1];$y2=[double]$yArr[$m]; if((([double]$y1-[double]$half)*([double]$y2-[double]$half)) -le 0){ $left=Interp-Linear @([double]$y1,[double]$y2) @([double]$xArr[$m-1],[double]$xArr[$m]) ([double]$half); break } }
        for($m=$idx;$m -lt $n-1;$m++){ $y1=[double]$yArr[$m];$y2=[double]$yArr[$m+1]; if((([double]$y1-[double]$half)*([double]$y2-[double]$half)) -le 0){ $right=Interp-Linear @([double]$y1,[double]$y2) @([double]$xArr[$m],[double]$xArr[$m+1]) ([double]$half); break } }
        $wF=if((Is-Finite $left)-and(Is-Finite $right)-and [double]$right -gt [double]$left){[double]$right-[double]$left}else{[double]::NaN}
        $iMid=if((Is-Finite $left)-and(Is-Finite $right)){0.5*($left+$right)}else{[double]::NaN}
        $wPos=@(); foreach($yy in $yArr){ $wPos += [math]::Max([double]$yy,0.0) }
        $sumW=($wPos|Measure-Object -Sum).Sum
        $iCent=[double]::NaN; if($sumW -gt 0){ $acc=0.0; for($m=0;$m -lt $n;$m++){$acc+=$wPos[$m]*$xArr[$m]}; $iCent=$acc/$sumW }
        $q10=[double]::NaN; $q20=[double]::NaN; $iMed=[double]::NaN; $q80=[double]::NaN; $q90=[double]::NaN
        if($sumW -gt 0){ $cum=0.0; for($m=0;$m -lt $n;$m++){ $cum += $wPos[$m]; $f=$cum/$sumW; if((-not (Is-Finite $q10)) -and $f -ge 0.10){$q10=$xArr[$m]}; if((-not (Is-Finite $q20)) -and $f -ge 0.20){$q20=$xArr[$m]}; if((-not (Is-Finite $iMed)) -and $f -ge 0.50){$iMed=$xArr[$m]}; if((-not (Is-Finite $q80)) -and $f -ge 0.80){$q80=$xArr[$m]}; if((-not (Is-Finite $q90)) -and $f -ge 0.90){$q90=$xArr[$m]} } }
        $wA20=if((Is-Finite $q20)-and(Is-Finite $q80)){[double]$q80-[double]$q20}else{[double]::NaN}
        $wA10=if((Is-Finite $q10)-and(Is-Finite $q90)){[double]$q90-[double]$q10}else{[double]::NaN}
        $wHalf=if((Is-Finite $left)-and(Is-Finite $right)){([double]$iPk-[double]$left)+([double]$right-[double]$iPk)}else{[double]::NaN}
        $sSort=@($yArr|Sort-Object -Descending)
        $sTop2=if($sSort.Count -ge 2){Mean-Of @([double]$sSort[0],[double]$sSort[1])}else{[double]::NaN}
        $sTop3=if($sSort.Count -ge 3){Mean-Of @([double]$sSort[0],[double]$sSort[1],[double]$sSort[2])}else{[double]::NaN}
        $sP95=if($sSort.Count -ge 1){ [double]$sSort[[math]::Min([math]::Max([int][math]::Floor(0.95*($sSort.Count-1)),0),$sSort.Count-1)] }else{[double]::NaN}
        $sArea=($wPos|Measure-Object -Sum).Sum
        $sCore=[double]::NaN; if((Is-Finite $left)-and(Is-Finite $right)){ $c=@(); for($m=0;$m -lt $n;$m++){ if($xArr[$m] -ge $left -and $xArr[$m] -le $right){$c += [math]::Max([double]$yArr[$m],0.0)} }; if($c.Count -gt 0){$sCore=($c|Measure-Object -Sum).Sum} }
        $tKey=[string]([int][math]::Round($tk)); if($p0ByT.ContainsKey($tKey)){ $p0=$p0ByT[$tKey]; if(-not (Is-Finite $iPk)){$iPk=$p0.I_peak_old}; if(-not (Is-Finite $wF) -or $wF -le 0){$wF=$p0.W_FWHM_crossing}; if(-not (Is-Finite $sPk) -or [math]::Abs($sPk)-le 1e-15){$sPk=$p0.S_peak_old} }
        $perT[[string]([int][math]::Round($tk))]=[pscustomobject]@{T_K=[double]$tk; x=[double[]]$xArr; y=[double[]]$yArr; I_peak_old=$iPk; I_quadratic_peak=[double]::NaN; I_half_midpoint=$iMid; I_centroid_positive=$iCent; I_median_area=$iMed; W_FWHM_crossing=$wF; W_sigma_positive=[double]::NaN; W_area_20_80=$wA20; W_area_10_90=$wA10; W_half_left_right_sum=$wHalf; S_peak_old=$sPk; S_peak_quadratic=[double]::NaN; S_top2_mean=$sTop2; S_top3_mean=$sTop3; S_percentile_95=$sP95; S_area_positive=$sArea; S_area_core=$sCore}
    }
    $keysT=@($perT.Keys|Sort-Object {[double]$_}); if($keysT.Count -lt 6){ throw 'Failed to build per-T table.' }

    for($i=0;$i -lt $keysT.Count;$i++){
        $o=$perT[$keysT[$i]]; $ii=@();$ww=@();$ss=@()
        foreach($j in @(([int]$i-1),[int]$i,([int]$i+1))){ if($j -ge 0 -and $j -lt $keysT.Count){ $oo=$perT[$keysT[$j]]; if(Is-Finite $oo.I_peak_old){$ii+=[double]$oo.I_peak_old}; if(Is-Finite $oo.W_FWHM_crossing){$ww+=[double]$oo.W_FWHM_crossing}; if(Is-Finite $oo.S_peak_old){$ss+=[double]$oo.S_peak_old} } }
        Add-Member -InputObject $o -NotePropertyName I_peak_smoothed_across_T -NotePropertyValue (Mean-Of $ii) -Force
        Add-Member -InputObject $o -NotePropertyName W_smoothed_across_T -NotePropertyValue (Mean-Of $ww) -Force
        Add-Member -InputObject $o -NotePropertyName S_smoothed_peak_across_T -NotePropertyValue (Mean-Of $ss) -Force
        if(Is-Finite $o.I_peak_old){ $wPos=@(); foreach($yy in $o.y){$wPos += [math]::Max([double]$yy,0.0)}; $sumW=($wPos|Measure-Object -Sum).Sum; if($sumW -gt 0){ $acc=0.0; for($m=0;$m -lt $o.x.Count;$m++){ $d=[double]$o.x[$m]-[double]$o.I_peak_old; $acc += [double]$wPos[$m]*$d*$d }; $o.W_sigma_positive=[math]::Sqrt($acc/$sumW) } }
        $perT[$keysT[$i]]=$o
    }

    $i0Defs=@('I_peak_old','I_quadratic_peak','I_half_midpoint','I_centroid_positive','I_median_area','I_peak_smoothed_across_T')
    $wDefs=@('W_FWHM_crossing','W_sigma_positive','W_area_20_80','W_area_10_90','W_half_left_right_sum','W_smoothed_across_T')
    $s0Defs=@('S_peak_old','S_peak_quadratic','S_top2_mean','S_top3_mean','S_percentile_95','S_area_positive','S_area_core','S_smoothed_peak_across_T')
    $candRows=@(); foreach($id in $i0Defs){$candRows += [pscustomobject]@{family='I0';candidate_id=$id;diagnostic_only=$(if($id -like '*smoothed*'){'YES'}else{'NO'});description=''}}; foreach($id in $wDefs){$candRows += [pscustomobject]@{family='W';candidate_id=$id;diagnostic_only=$(if($id -like '*smoothed*'){'YES'}else{'NO'});description=''}}; foreach($id in $s0Defs){$candRows += [pscustomobject]@{family='S0';candidate_id=$id;diagnostic_only=$(if($id -like '*smoothed*'){'YES'}else{'NO'});description=''}}
    $candRows|Export-Csv -NoTypeInformation -Encoding UTF8 $outCandidates
    $verdict.I0_CANDIDATES_TESTED='YES'; $verdict.W_CANDIDATES_TESTED='YES'; $verdict.S0_CANDIDATES_TESTED='YES'

    $combos=@(); foreach($i0 in $i0Defs){ foreach($w in $wDefs){ foreach($s0 in $s0Defs){ $combos += [pscustomobject]@{I0=$i0;W=$w;S0=$s0} } } }
    $metricRows=@(); $idx=0
    foreach($c in $combos){
        $idx++; if(($idx % 50)-eq 0){ Write-Host ("progress combination $idx/$($combos.Count)") }
        $curves=@(); $iSer=@();$wSer=@();$sSer=@()
        foreach($k in $keysT){
            $o=$perT[$k]
            $i0=To-DoubleOrNaN $o.($c.I0); $w0=To-DoubleOrNaN $o.($c.W); $s0=To-DoubleOrNaN $o.($c.S0)
            if(-not ((Is-Finite $i0)-and(Is-Finite $w0)-and(Is-Finite $s0)) -or $w0 -le 0 -or [math]::Abs($s0)-le 1e-15){ continue }
            if(($o.x -isnot [double[]]) -or ($o.y -isnot [double[]])){
                $debugRows += [pscustomobject]@{stage='curve_reject';T_K=[double]$o.T_K;reason='nonnumeric_curve_array_type';n_points=0;combo_I0=$c.I0;combo_W=$c.W;combo_S0=$c.S0}
                continue
            }
            $currArr=[double[]]$o.x
            $sigArr=[double[]]$o.y
            if($currArr.Count -ne $sigArr.Count){
                $debugRows += [pscustomobject]@{stage='curve_reject';T_K=[double]$o.T_K;reason='curve_xy_count_mismatch';n_points=0;combo_I0=$c.I0;combo_W=$c.W;combo_S0=$c.S0}
                continue
            }
            $xList = New-Object System.Collections.Generic.List[double]
            $yList = New-Object System.Collections.Generic.List[double]
            for($m=0;$m -lt $currArr.Count;$m++){
                $xRaw=[double]$currArr[$m]
                $yRaw=[double]$sigArr[$m]
                if((-not (Is-Finite $xRaw)) -or (-not (Is-Finite $yRaw))){ continue }
                $xx=[double](($xRaw-[double]$i0)/[double]$w0)
                $yy=[double]($yRaw/[double]$s0)
                if((Is-Finite $xx)-and(Is-Finite $yy)){ $xList.Add($xx); $yList.Add($yy) }
            }
            $curveX=[double[]]$xList.ToArray()
            $curveY=[double[]]$yList.ToArray()
            if($curveX.Count -lt 4 -or $curveY.Count -lt 4){
                $debugRows += [pscustomobject]@{stage='curve_reject';T_K=[double]$o.T_K;reason='curve_too_short_after_scaling';n_points=$curveX.Count;combo_I0=$c.I0;combo_W=$c.W;combo_S0=$c.S0}
                continue
            }
            $allFiniteCurve=$true
            for($m=0;$m -lt $curveX.Count;$m++){ if((-not (Is-Finite ([double]$curveX[$m]))) -or (-not (Is-Finite ([double]$curveY[$m])))){ $allFiniteCurve=$false; break } }
            if(-not $allFiniteCurve){
                $debugRows += [pscustomobject]@{stage='curve_reject';T_K=[double]$o.T_K;reason='curve_nonfinite_values';n_points=$curveX.Count;combo_I0=$c.I0;combo_W=$c.W;combo_S0=$c.S0}
                continue
            }
            $curves += [pscustomobject]@{T_K=[double]$o.T_K; x=$curveX; y=$curveY}
            $iSer += $i0; $wSer += $w0; $sSer += $s0
        }
        $mP=Evaluate-Collapse $curves 'primary' 101
        $mL=Evaluate-Collapse $curves 'low_primary' 101
        $mH=Evaluate-Collapse $curves 'high_primary' 101
        $mD=Evaluate-Collapse $curves 'diag_high' 101
        $m22=[double]::NaN; if($mP.rmse_by_T.ContainsKey('22')){$m22=$mP.rmse_by_T['22']}
        $mPno22=Evaluate-Collapse @($curves|Where-Object{[math]::Abs(([double]$_.T_K)-22.0)-gt 1e-9}) 'primary' 101
        $leave22=if((Is-Finite $mP.metric)-and(Is-Finite $mPno22.metric)){[double]$mPno22.metric-[double]$mP.metric}else{[double]::NaN}
        $dI=@();$dW=@();$dS=@(); for($m=1;$m -lt $iSer.Count;$m++){ $dI += [math]::Abs([double]$iSer[$m]-[double]$iSer[$m-1]); $dW += [math]::Abs([double]$wSer[$m]-[double]$wSer[$m-1]); $dS += [math]::Abs([double]$sSer[$m]-[double]$sSer[$m-1]) }
        $metricRows += [pscustomobject]@{combo_id=('G'+$idx.ToString('000'));I0_candidate=$c.I0;W_candidate=$c.W;S0_candidate=$c.S0;is_baseline=$(if($c.I0 -eq 'I_peak_old' -and $c.W -eq 'W_FWHM_crossing' -and $c.S0 -eq 'S_peak_old'){'YES'}else{'NO'});primary_metric_mean_std=$mP.metric;low_primary_metric_mean_std=$mL.metric;high_primary_metric_mean_std=$mH.metric;T22_specific_defect=$m22;leave22k_out_delta=$leave22;primary_common_x_min=$mP.x_min;primary_common_x_max=$mP.x_max;primary_valid_curves=$mP.n_curves;low_primary_valid_curves=$mL.n_curves;high_primary_valid_curves=$mH.n_curves;diag_32_34_metric_mean_std=$mD.metric;I0_roughness_mean_abs_step=(Mean-Of $dI);W_roughness_mean_abs_step=(Mean-Of $dW);S0_roughness_mean_abs_step=(Mean-Of $dS)}
    }

    $baseline=@($metricRows|Where-Object{$_.is_baseline -eq 'YES'}|Select-Object -First 1)
    if($null -eq $baseline){ throw 'Baseline gauge row missing.' }
    if((Is-Finite (To-DoubleOrNaN $baseline.primary_metric_mean_std)) -and ([int]$baseline.primary_valid_curves -gt 0)){ $verdict.BASELINE_OLD_GAUGE_FINITE='YES'; $verdict.VALID_PRIMARY_CURVES_GT_ZERO='YES' } else { throw 'Baseline gauge not finite or zero valid curves.' }

    $baseLow=To-DoubleOrNaN $baseline.low_primary_metric_mean_std; $baseHigh=To-DoubleOrNaN $baseline.high_primary_metric_mean_std
    foreach($r in $metricRows){ $low=To-DoubleOrNaN $r.low_primary_metric_mean_std; $high=To-DoubleOrNaN $r.high_primary_metric_mean_std; $dl=if((Is-Finite $low)-and(Is-Finite $baseLow)){[double]$low-[double]$baseLow}else{[double]::NaN}; $dh=if((Is-Finite $high)-and(Is-Finite $baseHigh)){[double]$high-[double]$baseHigh}else{[double]::NaN}; Add-Member -InputObject $r -NotePropertyName delta_low_vs_baseline -NotePropertyValue $dl -Force; Add-Member -InputObject $r -NotePropertyName delta_high_vs_baseline -NotePropertyValue $dh -Force; Add-Member -InputObject $r -NotePropertyName high_improvement_with_low_cost -NotePropertyValue $(if((Is-Finite $dl)-and(Is-Finite $dh)-and $dh -lt 0 -and $dl -le 0.01){'YES'}else{'NO'}) -Force }
    $metricRows|Export-Csv -NoTypeInformation -Encoding UTF8 $outMetrics

    $finiteRows=@($metricRows|Where-Object{ (Is-Finite (To-DoubleOrNaN $_.primary_metric_mean_std)) -and (Is-Finite (To-DoubleOrNaN $_.high_primary_metric_mean_std)) })
    if($finiteRows.Count -lt 3){ throw 'Finite metrics produced for too few combinations.' }
    $verdict.FINITE_METRICS_WRITTEN='YES'

    $bestPrimary=@($finiteRows|Sort-Object {[double]$_.primary_metric_mean_std}|Select-Object -First 1)[0]
    $bestHigh=@($finiteRows|Sort-Object {[double]$_.high_primary_metric_mean_std}|Select-Object -First 1)[0]
    $scored=@(); foreach($r in $finiteRows){ $dl=To-DoubleOrNaN $r.delta_low_vs_baseline; $h=To-DoubleOrNaN $r.high_primary_metric_mean_std; $score=$h + 2.0*[math]::Max(0.0,$(if(Is-Finite $dl){$dl}else{0.0})); $scored += [pscustomobject]@{row=$r;score=$score} }
    $bestBalanced=@($scored|Sort-Object score|Select-Object -First 1)[0].row
    @([pscustomobject]@{regime='best_primary';combo_id=$bestPrimary.combo_id;I0_candidate=$bestPrimary.I0_candidate;W_candidate=$bestPrimary.W_candidate;S0_candidate=$bestPrimary.S0_candidate;metric_value=$bestPrimary.primary_metric_mean_std;criterion='min primary_metric_mean_std'},[pscustomobject]@{regime='best_high_primary';combo_id=$bestHigh.combo_id;I0_candidate=$bestHigh.I0_candidate;W_candidate=$bestHigh.W_candidate;S0_candidate=$bestHigh.S0_candidate;metric_value=$bestHigh.high_primary_metric_mean_std;criterion='min high_primary_metric_mean_std'},[pscustomobject]@{regime='best_balanced';combo_id=$bestBalanced.combo_id;I0_candidate=$bestBalanced.I0_candidate;W_candidate=$bestBalanced.W_candidate;S0_candidate=$bestBalanced.S0_candidate;metric_value=$bestBalanced.high_primary_metric_mean_std;criterion='min high+low-penalty'}) | Export-Csv -NoTypeInformation -Encoding UTF8 $outBest

    $sets=@(
        @{id='I0 only';f={param($r) $r.I0_candidate -ne 'I_peak_old' -and $r.W_candidate -eq 'W_FWHM_crossing' -and $r.S0_candidate -eq 'S_peak_old'}},
        @{id='W only';f={param($r) $r.I0_candidate -eq 'I_peak_old' -and $r.W_candidate -ne 'W_FWHM_crossing' -and $r.S0_candidate -eq 'S_peak_old'}},
        @{id='S0 only';f={param($r) $r.I0_candidate -eq 'I_peak_old' -and $r.W_candidate -eq 'W_FWHM_crossing' -and $r.S0_candidate -ne 'S_peak_old'}},
        @{id='I0+W';f={param($r) $r.I0_candidate -ne 'I_peak_old' -and $r.W_candidate -ne 'W_FWHM_crossing' -and $r.S0_candidate -eq 'S_peak_old'}},
        @{id='I0+S0';f={param($r) $r.I0_candidate -ne 'I_peak_old' -and $r.W_candidate -eq 'W_FWHM_crossing' -and $r.S0_candidate -ne 'S_peak_old'}},
        @{id='W+S0';f={param($r) $r.I0_candidate -eq 'I_peak_old' -and $r.W_candidate -ne 'W_FWHM_crossing' -and $r.S0_candidate -ne 'S_peak_old'}},
        @{id='all three';f={param($r) $r.I0_candidate -ne 'I_peak_old' -and $r.W_candidate -ne 'W_FWHM_crossing' -and $r.S0_candidate -ne 'S_peak_old'}},
        @{id='none';f={param($r) $r.I0_candidate -eq 'I_peak_old' -and $r.W_candidate -eq 'W_FWHM_crossing' -and $r.S0_candidate -eq 'S_peak_old'}}
    )
    $abl=@(); foreach($s in $sets){ $sub=@($metricRows|Where-Object{ & $s.f $_ }|Where-Object{ Is-Finite (To-DoubleOrNaN $_.delta_high_vs_baseline) }); if($sub.Count -gt 0){ $b=@($sub|Sort-Object {[double]$_.delta_high_vs_baseline}|Select-Object -First 1)[0]; $abl += [pscustomobject]@{component_set=$s.id;best_combo_id=$b.combo_id;best_delta_high_vs_baseline=$b.delta_high_vs_baseline;low_delta_for_best=$b.delta_low_vs_baseline;high_improvement_with_low_cost=$b.high_improvement_with_low_cost} } else { $abl += [pscustomobject]@{component_set=$s.id;best_combo_id='';best_delta_high_vs_baseline=[double]::NaN;low_delta_for_best=[double]::NaN;high_improvement_with_low_cost='NO'} } }
    $abl|Export-Csv -NoTypeInformation -Encoding UTF8 $outAblation

    if((@($abl|Where-Object{$_.component_set -eq 'I0 only' -and (Is-Finite (To-DoubleOrNaN $_.best_delta_high_vs_baseline)) -and [double]$_.best_delta_high_vs_baseline -lt 0}).Count) -gt 0){$verdict.HIGH_T_INSTABILITY_REDUCED_BY_I0='YES'}
    if((@($abl|Where-Object{$_.component_set -eq 'W only' -and (Is-Finite (To-DoubleOrNaN $_.best_delta_high_vs_baseline)) -and [double]$_.best_delta_high_vs_baseline -lt 0}).Count) -gt 0){$verdict.HIGH_T_INSTABILITY_REDUCED_BY_W='YES'}
    if((@($abl|Where-Object{$_.component_set -eq 'S0 only' -and (Is-Finite (To-DoubleOrNaN $_.best_delta_high_vs_baseline)) -and [double]$_.best_delta_high_vs_baseline -lt 0}).Count) -gt 0){$verdict.HIGH_T_INSTABILITY_REDUCED_BY_S0='YES'}
    if((@($abl|Where-Object{$_.component_set -eq 'all three' -and (Is-Finite (To-DoubleOrNaN $_.best_delta_high_vs_baseline)) -and [double]$_.best_delta_high_vs_baseline -lt 0}).Count) -gt 0){$verdict.HIGH_T_INSTABILITY_REDUCED_BY_COMBINED_GAUGE='YES'}

    $verdict.BEST_PRIMARY_GAUGE_FOUND='YES'; $verdict.BEST_HIGH_PRIMARY_GAUGE_FOUND='YES'; $verdict.BALANCED_STABILIZED_GAUGE_FOUND='YES'; $verdict.GAUGE_DEFINITION_ATLAS_COMPLETE='YES'; $verdict.ATLAS_DEBUG_PASS_COMPLETE='YES'
    $debugRows += [pscustomobject]@{stage='baseline_summary';T_K=[double]::NaN;reason='baseline_finite';n_points=$baseline.primary_valid_curves;primary_valid_curves=$baseline.primary_valid_curves;primary_metric=$baseline.primary_metric_mean_std}
}
catch {
    $errPos=$_.InvocationInfo.PositionMessage
    $errStack=$_.ScriptStackTrace
    $err=($_.Exception.Message + ' | position: ' + $errPos + ' | stack: ' + $errStack)
    @([pscustomobject]@{combo_id='ERROR';I0_candidate='';W_candidate='';S0_candidate='';is_baseline='NO';primary_metric_mean_std=[double]::NaN;low_primary_metric_mean_std=[double]::NaN;high_primary_metric_mean_std=[double]::NaN;T22_specific_defect=[double]::NaN;leave22k_out_delta=[double]::NaN;primary_common_x_min=[double]::NaN;primary_common_x_max=[double]::NaN;primary_valid_curves=0;low_primary_valid_curves=0;high_primary_valid_curves=0;diag_32_34_metric_mean_std=[double]::NaN;I0_roughness_mean_abs_step=[double]::NaN;W_roughness_mean_abs_step=[double]::NaN;S0_roughness_mean_abs_step=[double]::NaN;delta_low_vs_baseline=[double]::NaN;delta_high_vs_baseline=[double]::NaN;high_improvement_with_low_cost='NO'})|Export-Csv -NoTypeInformation -Encoding UTF8 $outMetrics
    @([pscustomobject]@{regime='ERROR';combo_id='';I0_candidate='';W_candidate='';S0_candidate='';metric_value=[double]::NaN;criterion=$err})|Export-Csv -NoTypeInformation -Encoding UTF8 $outBest
    @([pscustomobject]@{component_set='ERROR';best_combo_id='';best_delta_high_vs_baseline=[double]::NaN;low_delta_for_best=[double]::NaN;high_improvement_with_low_cost='NO'})|Export-Csv -NoTypeInformation -Encoding UTF8 $outAblation
    $verdict.GAUGE_DEFINITION_ATLAS_COMPLETE='NO'; $verdict.BASELINE_OLD_GAUGE_FINITE='NO'; $verdict.VALID_PRIMARY_CURVES_GT_ZERO='NO'; $verdict.FINITE_METRICS_WRITTEN='NO'; $verdict.ATLAS_DEBUG_PASS_COMPLETE='NO'
    $debugRows += [pscustomobject]@{stage='ERROR';T_K=[double]::NaN;reason=$err;n_points=0}
}

if($debugRows.Count -eq 0){ $debugRows=@([pscustomobject]@{stage='debug';T_K=[double]::NaN;reason='no_debug_rows';n_points=0}) }
$debugRows|Export-Csv -NoTypeInformation -Encoding UTF8 $outDebug

$statusRows=@(); foreach($k in ($verdict.Keys|Sort-Object)){ $statusRows += [pscustomobject]@{verdict_key=$k;verdict_value=$verdict[$k]} }
$statusRows|Export-Csv -NoTypeInformation -Encoding UTF8 $outStatus

$rep=@(); $rep += '# Switching gauge-definition atlas (effective gauge candidates)'; $rep += ''; $rep += 'Bounded inner-loop rewrite applied: fixed-grid interpolation, no while loops, baseline-first gating.'; $rep += ''; $rep += '## Outputs'; $rep += '- `tables/switching_gauge_definition_atlas_candidates.csv`'; $rep += '- `tables/switching_gauge_definition_atlas_metrics.csv`'; $rep += '- `tables/switching_gauge_definition_atlas_best_by_regime.csv`'; $rep += '- `tables/switching_gauge_definition_atlas_component_ablation.csv`'; $rep += '- `tables/switching_gauge_definition_atlas_status.csv`'; $rep += '- `tables/switching_gauge_definition_atlas_debug_curve_counts.csv`'; $rep += ''; $rep += '## Verdicts'; foreach($k in ($verdict.Keys|Sort-Object)){ $rep += "- $k = $($verdict[$k])" }
$rep|Set-Content -Encoding UTF8 $outReport

Write-Host 'Wrote:'
Write-Host $outCandidates
Write-Host $outMetrics
Write-Host $outBest
Write-Host $outAblation
Write-Host $outStatus
Write-Host $outDebug
Write-Host $outReport
