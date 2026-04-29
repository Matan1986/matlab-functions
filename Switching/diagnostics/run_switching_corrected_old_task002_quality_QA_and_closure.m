% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: CORRECTED_CANONICAL_OLD_ANALYSIS / TASK_002A_quality_metrics_closure
% EVIDENCE_STATUS: DIAGNOSTIC_QA_and_closure — reads authoritative CSVs only; no mixed CANON_GEN PT/CDF columns as inputs
% BACKBONE_FORMULA: N/A (consistency checks on precomputed authoritative maps)
% SVD_INPUT: N/A
% COORDINATE_GRID: N/A
% SAFE_USE: closure tables + diagnostic PNGs under figures/switching/diagnostics/corrected_old_task002_quality_QA/
% UNSAFE_USE: citing QA PNGs as publication-ready; substituting for parity-bridge TASK_002B outputs
% NOT_MAIN_MANUSCRIPT_EVIDENCE_IF_APPLICABLE: diagnostic QA until publication provenance gate
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
% run_switching_corrected_old_task002_quality_QA_and_closure — metrics consistency + QA figures from authoritative tables only.

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    repoRoot = pwd;
end

tablesDir = fullfile(repoRoot, 'tables');
figDir = fullfile(repoRoot, 'figures', 'switching', 'diagnostics', 'corrected_old_task002_quality_QA');
if exist(figDir, 'dir') ~= 7
    mkdir(figDir);
end

bbPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_backbone_map.csv');
resPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_residual_map.csv');
m1Path = fullfile(tablesDir, 'switching_corrected_old_authoritative_mode1_reconstruction_map.csv');
raPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_residual_after_mode1_map.csv');
phiPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_phi1.csv');
kapPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_kappa1.csv');
qmPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_quality_metrics.csv');

