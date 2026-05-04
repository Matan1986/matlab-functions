param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Write-StatusCsv {
    param(
        [hashtable]$Verdicts,
        [string]$Path
    )
    $rows = @()
    foreach ($k in ($Verdicts.Keys | Sort-Object)) {
        $rows += [pscustomobject]@{
            verdict_key = $k
            verdict_value = $Verdicts[$k]
        }
    }
    $rows | Export-Csv -NoTypeInformation -Encoding UTF8 $Path
}

$tablesDir = Join-Path $RepoRoot 'tables'
$reportsDir = Join-Path $RepoRoot 'reports'
$outFigDir = Join-Path $RepoRoot 'results/switching/figures/canonical_paper'
$scriptsDir = Join-Path $RepoRoot 'scripts'
$manifestPath = Join-Path $tablesDir 'switching_canonical_paper_figures_manifest.csv'
$statusPath = Join-Path $tablesDir 'switching_canonical_paper_figures_status.csv'
$reportPath = Join-Path $reportsDir 'switching_canonical_paper_figures.md'

if (-not (Test-Path $tablesDir)) { New-Item -ItemType Directory -Path $tablesDir -Force | Out-Null }
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }
if (-not (Test-Path $outFigDir)) { New-Item -ItemType Directory -Path $outFigDir -Force | Out-Null }

$inputPaths = [ordered]@{
    switching_canonical_S_long = Join-Path $RepoRoot 'results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv'
    p0_collapse_metrics = Join-Path $tablesDir 'switching_P0_old_collapse_freeze_metrics.csv'
    p0_effective_values = Join-Path $tablesDir 'switching_P0_effective_observables_values.csv'
    p1_asymmetry_values = Join-Path $tablesDir 'switching_P1_asymmetry_LR_values.csv'
    p2_t22_metrics = Join-Path $tablesDir 'switching_P2_T22_crossover_metrics.csv'
    p2_t22_neighbors = Join-Path $tablesDir 'switching_P2_T22_crossover_neighbor_contrasts.csv'
    figure_recovery_decision = Join-Path $tablesDir 'switching_figure_recovery_decision.csv'
    figure_recovery_status = Join-Path $tablesDir 'switching_figure_recovery_status.csv'
}

$missing = @()
foreach ($kv in $inputPaths.GetEnumerator()) {
    if (-not (Test-Path $kv.Value)) { $missing += $kv.Value }
}

$mainPng = Join-Path $outFigDir 'switching_main_candidate_map_cuts_collapse.png'
$mainPdf = Join-Path $outFigDir 'switching_main_candidate_map_cuts_collapse.pdf'
$mainFig = Join-Path $outFigDir 'switching_main_candidate_map_cuts_collapse.fig'
$suppPng = Join-Path $outFigDir 'switching_supp_Xeff_components.png'
$suppPdf = Join-Path $outFigDir 'switching_supp_Xeff_components.pdf'
$suppFig = Join-Path $outFigDir 'switching_supp_Xeff_components.fig'

$verdict = @{
    CANONICAL_PAPER_FIGURES_GENERATED = 'NO'
    CANONICAL_S_USED = 'NO'
    P0_COLLAPSE_USED = 'NO'
    P0_EFFECTIVE_OBSERVABLES_USED = 'NO'
    P1_ASYMMETRY_USED = 'NO'
    P2_T22_USED = 'NO'
    MAIN_CANDIDATE_FIGURE_WRITTEN = 'NO'
    SUPPLEMENT_CANDIDATE_FIGURE_WRITTEN = 'NO'
    X_EFF_PRIMARY_DOMAIN_AXIS_SCALING = 'NO'
    ABOVE_31P5_DIAGNOSTIC_EXCLUDED_FROM_XEFF_AXIS_LIMITS = 'NO'
    T22_INCLUDED_IN_PRIMARY_DOMAIN = 'YES'
    ABOVE_31P5_DIAGNOSTIC_ONLY = 'YES'
    X_EFF_LABEL_USED = 'YES'
    X_CANON_CLAIMED = 'NO'
    UNIQUE_W_CLAIMED = 'NO'
    SAFE_TO_WRITE_SCALING_CLAIM = 'NO'
    CROSS_MODULE_SYNTHESIS_PERFORMED = 'NO'
}

