% run_pipeline_compare_direct_stability
% Pipeline-based execution for compare_direct_method_stability.m
% Uses existing Aging stage pipeline only (no manual DeltaM construction).

clearvars;
clc;

logPath = 'c:\Dev\matlab-functions\scripts\pipeline_compare_run.log';
statusPath = 'c:\Dev\matlab-functions\scripts\pipeline_compare_status.txt';
if exist(logPath, 'file') == 2
    delete(logPath);
end
if exist(statusPath, 'file') == 2
    delete(statusPath);
end
diary(logPath);
fprintf('Run started: %s\n', datestr(now, 31));

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(genpath(fullfile(repoRoot, 'General ver2')));
addpath(genpath(fullfile(repoRoot, 'Tools ver1')));

datasetPath = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane Aging no field high res 60min wait';

fprintf('=== Pipeline Load (Stage0-Stage3) ===\n');
fprintf('Dataset path: %s\n', datasetPath);

try
    cfg = agingConfig('MG119_60min');
    cfg.dataDir = datasetPath;
    cfg.doPlotting = false;
    cfg.saveTableMode = 'none';
    cfg.doFilterDeltaM = true;
    cfg.alignDeltaM = false;
    if isfield(cfg, 'debug') && isstruct(cfg.debug)
        cfg.debug.enable = false;
        cfg.debug.plotGeometry = false;
        cfg.debug.plotSwitching = false;
        cfg.debug.saveOutputs = false;
    end

    cfg = stage0_setupPaths(cfg);
    state = stage1_loadData(cfg);
    state = stage2_preprocess(state, cfg);
    state = stage3_computeDeltaM(state, cfg);

pauseRuns = state.pauseRuns;
nRuns = numel(pauseRuns);

fprintf('Loaded pauseRuns count: %d\n', nRuns);

% Print run-level data summary
validCandidates = false(nRuns, 1);
score = -inf(nRuns, 1);
waitKList = nan(nRuns, 1);

for i = 1:nRuns
    hasCore = isfield(pauseRuns(i), 'T_common') && isfield(pauseRuns(i), 'DeltaM');
    if ~hasCore
        continue;
    end

    T_i = pauseRuns(i).T_common(:);
    dM_i = pauseRuns(i).DeltaM(:);
    n_i = min(numel(T_i), numel(dM_i));
    if n_i < 50
        continue;
    end

    T_i = T_i(1:n_i);
    dM_i = dM_i(1:n_i);
    finiteMask = isfinite(T_i) & isfinite(dM_i);
    nFinite = nnz(finiteMask);
    if nFinite < 50
        continue;
    end

    T_v = T_i(finiteMask);
    dM_v = dM_i(finiteMask);
    if numel(T_v) < 50
        continue;
    end

    dT = diff(T_v);
    monotonic = all(dT > 0) || all(dT < 0);
    if ~monotonic
        continue;
    end

    % Prefer runs with many finite points and moderate waitK near median.
    if isfield(pauseRuns(i), 'waitK') && isfinite(pauseRuns(i).waitK)
        waitKList(i) = pauseRuns(i).waitK;
    end

    noiseProxy = std(diff(dM_v), 'omitnan');
    score(i) = nFinite - 100 * noiseProxy;
    validCandidates(i) = true;

    hasSigned = isfield(pauseRuns(i), 'DeltaM_signed') && ~isempty(pauseRuns(i).DeltaM_signed);
    fprintf('Run %3d | waitK=%7.3f K | T=[%7.3f,%7.3f] | n=%4d | DeltaM finite=%4d | DeltaM_signed=%d\n', ...
        i, waitKList(i), min(T_v), max(T_v), n_i, nFinite, hasSigned);
end

if ~any(validCandidates)
    error('No valid pauseRuns candidates after pipeline load checks.');
end

% Bias selection toward central waitK (avoid edge runs), then best score.
validIdx = find(validCandidates);
validWait = waitKList(validIdx);
medWait = median(validWait(isfinite(validWait)), 'omitnan');
if ~isfinite(medWait)
    medWait = 22;
end
centralPenalty = abs(waitKList - medWait);
combined = score - 2 * centralPenalty;
combined(~validCandidates) = -inf;
[~, selectedIdx] = max(combined);

