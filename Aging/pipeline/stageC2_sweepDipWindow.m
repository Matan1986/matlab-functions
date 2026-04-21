function resultsTable = stageC2_sweepDipWindow(cfg)
% stageC2_sweepDipWindow
% Robustness sweep over dip_window_K with pause-level metrics.

if nargin < 1 || ~isstruct(cfg)
    error(['stageC2_sweepDipWindow requires cfg as input.\n' ...
        'Run it like:\n' ...
        'cfg = agingConfig;\n' ...
        'cfg.dataDir = ''<your data folder>'';\n' ...
        'stageC2_sweepDipWindow(cfg);']);
end

if ~isfield(cfg,'dataDir') || isempty(cfg.dataDir)
    error(['cfg.dataDir is missing.\n' ...
        'Set it exactly as you do before calling Main_Aging.\n' ...
        'Example:\n' ...
        'cfg = agingConfig;\n' ...
        'cfg.dataDir = ''C:\Your\Data\Folder'';']);
end

dipVals = 3:0.5:6;
N = numel(dipVals);

corrC_baseline = nan(N,1);
R2_baseline = nan(N,1);
minCorrC_LOO = nan(N,1);
medianCorrC_LOO = nan(N,1);

nPauses_total = nan(N,1);
nPauses_valid = nan(N,1);
nDipOutside = nan(N,1);
nPlateauFlag = nan(N,1);
nTminOutsideWindow = nan(N,1);

for k = 1:N
    cfgK = cfg;
    cfgK.dip_window_K = dipVals(k);

    if isfield(cfgK, 'switchParams') && isstruct(cfgK.switchParams)
        cfgK.switchParams.dipWindowK = cfgK.dip_window_K;
    end

    cfgK.doPlotting = false;
    cfgK.saveTableMode = 'none';

    cfgK = stage0_setupPaths(cfgK);
    out = stage1_loadData(cfgK);
    out = stage2_preprocess(out, cfgK);
    out = stage3_computeDeltaM(out, cfgK);
    out = stage4_analyzeAFM_FM(out, cfgK);
    out = stage5_fitFMGaussian(out, cfgK);
    out = stage6_extractMetrics(out, cfgK);

    if isfield(cfgK,'switchExcludeTp') && ~isempty(cfgK.switchExcludeTp)
        cfgK.switchParams.switchExcludeTp = cfgK.switchExcludeTp(:);
    else
        cfgK.switchParams.switchExcludeTp = [];
    end

    if isfield(cfgK,'switchExcludeTpAbove') && ~isempty(cfgK.switchExcludeTpAbove)
        cfgK.switchParams.switchExcludeTpAbove = cfgK.switchExcludeTpAbove;
    else
        cfgK.switchParams.switchExcludeTpAbove = [];
    end

    if isfield(cfgK,'autoExcludeDegenerateDip')
        cfgK.switchParams.autoExcludeDegenerateDip = cfgK.autoExcludeDegenerateDip;
    else
        cfgK.switchParams.autoExcludeDegenerateDip = false;
    end

    if isfield(cfgK,'dipSigmaLowerBound')
        cfgK.switchParams.dipSigmaLowerBound = cfgK.dipSigmaLowerBound;
    else
        cfgK.switchParams.dipSigmaLowerBound = 0.4;
    end

    if isfield(cfgK,'dipAreaLowPercentile')
        cfgK.switchParams.dipAreaLowPercentile = cfgK.dipAreaLowPercentile;
    else
        cfgK.switchParams.dipAreaLowPercentile = 5;
    end

    if isfield(cfgK, 'enableStage7') && cfgK.enableStage7
        [result, state] = stage7_reconstructSwitching(out, cfgK);
    else
        continue;
    end

    % --- Extract pause-domain vectors (match stage7 output) ---
    if ~isfield(result,'Tp_pause') || ...
            ~isfield(result,'Rsw_pause') || ...
            ~isfield(result,'C_pause') || ...
            ~isfield(result,'A_pause') || ...
            ~isfield(result,'F_pause')
        error('stage7_reconstructSwitching output does not contain required *_pause fields.');
    end

    Tp  = result.Tp_pause(:);
    Rsw = result.Rsw_pause(:);
    C   = result.C_pause(:);
    A   = result.A_pause(:);
    F   = result.F_pause(:);


    Tp = Tp(:);
    A = A(:);
    F = F(:);
    C = C(:);
    Rsw = Rsw(:);

    nVec = numel(Tp);
    if numel(A) ~= nVec || numel(F) ~= nVec || numel(C) ~= nVec || numel(Rsw) ~= nVec
        error('Pause vectors are not the same length for dip_window_K=%.2f.', cfgK.dip_window_K);
    end

    nPauses_valid(k) = nVec;

    validCR = isfinite(C) & isfinite(Rsw);
    if nnz(validCR) >= 2
        corrC_baseline(k) = corr(C, Rsw, 'rows','complete');
        mdl = fitlm(C(validCR), Rsw(validCR));
        R2_baseline(k) = mdl.Rsquared.Ordinary;
    end

    corrC_loo = nan(nVec,1);
    minPts = 3;
    for i = 1:nVec
        mask = true(nVec,1);
        mask(i) = false;
        valid_i = mask & isfinite(C) & isfinite(Rsw);
        if nnz(valid_i) >= minPts
            corrC_loo(i) = corr(C(mask), Rsw(mask), 'rows','complete');
        end
    end

    minCorrC_LOO(k) = min(corrC_loo, [], 'omitnan');
    medianCorrC_LOO(k) = median(corrC_loo, 'omitnan');

    gf = extractGeomFlags(out, state);
    if ~isempty(gf)
        nPauses_total(k) = numel(gf);
        nDipOutside(k) = countFlag(gf, 'DipOutside');
        nPlateauFlag(k) = countFlag(gf, 'PlateauFlag');
        nTminOutsideWindow(k) = countFlag(gf, 'TminOutsideWindow');
    else
        nPauses_total(k) = nPauses_valid(k);
        nDipOutside(k) = 0;
        nPlateauFlag(k) = 0;
        nTminOutsideWindow(k) = 0;
    end