if ($missing.Count -gt 0) {
    @(
        [pscustomobject]@{ artifact_key = 'missing_inputs'; artifact_path = ($missing -join '; '); artifact_type = 'input'; generated = 'NO'; notes = 'Required canonical/recovery input missing.' }
    ) | Export-Csv -NoTypeInformation -Encoding UTF8 $manifestPath
    Write-StatusCsv -Verdicts $verdict -Path $statusPath
    $lines = @(
        '# Switching canonical paper-candidate figures',
        '',
        'Figure generation did not run because required inputs are missing.',
        '',
        '## Missing inputs',
        ($missing | ForEach-Object { '- `' + $_ + '`' }),
        '',
        'Manifest and status were written.'
    )
    $lines | Set-Content -Encoding UTF8 $reportPath
    Write-Host "Missing inputs; wrote manifest/status/report."
    exit 0
}

$verdict.CANONICAL_S_USED = 'YES'
$verdict.P0_COLLAPSE_USED = 'YES'
$verdict.P0_EFFECTIVE_OBSERVABLES_USED = 'YES'
$verdict.P1_ASYMMETRY_USED = 'YES'
$verdict.P2_T22_USED = 'YES'

$tmpMatlab = Join-Path $scriptsDir 'tmp_run_switching_canonical_paper_figures.m'
$repoRootEsc = $RepoRoot.Replace('\', '\\')
$outFigDirEsc = $outFigDir.Replace('\', '\\')
$sLongEsc = $inputPaths.switching_canonical_S_long.Replace('\', '\\')
$p0Esc = $inputPaths.p0_effective_values.Replace('\', '\\')
$p1Esc = $inputPaths.p1_asymmetry_values.Replace('\', '\\')

$matlabScript = @"
clear; clc;
repoRoot = '$repoRootEsc';
outFigDir = '$outFigDirEsc';
sLongPath = '$sLongEsc';
p0Path = '$p0Esc';
p1Path = '$p1Esc';

if exist(outFigDir, 'dir') ~= 7
    mkdir(outFigDir);
end

S = readtable(sLongPath);
P0 = readtable(p0Path);
P1 = readtable(p1Path);

reqS = {'T_K','current_mA','S_percent'};
for i = 1:numel(reqS)
    if ~ismember(reqS{i}, S.Properties.VariableNames)
        error('Missing required S_long column: %s', reqS{i});
    end
end
reqP0 = {'T_K','I_peak_mA','S_peak','W_I_mA','in_primary_domain_T_lt_31p5','above_31p5_diagnostic_only'};
for i = 1:numel(reqP0)
    if ~ismember(reqP0{i}, P0.Properties.VariableNames)
        error('Missing required P0 column: %s', reqP0{i});
    end
end

T = double(S.T_K);
I = double(S.current_mA);
Sv = double(S.S_percent);
v = isfinite(T) & isfinite(I) & isfinite(Sv);
T = T(v); I = I(v); Sv = Sv(v);
G = groupsummary(table(T,I,Sv), {'T','I'}, 'mean', {'Sv'});
allT = unique(double(G.T), 'sorted');
allI = unique(double(G.I), 'sorted');
M = nan(numel(allT), numel(allI));
for it = 1:numel(allT)
    for ii = 1:numel(allI)
        m = abs(double(G.T) - allT(it)) < 1e-9 & abs(double(G.I) - allI(ii)) < 1e-9;
        if any(m), M(it,ii) = double(G.mean_Sv(find(m,1))); end
    end
end

isPrimary = strcmpi(string(P0.in_primary_domain_T_lt_31p5), 'YES');
isDiag = strcmpi(string(P0.above_31p5_diagnostic_only), 'YES');
tp = double(P0.T_K);
ip = double(P0.I_peak_mA);
sp = double(P0.S_peak);
wp = double(P0.W_I_mA);
dcol = nan(size(tp));
if ismember('collapse_defect_vs_T_old_style', P0.Properties.VariableNames)
    dcol = double(P0.collapse_defect_vs_T_old_style);
end

fig1 = figure('Color', 'w', 'Visible', 'off', 'Position', [60 60 1700 980]);
tl1 = tiledlayout(fig1, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl1, 1);
imagesc(ax1, allI, allT, M);
set(ax1, 'YDir', 'normal');
xlabel(ax1, 'Current (mA)');
ylabel(ax1, 'Temperature (K)');
title(ax1, 'Canonical S(I,T) map');
cb1 = colorbar(ax1);
cb1.Label.String = 'S (%)';
hold(ax1, 'on');
plot(ax1, [min(allI) max(allI)], [31.5 31.5], 'k--', 'LineWidth', 1.0);
plot(ax1, min(allI) + 0.06*(max(allI)-min(allI)), 22, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 6);
hold(ax1, 'off');

ax2 = nexttile(tl1, 2);
cutCandidates = [10 22 30 32 34];
hold(ax2, 'on');
leg = {};
for k = 1:numel(cutCandidates)
    tk = cutCandidates(k);
    m = abs(T - tk) < 1e-9;
    if ~any(m), continue; end
    Ii = I(m); Si = Sv(m);
    [Ii, ord] = sort(Ii, 'ascend');
    Si = Si(ord);
    if tk == 22
        plot(ax2, Ii, Si, '-', 'LineWidth', 2.4, 'Color', [0.85 0.15 0.15]);
    elseif tk >= 31.5
        plot(ax2, Ii, Si, '--', 'LineWidth', 1.6);
    else
        plot(ax2, Ii, Si, '-', 'LineWidth', 1.7);
    end
    if tk >= 31.5
        leg{end+1} = sprintf('%d K diagnostic', tk); %#ok<AGROW>
    elseif tk == 22
        leg{end+1} = '22 K (internal crossover candidate)'; %#ok<AGROW>
    else
        leg{end+1} = sprintf('%d K primary', tk); %#ok<AGROW>
    end
end
hold(ax2, 'off');
xlabel(ax2, 'Current (mA)');
ylabel(ax2, 'S (%)');
title(ax2, 'Representative fixed-temperature cuts');
if ~isempty(leg), legend(ax2, leg, 'Location', 'best', 'Interpreter', 'none'); end
grid(ax2, 'on');

ax3 = nexttile(tl1, 3);
hold(ax3, 'on');
for i = 1:height(P0)
    if ~isPrimary(i), continue; end
    if ~(isfinite(tp(i)) && isfinite(ip(i)) && isfinite(sp(i)) && isfinite(wp(i)) && wp(i) > 0 && sp(i) > 0), continue; end
    m = abs(T - tp(i)) < 1e-9;
    if ~any(m), continue; end
    x = (I(m) - ip(i)) ./ wp(i);
    y = Sv(m) ./ sp(i);
    [x, ord] = sort(x, 'ascend');
    y = y(ord);
    if abs(tp(i) - 22) < 1e-9
        plot(ax3, x, y, '-', 'LineWidth', 2.6, 'Color', [0.85 0.15 0.15]);
    else
        plot(ax3, x, y, '-', 'LineWidth', 1.2, 'Color', [0.15 0.4 0.8 0.45]);
    end
end
hold(ax3, 'off');
xlabel(ax3, 'x = (I - I_{peak}) / W_I');
ylabel(ax3, 'y = S / S_{peak}');
title(ax3, 'Primary-domain effective collapse (T < 31.5 K)');
grid(ax3, 'on');

ax4 = nexttile(tl1, 4);
hold(ax4, 'on');
mP = isPrimary & isfinite(dcol);
plot(ax4, tp(mP), dcol(mP), '-o', 'LineWidth', 1.6, 'MarkerSize', 5, 'Color', [0.1 0.45 0.75]);
mD = isDiag & isfinite(dcol);
if any(mD)
    plot(ax4, tp(mD), dcol(mD), 'x', 'LineWidth', 1.6, 'MarkerSize', 7, 'Color', [0.45 0.45 0.45]);
end
m22 = abs(tp - 22) < 1e-9 & isfinite(dcol);
if any(m22)
    plot(ax4, tp(m22), dcol(m22), 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
end
plot(ax4, [31.5 31.5], ylim(ax4), 'k--', 'LineWidth', 1.0);
hold(ax4, 'off');
xlabel(ax4, 'Temperature (K)');
ylabel(ax4, 'Collapse defect / organization metric');
title(ax4, 'Collapse metric vs T (22 K highlighted)');
legend(ax4, {'Primary domain','Diagnostic-only (>=31.5K)','22 K'}, 'Location', 'best');
grid(ax4, 'on');

title(tl1, 'Switching main candidate: map + cuts + primary-domain effective collapse');
exportgraphics(fig1, fullfile(outFigDir, 'switching_main_candidate_map_cuts_collapse.png'), 'Resolution', 300);
exportgraphics(fig1, fullfile(outFigDir, 'switching_main_candidate_map_cuts_collapse.pdf'));
savefig(fig1, fullfile(outFigDir, 'switching_main_candidate_map_cuts_collapse.fig'));
close(fig1);

asymY = nan(size(tp));
asymLabel = 'asym_{WI}';
if ismember('asym_lr_sum', P1.Properties.VariableNames)
    asymY = nan(size(tp));
    for i = 1:numel(tp)
        m = abs(double(P1.T_K) - tp(i)) < 1e-9;
        if any(m)
            asymY(i) = double(P1.asym_lr_sum(find(m,1)));
        end
    end
    asymLabel = 'asym_{lr-sum}';
elseif ismember('asym_WI', P0.Properties.VariableNames)
    asymY = double(P0.asym_WI);
    asymLabel = 'asym_{WI}';
end

fig2 = figure('Color', 'w', 'Visible', 'off', 'Position', [60 60 1700 980]);
tl2 = tiledlayout(fig2, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

series = {
    'X_{eff}(T) = I_{peak}/(W_I S_{peak})', double(P0.X_eff), 'X_{eff}';
    'I_{peak}(T)', double(P0.I_peak_mA), 'I_{peak} (mA)';
    'W_I(T) recovered old-collapse width/gauge width', double(P0.W_I_mA), 'W_I (mA)';
    'S_{peak}(T)', double(P0.S_peak), 'S_{peak}';
    sprintf('%s(T)', asymLabel), asymY, asymLabel;
    'Primary-domain boundary markers', nan(size(tp)), ''
};

for j = 1:6
    ax = nexttile(tl2, j);
    hold(ax, 'on');
    yj = series{j,2};
    if all(~isfinite(yj))
        text(ax, 0.05, 0.7, 'Boundary reference only', 'Units', 'normalized');
    else
        pMask = isPrimary & isfinite(yj);
        dMask = isDiag & isfinite(yj);
        plot(ax, tp(pMask), yj(pMask), '-o', 'LineWidth', 1.6, 'MarkerSize', 5, 'Color', [0.1 0.45 0.75]);
        if any(dMask)
            plot(ax, tp(dMask), yj(dMask), 'x', 'LineWidth', 1.5, 'MarkerSize', 7, 'Color', [0.45 0.45 0.45]);
        end
        m22 = abs(tp - 22) < 1e-9 & isfinite(yj);
        if any(m22)
            plot(ax, tp(m22), yj(m22), 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
        end
        if j == 1
            % X_eff panel axis scaling: use only finite primary-domain values.
            yPrimary = yj(pMask);
            yPrimary = yPrimary(isfinite(yPrimary));
            if ~isempty(yPrimary)
                yMin = min(yPrimary);
                yMax = max(yPrimary);
                if yMax > yMin
                    yPad = 0.08 * (yMax - yMin);
                else
                    yPad = max(0.5, 0.08 * max(abs(yMax), 1));
                end
                ylim(ax, [yMin - yPad, yMax + yPad]);
                text(ax, 0.03, 0.97, ...
                    'Y-limits set by primary-domain values; above-31.5K diagnostic points shown but excluded from axis scaling.', ...
                    'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 8, ...
                    'BackgroundColor', [1 1 1 0.70], 'Margin', 2);
            end
        end
    end
    xl = xlim(ax);
    if isempty(xl) || any(~isfinite(xl)), xl = [min(tp)-1 max(tp)+1]; end
    plot(ax, [31.5 31.5], ylim(ax), 'k--', 'LineWidth', 1.0);
    xlim(ax, [min(tp)-1 max(tp)+1]);
    title(ax, series{j,1}, 'Interpreter', 'tex');
    xlabel(ax, 'Temperature (K)');
    if strlength(string(series{j,3})) > 0
        ylabel(ax, series{j,3}, 'Interpreter', 'tex');
    end
    grid(ax, 'on');
    hold(ax, 'off');
end

title(tl2, 'Switching supplement candidate: X_{eff} and component observables');
exportgraphics(fig2, fullfile(outFigDir, 'switching_supp_Xeff_components.png'), 'Resolution', 300);
exportgraphics(fig2, fullfile(outFigDir, 'switching_supp_Xeff_components.pdf'));
savefig(fig2, fullfile(outFigDir, 'switching_supp_Xeff_components.fig'));
close(fig2);
"@

$matlabScript | Set-Content -Encoding ASCII -Path $tmpMatlab

$wrapperPath = Join-Path $RepoRoot 'tools/run_matlab_safe.bat'
$matlabOk = $false
$matlabErr = ''
try {
    & $wrapperPath $tmpMatlab
    if ($LASTEXITCODE -ne 0) {
        throw "MATLAB wrapper failed with exit code $LASTEXITCODE"
    }
    $matlabOk = $true
} catch {
    $matlabErr = $_.Exception.Message
}

$mainWritten = (Test-Path $mainPng) -and (Test-Path $mainPdf) -and (Test-Path $mainFig)
$suppWritten = (Test-Path $suppPng) -and (Test-Path $suppPdf) -and (Test-Path $suppFig)
if ($matlabOk -and $mainWritten -and $suppWritten) {
    $verdict.CANONICAL_PAPER_FIGURES_GENERATED = 'YES'
    $verdict.MAIN_CANDIDATE_FIGURE_WRITTEN = 'YES'
    $verdict.SUPPLEMENT_CANDIDATE_FIGURE_WRITTEN = 'YES'
    $verdict.X_EFF_PRIMARY_DOMAIN_AXIS_SCALING = 'YES'
    $verdict.ABOVE_31P5_DIAGNOSTIC_EXCLUDED_FROM_XEFF_AXIS_LIMITS = 'YES'
}

$manifest = @(
    [pscustomobject]@{ artifact_key = 'main_png'; artifact_path = $mainPng; artifact_type = 'figure_png'; generated = $(if (Test-Path $mainPng) { 'YES' } else { 'NO' }); notes = 'Main candidate: map/cuts/collapse panel.' }
    [pscustomobject]@{ artifact_key = 'main_pdf'; artifact_path = $mainPdf; artifact_type = 'figure_pdf'; generated = $(if (Test-Path $mainPdf) { 'YES' } else { 'NO' }); notes = 'Main candidate PDF.' }
    [pscustomobject]@{ artifact_key = 'main_fig'; artifact_path = $mainFig; artifact_type = 'figure_fig'; generated = $(if (Test-Path $mainFig) { 'YES' } else { 'NO' }); notes = 'Main candidate MATLAB figure file.' }
    [pscustomobject]@{ artifact_key = 'supp_png'; artifact_path = $suppPng; artifact_type = 'figure_png'; generated = $(if (Test-Path $suppPng) { 'YES' } else { 'NO' }); notes = 'Supplement candidate: X_eff/components/asymmetry.' }
    [pscustomobject]@{ artifact_key = 'supp_pdf'; artifact_path = $suppPdf; artifact_type = 'figure_pdf'; generated = $(if (Test-Path $suppPdf) { 'YES' } else { 'NO' }); notes = 'Supplement candidate PDF.' }
    [pscustomobject]@{ artifact_key = 'supp_fig'; artifact_path = $suppFig; artifact_type = 'figure_fig'; generated = $(if (Test-Path $suppFig) { 'YES' } else { 'NO' }); notes = 'Supplement candidate MATLAB figure file.' }
    [pscustomobject]@{ artifact_key = 'temp_matlab_script'; artifact_path = $tmpMatlab; artifact_type = 'temp_script'; generated = $(if (Test-Path $tmpMatlab) { 'YES' } else { 'NO' }); notes = 'Generated by this PS1 for wrapper execution.' }
)
$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 $manifestPath

Write-StatusCsv -Verdicts $verdict -Path $statusPath

$reportLines = @()
$reportLines += '# Switching canonical paper-candidate figures'
$reportLines += ''
$reportLines += 'Figure-generation only pass using closed P0/P1/P2 + recovery inventory outputs.'
$reportLines += 'No scientific logic, recipes, metrics, or claim boundaries were modified.'
$reportLines += ''
$reportLines += '## Inputs used'
foreach ($kv in $inputPaths.GetEnumerator()) {
    $reportLines += ('- `' + $kv.Value + '`')
}
$reportLines += ''
$reportLines += '## Outputs'
$reportLines += ('- `' + $mainPng + '`')
$reportLines += ('- `' + $mainPdf + '`')
$reportLines += ('- `' + $mainFig + '`')
$reportLines += ('- `' + $suppPng + '`')
$reportLines += ('- `' + $suppPdf + '`')
$reportLines += ('- `' + $suppFig + '`')
$reportLines += ('- `' + $manifestPath + '`')
$reportLines += ('- `' + $statusPath + '`')
$reportLines += ''
$reportLines += '## Label and boundary controls'
$reportLines += '- Uses `X_eff` labeling (no `X_canon` claims).'
$reportLines += '- Uses `W_I` as recovered old-collapse width/gauge width (no unique-`W` claim).'
$reportLines += '- Collapse panel is labeled primary-domain effective collapse (T_K < 31.5 K).'
$reportLines += '- 22 K is highlighted as internal crossover/reorganization candidate.'
$reportLines += '- 32/34 K are diagnostic-only and not mixed into primary collapse claim.'
$reportLines += '- X_eff panel y-limits are set using finite primary-domain values only; above-31.5K diagnostic points are shown but excluded from axis scaling.'
$reportLines += ''
$reportLines += '## Execution status'
$reportLines += ('- MATLAB wrapper run success: ' + $(if ($matlabOk) { 'YES' } else { 'NO' }))
if (-not $matlabOk) {
    $reportLines += ('- MATLAB wrapper error: ' + $matlabErr)
}
$reportLines += ''
$reportLines += '## Verdicts'
foreach ($k in ($verdict.Keys | Sort-Object)) {
    $reportLines += ('- ' + $k + ' = ' + $verdict[$k])
}
$reportLines | Set-Content -Encoding UTF8 $reportPath

Write-Host "Wrote:"
Write-Host $manifestPath
Write-Host $statusPath
Write-Host $reportPath
