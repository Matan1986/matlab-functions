function out = run_barrier_relaxation_mechanism_closure(cfg)
%RUN_BARRIER_RELAXATION_MECHANISM_CLOSURE
% Level-2 mechanism closure: PT descriptors + kappa(T) vs A(T), R(T).
% Consumes existing run artifacts only; creates a new cross_experiment run.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

set(0, 'DefaultFigureVisible', 'off');

cfg = applyDefaults(cfg);
paths = resolveArtifactPaths(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('barrier:%s | kappa:%s', paths.barrierRunName, paths.kappaRunName);
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;
ensureRunSubdirs(runDir);

fprintf('Barrier-relaxation mechanism closure run directory:\n%s\n', runDir);

appendText(run.log_path, sprintf('[%s] closure started\n', stampNow()));
appendText(run.log_path, sprintf('Barrier descriptors: %s\n', paths.barrierDescriptorsPath));
appendText(run.log_path, sprintf('Kappa run: %s\n', paths.kappaRunName));

master = buildMasterDataset(repoRoot, paths, cfg);
auditTbl = buildDescriptorAudit(master);
save_run_table(auditTbl, 'descriptor_audit.csv', runDir);

[cmpA, cmpR, minA, minR, sectorTbl, residTbl, robTbl, bests] = runModelSuite(master, cfg); %#ok<ASGLU>

save_run_table(cmpA, 'A_model_comparison.csv', runDir);
save_run_table(cmpR, 'R_model_comparison.csv', runDir);
save_run_table(minA, 'A_minimal_models.csv', runDir);
save_run_table(minR, 'R_minimal_models.csv', runDir);
save_run_table(sectorTbl, 'sector_additivity_metrics.csv', runDir);
save_run_table(residTbl, 'PT_only_residual_links.csv', runDir);
save_run_table(robTbl, 'robustness_window_summary.csv', runDir);

manifestTbl = buildManifestTable(paths, master, cfg, thisFile);
save_run_table(manifestTbl, 'source_artifact_manifest.csv', runDir);

fig1 = figActualVsPred(master, cmpA, 'A', runDir);
fig2 = figActualVsPred(master, cmpR, 'R', runDir);
fig3 = figLoocvCompare(cmpA, 'A', runDir);
fig4 = figLoocvCompare(cmpR, 'R', runDir);
fig5 = figResidualVsKappa(master, bests, 'A', runDir);
fig6 = figResidualVsKappa(master, bests, 'R', runDir);
fig7 = figCoefStability(robTbl, runDir);
fig8 = figRobustnessWindows(robTbl, runDir);

[reportText, verdicts] = buildClosureReport(paths, master, auditTbl, cmpA, cmpR, minA, minR, ...
    sectorTbl, residTbl, robTbl, bests, cfg, thisFile);
reportPath = save_run_report(reportText, 'barrier_relaxation_mechanism_closure_report.md', runDir);
zipPath = buildReviewZip(runDir, 'barrier_relaxation_mechanism_closure_bundle.zip');

fprintf('\n=== CLOSURE VERDICTS ===\n');
fprintf('VERDICT_A: %s\n', verdicts.A);
fprintf('VERDICT_R: %s\n', verdicts.R);
fprintf('VERDICT_TWO_SECTOR: %s\n', verdicts.twoSector);
fprintf('Best PT-only (A): %s\n', verdicts.bestPT_A);
fprintf('Best PT-only (R): %s\n', verdicts.bestPT_R);
fprintf('Best PT+kappa (A): %s\n', verdicts.bestPTkap_A);
fprintf('Best PT+kappa (R): %s\n', verdicts.bestPTkap_R);
fprintf('LOOCV RMSE PT-only A / PT+kappa A: %.6g / %.6g\n', verdicts.loocv_pt_A, verdicts.loocv_ptk_A);
fprintf('LOOCV RMSE PT-only R / PT+kappa R: %.6g / %.6g\n', verdicts.loocv_pt_R, verdicts.loocv_ptk_R);
fprintf('Strongest PT-residual vs kappa |Spearman|: %s (%.4f)\n', verdicts.residKapStr, verdicts.residKapVal);
fprintf('Report: %s\n', reportPath);

appendText(run.log_path, sprintf('[%s] complete\n', stampNow()));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.paths = paths;
out.master = master;
out.verdicts = verdicts;
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
end

%% ------------------------------------------------------------------------
function cfg = applyDefaults(cfg)
cfg = setDef(cfg, 'runLabel', 'barrier_relaxation_mechanism_closure');
cfg = setDef(cfg, 'barrierRunHint', 'barrier_to_relaxation_mechanism');
cfg = setDef(cfg, 'barrierDescriptorsPath', '');
cfg = setDef(cfg, 'kappaRunHint', '220314_residual_decomposition');
cfg = setDef(cfg, 'kappaCsvPath', '');
cfg = setDef(cfg, 'phiShapePath', '');
cfg = setDef(cfg, 'canonicalXRunName', 'run_2026_03_22_013049_x_observable_export_corrected');
cfg = setDef(cfg, 'interpMethod', 'pchip');
cfg = setDef(cfg, 'ptLabelHint', 'pt_robust');
cfg = setDef(cfg, 'relaxLabelHint', 'relaxation_observable');
cfg = setDef(cfg, 'agingLabelHint', 'aging_clock_ratio');
cfg = setDef(cfg, 'switchLabelHint', 'alignment_audit');
cfg = setDef(cfg, 'corrPrune', 0.97);
cfg = setDef(cfg, 'degenStdTol', 1e-9);
cfg = setDef(cfg, 'tailRatioCap', 1e4);
cfg = setDef(cfg, 'materialLoocvRelImprove', 0.12);
end

function paths = resolveArtifactPaths(repoRoot, cfg)
paths = struct();
paths.repoRoot = repoRoot;

if strlength(string(cfg.barrierDescriptorsPath)) > 0 && isfile(char(cfg.barrierDescriptorsPath))
    paths.barrierDescriptorsPath = char(cfg.barrierDescriptorsPath);
    paths.barrierRunName = string(extractBarrierRunName(paths.barrierDescriptorsPath));
else
    [bd, bn] = findLatestRunWithFiles(repoRoot, 'cross_experiment', ...
        {'tables\barrier_descriptors.csv'}, cfg.barrierRunHint);
    paths.barrierDescriptorsPath = fullfile(char(bd), 'tables', 'barrier_descriptors.csv');
    paths.barrierRunName = bn;
end

if strlength(string(cfg.kappaCsvPath)) > 0 && isfile(char(cfg.kappaCsvPath))
    paths.kappaCsvPath = char(cfg.kappaCsvPath);
    paths.kappaRunName = string(extractRunFolderName(paths.kappaCsvPath));
    if strlength(string(cfg.phiShapePath)) > 0 && isfile(char(cfg.phiShapePath))
        paths.phiShapePath = char(cfg.phiShapePath);
    else
        kd = fileparts(fileparts(paths.kappaCsvPath));
        candPhi = fullfile(kd, 'tables', 'phi_shape.csv');
        if isfile(candPhi)
            paths.phiShapePath = candPhi;
        else
            paths.phiShapePath = '';
        end
    end
else
    [kd, kn] = findLatestSwitchingRunTwoFiles(repoRoot, ...
        {'tables\kappa_vs_T.csv', 'tables\phi_shape.csv'}, cfg.kappaRunHint);
    paths.kappaCsvPath = fullfile(char(kd), 'tables', 'kappa_vs_T.csv');
    paths.phiShapePath = fullfile(char(kd), 'tables', 'phi_shape.csv');
    paths.kappaRunName = kn;
end

if ~isfile(paths.phiShapePath)
    paths.phiShapePath = '';
end
end

function name = extractBarrierRunName(p)
parts = split(string(p), filesep);
idx = find(parts == "runs", 1, 'last');
if isempty(idx) || idx >= numel(parts)
    name = "unknown";
else
    name = parts(idx + 1);
end
end

function name = extractRunFolderName(p)
name = extractBarrierRunName(p);
end

function master = buildMasterDataset(repoRoot, paths, cfg)
desc = readtable(paths.barrierDescriptorsPath, 'VariableNamingRule', 'preserve');
desc = sanitizeDescriptorTable(desc, cfg.tailRatioCap);

need = {'A_T_interp', 'R_T_interp', 'X_T_interp', 'I_peak_mA', 'S_peak'};
if all(ismember(need, desc.Properties.VariableNames))
    T = double(desc.T_K(:));
    A = double(desc.A_T_interp(:));
    R = double(desc.R_T_interp(:));
    X = double(desc.X_T_interp(:));
    Ip = double(desc.I_peak_mA(:));
    Sp = double(desc.S_peak(:));
    rowOk = true(height(desc), 1);
    if ismember('row_valid', desc.Properties.VariableNames)
        rowOk = logical(desc.row_valid(:));
    end
else
    source = resolveSourcesBarrier(repoRoot, cfg);
    relax = loadRelaxationSeries(source.relaxTempPath);
    aging = loadAgingRatioSeries(source.agingClockPath);
    sw = loadSwitchingPeaks(source.switchMatrixPath);
    [TX, XX] = get_canonical_X('repoRoot', repoRoot, 'runName', char(cfg.canonicalXRunName));
    al = alignOnTemperatureGridClosure(desc, relax, aging, sw, TX, XX, cfg);
    T = al.T_K;
    A = al.A;
    R = al.R;
    X = al.X;
    Ip = al.I_peak_mA;
    Sp = al.S_peak;
    desc = al.descriptorTable;
    rowOk = true(numel(T), 1);
end

kTbl = readtable(paths.kappaCsvPath, 'VariableNamingRule', 'preserve');
tK = firstMatchingName(kTbl.Properties.VariableNames, {'T', 'T_K', 'temperature'});
kapCol = firstMatchingName(kTbl.Properties.VariableNames, {'kappa', 'kappa_T', 'Kappa'});
Tk = double(kTbl.(tK)(:));
Kk = double(kTbl.(kapCol)(:));
kappaOnT = interp1(Tk, Kk, T, cfg.interpMethod, NaN);

master = struct();
master.T_K = T;
master.A = A;
master.R = R;
master.X = X;
master.I_peak = Ip;
master.S_peak = Sp;
master.kappa = kappaOnT;
master.descriptorTable = desc;
master.rowOk = rowOk;
master.paths = paths;
end

function desc = sanitizeDescriptorTable(desc, tailCap)
if ismember('tail_ratio_high_over_low', desc.Properties.VariableNames)
    v = desc.tail_ratio_high_over_low(:);
    bad = ~isfinite(v) | abs(v) > tailCap;
    desc.tail_ratio_high_over_low(bad) = NaN;
end
end

function auditTbl = buildDescriptorAudit(master)
desc = master.descriptorTable;
vn = desc.Properties.VariableNames;
rows = [];
for i = 1:numel(vn)
    name = vn{i};
    if strcmp(name, 'T_K') || strcmp(name, 'row_valid')
        continue;
    end
    x = double(desc.(name)(:));
    fin = isfinite(x);
    nfin = sum(fin);
    cat = categorizeVariable(name);
    if nfin == 0
        row = buildAuditRow(name, cat, 0, NaN, NaN, NaN, NaN, true, "all NaN");
        rows = [rows; row]; %#ok<AGROW>
        continue;
    end
    xf = x(fin);
    med = median(xf);
    mn = min(xf);
    mx = max(xf);
    st = std(xf, 0);
    degen = st < 1e-12 || (mx - mn) < 1e-12;
    note = "";
    if degen
        note = "constant_or_near_constant";
    end
    row = buildAuditRow(name, cat, nfin, med, mn, mx, st, degen, note);
    rows = [rows; row]; %#ok<AGROW>
end

% Baseline / targets on master grid
rows = [rows; buildAuditRow('A_T_interp', "baseline_target", sum(isfinite(master.A)), median(master.A,'omitnan'), ...
    min(master.A,[],'omitnan'), max(master.A,[],'omitnan'), std(master.A,0,'omitnan'), false, "")];
rows = [rows; buildAuditRow('R_T_interp', "baseline_target", sum(isfinite(master.R)), median(master.R,'omitnan'), ...
    min(master.R,[],'omitnan'), max(master.R,[],'omitnan'), std(master.R,0,'omitnan'), false, "")];
rows = [rows; buildAuditRow('X_T_interp', "baseline", sum(isfinite(master.X)), median(master.X,'omitnan'), ...
    min(master.X,[],'omitnan'), max(master.X,[],'omitnan'), std(master.X,0,'omitnan'), false, "")];
rows = [rows; buildAuditRow('kappa_interp', "residual_sector", sum(isfinite(master.kappa)), median(master.kappa,'omitnan'), ...
    min(master.kappa,[],'omitnan'), max(master.kappa,[],'omitnan'), std(master.kappa,0,'omitnan'), false, "")];
rows = [rows; buildAuditRow('I_peak_mA', "baseline", sum(isfinite(master.I_peak)), median(master.I_peak,'omitnan'), ...
    min(master.I_peak,[],'omitnan'), max(master.I_peak,[],'omitnan'), std(master.I_peak,0,'omitnan'), false, "")];
rows = [rows; buildAuditRow('S_peak', "baseline", sum(isfinite(master.S_peak)), median(master.S_peak,'omitnan'), ...
    min(master.S_peak,[],'omitnan'), max(master.S_peak,[],'omitnan'), std(master.S_peak,0,'omitnan'), false, "")];

auditTbl = struct2table(rows);
end

function row = buildAuditRow(name, cat, nfin, med, mn, mx, st, degen, note)
row = struct('variable', string(name), 'category', string(cat), 'n_finite', nfin, ...
    'median', med, 'min', mn, 'max', mx, 'std', st, 'degenerate', degen, 'note', string(note));
end

function cat = categorizeVariable(name)
if ismember(name, {'mean_I_mA','median_I_mA','mode_I_mA','q10_I_mA','q25_I_mA','q50_I_mA','q75_I_mA','q90_I_mA'})
    cat = "location_quantile";
elseif ismember(name, {'iq75_25_mA','iq90_10_mA','asym_q75_50_minus_q50_25','tail_ratio_high_over_low','skewness_quantile'})
    cat = "asymmetry_span";
elseif ismember(name, {'cheb_m2_z','cheb_m4_z','moment_I2_weighted','mass_upper_half'})
    cat = "moment_shape";
elseif ismember(name, {'pt_svd_score1','pt_svd_score2'})
    cat = "svd";
else
    cat = "other";
end
end

function [cmpA, cmpR, minA, minR, sectorTbl, residTbl, robTbl, bests] = runModelSuite(master, cfg)
desc = master.descriptorTable;
locVars = {'mean_I_mA','median_I_mA','mode_I_mA'};
shapeVars = {'iq75_25_mA','iq90_10_mA','asym_q75_50_minus_q50_25','skewness_quantile', ...
    'cheb_m2_z','cheb_m4_z','pt_svd_score1','pt_svd_score2','mass_upper_half','q75_I_mA','moment_I2_weighted'};
shapeVars = shapeVars(ismember(shapeVars, desc.Properties.VariableNames));

ptPool = [locVars(:)', shapeVars(:)'];
ptPool = ptPool(cellfun(@(c) ismember(c, desc.Properties.VariableNames), ptPool));

maskBase = master.rowOk & isfinite(master.A) & isfinite(master.R) & isfinite(master.X) ...
    & isfinite(master.I_peak) & isfinite(master.S_peak) & isfinite(master.kappa);
for k = 1:numel(ptPool)
    maskBase = maskBase & isfinite(double(desc.(ptPool{k})(:)));
end
if ismember('q50_I_mA', desc.Properties.VariableNames)
    maskBase = maskBase & isfinite(double(desc.q50_I_mA(:)));
end

ptPool = pruneRedundantPredictors(desc, ptPool, maskBase, cfg.corrPrune);

[cmpA, bA] = buildComparisonForTarget(master, desc, maskBase, ptPool, 'A', cfg);
[cmpR, bR] = buildComparisonForTarget(master, desc, maskBase, ptPool, 'R', cfg);

bests = struct();
bests.pt1_name_A = bA.pt1;
bests.pt2_str_A = bA.pt2str;
bests.pt3_str_A = bA.pt3str;
bests.pt1_name_R = bR.pt1;
bests.pt2_str_R = bR.pt2str;
bests.pt3_str_R = bR.pt3str;
bests.ptPool = ptPool;

minA = extractMinimalRows(cmpA, 'A');
minR = extractMinimalRows(cmpR, 'R');

sectorTbl = buildSectorTable(cmpA, cmpR);
residTbl = buildResidualLinks(master, desc, maskBase, bests, cfg);
robTbl = buildRobustnessTable(master, desc, cfg, bests);
end

function pool = pruneRedundantPredictors(desc, pool, mask, cMin)
X = zeros(sum(mask), numel(pool));
for i = 1:numel(pool)
    X(:, i) = double(desc.(pool{i})(mask));
end
keep = true(1, numel(pool));
for i = 1:numel(pool)
    if ~keep(i)
        continue;
    end
    for j = i + 1:numel(pool)
        if ~keep(j)
            continue;
        end
        r = corr(X(:, i), X(:, j), 'rows', 'complete', 'type', 'Pearson');
        if isfinite(r) && abs(r) >= cMin
            keep(j) = false;
        end
    end
end
pool = pool(keep);
end

function [cmpTbl, binfo] = buildComparisonForTarget(master, desc, maskBase, ptPool, targetKey, cfg)
if targetKey == 'A'
    y = master.A(:);
else
    y = master.R(:);
end
T = master.T_K(:);
Xobs = master.X(:);
Kap = master.kappa(:);
Ip = master.I_peak(:);
Sp = master.S_peak(:);

models = {};

% --- singles: PT pool
for i = 1:numel(ptPool)
    models{end + 1} = evalNamedLinearModel(sprintf('PT_1_%s', ptPool{i}), 'PT_single', {ptPool{i}}, ...
        desc, y, maskBase, T, cfg); %#ok<AGROW>
end

% --- Family A: location block size 1..3
loc = {'mean_I_mA','median_I_mA','mode_I_mA'};
loc = loc(ismember(loc, ptPool));
for sz = 1:min(3, numel(loc))
    subs = loc(1:sz);
    if numel(unique(subs)) < sz
        continue;
    end
    models{end + 1} = evalNamedLinearModel(sprintf('family_A_loc_%d', sz), 'family_A', subs, ...
        desc, y, maskBase, T, cfg); %#ok<AGROW>
end

% --- Family C, D
models{end + 1} = evalNamedLinearModel('family_C_X_only', 'family_C', {'__X__'}, desc, y, maskBase, T, cfg, Xobs);
dPreds = minimalSwitchingBaseline(Xobs, Ip, Sp, maskBase);
models{end + 1} = evalNamedLinearModel('family_D_switch_min', 'family_D', dPreds, desc, y, maskBase, T, cfg, Xobs, Ip, Sp);

% --- kappa only
models{end + 1} = evalNamedLinearModel('kappa_only', 'kappa', {'__KAPPA__'}, desc, y, maskBase, T, cfg, [], [], [], Kap);

% --- exhaustive PT 2 and 3 from pool (small n)
if numel(ptPool) >= 2
    best2 = bestSubsetByLoocv(desc, y, maskBase, ptPool, 2, T, cfg, Xobs, [], [], Kap);
    models{end + 1} = best2; %#ok<AGROW>
end
if numel(ptPool) >= 3
    best3 = bestSubsetByLoocv(desc, y, maskBase, ptPool, 3, T, cfg, Xobs, [], [], Kap);
    models{end + 1} = best3; %#ok<AGROW>
end

% --- best single PT by LOOCV
loocvScores = nan(numel(ptPool), 1);
for i = 1:numel(ptPool)
    m = evalNamedLinearModel(sprintf('tmp_%s', ptPool{i}), 'tmp', {ptPool{i}}, desc, y, maskBase, T, cfg);
    loocvScores(i) = m.loocv_rmse;
end
[~, ix1] = min(loocvScores);
pt1 = ptPool{ix1};

% --- best 2-subset and 3-subset
if numel(ptPool) >= 2
    m2 = bestSubsetByLoocv(desc, y, maskBase, ptPool, 2, T, cfg);
    pt2str = m2.predictors;
else
    m2 = evalNamedLinearModel('PT_2_na', 'PT', {pt1}, desc, y, maskBase, T, cfg);
    pt2str = pt1;
end
if numel(ptPool) >= 3
    m3 = bestSubsetByLoocv(desc, y, maskBase, ptPool, 3, T, cfg);
    pt3str = m3.predictors;
else
    m3 = m2;
    pt3str = m2.predictors;
end

% --- PT best 1/2/3 explicit
models{end + 1} = evalNamedLinearModel('PT_best_loocv_1', 'family_E', {pt1}, desc, y, maskBase, T, cfg); %#ok<AGROW>
models{end + 1} = evalNamedLinearModel('PT_best_loocv_2', 'family_E', splitPreds(pt2str), desc, y, maskBase, T, cfg); %#ok<AGROW>
models{end + 1} = evalNamedLinearModel('PT_best_loocv_3', 'family_E', splitPreds(pt3str), desc, y, maskBase, T, cfg); %#ok<AGROW>

% --- Family F, G, H
models{end + 1} = evalNamedLinearModel('family_F_PT1_plus_kappa', 'family_F', [{pt1}, {'__KAPPA__'}], ...
    desc, y, maskBase, T, cfg, [], [], [], Kap);
models{end + 1} = evalNamedLinearModel('family_F_PT2_plus_kappa', 'family_F', appendKappaPreds(splitPreds(pt2str)), ...
    desc, y, maskBase, T, cfg, [], [], [], Kap);
models{end + 1} = evalNamedLinearModel('family_G_X_plus_kappa', 'family_G', {'__X__','__KAPPA__'}, ...
    desc, y, maskBase, T, cfg, Xobs, [], [], Kap);
models{end + 1} = evalNamedLinearModel('family_H_PT2_X_kappa', 'family_H', appendXKappaPreds(splitPreds(pt2str)), ...
    desc, y, maskBase, T, cfg, Xobs, [], [], Kap);

% --- Mechanism models M1–M5
models{end + 1} = evalNamedLinearModel('M1_target_best_PT2', 'M1', splitPreds(pt2str), desc, y, maskBase, T, cfg); %#ok<AGROW>
models{end + 1} = evalNamedLinearModel('M2_target_best_PT2_plus_kappa', 'M2', appendKappaPreds(splitPreds(pt2str)), ...
    desc, y, maskBase, T, cfg, [], [], [], Kap); %#ok<AGROW>
models{end + 1} = evalNamedLinearModel('M3_target_X_only', 'M3', {'__X__'}, desc, y, maskBase, T, cfg, Xobs); %#ok<AGROW>
models{end + 1} = evalNamedLinearModel('M4_target_X_plus_kappa', 'M4', {'__X__','__KAPPA__'}, desc, y, maskBase, T, cfg, Xobs, [], [], Kap); %#ok<AGROW>
models{end + 1} = evalNamedLinearModel('M5_target_PT2_X_kappa', 'M5', appendXKappaPreds(splitPreds(pt2str)), ...
    desc, y, maskBase, T, cfg, Xobs, [], [], Kap); %#ok<AGROW>

% --- log-linear singles where safe
for i = 1:numel(ptPool)
    models{end + 1} = evalLogLinearModel(sprintf('PT_log1_%s', ptPool{i}), ptPool{i}, desc, y, maskBase, T, cfg); %#ok<AGROW>
end

cmpTbl = struct2table(vertcat(models{:}));

binfo = struct('pt1', pt1, 'pt2str', char(string(pt2str)), 'pt3str', char(string(pt3str)));
end

function c = appendKappaPreds(ptCell)
c = ptCell(:)';
c{end + 1} = '__KAPPA__';
end

function c = appendXKappaPreds(ptCell)
c = ptCell(:)';
c{end + 1} = '__X__';
c{end + 1} = '__KAPPA__';
end

function preds = splitPreds(s)
parts = strsplit(char(s), '+');
preds = cellstr(parts(:)');
end

function preds = minimalSwitchingBaseline(X, Ip, Sp, mask)
Xv = X(mask);
Iv = Ip(mask);
Sv = Sp(mask);
rXI = corr(Xv, Iv, 'rows', 'complete', 'type', 'Pearson');
rXS = corr(Xv, Sv, 'rows', 'complete', 'type', 'Pearson');
preds = {'__X__'};
if isfinite(rXI) && abs(rXI) < 0.92
    preds{end + 1} = '__IPEAK__'; %#ok<AGROW>
end
if isfinite(rXS) && abs(rXS) < 0.92
    preds{end + 1} = '__SPEAK__'; %#ok<AGROW>
end
end

function m = bestSubsetByLoocv(desc, y, maskBase, pool, sz, T, cfg, Xobs, Ip, Sp, Kap)
if nargin < 8
    Xobs = [];
end
if nargin < 9
    Ip = [];
end
if nargin < 10
    Sp = [];
end
if nargin < 11
    Kap = [];
end
idx = nchoosek(1:numel(pool), sz);
if isempty(idx)
    m = emptyModelRow(sprintf('PT_exhaust_empty_sz%d', sz), 'PT_exhaust', char(strjoin(string(pool), '+')), sum(maskBase), sz);
    return;
end
bestLo = inf;
bestM = [];
for r = 1:size(idx, 1)
    vars = pool(idx(r, :));
    mm = evalNamedLinearModel(sprintf('PT_exhaust_%s', char(strjoin(string(vars), '+'))), 'PT_exhaust', vars, ...
        desc, y, maskBase, T, cfg, Xobs, Ip, Sp, Kap);
    if isfinite(mm.loocv_rmse) && mm.loocv_rmse < bestLo
        bestLo = mm.loocv_rmse;
        bestM = mm;
    end
end
if isempty(bestM)
    m = emptyModelRow(sprintf('PT_exhaust_failed_sz%d', sz), 'PT_exhaust', char(strjoin(string(pool), '+')), sum(maskBase), sz);
else
    m = bestM;
end
end

function m = evalNamedLinearModel(modelId, family, predCell, desc, y, maskBase, T, cfg, Xobs, Ip, Sp, Kap)
if nargin < 9
    Xobs = [];
end
if nargin < 10
    Ip = [];
end
if nargin < 11
    Sp = [];
end
if nargin < 12
    Kap = [];
end

mask = maskBase;
n0 = sum(mask);
[Z, colnames, mask] = designMatrixFromPreds(desc, predCell, mask, Xobs, Ip, Sp, Kap);
yv = y(mask);
Tv = T(mask);
n = sum(mask);
p = size(Z, 2) - 1;

if n < p + 2 || p < 0
    m = emptyModelRow(modelId, family, char(strjoin(string(predCell), '+')), n0, p);
    return;
end

stats = linearRegressionStats(Z, yv);
loo = loocvLinear(Z, yv);

nrmse = stats.rmse / max(std(yv, 0), eps);

m = struct();
m.model_id = string(modelId);
m.family = string(family);
m.predictors = string(strjoin(colnames, '+'));
m.n = stats.n;
m.model_size = p;
m.pearson_r = stats.pearson_r;
m.spearman_rho = stats.spearman_rho;
m.rmse_insample = stats.rmse;
m.rmse_norm = nrmse;
m.r2_insample = stats.r2;
m.adj_r2 = stats.adj_r2;
m.aicc = stats.aicc;
m.loocv_rmse = loo.rmse;
m.loocv_pearson = loo.pearson;
m.loocv_spearman = loo.spearman;
m.coefficients = string(stats.coefStr);
m.notes = "";
m.T_K_list = string(sprintf('[%s]', strjoin(split(strtrim(sprintf('%.2f ', Tv')), ' '), ',')));
end

function m = emptyModelRow(modelId, family, preds, n, p)
m = struct('model_id', string(modelId), 'family', string(family), 'predictors', string(preds), ...
    'n', n, 'model_size', p, 'pearson_r', NaN, 'spearman_rho', NaN, 'rmse_insample', NaN, ...
    'rmse_norm', NaN, 'r2_insample', NaN, 'adj_r2', NaN, 'aicc', NaN, 'loocv_rmse', NaN, ...
    'loocv_pearson', NaN, 'loocv_spearman', NaN, 'coefficients', "", 'notes', "insufficient_data", ...
    'T_K_list', "");
end

function [Z, colnames, mask] = designMatrixFromPreds(desc, predCell, mask, Xobs, Ip, Sp, Kap)
colnames = {};
cols = [];
for k = 1:numel(predCell)
    pk = predCell{k};
    if strcmp(pk, '__X__') || strcmp(pk, 'X_T_interp')
        v = Xobs(:);
        nm = 'X_T_interp';
    elseif strcmp(pk, '__KAPPA__') || strcmpi(pk, 'kappa')
        v = Kap(:);
        nm = 'kappa';
    elseif strcmp(pk, '__IPEAK__') || strcmp(pk, 'I_peak_mA')
        v = Ip(:);
        nm = 'I_peak_mA';
    elseif strcmp(pk, '__SPEAK__') || strcmp(pk, 'S_peak')
        v = Sp(:);
        nm = 'S_peak';
    else
        v = double(desc.(pk)(:));
        nm = pk;
    end
    cols = [cols, v]; %#ok<AGROW>
    colnames{end + 1} = nm; %#ok<AGROW>
end
mask = mask & all(isfinite(cols), 2);
cols = cols(mask, :);
Z = [ones(sum(mask), 1), cols];
end

function stats = linearRegressionStats(Z, y)
n = size(Z, 1);
p = size(Z, 2) - 1;
beta = Z \ y;
yhat = Z * beta;
res = y - yhat;
rss = sum(res.^2);
tss = sum((y - mean(y)).^2);
r2 = 1 - rss / max(tss, eps);
adj_r2 = 1 - (rss / max(n - p - 1, 1)) / max(tss / max(n - 1, 1), eps);

stats = struct();
stats.n = n;
stats.beta = beta;
stats.rmse = sqrt(mean(res.^2));
stats.pearson_r = corr(y, yhat, 'rows', 'complete', 'type', 'Pearson');
stats.spearman_rho = corr(y, yhat, 'rows', 'complete', 'type', 'Spearman');
stats.r2 = r2;
stats.adj_r2 = adj_r2;
if n > p + 2
    aic = n * log(rss / n + eps) + 2 * (p + 1);
    aicc = aic + 2 * (p + 1) * (p + 2) / max(n - p - 2, eps);
else
    aicc = NaN;
end
stats.aicc = aicc;
stats.coefStr = formatCoefString(beta, p);
end

function s = formatCoefString(beta, p)
terms = sprintf('b0=%.4g', beta(1));
for j = 1:p
    terms = [terms, sprintf(' | b%d=%.4g', j, beta(j + 1))]; %#ok<AGROW>
end
s = terms;
end

function loo = loocvLinear(Z, y)
n = size(Z, 1);
p = size(Z, 2);
yhat = nan(n, 1);
for i = 1:n
    idx = true(n, 1);
    idx(i) = false;
    Zt = Z(idx, :);
    yt = y(idx);
    if rank(Zt) < p
        beta = pinv(Zt) * yt;
    else
        beta = Zt \ yt;
    end
    yhat(i) = Z(i, :) * beta;
end
err = y - yhat;
loo.rmse = sqrt(mean(err.^2));
loo.pearson = corr(y, yhat, 'rows', 'complete', 'type', 'Pearson');
loo.spearman = corr(y, yhat, 'rows', 'complete', 'type', 'Spearman');
end

function m = evalLogLinearModel(modelId, pname, desc, y, maskBase, T, cfg)
x = double(desc.(pname)(:));
yv = y(:);
mask = maskBase & isfinite(x) & isfinite(yv) & x > 0 & yv > 0;
if sum(mask) < 5
    m = emptyModelRow(modelId, 'loglin', pname, sum(mask), 1);
    return;
end
Z = [ones(sum(mask), 1), log(x(mask))];
yy = log(yv(mask));
stats = linearRegressionStats(Z, yy);
loo = loocvLinear(Z, yy);
yhatLin = exp(Z * stats.beta);
m = struct();
m.model_id = string(modelId);
m.family = "log_linear";
m.predictors = string(sprintf('log(%s)->log(y)', pname));
m.n = stats.n;
m.model_size = 1;
m.pearson_r = corr(yv(mask), yhatLin, 'rows', 'complete', 'type', 'Pearson');
m.spearman_rho = corr(yv(mask), yhatLin, 'rows', 'complete', 'type', 'Spearman');
m.rmse_insample = sqrt(mean((yv(mask) - yhatLin).^2));
m.rmse_norm = m.rmse_insample / max(std(yv(mask), 0), eps);
m.r2_insample = NaN;
m.adj_r2 = NaN;
m.aicc = stats.aicc;
m.loocv_rmse = NaN;
m.loocv_pearson = NaN;
m.loocv_spearman = NaN;
m.coefficients = string(stats.coefStr);
m.notes = "log_space_fit";
m.T_K_list = "";
end

function minTbl = extractMinimalRows(cmp, targetName)
ids = {'PT_best_loocv_1','PT_best_loocv_2','PT_best_loocv_3','M1_target_best_PT2','M2_target_best_PT2_plus_kappa', ...
    'M3_target_X_only','M4_target_X_plus_kappa','M5_target_PT2_X_kappa','family_G_X_plus_kappa'};
rowMask = ismember(cmp.model_id, string(ids));
minTbl = cmp(rowMask, :);
minTbl.target = repmat(string(targetName), height(minTbl), 1);
end

function sectorTbl = buildSectorTable(cmpA, cmpR)
ids = {'M1_target_best_PT2','M2_target_best_PT2_plus_kappa','M3_target_X_only','M4_target_X_plus_kappa','M5_target_PT2_X_kappa'};
sectorTbl = table();
for i = 1:numel(ids)
    id = ids{i};
    aRow = cmpA(ismember(cmpA.model_id, string(id)), :);
    rRow = cmpR(ismember(cmpR.model_id, string(id)), :);
    sectorTbl = [sectorTbl; packSectorRow(id, aRow, rRow)]; %#ok<AGROW>
end
end

function row = packSectorRow(id, aRow, rRow)
row = table( ...
    string(id), ...
    getf(aRow, 'loocv_rmse'), getf(rRow, 'loocv_rmse'), ...
    getf(aRow, 'loocv_pearson'), getf(rRow, 'loocv_pearson'), ...
    getf(aRow, 'rmse_insample'), getf(rRow, 'rmse_insample'), ...
    'VariableNames', {'model_id','loocv_rmse_A','loocv_rmse_R','loocv_pearson_A','loocv_pearson_R','rmse_in_A','rmse_in_R'});
end

function v = getf(tbl, fname)
if isempty(tbl) || height(tbl) < 1 || ~ismember(fname, tbl.Properties.VariableNames)
    v = NaN;
else
    v = tbl.(fname)(1);
end
end

function residTbl = buildResidualLinks(master, desc, maskBase, bests, cfg)
if isfield(bests, 'pt2_str_A')
    ptA = splitPreds(bests.pt2_str_A);
else
    ptA = {bests.pt1_name_A};
end
if isfield(bests, 'pt2_str_R')
    ptR = splitPreds(bests.pt2_str_R);
else
    ptR = {bests.pt1_name_R};
end

maskA = maskBase;
[ZA, ~, maskA] = designMatrixFromPreds(desc, ptA, maskA, master.X, master.I_peak, master.S_peak, master.kappa);
yA = master.A(:);
yvA = yA(maskA);
betaA = ZA \ yvA;
resA = yvA - ZA * betaA;
TA = master.T_K(maskA);

maskR = maskBase;
[ZR, ~, maskR] = designMatrixFromPreds(desc, ptR, maskR, master.X, master.I_peak, master.S_peak, master.kappa);
yR = master.R(:);
yvR = yR(maskR);
betaR = ZR \ yvR;
resR = yvR - ZR * betaR;
TR = master.T_K(maskR);

kA = master.kappa(maskA);
XA = master.X(maskA);
iA = master.I_peak(maskA);
sA = master.S_peak(maskA);

kR = master.kappa(maskR);
XR = master.X(maskR);
iR = master.I_peak(maskR);
sR = master.S_peak(maskR);

rows = [];
rows = [rows; residRow('A', 'kappa', resA, kA)];
rows = [rows; residRow('A', 'X_T_interp', resA, XA)];
rows = [rows; residRow('A', 'I_peak_mA', resA, iA)];
rows = [rows; residRow('A', 'S_peak', resA, sA)];
rows = [rows; residRow('R', 'kappa', resR, kR)];
rows = [rows; residRow('R', 'X_T_interp', resR, XR)];
rows = [rows; residRow('R', 'I_peak_mA', resR, iR)];
rows = [rows; residRow('R', 'S_peak', resR, sR)];
residTbl = struct2table(rows);
end

function row = residRow(target, pred, res, x)
row = struct('target', string(target), 'predictor', string(pred), ...
    'n', numel(res), 'pearson_res_pred', pearsonSafe(res, x), ...
    'spearman_res_pred', spearmanSafe(res, x));
end

function robTbl = buildRobustnessTable(master, desc, cfg, bests)
labels = {'full', 'exclude_T22', 'T_le_24'};
masks = {
    true(size(master.T_K));
    abs(master.T_K - 22) > 0.6;
    master.T_K <= 24 + 1e-6
    };

robTbl = table();
for w = 1:numel(labels)
    mbase = masks{w};
    for target = ["A", "R"]
        if target == "A"
            y = master.A(:);
            pt = splitPreds(bests.pt2_str_A);
            tchar = 'A';
        else
            y = master.R(:);
            pt = splitPreds(bests.pt2_str_R);
            tchar = 'R';
        end
        mask = mbase(:) & master.rowOk & isfinite(y) & isfinite(master.kappa) & isfinite(master.X);
        for k = 1:numel(pt)
            mask = mask & isfinite(double(desc.(pt{k})(:)));
        end
        m1 = evalNamedLinearModel(sprintf('rob_%s_PT2_%s', labels{w}, tchar), 'rob', pt, desc, y, mask, master.T_K, cfg);
        m2 = evalNamedLinearModel(sprintf('rob_%s_PT2kap_%s', labels{w}, tchar), 'rob', appendKappaPreds(pt), ...
            desc, y, mask, master.T_K, cfg, [], [], [], master.kappa);
        row = table(string(labels{w}), string(target), m1.n, m1.loocv_rmse, m2.loocv_rmse, ...
            m1.loocv_pearson, m2.loocv_pearson, m1.predictors, ...
            'VariableNames', {'window','target','n','loocv_rmse_PT2','loocv_rmse_PT2_kappa','loocv_pearson_PT2','loocv_pearson_PT2_kappa','pt_predictors'});
        robTbl = [robTbl; row]; %#ok<AGROW>
    end
end
end

function manifestTbl = buildManifestTable(paths, master, cfg, thisFile)
rows = {
    'barrier_descriptors_csv', paths.barrierDescriptorsPath;
    'kappa_vs_T_csv', paths.kappaCsvPath;
    'phi_shape_csv', paths.phiShapePath;
    'canonical_X_run', fullfile('results', 'switching', 'runs', cfg.canonicalXRunName, 'observables.csv');
    'closure_script', thisFile;
    'n_master_descriptor_rows', sprintf('%d', height(master.descriptorTable))
    };
manifestTbl = cell2table(rows, 'VariableNames', {'artifact', 'path'});
end

%% ---- Figures -----------------------------------------------------------

function paths = figActualVsPred(master, cmp, targetKey, runDir)
if targetKey == 'A'
    y = master.A(:);
else
    y = master.R(:);
end
idBest = pickBestLoocvId(cmp, {'M5_target_PT2_X_kappa','M2_target_best_PT2_plus_kappa','M1_target_best_PT2'});
row = cmp(ismember(cmp.model_id, string(idBest)), :);
if isempty(row)
    idBest = 'PT_best_loocv_1';
    row = cmp(ismember(cmp.model_id, string(idBest)), :);
end

base_name = sprintf('%s_actual_vs_pred_best_models', targetKey);
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'centimeters', 'Position', [2 2 12 10]);
tiledlayout(1, 2, 'Padding', 'compact');

mask = master.rowOk & isfinite(y);
desc = master.descriptorTable;
predsBest = splitPreds(char(row.predictors(1)));
[Z, ~, mask] = designMatrixFromPreds(desc, predsBest, mask, master.X, master.I_peak, master.S_peak, master.kappa);
yv = y(mask);
yh = Z * (Z \ yv);

nexttile;
scatter(yv, yh, 48, master.T_K(mask), 'filled');
colormap(gca, parula);
colorbar;
hold on;
plot([min(yv), max(yv)], [min(yv), max(yv)], 'k--', 'LineWidth', 1.5);
hold off;
xlabel(sprintf('Actual %s', targetKey), 'FontSize', 14);
ylabel('In-sample fitted', 'FontSize', 14);
title(sprintf('Panel 1: %s', idBest), 'FontSize', 13);
set(gca, 'FontSize', 14, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');

% Second panel: PT2 + kappa
row2 = cmp(ismember(cmp.model_id, "M2_target_best_PT2_plus_kappa"), :);
preds2 = splitPreds(char(row2.predictors(1)));
mask2 = master.rowOk & isfinite(y);
[Z2, ~, mask2] = designMatrixFromPreds(desc, preds2, mask2, master.X, master.I_peak, master.S_peak, master.kappa);
yv2 = y(mask2);
yh2 = Z2 * (Z2 \ yv2);

nexttile;
scatter(yv2, yh2, 48, master.T_K(mask2), 'filled');
colormap(gca, parula);
colorbar;
hold on;
plot([min(yv2), max(yv2)], [min(yv2), max(yv2)], 'k--', 'LineWidth', 1.5);
hold off;
xlabel(sprintf('Actual %s', targetKey), 'FontSize', 14);
ylabel('Fitted (PT2+\kappa)', 'FontSize', 14);
title('M2: PT2 + \kappa', 'FontSize', 13);
set(gca, 'FontSize', 14, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');

paths = save_run_figure(fig, base_name, runDir);
close(fig);
end

function id = pickBestLoocvId(cmp, order)
for i = 1:numel(order)
    rows = cmp(ismember(cmp.model_id, string(order{i})), :);
    if ~isempty(rows) && isfinite(rows.loocv_rmse(1))
        id = order{i};
        return;
    end
end
id = char(cmp.model_id(1));
end

function paths = figLoocvCompare(cmp, targetKey, runDir)
ids = {'M1_target_best_PT2','M2_target_best_PT2_plus_kappa','M3_target_X_only','M4_target_X_plus_kappa','M5_target_PT2_X_kappa'};
labels = {'M1 PT','M2 PT+\kappa','M3 X','M4 X+\kappa','M5 PT+X+\kappa'};
vals = nan(size(ids));
for i = 1:numel(ids)
    r = cmp(ismember(cmp.model_id, string(ids{i})), :);
    if ~isempty(r)
        vals(i) = r.loocv_rmse(1);
    end
end

base_name = sprintf('LOOCV_error_comparison_%s', targetKey);
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'centimeters', 'Position', [2 2 12 6]);
bar(vals, 'FaceColor', [0.35 0.55 0.75]);
set(gca, 'XTickLabel', labels, 'XTickLabelRotation', 25, 'FontSize', 12);
ylabel('LOOCV RMSE', 'FontSize', 14);
set(gca, 'FontSize', 13, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');
paths = save_run_figure(fig, base_name, runDir);
close(fig);
end

function paths = figResidualVsKappa(master, bests, targetKey, runDir)
desc = master.descriptorTable;
if targetKey == 'A'
    y = master.A(:);
    pt = splitPreds(bests.pt2_str_A);
else
    y = master.R(:);
    pt = splitPreds(bests.pt2_str_R);
end
mask = master.rowOk & isfinite(y);
for k = 1:numel(pt)
    mask = mask & isfinite(double(desc.(pt{k})(:)));
end
[Z, ~, mask] = designMatrixFromPreds(desc, pt, mask, master.X, master.I_peak, master.S_peak, master.kappa);
yv = y(mask);
beta = Z \ yv;
res = yv - Z * beta;
kap = master.kappa(mask);

base_name = sprintf('residual_%s_vs_kappa', targetKey);
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'centimeters', 'Position', [2 2 10 7]);
scatter(kap, res, 56, master.T_K(mask), 'filled');
colormap(gca, parula);
cb = colorbar;
cb.Label.String = 'T (K)';
xlabel('\kappa(T)', 'FontSize', 14);
ylabel(sprintf('PT-only residual %s', targetKey), 'FontSize', 14);
set(gca, 'FontSize', 14, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');
paths = save_run_figure(fig, base_name, runDir);
close(fig);
end

function paths = figCoefStability(robTbl, runDir)
base_name = 'coefficient_stability_summary';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'centimeters', 'Position', [2 2 12 7]);
windows = unique(robTbl.window);
x = 1:numel(windows);
hold on;
for i = 1:numel(x)
    sub = robTbl(strcmp(robTbl.window, windows{i}) & robTbl.target == "A", :);
    if ~isempty(sub)
        plot(x(i), sub.loocv_rmse_PT2_kappa(1), 'o', 'MarkerSize', 12, 'LineWidth', 2, 'DisplayName', 'A');
    end
end
for i = 1:numel(x)
    sub = robTbl(strcmp(robTbl.window, windows{i}) & robTbl.target == "R", :);
    if ~isempty(sub)
        plot(x(i) + 0.1, sub.loocv_rmse_PT2_kappa(1), 's', 'MarkerSize', 12, 'LineWidth', 2, 'HandleVisibility', 'off');
    end
end
hold off;
set(gca, 'XTick', x, 'XTickLabel', windows, 'FontSize', 12);
ylabel('LOOCV RMSE (PT2+\kappa)', 'FontSize', 14);
title('Coefficient / window stability proxy', 'FontSize', 14);
legend('A marker', 'Location', 'best');
set(gca, 'FontSize', 13, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');
paths = save_run_figure(fig, base_name, runDir);
close(fig);
end

function paths = figRobustnessWindows(robTbl, runDir)
base_name = 'robustness_window_comparison';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'centimeters', 'Position', [2 2 12 7]);
windows = unique(robTbl.window);
xa = nan(numel(windows), 1);
xr = xa;
for i = 1:numel(windows)
    sa = robTbl(strcmp(robTbl.window, windows{i}) & robTbl.target == "A", :);
    sr = robTbl(strcmp(robTbl.window, windows{i}) & robTbl.target == "R", :);
    if ~isempty(sa)
        xa(i) = sa.loocv_rmse_PT2(1) - sa.loocv_rmse_PT2_kappa(1);
    end
    if ~isempty(sr)
        xr(i) = sr.loocv_rmse_PT2(1) - sr.loocv_rmse_PT2_kappa(1);
    end
end
bar([xa, xr], 'BarWidth', 0.9);
set(gca, 'XTickLabel', windows, 'FontSize', 12);
ylabel('\Delta LOOCV RMSE (PT2 - PT2+\kappa)', 'FontSize', 14);
legend({'A','R'}, 'Location', 'best');
set(gca, 'FontSize', 13, 'LineWidth', 2, 'TickDir', 'out', 'Box', 'off');
paths = save_run_figure(fig, base_name, runDir);
close(fig);
end

%% ---- Report + verdicts -------------------------------------------------

function [txt, verdicts] = buildClosureReport(paths, master, auditTbl, cmpA, cmpR, minA, minR, sectorTbl, residTbl, robTbl, bests, cfg, thisFile)
lines = strings(0, 1);
lines(end + 1) = "# Barrier \rightarrow Relaxation / Aging — mechanism closure (Level 2)";
lines(end + 1) = "";
lines(end + 1) = "## A. Supported";
lines(end + 1) = "## B. Suggestive (not decisive)";
lines(end + 1) = "## C. Not supported";
lines(end + 1) = "(Verdict bullets filled after scoring.)";
lines(end + 1) = "";
lines(end + 1) = "## Inputs";
lines(end + 1) = sprintf("- `barrier_descriptors`: `%s`", paths.barrierDescriptorsPath);
lines(end + 1) = sprintf("- `kappa_vs_T`: `%s`", paths.kappaCsvPath);
lines(end + 1) = sprintf("- `phi_shape` (provenance): `%s`", ternary(strlength(string(paths.phiShapePath)) > 0, paths.phiShapePath, 'not found'));
lines(end + 1) = sprintf("- Master n (descriptor rows): **%d**", height(master.descriptorTable));
lines(end + 1) = "";
lines(end + 1) = "## Descriptor audit summary";
lines(end + 1) = sprintf("- Audit rows: **%d** (see `tables/descriptor_audit.csv`).", height(auditTbl));
lines(end + 1) = "";
lines(end + 1) = "## Q1–Q3 answers (explicit)";
lines(end + 1) = "### Q1. Small robust PT set for A and R?";
lines(end + 1) = formatBestRows(cmpA, cmpR);
lines(end + 1) = "### Q2. Two-sector additive structure?";
lines(end + 1) = "### Q3. Does \kappa add beyond PT and X?";
lines(end + 1) = "";
lines(end + 1) = "## Sector model table (M1–M5)";
lines(end + 1) = "(See `tables/sector_additivity_metrics.csv`.)";
lines(end + 1) = "";
lines(end + 1) = "## PT-only residual links";
lines(end + 1) = formatResidMarkdown(residTbl);
lines(end + 1) = "";
lines(end + 1) = "## Robustness";
lines(end + 1) = "(See `tables/robustness_window_summary.csv`.)";
lines(end + 1) = "";
lines(end + 1) = "## Provenance";
lines(end + 1) = sprintf("- Script: `%s`", thisFile);
lines(end + 1) = "";

[verdicts, fillA, fillB, fillC, qtext] = computeVerdicts(cmpA, cmpR, residTbl, robTbl, cfg);
lines = replaceVerdictSection(lines, fillA, fillB, fillC, qtext);

lines(end + 1) = "";
lines(end + 1) = "## FINAL VERDICTS";
lines(end + 1) = sprintf("VERDICT_A: **%s**", verdicts.A);
lines(end + 1) = sprintf("VERDICT_R: **%s**", verdicts.R);
lines(end + 1) = sprintf("VERDICT_TWO_SECTOR: **%s**", verdicts.twoSector);

txt = join(lines, newline);
verdicts.bestPT_A = sprintf('M1 PT2: %s', bests.pt2_str_A);
verdicts.bestPT_R = sprintf('M1 PT2: %s', bests.pt2_str_R);
m2a = cmpA(ismember(cmpA.model_id, "M2_target_best_PT2_plus_kappa"), :);
m2r = cmpR(ismember(cmpR.model_id, "M2_target_best_PT2_plus_kappa"), :);
verdicts.bestPTkap_A = ternary(~isempty(m2a), char(m2a.predictors(1)), 'n/a');
verdicts.bestPTkap_R = ternary(~isempty(m2r), char(m2r.predictors(1)), 'n/a');
m1a = cmpA(ismember(cmpA.model_id, "M1_target_best_PT2"), :);
m1r = cmpR(ismember(cmpR.model_id, "M1_target_best_PT2"), :);
verdicts.loocv_pt_A = getf(m1a, 'loocv_rmse');
verdicts.loocv_ptk_A = getf(m2a, 'loocv_rmse');
verdicts.loocv_pt_R = getf(m1r, 'loocv_rmse');
verdicts.loocv_ptk_R = getf(m2r, 'loocv_rmse');
sub = residTbl(residTbl.target == "A", :);
if isempty(sub)
    verdicts.residKapStr = 'n/a';
    verdicts.residKapVal = NaN;
else
    [~, im] = max(abs(sub.spearman_res_pred));
    verdicts.residKapStr = char(sub.predictor(im));
    verdicts.residKapVal = sub.spearman_res_pred(im);
end
end

function lines = replaceVerdictSection(lines, fillA, fillB, fillC, qtext)
idxA = find(lines == "## A. Supported", 1);
idxB = find(lines == "## B. Suggestive (not decisive)", 1);
idxC = find(lines == "## C. Not supported", 1);
lines(idxA + 1) = fillA;
lines(idxB + 1) = fillB;
lines(idxC + 1) = fillC;
idxQ = find(contains(lines, "### Q1."), 1);
if ~isempty(idxQ)
    lines(idxQ + 1) = qtext;
end
end

function [verdicts, fillA, fillB, fillC, q1] = computeVerdicts(cmpA, cmpR, residTbl, robTbl, cfg)
m1a = cmpA(ismember(cmpA.model_id, "M1_target_best_PT2"), :);
m2a = cmpA(ismember(cmpA.model_id, "M2_target_best_PT2_plus_kappa"), :);
m1r = cmpR(ismember(cmpR.model_id, "M1_target_best_PT2"), :);
m2r = cmpR(ismember(cmpR.model_id, "M2_target_best_PT2_plus_kappa"), :);

if isempty(m1a) || isempty(m2a)
    impA = 0;
else
    impA = (m1a.loocv_rmse(1) - m2a.loocv_rmse(1)) / max(m1a.loocv_rmse(1), eps);
end
if isempty(m1r) || isempty(m2r)
    impR = 0;
else
    impR = (m1r.loocv_rmse(1) - m2r.loocv_rmse(1)) / max(m1r.loocv_rmse(1), eps);
end

subA = residTbl(strcmp(residTbl.target, 'A'), :);
[~, im] = max(abs(subA.spearman_res_pred));
skA = abs(subA.spearman_res_pred(im));

verdicts = struct();
verdicts.A = verdict1D(cmpA, impA, cfg.materialLoocvRelImprove);
verdicts.R = verdict1D(cmpR, impR, cfg.materialLoocvRelImprove);
verdicts.twoSector = verdictTwoSector(impA, impR, skA, cfg);

subPT = cmpA(contains(cmpA.model_id, "PT_best_loocv"), :);
fillA = string(sprintf("- **A**: max |LOOCV Pearson| among PT_best_loocv_* rows = %.2f (see `A_model_comparison.csv`).", ...
    max(abs(subPT.loocv_pearson), [], 'omitnan')));
fillB = string(sprintf("- **\kappa**: Adding \kappa after best PT changes LOOCV RMSE for A by **%.1f%%** (relative drop).", 100 * impA));
fillC = string("- Small n (~11); causal mechanism closure is **not** established by regression alone.");
q1 = string(sprintf("Best PT rows (see `A_model_comparison.csv` / `R_model_comparison.csv`). M2 vs M1 LOOCV: A rel. improvement = %.2f%%.", 100 * impA));
end

function v = verdict1D(cmp, impKappa, thr)
bestP = max(abs(cmp.loocv_pearson(contains(cmp.model_id, "PT_best_loocv_3"))), [], 'omitnan');
if bestP >= 0.75 && impKappa >= thr
    v = "SUPPORTED";
elseif bestP >= 0.5 || impKappa >= 0.05
    v = "PARTIALLY SUPPORTED";
else
    v = "NOT SUPPORTED";
end
end

function v = verdictTwoSector(impA, impR, spearmanResKap, cfg)
if (impA >= cfg.materialLoocvRelImprove || impR >= cfg.materialLoocvRelImprove) && spearmanResKap >= 0.45
    v = "PARTIALLY SUPPORTED";
elseif spearmanResKap >= 0.55 && (impA > 0 || impR > 0)
    v = "PARTIALLY SUPPORTED";
else
    v = "NOT SUPPORTED";
end
end

function s = formatBestRows(cmpA, cmpR)
r1 = cmpA(ismember(cmpA.model_id, "PT_best_loocv_1"), :);
r3 = cmpA(ismember(cmpA.model_id, "PT_best_loocv_3"), :);
if isempty(r1) || isempty(r3)
    s = "- **A**: PT_best_loocv rows missing from comparison table.\n";
else
    s = sprintf("- **A** best 1-PT (LOOCV): %s, rmse=%.4g, rho_pred=%.3f\n- **A** best 3-PT: %s, rmse=%.4g, rho_pred=%.3f\n", ...
        char(r1.predictors(1)), r1.loocv_rmse(1), r1.loocv_spearman(1), ...
        char(r3.predictors(1)), r3.loocv_rmse(1), r3.loocv_spearman(1));
end
r1r = cmpR(ismember(cmpR.model_id, "PT_best_loocv_1"), :);
r3r = cmpR(ismember(cmpR.model_id, "PT_best_loocv_3"), :);
if isempty(r1r) || isempty(r3r)
    s = s + "- **R**: PT_best_loocv rows missing.\n";
else
    s = s + sprintf("- **R** best 1-PT: %s, rmse=%.4g\n- **R** best 3-PT: %s, rmse=%.4g\n", ...
        char(r1r.predictors(1)), r1r.loocv_rmse(1), char(r3r.predictors(1)), r3r.loocv_rmse(1));
end
end

function s = formatResidMarkdown(residTbl)
s = "";
for i = 1:height(residTbl)
    s = s + sprintf("- **%s** residual vs **%s**: Spearman = %.3f, Pearson = %.3f (n=%d)\n", ...
        residTbl.target(i), residTbl.predictor(i), residTbl.spearman_res_pred(i), residTbl.pearson_res_pred(i), residTbl.n(i));
end
end

function s = ternary(c, a, b)
if c
    s = a;
else
    s = b;
end
end

%% ---- Copied / shared helpers (mechanism script parity) ------------------

function aligned = alignOnTemperatureGridClosure(descTbl, relax, aging, switchObs, TX, XX, cfg)
T = descTbl.T_K(:);
mask = true(size(T));
if ismember('row_valid', descTbl.Properties.VariableNames)
    mask = logical(descTbl.row_valid(:));
end
mask = mask & isfinite(T);
T = T(mask);
descTbl = descTbl(mask, :);
A = interp1(relax.T, relax.A, T, cfg.interpMethod, NaN);
R = interp1(aging.T, aging.R, T, cfg.interpMethod, NaN);
Ipeak = interp1(switchObs.T, switchObs.I_peak, T, cfg.interpMethod, NaN);
Speak = interp1(switchObs.T, switchObs.S_peak, T, cfg.interpMethod, NaN);
Xx = interp1(TX, XX, T, cfg.interpMethod, NaN);
use = isfinite(A) & isfinite(R) & isfinite(Xx) & isfinite(Ipeak) & isfinite(Speak);
for k = 1:width(descTbl)
    vn = descTbl.Properties.VariableNames{k};
    if any(strcmp(vn, {'T_K', 'row_valid'}))
        continue;
    end
    use = use & isfinite(double(descTbl.(vn)(:)));
end
aligned = struct();
aligned.T_K = T(use);
aligned.descriptorTable = descTbl(use, :);
aligned.A = A(use);
aligned.R = R(use);
aligned.I_peak_mA = Ipeak(use);
aligned.S_peak = Speak(use);
aligned.X = Xx(use);
end

function source = resolveSourcesBarrier(repoRoot, cfg)
source = struct();
source.ptMatrixPath = '';
[rxDir, ~] = findLatestRunWithFiles(repoRoot, 'relaxation', ...
    {'tables\temperature_observables.csv', 'tables\observables_relaxation.csv'}, cfg.relaxLabelHint);
source.relaxTempPath = fullfile(char(rxDir), 'tables', 'temperature_observables.csv');
[agDir, ~] = findLatestRunWithFiles(repoRoot, 'aging', ...
    {'tables\table_clock_ratio.csv'}, cfg.agingLabelHint);
source.agingClockPath = fullfile(char(agDir), 'tables', 'table_clock_ratio.csv');
[swDir, ~] = findLatestRunWithFiles(repoRoot, 'switching', ...
    {'observable_matrix.csv', 'switching_alignment_core_data.mat'}, cfg.switchLabelHint);
source.switchMatrixPath = fullfile(char(swDir), 'observable_matrix.csv');
end

function [runDir, runName] = findLatestRunWithFiles(repoRoot, experiment, requiredFiles, labelHint)
runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
names = string({runDirs.name});
runDirs = runDirs(~startsWith(names, "run_legacy", 'IgnoreCase', true));
[~, order] = sort({runDirs.name});
runDirs = runDirs(order);
for i = numel(runDirs):-1:1
    candidateName = string(runDirs(i).name);
    if strlength(labelHint) > 0 && ~contains(candidateName, labelHint)
        continue;
    end
    candidateDir = fullfile(runDirs(i).folder, runDirs(i).name);
    ok = true;
    for k = 1:numel(requiredFiles)
        if exist(fullfile(candidateDir, requiredFiles{k}), 'file') ~= 2
            ok = false;
            break;
        end
    end
    if ok
        runDir = string(candidateDir);
        runName = candidateName;
        return;
    end
end
error('No %s run matched hint "%s".', experiment, labelHint);
end

function [runDir, runName] = findLatestSwitchingRunTwoFiles(repoRoot, requiredFiles, labelHint)
runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
names = string({runDirs.name});
runDirs = runDirs(~startsWith(names, "run_legacy", 'IgnoreCase', true));
[~, order] = sort({runDirs.name});
runDirs = runDirs(order);
for i = numel(runDirs):-1:1
    candidateName = string(runDirs(i).name);
    if strlength(labelHint) > 0 && ~contains(candidateName, labelHint)
        continue;
    end
    candidateDir = fullfile(runDirs(i).folder, runDirs(i).name);
    ok = true;
    for k = 1:numel(requiredFiles)
        if exist(fullfile(candidateDir, requiredFiles{k}), 'file') ~= 2
            ok = false;
            break;
        end
    end
    if ok
        runDir = string(candidateDir);
        runName = candidateName;
        return;
    end
end
error('No switching run matched hint "%s" with kappa+phi files.', labelHint);
end

function relax = loadRelaxationSeries(pathStr)
tbl = readtable(pathStr, 'VariableNamingRule', 'preserve');
tcol = firstMatchingName(tbl.Properties.VariableNames, {'T', 'T_K', 'temperature'});
acol = firstMatchingName(tbl.Properties.VariableNames, {'A_T', 'A', 'Relax_tau_T'});
relax.T = double(tbl.(tcol)(:));
relax.A = double(tbl.(acol)(:));
end

function aging = loadAgingRatioSeries(pathStr)
tbl = readtable(pathStr, 'VariableNamingRule', 'preserve');
tcol = firstMatchingName(tbl.Properties.VariableNames, {'Tp', 'T_K', 'T', 'temperature'});
rcol = firstMatchingName(tbl.Properties.VariableNames, {'R_tau_FM_over_tau_dip', 'R', 'ratio'});
aging.T = double(tbl.(tcol)(:));
aging.R = double(tbl.(rcol)(:));
end

function sw = loadSwitchingPeaks(pathStr)
tbl = readtable(pathStr, 'VariableNamingRule', 'preserve');
tcol = firstMatchingName(tbl.Properties.VariableNames, {'T', 'T_K', 'temperature'});
sw.T = double(tbl.(tcol)(:));
sw.I_peak = double(tbl.I_peak(:));
sw.S_peak = double(tbl.S_peak(:));
end

function name = firstMatchingName(names, candidates)
for i = 1:numel(candidates)
    if any(strcmp(names, candidates{i}))
        name = candidates{i};
        return;
    end
end
error('No matching column.');
end

function r = pearsonSafe(a, b)
a = a(:);
b = b(:);
m = isfinite(a) & isfinite(b);
if sum(m) < 2
    r = NaN;
    return;
end
r = corr(a(m), b(m), 'type', 'Pearson');
end

function r = spearmanSafe(a, b)
a = a(:);
b = b(:);
m = isfinite(a) & isfinite(b);
if sum(m) < 3
    r = NaN;
    return;
end
r = corr(a(m), b(m), 'type', 'Spearman');
end

function ensureRunSubdirs(runDir)
for s = {'figures', 'tables', 'reports', 'review'}
    d = fullfile(runDir, s{1});
    if exist(d, 'dir') ~= 7
        mkdir(d);
    end
end
end

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
        mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid < 0
    return;
end
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDef(cfg, f, v)
if ~isfield(cfg, f) || isempty(cfg.(f))
    cfg.(f) = v;
end
end
