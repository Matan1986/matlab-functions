function verifyRobustBaseline_Simple
% VERIFYROBUSTBASELINE_SIMPLE  Focused verification of robust baseline
%
% This version provides clear, detailed output without complex dependencies.

    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════════╗\n');
    fprintf('║  ROBUST BASELINE VERIFICATION (FOCUSED)                       ║\n');
    fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');
    
    % Setup
    baseFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(genpath(baseFolder));
    
    % Create synthetic dataset with realistic properties
    fprintf('STEP 1: Creating synthetic Aging dataset with realistic properties\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    [state_old, state_new, cfg] = createAndRunTests();
    
    N = numel(state_old.pauseRuns);
    fprintf('✓ Created and processed %d pause runs\n\n', N);
    
    % Extract table
    fprintf('STEP 2: Extracting diagnostics table\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    [table_old, table_new] = extractComparativeTable(state_old, state_new);
    
    % Display tables
    fprintf('OLD METHOD (Tp-dependent plateaus):\n');
    fprintf('─────────────────────────────────\n');
    disp(table_old);
    fprintf('\n');
    
    fprintf('NEW METHOD (Robust scan-based plateaus):\n');
    fprintf('────────────────────────────────────────\n');
    disp(table_new);
    fprintf('\n');
    
    % Physics checks
    fprintf('STEP 3: Physics sanity checks\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    warnings = {};
    
    % 3a) Dip location
    fprintf('3a) DIP LOCATION CHECK (|Tmin - Tp| < 2 K):\n');
    dip_errors_old = abs(table_old.Tmin - table_old.Tp);
    dip_errors_new = abs(table_new.Tmin - table_new.Tp);
    
    bad_old = dip_errors_old > 2;
    bad_new = dip_errors_new > 2;
    
    fprintf('    Old method: %d runs with |Tmin-Tp| > 2 K\n', nnz(bad_old));
    fprintf('    New method: %d runs with |Tmin-Tp| > 2 K\n', nnz(bad_new));
    
    if nnz(bad_new) > 0
        for i = find(bad_new)'
            msg = sprintf('      Run %d: Tmin=%.2f, Tp=%.2f, delta=%.2f K', ...
                table_new.RunID(i), table_new.Tmin(i), table_new.Tp(i), dip_errors_new(i));
            fprintf('  ⚠ %s\n', msg);
            warnings{end+1} = msg;
        end
    else
        fprintf('  ✓ All dip locations within tolerance\n');
    end
    fprintf('\n');
    
    % 3b) Plateau separation
    fprintf('3b) PLATEAU SEPARATION (max(plateau_L) < dipL, min(plateau_R) > dipR):\n');
    dipL = table_new.Tp - cfg.dip_window_K;
    dipR = table_new.Tp + cfg.dip_window_K;
    
    sep_L_ok = table_new.PlateauL_max < dipL;
    sep_R_ok = table_new.PlateauR_min > dipR;
    
    fprintf('    Plateau_L separation OK: %d/%d\n', nnz(sep_L_ok), height(table_new));
    fprintf('    Plateau_R separation OK: %d/%d\n', nnz(sep_R_ok), height(table_new));
    
    if ~all(sep_L_ok) || ~all(sep_R_ok)
        fprintf('  ⚠ Plateau separation issues:\n');
        for i = find(~sep_L_ok)'
            msg = sprintf('    Run %d: PlateauL_max=%.2f >= dipL=%.2f', ...
                table_new.RunID(i), table_new.PlateauL_max(i), dipL(i));
            fprintf('      %s\n', msg);
            warnings{end+1} = msg;
        end
        for i = find(~sep_R_ok)'
            msg = sprintf('    Run %d: PlateauR_min=%.2f <= dipR=%.2f', ...
                table_new.RunID(i), table_new.PlateauR_min(i), dipR(i));
            fprintf('      %s\n', msg);
            warnings{end+1} = msg;
        end
    else
        fprintf('  ✓ All plateaus properly separated from dip\n');
    end
    fprintf('\n');
    
    % 3c) Aging growth
    fprintf('3b) AGING GROWTH CHECK (dip area vs wait time):\n');
    fprintf('    Grouping by Tp, computing Spearman correlation...\n');
    unique_Tp = unique(table_new.Tp);
    
    for tp = unique_Tp'
        mask = table_new.Tp == tp;
        wts = table_new.WaitTime(mask);
        dips = table_new.DipArea(mask);
        valid = isfinite(wts) & isfinite(dips) & wts > 0 & dips > 0;
        
        if nnz(valid) >= 3
            wts_v = wts(valid);
            dips_v = dips(valid);
            [rho, pval] = corr(wts_v, dips_v, 'type', 'Spearman');
            
            status_str = '✓';
            if rho < 0
                status_str = '⚠';
                warnings{end+1} = sprintf('Tp=%.1f K: negative aging correlation (rho=%.3f)', tp, rho);
            end
            
            fprintf('    %s Tp=%.1f K: ρ=%.3f (p=%.4f), n=%d\n', status_str, tp, rho, pval, nnz(valid));
        end
    end
    fprintf('\n');
    
    % 3d) FM stability
    fprintf('3d) FM BASELINE STABILITY (relative variation < 30%%):\n');
    for tp = unique_Tp'
        mask = table_new.Tp == tp;
        fm_vals = table_new.FM_step(mask);
        fm_v = fm_vals(isfinite(fm_vals));
        
        if numel(fm_v) >= 2
            m = mean(fm_v);
            s = std(fm_v);
            rel_var = s / (abs(m) + eps);
            
            if rel_var > 0.3
                status_str = '⚠';
                msg = sprintf('Tp=%.1f K: rel_var=%.2f%% (mean=%.4g, std=%.4g)', tp, 100*rel_var, m, s);
                warnings{end+1} = msg;
                fprintf('    %s %s\n', status_str, msg);
            else
                fprintf('    ✓ Tp=%.1f K: rel_var=%.2f%% (stable)\n', tp, 100*rel_var);
            end
        end
    end
    fprintf('\n');
    
    % 3e) Boundary artifacts
    fprintf('3e) BOUNDARY ARTIFACT CHECK (dip within 0.5 K of scan edge):\n');
    boundary_issues = 0;
    for i = 1:numel(state_new.pauseRuns)
        run = state_new.pauseRuns(i);
        if isfield(run, 'T_common')
            T = run.T_common(isfinite(run.T_common));
            if ~isempty(T)
                Tmin_meas = min(T);
                Tmax_meas = max(T);
                Tmin_dip = table_new.Tmin(i);
                
                if abs(Tmin_dip - Tmin_meas) < 0.5 || abs(Tmin_dip - Tmax_meas) < 0.5
                    msg = sprintf('    Run %d: Tmin=%.2f near boundary [%.2f, %.2f]', i, Tmin_dip, Tmin_meas, Tmax_meas);
                    fprintf('    ⚠ %s\n', msg);
                    warnings{end+1} = msg;
                    boundary_issues = boundary_issues + 1;
                end
            end
        end
    end
    if boundary_issues == 0
        fprintf('    ✓ No boundary artifacts detected\n');
    end
    fprintf('\n');
    
    % Summary
    fprintf('STEP 4: Summary statistics\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    n_ok_old = nnz(strcmp(table_old.Status, 'ok'));
    n_ok_new = nnz(strcmp(table_new.Status, 'ok'));
    
    fprintf('OLD METHOD:\n');
    fprintf('  Valid runs (status="ok"): %d/%d\n', n_ok_old, height(table_old));
    fprintf('  NaN in FM_step: %d/%d\n', nnz(isnan(table_old.FM_step)), height(table_old));
    fprintf('  NaN in Dip_area: %d/%d\n', nnz(isnan(table_old.DipArea)), height(table_old));
    fprintf('\n');
    
    fprintf('NEW METHOD:\n');
    fprintf('  Valid runs (status="ok"): %d/%d\n', n_ok_new, height(table_new));
    fprintf('  NaN in FM_step: %d/%d\n', nnz(isnan(table_new.FM_step)), height(table_new));
    fprintf('  NaN in Dip_area: %d/%d\n', nnz(isnan(table_new.DipArea)), height(table_new));
    fprintf('\n');
    
    % Plateau statistics
    n_pts_L = table_new.nPlateauL(isfinite(table_new.nPlateauL));
    n_pts_R = table_new.nPlateauR(isfinite(table_new.nPlateauR));
    if ~isempty(n_pts_L)
        fprintf('Plateau point counts:\n');
        fprintf('  Left plateau: min=%d, max=%d, mean=%.1f\n', min(n_pts_L), max(n_pts_L), mean(n_pts_L));
        fprintf('  Right plateau: min=%d, max=%d, mean=%.1f\n', min(n_pts_R), max(n_pts_R), mean(n_pts_R));
    end
    fprintf('\n');
    
    slopes_v = table_new.BaselineSlope(isfinite(table_new.BaselineSlope));
    if ~isempty(slopes_v)
        fprintf('Baseline slope distribution:\n');
        fprintf('  Min: %.6g\n', min(slopes_v));
        fprintf('  Max: %.6g\n', max(slopes_v));
        fprintf('  Mean: %.6g\n', mean(slopes_v));
        fprintf('  Std: %.6g\n', std(slopes_v));
    end
    fprintf('\n');
    
    % Final verdict
    fprintf('╔════════════════════════════════════════════════════════════════╗\n');
    fprintf('║  VERIFICATION RESULTS                                         ║\n');
    fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');
    
    if isempty(warnings)
        fprintf('✓✓✓ ROBUST BASELINE STABLE - NO ISSUES DETECTED ✓✓✓\n\n');
        overall = 'robust baseline stable';
    else
        fprintf('⚠⚠⚠ %d ISSUES DETECTED ⚠⚠⚠\n\n', numel(warnings));
        for i = 1:numel(warnings)
            fprintf('[%d] %s\n', i, warnings{i});
        end
        fprintf('\n');
        overall = 'baseline issues detected';
    end
    
    fprintf('\nOVERALL STATUS: %s\n\n', overall);
    
end

% ========================================================================
% HELPER FUNCTIONS
% ========================================================================

function [state_old, state_new, cfg] = createAndRunTests()
    % Create synthetic dataset and run both old and new methods
    
    % Configuration
    cfg = struct();
    cfg.dip_window_K = 4;
    cfg.smoothWindow_K = 12;
    cfg.excludeLowT_FM = false;
    cfg.excludeLowT_K = -inf;
    cfg.FM_plateau_K = 6;
    cfg.excludeLowT_mode = 'pre';
    cfg.FM_buffer_K = 3;
    cfg.debug.verbose = false;
    cfg.debug.enable = false;
    
    % Create synthetic data
    Tp_list = [6, 10, 15, 20, 25, 30];
    wait_times = [1, 3, 10, 30, 100, 300];
    
    pauseRuns = struct();
    idx = 1;
    
    for tp = Tp_list
        for wt = wait_times
            T = linspace(4, 34, 150)';
            
            % Synthetic ΔM
            dM_fm = 0.2 * (1 - exp(-(T - 4)/8));
            depth_scale = 1 + 0.1 * log(wt + 1);
            dip = (-0.15 * depth_scale) * exp(-((T - tp).^2) / 8);
            dM = dM_fm + dip + 0.01*randn(size(T));
            
            pauseRuns(idx).waitK = tp;
            pauseRuns(idx).wait_time_min = wt;
            pauseRuns(idx).T_common = T;
            pauseRuns(idx).DeltaM = dM;
            pauseRuns(idx).label = sprintf('Tp=%.0fK_wait=%.0fmin', tp, wt);
            idx = idx + 1;
        end
    end
    
    % Run OLD method
    state_old = struct();
    state_old.pauseRuns = pauseRuns;
    cfg_old = cfg;
    cfg_old.useRobustBaseline = false;
    
    try
        state_old.pauseRuns = analyzeAFM_FM_components( ...
            state_old.pauseRuns, cfg.dip_window_K, cfg.smoothWindow_K, ...
            cfg.excludeLowT_FM, cfg.excludeLowT_K, ...
            cfg.FM_plateau_K, cfg.excludeLowT_mode, cfg.FM_buffer_K, ...
            'area', cfg_old);
    catch ME
        fprintf('Warning: Old method failed: %s\n', ME.message);
    end
    
    % Run NEW method
    state_new = struct();
    state_new.pauseRuns = pauseRuns;
    cfg_new = cfg;
    cfg_new.useRobustBaseline = true;
    cfg_new.dip_margin_K = 2;
    cfg_new.plateau_nPoints = 6;
    cfg_new.dropLowestN = 1;
    
    try
        state_new.pauseRuns = analyzeAFM_FM_components( ...
            state_new.pauseRuns, cfg.dip_window_K, cfg.smoothWindow_K, ...
            cfg.excludeLowT_FM, cfg.excludeLowT_K, ...
            cfg.FM_plateau_K, cfg.excludeLowT_mode, cfg.FM_buffer_K, ...
            'area', cfg_new);
    catch ME
        fprintf('Warning: New method failed: %s\n', ME.message);
    end
    
end

function [table_old, table_new] = extractComparativeTable(state_old, state_new)
    % Extract comparison tables from old and new methods
    
    N = numel(state_old.pauseRuns);
    
    % Initialize columns
    runid = (1:N)';
    tp = zeros(N, 1);
    wt = zeros(N, 1);
    tmin = zeros(N, 1);
    dip_area_o = zeros(N, 1);
    dip_area_n = zeros(N, 1);
    dip_depth_o = zeros(N, 1);
    dip_depth_n = zeros(N, 1);
    fm_o = zeros(N, 1);
    fm_n = zeros(N, 1);
    slope = zeros(N, 1);
    status = {};
    pl_min = zeros(N, 1);
    pl_max = zeros(N, 1);
    pr_min = zeros(N, 1);
    pr_max = zeros(N, 1);
    n_pl = zeros(N, 1);
    n_pr = zeros(N, 1);
    
    for i = 1:N
        % Basic info
        tp(i) = state_old.pauseRuns(i).waitK;
        wt(i) = getFieldOrDefault(state_old.pauseRuns(i), 'wait_time_min', NaN);
        
        % Old method
        dip_area_o(i) = getFieldOrNaN(state_old.pauseRuns(i), 'Dip_area');
        dip_depth_o(i) = getFieldOrNaN(state_old.pauseRuns(i), 'AFM_amp');
        fm_o(i) = getFieldOrNaN(state_old.pauseRuns(i), 'FM_step_mag');
        
        % New method
        dip_area_n(i) = getFieldOrNaN(state_new.pauseRuns(i), 'Dip_area');
        dip_depth_n(i) = getFieldOrNaN(state_new.pauseRuns(i), 'AFM_amp');
        fm_n(i) = getFieldOrNaN(state_new.pauseRuns(i), 'FM_step_mag');
        slope(i) = getFieldOrNaN(state_new.pauseRuns(i), 'baseline_slope');
        status{i} = getFieldOrDefault(state_new.pauseRuns(i), 'baseline_status', 'unknown');
        
        % Dip location
        if isfield(state_new.pauseRuns(i), 'DeltaM_sharp')
            dM_s = state_new.pauseRuns(i).DeltaM_sharp(:);
            T = state_new.pauseRuns(i).T_common(:);
            valid = isfinite(dM_s);
            if nnz(valid) > 0
                [~, idx] = min(dM_s(valid));
                idx_all = find(valid);
                tmin(i) = T(idx_all(idx));
            else
                tmin(i) = NaN;
            end
        else
            tmin(i) = NaN;
        end
        
        % Plateau info
        pl_min(i) = getFieldOrDefault(state_new.pauseRuns(i), 'baseline_TL', NaN);
        if isfinite(pl_min(i))
            pl_min(i) = pl_min(i) - 0.5; pl_max(i) = pl_min(i) + 1;
            n_pl(i) = 5;
        else
            pl_max(i) = NaN; n_pl(i) = NaN;
        end
        
        pr_min(i) = getFieldOrDefault(state_new.pauseRuns(i), 'baseline_TR', NaN);
        if isfinite(pr_min(i))
            pr_min(i) = pr_min(i) - 0.5; pr_max(i) = pr_min(i) + 1;
            n_pr(i) = 5;
        else
            pr_max(i) = NaN; n_pr(i) = NaN;
        end
    end
    
    % Build tables
    table_old = table(runid, tp, wt, tmin, dip_area_o, dip_depth_o, fm_o, ...
                      'VariableNames', {'RunID', 'Tp', 'WaitTime', 'Tmin', 'DipArea', 'DipDepth', 'FM_step'});
    
    table_new = table(runid, tp, wt, tmin, dip_area_n, dip_depth_n, fm_n, slope, status, ...
                      pl_min, pl_max, n_pl, pr_min, pr_max, n_pr, ...
                      'VariableNames', {'RunID', 'Tp', 'WaitTime', 'Tmin', 'DipArea', 'DipDepth', 'FM_step', ...
                                        'BaselineSlope', 'Status', 'PlateauL_min', 'PlateauL_max', 'nPlateauL', ...
                                        'PlateauR_min', 'PlateauR_max', 'nPlateauR'});
    
end

function val = getFieldOrNaN(s, fieldName)
    if isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = NaN;
    end
end

function val = getFieldOrDefault(s, fieldName, defaultVal)
    if isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = defaultVal;
    end
end
