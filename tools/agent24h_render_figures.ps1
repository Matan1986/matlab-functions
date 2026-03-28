# Agent 24H: render PNG figures from canonical CSVs (no MATLAB required for CI/sandbox).
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$tbl = Join-Path $root "tables"
$fig = Join-Path $root "figures"
if (-not (Test-Path $fig)) { New-Item -ItemType Directory -Path $fig | Out-Null }

Add-Type -AssemblyName System.Drawing

function Get-Corr {
    param([double[]]$a, [double[]]$b)
    $n = [Math]::Min($a.Length, $b.Length)
    $aa = @(); $bb = @()
    for ($i = 0; $i -lt $n; $i++) {
        if ($a[$i] -eq $a[$i] -and $b[$i] -eq $b[$i]) { $aa += $a[$i]; $bb += $b[$i] }
    }
    if ($aa.Count -lt 3) { return [double]::NaN }
    $ma = ($aa | Measure-Object -Average).Average
    $mb = ($bb | Measure-Object -Average).Average
    $num = 0; $da = 0; $db = 0
    for ($i = 0; $i -lt $aa.Count; $i++) {
        $va = $aa[$i] - $ma; $vb = $bb[$i] - $mb
        $num += $va * $vb; $da += $va * $va; $db += $vb * $vb
    }
    if ($da -le 0 -or $db -le 0) { return [double]::NaN }
    return $num / [Math]::Sqrt($da * $db)
}

function Draw-ScatterPanel {
    param($g, [float]$x0, [float]$y0, [float]$w, [float]$h, [double[]]$xs, [double[]]$ys, [double[]]$cvals, [string]$xt, [string]$yt, [string]$title)
    $brushW = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(250,250,250))
    $g.FillRectangle($brushW, $x0, $y0, $w, $h)
    $penAx = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(180,180,180))
    $minx = ($xs | Measure-Object -Minimum).Minimum; $maxx = ($xs | Measure-Object -Maximum).Maximum
    $miny = ($ys | Measure-Object -Minimum).Minimum; $maxy = ($ys | Measure-Object -Maximum).Maximum
    $rx = [Math]::Max($maxx - $minx, 1e-9); $ry = [Math]::Max($maxy - $miny, 1e-9)
    $minc = ($cvals | Measure-Object -Minimum).Minimum; $maxc = ($cvals | Measure-Object -Maximum).Maximum
    $rc = [Math]::Max($maxc - $minc, 1e-9)
    for ($i = 0; $i -lt $xs.Count; $i++) {
        if ($xs[$i] -ne $xs[$i]) { continue }
        $px = $x0 + 40 + ($xs[$i] - $minx) / $rx * ($w - 55)
        $py = $y0 + $h - 35 - ($ys[$i] - $miny) / $ry * ($h - 50)
        $t = [int](255 * ($cvals[$i] - $minc) / $rc)
        $t = [Math]::Max(0, [Math]::Min(255, $t))
        $col = [System.Drawing.Color]::FromArgb(30, 80, 120 + $t / 2)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush $col), $px - 3, $py - 3, 7, 7)
    }
    $g.DrawRectangle($penAx, $x0, $y0, $w, $h)
    $font = New-Object System.Drawing.Font @("Segoe UI", 8.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
    $fontT = New-Object System.Drawing.Font @("Segoe UI", 9.0, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
    $g.DrawString($title, $fontT, [System.Drawing.Brushes]::Black, $x0 + 5, $y0 + 4)
    $g.DrawString($xt, $font, [System.Drawing.Brushes]::Black, $x0 + $w / 3, $y0 + $h - 22)
    $sf = New-Object System.Drawing.StringFormat
    $sf.FormatFlags = [System.Drawing.StringFormatFlags]::DirectionVertical
    $g.DrawString($yt, $font, [System.Drawing.Brushes]::Black, $x0 + 2, $y0 + $h / 3, $sf)
}

$csv = Import-Csv (Join-Path $tbl "alpha_structure.csv")
$TK = @(); $k1 = @(); $k2 = @(); $al = @(); $W = @(); $Sp = @(); $Ip = @(); $asym = @()
foreach ($row in $csv) {
    $TK += [double]$row.T_K
    $k1 += [double]$row.kappa1
    $k2 += [double]$row.kappa2
    $al += [double]$row.alpha
    $W += [double]$row.q90_minus_q50
    $Sp += [double]$row.S_peak
    $Ip += [double]$row.I_peak_mA
    $asym += [double]$row.asymmetry_q_spread
}

$W800 = 900; $H700 = 700
$bmp1 = New-Object System.Drawing.Bitmap $W800, $H700
$g1 = [System.Drawing.Graphics]::FromImage($bmp1)
$g1.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g1.Clear([System.Drawing.Color]::White)
$hw = ($W800 - 60) / 2; $hh = ($H700 - 80) / 2
Draw-ScatterPanel $g1 30 50 $hw $hh $W $k1 $TK "q90-q50 map (mA)" "kappa1" ("k1 vs spread rho={0:n2}" -f (Get-Corr $W $k1))
Draw-ScatterPanel $g1 (40 + $hw) 50 $hw $hh $Sp $k1 $TK "S_peak" "kappa1" ("k1 vs S_peak rho={0:n2}" -f (Get-Corr $Sp $k1))
Draw-ScatterPanel $g1 30 (60 + $hh) $hw $hh $Ip $k2 $TK "I_peak (mA)" "kappa2" ("k2 vs I_peak rho={0:n2}" -f (Get-Corr $Ip $k2))
Draw-ScatterPanel $g1 (40 + $hw) (60 + $hh) $hw $hh $asym $al $TK "asymmetry (map)" "alpha" ("alpha vs asym rho={0:n2}" -f (Get-Corr $asym $al))
$g1.DrawString("Latent decomposition scalars vs direct map / ridge observables", (New-Object System.Drawing.Font @("Segoe UI", 11.0, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)), [System.Drawing.Brushes]::Black, 30, 12)
$path1 = Join-Path $fig "latent_vs_observable_proxy_comparison.png"
$bmp1.Save($path1, [System.Drawing.Imaging.ImageFormat]::Png)
$g1.Dispose(); $bmp1.Dispose()

# Figure 2 — Phi2 metrics + text panel
$phi2 = Import-Csv (Join-Path $tbl "phi2_structure_metrics.csv") | Select-Object -First 1
$even = [double]$phi2.phi2_even_energy_fraction
$tight = [double]$phi2.phi2_center_energy_frac_abs_x_le_tight
$sh = [double]$phi2.phi2_shoulder_tail_ratio_R_over_L
$kc = [double]$phi2.phi2_best_kernel_abs_corr
$kname = $phi2.phi2_best_kernel_name
$W820 = 820; $H520 = 520
$bmp2 = New-Object System.Drawing.Bitmap $W820, $H520
$g2 = [System.Drawing.Graphics]::FromImage($bmp2)
$g2.Clear([System.Drawing.Color]::White)
$names = @("Even frac", "Tight center", "Shoulder R/L", "Kernel |r|")
$vals = @($even, $tight, $sh, $kc)
$bw = 60; $bx0 = 50; $by0 = 120; $mx = 1.15
for ($i = 0; $i -lt 4; $i++) {
    $hbar = [int](($vals[$i] / $mx) * 200)
    $g2.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(50,110,160))), $bx0 + $i * 90, $by0 + 200 - $hbar, $bw - 10, $hbar)
    $g2.DrawString($names[$i], (New-Object System.Drawing.Font @("Segoe UI", 8.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)), [System.Drawing.Brushes]::Black, $bx0 + $i * 90 - 5, $by0 + 210)
}
$g2.DrawString("Mode-2 shape: experimental descriptors", (New-Object System.Drawing.Font @("Segoe UI", 10.0, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)), [System.Drawing.Brushes]::Black, 50, 55)
$txt = @"
Phi1 (rank-1 correction)
Broad symmetric adjustment of the switching curve
away from the threshold-PDF backbone in normalized x.

