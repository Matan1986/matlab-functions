function verifyRobustBaseline_WithLogging
% VERIFYROBUSTBASELINE_WITHLOGGING - Verification with full file logging
%
% Runs all verifications and logs everything to a text file

    % Create log file in a debug area under the repository root.
    thisFile = mfilename('fullpath');
    verificationDir = fileparts(thisFile);
    agingDir = fileparts(verificationDir);
    repoRoot = fileparts(agingDir);
    logDir = fullfile(repoRoot, 'tmp_debug_outputs', 'verification');
    if exist(logDir, 'dir') ~= 7
        mkdir(logDir);
    end
    logfile = fullfile(logDir, 'verification_results.txt');
    
    % Override fprintf to also log to file
    fid_log = fopen(logfile, 'w');
    
    % Create function handles to write to both console and file
    fprintf_both = @(fmt, varargin) ...
        fprintf_to_both(fid_log, fmt, varargin{:});
    
    fprintf_both('\n');
    fprintf_both('â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—\n');
    fprintf_both('â•‘  ROBUST BASELINE VERIFICATION (WITH LOGGING)                  â•‘\n');
    fprintf_both('â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•\n\n');
    fprintf_both('Log file: %s\n\n', logfile);
    
    % Setup
    baseFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(genpath(baseFolder));
    
    % Create synthetic dataset
    fprintf_both('STEP 1: Creating synthetic Aging dataset\n');
    fprintf_both('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n\n');
    
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
    
    % Create test dataset
    [pauseRuns_base, metadata] = createSyntheticDataset();
    N = numel(pauseRuns_base);
    fprintf_both('âœ“ Created %d pause runs from %d combinations\n', N, metadata.n_Tp * metadata.n_wait);
    fprintf_both('  Pause temperatures: %s K\n', sprintf('%.0f ', metadata.Tp_list));
    fprintf_both('  Wait times: %s min\n', sprintf('%.0f ', metadata.wait_times));
    fprintf_both('\n');
    
    % Run OLD method
    fprintf_both('STEP 2: Running OLD method (Tp-dependent plateaus)\n');
    fprintf_both('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n\n');
    
    cfg_old = cfg;
    cfg_old.useRobustBaseline = false;
    
    try
        pauseRuns_old = analyzeAFM_FM_components( ...
            pauseRuns_base, cfg.dip_window_K, cfg.smoothWindow_K, ...
            cfg.excludeLowT_FM, cfg.excludeLowT_K, ...
            cfg.FM_plateau_K, cfg.excludeLowT_mode, cfg.FM_buffer_K, ...
            'area', cfg_old);
        fprintf_both('âœ“ Old method completed successfully\n\n');
    catch ME
        fprintf_both('âœ— Old method failed with error:\n');
        fprintf_both('  %s\n\n', ME.message);
        fclose(fid_log);
        return;
    end
    
    % Run NEW method
    fprintf_both('STEP 3: Running NEW method (scan-based robust baseline)\n');
    fprintf_both('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n\n');
    
    cfg_new = cfg;
    cfg_new.useRobustBaseline = true;
    cfg_new.dip_margin_K = 2;
    cfg_new.plateau_nPoints = 6;
    cfg_new.dropLowestN = 1;
    
    try
        pauseRuns_new = analyzeAFM_FM_components( ...
            pauseRuns_base, cfg.dip_window_K, cfg.smoothWindow_K, ...
            cfg.excludeLowT_FM, cfg.excludeLowT_K, ...
            cfg.FM_plateau_K, cfg.excludeLowT_mode, cfg.FM_buffer_K, ...
            'area', cfg_new);
        fprintf_both('âœ“ New method completed successfully\n\n');
    catch ME
        fprintf_both('âœ— New method failed with error:\n');
        fprintf_both('  %s\n\n', ME.message);
        fclose(fid_log);
        return;
    end
    
    % Extract tables
    fprintf_both('STEP 4: Extracting diagnostic tables\n');
    fprintf_both('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n\n');
    
    [t_old, t_new] = buildTableComparison(pauseRuns_old, pauseRuns_new, cfg);
    
    fprintf_both('OLD METHOD RESULTS:\n');
    fprintf_both('â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€\n');
    printTable_brief(fid_log, t_old);
    fprintf_both('\n');
    
    fprintf_both('NEW METHOD RESULTS:\n');
    fprintf_both('â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€\n');
    printTable_brief(fid_log, t_new);
    fprintf_both('\n');
    
    % Physics checks
    fprintf_both('STEP 5: Physics sanity checks\n');
    fprintf_both('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n\n');
    
    warnings_list = {};
    
    % Check 5a: Dip location
    fprintf_both('5a) DIP LOCATION (|Tmin - Tp| < 2 K):\n');
    dip_err_old = abs(t_old.Tmin - t_old.Tp);
    dip_err_new = abs(t_new.Tmin - t_new.Tp);
    bad_old = sum(dip_err_old > 2);
    bad_new = sum(dip_err_new > 2, 'omitnan');
    fprintf_both('    Old: %d/%d (%.1f%%) out of tolerance\n', bad_old, height(t_old), 100*bad_old/height(t_old));
    fprintf_both('    New: %d/%d (%.1f%%) out of tolerance\n', bad_new, height(t_new), 100*max(bad_new,0)/height(t_new));
    if bad_new > 0
        for i = 1:height(t_new)
            if dip_err_new(i) > 2
                w = sprintf('Dip location: Run %d |Tmin-Tp|=%.2f K > 2 K', t_new.RunID(i), dip_err_new(i));
                warnings_list{end+1} = w;
            end
        end
    else
        fprintf_both('    âœ“ All within tolerance\n');
    end
    fprintf_both('\n');
    
    % Check 5b: Plateau separation
    fprintf_both('5b) PLATEAU SEPARATION (no overlap with dip):\n');
    dipL = t_new.Tp - cfg.dip_window_K;
    dipR = t_new.Tp + cfg.dip_window_K;
    sep_L = t_new.PlateauL_max < dipL;
    sep_R = t_new.PlateauR_min > dipR;
    sep_ok = sep_L & sep_R;
    n_ok = sum( sep_ok, 'omitnan');
    fprintf_both('    Plateau separation OK: %d/%d (%.1f%%)\n', n_ok, height(t_new), 100*n_ok/height(t_new));
    if n_ok < height(t_new)
        for i = find(~sep_ok)'
            if ~sep_L(i)
                w = sprintf('Plateau_L overlap: Run %d max=%.2f >= dipL=%.2f', t_new.RunID(i), t_new.PlateauL_max(i), dipL(i));
                warnings_list{end+1} = w;
            end
            if ~sep_R(i)
                w = sprintf('Plateau_R overlap: Run %d min=%.2f <= dipR=%.2f', t_new.RunID(i), t_new.PlateauR_min(i), dipR(i));
                warnings_list{end+1} = w;
            end
        end
    else
        fprintf_both('    âœ“ All plateaus properly separated\n');
    end
    fprintf_both('\n');
    
    % Check 5c: Aging growth
    fprintf_both('5c) AGING GROWTH (dip area increases with wait time):\n');
    unique_Tp = unique(t_new.Tp, 'rows');
    for tp = unique_Tp'
        mask = t_new.Tp == tp;
        wt_v = t_new.WaitTime(mask);
        dip_v = t_new.DipArea(mask);
        valid = isfinite(wt_v) & isfinite(dip_v) & wt_v > 0 & dip_v > 0;
        
        if sum(valid) >= 3
            wt_clean = wt_v(valid);
            dip_clean = dip_v(valid);
            try
                [rho, pval] = corr(wt_clean, dip_clean, 'type', 'Spearman');
                fprintf_both('    Tp=%.1f K: Ï=%.3f (p=%.4f), n=%d', tp, rho, pval, sum(valid));
                if rho < 0
                    fprintf_both(' âš  NEGATIVE CORRELATION\n');
                    w = sprintf('Negative aging correlation at Tp=%.1f K (rho=%.3f)', tp, rho);
                    warnings_list{end+1} = w;
                else
                    fprintf_both(' âœ“\n');
                end
            catch
                fprintf_both('    Tp=%.1f K: correlation computation failed\n', tp);
            end
        end
    end
    fprintf_both('\n');
    
    % Check 5d: FM stability
    fprintf_both('5d) FM BASELINE STABILITY (relative variation < 30%%):\n');
    for tp = unique_Tp'
        mask = t_new.Tp == tp;
        fm_v = t_new.FM_step(mask);
        fm_clean = fm_v(isfinite(fm_v));
        
        if numel(fm_clean) >= 2
            m = mean(fm_clean);
            s = std(fm_clean);
            rel_var = s / (abs(m) + eps);
            fprintf_both('    Tp=%.1f K: rel_var=%.1f%%, mean=%.4g, std=%.4g', tp, 100*rel_var, m, s);
            if rel_var > 0.3
                fprintf_both(' âš  HIGH VARIATION\n');
                w = sprintf('FM stability: Tp=%.1f K rel_var=%.1f%% > 30%%', tp, 100*rel_var);
                warnings_list{end+1} = w;
            else
                fprintf_both(' âœ“\n');
            end
        end
    end
    fprintf_both('\n');
    
    % Check 5e: Boundary artifacts
    fprintf_both('5e) BOUNDARY ARTIFACTS (dip >0.5 K from scan edge):\n');
    n_boundary = 0;
    for i = 1:numel(pauseRuns_new)
        run = pauseRuns_new(i);
        if isfield(run, 'T_common')
            T = run.T_common(isfinite(run.T_common));
            if ~isempty(T)
                Tlo = min(T);
                Thi = max(T);
                Tmin_dip = t_new.Tmin(i);
                if abs(Tmin_dip - Tlo) < 0.5 || abs(Tmin_dip - Thi) < 0.5
                    fprintf_both('    âš  Run %d: Tmin=%.2f near edge [%.2f, %.2f]\n', i, Tmin_dip, Tlo, Thi);
                    n_boundary = n_boundary + 1;
                    w = sprintf('Boundary artifact: Run %d Tmin=%.2f near [%.2f,%.2f]', i, Tmin_dip, Tlo, Thi);
                    warnings_list{end+1} = w;
                end
            end
        end
    end
    if n_boundary == 0
        fprintf_both('    âœ“ No boundary artifacts\n');
    end
    fprintf_both('\n');
    
    % Summary statistics
    fprintf_both('STEP 6: Summary statistics\n');
    fprintf_both('â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\n\n');
    
    fprintf_both('OLD METHOD STATISTICS:\n');
    n_ok_old = sum(strcmp(t_old.Status, 'ok'), 'omitnan');
    fprintf_both('  Valid runs (status="ok"): %d/%d (%.1f%%)\n', n_ok_old, height(t_old), 100*n_ok_old/height(t_old));
    fprintf_both('  NaN in FM_step: %d/%d\n', sum(isnan(t_old.FM_step)), height(t_old));
    fprintf_both('  NaN in Dip_area: %d/%d\n', sum(isnan(t_old.DipArea)), height(t_old));
    fprintf_both('\n');
    
    fprintf_both('NEW METHOD STATISTICS:\n');
    n_ok_new = sum(strcmp(t_new.Status, 'ok'), 'omitnan');
    fprintf_both('  Valid runs (status="ok"): %d/%d (%.1f%%)\n', n_ok_new, height(t_new), 100*n_ok_new/height(t_new));
    fprintf_both('  NaN in FM_step: %d/%d\n', sum(isnan(t_new.FM_step)), height(t_new));
    fprintf_both('  NaN in Dip_area: %d/%d\n', sum(isnan(t_new.DipArea)), height(t_new));
    fprintf_both('\n');
    
    % Final verdict
    fprintf_both('â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—\n');
    fprintf_both('â•‘  FINAL VERIFICATION REPORT                                    â•‘\n');
    fprintf_both('â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•\n\n');
    
    if isempty(warnings_list)
        fprintf_both('âœ“âœ“âœ“ ROBUST BASELINE STABLE âœ“âœ“âœ“\n');
        fprintf_both('NO ISSUES DETECTED\n\n');
        overall = 'robust baseline stable';
    else
        fprintf_both('âš âš âš  %d WARNINGS DETECTED âš âš âš \n\n', numel(warnings_list));
        for i = 1:numel(warnings_list)
            fprintf_both('[%d] %s\n', i, warnings_list{i});
        end
        fprintf_both('\n');
        overall = 'baseline issues detected';
    end
    
    fprintf_both('OVERALL STATUS: %s\n\n', overall);
    fprintf_both('Report generated: %s\n', datetime('now'));
    
    fclose(fid_log);
    
    % Display file path
    fprintf('âœ“ Full verification report saved to:\n  %s\n', logfile);
    
