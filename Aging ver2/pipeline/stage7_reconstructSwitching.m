function [result, state] = stage7_reconstructSwitching(state, cfg)
% =========================================================
% stage7_reconstructSwitching
%
% PURPOSE:
%   Reconstruct switching amplitude from AFM/FM metrics.
%
% INPUTS:
%   state - struct with pauseRuns and pauseRuns_raw
%   cfg   - configuration struct
%
% OUTPUTS:
%   result - reconstruction output struct
%   state  - unchanged data struct
%
% Physics meaning:
%   AFM = low-manifold dip metric
%   FM  = high-manifold background metric
%
% =========================================================

if strcmpi(cfg.switchingMetricMode, 'direct')
    mode = 'experimental';
else
    mode = 'fit';
end
Tsw = cfg.Tsw;
Rsw = cfg.Rsw;

params = cfg.switchParams;

% --- Wire optional Tp exclusion from config ---
params.switchExcludeTp = cfg.switchExcludeTp;
params.switchExcludeTpAbove = cfg.switchExcludeTpAbove;

result = reconstructSwitchingAmplitude( ...
    mode, ...
    state.pauseRuns, ...
    state.pauseRuns_raw, ...
    params, ...
    [state.pauseRuns.waitK], ...
    Tsw, ...
    Rsw);

if cfg.debug.enable
    disp('stage7: result fields =');
    disp(fieldnames(result));
    if isfield(result,'C_pause')
        fprintf('C_pause: N=%d, mean=%.3e, std=%.3e\n', ...
            numel(result.C_pause), mean(result.C_pause,'omitnan'), std(result.C_pause,'omitnan'));
    end
end

if cfg.debug.enable && isfield(cfg.debug,'plotSwitching') && cfg.debug.plotSwitching
    debugPlotSwitchingReconstruction(state, cfg, result);
end

% =========================================================
% Correlation between RMS FM background and fitted FM_step_A
% =========================================================

% --- Get valid Tp from switching reconstruction (synchronized source of truth) ---
% --- Get valid Tp from switching reconstruction (optional for diagnostics) ---
if isfield(result, 'Tp_valid') && ~isempty(result.Tp_valid)
    Tp_fm = result.Tp_valid;
elseif isfield(state, 'validPauseTp') && ~isempty(state.validPauseTp)
    Tp_fm = state.validPauseTp;
elseif isfield(result, 'Tp') && ~isempty(result.Tp)
    Tp_fm = result.Tp;
else
    Tp_fm = [];
    if isfield(cfg,'debug') && isfield(cfg.debug,'enable') && cfg.debug.enable
        warning('Tp_valid not found in result or state; skipping debug Tp/Tsw audit.');
    end
end


% Debug: guard against Tp/Tsw mixing
if isfield(cfg, 'debug') && isfield(cfg.debug, 'enable') && cfg.debug.enable
    if isfield(cfg.debug, 'assertNoTpMixing') && cfg.debug.assertNoTpMixing
        pauseTpList = [state.pauseRuns.waitK];
        outFolder = resolveDebugOutFolderStage7(cfg);
        if cfg.debug.logToFile && cfg.debug.saveOutputs && ~isempty(outFolder)
            appendDebugLogStage7(outFolder, pauseTpList, cfg.Tsw, Tp_fm);
        end

        if numel(pauseTpList) == numel(cfg.Tsw) && all(abs(pauseTpList(:) - cfg.Tsw(:)) < 1e-9)
            warning('Diagnostics: pauseTpList matches cfg.Tsw exactly; verify no Tp/Tsw mixing.');
        end
    end
end

% Extract FM_step_A for all pauses, then slice to valid Tp only
FM_fit_all = [state.pauseRuns.FM_step_A]';
Tp_all = [state.pauseRuns.waitK]';
FM_fit_f = FM_fit_all(ismember(Tp_all, Tp_fm));

