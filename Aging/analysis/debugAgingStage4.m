function state = debugAgingStage4(state, cfg)
% =========================================================
% debugAgingStage4
%
% PURPOSE:
%   Generate debug diagnostics for stage 4 AFM/FM analysis.
%
% INPUTS:
%   state - struct with pauseRuns and pauseRuns_raw
%   cfg   - configuration struct
%
% OUTPUTS:
%   state - updated with debug fields
%
% =========================================================

debugCfg = cfg.debug;
outFolder = resolveDebugOutFolder(cfg, debugCfg);

pauseTp = [state.pauseRuns.waitK];
debugRows = repmat(struct(), 0, 1);
overlayCount = 0;

for i = 1:numel(state.pauseRuns)
    Tp = state.pauseRuns(i).waitK;

    T = getRunVector(state.pauseRuns(i), 'T_common');
    if isempty(T)
        T = getRunVector(state.pauseRuns(i), 'T');
    end

    dM_filt = getRunVector(state.pauseRuns(i), 'DeltaM');
    dM_raw = dM_filt;
    if isfield(state, 'pauseRuns_raw') && numel(state.pauseRuns_raw) >= i
        dM_raw = getRunVector(state.pauseRuns_raw(i), 'DeltaM');
    end

    if isempty(T) || isempty(dM_filt)
        continue;
    end

    windows = buildDebugWindows(Tp, cfg, debugCfg, T, state.pauseRuns(i));

    [dipDepth_raw, dipArea_raw] = computeDipMetrics(T, dM_raw, windows.dip);
    [dipDepth_filt, dipArea_filt] = computeDipMetrics(T, dM_filt, windows.dip);

    metrics = struct();
    metrics.dipDepth_raw = dipDepth_raw;
    metrics.dipArea_raw = dipArea_raw;
    metrics.dipDepth_filt = dipDepth_filt;
    metrics.dipArea_filt = dipArea_filt;
    metrics.fmStep = getFieldOrNaN(state.pauseRuns(i), 'FM_step_mag');
    metrics.dipSigma = getFieldOrNaN(state.pauseRuns(i), 'Dip_sigma');
    metrics.dipFitArea = getFieldOrNaN(state.pauseRuns(i), 'Dip_area');

    meta = struct();
    if isfield(cfg, 'sample_name')
        meta.sampleName = cfg.sample_name;
    end
    if isfield(state.pauseRuns(i), 'label')
        meta.pauseLabel = state.pauseRuns(i).label;
    end
    if isfield(state.pauseRuns(i), 'file')
        meta.sourceFile = state.pauseRuns(i).file;
    end

    dbg = debugAgingDiagnostics(cfg, Tp, T, dM_raw, dM_filt, windows, metrics, meta);
    
    % Safe field-aligned struct append
    if isempty(debugRows)
        debugRows = dbg.row;
    else
        % Align fields before appending
        f1 = fieldnames(debugRows);
        f2 = fieldnames(dbg.row);
        
        missingInRows = setdiff(f2, f1);
        missingInDbg  = setdiff(f1, f2);
        
        % Add missing fields to debugRows
        for k = 1:numel(missingInRows)
            field = missingInRows{k};
            [debugRows.(field)] = deal(NaN);
        end
        
        % Add missing fields to dbg.row
        for k = 1:numel(missingInDbg)
            field = missingInDbg{k};
            dbg.row.(field) = NaN;
        end
        
        debugRows(end+1) = dbg.row; %#ok<AGROW>
    end

    if debugCfg.makeWindowOverlayPlots
        if shouldPlotTp(Tp, debugCfg.selectedTp) && overlayCount < debugCfg.maxOverlayPauses
            overlayCount = overlayCount + 1;
            if debugCfg.saveOutputs
                makeOverlayPlot(cfg, debugCfg, Tp, T, dM_raw, dM_filt, windows, metrics, dbg, outFolder);
            end
        end
    end
end

if ~isempty(debugRows)
    debugTable = struct2table(debugRows, 'AsArray', true);
else
    debugTable = table();
end

