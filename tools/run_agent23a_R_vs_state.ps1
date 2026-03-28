# Agent 23A: merge alpha_structure + barrier_descriptors, correlations, OLS LOOCV, CSV/MD/PNG
$ErrorActionPreference = 'Stop'
# tools/ -> repo root
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $repoRoot 'tables\alpha_structure.csv'))) {
    $repoRoot = (Get-Location).Path
}

$alphaPath = Join-Path $repoRoot 'tables\alpha_structure.csv'
$barrierPath = Join-Path $repoRoot 'results\cross_experiment\runs\run_2026_03_25_031904_barrier_to_relaxation_mechanism\tables\barrier_descriptors.csv'
if (-not (Test-Path $barrierPath)) {
    $cands = Get-ChildItem (Join-Path $repoRoot 'results\cross_experiment\runs') -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'tables\barrier_descriptors.csv' } |
        Where-Object { Test-Path $_ }
    if ($cands) { $barrierPath = ($cands | Sort-Object LastWriteTime -Descending | Select-Object -First 1) }
}

Add-Type @"
using System;
public static class Agent23aMath {
  public static double Pearson(double[] x, double[] y) {
    if (x == null || y == null) return double.NaN;
    int n = x.Length; double mx = 0, my = 0; int c = 0;
    for (int i = 0; i < n; i++) {
      if (double.IsNaN(x[i]) || double.IsNaN(y[i])) continue;
      mx += x[i]; my += y[i]; c++;
    }
    if (c < 2) return double.NaN;
    mx /= c; my /= c;
    double sxx = 0, syy = 0, sxy = 0;
    for (int i = 0; i < n; i++) {
      if (double.IsNaN(x[i]) || double.IsNaN(y[i])) continue;
      double dx = x[i] - mx, dy = y[i] - my;
      sxx += dx * dx; syy += dy * dy; sxy += dx * dy;
    }
    if (sxx <= 0 || syy <= 0) return double.NaN;
    return sxy / Math.Sqrt(sxx * syy);
  }
  public static double[] Rank(double[] x) {
    int n = x.Length;
    var idx = new int[n];
    for (int i = 0; i < n; i++) idx[i] = i;
    Array.Sort(idx, (a, b) => x[a].CompareTo(x[b]));
    double[] r = new double[n];
    int j = 0;
    while (j < n) {
      int k = j;
      while (k + 1 < n && x[idx[k + 1]] == x[idx[j]]) k++;
      double avg = (j + k + 2) / 2.0;
      for (int t = j; t <= k; t++) r[idx[t]] = avg;
      j = k + 1;
    }
    return r;
  }
  public static double Spearman(double[] x, double[] y) {
    return Pearson(Rank(x), Rank(y));
  }
  static double[,] XtXinvXt(double[,] X) {
    int n = X.GetLength(0), p = X.GetLength(1);
    double[,] XtX = new double[p, p];
    for (int i = 0; i < p; i++)
      for (int j = 0; j < p; j++) {
        double s = 0;
        for (int r = 0; r < n; r++) s += X[r, i] * X[r, j];
        XtX[i, j] = s;
      }
    double[,] Xt = new double[p, n];
    for (int i = 0; i < p; i++)
      for (int r = 0; r < n; r++) Xt[i, r] = X[r, i];
    double[,] inv = Invert(XtX);
    double[,] pinv = new double[p, n];
    for (int i = 0; i < p; i++)
      for (int r = 0; r < n; r++) {
        double s = 0;
        for (int j = 0; j < p; j++) s += inv[i, j] * Xt[j, r];
        pinv[i, r] = s;
      }
    return pinv;
  }
  static double[,] Invert(double[,] A) {
    int n = A.GetLength(0);
    double[,] M = new double[n, 2 * n];
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) M[i, j] = A[i, j];
      M[i, n + i] = 1;
    }
    for (int col = 0; col < n; col++) {
      int piv = col;
      double maxv = Math.Abs(M[col, col]);
      for (int r = col + 1; r < n; r++)
        if (Math.Abs(M[r, col]) > maxv) { maxv = Math.Abs(M[r, col]); piv = r; }
      if (maxv < 1e-15) throw new Exception("singular");
      if (piv != col)
        for (int c = 0; c < 2 * n; c++) { double t = M[col, c]; M[col, c] = M[piv, c]; M[piv, c] = t; }
      double div = M[col, col];
      for (int c = 0; c < 2 * n; c++) M[col, c] /= div;
      for (int r = 0; r < n; r++) {
        if (r == col) continue;
        double f = M[r, col];
        if (Math.Abs(f) < 1e-18) continue;
        for (int c = 0; c < 2 * n; c++) M[r, c] -= f * M[col, c];
      }
    }
    double[,] Inv = new double[n, n];
    for (int i = 0; i < n; i++)
      for (int j = 0; j < n; j++) Inv[i, j] = M[i, n + j];
    return Inv;
  }
  public static double[] FitOls(double[,] X, double[] y) {
    int n = X.GetLength(0), p = X.GetLength(1);
    double[,] XtX = new double[p, p];
    double[] Xty = new double[p];
    for (int i = 0; i < p; i++) {
      for (int j = 0; j < p; j++) {
        double s = 0;
        for (int r = 0; r < n; r++) s += X[r, i] * X[r, j];
        XtX[i, j] = s;
      }
      double sy = 0;
      for (int r = 0; r < n; r++) sy += X[r, i] * y[r];
      Xty[i] = sy;
    }
    double[,] inv = Invert(XtX);
    double[] beta = new double[p];
    for (int i = 0; i < p; i++) {
      double s = 0;
      for (int j = 0; j < p; j++) s += inv[i, j] * Xty[j];
      beta[i] = s;
    }
    return beta;
  }
  public static void OlsLoocv(double[,] X, double[] y, out double loocvRmse, out double pearYYhat, out double spearYYhat, out double maxLev) {
    int n = X.GetLength(0), p = X.GetLength(1);
    double[] beta = FitOls(X, y);
    double[] yhat = new double[n];
    for (int r = 0; r < n; r++) {
      double s = 0;
      for (int c = 0; c < p; c++) s += X[r, c] * beta[c];
      yhat[r] = s;
    }
    pearYYhat = Pearson(yhat, y);
    spearYYhat = Spearman(yhat, y);
    double[,] P = XtXinvXt(X);
    double[] h = new double[n];
    for (int i = 0; i < n; i++) {
      double s = 0;
      for (int j = 0; j < p; j++) s += X[i, j] * P[j, i];
      h[i] = s;
    }
    maxLev = h[0];
    for (int i = 1; i < n; i++) if (h[i] > maxLev) maxLev = h[i];
    double sse = 0;
    for (int i = 0; i < n; i++) {
      double e = y[i] - yhat[i];
      double adj = 1.0 - h[i];
      if (Math.Abs(adj) < 1e-12) adj = 1e-12;
      double loo = e / adj;
      sse += loo * loo;
    }
    loocvRmse = Math.Sqrt(sse / n);
  }
  public static double LoocvNaiveMean(double[] y) {
    int n = y.Length;
    double sse = 0;
    for (int i = 0; i < n; i++) {
      double mu = 0;
      for (int j = 0; j < n; j++) if (j != i) mu += y[j];
      mu /= (n - 1);
      double e = y[i] - mu;
      sse += e * e;
    }
    return Math.Sqrt(sse / n);
  }
}
"@

