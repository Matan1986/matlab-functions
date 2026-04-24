% run_compare_afm_observables_same_dip_stability
% Compare AFM observable stability using the SAME extracted dip trace.
%
% Goal:
%   Rank AFM definitions by sensitivity to:
%   1) FM choice (core / derivative-assisted / robust-baseline)
%   2) additive noise
%   3) windowing (dip_window_K + smoothWindow_K)
%
% Observables (all computed from the same dip trace for each condition):
%   - AFM_amplitude: min(dip)
%   - AFM_area: trapz(T, abs(dip)) in dip window
%   - AFM_RMS: sqrt(mean(dip.^2)) in dip window
%   - AFM_center_minus_edges: mean(center) - mean(edges) from dip window
%     (no extra baseline model)

clearvars;
clc;

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(genpath(fullfile(repoRoot, 'General ver2')));
addpath(genpath(fullfile(repoRoot, 'Tools ver1')));

datasetPath = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane Aging no field high res 60min wait';

outCsv = fullfile(repoRoot, 'scripts', 'afm_observable_stability_same_dip.csv');
perRunCsv = fullfile(repoRoot, 'scripts', 'afm_observable_stability_same_dip_per_run.csv');

fprintf('=== AFM Observable Stability (Same Dip) ===\n');
fprintf('Dataset path: %s\n', datasetPath);

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
fprintf('Loaded pause runs: %d\n', nRuns);

cfgBase = struct();
cfgBase.dip_window_K = 1;
cfgBase.smoothWindow_K = 2;
cfgBase.excludeLowT_FM = false;
cfgBase.excludeLowT_K = -inf;
cfgBase.FM_plateau_K = 6;
cfgBase.excludeLowT_mode = 'pre';
cfgBase.FM_buffer_K = 3;
cfgBase.AFM_metric_main = 'area';
cfgBase.FMConvention = 'leftMinusRight';
cfgBase.doFilterDeltaM = false;

cfgBase.dip_margin_K = 2;
cfgBase.plateau_nPoints = 6;
cfgBase.dropLowestN = 1;
cfgBase.dropHighestN = 0;
cfgBase.plateau_agg = 'median';
cfgBase.FM_plateau_minWidth_K = 1.0;
cfgBase.FM_plateau_minPoints = 12;
cfgBase.FM_plateau_maxAllowedSlope = 0.02;
cfgBase.FM_plateau_allowNarrowFallback = true;

methodNames = {'core direct', 'derivative-assisted', 'robust-baseline'};
nMethods = numel(methodNames);

obsNames = {'AFM_amplitude', 'AFM_area', 'AFM_RMS', 'AFM_center_minus_edges'};
nObs = numel(obsNames);

smoothWindow_K_list = [1, 2, 3, 4];
dip_window_K_list = [0.5, 1, 2];

noise_levels = [0, 0.01, 0.02, 0.05];
nNoiseRealizations = 25;
rng(1);

fmSens = nan(nRuns, nObs);
windowSens = nan(nRuns, nObs);
noiseSens = nan(nRuns, nObs);
waitKVec = nan(nRuns, 1);
validRun = false(nRuns, 1);