state.debug = struct();
state.debug.debugTable = debugTable;
state.debug.outFolder = outFolder;

if debugCfg.dumpTables && debugCfg.saveOutputs && ~isempty(outFolder)
    writetable(debugTable, fullfile(outFolder, 'debug_metrics.csv'));
    cfg_snapshot = cfg;
    save(fullfile(outFolder, 'debug_metrics.mat'), 'debugTable', 'cfg_snapshot');
end

if debugCfg.saveOutputs && ~isempty(outFolder)
    if debugCfg.makeRawVsFilteredPlots
        makeFilterImpactPlot(debugTable, debugCfg, outFolder);
    end
    if debugCfg.makeSummaryPlots
        makeSNRPlot(debugTable, debugCfg, outFolder);
        makeFitSummaryPlot(debugTable, cfg, debugCfg, outFolder);
    end
end

if debugCfg.logToFile && debugCfg.saveOutputs && ~isempty(outFolder)
    writeDebugLog(debugTable, cfg, debugCfg, outFolder, pauseTp);
end

% --- Console summary ---
printStage4DiagnosticSummary(debugRows);

end

% ====================== Local helper functions ======================

function outFolder = resolveDebugOutFolder(cfg, debugCfg)
outFolder = '';
if ~isfield(debugCfg, 'saveOutputs') || ~debugCfg.saveOutputs
    return;
end

if isfield(debugCfg, 'outFolder') && ~isempty(debugCfg.outFolder)
    outFolder = debugCfg.outFolder;
else
    runTag = debugCfg.runTag;
    if isempty(runTag)
        runTag = datestr(now, 'yyyymmdd_HHMMSS');
    end
    outputRoot = debugCfg.outputRoot;
    if isempty(outputRoot)
        outputRoot = getResultsDir('aging', 'debug_runs');
    end
    outFolder = fullfile(outputRoot, runTag);
end

if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end
end

function windows = buildDebugWindows(Tp, cfg, debugCfg, T, pauseRun)
% Build debug windows using persisted stage4 pipeline plateau state.

T = T(:);
if nargin < 5 || ~isstruct(pauseRun)
    pauseRun = struct();
end

if isempty(T)
    windows = struct();
    windows.dip = [Tp - cfg.dip_window_K, Tp + cfg.dip_window_K];
    windows.baseL = [NaN NaN];
    windows.baseR = [NaN NaN];
    windows.noise = [NaN NaN];
    windows.fmPlateauL = [NaN NaN];
    windows.fmPlateauR = [NaN NaN];
    windows.fmMaskL = false(size(T));
    windows.fmMaskR = false(size(T));
    return;
end

dip = [Tp - cfg.dip_window_K, Tp + cfg.dip_window_K];
maskL = false(size(T));
maskR = false(size(T));
if isfield(pauseRun, 'FM_plateau_mask_left') && ~isempty(pauseRun.FM_plateau_mask_left)
    tmp = logical(pauseRun.FM_plateau_mask_left(:));
    if numel(tmp) == numel(T)
        maskL = tmp;
    end
end
if isfield(pauseRun, 'FM_plateau_mask_right') && ~isempty(pauseRun.FM_plateau_mask_right)
    tmp = logical(pauseRun.FM_plateau_mask_right(:));
    if numel(tmp) == numel(T)
        maskR = tmp;
    end
end

if isfield(pauseRun, 'FM_plateau_left_window') && numel(pauseRun.FM_plateau_left_window) == 2
    fmL = pauseRun.FM_plateau_left_window(:).';
else
    fmL = [NaN NaN];
end
if isfield(pauseRun, 'FM_plateau_right_window') && numel(pauseRun.FM_plateau_right_window) == 2
    fmR = pauseRun.FM_plateau_right_window(:).';
else
    fmR = [NaN NaN];
end
if ~any(maskL)
    fmL = [NaN NaN];
end
if ~any(maskR)
    fmR = [NaN NaN];
end
baseL = fmL;
baseR = fmR;

% Noise window
noise = resolveNoiseWindow(T, debugCfg);

