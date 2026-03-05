function [result, state] = stage7_reconstructSwitching(state, cfg)
% =========================================================
% stage7_reconstructSwitching
%
% PURPOSE:
%   Reconstruct switching amplitude from AFM/FM metrics.
%   Uses controlled debug logging for production pipelines.
%
% INPUTS:
%   state - struct with pauseRuns and pauseRuns_raw
%   cfg   - configuration struct with debug settings
%
% OUTPUTS:
%   result - reconstruction output struct
%   state  - updated state struct (stores result in state.stage7)
%
% Physics meaning:
%   AFM = low-manifold dip metric
%   FM  = high-manifold background metric
%
% DEBUG INFRASTRUCTURE:
%   Uses dbg() for logging at appropriate verbosity levels
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
if ~isfield(params, 'FM_source') || isempty(params.FM_source)
    params.FM_source = 'stage7_recompute';
end
if isfield(cfg, 'FM_source') && ~isempty(cfg.FM_source)
    params.FM_source = cfg.FM_source;
end

dbg(cfg, "summary", "Switching reconstruction: mode=%s", mode);

% --- Wire optional Tp exclusion from config ---
params.switchExcludeTp = cfg.switchExcludeTp;
params.switchExcludeTpAbove = cfg.switchExcludeTpAbove;

result = reconstructSwitchingAmplitude( ...
    mode, ...
    getPauseRuns(state), ...
    state.pauseRuns_raw, ...
    params, ...
    [getPauseRuns(state).waitK], ...
    Tsw, ...
    Rsw);