for i = 1:nRuns
    if ~isfield(pauseRuns(i), 'T_common') || ~isfield(pauseRuns(i), 'DeltaM')
        continue;
    end

    T = pauseRuns(i).T_common(:);
    dM = pauseRuns(i).DeltaM(:);
    n = min(numel(T), numel(dM));
    T = T(1:n);
    dM = dM(1:n);

    if isfield(pauseRuns(i), 'DeltaM_signed') && ~isempty(pauseRuns(i).DeltaM_signed)
        dM_signed = pauseRuns(i).DeltaM_signed(:);
        dM_signed = dM_signed(1:min(numel(dM_signed), n));
        n = min(n, numel(dM_signed));
        T = T(1:n);
        dM = dM(1:n);
        dM_signed = dM_signed(1:n);
    else
        dM_signed = dM;
    end

    if isfield(pauseRuns(i), 'waitK') && isfinite(pauseRuns(i).waitK)
        Tp = pauseRuns(i).waitK;
    else
        [~, idxMin] = min(dM_signed);
        Tp = T(idxMin);
    end
    waitKVec(i) = Tp;

    finiteMask = isfinite(T) & isfinite(dM) & isfinite(dM_signed);
    T = T(finiteMask);
    dM = dM(finiteMask);
    dM_signed = dM_signed(finiteMask);
    if numel(T) < 50
        continue;
    end

    if all(diff(T) < 0)
        T = flipud(T);
        dM = flipud(dM);
        dM_signed = flipud(dM_signed);
    end
    if ~all(diff(T) > 0)
        [T, idxSort] = sort(T);
        dM = dM(idxSort);
        dM_signed = dM_signed(idxSort);
    end

    % 1) FM-choice sensitivity at baseline config.
    valsFM = nan(nMethods, nObs);
    for m = 1:nMethods
        dip = extractDipByMethod(m, T, dM, dM_signed, Tp, cfgBase);
        valsFM(m, :) = computeObservablesFromDip(T, dip, Tp, cfgBase.dip_window_K);
    end
    fmSens(i, :) = colCV(valsFM);

    % 2) Window sensitivity across methods and window combinations.
    valsW = nan(0, nObs);
    for m = 1:nMethods
        for iS = 1:numel(smoothWindow_K_list)
            for iD = 1:numel(dip_window_K_list)
                cfgW = cfgBase;
                cfgW.smoothWindow_K = smoothWindow_K_list(iS);
                cfgW.dip_window_K = dip_window_K_list(iD);

                dip = extractDipByMethod(m, T, dM, dM_signed, Tp, cfgW);
                obs = computeObservablesFromDip(T, dip, Tp, cfgW.dip_window_K);
                valsW(end + 1, :) = obs; %#ok<SAGROW>
            end
        end
    end
    windowSens(i, :) = colCV(valsW);

    % 3) Noise sensitivity across methods/noise realizations (baseline windows).
    valsN = nan(0, nObs);
    for m = 1:nMethods
        for iL = 1:numel(noise_levels)
            sigma = noise_levels(iL);
            for r = 1:nNoiseRealizations
                noisySigned = dM_signed + sigma * randn(size(dM_signed));
                noisyDeltaM = dM + sigma * randn(size(dM));

                dip = extractDipByMethod(m, T, noisyDeltaM, noisySigned, Tp, cfgBase);
                obs = computeObservablesFromDip(T, dip, Tp, cfgBase.dip_window_K);
                valsN(end + 1, :) = obs; %#ok<SAGROW>
            end
        end
    end
    noiseSens(i, :) = colCV(valsN);

    validRun(i) = true;
    fprintf('Run %d done (waitK=%.3f)\n', i, Tp);
end

validIdx = find(validRun);
if isempty(validIdx)
    error('No valid runs produced finite AFM observable stability metrics.');
end

fmMed = median(fmSens(validIdx, :), 1, 'omitnan');
noiseMed = median(noiseSens(validIdx, :), 1, 'omitnan');
windowMed = median(windowSens(validIdx, :), 1, 'omitnan');
totalScore = fmMed + noiseMed + windowMed;

[~, ord] = sort(totalScore, 'ascend');
rankPos = nan(1, nObs);
for k = 1:nObs
    rankPos(ord(k)) = k;
end

resultTbl = table(obsNames(:), fmMed(:), noiseMed(:), windowMed(:), totalScore(:), rankPos(:), ...
    'VariableNames', {'Observable', 'FM_choice_sensitivity_CV', 'Noise_sensitivity_CV', 'Window_sensitivity_CV', 'Total_sensitivity_score', 'Rank'});
resultTbl = sortrows(resultTbl, 'Total_sensitivity_score', 'ascend');

% Per-run table for transparency.
perRunRows = [];
for ii = 1:numel(validIdx)
    i = validIdx(ii);
    for j = 1:nObs
        row = table(i, waitKVec(i), string(obsNames{j}), fmSens(i, j), noiseSens(i, j), windowSens(i, j), ...
            'VariableNames', {'run_index', 'waitK', 'Observable', 'FM_choice_sensitivity_CV', 'Noise_sensitivity_CV', 'Window_sensitivity_CV'});
        if isempty(perRunRows)
            perRunRows = row;
        else
            perRunRows = [perRunRows; row]; %#ok<AGROW>
        end
    end
end

writetable(resultTbl, outCsv);
writetable(perRunRows, perRunCsv);

fprintf('\n=== AFM Observable Stability Summary (lower is better) ===\n');
disp(resultTbl);
fprintf('Used valid runs: %d / %d\n', numel(validIdx), nRuns);
fprintf('Saved summary CSV: %s\n', outCsv);
fprintf('Saved per-run CSV: %s\n', perRunCsv);