% Verbose diagnostics
if isfield(debugCfg, 'verbose') && debugCfg.verbose
    fprintf('\nDebug plateau windows from pipeline [Tp=%.4g K]:\n', Tp);
    fprintf('  Plateau_L: T=[%.4g,%.4g] K (n=%d points)\n', ...
        fmL(1), fmL(2), nnz(maskL));
    fprintf('  Plateau_R: T=[%.4g,%.4g] K (n=%d points)\n', ...
        fmR(1), fmR(2), nnz(maskR));
end

windows = struct();
windows.dip = dip;
windows.baseL = baseL;
windows.baseR = baseR;
windows.noise = noise;
windows.fmPlateauL = fmL;
windows.fmPlateauR = fmR;
windows.fmMaskL = maskL;
windows.fmMaskR = maskR;
end

function win = resolveNoiseWindow(T, debugCfg)
T = T(:);
finiteT = T(isfinite(T));
if isempty(finiteT)
    win = [NaN NaN];
    return;
end

Tmin = min(finiteT);
Tmax = max(finiteT);

mode = lower(string(debugCfg.noiseWindowMode));
if mode == "hight"
    winReq = debugCfg.noiseWindowHighT;
    win = [max(Tmin, winReq(1)), min(Tmax, winReq(2))];
    if win(2) <= win(1)
        mode = "tail";
    end
end

if mode == "tail"
    tailK = debugCfg.noiseWindowTailK;
    win = [max(Tmin, Tmax - tailK), Tmax];
end
end

function [dipDepth, dipArea] = computeDipMetrics(T, dM, dipWindow)
% Compute dip depth and area with optional baseline subtraction
% 
% Usage:
%   [dipDepth, dipArea] = computeDipMetrics(T, dM, dipWindow)
%   [dipDepth, dipArea] = computeDipMetrics(T, dM, dipWindow, baseline)

T = T(:);
dM = dM(:);
if isempty(T) || isempty(dM) || numel(T) ~= numel(dM)
    dipDepth = NaN;
    dipArea = NaN;
    return;
end

lo = min(dipWindow);
hi = max(dipWindow);
mask = isfinite(T) & isfinite(dM) & (T >= lo) & (T <= hi);
if nnz(mask) < 3
    dipDepth = NaN;
    dipArea = NaN;
    return;
end

dMwin = dM(mask);
Twin = T(mask);

% Compute basic metrics from data as-provided
dipDepth = -min(dMwin);
y = max(0, -dMwin);
dipArea = trapz(Twin, y);
end

function val = getFieldOrNaN(s, fieldName)
if isfield(s, fieldName)
    val = s.(fieldName);
else
    val = NaN;
end
end

function v = getRunVector(s, fieldName)
v = [];
if isfield(s, fieldName)
    v = s.(fieldName);
end
end

function tf = shouldPlotTp(Tp, selectedTp)
if isempty(selectedTp)
    tf = true;
