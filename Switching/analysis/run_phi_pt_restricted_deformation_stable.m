function out = run_phi_pt_restricted_deformation_stable(cfg)
% run_phi_pt_restricted_deformation_stable
% AGENT 5.1 — PHI FROM PT (STABLE VERSION)
%
% CRITICAL FIXES (per instructions):
% 1) Uses explicit ptRunId from cfg (no "latest" search).
% 2) Creates run context immediately after minimal path setup.
% 3) Emits debug prints after every numbered step.
% 4) No recursive directory scanning.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

set(0, 'DefaultFigureVisible', 'off');

analysisDir = fileparts(mfilename('fullpath'));
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

% Minimal path setup (required for run + helpers)
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'analysis', 'knowledge'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

% -------------------- STEP 0 — INIT --------------------
% Decomposition run (Phi/kappa) is fixed by instructions.
cfg = localSetDef(cfg, 'decompositionRunId', "run_2026_03_24_220314_residual_decomposition");

% PT run MUST be explicit; default provided but overridable via cfg.
cfg = localSetDef(cfg, 'ptRunId', "run_2026_03_25_013356_pt_robust_canonical");
ptRunId = string(cfg.ptRunId);
if contains(lower(ptRunId), 'xxxxx')
    error('cfg.ptRunId is still a placeholder (contains XXXXX). Provide an explicit run id.');
end

cfg = localSetDef(cfg, 'runLabel', "phi_pt_restricted_deformation_stable");
cfg = localSetDef(cfg, 'canonicalMaxTemperatureK', 30);
cfg = localSetDef(cfg, 'exclude22K', 22);
cfg = localSetDef(cfg, 'excludeTolK', 1e-3);
cfg = localSetDef(cfg, 'tempMatchTolK', 0.05);   % relaxed: avoids "no match" failures
cfg = localSetDef(cfg, 'epsFloor', 1e-12);
cfg = localSetDef(cfg, 'tangentEpsilonRel', 1e-3);

% Keep sweeps capped to avoid long/hanging runs.
cfg = localSetDef(cfg, 'maxAlphaPerPerturb', 5);

decompRunId = string(cfg.decompositionRunId);
runDataset = sprintf('phi_pt_restricted_deformation_stable | decomp:%s | pt:%s', ...
    char(decompRunId), char(ptRunId));
run = createRunContext('switching', struct('runLabel', cfg.runLabel, 'dataset', runDataset)); % FIRST STAGE: run created early
fprintf("RUN CREATED: %s\n", run.run_dir);

appendText(run.log_path, sprintf('[%s] run_phi_pt_restricted_deformation_stable started\n', localStampNow()));
appendText(run.log_path, sprintf('decompositionRunId=%s\nptRunId=%s\n', char(decompRunId), char(ptRunId)));

% Outputs init (so we can always print verdicts)
globalVerdict = "NOT_SUPPORTED";
localVerdict = "NOT_SUPPORTED";
phiModeVerdict = "NO";

globalBestCorr = NaN; globalBestRmse = NaN;
globalBestCorrAll = NaN; globalBestRmseAll = NaN;
localBestCorr = NaN; localBestRmse = NaN;
localBestCorrAll = NaN; localBestRmseAll = NaN;

reconSummaryPath = "";
localTangentPath = "";
reportPath = "";