end

% ========================================================================
% HELPER FUNCTIONS
% ========================================================================

function [pauseRuns, metadata] = createSyntheticDataset()
    % Create realistic synthetic Aging dataset
    
    Tp_list = [6, 10, 15, 20, 25, 30];
    wait_times = [1, 3, 10, 30, 100, 300];
    
    metadata.Tp_list = Tp_list;
    metadata.wait_times = wait_times;
    metadata.n_Tp = numel(Tp_list);
    metadata.n_wait = numel(wait_times);
    
    pauseRuns = struct();
    idx = 1;
    
    for tp = Tp_list
        for wt = wait_times
            T = linspace(4, 34, 150)';
            dT = mean(diff(T));
            
            % Synthetic Î”M with FM background + AFM dip
            dM_fm = 0.2 * (1 - exp(-(T - 4)/8));
            
            % Dip depth scales with aging (wait time)
            depth_factor = 1 + 0.1 * log(wt + 1);
            dip = (-0.15 * depth_factor) * exp(-((T - tp).^2) / 8);
            
            % Add realistic noise
            noise = 0.01 * randn(size(T));
            
            dM = dM_fm + dip + noise;
            
            pauseRuns(idx).waitK = tp;
            pauseRuns(idx).wait_time_min = wt;
            pauseRuns(idx).T_common = T;
            pauseRuns(idx).DeltaM = dM;
            pauseRuns(idx).label = sprintf('Tp_%.0f_wait_%.0f', tp, wt);
            
            idx = idx + 1;
        end
    end
    