else
    tf = any(abs(Tp - selectedTp(:)') < 1e-9);
end
end

function makeOverlayPlot(cfg, debugCfg, Tp, T, dM_raw, dM_filt, windows, metrics, dbg, outFolder)
fig = figure('Visible','off', 'Color','w');
ax = axes(fig); hold(ax, 'on');

plot(ax, T, dM_raw, '-', 'LineWidth', 1.0, 'Color', [0.4 0.4 0.4]);
plot(ax, T, dM_filt, '-', 'LineWidth', 2.0, 'Color', [0 0 0]);

addWindowPatch(ax, windows.dip, [0.9 0.7 0.7]);
addWindowPatch(ax, windows.baseL, [0.7 0.8 0.9]);
addWindowPatch(ax, windows.baseR, [0.7 0.8 0.9]);
addWindowPatch(ax, windows.noise, [0.9 0.9 0.7]);
addMaskPatch(ax, T, windows.fmMaskL, [0.8 0.9 0.8]);
addMaskPatch(ax, T, windows.fmMaskR, [0.8 0.9 0.8]);

xline(ax, Tp, 'r--', 'LineWidth', 1.2);
if debugCfg.overlayShowTc
    xline(ax, debugCfg.Tc, 'b--', 'LineWidth', 1.0);
end

title(ax, sprintf('Tp = %.2f K', Tp));
xlabel(ax, 'T (K)');
ylabel(ax, 'DeltaM');

infoText = sprintf(['depth raw/filt: %.3g / %.3g\n' ...
    'area raw/filt: %.3g / %.3g\n' ...
    'SNR raw/filt: %.2f / %.2f'], ...
    metrics.dipDepth_raw, metrics.dipDepth_filt, ...
    metrics.dipArea_raw, metrics.dipArea_filt, ...
    dbg.SNR_depth_raw, dbg.SNR_depth_filt);

flagText = flagsToText(dbg.flags);
text(ax, 0.02, 0.98, infoText, 'Units','normalized', ...
    'VerticalAlignment','top', 'FontSize', 10, 'BackgroundColor', 'w');
if ~isempty(flagText)
    text(ax, 0.02, 0.78, flagText, 'Units','normalized', ...
        'VerticalAlignment','top', 'FontSize', 10, 'Color', [0.8 0 0]);
end

fileName = sprintf('overlay_Tp_%g.png', Tp);
saveas(fig, fullfile(outFolder, fileName));
close(fig);
end

function addWindowPatch(ax, win, color)
if isempty(win) || numel(win) ~= 2 || any(~isfinite(win))
    return;
end
lo = min(win); hi = max(win);
yl = ylim(ax);
patch(ax, [lo hi hi lo], [yl(1) yl(1) yl(2) yl(2)], color, ...
    'FaceAlpha', 0.15, 'EdgeColor', 'none');
end

function addMaskPatch(ax, T, mask, color)
if isempty(mask) || isempty(T)
    return;
end
mask = logical(mask(:));
T = T(:);
if numel(mask) ~= numel(T) || ~any(mask)
    return;
end
idx = find(mask);
breaks = [1; find(diff(idx) > 1) + 1];
for k = 1:numel(breaks)
    iStart = idx(breaks(k));
    if k < numel(breaks)
        iEnd = idx(breaks(k + 1) - 1);
    else
        iEnd = idx(end);
    end
    addWindowPatch(ax, [T(iStart), T(iEnd)], color);
end
end

function txt = flagsToText(flags)
txt = '';
if flags.dipWindowOutOfBounds
    txt = [txt 'DIP_OOB '];
end
if flags.baselineOutOfBounds
    txt = [txt 'BASE_OOB '];
end
if flags.noiseWindowOutOfBounds
    txt = [txt 'NOISE_OOB '];
end
if flags.baselineOverlapsDip
    txt = [txt 'BASE_OVERLAP '];
end
if flags.fmPlateauOverlapsDip
    txt = [txt 'FM_OVERLAP '];
end
if flags.filterImpactLarge
    txt = [txt 'FILTER_IMPACT '];
end
if flags.lowSNR
    txt = [txt 'LOW_SNR '];
end
if flags.suspiciousSpike
    txt = [txt 'SPIKE '];
end
txt = strtrim(txt);
end

function makeFilterImpactPlot(debugTable, debugCfg, outFolder)
if isempty(debugTable) || ~ismember('Tp', debugTable.Properties.VariableNames)
    return;
end
Tp = debugTable.Tp;
rawDepth = debugTable.dipDepth_raw;
filtDepth = debugTable.dipDepth_filt;
rawArea = debugTable.dipArea_raw;
filtArea = debugTable.dipArea_filt;

pctDepth = 100 * (filtDepth - rawDepth) ./ (rawDepth + eps);
pctArea = 100 * (filtArea - rawArea) ./ (rawArea + eps);

fig = figure('Visible','off', 'Color','w');
ax = axes(fig); hold(ax, 'on');
plot(ax, Tp, pctDepth, '-o', 'LineWidth', 1.5);
plot(ax, Tp, pctArea, '-o', 'LineWidth', 1.5);
yline(ax, debugCfg.filterImpactWarnPct, 'r--');
yline(ax, -debugCfg.filterImpactWarnPct, 'r--');
xlabel(ax, 'Tp (K)');
ylabel(ax, 'Percent change (filt vs raw)');
legend(ax, 'Dip depth', 'Dip area', 'Location', 'best');
title(ax, 'Filter impact on dip metrics');
saveas(fig, fullfile(outFolder, 'summary_filter_impact.png'));
close(fig);
end

function makeSNRPlot(debugTable, debugCfg, outFolder)
if isempty(debugTable) || ~ismember('Tp', debugTable.Properties.VariableNames)
    return;
end
Tp = debugTable.Tp;
snrRaw = debugTable.SNR_depth_raw;
snrFilt = debugTable.SNR_depth_filt;

fig = figure('Visible','off', 'Color','w');
ax = axes(fig); hold(ax, 'on');
plot(ax, Tp, snrRaw, '-o', 'LineWidth', 1.5);
plot(ax, Tp, snrFilt, '-o', 'LineWidth', 1.5);
xlabel(ax, 'Tp (K)');
ylabel(ax, 'SNR (depth/noise)');
legend(ax, 'Raw', 'Filtered', 'Location', 'best');
title(ax, 'SNR vs Tp');
saveas(fig, fullfile(outFolder, 'summary_snr.png'));
close(fig);
end

function makeFitSummaryPlot(debugTable, cfg, debugCfg, outFolder)
if isempty(debugTable)
    return;
end
vars = debugTable.Properties.VariableNames;
if ~ismember('dipSigma', vars) || ~ismember('dipFitArea', vars)
    return;
end
if all(isnan(debugTable.dipSigma)) && all(isnan(debugTable.dipFitArea))
    return;
end

Tp = debugTable.Tp;
sigma = debugTable.dipSigma;
area = debugTable.dipFitArea;

fig = figure('Visible','off', 'Color','w');
ax = axes(fig); hold(ax, 'on');
yyaxis(ax, 'left');
plot(ax, Tp, sigma, '-o', 'LineWidth', 1.5);
yline(ax, cfg.dipSigmaLowerBound, 'r--');
ylabel(ax, 'Dip sigma');
yyaxis(ax, 'right');
plot(ax, Tp, area, '-s', 'LineWidth', 1.5);
ylabel(ax, 'Dip fit area');
xlabel(ax, 'Tp (K)');
title(ax, 'Fit degeneracy check');
saveas(fig, fullfile(outFolder, 'summary_fit_degeneracy.png'));
close(fig);
end

function printStage4DiagnosticSummary(debugRows)
if isempty(debugRows)
    return;
end

fprintf('\n---- PHASE B AGING DIAGNOSTICS ----\n');

countDipOutside = 0;
countPlateauFlag = 0;

for i = 1:numel(debugRows)
    row = debugRows(i);
    
    dipOut = 0;
    if isfield(row, 'flag_dipMinOutsideWindow')
        dipOut = double(row.flag_dipMinOutsideWindow);
    end
    
    dipNear = 0;
    if isfield(row, 'flag_dipMinTooCloseToBoundary')
        dipNear = double(row.flag_dipMinTooCloseToBoundary);
    end
    
    slopeL = 0;
    if isfield(row, 'plateau_slope_L') && isfinite(row.plateau_slope_L)
        slopeL = row.plateau_slope_L;
    end
    
    slopeR = 0;
    if isfield(row, 'plateau_slope_R') && isfinite(row.plateau_slope_R)
        slopeR = row.plateau_slope_R;
    end
    
    R2L = 0;
    if isfield(row, 'plateau_R2_L') && isfinite(row.plateau_R2_L)
        R2L = row.plateau_R2_L;
    end
    
    R2R = 0;
    if isfield(row, 'plateau_R2_R') && isfinite(row.plateau_R2_R)
        R2R = row.plateau_R2_R;
    end
    
    N_L = 0;
    if isfield(row, 'plateau_N_L')
        N_L = row.plateau_N_L;
    end
    
    N_R = 0;
    if isfield(row, 'plateau_N_R')
        N_R = row.plateau_N_R;
    end
    
    stdL = 0;
    if isfield(row, 'plateau_std_L') && isfinite(row.plateau_std_L)
        stdL = row.plateau_std_L;
    end
    
    stdR = 0;
    if isfield(row, 'plateau_std_R') && isfinite(row.plateau_std_R)
        stdR = row.plateau_std_R;
    end
    
    plateauFlag = 0;
    if isfield(row, 'flag_plateauSlopeExcessive')
        plateauFlag = double(row.flag_plateauSlopeExcessive);
    end
    
    Tp_val = row.Tp;
    
    fprintf('Tp=%.1f K | DipOutside=%d | DipNearBoundary=%d | SlopeL=%.3e | SlopeR=%.3e | R2L=%.3f | R2R=%.3f | N_L=%d | N_R=%d | stdL=%.3e | stdR=%.3e | PlateauFlag=%d\n', ...
        Tp_val, dipOut, dipNear, slopeL, slopeR, R2L, R2R, N_L, N_R, stdL, stdR, plateauFlag);
    
    countDipOutside = countDipOutside + dipOut;
    countPlateauFlag = countPlateauFlag + plateauFlag;
end

fprintf('\nTotal DipOutside count: %d\n', countDipOutside);
fprintf('Total PlateauFlag count: %d\n', countPlateauFlag);
fprintf('------------------------------------\n\n');
end

function writeDebugLog(debugTable, cfg, debugCfg, outFolder, pauseTp)
logPath = fullfile(outFolder, 'log.txt');
fid = fopen(logPath, 'w');
if fid < 0
    return;
end

fprintf(fid, 'Diagnostics log\n');
fprintf(fid, 'dip_window_K = %.3f\n', cfg.dip_window_K);
fprintf(fid, 'FM_buffer_K = %.3f\n', cfg.FM_buffer_K);
fprintf(fid, 'FM_plateau_K = %.3f\n', cfg.FM_plateau_K);
fprintf(fid, 'doFilterDeltaM = %d\n', cfg.doFilterDeltaM);
fprintf(fid, 'filterMethod = %s\n', cfg.filterMethod);
fprintf(fid, 'sgolayOrder = %d\n', cfg.sgolayOrder);
fprintf(fid, 'sgolayFrame = %d\n', cfg.sgolayFrame);
fprintf(fid, 'pauseTpList = %s\n', mat2str(pauseTp(:)'));

if ~isempty(debugTable)
    flagNames = { ...
        'flag_dipWindowOutOfBounds', ...
        'flag_baselineOutOfBounds', ...
        'flag_noiseWindowOutOfBounds', ...
        'flag_baselineOverlapsDip', ...
        'flag_fmPlateauOverlapsDip', ...
        'flag_filterImpactLarge', ...
        'flag_lowSNR', ...
        'flag_suspiciousSpike'};
    for k = 1:numel(flagNames)
        if ismember(flagNames{k}, debugTable.Properties.VariableNames)
            count = nnz(debugTable.(flagNames{k}));
            fprintf(fid, '%s = %d\n', flagNames{k}, count);
        end
    end

    if ismember('Tp', debugTable.Properties.VariableNames)
        tpFilter = debugTable.Tp(debugTable.flag_filterImpactLarge);
        if ~isempty(tpFilter)
            fprintf(fid, 'Tp_filterImpactLarge = %s\n', mat2str(tpFilter(:)'));
        end
        tpOverlap = debugTable.Tp(debugTable.flag_baselineOverlapsDip | debugTable.flag_fmPlateauOverlapsDip);
        if ~isempty(tpOverlap)
            fprintf(fid, 'Tp_overlap = %s\n', mat2str(tpOverlap(:)'));
        end
        tpOob = debugTable.Tp(debugTable.flag_dipWindowOutOfBounds | debugTable.flag_baselineOutOfBounds | debugTable.flag_noiseWindowOutOfBounds);
        if ~isempty(tpOob)
            fprintf(fid, 'Tp_outOfBounds = %s\n', mat2str(tpOob(:)'));
        end
    end
end

fclose(fid);
end