% -------------------- STEP 1 — LOAD RESIDUAL RUN --------------------
fprintf("Loading residual decomposition...\n");
try
    evDecomp = load_run_evidence(decompRunId);
    assert(strlength(evDecomp.path) > 0, 'Decomposition run path unresolved.');

    % Deterministic run-artifact paths (avoid suffix ambiguity)
    phiPath = fullfile(char(evDecomp.path), 'tables', 'phi_shape.csv');
    kappaPath = fullfile(char(evDecomp.path), 'tables', 'kappa_vs_T.csv');
    sourcesPath = fullfile(char(evDecomp.path), 'tables', 'residual_decomposition_sources.csv');

    assert(exist(phiPath, 'file') == 2, 'Missing phi_shape.csv at %s', phiPath);
    assert(exist(kappaPath, 'file') == 2, 'Missing kappa_vs_T.csv at %s', kappaPath);
    assert(exist(sourcesPath, 'file') == 2, 'Missing residual_decomposition_sources.csv at %s', sourcesPath);

    phiTbl = readtable(phiPath);
    xGrid = double(phiTbl.x(:));
    phiEmp = localNormalizeToMaxAbs(double(phiTbl.Phi(:)));

    kappaTbl = readtable(kappaPath);
    kappaCol = localPickVar(string(kappaTbl.Properties.VariableNames), ["T", "T_K"]);
    tempsK = double(kappaTbl.(kappaCol)(:));
    kappaVals = double(kappaTbl.kappa(:));

    % alignment + scaling + pt_matrix baseline for deltaS_actual
    sourcesTbl = readtable(sourcesPath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    alignmentCorePath = localFindSourceFile(sourcesTbl, 'alignment_core_map');
    scalingParamsPath = localFindSourceFile(sourcesTbl, 'full_scaling_parameters');
    ptMatrixDecompPath = localFindSourceFile(sourcesTbl, 'pt_matrix');

    [Smap, tempsMap, currents] = localLoadAlignmentCore(alignmentCorePath);
    [Ipeak, Speak, width, tempsScale] = localLoadScalingParams(scalingParamsPath);

    ptDecompData = localLoadPTData(ptMatrixDecompPath);
    ptRobustData = localLoadPTData(localFindPTMatrixPath(repoRoot, ptRunId));

    % temperature masks on kappa grid
    maskAllLow = tempsK <= cfg.canonicalMaxTemperatureK;
    maskNo22 = maskAllLow & ~(abs(tempsK - cfg.exclude22K) <= cfg.excludeTolK);
    if ~any(maskNo22)
        maskNo22 = maskAllLow;
    end

    fprintf("[STEP 1] Loaded Phi/kappa and alignment/scaling data. nT=%d nX=%d\n", numel(tempsK), numel(xGrid));
catch ME
    fprintf(2, "[STEP 1] FAILED: %s\n", ME.message);
    appendText(run.log_path, sprintf('[FAIL_STAGE STEP_1] %s\n', ME.message));
    fprintf('FAIL_STAGE: STEP_1\n');
    return;
end

% -------------------- STEP 2 — LOAD PT (DIRECT PATH) --------------------
% (PT already loaded inside step 1 for deltaS_actual + perturbations.)
fprintf("Loading PT from run: %s\n", ptRunId);
fprintf("[STEP 2] OK\n");

% -------------------- STEP 3 — RUN GLOBAL TEST --------------------
fprintf("Running global deformation test...\n");
try
    [deltaS_actual_x, deltaS_pred_x_last, cdfRobust0, Xrows] = localPrepareBaselineAndCDF( ...
        tempsK, tempsMap, currents, Smap, Ipeak, Speak, width, ...
        ptDecompData, ptRobustData, xGrid, maskAllLow, cfg);

    % Build induced phi prediction for perturbations and pick best
    pertTypes = {'mean_shift', 'width_scaling', 'skew_perturb', 'tail_reweight_highI'};

    alpha = localBuildAlphaGrids(cfg, pertTypes);

    rows = {};
    for pi = 1:numel(pertTypes)
        pType = pertTypes{pi};
        bestAll = struct('corr', -Inf, 'rmseRatio', NaN);
        bestNo22 = struct('corr', -Inf, 'rmseRatio', NaN);

        alphas = alpha.(pType);
        for ai = 1:numel(alphas)
            a = alphas(ai);
            try
                deltaS_pred_x = localComputeInducedDeltaSForPerturb( ...
                    tempsK, currents, Speak, maskAllLow, xGrid, Xrows, ...
                    ptRobustData, cdfRobust0, pType, a, cfg);

                % Evaluate on all_lowT subset
                [corrAll, rmseAll] = localCorrAndRmse(phiEmp, deltaS_actual_x, deltaS_pred_x, ...
                    kappaVals, maskAllLow, cfg);

                if isfinite(corrAll) && corrAll > bestAll.corr
                    bestAll.corr = corrAll;
                    bestAll.rmseRatio = rmseAll;
                end

                % Evaluate on no_22K subset
                [corrNo22, rmseNo22] = localCorrAndRmse(phiEmp, deltaS_actual_x, deltaS_pred_x, ...
                    kappaVals, maskNo22, cfg);
                if isfinite(corrNo22) && corrNo22 > bestNo22.corr
                    bestNo22.corr = corrNo22;
                    bestNo22.rmseRatio = rmseNo22;
                end
            catch ME2
                appendText(run.log_path, sprintf('GLOBAL: perturb failed p=%s alpha=%g: %s\n', pType, a, ME2.message));
                continue;
            end
        end

        rows{end+1, 1} = table({pType}, bestAll.corr, bestAll.rmseRatio, {'all_lowT'}, ...
            'VariableNames', {'perturbation_type', 'corr_with_phi', 'rmse_ratio', 'subset'}); %#ok<AGROW>
        rows{end+1, 1} = table({pType}, bestNo22.corr, bestNo22.rmseRatio, {'no_22K'}, ...
            'VariableNames', {'perturbation_type', 'corr_with_phi', 'rmse_ratio', 'subset'}); %#ok<AGROW>
    end

    reconSummaryTbl = vertcat(rows{:});
    reconSummaryPath = save_run_table(reconSummaryTbl, 'phi_pt_restricted_reconstruction_summary.csv', run.run_dir);

    % Best across perturbations for verdict logic (use no_22K)
    sub = reconSummaryTbl(reconSummaryTbl.subset == "no_22K", :);
    [globalBestCorr, ix] = max(sub.corr_with_phi, [], 'omitnan');
    globalBestRmse = double(sub.rmse_ratio(ix));

    % Best across perturbations on all_lowT (for with/without 22K comparison)
    sub2 = reconSummaryTbl(reconSummaryTbl.subset == "all_lowT", :);
    [globalBestCorrAll, ix2] = max(sub2.corr_with_phi, [], 'omitnan');
    globalBestRmseAll = double(sub2.rmse_ratio(ix2));

    fprintf("[STEP 3] Global test complete. Best(all no_22K) corr=%.4f rmse_ratio=%.4g\n", globalBestCorr, globalBestRmse);
    fprintf("[STEP 3] OK (all_lowT corr=%.4f rmse_ratio=%.4g)\n", globalBestCorrAll, globalBestRmseAll);
catch ME
    fprintf(2, "[STEP 3] FAILED: %s\n", ME.message);
    appendText(run.log_path, sprintf('[FAIL_STAGE STEP_3] %s\n', ME.message));
    fprintf('FAIL_STAGE: STEP_3\n');
    return;
end

% -------------------- STEP 4 — RUN LOCAL TEST --------------------
fprintf("Running local tangent test...\n");
try
    [corrT_all, rmseT_all, corrT_no22, rmseT_no22] = localComputeTangentTest( ...
        phiEmp, deltaS_actual_x, tempsK, currents, ...
        ptRobustData, cdfRobust0, xGrid, Xrows, Speak, kappaVals, maskAllLow, maskNo22, cfg);

    localTangentTbl = table( ...
        [corrT_all; corrT_no22], ...
        [rmseT_all; rmseT_no22], ...
        ["all_lowT"; "no_22K"], ...
        'VariableNames', {'corr_tangent', 'rmse_ratio_tangent', 'subset'} );
    localTangentPath = save_run_table(localTangentTbl, 'phi_local_tangent_summary.csv', run.run_dir);

    localBestCorr = corrT_no22;
    localBestRmse = rmseT_no22;
    localBestCorrAll = corrT_all;
    localBestRmseAll = rmseT_all;
    fprintf("[STEP 4] Local tangent complete. Best(no_22K) corr=%.4f rmse_ratio=%.4g\n", localBestCorr, localBestRmse);
    fprintf("[STEP 4] OK (all_lowT corr=%.4f rmse_ratio=%.4g)\n", localBestCorrAll, localBestRmseAll);
catch ME
    fprintf(2, "[STEP 4] FAILED: %s\n", ME.message);
    appendText(run.log_path, sprintf('[FAIL_STAGE STEP_4] %s\n', ME.message));
    fprintf('FAIL_STAGE: STEP_4\n');
    return;
end

% -------------------- STEP 5 — SAVE TABLES + REPORT --------------------
fprintf("Saving outputs...\n");
try
    reportText = localBuildReport(phiEmp, phiTbl, kappaTbl, tempsK, ptRunId, decompRunId, ...
        reconSummaryPath, localTangentPath, globalBestCorr, globalBestRmse, localBestCorr, localBestRmse, ...
        xGrid, maskAllLow, maskNo22);
    reportPath = save_run_report(reportText, 'phi_pt_deformation_report.md', run.run_dir);
catch ME
    fprintf(2, "[STEP 5] FAILED: %s\n", ME.message);
    appendText(run.log_path, sprintf('[FAIL_STAGE STEP_5] %s\n', ME.message));
    fprintf('FAIL_STAGE: STEP_5\n');
    return;
end
fprintf("[STEP 5] OK\n");

% -------------------- STEP 6 — PRINT VERDICTS --------------------
% Global verdict thresholds (spec):
% SUPPORTED if corr > 0.9 and rmse_ratio < 1.5
% PARTIAL if corr ~ 0.6–0.9
% NOT_SUPPORTED otherwise
globalStrong = isfinite(globalBestCorr) && globalBestCorr > 0.9 && isfinite(globalBestRmse) && globalBestRmse < 1.5;
globalPartial = isfinite(globalBestCorr) && globalBestCorr >= 0.6 && globalBestCorr <= 0.9;

if globalStrong
    globalVerdict = "SUPPORTED";
elseif globalPartial
    globalVerdict = "PARTIAL";
else
    globalVerdict = "NOT_SUPPORTED";
end

localStrong = isfinite(localBestCorr) && localBestCorr > 0.9 && isfinite(localBestRmse) && localBestRmse < 1.5;
localPartial = isfinite(localBestCorr) && localBestCorr >= 0.6 && localBestCorr <= 0.9;
if localStrong
    localVerdict = "SUPPORTED";
elseif localPartial
    localVerdict = "PARTIAL";
else
    localVerdict = "NOT_SUPPORTED";
end

% PHI_AS_PT_ONLY_MODE:
% YES if either global or local strongly supported
% NO if both fail
% PARTIAL otherwise
if globalStrong || localStrong
    phiModeVerdict = "YES";
elseif globalVerdict == "NOT_SUPPORTED" && localVerdict == "NOT_SUPPORTED"
    phiModeVerdict = "NO";
else
    phiModeVerdict = "PARTIAL";
end

fprintf('GLOBAL_PT_DEFORMATION: %s\n', globalVerdict);
fprintf('LOCAL_PT_DEFORMATION: %s\n', localVerdict);
fprintf('PHI_AS_PT_ONLY_MODE: %s\n', phiModeVerdict);

% Additional required prints
fprintf('best_global_corr_no_22K=%.4f rmse_ratio_no_22K=%.4g | best_global_corr_all_lowT=%.4f rmse_ratio_all_lowT=%.4g\n', ...
    globalBestCorr, globalBestRmse, globalBestCorrAll, globalBestRmseAll);
fprintf('best_local_corr_no_22K=%.4f rmse_ratio_no_22K=%.4g | best_local_corr_all_lowT=%.4f rmse_ratio_all_lowT=%.4g\n', ...
    localBestCorr, localBestRmse, localBestCorrAll, localBestRmseAll);
fprintf('comparison_remove_22K: global corr %.4f -> %.4f ; rmse_ratio %.4g -> %.4g | local corr %.4f -> %.4f ; rmse_ratio %.4g -> %.4g\n', ...
    globalBestCorrAll, globalBestCorr, globalBestRmseAll, globalBestRmse, localBestCorrAll, localBestCorr, localBestRmseAll, localBestRmse);

appendText(run.log_path, sprintf('Verdicts: global=%s local=%s phi_as_pt_only=%s\n', ...
    char(globalVerdict), char(localVerdict), char(phiModeVerdict)));

out = struct();
out.runDir = string(run.run_dir);
out.reportPath = string(reportPath);
out.reconSummaryPath = string(reconSummaryPath);
out.localTangentPath = string(localTangentPath);
out.globalVerdict = string(globalVerdict);
out.localVerdict = string(localVerdict);
out.phiModeVerdict = string(phiModeVerdict);
out.globalBestCorr = globalBestCorr;
out.globalBestRmse = globalBestRmse;
out.localBestCorr = localBestCorr;
out.localBestRmse = localBestRmse;
end

%% -------------------- Helper functions --------------------
function cfg = localSetDef(cfg, name, val)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = val;
end
end

function p = localFindPathBySuffix(paths, suffix)
p = "";
for i = 1:numel(paths)
    if endsWith(string(paths{i}), suffix, 'IgnoreCase', true)
        p = string(paths{i});
        return;
    end
end
end

function ptPath = localFindPTMatrixPath(repoRoot, ptRunId)
% Load run evidence and select PT_matrix.csv only (no scanning).
evPT = load_run_evidence(ptRunId);
ptPath = localFindPathBySuffix(evPT.tables, 'PT_matrix.csv');
if strlength(ptPath) == 0 || exist(char(ptPath), 'file') ~= 2
    error('PT_matrix.csv missing for ptRunId=%s', char(ptRunId));
end
end

function col = localPickVar(varNames, candidates)
col = "";
for i = 1:numel(candidates)
    if any(varNames == string(candidates(i)))
        col = string(candidates(i));
        return;
    end
end
if strlength(col) == 0
    col = varNames(1);
end
end

function sourcesPath = localFindSourceFile(tbl, role)
vn = string(tbl.Properties.VariableNames);
% Normalize variable names (trim + lowercase + remove possible UTF-8 BOM).
vnNorm = lower(strtrim(regexprep(vn, '^\ufeff', '')));
roleNorm = lower(strtrim(string(role)));

roleColIdx = find(vnNorm == "source_role", 1, 'first');
fileColIdx = find(vnNorm == "source_file", 1, 'first');

if isempty(roleColIdx)
    error('residual_decomposition_sources.csv missing source_role column (vars=%s).', strjoin(cellstr(vn), ','));
end
if isempty(fileColIdx)
    error('residual_decomposition_sources.csv missing source_file column (vars=%s).', strjoin(cellstr(vn), ','));
end

roleColName = vn(roleColIdx);
fileColName = vn(fileColIdx);

roles = string(tbl.(char(roleColName))(:));
idx = find(lower(strtrim(roles)) == roleNorm, 1, 'first');
if isempty(idx)
    error('Missing role=%s in residual_decomposition_sources.csv', role);
end
sourcesPath = string(tbl.(char(fileColName))(idx));
end

function [Smap, temps, currents] = localLoadAlignmentCore(alignmentCorePath)
core = load(alignmentCorePath, 'Smap', 'temps', 'currents');
Smap = double(core.Smap);
temps = double(core.temps(:));
currents = double(core.currents(:));

rowsAreTemps = size(Smap, 1) == numel(temps) && size(Smap, 2) == numel(currents);
rowsAreCurrents = size(Smap, 1) == numel(currents) && size(Smap, 2) == numel(temps);
if rowsAreCurrents && ~rowsAreTemps
    Smap = Smap.';
elseif ~(rowsAreTemps || rowsAreCurrents)
    error('Smap dims do not match temps/currents in alignment core.');
end

[temps, tOrd] = sort(temps);
[currents, iOrd] = sort(currents);
Smap = Smap(tOrd, iOrd);
end

function [Ipeak, Speak, width, tempsScale] = localLoadScalingParams(scalingParamsPath)
tbl = readtable(scalingParamsPath);
vn = string(tbl.Properties.VariableNames);
tempsScale = localNumericColumn(tbl, vn, ["T_K", "T"]);
Ipeak = localNumericColumn(tbl, vn, ["Ipeak_mA", "I_peak", "Ipeak"]);
Speak = localNumericColumn(tbl, vn, ["S_peak", "Speak", "Speak_peak"]);
width = localNumericColumn(tbl, vn, ["width_chosen_mA", "width_I", "width"]);

[tempsScale, ord] = sort(tempsScale);
Ipeak = Ipeak(ord);
Speak = Speak(ord);
width = width(ord);
end

function col = localNumericColumn(tbl, varNames, candidates)
col = NaN(height(tbl), 1);
for i = 1:numel(candidates)
    idx = find(varNames == string(candidates(i)), 1, 'first');
    if ~isempty(idx)
        raw = tbl.(varNames(idx));
        if isnumeric(raw)
            col = double(raw(:));
        else
            col = str2double(string(raw(:)));
        end
        return;
    end
end
end

function ptData = localLoadPTData(ptMatrixPath)
ptData = struct('temps', [], 'currents', [], 'PT', []);
if exist(ptMatrixPath, 'file') ~= 2
    return;
end
tbl = readtable(ptMatrixPath);
vn = string(tbl.Properties.VariableNames);
if any(vn == "T_K")
    tCol = "T_K";
else
    tCol = vn(1);
end
ptData.temps = double(tbl.(tCol)(:));
currentCols = setdiff(vn, tCol, 'stable');
currents = NaN(numel(currentCols), 1);
for j = 1:numel(currentCols)
    currents(j) = localParseCurrentFromColumnName(currentCols(j));
end
keep = isfinite(currents);
currents = currents(keep);
currentCols = currentCols(keep);
PT = table2array(tbl(:, currentCols));
PT = double(PT);
[currents, ord] = sort(currents);
PT = PT(:, ord);
ptData.currents = currents;
ptData.PT = PT;
end

function val = localParseCurrentFromColumnName(name)
s = char(string(name));
s = regexprep(s, '^Ith_', '', 'ignorecase');
s = regexprep(s, '_mA$', '', 'ignorecase');
sDot = strrep(s, '_', '.');
val = str2double(sDot);
if isfinite(val)
    return;
end
m = regexp(s, '[-+]?\d*\.?\d+', 'match', 'once');
val = str2double(m);
end

function v = localNormalizeToMaxAbs(v)
scale = max(abs(v), [], 'omitnan');
if ~(isfinite(scale) && scale > 0)
    scale = 1;
end
v = v ./ scale;
end

function stamp = localStampNow()
stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1
    return;
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', char(string(textValue)));
end

function [deltaS_actual_x, deltaS_pred_x_last, cdfRobust0, Xrows] = localPrepareBaselineAndCDF( ...
    tempsK, tempsMap, currents, Smap, Ipeak, Speak, width, ...
    ptDecompData, ptRobustData, xGrid, maskAllLow, cfg)

nT = numel(tempsK);
nX = numel(xGrid);
deltaS_actual_x = NaN(nT, nX);

% Precompute robust cdf0 for all T in kappa grid for which we need it (all low-T mask)
nI = numel(currents);
cdfRobust0 = NaN(nT, nI);

% Build a quick nearest-match map for temps
for it = 1:nT
    T = tempsK(it);
    if ~maskAllLow(it)
        continue;
    end
    idxM = find(abs(tempsMap - T) <= cfg.tempMatchTolK, 1, 'first');
    if isempty(idxM)
        idxM = find(abs(tempsMap - T) == min(abs(tempsMap - T)), 1, 'first');
    end

    % In this stable runner we assume Ipeak/Speak/width arrays are on the kappa temps grid.
    Ipk = Ipeak(it);
    Spk = Speak(it);
    w = width(it);

    if ~(isfinite(Ipk) && isfinite(Spk) && isfinite(w) && w ~= 0)
        continue;
    end

    Srow = Smap(idxM, :);
    p0 = localPTpdfAtT(ptDecompData, T);
    if isempty(p0)
        continue;
    end
    cdf0 = localCdfFromPdfOnCurrents(p0, ptDecompData.currents, currents);
    if any(~isfinite(cdf0))
        continue;
    end
    Scdf = Spk * cdf0(:).';
    dSrow = Srow - Scdf;

    xRow = (currents(:)' - Ipk) ./ w;
    deltaS_actual_x(it, :) = localInterpolateRowToX(xGrid, xRow, dSrow);

    % Robust cdf0
    pRob = localPTpdfAtT(ptRobustData, T);
    if ~isempty(pRob)
        cdfRobust0(it, :) = localCdfFromPdfOnCurrents(pRob, ptRobustData.currents, currents);
    end
end

deltaS_pred_x_last = [];
% Return xRows for exact mapping in later tasks
Xrows = NaN(nT, numel(currents));
for it = 1:nT
    Xrows(it, :) = (currents(:)' - Ipeak(it)) ./ max(width(it), eps);
end
end

function p = localPTpdfAtT(ptData, T)
% Returns pdf p(I) on ptData.currents grid for temperature T using row interpolation.
p = [];
tempsPT = ptData.temps(:);
if isempty(tempsPT) || isempty(ptData.PT)
    return;
end
% Nearest row is typically enough (temperatures are discrete here).
[d, ix] = min(abs(tempsPT - T));
if d > 0.2
    % fallback to interpolation if too far
    pVec = NaN(numel(ptData.currents), 1);
    for j = 1:numel(ptData.currents)
        col = ptData.PT(:, j);
        pVec(j) = interp1(tempsPT, col, T, 'linear', NaN);
    end
    if any(isfinite(pVec))
        p = max(pVec, 0);
        area = trapz(ptData.currents, p);
        if isfinite(area) && area > 0
            p = p ./ area;
        else
            p = [];
        end
    end
    return;
end
p = double(ptData.PT(ix, :)).';
if any(~isfinite(p))
    return;
end
p = max(p, 0);
area = trapz(ptData.currents, p);
if ~(isfinite(area) && area > 0)
    p = [];
    return;
end
p = p ./ area;
end

function cdf = localCdfFromPdfOnCurrents(p, pCurr, switchingCurr)
% p is pdf on pCurr. Returns normalized CDF sampled on switchingCurr.
p = double(p(:));
pCurr = double(pCurr(:));
switchingCurr = double(switchingCurr(:));

pOn = interp1(pCurr, p, switchingCurr, 'linear', 0);
pOn = max(pOn, 0);
area = trapz(switchingCurr, pOn);
if ~(isfinite(area) && area > 0)
    cdf = NaN(size(switchingCurr));
    return;
end
pOn = pOn ./ area;

cdf = cumtrapz(switchingCurr, pOn);
if ~(isfinite(cdf(end)) && cdf(end) > 0)
    cdf = NaN(size(switchingCurr));
    return;
end
cdf = cdf ./ cdf(end);
cdf = min(max(cdf, 0), 1);
end

function y = localInterpolateRowToX(xGrid, xRow, yRow)
xRow = double(xRow(:)).';
yRow = double(yRow(:)).';
m = isfinite(xRow) & isfinite(yRow);
if nnz(m) < 3
    y = NaN(size(xGrid));
    return;
end
x = xRow(m);
yv = yRow(m);
[x, ord] = sort(x);
yv = yv(ord);
[x, iu] = unique(x, 'stable');
yv = yv(iu);
y = interp1(x, yv, xGrid, 'linear', NaN);
end

function inducedDeltaS_x = localComputeInducedDeltaSForPerturb( ...
    tempsK, currents, Speak, maskAllLow, xGrid, Xrows, ...
    ptRobustData, cdfRobust0, pType, alpha, cfg) %#ok<INUSL>

nT = numel(tempsK);
nX = numel(xGrid);
inducedDeltaS_x = NaN(nT, nX);

% Perturbations use base pdf p0 on ptRobustData.currents at each T.
for it = 1:nT
    if ~maskAllLow(it)
        continue;
    end
    T = tempsK(it);
    if ~isfinite(Speak(it))
        continue;
    end
    p0 = localPTpdfAtT(ptRobustData, T);
    if isempty(p0)
        continue;
    end
    cdf0 = cdfRobust0(it, :).';
    if any(~isfinite(cdf0))
        continue;
    end

    p1 = localPerturbPdf(p0, ptRobustData.currents, pType, alpha);
    if isempty(p1)
        continue;
    end

    cdf1 = localCdfFromPdfOnCurrents(p1, ptRobustData.currents, currents);
    if any(~isfinite(cdf1))
        continue;
    end

    inducedCurrent = Speak(it) * (cdf1(:) - cdf0(:));
    xRow = Xrows(it, :);
    if all(~isfinite(xRow))
        continue;
    end
    inducedDeltaS_x(it, :) = localInterpolateRowToX(xGrid, xRow, inducedCurrent(:).');
end
end

function [corrAbs, rmseRatio] = localCorrAndRmse(phiEmp, deltaS_actual_x, deltaS_pred_x, ...
    kappaVals, maskSel, cfg)

phiEmp = phiEmp(:);
kappaSel = kappaVals(maskSel);
Ractual = deltaS_actual_x(maskSel, :);
Rpred = deltaS_pred_x(maskSel, :);

% phiPred extracted by kappa-weighted projection across T for each x.
nX = size(Rpred, 2);
phiPred = NaN(nX, 1);
for xi = 1:nX
    m = isfinite(Rpred(:, xi)) & isfinite(kappaSel);
    if nnz(m) < 2
        continue;
    end
    denom = sum(kappaSel(m).^2, 'omitnan');
    if ~(isfinite(denom) && denom > 0)
        continue;
    end
    phiPred(xi) = sum(kappaSel(m) .* Rpred(m, xi), 'omitnan') ./ denom;
end
phiPred = localNormalizeToMaxAbs(phiPred);

mCorr = isfinite(phiEmp) & isfinite(phiPred);
if nnz(mCorr) < 10
    corrAbs = NaN;
else
    if dot(phiPred(mCorr), phiEmp(mCorr)) < 0
        phiPred = -phiPred;
    end
    corrAbs = abs(corr(phiEmp(mCorr), phiPred(mCorr)));
end

% RMSE ratio in residual space
RhatPred = kappaSel(:) .* phiPred(:).';
RhatBase = kappaSel(:) .* phiEmp(:).';
rmsePred = localRMSE(Ractual, RhatPred);
rmseBase = localRMSE(Ractual, RhatBase);
rmseRatio = rmsePred / max(rmseBase, cfg.epsFloor);
end

function rmse = localRMSE(A, B)
diff = double(A - B);
diff = diff(:);
diff = diff(isfinite(diff));
if isempty(diff)
    rmse = NaN;
    return;
end
rmse = sqrt(mean(diff.^2, 'omitnan'));
end

function alpha = localBuildAlphaGrids(cfg, pertTypes)
% Small alpha grids to avoid long runtimes.
N = cfg.maxAlphaPerPerturb;
if N < 3
    N = 3;
end

alpha = struct();
alpha.mean_shift = linspace(-0.6, 0.6, N);
alpha.width_scaling = linspace(-0.25, 0.25, N);
alpha.skew_perturb = linspace(-2.0, 2.0, N);
alpha.tail_reweight_highI = linspace(-2.0, 2.0, N);
end

function p1 = localPerturbPdf(p0, ptCurr, pType, alpha)
p0 = double(p0(:));
ptCurr = double(ptCurr(:));

if any(~isfinite(p0)) || isempty(p0)
    p1 = [];
    return;
end

mu = trapz(ptCurr, p0 .* ptCurr);
var = trapz(ptCurr, p0 .* (ptCurr - mu).^2);
sigma = sqrt(max(var, 0));
if ~(isfinite(sigma) && sigma > 0)
    sigma = 1;
end

p1 = NaN(size(p0));
switch pType
    case 'mean_shift'
        shift = alpha * sigma;
        p1 = interp1(ptCurr, p0, ptCurr - shift, 'linear', 0);
    case 'width_scaling'
        s = exp(alpha);
        J = mu + (ptCurr - mu) ./ s;
        p1 = interp1(ptCurr, p0, J, 'linear', 0) ./ s;
    case 'skew_perturb'
        tilt = exp(alpha * (ptCurr - mu) ./ (sigma + eps));
        p1 = p0 .* tilt;
    case 'tail_reweight_highI'
        cdf0 = cumtrapz(ptCurr, p0);
        if cdf0(end) > 0
            cdf0 = cdf0 ./ cdf0(end);
        else
            cdf0(:) = 0.5;
        end
        qTail = 0.75;
        idx = find(cdf0 >= qTail, 1, 'first');
        if isempty(idx)
            Ithr = ptCurr(end);
        else
            Ithr = ptCurr(idx);
        end
        rewt = exp(alpha * max(0, ptCurr - Ithr) ./ (sigma + eps));
        p1 = p0 .* rewt;
    otherwise
        p1 = [];
        return;
end

p1 = max(p1, 0);
area = trapz(ptCurr, p1);
if ~(isfinite(area) && area > 0)
    p1 = [];
    return;
end
p1 = p1 ./ area;
end

function [corrT_all, rmseT_all, corrT_no22, rmseT_no22] = localComputeTangentTest( ...
    phiEmp, deltaS_actual_x, tempsK, currents, ptRobustData, cdfRobust0, ...
    xGrid, Xrows, Speak, kappaVals, maskAllLow, maskNo22, cfg)

% Compute tangent basis in phi-space by bin-local perturbations at each PT current bin.
ptCurr = ptRobustData.currents(:);
nBins = numel(ptCurr);

% Build basis matrix on all_lowT (for fitting); reuse basis for no_22K by refitting.
B_all = NaN(numel(xGrid), nBins);
for j = 1:nBins
    try
        B_all(:, j) = localPhiBasisFromOneBin(j, tempsK, currents, ptRobustData, cdfRobust0, ...
            xGrid, Xrows, Speak, kappaVals, maskAllLow, cfg);
    catch
        % leave NaNs
    end
end

maskX = isfinite(phiEmp(:)) & any(isfinite(B_all), 2);
Dsub = B_all(maskX, :);
phiSub = phiEmp(maskX);
if nnz(maskX) < 10
    corrT_all = NaN; rmseT_all = NaN;
else
    a = pinv(Dsub) * phiSub;
    phiRecon = NaN(numel(xGrid), 1);
    phiRecon(maskX) = Dsub * a;
    phiRecon = localNormalizeToMaxAbs(phiRecon);

    corrT_all = abs(corr(phiEmp(maskX), phiRecon(maskX)));
    rmseT_all = localTangentRmseRatio(phiEmp, phiRecon, deltaS_actual_x, kappaVals, maskAllLow, cfg);
end

% For no_22K we refit using basis vectors computed on the same bin perturbations but
% contracted over no_22K subset.
B_no22 = NaN(numel(xGrid), nBins);
for j = 1:nBins
    try
        B_no22(:, j) = localPhiBasisFromOneBin(j, tempsK, currents, ptRobustData, cdfRobust0, ...
            xGrid, Xrows, Speak, kappaVals, maskNo22, cfg);
    catch
    end
end

maskX2 = isfinite(phiEmp(:)) & any(isfinite(B_no22), 2);
Dsub2 = B_no22(maskX2, :);
phiSub2 = phiEmp(maskX2);
if nnz(maskX2) < 10
    corrT_no22 = NaN; rmseT_no22 = NaN;
else
    a2 = pinv(Dsub2) * phiSub2;
    phiRecon2 = NaN(numel(xGrid), 1);
    phiRecon2(maskX2) = Dsub2 * a2;
    phiRecon2 = localNormalizeToMaxAbs(phiRecon2);

    corrT_no22 = abs(corr(phiEmp(maskX2), phiRecon2(maskX2)));
    rmseT_no22 = localTangentRmseRatio(phiEmp, phiRecon2, deltaS_actual_x, kappaVals, maskNo22, cfg);
end
end

function phiBasis = localPhiBasisFromOneBin( ...
    j, tempsK, currents, ptRobustData, cdfRobust0, xGrid, Xrows, Speak, kappaVals, maskSel, cfg)

nT = numel(tempsK);
nX = numel(xGrid);
phiBasis = NaN(nX, 1);

kappaSel = kappaVals(maskSel);
if nnz(maskSel) < 3
    return;
end

% Precompute base cdf and induced current per T:
idxSel = find(maskSel);
denomK = sum(kappaSel.^2, 'omitnan');
if ~(isfinite(denomK) && denomK > 0)
    return;
end

acc = zeros(nX, 1);
for kk = 1:numel(idxSel)
    it = idxSel(kk);
    T = tempsK(it);
    cdf0 = cdfRobust0(it, :).';
    if any(~isfinite(cdf0))
        continue;
    end

    p0 = localPTpdfAtT(ptRobustData, T);
    if isempty(p0)
        continue;
    end

    % Local perturbation: modify single bin (j) and renormalize
    e = zeros(size(p0));
    if j <= numel(p0)
        e(j) = p0(j);
    else
        continue;
    end
    p1 = max(p0 + cfg.tangentEpsilonRel * e, 0);
    area = trapz(ptRobustData.currents, p1);
    if ~(isfinite(area) && area > 0)
        continue;
    end
    p1 = p1 ./ area;

    cdf1 = localCdfFromPdfOnCurrents(p1, ptRobustData.currents, currents);
    if any(~isfinite(cdf1))
        continue;
    end

    inducedCurrent = Speak(it) * (cdf1(:) - cdf0(:));
    xRow = Xrows(it, :);
    deltaSx = localInterpolateRowToX(xGrid, xRow, inducedCurrent(:).');

    if any(isfinite(deltaSx))
        acc = acc + kappaVals(it) .* deltaSx(:);
    end
end

phiBasis = acc ./ denomK;
end

function rmseRatio = localTangentRmseRatio(phiEmp, phiRecon, deltaS_actual_x, kappaVals, maskSel, cfg)
phiEmp = phiEmp(:);
phiRecon = phiRecon(:);
kappaSel = kappaVals(maskSel);
RactualSel = deltaS_actual_x(maskSel, :);
RhatPred = kappaSel(:) .* phiRecon(:).';
RhatBase = kappaSel(:) .* phiEmp(:).';
rmsePred = localRMSE(RactualSel, RhatPred);
rmseBase = localRMSE(RactualSel, RhatBase);
rmseRatio = rmsePred / max(rmseBase, cfg.epsFloor);
end

function reportText = localBuildReport(phiEmp, phiTbl, kappaTbl, tempsK, ptRunId, decompRunId, ...
    reconSummaryPath, localTangentPath, globalBestCorr, globalBestRmse, localBestCorr, localBestRmse, ...
    xGrid, maskAllLow, maskNo22) %#ok<INUSD>

lines = strings(0, 1);
lines(end+1) = "# Phi from PT restricted deformation (stable runner)";
lines(end+1) = "";
lines(end+1) = "## Inputs";
lines(end+1) = sprintf("- Decomposition run: `%s`", char(decompRunId));
lines(end+1) = sprintf("- PT run: `%s`", char(ptRunId));
lines(end+1) = "";
lines(end+1) = "## Key metrics (no_22K subset)";
lines(end+1) = sprintf("- Global best: corr=%.4f rmse_ratio=%.4g", globalBestCorr, globalBestRmse);
lines(end+1) = sprintf("- Local tangent best: corr=%.4f rmse_ratio=%.4g", localBestCorr, localBestRmse);
lines(end+1) = "";
lines(end+1) = "## Output tables";
lines(end+1) = sprintf("- `%s`", char(reconSummaryPath));
lines(end+1) = sprintf("- `%s`", char(localTangentPath));
reportText = strjoin(lines, newline);
end

function out = localFinalizeWithoutCompute(run, globalVerdict, localVerdict, phiModeVerdict)
out = struct();
out.runDir = string(run.run_dir);
out.globalVerdict = string(globalVerdict);
out.localVerdict = string(localVerdict);
out.phiModeVerdict = string(phiModeVerdict);
end

