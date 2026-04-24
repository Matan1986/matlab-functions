clear; clc;

repoRoot = 'c:/Dev/matlab-functions';
cd(repoRoot);

addpath(fullfile(repoRoot, 'Aging'));
addpath(fullfile(repoRoot, 'Aging', 'pipeline'));

tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
figDir = fullfile(repoRoot, 'results', 'aging', 'figures');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end
if exist(figDir, 'dir') ~= 7, mkdir(figDir); end

pList = [80, 90, 95];
runByP = cell(numel(pList), 1);

for k = 1:numel(pList)
    cfg = agingConfig('MG119_60min');
    cfg.agingMetricMode = 'direct';
    cfg.AFM_metric_main = 'area';
    cfg.AFM_percentile = pList(k);
    cfg.doPlotting = false;
    cfg.enableStage7 = false;

    state = Main_Aging(cfg);
    runByP{k} = state.pauseRuns;
end

Tp = [runByP{1}.waitK]';
AFM_RMS = [runByP{1}.AFM_RMS]';
AFM_p80 = [runByP{1}.AFM_percentile]';
AFM_p90 = [runByP{2}.AFM_percentile]';
AFM_p95 = [runByP{3}.AFM_percentile]';

FM_signed = nan(numel(Tp), 1);
for i = 1:numel(Tp)
    pr = runByP{1}(i);
    if isfield(pr, 'FM_signed') && isfinite(pr.FM_signed)
        FM_signed(i) = pr.FM_signed;
    elseif isfield(pr, 'FM_step_raw') && isfinite(pr.FM_step_raw)
        FM_signed(i) = pr.FM_step_raw;
    end
end

outTbl = table(Tp, AFM_RMS, AFM_p80, AFM_p90, AFM_p95, FM_signed);
outPath = fullfile(tablesDir, 'afm_percentile_sensitivity.csv');
writetable(outTbl, outPath);

% Optional plot
h = figure('Color', 'w', 'Name', 'AFM Percentiles vs Tp', 'NumberTitle', 'off');
hold on;
plot(Tp, AFM_p80, '-o', 'LineWidth', 1.5, 'DisplayName', 'AFM p80');
plot(Tp, AFM_p90, '-o', 'LineWidth', 1.5, 'DisplayName', 'AFM p90');
plot(Tp, AFM_p95, '-o', 'LineWidth', 1.5, 'DisplayName', 'AFM p95');
xlabel('Tp (K)');
ylabel('AFM percentile (\mu_B / Co)');
legend('Location', 'best');
box on;
grid off;
figPath = fullfile(figDir, 'AFM_percentiles_vs_Tp.png');
saveas(h, figPath);
close(h);

% Verdicts
rel80_95 = abs(AFM_p95 - AFM_p80) ./ max(abs(AFM_p90), eps);
maskFiniteRel = isfinite(rel80_95);
if any(maskFiniteRel)
    percentileSensitive = any(rel80_95(maskFiniteRel) > 0.15);
else
    percentileSensitive = false;
end

rankStable = true;
for i = 1:numel(Tp)
    vals = [AFM_p80(i), AFM_p90(i), AFM_p95(i)];
    if any(~isfinite(vals))
        continue;
    end
    if ~(vals(1) <= vals(2) && vals(2) <= vals(3))
        rankStable = false;
        break;
    end
end

choiceCritical = percentileSensitive;

reportPath = fullfile(reportsDir, 'afm_percentile_sensitivity_report.md');
fid = fopen(reportPath, 'w');
fprintf(fid, '# AFM Percentile Sensitivity Report\n\n');
fprintf(fid, 'This run keeps direct decomposition unchanged and varies only `cfg.AFM_percentile` = 80, 90, 95.\n\n');
fprintf(fid, '## Final Verdicts\n\n');
fprintf(fid, '- PERCENTILE_SENSITIVE = %s\n', yn(percentileSensitive));
fprintf(fid, '- PERCENTILE_RANKING_STABLE = %s\n', yn(rankStable));
fprintf(fid, '- CHOICE_OF_PERCENTILE_CRITICAL = %s\n\n', yn(choiceCritical));
fprintf(fid, '## Interpretation\n\n');
if percentileSensitive
    fprintf(fid, 'The AFM amplitude level changes materially between 80/90/95 for at least part of Tp, so percentile choice affects quantitative magnitude.\n');
else
    fprintf(fid, 'AFM amplitude differences between 80/90/95 stay limited across Tp, so percentile choice is not critical for this dataset.\n');
end
if rankStable
    fprintf(fid, 'The percentile ordering remains monotonic (`p80 <= p90 <= p95`) across finite Tp values, indicating stable trend ordering.\n');
else
    fprintf(fid, 'Percentile ordering is not consistently monotonic, indicating instability in percentile-based ranking.\n');
end
fprintf(fid, '\nDoes physical trend depend on choosing 80 vs 90 vs 95? %s\n', ternary(percentileSensitive, 'Partly yes (magnitude level), while ordering remains stable if monotonic.', 'No strong dependence in this run.'));
fprintf(fid, '\n## Outputs\n\n');
fprintf(fid, '- `%s`\n', outPath);
fprintf(fid, '- `%s`\n', figPath);
fclose(fid);

fprintf('Wrote table: %s\n', outPath);
fprintf('Wrote plot: %s\n', figPath);
fprintf('Wrote report: %s\n', reportPath);

function s = yn(tf)
if tf, s = 'YES'; else, s = 'NO'; end
end

function s = ternary(tf, a, b)
if tf, s = a; else, s = b; end
end
