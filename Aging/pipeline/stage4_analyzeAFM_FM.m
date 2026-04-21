function state = stage4_analyzeAFM_FM(state, cfg)
% =========================================================
% stage4_analyzeAFM_FM
%
% PURPOSE:
%   Orchestrate AFM/FM decomposition from DeltaM.
%   Delegates computation to specialized analysis functions.
%
% INPUTS:
%   state - struct with pauseRuns
%   cfg   - configuration struct
%
% OUTPUTS:
%   state - updated with AFM/FM metrics
%
% Canonical physics definitions used across the Aging sign layer:
%   DeltaM_signed = M_pause - M_noPause
%   dip_signed    = DeltaM_signed - DeltaM_smooth
%   FM_signed     = signed background/step and may change sign physically
%
% NOTE:
%   Raw window observables and magnitude transforms are metrics, not
%   canonical signed physical variables.
%
% =========================================================

% ====================== Core Analysis ======================
% Compute AFM/FM decomposition
if ~isfield(cfg, 'agingMetricMode') || isempty(cfg.agingMetricMode)
    cfg.agingMetricMode = 'direct';
end
agingMode = lower(string(cfg.agingMetricMode));

switch agingMode
    case {'direct', 'model', 'fit'}
        state.pauseRuns = analyzeAFM_FM_components( ...
            state.pauseRuns, cfg.dip_window_K, cfg.smoothWindow_K, ...
            cfg.excludeLowT_FM, cfg.excludeLowT_K, ...
            cfg.FM_plateau_K, cfg.excludeLowT_mode, cfg.FM_buffer_K, ...
            cfg.AFM_metric_main, cfg);

    case 'derivative'
        for i = 1:numel(state.pauseRuns)
            run = state.pauseRuns(i);
            if ~isfield(run, 'T_common') || ~isfield(run, 'DeltaM') || ~isfield(run, 'waitK')
                continue;
            end

            % Use canonical DeltaM when available; keep legacy fallback.
            dM_for_derivative = run.DeltaM;
            if isfield(run, 'DeltaM_signed') && ~isempty(run.DeltaM_signed)
                dM_for_derivative = run.DeltaM_signed;
            end
            result = analyzeAFM_FM_derivative(run.T_common, dM_for_derivative, run.waitK, cfg);
            f = fieldnames(result);
            for j = 1:numel(f)
                run.(f{j}) = result.(f{j});
            end
            state.pauseRuns = assignRunFields(state.pauseRuns, i, run);
        end

    case 'extrema_smoothed'
        for i = 1:numel(state.pauseRuns)
            run = state.pauseRuns(i);
            result = analyzeAFM_FM_extrema_smoothed(run);
            f = fieldnames(result);
            for j = 1:numel(f)
                run.(f{j}) = result.(f{j});
            end
            state.pauseRuns = assignRunFields(state.pauseRuns, i, run);
        end

    otherwise
        error('Unknown agingMetricMode: %s', cfg.agingMetricMode);
end