fprintf('\n=== Representative Run Selection ===\n');
fprintf('Selected run index: %d\n', selectedIdx);
fprintf('Selected waitK / Tp: %.6f K\n', pauseRuns(selectedIdx).waitK);

% Prepare workspace variables expected by compare_direct_method_stability.m
T = pauseRuns(selectedIdx).T_common(:);
DeltaM = pauseRuns(selectedIdx).DeltaM(:);
if isfield(pauseRuns(selectedIdx), 'DeltaM_signed') && ~isempty(pauseRuns(selectedIdx).DeltaM_signed)
    DeltaM_signed = pauseRuns(selectedIdx).DeltaM_signed(:);
end
waitK = pauseRuns(selectedIdx).waitK;

% Ensure monotonic ascending for consistency
if all(diff(T) < 0)
    T = flipud(T);
    DeltaM = flipud(DeltaM);
    if exist('DeltaM_signed', 'var')
        DeltaM_signed = flipud(DeltaM_signed);
    end
end

fprintf('Representative run summary:\n');
fprintf('T range: [%.6f, %.6f] K\n', min(T), max(T));
fprintf('DeltaM size: %d\n', numel(DeltaM));

% Attempt run; if NaN metrics, retry on next-best candidate
sortedCandidates = validIdx(:);
[~, order] = sort(combined(sortedCandidates), 'descend');
sortedCandidates = sortedCandidates(order);

success = false;
selectedFinal = NaN;

for k = 1:numel(sortedCandidates)
    idx = sortedCandidates(k);

    T = pauseRuns(idx).T_common(:);
    DeltaM = pauseRuns(idx).DeltaM(:);
    clear DeltaM_signed;
    if isfield(pauseRuns(idx), 'DeltaM_signed') && ~isempty(pauseRuns(idx).DeltaM_signed)
        DeltaM_signed = pauseRuns(idx).DeltaM_signed(:);
    end
    waitK = pauseRuns(idx).waitK;

    if all(diff(T) < 0)
        T = flipud(T);
        DeltaM = flipud(DeltaM);
        if exist('DeltaM_signed', 'var')
            DeltaM_signed = flipud(DeltaM_signed);
        end
    end

    fprintf('\n=== Running Stability Script (candidate %d: run index %d, waitK=%.6f K) ===\n', ...
        k, idx, waitK);

    run(fullfile(repoRoot, 'scripts', 'compare_direct_method_stability.m'));

    requiredVars = {'summaryTbl','AFM_param_var','AFM_noise_var','FM_param_var','FM_noise_var'};
    hasAll = all(cellfun(@(v) exist(v, 'var') == 1, requiredVars));
    if ~hasAll
        fprintf('Candidate %d failed: script outputs missing.\n', k);
        continue;
    end

    metrics = [AFM_param_var(:); AFM_noise_var(:); FM_param_var(:); FM_noise_var(:)];
    if all(isfinite(metrics))
        success = true;
        selectedFinal = idx;
        break;
    end

    fprintf('Candidate %d has NaN metrics; trying next candidate.\n', k);
end

if ~success
    error('No candidate run produced fully finite final metrics.');
end

fprintf('\n=== Final Selected Run ===\n');
fprintf('Run index: %d\n', selectedFinal);
fprintf('waitK / Tp: %.6f K\n', pauseRuns(selectedFinal).waitK);

% Sort output by AFM_param_var ascending (required)
sortedTbl = sortrows(summaryTbl, 'AFM_param_var', 'ascend');

fprintf('\n=== Stability Summary (Sorted by AFM_param_var) ===\n');
disp(sortedTbl);

% Most stable AFM/FM methods from script scores
afmScore = AFM_param_var + AFM_noise_var;
fmScore = FM_param_var + FM_noise_var;
[~, idxAFM] = min(afmScore);
[~, idxFM] = min(fmScore);

fprintf('Most stable AFM method = %s\n', Method{idxAFM});
fprintf('Most stable FM method = %s\n', Method{idxFM});