if cfg.debug.enable
    dbg(cfg, "full", "Reconstruction result fields: %s", strjoin(fieldnames(result), ', '));
    if isfield(result,'C_pause')
        dbg(cfg, "full", "C_pause: N=%d, mean=%.3e, std=%.3e", ...
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
        pauseTpList = [getPauseRuns(state).waitK];
        outFolder = resolveDebugOutFolderStage7(cfg);
        if cfg.debug.logToFile && cfg.debug.saveOutputs && ~isempty(outFolder)
            appendDebugLogStage7(outFolder, pauseTpList, cfg.Tsw, Tp_fm);
        end

        if numel(pauseTpList) == numel(cfg.Tsw) && all(abs(pauseTpList(:) - cfg.Tsw(:)) < 1e-9)
            warning('Diagnostics: pauseTpList matches cfg.Tsw exactly; verify no Tp/Tsw mixing.');
        end
    end
end

% Robust FM extraction (no crash if FM field missing)
fmCandidates = {'FM_step_A','FM_step','FM_stepA','FM_A','FM'};
fmField = '';
pauseRuns_loc = getPauseRuns(state);  % Get once to avoid multiple calls

for k = 1:numel(fmCandidates)
    if isfield(pauseRuns_loc, fmCandidates{k})
        fmField = fmCandidates{k};
        break;
    end
end

Tp_all = [pauseRuns_loc.waitK]';

if isempty(fmField)
    FM_fit_all = nan(numel(Tp_all),1);
else
    tmp = {pauseRuns_loc.(fmField)};
    FM_fit_all = cellfun(@double, tmp(:));
end

FM_fit_f = FM_fit_all(ismember(Tp_all, Tp_fm));

% Debug gating + validation
if isfield(params,'debugSwitching') && params.debugSwitching
    dbg(cfg, "summary", "FM cross-check (synchronized with switching Tp)");
    dbg(cfg, "summary", "FM cross-check N = %d", numel(Tp_fm));
    dbg(cfg, "summary", "FM cross-check Tp = %s", mat2str(Tp_fm(:).'));

    % Assert Tp vector sizes match
    if ~all(isnan(FM_fit_f))
        assert(isequal(numel(Tp_fm), numel(FM_fit_f)), ...
            'FM cross-check: Tp count mismatch with FM data');
    end
end

B_loc = result.B_basis(:);   % RMS FM on Tsw grid
Tsw_loc = Tsw(:);

B_rms_atTp = interp1(Tsw_loc, B_loc, Tp_fm, 'pchip');

if exist('FM_fit_f','var') && exist('B_rms_atTp','var') ...
        && ~isempty(FM_fit_f) && ~isempty(B_rms_atTp)
    [R_FM, status_FM, n_FM] = safeCorr(FM_fit_f(:), B_rms_atTp(:));
    if status_FM ~= "ok"
        dbg(cfg, "full", "FM cross-check: safeCorr status=%s, n=%d", status_FM, n_FM);
    end
else
    R_FM = NaN;
    status_FM = "undefined";
end

dbg(cfg, "summary", "FM cross-check: corr(RMS B(Tp), FM_step_A) = %.3f", R_FM);

% =========================================================
% Channel correlation diagnostics (diagnostics-only)
% Tests AFM/FM association with switching beyond pure temperature trend
% =========================================================
if isfield(result, 'A_basis') && isfield(result, 'B_basis')
    A = result.A_basis(:);
    B = result.B_basis(:);
    Rsw_loc = Rsw(:);
    Tsw_corr = Tsw(:);

    dA = gradient(A, Tsw_corr);
    dB = gradient(B, Tsw_corr);

    [c_RA, status_RA, n_RA] = safeCorr(Rsw_loc, A);
    [c_RB, status_RB, n_RB] = safeCorr(Rsw_loc, B);
    [c_RdA, status_RdA, n_RdA] = safeCorr(Rsw_loc, abs(dA));
    [c_RdB, status_RdB, n_RdB] = safeCorr(Rsw_loc, abs(dB));

    if status_RA ~= "ok"
        dbg(cfg, "full", "Channel corr R,A: status=%s, n=%d", status_RA, n_RA);
    end
    if status_RB ~= "ok"
        dbg(cfg, "full", "Channel corr R,B: status=%s, n=%d", status_RB, n_RB);
    end
    if status_RdA ~= "ok"
        dbg(cfg, "full", "Channel corr R,|dA/dT|: status=%s, n=%d", status_RdA, n_RdA);
    end
    if status_RdB ~= "ok"
        dbg(cfg, "full", "Channel corr R,|dB/dT|: status=%s, n=%d", status_RdB, n_RdB);
    end

    pc_RA_T = partialcorr(Rsw_loc, A, Tsw_corr, 'rows','complete');
    pc_RB_T = partialcorr(Rsw_loc, B, Tsw_corr, 'rows','complete');

    % Store in result for diagnostics summary
    result.corr_R_A = c_RA;
    result.corr_R_B = c_RB;
    result.corr_R_dAdT = c_RdA;
    result.corr_R_dBdT = c_RdB;
    result.partialcorr_R_A_given_T = pc_RA_T;
    result.partialcorr_R_B_given_T = pc_RB_T;

    fprintf('\n=== CHANNEL CORRELATION DIAGNOSTICS ===\n');
    fprintf('corr(R,A) = %.3f\n', c_RA);
    fprintf('corr(R,B) = %.3f\n', c_RB);
    fprintf('corr(R,|dA/dT|) = %.3f\n', c_RdA);
    fprintf('corr(R,|dB/dT|) = %.3f\n', c_RdB);
    fprintf('partialcorr(R,A | T) = %.3f\n', pc_RA_T);
    fprintf('partialcorr(R,B | T) = %.3f\n', pc_RB_T);
    fprintf('=======================================\n');
end

% Enhanced diagnostics when correlation is NaN
if isnan(R_FM) && isfield(cfg, 'debug') && isfield(cfg.debug, 'enable') && cfg.debug.enable
    if exist('FM_fit_f','var') && exist('B_rms_atTp','var')
        dbg(cfg, "full", "  FM_fit_f: length=%d, NaNs=%d, std=%.4f", ...
            numel(FM_fit_f), nnz(isnan(FM_fit_f)), std(FM_fit_f, 'omitnan'));
        dbg(cfg, "full", "  B_rms_atTp: length=%d, NaNs=%d, std=%.4f", ...
            numel(B_rms_atTp), nnz(isnan(B_rms_atTp)), std(B_rms_atTp, 'omitnan'));
    else
        dbg(cfg, "full", "  One or both vectors not defined.");
    end
end

% --- NEW: Interpolation overshoot diagnostic ---
if isfield(cfg, 'debug') && isfield(cfg.debug, 'enable') && cfg.debug.enable
    [A_violated, A_rangePct, A_overshootPct, B_violated, B_rangePct, B_overshootPct] = checkInterpolationOvershoot(cfg, result, [getPauseRuns(state).waitK]);
    printStage7DiagnosticSummary(cfg, A_violated, A_rangePct, A_overshootPct, B_violated, B_rangePct, B_overshootPct);
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

dbg(cfg, "summary", "Baseline snapshot saved for Phase C (LOO)");

state.stage7 = result;
%{
T = state.stage7.T;
R = state.stage7.R_measured;
A = state.stage7.A_basis;
B = state.stage7.B_basis;

[rA,pA] = partialcorr(R,A,T);
[rB,pB] = partialcorr(R,B,T);

fprintf('partialcorr(R,A|T) = %.3f (p=%.3g)\n',rA,pA);
fprintf('partialcorr(R,B|T) = %.3f (p=%.3g)\n',rB,pB);
%}
end

% ====================== Local debug helpers ======================
function [A_violated, A_rangePct, A_overshootPct, B_violated, B_rangePct, B_overshootPct] = checkInterpolationOvershoot(cfg, result, Tp)
% Check interpolation range inflation in basis amplitude units (dimensionally consistent).
A_violated = 0;
A_rangePct = 0;
A_overshootPct = 0;
B_violated = 0;
B_rangePct = 0;
B_overshootPct = 0;

if ~isfield(cfg.debug, 'interpOvershootPct')
    return;
end
if ~isfield(result, 'Tsw') || isempty(result.Tsw)
    return;
end

Tp = Tp(:);
Tsw_loc = result.Tsw(:);
thresholdPct = cfg.debug.interpOvershootPct;

% Check A_basis (compare interpolated full-range vs pause-sampled range in same units)
if isfield(result, 'A_basis')
    A = result.A_basis(:);
    A_atTp = interp1(Tsw_loc, A, Tp, 'pchip', NaN);
    A_atTp = A_atTp(isfinite(A_atTp));

    if numel(A_atTp) >= 2
        baseRange = max(A_atTp) - min(A_atTp);
        interpRange = max(A) - min(A);
        if baseRange > 0
            A_rangePct = 100 * (interpRange / baseRange - 1);
            A_overshootPct = max(0, A_rangePct);
        end

        if A_overshootPct > thresholdPct
            A_violated = 1;
            warning('Interpolation overshoot: A_basis range exceeds pause-sampled A range by %.2f%% (threshold %.1f%%)', ...
                A_overshootPct, thresholdPct);
        end
    end
end

% Check B_basis (same units as A)
if isfield(result, 'B_basis')
    B = result.B_basis(:);
    B_atTp = interp1(Tsw_loc, B, Tp, 'pchip', NaN);
    B_atTp = B_atTp(isfinite(B_atTp));

    if numel(B_atTp) >= 2
        baseRange = max(B_atTp) - min(B_atTp);
        interpRange = max(B) - min(B);
        if baseRange > 0
            B_rangePct = 100 * (interpRange / baseRange - 1);
            B_overshootPct = max(0, B_rangePct);
        end

        if B_overshootPct > thresholdPct
            B_violated = 1;
            warning('Interpolation overshoot: B_basis range exceeds pause-sampled B range by %.2f%% (threshold %.1f%%)', ...
                B_overshootPct, thresholdPct);
        end
    end
end
end

function printStage7DiagnosticSummary(cfg, A_violated, A_rangePct, A_overshootPct, B_violated, B_rangePct, B_overshootPct)
dbg(cfg, "summary", "---- PHASE B INTERPOLATION DIAGNOSTICS ----");
dbg(cfg, "summary", "A_rangePct = %.2f%%", A_rangePct);
dbg(cfg, "summary", "A_overshootPct = %.2f%%", A_overshootPct);
dbg(cfg, "summary", "A_violation = %d", A_violated);
dbg(cfg, "summary", "B_rangePct = %.2f%%", B_rangePct);
dbg(cfg, "summary", "B_overshootPct = %.2f%%", B_overshootPct);
dbg(cfg, "summary", "B_violation = %d", B_violated);

if A_violated == 0 && B_violated == 0
    dbg(cfg, "summary", "ALL INTERPOLATION CHECKS PASSED");
end
dbg(cfg, "summary", "--------------------------------------------");
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