% ====================== Stage4 Dip Diagnostics ======================
% Keep dip-analysis diagnostics in pauseRuns without altering AFM/FM logic.
for i = 1:numel(state.pauseRuns)
    run = state.pauseRuns(i);

    % Persist AFM dip metric mode for downstream plotting/diagnostics.
    if isfield(cfg, 'AFM_metric_main') && ~isempty(cfg.AFM_metric_main)
        run.dipMetric = char(lower(string(cfg.AFM_metric_main)));
    end

    % Keep direct (stage4) dip area explicitly, independent of fit-based fields.
    if isfield(run, 'AFM_area') && ~isempty(run.AFM_area) && isfinite(run.AFM_area)
        run.Dip_area_direct = run.AFM_area;
    else
        run.Dip_area_direct = NaN;
    end

    % Ensure required diagnostics fields exist
    if ~isfield(run, 'Dip_area') || isempty(run.Dip_area)
        % Legacy compatibility: prefer explicit direct area when Dip_area is missing.
        if isfield(run, 'Dip_area_direct') && ~isempty(run.Dip_area_direct) && isfinite(run.Dip_area_direct)
            run.Dip_area = run.Dip_area_direct;
        else
            run.Dip_area = NaN;
        end
    end
    if ~isfield(run, 'Dip_depth') || isempty(run.Dip_depth)
        % Use AFM_amp from analyzer (dip amplitude/height)
        if isfield(run, 'AFM_amp') && ~isempty(run.AFM_amp) && isfinite(run.AFM_amp)
            run.Dip_depth = run.AFM_amp;
            run.Dip_depth_source = 'afm_amp_residual';
        else
            run.Dip_depth = NaN;
            run.Dip_depth_source = 'unset';
        end
    end
    if ~isfield(run, 'FM_step_mag') || isempty(run.FM_step_mag)
        run.FM_step_mag = NaN;
    end
    if isfield(run, 'FM_step_raw') && ~isempty(run.FM_step_raw) && isfinite(run.FM_step_raw)
        % FM_signed is a physical signed quantity (sign is meaningful).
        run.FM_signed = run.FM_step_raw;
    elseif isfield(run, 'FM_step_mag') && ~isempty(run.FM_step_mag) && isfinite(run.FM_step_mag)
        % Compatibility fallback when only FM_step_mag exists.
        run.FM_signed = run.FM_step_mag;
    else
        run.FM_signed = NaN;
    end
    if isfinite(run.FM_signed)
        % Magnitude metric (non-canonical physical variable).
        run.FM_abs = abs(run.FM_signed);
    else
        run.FM_abs = NaN;
    end
    if ~isfield(run, 'baseline_slope') || isempty(run.baseline_slope)
        run.baseline_slope = NaN;
    end
    if ~isfield(run, 'baseline_status') || isempty(run.baseline_status)
        run.baseline_status = 'unknown';
    end

    % Need Tp and dip half-width for dip-window diagnostics
    if ~isfield(run, 'waitK') || isempty(run.waitK) || ~isfinite(run.waitK)
        run.Tp = NaN;
        run.dip_window = [NaN NaN];
        run.dip_edge_flag = false;
        run.Tmin = NaN;
        run.Tmin_offset = NaN;
        state.pauseRuns = assignRunFields(state.pauseRuns, i, run);
        continue;
    end

    Tp = run.waitK;
    run.Tp = Tp;

    dipHalfWidth = cfg.dip_window_K;
    dip_lo_raw = Tp - dipHalfWidth;
    dip_hi_raw = Tp + dipHalfWidth;

    % Use DeltaM for Tmin diagnostics (smoothed only for Tmin detection)
    hasT = isfield(run, 'T_common') && ~isempty(run.T_common);
    hasDM = isfield(run, 'DeltaM') && ~isempty(run.DeltaM);

    if ~(hasT && hasDM)
        run.dip_window = [NaN NaN];
        run.dip_edge_flag = false;
        run.Tmin = NaN;
        run.Tmin_offset = NaN;
        state.pauseRuns = assignRunFields(state.pauseRuns, i, run);
        continue;
    end

    T = run.T_common(:);
    % Active observable used by stage4 diagnostics (legacy-compatible).
    DeltaM_observable = run.DeltaM(:);
    % Canonical physical DeltaM (preferred when available).
    if isfield(run, 'DeltaM_signed') && ~isempty(run.DeltaM_signed)
        DeltaM_signed = run.DeltaM_signed(:);
        run.DeltaM_signed_source = 'input_canonical';
    else
        DeltaM_signed = DeltaM_observable;
        run.DeltaM_signed_source = 'fallback_from_DeltaM_observable';
    end

    n = min([numel(T), numel(DeltaM_observable), numel(DeltaM_signed)]);
    T = T(1:n);
    DeltaM_observable = DeltaM_observable(1:n);
    DeltaM_signed = DeltaM_signed(1:n);
    % Keep canonical DeltaM aligned to the trimmed support for downstream audits.
    run.DeltaM_signed = DeltaM_signed;

    valid = isfinite(T) & isfinite(DeltaM_observable);
    if ~any(valid)
        run.dip_window = [NaN NaN];
        run.dip_edge_flag = false;
        run.Tmin = NaN;
        run.Tmin_offset = NaN;
        state.pauseRuns = assignRunFields(state.pauseRuns, i, run);
        continue;
    end

    Tv = T(valid);
    dMv = DeltaM_observable(valid);

    % Clamp dip window to measured scan range
    Tlo = min(Tv);
    Thi = max(Tv);
    dip_lo = max(dip_lo_raw, Tlo);
    dip_hi = min(dip_hi_raw, Thi);
    run.dip_window = [dip_lo dip_hi];
    run.dip_edge_flag = (dip_lo > dip_lo_raw) || (dip_hi < dip_hi_raw);

    % Tmin diagnostic only (light smoothing if not already present)
    % Restrict search to dip window around Tp (not global minimum)
    window_mask = (Tv >= dip_lo) & (Tv <= dip_hi);
    if ~any(window_mask)
        % Fallback: use full range if window has no points
        window_mask = true(size(Tv));
    end
    Tv_window = Tv(window_mask);
    dMv_window = dMv(window_mask);
    if numel(dMv_window) >= 3
        DeltaM_smooth = movmean(dMv_window, 3, 'omitnan');
    else
        DeltaM_smooth = dMv_window;
    end
    [~, idxMin] = min(DeltaM_smooth);
    Tmin = Tv_window(idxMin);
    run.Tmin = Tmin;
    run.Tmin_offset = Tmin - Tp;

    % Compatibility dip-window metric from raw DeltaM observable.
    % This is NOT the canonical physical dip (which is residual dip_signed).
    run.Dip_depth_window_metric = NaN;
    if ~isfield(run, 'Dip_depth') || isempty(run.Dip_depth) || ~isfinite(run.Dip_depth)
        % Only compute if dMv_window has valid data
        valid_window = isfinite(dMv_window);
        if any(valid_window)
            dip_depth_value = max(dMv_window(valid_window));
            if isfinite(dip_depth_value)
                run.Dip_depth = dip_depth_value;
                run.Dip_depth_source = 'raw_deltam_window_metric_noncanonical';
                run.Dip_depth_window_metric = dip_depth_value;
            end
        end
    elseif isfield(run, 'Dip_depth_source') && strcmp(run.Dip_depth_source, 'afm_amp_residual')
        valid_window = isfinite(dMv_window);
        if any(valid_window)
            run.Dip_depth_window_metric = max(dMv_window(valid_window));
        end
    end

    % Keep compatibility with existing diagnostics that use Tmin_K
    if ~isfield(run, 'Tmin_K') || isempty(run.Tmin_K) || ~isfinite(run.Tmin_K)
        run.Tmin_K = Tmin;
    end

    % ===== TWO-TIME LAYER (Audit-Ready) =====
    % Dip clock below is a raw-window observable metric for compatibility.
    % Canonical physical dip remains run.dip_signed from residual decomposition.
    % FM clock remains based on signed FM_step_raw/FM_signed.
    
    if isfield(cfg, 'useCanonicalClocks') && cfg.useCanonicalClocks
        % DIP WINDOW METRIC CLOCK (non-canonical dip observable)
        if hasT && hasDM
            % Prepare raw DeltaM window observable within dip window
            dipMask = (T >= dip_lo) & (T <= dip_hi);
            if any(dipMask)
                T_dip = T(dipMask);
                dM_dip_window_metric = DeltaM_observable(dipMask);
                dM_dip_window_metric_signed = dM_dip_window_metric;
                
                % Build dip-window metric clock (legacy behavior preserved).
                cfg_dip = struct();
                if isfield(cfg, 'dip_selector_mode')
                    cfg_dip.selector_mode = cfg.dip_selector_mode;
                else
                    cfg_dip.selector_mode = 'half_range_primary';
                end
                if isfield(cfg, 'dip_support_mode')
                    cfg_dip.support_mode = cfg.dip_support_mode;
                else
                    cfg_dip.support_mode = 'resolved';
                end
                if isfield(cfg, 'dip_crossing_rule')
                    cfg_dip.crossing_rule = cfg.dip_crossing_rule;
                else
                    cfg_dip.crossing_rule = 'first_point';
                end
                cfg_dip.sign_handling = 'preserve';  % Always preserve sign for audit
                
                dip_clock = construct_canonical_clock( ...
                    T_dip, dM_dip_window_metric, dM_dip_window_metric_signed, cfg_dip);
                
                % Legacy field names are kept for compatibility with downstream code.
                run.tau_dip_canonical = dip_clock.value;
                run.tau_dip_signed = dip_clock.signed_value;
                run.tau_dip_absolute = dip_clock.absolute_value;
                run.tau_dip_selector_mode = dip_clock.selector_mode_used;
                run.tau_dip_crossing_mode = dip_clock.crossing_rule_used;
                run.tau_dip_support_status = dip_clock.support_status;
                run.tau_dip_n_valid_points = dip_clock.n_valid_points;
                run.tau_dip_range = dip_clock.data_range;
                % Store full clock struct for robustness audits
                run.tau_dip_clock_struct = dip_clock;
                run.tau_dip_source = 'raw_deltam_window_metric_noncanonical';
                run.tau_dip_is_canonical = false;
                run.tau_dip_metric = dip_clock.value;
            end
        end
        
        % FM CLOCK - signed physical FM step (canonical sign preserved)
        if isfinite(run.FM_step_raw) || isfinite(run.FM_step_mag)
            % Use FM step value (preserved signed and unsigned)
            FM_signed = run.FM_step_raw;  % Preserve signed FM convention
            FM_raw = FM_signed;
            
            % Create synthetic temperature array [low, high] for FM plateau
            if isfinite(run.FM_plateau_left_width_K) && isfinite(run.FM_plateau_right_width_K)
                T_fm = [0; 1];  % Synthetic: low to high temperature
            else
                T_fm = [];
            end
            
            if ~isempty(T_fm)
                % Build canonical FM clock using same selector logic
                cfg_fm = struct();
                if isfield(cfg, 'fm_selector_mode')
                    cfg_fm.selector_mode = cfg.fm_selector_mode;
                else
                    cfg_fm.selector_mode = 'half_range_primary';
                end
                if isfield(cfg, 'fm_support_mode')
                    cfg_fm.support_mode = cfg.fm_support_mode;
                else
                    cfg_fm.support_mode = 'resolved';
                end
                if isfield(cfg, 'fm_crossing_rule')
                    cfg_fm.crossing_rule = cfg.fm_crossing_rule;
                else
                    cfg_fm.crossing_rule = 'first_point';
                end
                cfg_fm.sign_handling = 'preserve';  % Always preserve sign for audit
                
                % For FM, treatment is scalar; replicate to match structure
                FM_observable_raw = [FM_raw; FM_raw];
                FM_observable_signed = [FM_signed; FM_signed];
                
                fm_clock = construct_canonical_clock(T_fm, FM_observable_raw, FM_observable_signed, cfg_fm);
                
                % Assign canonical FM outputs
                run.tau_fm_canonical = fm_clock.value;
                run.tau_fm_signed = fm_clock.signed_value;
                run.tau_fm_absolute = fm_clock.absolute_value;
                run.tau_fm_selector_mode = fm_clock.selector_mode_used;
                run.tau_fm_crossing_mode = fm_clock.crossing_rule_used;
                run.tau_fm_support_status = fm_clock.support_status;
                run.tau_fm_n_valid_points = fm_clock.n_valid_points;
                run.tau_fm_range = fm_clock.data_range;
                % Store full clock struct for robustness audits
                run.tau_fm_clock_struct = fm_clock;
            end
        end
    end
    % ===== END TWO-TIME LAYER =====

    state.pauseRuns = assignRunFields(state.pauseRuns, i, run);
end

% ====================== Debug Diagnostics (Optional) ======================
if isfield(cfg, 'debug') && isfield(cfg.debug, 'enable') && cfg.debug.enable
    state = debugAgingStage4(state, cfg);
end

% ====================== Debug Geometry Plots (Optional) ======================
if isfield(cfg, 'doPlotting') && cfg.doPlotting && ...
        isfield(cfg, 'debug') && isfield(cfg.debug, 'plotGeometry') && cfg.debug.plotGeometry && ...
        usejava('desktop')
    debugPlotGeometry(state, cfg);
end

% ====================== Robustness Check (Optional) ======================
if isfield(cfg, 'RobustnessCheck') && cfg.RobustnessCheck
    runRobustnessCheck(state, cfg);
end

% ====================== Example Decomposition Plots (Optional) ======================
if isfield(cfg, 'showAFM_FM_example') && cfg.showAFM_FM_example
    plotDecompositionExamples(state, cfg);
end

end

function pauseRuns = assignRunFields(pauseRuns, idx, run)
fields = fieldnames(run);
for j = 1:numel(fields)
    pauseRuns(idx).(fields{j}) = run.(fields{j});
end
end