% Debug gating + validation
if isfield(params,'debugSwitching') && params.debugSwitching
    fprintf('\nFM cross-check (synchronized with switching Tp)\n');
    fprintf('FM cross-check N = %d\n', numel(Tp_fm));
    fprintf('FM cross-check Tp = %s\n', mat2str(Tp_fm(:).'));
    
    % Assert Tp vector sizes match
    assert(isequal(numel(Tp_fm), numel(FM_fit_f)), ...
        'FM cross-check: Tp count mismatch with FM_step_A');
end

B_loc = result.B_basis(:);   % RMS FM on Tsw grid
Tsw_loc = Tsw(:);

B_rms_atTp = interp1(Tsw_loc, B_loc, Tp_fm, 'pchip');

if exist('FM_fit_f','var') && exist('B_rms_atTp','var') ...
        && ~isempty(FM_fit_f) && ~isempty(B_rms_atTp)
    R_FM = corr(FM_fit_f(:), B_rms_atTp(:), 'rows','complete');
else
    R_FM = NaN;
end

fprintf('\n=== FM cross-check ===\n');
fprintf('corr(RMS B(Tp), FM_step_A) = %.3f\n', R_FM);

% Enhanced diagnostics when correlation is NaN
if isnan(R_FM) && isfield(cfg, 'debug') && isfield(cfg.debug, 'enable') && cfg.debug.enable
    if exist('FM_fit_f','var') && exist('B_rms_atTp','var')
        fprintf('  FM_fit_f length: %d, NaNs: %d, std: %.4f\n', ...
            numel(FM_fit_f), nnz(isnan(FM_fit_f)), std(FM_fit_f, 'omitnan'));
        fprintf('  B_rms_atTp length: %d, NaNs: %d, std: %.4f\n', ...
            numel(B_rms_atTp), nnz(isnan(B_rms_atTp)), std(B_rms_atTp, 'omitnan'));
    else
        fprintf('  One or both vectors not defined.\n');
    end
end

% --- NEW: Interpolation overshoot diagnostic ---
if isfield(cfg, 'debug') && isfield(cfg.debug, 'enable') && cfg.debug.enable
    [A_violated, A_rangePct, A_overshootPct, B_violated, B_rangePct, B_overshootPct] = checkInterpolationOvershoot(cfg, result, [state.pauseRuns.waitK]);
    printStage7DiagnosticSummary(A_violated, A_rangePct, A_overshootPct, B_violated, B_rangePct, B_overshootPct);
end

% ===== Phase C Baseline Snapshot Export =====
if isfield(result,'Tp_pause')
    resultsLOO.Tp = result.Tp_pause(:);
else
    error('Pause-level Tp not found in result.');
end

if isfield(result,'Rsw_pause')
    resultsLOO.Rsw = result.Rsw_pause(:);
else
    error('Pause-level Rsw not found in result.');
end

if isfield(result,'C_pause')
    resultsLOO.C = result.C_pause(:);
else
    error('Pause-level coexistence not found in result.');
end

if isfield(result,'A_pause')
    resultsLOO.A = result.A_pause(:);
else
    error('Pause-level AFM metric not found in result.');
end

if isfield(result,'F_pause')
    resultsLOO.F = result.F_pause(:);
else
    error('Pause-level FM metric not found in result.');
end

outDir = fullfile(pwd,'results');
if ~exist(outDir,'dir')
    mkdir(outDir);
end

save(fullfile(outDir,'baseline_resultsLOO.mat'),'resultsLOO');

fprintf('\nBaseline snapshot saved for Phase C (LOO).\n');

end

% ====================== Local debug helpers ======================
function [A_violated, A_rangePct, A_overshootPct, B_violated, B_rangePct, B_overshootPct] = checkInterpolationOvershoot(cfg, result, Tp)
% Check that pchip interpolation of A_basis and B_basis does not exceed original Tp range by >threshold%.
A_violated = 0;
A_rangePct = 0;
A_overshootPct = 0;
B_violated = 0;
B_rangePct = 0;
B_overshootPct = 0;

if ~isfield(cfg.debug, 'interpOvershootPct')
    return;
end

Tp = Tp(:);
origRange = max(Tp) - min(Tp);

if origRange == 0
    return;
end

thresholdPct = cfg.debug.interpOvershootPct;

% Check A_basis
if isfield(result, 'A_basis')
    A = result.A_basis(:);
    interpRange = max(A) - min(A);
    
    A_rangePct = 100 * (interpRange / origRange - 1);
    A_overshootPct = max(0, A_rangePct);
    
    if A_overshootPct > thresholdPct
        A_violated = 1;
        warning('Interpolation overshoot: A_basis range exceeds original Tp range by %.2f%% (threshold %.1f%%)', ...
            A_overshootPct, thresholdPct);
    end
end

% Check B_basis
if isfield(result, 'B_basis')
    B = result.B_basis(:);
    interpRange = max(B) - min(B);
    
    B_rangePct = 100 * (interpRange / origRange - 1);
    B_overshootPct = max(0, B_rangePct);
    
    if B_overshootPct > thresholdPct
        B_violated = 1;
        warning('Interpolation overshoot: B_basis range exceeds original Tp range by %.2f%% (threshold %.1f%%)', ...
            B_overshootPct, thresholdPct);
    end
end
end

function printStage7DiagnosticSummary(A_violated, A_rangePct, A_overshootPct, B_violated, B_rangePct, B_overshootPct)
fprintf('\n---- PHASE B INTERPOLATION DIAGNOSTICS ----\n');
fprintf('A_rangePct = %.2f%%\n', A_rangePct);
fprintf('A_overshootPct = %.2f%%\n', A_overshootPct);
fprintf('A_violation = %d\n', A_violated);
fprintf('B_rangePct = %.2f%%\n', B_rangePct);
fprintf('B_overshootPct = %.2f%%\n', B_overshootPct);
fprintf('B_violation = %d\n', B_violated);

if A_violated == 0 && B_violated == 0
    fprintf('ALL INTERPOLATION CHECKS PASSED\n');
end
fprintf('-------------------------------------------\n\n');
end

function outFolder = resolveDebugOutFolderStage7(cfg)
outFolder = '';
if ~isfield(cfg, 'debug') || ~isfield(cfg.debug, 'saveOutputs') || ~cfg.debug.saveOutputs
    return;
end
if isfield(cfg.debug, 'outFolder') && ~isempty(cfg.debug.outFolder)
    outFolder = cfg.debug.outFolder;
    return;
end
runTag = cfg.debug.runTag;
if isempty(runTag)
    runTag = datestr(now, 'yyyymmdd_HHMMSS');
end
outputRoot = cfg.debug.outputRoot;
if isempty(outputRoot)
    outputRoot = fullfile(cfg.outputFolder, 'Debug');
end
outFolder = fullfile(outputRoot, runTag);
if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end
end

function appendDebugLogStage7(outFolder, pauseTpList, Tsw, Tp_valid)
logPath = fullfile(outFolder, 'log.txt');
fid = fopen(logPath, 'a');
if fid < 0
    return;
end
fprintf(fid, '\nSwitching diagnostics:\n');
fprintf(fid, 'pauseTpList: %s\n', mat2str(pauseTpList(:)'));
fprintf(fid, 'cfg.Tsw: %s\n', mat2str(Tsw(:)'));
fprintf(fid, 'validSwitchTp: %s\n', mat2str(Tp_valid(:)'));
fclose(fid);
end