end

varNames = { ...
    'dip_window_K', ...
    'corrC_baseline', ...
    'R2_baseline', ...
    'minCorrC_LOO', ...
    'medianCorrC_LOO', ...
    'nPauses_total', ...
    'nPauses_valid', ...
    'nDipOutside', ...
    'nPlateauFlag', ...
    'nTminOutsideWindow'};

resultsTable = table( ...
    dipVals(:), ...
    corrC_baseline, ...
    R2_baseline, ...
    minCorrC_LOO, ...
    medianCorrC_LOO, ...
    nPauses_total, ...
    nPauses_valid, ...
    nDipOutside, ...
    nPlateauFlag, ...
    nTminOutsideWindow, ...
    'VariableNames', varNames);

if exist('getResultsDir', 'file') == 2
    outDir = getResultsDir('aging', 'diagnostics_misc');
else
    outDir = fullfile(pwd, 'results');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
end


save(fullfile(outDir, 'C2_dipWindowSweep.mat'), 'resultsTable');
writetable(resultsTable, fullfile(outDir, 'C2_dipWindowSweep.csv'));

end

function n = countFlag(flags, fieldName)
if isempty(flags)
    n = 0;
    return;
end

n = 0;
for i = 1:numel(flags)
    if isfield(flags(i), fieldName) && logical(flags(i).(fieldName))
        n = n + 1;
    end
end
end



function gf = extractGeomFlags(out, state)
gf = [];
if isfield(out, 'diagnostics') && isfield(out.diagnostics, 'geomFlags')
    gf = out.diagnostics.geomFlags;
elseif isfield(state, 'diagnostics') && isfield(state.diagnostics, 'geomFlags')
    gf = state.diagnostics.geomFlags;
elseif isfield(out, 'geomFlags')
    gf = out.geomFlags;
elseif isfield(state, 'geomFlags')
    gf = state.geomFlags;
end
end