$a = Import-Csv $alphaPath
$b = Import-Csv $barrierPath
$Rcol = if ($b[0].PSObject.Properties.Name -contains 'R_T_interp') { 'R_T_interp' }
        elseif ($b[0].PSObject.Properties.Name -contains 'R_T') { 'R_T' } else { 'R' }

$byT = @{}
foreach ($row in $a) { $byT[[double]$row.T_K] = $row }
$merged = New-Object System.Collections.Generic.List[object]
foreach ($row in $b) {
    $tk = [double]$row.T_K
    if ($byT.ContainsKey($tk)) {
        $merged.Add([pscustomobject]@{
            T_K = $tk
            kappa1 = [double]$byT[$tk].kappa1
            kappa2 = [double]$byT[$tk].kappa2
            alpha = [double]$byT[$tk].alpha
            R_T = [double]$row.$Rcol
        })
    }
}
$merged = $merged | Sort-Object T_K
if ($merged.Count -lt 4) { throw "Too few merged rows" }

$n = $merged.Count
$k1 = @($merged | ForEach-Object { $_.kappa1 })
$k2 = @($merged | ForEach-Object { $_.kappa2 })
$alp = @($merged | ForEach-Object { $_.alpha })
$yR = @($merged | ForEach-Object { $_.R_T })
$Ry = [double[]]::new($n)
for ($i = 0; $i -lt $n; $i++) { $Ry[$i] = [double]$yR[$i] }
$Tk = @($merged | ForEach-Object { $_.T_K })
$theta = @($merged | ForEach-Object { [Math]::Atan2($_.kappa2, $_.kappa1) })
$rMag = @($merged | ForEach-Object { [Math]::Sqrt($_.kappa1 * $_.kappa1 + $_.kappa2 * $_.kappa2) })