fprintf('Most stable AFM observable: %s\n', string(resultTbl.Observable(1)));

% ---------------- Local functions ----------------
function dip = extractDipByMethod(methodIdx, T, dM, dM_signed, Tp, cfg)
dip = nan(size(T));
try
    switch methodIdx
        case 1 % core direct
            cfgLocal = cfg;
            cfgLocal.useRobustBaseline = false;
            runIn = makeRunStruct(T, dM, dM_signed, Tp);
            out = analyzeAFM_FM_components( ...
                runIn, cfgLocal.dip_window_K, cfgLocal.smoothWindow_K, ...
                cfgLocal.excludeLowT_FM, cfgLocal.excludeLowT_K, ...
                cfgLocal.FM_plateau_K, cfgLocal.excludeLowT_mode, cfgLocal.FM_buffer_K, ...
                cfgLocal.AFM_metric_main, cfgLocal);
            dip = pickDip(out(1), T);

        case 2 % derivative-assisted
            cfgLocal = cfg;
            cfgLocal.agingMetricMode = 'derivative';
            out = analyzeAFM_FM_derivative(T, dM_signed, Tp, cfgLocal);
            dip = pickDip(out, T);

        case 3 % robust-baseline
            cfgLocal = cfg;
            cfgLocal.useRobustBaseline = true;
            runIn = makeRunStruct(T, dM, dM_signed, Tp);
            out = analyzeAFM_FM_components( ...
                runIn, cfgLocal.dip_window_K, cfgLocal.smoothWindow_K, ...
                cfgLocal.excludeLowT_FM, cfgLocal.excludeLowT_K, ...
                cfgLocal.FM_plateau_K, cfgLocal.excludeLowT_mode, cfgLocal.FM_buffer_K, ...
                cfgLocal.AFM_metric_main, cfgLocal);
            dip = pickDip(out(1), T);
    end
catch
    dip = nan(size(T));
end
end

function runIn = makeRunStruct(T, dM, dM_signed, Tp)
runIn = struct();
runIn.T_common = T(:);
runIn.DeltaM = dM(:);
runIn.DeltaM_signed = dM_signed(:);
runIn.waitK = Tp;
end

function dip = pickDip(s, T)
dip = nan(size(T));
if isfield(s, 'dip_signed') && ~isempty(s.dip_signed)
    d = s.dip_signed(:);
    n = min(numel(d), numel(T));
    dip(1:n) = d(1:n);
elseif isfield(s, 'DeltaM_sharp') && ~isempty(s.DeltaM_sharp)
    d = s.DeltaM_sharp(:);
    n = min(numel(d), numel(T));
    dip(1:n) = d(1:n);
end
end

function obs = computeObservablesFromDip(T, dip, Tp, dipWindowK)
obs = nan(1, 4);
if isempty(T) || isempty(dip)
    return;
end
T = T(:);
dip = dip(:);
n = min(numel(T), numel(dip));
T = T(1:n);
dip = dip(1:n);

mask = isfinite(T) & isfinite(dip) & (abs(T - Tp) <= dipWindowK);
if nnz(mask) < 5
    return;
end
x = T(mask);
y = dip(mask);
if numel(x) < 2
    return;
end

% 1) AFM_amplitude (min value)
obs(1) = min(y);

% 2) AFM_area (integral magnitude on same dip support)
obs(2) = trapz(x, abs(y));

% 3) AFM_RMS
obs(3) = sqrt(mean(y.^2, 'omitnan'));

% 4) AFM_center_minus_edges (no extra baseline model)
rel = abs(x - Tp);
centerMask = rel <= 0.33 * dipWindowK;
edgeMask = (rel >= 0.67 * dipWindowK) & (rel <= dipWindowK);
if nnz(centerMask) >= 2 && nnz(edgeMask) >= 2
    obs(4) = mean(y(centerMask), 'omitnan') - mean(y(edgeMask), 'omitnan');
end
end

function cv = colCV(X)
if isempty(X)
    cv = nan(1, 0);
    return;
end
cv = nan(1, size(X, 2));
for j = 1:size(X, 2)
    v = X(:, j);
    v = v(isfinite(v));
    if numel(v) < 2
        cv(j) = NaN;
        continue;
    end
    mu = mean(v, 'omitnan');
    sd = std(v, 0, 'omitnan');
    if abs(mu) <= eps
        cv(j) = NaN;
    else
        cv(j) = sd / abs(mu);
    end
end
end
