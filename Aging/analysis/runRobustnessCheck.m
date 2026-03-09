function runRobustnessCheck(state, cfg)
% =========================================================
% runRobustnessCheck
%
% PURPOSE:
%   Perform parameter robustness sweep for AFM/FM analysis.
%
% INPUTS:
%   state - struct with pauseRuns
%   cfg   - configuration struct
%
% OUTPUTS:
%   none (console output and plots only)
%
% =========================================================

% =========================================================
% Robustness parameter sweep (broader coverage)
% =========================================================
% Goals:
%  - probe wider smoothing scales (smoothWindow_K)
%  - probe wider plateau geometry (FM_plateau_K, FM_buffer_K)
%  - keep everything deterministic and comparable

k = 0;

% --- choose smoothing multipliers (relative to dip_window_K) ---
smoothMult = [2 3 4 6 8 10];     % expanded to larger domains

% --- choose plateau widths (K) ---
plateauList = [4 6 8 12 16];     % expanded

% --- choose buffers away from dip (K) ---
bufferList  = [2 4 6 8 10];      % expanded

for sm = smoothMult
    for pl = plateauList
        for bf = bufferList

            % Skip unphysical combos: plateau should not be too small vs buffer
            if pl < 2
                continue;
            end

            % Skip too-aggressive near-dip: ensure buffer at least ~dip_window_K/2
            if bf < 0.5*cfg.dip_window_K
                continue;
            end

            k = k + 1;

            paramSet(k) = struct( ...
                'label', sprintf('sm=%gx | pl=%gK | bf=%gK', sm, pl, bf), ...
                'smoothWindow_K', sm*cfg.dip_window_K, ...
                'FM_plateau_K',   pl, ...
                'FM_buffer_K',    bf);

        end
    end
end

DeltaT = nan(numel(paramSet),1);
TA = nan(numel(paramSet),1);
TF = nan(numel(paramSet),1);

for kk = 1:numel(paramSet)

    tmp = analyzeAFM_FM_components( ...
        state.pauseRuns, cfg.dip_window_K, paramSet(kk).smoothWindow_K, ...
        cfg.excludeLowT_FM, cfg.excludeLowT_K, ...
        paramSet(kk).FM_plateau_K, cfg.excludeLowT_mode, ...
        paramSet(kk).FM_buffer_K, cfg.AFM_metric_main, cfg);

    Tp_loc = [tmp.waitK];

    % --- AFM metric ---
    switch cfg.AFM_metric_main
        case 'height'
            AFM = [tmp.AFM_amp];
        case 'area'
            AFM = [tmp.AFM_area];
    end

    % --- FM metric ---
    FM = [tmp.FM_step_mag];

    if all(isnan(AFM)) || all(isnan(FM))
        continue;
    end

    [~,iA] = max(AFM);
    [~,iF] = max(FM);

    TA(kk) = Tp_loc(iA);
    TF(kk) = Tp_loc(iF);

    DeltaT(kk) = abs(TA(kk) - TF(kk));
end

fprintf('\n=== AFM–FM peak separation over robustness sweep ===\n');
fprintf('Mean ΔT = %.2f K\n', mean(DeltaT,'omitnan'));
fprintf('Min  ΔT = %.2f K\n', min(DeltaT));
fprintf('Max  ΔT = %.2f K\n', max(DeltaT));

[~,imin] = min(DeltaT);
disp('Worst-case (minimum separation) parameter set:');
disp(paramSet(imin));
[~,imax] = max(DeltaT);
disp('Best-case (maximum separation) parameter set:');
disp(paramSet(imax));

% Run the check
plotAFM_FM_robustnessCheck( ...
    state.pauseRuns, cfg.dip_window_K, ...
    cfg.excludeLowT_FM, cfg.excludeLowT_K, cfg.excludeLowT_mode, ...
    paramSet, cfg.fontsize);

end