$outCsv = Join-Path $repoRoot 'tables\R_vs_state.csv'
$outRows = for ($i = 0; $i -lt $n; $i++) {
    [pscustomobject]@{
        T_K = $Tk[$i]; kappa1 = $k1[$i]; kappa2 = $k2[$i]; alpha = $alp[$i]
        theta_rad = $theta[$i]; r = $rMag[$i]; R_T = $yR[$i]
    }
}
$outRows | Export-Csv -Path $outCsv -NoTypeInformation

$uniNames = @('kappa1', 'kappa2', 'theta_rad', 'r')
$uni = @()
$coords = [System.Collections.ArrayList]@()
[void]$coords.Add($k1)
[void]$coords.Add($k2)
[void]$coords.Add($theta)
[void]$coords.Add($rMag)
for ($u = 0; $u -lt 4; $u++) {
    $xv = [double[]]($coords[$u])
    $p = [Agent23aMath]::Pearson($xv, $Ry)
    $s = [Agent23aMath]::Spearman($xv, $Ry)
    $uni += [pscustomobject]@{ coordinate = $uniNames[$u]; pearson_R = $p; spearman_R = $s }
}

function Add-FitRow {
    param([string]$id, $X)
    try {
        $null = [Agent23aMath]::FitOls($X, $Ry)
        $lo = [ref]0.0; $pear = [ref]0.0; $spear = [ref]0.0; $ml = [ref]0.0
        [void][Agent23aMath]::OlsLoocv($X, $Ry, $lo, $pear, $spear, $ml)
        return [pscustomobject]@{ model = $id; n = $script:n; loocv_rmse = $lo.Value; pearson_y_yhat = $pear.Value; spearman_y_yhat = $spear.Value; max_leverage = $ml.Value }
    } catch {
        return [pscustomobject]@{ model = $id; n = $script:n; loocv_rmse = [double]::NaN; pearson_y_yhat = [double]::NaN; spearman_y_yhat = [double]::NaN; max_leverage = [double]::NaN }
    }
}

$fitRows = @()
# R ~ kappa1
$X1 = New-Object 'double[,]' $n, 2
for ($rr = 0; $rr -lt $n; $rr++) { $X1[$rr, 0] = 1; $X1[$rr, 1] = $k1[$rr] }
$fitRows += Add-FitRow 'R ~ kappa1' $X1
# R ~ kappa1 + kappa2
$X2 = New-Object 'double[,]' $n, 3
for ($rr = 0; $rr -lt $n; $rr++) { $X2[$rr, 0] = 1; $X2[$rr, 1] = $k1[$rr]; $X2[$rr, 2] = $k2[$rr] }
$fitRows += Add-FitRow 'R ~ kappa1 + kappa2' $X2
# R ~ theta_rad
$X3 = New-Object 'double[,]' $n, 2
for ($rr = 0; $rr -lt $n; $rr++) { $X3[$rr, 0] = 1; $X3[$rr, 1] = $theta[$rr] }
$fitRows += Add-FitRow 'R ~ theta_rad' $X3
# R ~ theta_rad + r
$X4 = New-Object 'double[,]' $n, 3
for ($ri = 0; $ri -lt $n; $ri++) { $X4[$ri, 0] = 1; $X4[$ri, 1] = $theta[$ri]; $X4[$ri, 2] = $rMag[$ri] }
$fitRows += Add-FitRow 'R ~ theta_rad + r' $X4

$singles = @(
    @{ name = 'kappa1'; x = $k1 },
    @{ name = 'kappa2'; x = $k2 },
    @{ name = 'theta'; x = $theta },
    @{ name = 'r'; x = $rMag }
)
$bestName = 'kappa1'
$bestRmse = [double]::PositiveInfinity
foreach ($s in $singles) {
    $X1 = New-Object 'double[,]' $n, 2
    for ($rr = 0; $rr -lt $n; $rr++) { $X1[$rr, 0] = 1; $X1[$rr, 1] = $s.x[$rr] }
    try {
        $lo = [ref]0.0; $p = [ref]0.0; $sp = [ref]0.0; $ml = [ref]0.0
        [void][Agent23aMath]::OlsLoocv($X1, $Ry, $lo, $p, $sp, $ml)
        if ($lo.Value -lt $bestRmse) { $bestRmse = $lo.Value; $bestName = $s.name }
    } catch {}
}

