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

% =========================================================
% Correlation between RMS FM background and fitted FM_step_A
% =========================================================

% --- Get valid Tp from switching reconstruction (synchronized source of truth) ---
% --- Get valid Tp from switching reconstruction (optional for diagnostics) ---
if isfield(result, 'Tp_valid') && ~isempty(result.Tp_valid)
    Tp_fm = result.Tp_valid;
else
    Tp_fm = [];
    if isfield(cfg,'debug') && isfield(cfg.debug,'enable') && cfg.debug.enable
        warning('Tp_valid not found in result; skipping debug Tp/Tsw audit.');
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

end

% ====================== Local debug helpers ======================
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