end

function [t_old, t_new] = buildTableComparison(pauseRuns_old, pauseRuns_new, cfg)
    % Build comparison tables from old and new method results
    
    N = numel(pauseRuns_old);
    
    % Preallocate
    runid = (1:N)';
    tp = NaN(N,1);
    wt = NaN(N,1);
    tmin = NaN(N,1);
    dip_o = NaN(N,1);
    dip_n = NaN(N,1);
    fm_o = NaN(N,1);
    fm_n = NaN(N,1);
    slope = NaN(N,1);
    status = cell(N,1);
    pl_min = NaN(N,1);
    pl_max = NaN(N,1);
    pr_min = NaN(N,1);
    pr_max = NaN(N,1);
    
    for i = 1:N
        % Basic info
        tp(i) = pauseRuns_old(i).waitK;
        wt(i) = getFieldOrDefault(pauseRuns_old(i), 'wait_time_min', NaN);
        
        % Old method
        dip_o(i) = getFieldOrNaN(pauseRuns_old(i), 'Dip_area');
        fm_o(i) = getFieldOrNaN(pauseRuns_old(i), 'FM_step_mag');
        
        % New method
        dip_n(i) = getFieldOrNaN(pauseRuns_new(i), 'Dip_area');
        fm_n(i) = getFieldOrNaN(pauseRuns_new(i), 'FM_step_mag');
        slope(i) = getFieldOrNaN(pauseRuns_new(i), 'baseline_slope');
        status{i} = getFieldOrDefault(pauseRuns_new(i), 'baseline_status', 'unknown');
        
        % Dip minimum location
        if isfield(pauseRuns_new(i), 'DeltaM_sharp') && ~isempty(pauseRuns_new(i).DeltaM_sharp)
            dM_s = pauseRuns_new(i).DeltaM_sharp(:);
            T = pauseRuns_new(i).T_common(:);
            valid_mask = isfinite(dM_s);
            if nnz(valid_mask) >= 1
                [~, idx_local] = min(dM_s(valid_mask));
                idx_global = find(valid_mask);
                tmin(i) = T(idx_global(idx_local));
            end
        end
        
        % Plateau temperatures
        tl = getFieldOrDefault(pauseRuns_new(i), 'baseline_TL', NaN);
        if isfinite(tl)
            pl_min(i) = tl - 0.5;
            pl_max(i) = tl + 0.5;
        end
        
        tr = getFieldOrDefault(pauseRuns_new(i), 'baseline_TR', NaN);
        if isfinite(tr)
            pr_min(i) = tr - 0.5;
            pr_max(i) = tr + 0.5;
        end
    end
    
    % Build tables
    t_old = table(runid, tp, wt, tmin, dip_o, fm_o, ...
                  'VariableNames', {'RunID', 'Tp', 'WaitTime', 'Tmin', 'DipArea', 'FM_step'});
    
    t_new = table(runid, tp, wt, tmin, dip_n, fm_n, slope, status, ...
                  pl_min, pl_max, pr_min, pr_max, ...
                  'VariableNames', {'RunID', 'Tp', 'WaitTime', 'Tmin', 'DipArea', 'FM_step', ...
                                    'BaselineSlope', 'Status', 'PlateauL_min', 'PlateauL_max', ...
                                    'PlateauR_min', 'PlateauR_max'});
    