$loocvNaive = [Agent23aMath]::LoocvNaiveMean($Ry)
$sigY = 0
$meanR = ($yR | Measure-Object -Average).Average
$sigY = [Math]::Sqrt((($yR | ForEach-Object { ($_ - $meanR) * ($_ - $meanR) } | Measure-Object -Sum).Sum / [Math]::Max(1, $n - 1)))

$valid = $fitRows | Where-Object { -not [double]::IsNaN($_.loocv_rmse) }
$bestState = $valid | Sort-Object loocv_rmse | Select-Object -First 1
$thrLink = 0.35
$maxUniPear = ($uni | ForEach-Object { [Math]::Abs($_.pearson_R) } | Measure-Object -Maximum).Maximum
$maxUniSpear = ($uni | ForEach-Object { [Math]::Abs($_.spearman_R) } | Measure-Object -Maximum).Maximum
$linkedUni = ($n -ge 4) -and (($maxUniPear -ge $thrLink) -or ($maxUniSpear -ge $thrLink))
$pearB = $bestState.pearson_y_yhat
$spearB = $bestState.spearman_y_yhat
$bestStateLoocv = $bestState.loocv_rmse
$predictable = ($bestStateLoocv -lt $loocvNaive) -and (([Math]::Abs($pearB) -ge 0.4 -and [Math]::Abs($spearB) -ge 0.35) -or ([Math]::Abs($pearB) -ge 0.5))
$flagLinked = if ($predictable -or $linkedUni) { 'YES' } else { 'NO' }