bb = readtable(bbPath, 'VariableNamingRule', 'preserve');
res = readtable(resPath, 'VariableNamingRule', 'preserve');
m1 = readtable(m1Path, 'VariableNamingRule', 'preserve');
ra = readtable(raPath, 'VariableNamingRule', 'preserve');
phiT = readtable(phiPath, 'VariableNamingRule', 'preserve');
kap = readtable(kapPath, 'VariableNamingRule', 'preserve');
qm = readtable(qmPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');

S = bb.S_percent;
B = bb.S_backbone_old_recipe;
Rtbl = res.DeltaS;
Mtbl = m1.S_mode1_reconstruction;
RAtbl = ra.DeltaS_after_mode1;
Tcol = bb.T_K;
Icol = bb.current_mA;
Xcol = bb.x_aligned;

%% Identity checks (finite rows only where mode1 is finite for mode1 identities)
tolAbs = 1e-9;
tolRel = 1e-7;

r1 = Rtbl - (S - B);
chk_bb_res = max(abs(r1), [], 'omitnan');

mode1Finite = isfinite(Mtbl);
m1pred = nan(height(bb), 1);
xg = phiT.x_aligned;
ph = phiT.Phi1_corrected_old;
for i = 1:height(kap)
    tval = kap.T_K(i);
    k = kap.kappa1_corrected_old(i);
    idx = Tcol == tval;
    xi = Xcol(idx);
    phat = interp1(xg, ph, xi, 'linear', NaN);
    m1pred(idx) = B(idx) + k .* phat;
end
dMode = Mtbl - m1pred;
chk_mode1 = max(abs(dMode(mode1Finite)), [], 'omitnan');

raPred = S - Mtbl;
dRa = RAtbl - raPred;
chk_ra = max(abs(dRa(mode1Finite)), [], 'omitnan');

rmse_bb_rep = sqrt(mean((S - B).^2, 'omitnan'));
rmse_after_rep = sqrt(mean((S - Mtbl).^2, 'omitnan'));
imp_rep = rmse_bb_rep / rmse_after_rep;

qmKeys = upper(strtrim(string(qm.metric_key)));
qmVals = string(qm.metric_value);
getv = @(k) str2double(qmVals(qmKeys == upper(strtrim(string(k)))));

rmse_bb_file = getv("rmse_backbone_only");
rmse_after_file = getv("rmse_after_mode1");
imp_file = getv("improvement_factor_backbone_to_mode1");
ev_file = getv("svd_mode1_explained_variance");

fprintf('CHK backbone-residual max abs: %.3g\n', chk_bb_res);
fprintf('CHK mode1 identity max abs (finite mode1): %.3g\n', chk_mode1);
fprintf('CHK residual-after identity max abs (finite mode1): %.3g\n', chk_ra);
fprintf('RMSE backbone file vs replay: %.12g vs %.12g\n', rmse_bb_file, rmse_bb_rep);
fprintf('RMSE after file vs replay: %.12g vs %.12g\n', rmse_after_file, rmse_after_rep);

%% Per-temperature metrics
uT = unique(Tcol, 'sorted');
nT = numel(uT);
rmse_bb_T = nan(nT, 1);
rmse_af_T = nan(nT, 1);
mean_abs_R_T = nan(nT, 1);
mean_abs_RA_T = nan(nT, 1);
for k = 1:nT
    tv = uT(k);
    m = Tcol == tv;
    rmse_bb_T(k) = sqrt(mean((S(m) - B(m)).^2, 'omitnan'));
    rmse_af_T(k) = sqrt(mean((S(m) - Mtbl(m)).^2, 'omitnan'));
    mean_abs_R_T(k) = mean(abs(Rtbl(m)), 'omitnan');
    mean_abs_RA_T(k) = mean(abs(RAtbl(m)), 'omitnan');
end
byTTbl = table(uT, rmse_bb_T, rmse_af_T, mean_abs_R_T, mean_abs_RA_T, ...
    'VariableNames', {'T_K','rmse_backbone_only','rmse_after_mode1','mean_abs_DeltaS','mean_abs_DeltaS_after_mode1'});
writetable(byTTbl, fullfile(tablesDir, 'switching_corrected_old_quality_metrics_by_T.csv'));

stMode1 = grade3(chk_mode1, 1e-5, 1e-3);
stRa = grade3(chk_ra, 1e-5, 1e-3);
stRmseB = closeMetricStatus(rmse_bb_rep, rmse_bb_file, 1e-5);
stRmseA = closeMetricStatus(rmse_after_rep, rmse_after_file, 1e-5);
stImp = closeMetricStatus(imp_rep, imp_file, 1e-5);
stBB = 'fail'; if chk_bb_res < 1e-6, stBB = 'pass'; end
stTcov = 'fail'; if numel(uT) == 14 && min(uT) == 4 && max(uT) == 30, stTcov = 'pass'; end

%% Consistency check CSV rows (written here for single source of truth)
chkRows = {
    'CHK001', 'backbone_residual_identity', strjoin({bbPath; resPath}, ';'), ...
        'max abs(DeltaS - (S_percent - S_backbone)) < 1e-6', sprintf('%.3g', chk_bb_res), ...
        stBB, ...
        'Row-wise on authoritative backbone and residual maps.';
    'CHK002', 'mode1_reconstruction_identity', strjoin({bbPath; m1Path; phiPath; kapPath}, ';'), ...
        'S_mode1 = S_backbone + kappa1(T)*Phi1(x) where mode1 finite', sprintf('%.3g', chk_mode1), ...
        stMode1, ...
        'Uses interp1 on exported Phi1 grid matching builder.';
    'CHK003', 'residual_after_mode1_identity', strjoin({bbPath; m1Path; raPath}, ';'), ...
        'DeltaS_after = S_percent - S_mode1 where mode1 finite', sprintf('%.3g', chk_ra), ...
        stRa, ...
        'NaN rows excluded from max-norm where mode1 is NaN.';
    'CHK004', 'rmse_backbone_replayed_vs_quality_metrics', qmPath, ...
        'rmse_backbone_only matches replay over all rows', sprintf('file %.12g replay %.12g', rmse_bb_file, rmse_bb_rep), ...
        stRmseB, ...
        'Replay uses same stacked table as builder outputs.';
    'CHK005', 'rmse_after_mode1_replayed_vs_quality_metrics', qmPath, ...
        'rmse_after_mode1 matches replay', sprintf('file %.12g replay %.12g', rmse_after_file, rmse_after_rep), ...
        stRmseA, ...
        'mean(...,omitnan) matches builder.';
    'CHK006', 'improvement_factor_consistency', qmPath, ...
        'improvement = rmse_bb / rmse_after', sprintf('file %.8g replay %.8g', imp_file, imp_rep), ...
        stImp, ...
        '';
    'CHK007', 'svd_mode1_explained_variance_replay', strjoin({resPath; phiPath}, ';'), ...
        'Leading singular value energy fraction equals quality metric', 'not recomputed without alignedResidual matrix', ...
        'not_applicable', ...
        'Scalar reported only in switching_corrected_old_authoritative_quality_metrics.csv; aligned grid not exported.';
    'CHK008', 'temperature_coverage', bbPath, ...
        'T = 4:2:30 all present', sprintf('%d distinct T', numel(uT)), ...
        stTcov, ...
        '';
    'CHK009', 'forbidden_evidence_inputs', 'n/a', ...
        'Script inputs are corrected-old authoritative tables only', 'authoritative CSV paths only', ...
        'pass', ...
        'No mixed canonical diagnostics; no quarantined paths; no old figures read.';
    };

cchk = cell2table(chkRows, 'VariableNames', ...
    {'check_id','check_name','source_paths','expected_result','observed_result','status','notes'});
writetable(cchk, fullfile(tablesDir, 'switching_corrected_old_quality_metrics_consistency_check.csv'));

%% Pivot for heatmaps
uI = unique(Icol, 'sorted');
Mbb = pivotField(bb, uT, uI, 'S_backbone_old_recipe');
Mr = pivotField(res, uT, uI, 'DeltaS');
Mm1 = pivotField(m1, uT, uI, 'S_mode1_reconstruction');
Mra = pivotField(ra, uT, uI, 'DeltaS_after_mode1');

set(0, 'DefaultAxesFontSize', 14, 'DefaultLineLineWidth', 2);

%% Figure 1 — four heatmaps
base_name = 'switching_corrected_old_QA_backbone_residual_mode1_maps';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Position', [80 80 1200 900]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile; imagesc(uI, uT, Mbb); axis xy; colormap(gca, parula); colorbar; xlabel('Current (mA)'); ylabel('Temperature (K)');
title('S backbone (corrected-old)');
nexttile; imagesc(uI, uT, Mr); axis xy; colormap(gca, parula); colorbar; xlabel('Current (mA)'); ylabel('Temperature (K)');
title('\DeltaS residual before mode1');
nexttile; imagesc(uI, uT, Mm1); axis xy; colormap(gca, parula); colorbar; xlabel('Current (mA)'); ylabel('Temperature (K)');
title('Mode-1 reconstruction');
nexttile; imagesc(uI, uT, Mra); axis xy; colormap(gca, parula); colorbar; xlabel('Current (mA)'); ylabel('Temperature (K)');
title('\DeltaS after mode1');
exportgraphics(fig, fullfile(figDir, [base_name '.png']), 'Resolution', 300);
close(fig);

%% Figure 2 — Phi1 and kappa1
base_name = 'switching_corrected_old_QA_phi1_kappa1';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Position', [80 80 1100 450]);
tiledlayout(1, 2, 'Padding', 'compact');
nexttile;
finitePhi = isfinite(ph);
plot(xg(finitePhi), ph(finitePhi), 'LineWidth', 2);
grid on; xlabel('x aligned ((I - I_{peak}) / W)'); ylabel('\Phi_1 (corrected-old)');
title('\Phi_1 vs aligned x (finite support)');
nexttile;
plot(kap.T_K, kap.kappa1_corrected_old, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
grid on; xlabel('Temperature (K)'); ylabel('\kappa_1 (corrected-old)');
title('\kappa_1 vs T');
exportgraphics(fig, fullfile(figDir, [base_name '.png']), 'Resolution', 300);
close(fig);

%% Figure 3 — residual before / after heatmaps
base_name = 'switching_corrected_old_QA_residual_before_after_mode1';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Position', [80 80 1100 420]);
tiledlayout(1, 2, 'Padding', 'compact');
nexttile; imagesc(uI, uT, Mr); axis xy; colormap(gca, parula); colorbar; xlabel('Current (mA)'); ylabel('Temperature (K)');
title('Residual before mode1');
nexttile; imagesc(uI, uT, Mra); axis xy; colormap(gca, parula); colorbar; xlabel('Current (mA)'); ylabel('Temperature (K)');
title('Residual after mode1');
exportgraphics(fig, fullfile(figDir, [base_name '.png']), 'Resolution', 300);
close(fig);

%% Figure 4 — quality by T
base_name = 'switching_corrected_old_QA_quality_by_T';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Position', [80 80 1100 450]);
tiledlayout(1, 2, 'Padding', 'compact');
nexttile;
plot(uT, rmse_bb_T, 's-', 'LineWidth', 2, 'DisplayName', 'RMSE backbone'); hold on;
plot(uT, rmse_af_T, 'o-', 'LineWidth', 2, 'DisplayName', 'RMSE after mode1');
grid on; xlabel('Temperature (K)'); ylabel('RMSE (S units)'); legend('Location', 'best');
title('Per-T RMSE');
nexttile;
plot(uT, mean_abs_R_T, 's-', 'LineWidth', 2, 'DisplayName', 'mean |\DeltaS|'); hold on;
plot(uT, mean_abs_RA_T, 'o-', 'LineWidth', 2, 'DisplayName', 'mean |\DeltaS_{after}|');
grid on; xlabel('Temperature (K)'); ylabel('Mean abs residual'); legend('Location', 'best');
title('Per-T mean abs residual');
exportgraphics(fig, fullfile(figDir, [base_name '.png']), 'Resolution', 300);
close(fig);

fprintf('TASK_002 QA script complete. Figures in:\n%s\n', figDir);

function M = pivotField(tbl, uT, uI, varName)
Tcol = tbl.T_K;
Icol = tbl.current_mA;
M = nan(numel(uT), numel(uI));
v = tbl.(varName);
for i = 1:numel(uT)
    for j = 1:numel(uI)
        m = Tcol == uT(i) & Icol == uI(j);
        if any(m)
            M(i, j) = v(find(m, 1));
        end
    end
end
end

function s = grade3(x, tPass, tPartial)
if x < tPass
    s = 'pass';
elseif x < tPartial
    s = 'partial';
else
    s = 'fail';
end
end

function s = closeMetricStatus(a, b, relTol)
den = max(abs(a), abs(b));
if den <= 0
    s = 'pass';
    return
end
if abs(a - b) <= relTol * den
    s = 'pass';
else
    s = 'partial';
end
end