end

function printTable_brief(fid, tbl)
    % Print brief table summary to file
    
    n_show = min(5, height(tbl));
    
    % Get variable names
    vars = tbl.Properties.VariableNames;
    
    % Print header
    for i = 1:numel(vars)
        if i < numel(vars)
            fprintf(fid, '%s | ', vars{i});
        else
            fprintf(fid, '%s\n', vars{i});
        end
    end
    fprintf(fid, '%s\n', repmat('â”€', 1, 80));
    
    % Print first n rows
    for row = 1:n_show
        for i = 1:numel(vars)
            var_val = tbl.(vars{i})(row);
            if islogical(var_val)
                str = sprintf('%d', var_val);
            elseif isnumeric(var_val)
                str = sprintf('%.4g', var_val);
            elseif ischar(var_val) || isstring(var_val)
                str = sprintf('%s', var_val);
            else
                str = '?';
            end
            if i < numel(vars)
                fprintf(fid, '%-15s | ', str);
            else
                fprintf(fid, '%-15s\n', str);
            end
        end
    end
    
    if height(tbl) > n_show
        fprintf(fid, '... (%d more rows)\n', height(tbl) - n_show);
    end
    
end

function fprintf_to_both(fid, fmt, varargin)
    % Write to both console and file
    fprintf(fmt, varargin{:});
    fprintf(fid, fmt, varargin{:});
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