# PNG: theta vs R, color by T
Add-Type -AssemblyName System.Drawing
$W = 800; $H = 600
$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::White)
$padL = 70; $padR = 50; $padT = 40; $padB = 60
$plotW = $W - $padL - $padR; $plotH = $H - $padT - $padB
$tmin = ($Tk | Measure-Object -Minimum).Minimum
$tmax = ($Tk | Measure-Object -Maximum).Maximum
$xmin = ($theta | Measure-Object -Minimum).Minimum
$xmax = ($theta | Measure-Object -Maximum).Maximum
$ymin = ($yR | Measure-Object -Minimum).Minimum
$ymax = ($yR | Measure-Object -Maximum).Maximum
if ($xmax - $xmin -lt 1e-9) { $xmin -= 1; $xmax += 1 }
if ($ymax - $ymin -lt 1e-9) { $ymin -= 1; $ymax += 1 }
$dx = $xmax - $xmin; $dy = $ymax - $ymin
$xmin -= 0.05 * $dx; $xmax += 0.05 * $dx
$ymin -= 0.05 * $dy; $ymax += 0.05 * $dy
$dx = $xmax - $xmin; $dy = $ymax - $ymin
function Get-Sx([double]$xv) { return $padL + ($xv - $xmin) / $dx * $plotW }
function Get-Sy([double]$yv) { return $padT + $plotH - ($yv - $ymin) / $dy * $plotH }
$axisPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.5)
$gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 220, 220), 1)
for ($gi = 0; $gi -le 5; $gi++) {
    $gx = $xmin + $gi / 5.0 * $dx
    $gy = $ymin + $gi / 5.0 * $dy
    $g.DrawLine($gridPen, [int](Get-Sx $gx), $padT, [int](Get-Sx $gx), $padT + $plotH)
    $g.DrawLine($gridPen, $padL, [int](Get-Sy $gy), $padL + $plotW, [int](Get-Sy $gy))
}
$g.DrawRectangle($axisPen, $padL, $padT, $plotW, $plotH)
$font = New-Object System.Drawing.Font('Segoe UI', 11)
$brush = [System.Drawing.Brushes]::Black
$g.DrawString('theta = atan2(kappa2, kappa1) (rad)', $font, $brush, [float]($W / 2 - 160), [float]($H - 35))
$g.DrawString('R(T)', $font, $brush, 12, [float]($padT + 20))
# polyline
for ($i = 0; $i -lt $n - 1; $i++) {
    $penG = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(160, 160, 160), 1.2)
    $g.DrawLine($penG, [int](Get-Sx $theta[$i]), [int](Get-Sy $yR[$i]), [int](Get-Sx $theta[$i + 1]), [int](Get-Sy $yR[$i + 1]))
}
for ($i = 0; $i -lt $n; $i++) {
    $tn = if ($tmax - $tmin -lt 1e-9) { 0.5 } else { ($Tk[$i] - $tmin) / ($tmax - $tmin) }
    $col = [System.Drawing.Color]::FromArgb(255, [int](40 + 180 * $tn), [int](200 * (1 - $tn)), 220)
    $br = New-Object System.Drawing.SolidBrush($col)
    $g.FillEllipse($br, [int](Get-Sx $theta[$i] - 5), [int](Get-Sy $yR[$i] - 5), 10, 10)
}
$figPath = Join-Path $repoRoot 'figures\R_vs_theta.png'
if (-not (Test-Path (Split-Path $figPath))) { New-Item -ItemType Directory -Path (Split-Path $figPath) -Force | Out-Null }
$bmp.Save($figPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

$rep = @()
$rep += '# Aging R(T) vs collective state (Agent 23A)'
$rep += ''
$rep += '## Inputs'
$rep += "- **alpha_structure:** ``$($alphaPath.Replace('\','/'))``"
$rep += "- **barrier_descriptors:** ``$($barrierPath.Replace('\','/'))`` (column ``$Rcol`` -> ``R_T``)"
$rep += ''
$rep += '## Construction'
$rep += '- Merge on ``T_K``: ``kappa1``, ``kappa2``, ``alpha`` from ``alpha_structure``; ``R(T)`` from barrier table.'
$rep += '- ``theta_rad = atan2(kappa2, kappa1)``, ``r = hypot(kappa1, kappa2)``.'
$rep += ''
$rep += '## Univariate correlations (R vs coordinate)'
$rep += '| coordinate | Pearson | Spearman |'
$rep += '|---|---:|---:|'
foreach ($u in $uni) { $rep += "| $($u.coordinate) | $($u.pearson_R.ToString('G6')) | $($u.spearman_R.ToString('G6')) |" }
$rep += ''
$rep += '## Linear models (OLS + LOOCV RMSE)'
$rep += '| model | n | LOOCV RMSE | Pearson(y,yhat) | Spearman(y,yhat) | max leverage |'
$rep += '|---|---:|---:|---:|---:|---:|'
foreach ($f in $fitRows) {
    $rep += "| $($f.model) | $($f.n) | $($f.loocv_rmse.ToString('G6')) | $($f.pearson_y_yhat.ToString('G6')) | $($f.spearman_y_yhat.ToString('G6')) | $($f.max_leverage.ToString('G6')) |"
}
$rep += ''
$rep += "- **Best model (lowest LOOCV among the four):** ``$($bestState.model)`` (RMSE = $($bestStateLoocv.ToString('G6')))"
$rep += "- **LOOCV naive mean benchmark:** $($loocvNaive.ToString('G6')); **std(R):** $($sigY.ToString('G6'))"
$rep += ''
$rep += '## Final flags'
$rep += "- **AGING_LINKED_TO_STATE** = **$flagLinked** (YES if best multivariate model generalizes vs naive mean and/or max |rho|,|rho_s| >= $thrLink on univariate tests; n >= 4)"
$rep += "- **BEST_STATE_COORDINATE_FOR_R** = **$bestName** (lowest LOOCV among single-term {kappa1, kappa2, theta, r})"
$rep += ''
$rep += '*Primary MATLAB entry point: `analysis/run_aging_R_vs_collective_state_agent23a.m`. This file was generated by `tools/run_agent23a_R_vs_state.ps1` (numeric parity).*'
$repPath = Join-Path $repoRoot 'reports\R_state_report.md'
if (-not (Test-Path (Split-Path $repPath))) { New-Object -ItemType Directory -Path (Split-Path $repPath) -Force | Out-Null }
$rep -join "`n" | Set-Content -Path $repPath -Encoding utf8

Write-Host "AGING_LINKED_TO_STATE = $flagLinked"
Write-Host "BEST_STATE_COORDINATE_FOR_R = $bestName"
Write-Host "Wrote $outCsv"
Write-Host "Wrote $figPath"
Write-Host "Wrote $repPath"