Phi2 (rank-2 correction)
Mixed width/slope-like pattern on the ridge;
~$([math]::Round(100*$even))% even / ~$([math]::Round(100*(1-$even)))% odd;
localized near ridge center; best simple-template match |r| ~ $([math]::Round($kc,2)) ($kname).
"@
$g2.DrawString($txt.Trim(), (New-Object System.Drawing.Font @("Segoe UI", 10.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)), [System.Drawing.Brushes]::Black, 420, 60)
$g2.DrawString("Interpreting spatial modes without linear-algebra jargon", (New-Object System.Drawing.Font @("Segoe UI", 11.0, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)), [System.Drawing.Brushes]::Black, 50, 12)
$path2 = Join-Path $fig "phi1_phi2_in_experimental_language.png"
$bmp2.Save($path2, [System.Drawing.Imaging.ImageFormat]::Png)
$g2.Dispose(); $bmp2.Dispose()

# Figure 3 — bar comparison
$W780 = 780; $H420 = 420
$bmp3 = New-Object System.Drawing.Bitmap $W780, $H420
$g3 = [System.Drawing.Graphics]::FromImage($bmp3)
$g3.Clear([System.Drawing.Color]::White)
$y1a = 13.78698119261; $y1b = 11.9148173531162
$y2a = 0.0184738729675384; $y2b = 0.113456194057352
$left = 50; $top = 70; $pw = 280; $ph = 220
$g3.DrawString("Aging R(T): LOOCV RMSE", (New-Object System.Drawing.Font @("Segoe UI", 10.0, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)), [System.Drawing.Brushes]::Black, $left, $top - 35)
$mx1 = [Math]::Max($y1a, $y1b) * 1.15
$h1 = [int]($y1a / $mx1 * $ph); $h2 = [int]($y1b / $mx1 * $ph)
$g3.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(60,120,190))), $left + 30, $top + $ph - $h1, 50, $h1)
$g3.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(100,160,90))), $left + 120, $top + $ph - $h2, 50, $h2)
$g3.DrawString("spread only", (New-Object System.Drawing.Font @("Segoe UI", 8.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)), [System.Drawing.Brushes]::Black, $left + 15, $top + $ph + 5)
$g3.DrawString("+ kappa1", (New-Object System.Drawing.Font @("Segoe UI", 8.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)), [System.Drawing.Brushes]::Black, $left + 110, $top + $ph + 5)
$left2 = 400
$g3.DrawString("Latent ~ observable (LOOCV RMSE)", (New-Object System.Drawing.Font @("Segoe UI", 10.0, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)), [System.Drawing.Brushes]::Black, $left2, $top - 35)
$mx2 = [Math]::Max($y2a, $y2b) * 1.15
$u1 = [int]($y2a / $mx2 * $ph); $u2 = [int]($y2b / $mx2 * $ph)
$g3.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(140,90,60))), $left2 + 30, $top + $ph - $u1, 50, $u1)
$g3.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(140,90,60))), $left2 + 120, $top + $ph - $u2, 50, $u2)
$g3.DrawString("k1~W+S", (New-Object System.Drawing.Font @("Segoe UI", 8.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)), [System.Drawing.Brushes]::Black, $left2 + 25, $top + $ph + 5)
$g3.DrawString("k2~Ipeak", (New-Object System.Drawing.Font @("Segoe UI", 8.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)), [System.Drawing.Brushes]::Black, $left2 + 105, $top + $ph + 5)
$g3.DrawString("When observables replace or surround latent scalars (canonical agent tables)", (New-Object System.Drawing.Font @("Segoe UI", 11.0, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)), [System.Drawing.Brushes]::Black, 50, 12)
$path3 = Join-Path $fig "observable_replacement_summary.png"
$bmp3.Save($path3, [System.Drawing.Imaging.ImageFormat]::Png)
$g3.Dispose(); $bmp3.Dispose()

