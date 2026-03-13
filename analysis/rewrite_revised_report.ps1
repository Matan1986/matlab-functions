$runDir = 'C:\Dev\matlab-functions\results\cross_experiment\runs\run_2026_03_11_101123_switching_barrier_projection'
$metrics = Import-Csv (Join-Path $runDir 'tables\switching_barrier_alignment_metrics.csv') | Select-Object -First 1

$support = [double]$metrics.switch_support_fraction
$densityT = [double]$metrics.density_peak_T_K
$densityE = [double]$metrics.density_peak_E_meV
$motionT = [double]$metrics.motion_peak_T_K
$motionE = [double]$metrics.motion_peak_E_meV
$ampT = [double]$metrics.amplitude_peak_T_K
$ampE = [double]$metrics.amplitude_peak_E_meV
$motionDelta = [double]$metrics.motion_delta_to_nearest_steep_meV
$ampDelta = [double]$metrics.amplitude_delta_to_density_peak_meV
$rMP = [double]$metrics.pearson_motion_vs_density
$rsMP = [double]$metrics.spearman_motion_vs_density
$rMS = [double]$metrics.pearson_motion_vs_absSlope
$rsMS = [double]$metrics.spearman_motion_vs_absSlope
$rSP = [double]$metrics.pearson_Speak_vs_density
$rsSP = [double]$metrics.spearman_Speak_vs_density
$rSS = [double]$metrics.pearson_Speak_vs_absSlope
$rsSS = [double]$metrics.spearman_Speak_vs_absSlope
$same = $metrics.same_distribution_verdict
$motionTracks = [System.Convert]::ToBoolean($metrics.motion_tracks_steep_region)
$ampPinned = [System.Convert]::ToBoolean($metrics.amplitude_in_pinned_sector)
$windowLo = [double]$metrics.density_window_low_meV
$windowHi = [double]$metrics.density_window_high_meV
$steepLow = [double]$metrics.steep_low_E_meV
$steepHigh = [double]$metrics.steep_high_E_meV
$motionRegion = $metrics.motion_peak_region
$ampRegion = $metrics.amplitude_peak_region

if ($same -eq 'supported') {
    $sameSentence = "Switching samples the same temperature window of dynamic activity revealed by Relaxation. The projected ridge remains inside the modeled activation landscape support with switch_support_fraction = {0:N3}, so a shared activation landscape is supported at the level of these observables." -f $support
} elseif ($same -eq 'partial') {
    $sameSentence = "Switching overlaps substantially with the same temperature window of dynamic activity revealed by Relaxation, but not cleanly enough to claim a single fully shared landscape without qualification. The support fraction is switch_support_fraction = {0:N3}." -f $support
} else {
    $sameSentence = "Switching touches the Relaxation activity window, but the overlap is too limited to claim a clearly shared activation landscape from this analysis alone. The support fraction is switch_support_fraction = {0:N3}." -f $support
}

if ($motionTracks) {
    $motionSentence = "Ridge motion is strongest near the center of the Relaxation activity peak and remains close to a steep portion of the modeled activation coordinate. In the present mapping, the motion maximum occurs at T = {0:N0} K and E_eff = {1:N3} meV, with a separation of {2:N3} meV from the nearest steep-flank landmark." -f $motionT, $motionE, $motionDelta
} else {
    $motionSentence = "Ridge motion is strongest near the center of the Relaxation activity peak, around T = {0:N0} K. In the model-dependent effective activation coordinate, this corresponds to E_eff = {1:N3} meV, which is {2:N3} meV away from the nearest steep-flank landmark, so the motion-follows-the-steepest-P(E)-region picture should be treated as only partial." -f $motionT, $motionE, $motionDelta
}

if ($ampPinned) {
    $ampSentence = "S_peak is strongest in a dense, slowly varying part of the modeled activation landscape. The amplitude maximum occurs at T = {0:N0} K, corresponding under the mapping to E_eff = {1:N3} meV." -f $ampT, $ampE
} else {
    $ampSentence = "S_peak emphasizes a different part of the response window at lower temperatures. Its maximum occurs at T = {0:N0} K, corresponding under the model-dependent mapping to E_eff = {1:N3} meV, which is offset by {2:N3} meV from the temperature region of maximal activity identified by Relaxation." -f $ampT, $ampE, $ampDelta
}

$lines = @(
'# Switching Barrier Projection Report (Revised Interpretation)',
'',
'## Inputs',
'- Relaxation source run: run_2026_03_10_175048_relaxation_observable_stability_audit.',
'- Switching source run: run_2026_03_10_112659_alignment_audit.',
'- Effective-coordinate mapping used: E_eff(T) = k_B T ln(tau(T)/tau0) with tau0 = 1e-9 s.',
'- In this report, A(T) is interpreted cautiously as an empirical dynamic participation landscape versus temperature, not as a proven physical barrier-height distribution.',
'',
'## Revised Interpretation',
"1. $sameSentence",
"2. $motionSentence",
"3. $ampSentence",
'4. Taken together, the two switching observables appear to probe different dynamical sectors of the same shared activation landscape, rather than directly sampling different parts of a proven barrier distribution.',
'',
'## Correlations',
("- corr(motion, P_eff) = {0:N4} Pearson, {1:N4} Spearman." -f $rMP, $rsMP),
("- corr(motion, |dP/dE|) = {0:N4} Pearson, {1:N4} Spearman." -f $rMS, $rsMS),
("- corr(S_peak, P_eff) = {0:N4} Pearson, {1:N4} Spearman." -f $rSP, $rsSP),
("- corr(S_peak, |dP/dE|) = {0:N4} Pearson, {1:N4} Spearman." -f $rSS, $rsSS),
'',
'## Reference Landmarks',
("- Temperature region of maximal Relaxation activity: T = {0:N0} K, corresponding under the model-dependent activation-coordinate mapping to E_eff = {1:N3} meV." -f $densityT, $densityE),
("- Central activity window in the effective coordinate: {0:N3} to {1:N3} meV." -f $windowLo, $windowHi),
("- Steep-landscape reference points in the effective coordinate: {0:N3} meV and {1:N3} meV." -f $steepLow, $steepHigh),
("- Ridge-motion maximum: T = {0:N0} K, E_eff = {1:N3} meV, region = {2}." -f $motionT, $motionE, $motionRegion),
("- Switching-amplitude maximum: T = {0:N0} K, E_eff = {1:N3} meV, region = {2}." -f $ampT, $ampE, $ampRegion),
'',
'## Interpretation Caveats',
'- Relaxation constrains dynamic participation versus temperature.',
'- The temperature-to-E_eff mapping relies on modeling assumptions.',
'- The barrier interpretation should be considered provisional.'
)

$revisedPath = Join-Path $runDir 'reports\switching_barrier_projection_report_revised.md'
$lines -join "`r`n" | Set-Content -Path $revisedPath
$zipPath = Join-Path $runDir 'review\switching_barrier_projection_bundle.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $runDir 'tables'), (Join-Path $runDir 'figures'), (Join-Path $runDir 'reports'), (Join-Path $runDir 'run_manifest.json'), (Join-Path $runDir 'config_snapshot.json'), (Join-Path $runDir 'log.txt'), (Join-Path $runDir 'run_notes.txt') -DestinationPath $zipPath -Force
Get-Content $revisedPath