% Sanity check: dip consistency between methods
cfgBaseCheck = struct();
cfgBaseCheck.dip_window_K = 1;
cfgBaseCheck.smoothWindow_K = 2;
cfgBaseCheck.excludeLowT_FM = false;
cfgBaseCheck.excludeLowT_K = -inf;
cfgBaseCheck.FM_plateau_K = 6;
cfgBaseCheck.excludeLowT_mode = 'pre';
cfgBaseCheck.FM_buffer_K = 3;
cfgBaseCheck.AFM_metric_main = 'area';
cfgBaseCheck.FMConvention = 'leftMinusRight';
cfgBaseCheck.doFilterDeltaM = false;
cfgBaseCheck.useRobustBaseline = false;

runIn = struct('T_common', T, 'DeltaM', DeltaM, 'waitK', waitK);
if exist('DeltaM_signed', 'var') && ~isempty(DeltaM_signed)
    runIn.DeltaM_signed = DeltaM_signed;
end

coreOut = analyzeAFM_FM_components( ...
    runIn, cfgBaseCheck.dip_window_K, cfgBaseCheck.smoothWindow_K, ...
    cfgBaseCheck.excludeLowT_FM, cfgBaseCheck.excludeLowT_K, ...
    cfgBaseCheck.FM_plateau_K, cfgBaseCheck.excludeLowT_mode, cfgBaseCheck.FM_buffer_K, ...
    cfgBaseCheck.AFM_metric_main, cfgBaseCheck);

derOut = analyzeAFM_FM_derivative(T, DeltaM, waitK, cfgBaseCheck);

cfgBaseCheck.useRobustBaseline = true;
robOut = analyzeAFM_FM_components( ...
    runIn, cfgBaseCheck.dip_window_K, cfgBaseCheck.smoothWindow_K, ...
    cfgBaseCheck.excludeLowT_FM, cfgBaseCheck.excludeLowT_K, ...
    cfgBaseCheck.FM_plateau_K, cfgBaseCheck.excludeLowT_mode, cfgBaseCheck.FM_buffer_K, ...
    cfgBaseCheck.AFM_metric_main, cfgBaseCheck);

if isfield(coreOut, 'dip_signed') && isfield(derOut, 'dip_signed') && isfield(robOut, 'dip_signed')
    d1 = coreOut.dip_signed(:);
    d2 = derOut.dip_signed(:);
    d3 = robOut.dip_signed(:);
    n = min([numel(d1), numel(d2), numel(d3)]);
    d1 = d1(1:n); d2 = d2(1:n); d3 = d3(1:n);
    rmse12 = sqrt(mean((d1 - d2).^2, 'omitnan'));
    rmse13 = sqrt(mean((d1 - d3).^2, 'omitnan'));
    rmse23 = sqrt(mean((d2 - d3).^2, 'omitnan'));
    dipPass = all(isfinite([rmse12 rmse13 rmse23])) && max([rmse12 rmse13 rmse23]) < 1e-9;
else
    dipPass = false;
    rmse12 = NaN; rmse13 = NaN; rmse23 = NaN;
end

fprintf('Dip RMSE core-deriv = %.3e, core-robust = %.3e, deriv-robust = %.3e\n', rmse12, rmse13, rmse23);
if dipPass
    fprintf('Dip consistency = PASS\n');
else
    fprintf('Dip consistency = FAIL\n');
end

% Save machine-readable result table
    outCsv = fullfile(repoRoot, 'scripts', 'direct_method_stability_results_pipeline.csv');
    writetable(sortedTbl, outCsv);
    fprintf('Saved results CSV: %s\n', outCsv);

    fid = fopen(statusPath, 'w');
    if fid ~= -1
        fprintf(fid, 'SUCCESS\n');
        fprintf(fid, 'Run index: %d\n', selectedFinal);
        fprintf(fid, 'waitK: %.6f\n', pauseRuns(selectedFinal).waitK);
        fclose(fid);
    end
catch ME
    fprintf('\nERROR: %s\n', ME.message);
    for s = 1:numel(ME.stack)
        fprintf('  at %s (line %d)\n', ME.stack(s).name, ME.stack(s).line);
    end
    fid = fopen(statusPath, 'w');
    if fid ~= -1
        fprintf(fid, 'ERROR\n');
        fprintf(fid, '%s\n', ME.message);
        fclose(fid);
    end
    rethrow(ME);
end

fprintf('Run finished: %s\n', datestr(now, 31));
diary off;