# Correlations CSV (mirror MATLAB script)
$rows = @()
$rows += [pscustomobject]@{ latent='kappa1'; observable='q90_minus_q50_measured'; pearson=(Get-Corr $W $k1); spearman=[double]::NaN; n=($W.Count) }
$rows += [pscustomobject]@{ latent='kappa1'; observable='S_peak'; pearson=(Get-Corr $Sp $k1); spearman=[double]::NaN; n=$Sp.Count }
$rows += [pscustomobject]@{ latent='kappa1'; observable='I_peak_mA'; pearson=(Get-Corr $Ip $k1); spearman=[double]::NaN; n=$Ip.Count }
$rows += [pscustomobject]@{ latent='kappa2'; observable='I_peak_mA'; pearson=(Get-Corr $Ip $k2); spearman=[double]::NaN; n=$Ip.Count }
$rows += [pscustomobject]@{ latent='alpha'; observable='asymmetry_q_spread_measured'; pearson=(Get-Corr $asym $al); spearman=[double]::NaN; n=$asym.Count }
$rows += [pscustomobject]@{ latent='alpha'; observable='q90_minus_q50_measured'; pearson=(Get-Corr $W $al); spearman=[double]::NaN; n=$W.Count }
$kpt = Import-Csv (Join-Path $tbl "kappa1_from_PT.csv")
$k1p = @(); $Wpt = @(); $Spp = @()
foreach ($r in $kpt) {
    $k1p += [double]$r.kappa1
    $Wpt += [double]$r.tail_width_q90_q50
    $Spp += [double]$r.S_peak
}
$mask = 0..($k1p.Count-1) | Where-Object { $k1p[$_] -eq $k1p[$_] -and $Wpt[$_] -eq $Wpt[$_] -and $Spp[$_] -eq $Spp[$_] }
$k1ok = @(); $Wok = @(); $Sok = @()
foreach ($i in $mask) { $k1ok += $k1p[$i]; $Wok += $Wpt[$i]; $Sok += $Spp[$i] }
$rows += [pscustomobject]@{ latent='kappa1'; observable='tail_width_q90_q50_PT'; pearson=(Get-Corr $Wok $k1ok); spearman=[double]::NaN; n=$k1ok.Count }
$rows += [pscustomobject]@{ latent='kappa1'; observable='S_peak_PT_row'; pearson=(Get-Corr $Sok $k1ok); spearman=[double]::NaN; n=$k1ok.Count }
$rows | Export-Csv (Join-Path $tbl "agent24h_correlations.csv") -NoTypeInformation

Write-Host "Wrote $path1"
Write-Host "Wrote $path2"
Write-Host "Wrote $path3"
Write-Host "Wrote $(Join-Path $tbl 'agent24h_correlations.csv')"
