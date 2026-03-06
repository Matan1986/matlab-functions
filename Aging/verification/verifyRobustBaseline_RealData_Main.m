function verifyRobustBaseline_RealData_Main
% VERIFYROBUSTBASELINE_REALDATA_MAIN
%
% Runs the REAL Aging pipeline with robust baseline enabled.
% Uses actual .dat measurement files (not synthetic data).
%
% Steps:
%   1. Load real data via Main_Aging pipeline
%   2. Run with robust baseline enabled
%   3. Extract diagnostics from real pauseRuns
%   4. Compute statistics for each Tp
%   5. Check for baseline drift (correlation with wait_time)
%   6. Generate plots with real data
    
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════════╗\n');
    fprintf('║  ROBUST BASELINE VERIFICATION - REAL AGING DATASET            ║\n');
    fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');
    
    % Setup paths
    baseFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(genpath(baseFolder));
    
    % Load configuration
    fprintf('STEP 1: Loading Aging configuration\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    cfg = agingConfig();
    
    % Enable robust baseline
    cfg.useRobustBaseline = true;
    cfg.dip_margin_K = 2;
    cfg.plateau_nPoints = 6;
    cfg.dropLowestN = 1;
    cfg.debug.verbose = false;
    cfg.debug.enable = false;
    
    % Check if data directory is set
    if ~isfield(cfg, 'dataDir') || isempty(cfg.dataDir)
        % Try to find Aging data directory
        dataDir = fullfile(baseFolder, 'AgingData');
        if ~exist(dataDir, 'dir')
            % Look for common alternate locations
            dataDir = fullfile(baseFolder, 'data', 'Aging');
        end
        if ~exist(dataDir, 'dir')
            % Create a demo with standard locations
            fprintf('⚠ Warning: No data directory configured\n');
            fprintf('  Checked: %s\n', fullfile(baseFolder, 'AgingData'));
            fprintf('  Please set cfg.dataDir to your data folder.\n\n');
            
            % Try to use a default if available
            homeDir = char(java.nio.file.FileSystems.getDefault().getPath(char(filesep), ...
                                char(java.nio.file.Paths.get(char(filesep)))'));
            possibleDirs = {
                fullfile(baseFolder, 'Aging', 'data');
                fullfile(pwd, 'data');
                'C:\Data\Aging';
                'D:\Data\Aging';
            };
            
            for i = 1:numel(possibleDirs)
                if exist(possibleDirs{i}, 'dir')
                    dataDir = possibleDirs{i};
                    fprintf('✓ Found data at: %s\n\n', dataDir);
                    break;
                end
            end
            
            if ~exist(dataDir, 'dir')
                error('Could not locate Aging data directory. Please set cfg.dataDir manually.');
            end
        end
        cfg.dataDir = dataDir;
    end
    
    fprintf('Data directory: %s\n', cfg.dataDir);
    
    if ~exist(cfg.dataDir, 'dir')
        error('Data directory does not exist: %s', cfg.dataDir);
    end
    
    % Run the REAL pipeline
    fprintf('\nSTEP 2: Running REAL Aging pipeline with robust baseline\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    try
        state = Main_Aging(cfg);
        fprintf('✓ Pipeline completed successfully\n');
        fprintf('  Total pause runs: %d\n\n', numel(state.pauseRuns));
    catch ME
        fprintf('✗ Pipeline failed with error:\n');
        fprintf('  %s\n\n', ME.message);
        return;
    end
    
    % Verify robust baseline was applied
    if isfield(state.pauseRuns(1), 'baseline_status')
        fprintf('✓ Robust baseline was applied (baseline_status field present)\n\n');
    else
        fprintf('⚠ Warning: baseline_status field missing (robust baseline may not be active)\n\n');
    end
    
    % Extract diagnostics table
    fprintf('STEP 3: Extracting diagnostics from real pauseRuns\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    diagTable = extractRealDiagnosticsTable(state);
    
    fprintf('Diagnostics table (%d runs):\n', height(diagTable));
    fprintf('─────────────────────────────────────────────────────────────\n');
    disp(diagTable);
    fprintf('\n');
    
    % Physics checks
    fprintf('STEP 4: Physics sanity checks on real data\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    warnings = {};
    
    % 4a) Dip location
    fprintf('4a) Dip location check (|Tmin - Tp| < 2 K):\n');
    dip_err = abs(diagTable.Tmin - diagTable.Tp);
    bad_dip = dip_err > 2 & isfinite(dip_err);
    fprintf('    Dips within tolerance: %d/%d\n', nnz(~bad_dip), height(diagTable));
    if any(bad_dip)
        for i = find(bad_dip)'
            msg = sprintf('  ⚠ Run %d: |Tmin-Tp| = %.2f K > 2 K', ...
                diagTable.RunID(i), dip_err(i));
            fprintf('%s\n', msg);
            warnings{end+1} = msg;
        end
    else
        fprintf('    ✓ All dips located correctly\n');
    end
    fprintf('\n');
    
    % 4b) Plateau separation
    fprintf('4b) Plateau separation (no overlap with dip):\n');
    dipL = diagTable.Tp - cfg.dip_window_K;
    dipR = diagTable.Tp + cfg.dip_window_K;
    sep_L = diagTable.PlateauL_max < dipL;
    sep_R = diagTable.PlateauR_min > dipR;
    sep_ok = sep_L & sep_R;
    n_sep = sum(sep_ok, 'omitnan');
    fprintf('    Plateaus properly separated: %d/%d (%.1f%%)\n', n_sep, height(diagTable), 100*n_sep/height(diagTable));
    if ~all(sep_ok, 'omitnan')
        for i = find(~sep_ok & isfinite(sep_ok))'
            if ~sep_L(i)
                msg = sprintf('  ⚠ Run %d: PlateauL_max=%.2f >= dipL=%.2f', ...
                    diagTable.RunID(i), diagTable.PlateauL_max(i), dipL(i));
                fprintf('%s\n', msg);
                warnings{end+1} = msg;
            end
            if ~sep_R(i)
                msg = sprintf('  ⚠ Run %d: PlateauR_min=%.2f <= dipR=%.2f', ...
                    diagTable.RunID(i), diagTable.PlateauR_min(i), dipR(i));
                fprintf('%s\n', msg);
                warnings{end+1} = msg;
            end
        end
    else
        fprintf('    ✓ All plateaus properly separated\n');
    end
    fprintf('\n');
    
    % 4c) Aging growth (Spearman correlation)
    fprintf('4c) Aging growth check (Dip_area vs wait_time):\n');
    fprintf('    Computing Spearman correlation for each Tp...\n\n');
    
    unique_Tp = unique(diagTable.Tp, 'rows');
    aging_data = struct();
    
    for tp = unique_Tp'
        mask = diagTable.Tp == tp;
        wt_v = diagTable.WaitTime(mask);
        dip_v = diagTable.DipArea(mask);
        valid = isfinite(wt_v) & isfinite(dip_v) & wt_v > 0 & dip_v > 0;
        
        if sum(valid) >= 3
            wt_clean = wt_v(valid);
            dip_clean = dip_v(valid);
            try
                [rho, pval] = corr(wt_clean, dip_clean, 'type', 'Spearman');
                fprintf('    Tp=%.1f K: ρ = %.3f (p=%.4f), n=%d', tp, rho, pval, sum(valid));
                
                aging_data(tp).rho = rho;
                aging_data(tp).pval = pval;
                aging_data(tp).n_valid = sum(valid);
                aging_data(tp).wt = wt_clean;
                aging_data(tp).dip = dip_clean;
                
                if rho < 0
                    fprintf(' ⚠ NEGATIVE\n');
                    msg = sprintf('Aging: Tp=%.1f K negative correlation (rho=%.3f)', tp, rho);
                    warnings{end+1} = msg;
                elseif pval > 0.05
                    fprintf(' ⚠ NOT SIGNIFICANT\n');
                else
                    fprintf(' ✓\n');
                end
            catch
                fprintf('    Tp=%.1f K: correlation computation failed\n', tp);
            end
        else
            fprintf('    Tp=%.1f K: Insufficient valid points (%d)\n', tp, sum(valid));
        end
    end
    fprintf('\n');
    
    % 4d) FM baseline stability
    fprintf('4d) FM baseline stability (relative variation < 30%%):\n');
    for tp = unique_Tp'
        mask = diagTable.Tp == tp;
        fm_v = diagTable.FM_step(mask);
        fm_clean = fm_v(isfinite(fm_v));
        
        if numel(fm_clean) >= 2
            m = mean(fm_clean);
            s = std(fm_clean);
            rel_var = s / (abs(m) + eps);
            fprintf('    Tp=%.1f K: mean=%.6g, std=%.6g, rel_var=%.1f%%', ...
                tp, m, s, 100*rel_var);
            
            if rel_var > 0.3
                fprintf(' ⚠ HIGH\n');
                msg = sprintf('FM stability: Tp=%.1f K rel_var=%.1f%% > 30%%', tp, 100*rel_var);
                warnings{end+1} = msg;
            else
                fprintf(' ✓\n');
            end
        end
    end
    fprintf('\n');
    
    % 4e) Baseline drift check (correlation with wait_time)
    fprintf('4e) BASELINE DRIFT CHECK (correlation with wait_time):\n');
    fprintf('    Large correlation could indicate baseline drift mimicking aging.\n\n');
    
    for tp = unique_Tp'
        mask = diagTable.Tp == tp;
        wt_v = diagTable.WaitTime(mask);
        slope_v = diagTable.BaselineSlope(mask);
        valid = isfinite(wt_v) & isfinite(slope_v) & wt_v > 0;
        
        if sum(valid) >= 3
            wt_clean = wt_v(valid);
            slope_clean = slope_v(valid);
            try
                [rho_drift, pval_drift] = corr(wt_clean, slope_clean, 'type', 'Spearman');
                fprintf('    Tp=%.1f K: ρ(wait_time, baseline_slope) = %.3f (p=%.4f), n=%d', ...
                    tp, rho_drift, pval_drift, sum(valid));
                
                if abs(rho_drift) > 0.7
                    fprintf(' ⚠⚠ STRONG DRIFT\n');
                    msg = sprintf('Baseline drift: Tp=%.1f K strong correlation (rho=%.3f)', tp, rho_drift);
                    warnings{end+1} = msg;
                elseif abs(rho_drift) > 0.5
                    fprintf(' ⚠ MODERATE DRIFT\n');
                    msg = sprintf('Baseline drift: Tp=%.1f K moderate correlation (rho=%.3f)', tp, rho_drift);
                    warnings{end+1} = msg;
                else
                    fprintf(' ✓ STABLE\n');
                end
            catch
                fprintf('    Tp=%.1f K: drift computation failed\n', tp);
            end
        else
            fprintf('    Tp=%.1f K: Insufficient valid points\n', tp);
        end
    end
    fprintf('\n');
    
    % Summary statistics
    fprintf('STEP 5: Summary statistics\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    n_ok = sum(strcmp(diagTable.Status, 'ok'), 'omitnan');
    fprintf('Valid runs (status="ok"): %d/%d (%.1f%%)\n', n_ok, height(diagTable), 100*n_ok/height(diagTable));
    fprintf('NaN in FM_step: %d/%d\n', sum(isnan(diagTable.FM_step)), height(diagTable));
    fprintf('NaN in Dip_area: %d/%d\n', sum(isnan(diagTable.DipArea)), height(diagTable));
    fprintf('\n');
    
    % Plateau statistics
    n_pl = diagTable.nPlateauL(isfinite(diagTable.nPlateauL));
    if ~isempty(n_pl)
        fprintf('Plateau point statistics:\n');
        fprintf('  Min: %d\n', min(n_pl));
        fprintf('  Max: %d\n', max(n_pl));
        fprintf('  Mean: %.1f\n', mean(n_pl));
    end
    fprintf('\n');
    
    % Baseline slope statistics
    slopes_v = diagTable.BaselineSlope(isfinite(diagTable.BaselineSlope));
    if ~isempty(slopes_v)
        fprintf('Baseline slope distribution:\n');
        fprintf('  Min: %.6g\n', min(slopes_v));
        fprintf('  Max: %.6g\n', max(slopes_v));
        fprintf('  Mean: %.6g\n', mean(slopes_v));
        fprintf('  Std: %.6g\n', std(slopes_v));
    end
    fprintf('\n');
    
    % Plateau temperature ranges
    fprintf('STEP 6: Plateau temperature ranges used\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    for tp = unique_Tp'
        mask = diagTable.Tp == tp;
        pl_min_v = diagTable.PlateauL_min(mask);
        pl_max_v = diagTable.PlateauL_max(mask);
        pr_min_v = diagTable.PlateauR_min(mask);
        pr_max_v = diagTable.PlateauR_max(mask);
        
        pl_min_all = pl_min_v(isfinite(pl_min_v));
        pl_max_all = pl_max_v(isfinite(pl_max_v));
        pr_min_all = pr_min_v(isfinite(pr_min_v));
        pr_max_all = pr_max_v(isfinite(pr_max_v));
        
        fprintf('Tp=%.1f K:\n', tp);
        if ~isempty(pl_min_all)
            fprintf('  Plateau_L: [%.2f - %.2f] K (mean range: [%.2f, %.2f] K)\n', ...
                min(pl_min_all), max(pl_max_all), mean(pl_min_all), mean(pl_max_all));
        end
        if ~isempty(pr_min_all)
            fprintf('  Plateau_R: [%.2f - %.2f] K (mean range: [%.2f, %.2f] K)\n', ...
                min(pr_min_all), max(pr_max_all), mean(pr_min_all), mean(pr_max_all));
        end
    end
    fprintf('\n');
    
    % Plot generation
    fprintf('STEP 7: Creating plots for two Tp values\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    fig_files = {};
    
    % Select two Tp values
    if numel(unique_Tp) >= 2
        Tp_plot = [unique_Tp(1), unique_Tp(ceil(numel(unique_Tp)/2))];
    elseif numel(unique_Tp) == 1
        Tp_plot = unique_Tp(1);
    else
        Tp_plot = [];
    end
    
    for tp = Tp_plot
        fprintf('  Creating plot for Tp=%.1f K...\n', tp);
        fig = createRealDataPlot(state, diagTable, tp, cfg);
        if ~isempty(fig)
            fname = sprintf('RealData_Curves_Tp_%.1f_K.png', tp);
            saveas(fig, fname);
            fig_files{end+1} = fname;
            close(fig);
            fprintf('    ✓ Saved: %s\n', fname);
        end
    end
    fprintf('\n');
    
    % Final verdict
    fprintf('╔════════════════════════════════════════════════════════════════╗\n');
    fprintf('║  FINAL VERIFICATION REPORT - REAL DATA                        ║\n');
    fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');
    
    if isempty(warnings)
        fprintf('✓✓✓ ROBUST BASELINE STABLE - NO ISSUES ✓✓✓\n\n');
        overall = 'robust baseline stable';
    else
        fprintf('⚠ %d WARNINGS DETECTED:\n\n', numel(warnings));
        for i = 1:numel(warnings)
            fprintf('[%d] %s\n', i, warnings{i});
        end
        fprintf('\n');
        overall = 'baseline issues detected';
    end
    
    fprintf('OVERALL STATUS: %s\n\n', overall);
    
end

% ========================================================================
% HELPER FUNCTIONS
% ========================================================================

function diagTable = extractRealDiagnosticsTable(state)
    % Extract diagnostics from real pauseRuns produced by pipeline
    
    N = numel(state.pauseRuns);
    
    runid = (1:N)';
    tp = NaN(N, 1);
    wt = NaN(N, 1);
    tmin = NaN(N, 1);
    dip_area = NaN(N, 1);
    dip_depth = NaN(N, 1);
    fm_step = NaN(N, 1);
    baseline_slope = NaN(N, 1);
    status = cell(N, 1);
    pl_min = NaN(N, 1);
    pl_max = NaN(N, 1);
    pr_min = NaN(N, 1);
    pr_max = NaN(N, 1);
    n_pl = NaN(N, 1);
    n_pr = NaN(N, 1);
    
    for i = 1:N
        run = state.pauseRuns(i);
        
        % Basic info
        tp(i) = getFieldOrDefault(run, 'waitK', NaN);
        wt(i) = getFieldOrDefault(run, 'wait_time_min', NaN);
        
        % Metrics
        dip_area(i) = getFieldOrDefault(run, 'Dip_area', NaN);
        dip_depth(i) = getFieldOrDefault(run, 'AFM_amp', NaN);
        fm_step(i) = getFieldOrDefault(run, 'FM_step_mag', NaN);
        baseline_slope(i) = getFieldOrDefault(run, 'baseline_slope', NaN);
        status{i} = getFieldOrDefault(run, 'baseline_status', 'unknown');
        
        % Dip minimum location
        if isfield(run, 'DeltaM_sharp') && ~isempty(run.DeltaM_sharp)
            dM_s = run.DeltaM_sharp(:);
            T = run.T_common(:);
            valid_mask = isfinite(dM_s);
            if nnz(valid_mask) >= 1
                [~, idx_local] = min(dM_s(valid_mask));
                idx_global = find(valid_mask);
                tmin(i) = T(idx_global(idx_local));
            end
        end
        
        % Plateau temperatures
        tl = getFieldOrDefault(run, 'baseline_TL', NaN);
        if isfinite(tl)
            pl_min(i) = tl - 0.5;
            pl_max(i) = tl + 0.5;
            n_pl(i) = 5;
        end
        
        tr = getFieldOrDefault(run, 'baseline_TR', NaN);
        if isfinite(tr)
            pr_min(i) = tr - 0.5;
            pr_max(i) = tr + 0.5;
            n_pr(i) = 5;
        end
    end
    
    % Build table
    diagTable = table(runid, tp, wt, tmin, dip_area, dip_depth, fm_step, baseline_slope, status, ...
                      pl_min, pl_max, pr_min, pr_max, n_pl, n_pr, ...
                      'VariableNames', {'RunID', 'Tp', 'WaitTime', 'Tmin', 'DipArea', 'DipDepth', ...
                                        'FM_step', 'BaselineSlope', 'Status', ...
                                        'PlateauL_min', 'PlateauL_max', 'PlateauR_min', 'PlateauR_max', ...
                                        'nPlateauL', 'nPlateauR'});
    
end

function fig = createRealDataPlot(state, diagTable, Tp, cfg)
    % Create plot with real ΔM data, baseline, and plateau overlay
    
    % Find runs with this Tp
    idx_tp = find(diagTable.Tp == Tp);
    
    if isempty(idx_tp)
        fig = [];
        return;
    end
    
    % Get runs for this Tp
    run_indices = idx_tp;
    n_runs = numel(run_indices);
    
    fig = figure('Position', [100 100 1200 700]);
    hold on; grid on;
    
    % Color map
    colors = colormap(lines(max(n_runs, 3)));
    
    % Plot each run
    for j = 1:n_runs
        i = run_indices(j);
        run = state.pauseRuns(i);
        
        if ~isfield(run, 'T_common') || ~isfield(run, 'DeltaM')
            continue;
        end
        
        T = run.T_common(:);
        dM = run.DeltaM(:);
        
        wt = diagTable.WaitTime(i);
        label_str = sprintf('t_w=%.0f min', wt);
        
        plot(T, dM, 'o-', 'Color', colors(mod(j-1, size(colors,1))+1, :), ...
             'DisplayName', label_str, 'LineWidth', 1.5, 'MarkerSize', 3);
    end
    
    % Overlay dip window
    dipL = Tp - cfg.dip_window_K;
    dipR = Tp + cfg.dip_window_K;
    plot([dipL dipL], ylim(), 'r--', 'LineWidth', 2, 'DisplayName', 'Dip window', 'Alpha', 0.7);
    plot([dipR dipR], ylim(), 'r--', 'LineWidth', 2, 'HandleVisibility', 'off', 'Alpha', 0.7);
    
    % Labels and title
    xlabel('Temperature (K)', 'FontSize', 12);
    ylabel('ΔM (a.u.)', 'FontSize', 12);
    title(sprintf('Real Aging Data: ΔM(T) for Tp = %.1f K (Robust Baseline)', Tp), ...
          'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 10);
    
end

function val = getFieldOrDefault(s, fieldName, defaultVal)
    if isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = defaultVal;
    end
end
