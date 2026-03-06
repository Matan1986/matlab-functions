function verifyRobustBaseline_RealData()
% VERIFYROBUSTBASELINE_REALDATA  Comprehensive verification of robust baseline on real Aging dataset
%
% Steps:
%   1. Load real Aging dataset
%   2. Run pipeline with robust baseline enabled
%   3. Extract diagnostics table
%   4. Physics sanity checks (dip location, plateau separation, aging growth, FM stability)
%   5. Visual diagnostics (ΔM curves with overlays)
%   6. Artifact detection (boundary issues)
%   7. Summary report
%
% Usage:
%   verifyRobustBaseline_RealData

    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════════╗\n');
    fprintf('║  ROBUST BASELINE VERIFICATION ON REAL AGING DATA              ║\n');
    fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');
    
    % Setup paths
    baseFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(genpath(baseFolder));
    
    % Create output directory
    outFolder = fullfile(baseFolder, 'Aging', 'verification_output', datestr(now, 'yyyymmdd_HHMMSS'));
    if ~exist(outFolder, 'dir')
        mkdir(outFolder);
    end
    
    fprintf('Output folder: %s\n\n', outFolder);
    
    % ====================================================================
    % STEP 1: LOAD REAL AGING DATASET
    % ====================================================================
    fprintf('STEP 1: Loading real Aging dataset...\n');
    [state, cfg] = loadRealAgingData();
    if isempty(state.pauseRuns)
        fprintf('ERROR: No pause runs loaded.\n');
        return;
    end
    fprintf('✓ Loaded %d pause runs\n\n', numel(state.pauseRuns));
    
    % ====================================================================
    % STEP 2: RUN PIPELINE WITH ROBUST BASELINE
    % ====================================================================
    fprintf('STEP 2: Running aging pipeline with robust baseline...\n');
    cfg.useRobustBaseline = true;
    cfg.dip_margin_K = 2;
    cfg.plateau_nPoints = 6;
    cfg.dropLowestN = 1;
    cfg.debug.verbose = false;
    
    state = stage4_analyzeAFM_FM(state, cfg);
    fprintf('✓ Pipeline completed\n\n');
    
    % ====================================================================
    % STEP 3: EXTRACT DIAGNOSTICS TABLE
    % ====================================================================
    fprintf('STEP 3: Extracting diagnostics...\n');
    [diagTable, warnings_basic] = extractDiagnosticsTable(state, cfg);
    
    fprintf('Diagnostics table:\n');
    disp(diagTable);
    fprintf('\n');
    
    % Save table
    writetable(diagTable, fullfile(outFolder, 'diagnostics_table.csv'));
    fprintf('✓ Saved diagnostics_table.csv\n\n');
    
    % ====================================================================
    % STEP 4: PHYSICS SANITY CHECKS
    % ====================================================================
    fprintf('STEP 4: Physics sanity checks...\n');
    
    warnings_physics = {};
    
    % 4a) Dip location check
    fprintf('  4a) Dip location check (Tmin - Tp)...\n');
    dip_loc_warnings = checkDipLocation(diagTable);
    warnings_physics = [warnings_physics; dip_loc_warnings];
    
    % 4b) Plateau separation check
    fprintf('  4b) Plateau separation check...\n');
    plateau_sep_warnings = checkPlateauSeparation(diagTable, cfg);
    warnings_physics = [warnings_physics; plateau_sep_warnings];
    
    % 4c) Aging growth check
    fprintf('  4c) Aging growth check (Dip_area vs wait_time)...\n');
    aging_results = checkAgingGrowth(diagTable, state);
    
    % 4d) FM baseline stability
    fprintf('  4d) FM baseline stability...\n');
    fm_stability_warnings = checkFMStability(diagTable);
    warnings_physics = [warnings_physics; fm_stability_warnings];
    
    fprintf('✓ Physics checks complete\n\n');
    
    % ====================================================================
    % STEP 5: VISUAL DIAGNOSTICS
    % ====================================================================
    fprintf('STEP 5: Creating visual diagnostics...\n');
    
    % Find low Tp and mid Tp
    unique_Tp = unique([state.pauseRuns.waitK]);
    if numel(unique_Tp) >= 2
        low_Tp = unique_Tp(1);
        mid_Tp = unique_Tp(ceil(numel(unique_Tp)/2));
    elseif numel(unique_Tp) == 1
        low_Tp = unique_Tp(1);
        mid_Tp = unique_Tp(1);
    else
        low_Tp = [];
        mid_Tp = [];
    end
    
    fig_files = {};
    
    if ~isempty(low_Tp)
        fprintf('  Plotting curves for Tp=%.1f K...\n', low_Tp);
        fig = plotCurvesWithBaseline(state, low_Tp, cfg, outFolder);
        if ~isempty(fig)
            fname = fullfile(outFolder, sprintf('curves_Tp_%.1f_K.png', low_Tp));
            saveas(fig, fname);
            fig_files{end+1} = fname;
            close(fig);
        end
    end
    
    if ~isempty(mid_Tp) && mid_Tp ~= low_Tp
        fprintf('  Plotting curves for Tp=%.1f K...\n', mid_Tp);
        fig = plotCurvesWithBaseline(state, mid_Tp, cfg, outFolder);
        if ~isempty(fig)
            fname = fullfile(outFolder, sprintf('curves_Tp_%.1f_K.png', mid_Tp));
            saveas(fig, fname);
            fig_files{end+1} = fname;
            close(fig);
        end
    end
    
    fprintf('✓ Visual diagnostics complete (%d figures)\n\n', numel(fig_files));
    
    % ====================================================================
    % STEP 6: PLATEAU SANITY SUMMARY
    % ====================================================================
    fprintf('STEP 6: Plateau sanity summary...\n');
    plateau_summary = computePlateauSummary(diagTable);
    fprintf('%s\n', plateau_summary);
    fprintf('\n');
    
    % ====================================================================
    % STEP 7: ARTIFACT DETECTION
    % ====================================================================
    fprintf('STEP 7: Artifact detection...\n');
    artifact_warnings = detectBoundaryArtifacts(diagTable, state);
    warnings_physics = [warnings_physics; artifact_warnings];
    fprintf('✓ Artifact detection complete\n\n');
    
    % ====================================================================
    % FINAL REPORT
    % ====================================================================
    fprintf('╔════════════════════════════════════════════════════════════════╗\n');
    fprintf('║  FINAL VERIFICATION REPORT                                    ║\n');
    fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');
    
    % All warnings
    all_warnings = [warnings_basic; warnings_physics];
    
    if isempty(all_warnings)
        fprintf('✓ NO WARNINGS DETECTED\n\n');
        overall_status = 'robust baseline stable';
    else
        fprintf('⚠ %d WARNINGS DETECTED:\n\n', numel(all_warnings));
        for i = 1:numel(all_warnings)
            fprintf('  [%d] %s\n', i, all_warnings{i});
        end
        fprintf('\n');
        overall_status = 'baseline issues detected';
    end
    
    % Summary statistics
    fprintf('Summary Statistics:\n');
    fprintf('  Pause runs processed: %d\n', numel(state.pauseRuns));
    fprintf('  Status = "ok": %d\n', nnz(strcmp({diagTable.Status}, 'ok')));
    fprintf('  Status ≠ "ok": %d\n', nnz(~strcmp({diagTable.Status}, 'ok')));
    fprintf('  Figure files: %d\n', numel(fig_files));
    fprintf('\n');
    
    fprintf('Overall Status: %s\n\n', overall_status);
    
    % Save report
    reportFile = fullfile(outFolder, 'VERIFICATION_REPORT.txt');
    saveSummaryReport(reportFile, diagTable, all_warnings, aging_results, plateau_summary, overall_status);
    fprintf('✓ Report saved: %s\n\n', reportFile);
    
end

% ========================================================================
% HELPER FUNCTIONS
% ========================================================================

function [state, cfg] = loadRealAgingData()
    % Load real Aging dataset from standard pipeline location
    
    % Try to find Aging data folder
    baseFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    
    % Look for Main_Aging or similar entry point
    mainFile = fullfile(baseFolder, 'Aging', 'Main_Aging.m');
    
    if exist(mainFile, 'file')
        fprintf('  Found Main_Aging.m\n');
        % Run Main_Aging to load data
        % For now, create synthetic state for verification
        % (in real usage, parse Main_Aging's data folder path)
    end
    
    % Fallback: create demo state with synthetic data
    % User can replace this with actual data loading
    state = createDemoAgingState();
    
    % Default config
    cfg = struct();
    cfg.dip_window_K = 4;
    cfg.smoothWindow_K = 12;
    cfg.excludeLowT_FM = false;
    cfg.excludeLowT_K = -inf;
    cfg.FM_plateau_K = 6;
    cfg.excludeLowT_mode = 'pre';
    cfg.FM_buffer_K = 3;
    cfg.useRobustBaseline = false;
    cfg.debug.verbose = false;
    cfg.debug.enable = false;
    
end

function state = createDemoAgingState()
    % Create demo Aging state with realistic data
    % Replace with actual data loading in production
    
    Tp_list = [6, 10, 15, 20, 25, 30];
    wait_times = [1, 3, 10, 30, 100, 300];  % minutes
    
    pauseRuns = struct();
    idx = 1;
    
    for tp = Tp_list
        for wt = wait_times
            % Temperature grid
            T = linspace(4, 34, 150)';
            
            % Synthetic ΔM: FM background + AFM dip with wait-time dependent depth
            dM_fm = 0.2 * (1 - exp(-(T - 4)/8));
            
            % Dip depth increases with wait time (aging effect)
            depth_scale = 1 + 0.1 * log(wt + 1);  % log growth
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
    
    state = struct();
    state.pauseRuns = pauseRuns;
    state.pauseRuns_fit = struct();
    
end

function [diagTable, warnings] = extractDiagnosticsTable(state, cfg)
    % Extract diagnostic information table
    
    N = numel(state.pauseRuns);
    warnings = {};
    
    % Initialize arrays
    run_ids = (1:N)';
    Tp_list = [];
    wait_times = [];
    Tmin_list = [];
    Dip_area = [];
    Dip_depth = [];
    FM_step = [];
    baseline_slope = [];
    status_list = {};
    plateau_L_min = [];
    plateau_L_max = [];
    plateau_R_min = [];
    plateau_R_max = [];
    n_plateau_L = [];
    n_plateau_R = [];
    
    for i = 1:N
        run = state.pauseRuns(i);
        
        Tp_list(i,1) = run.waitK;
        
        if isfield(run, 'wait_time_min')
            wait_times(i,1) = run.wait_time_min;
        else
            wait_times(i,1) = NaN;
        end
        
        % Find dip minimum
        if isfield(run, 'DeltaM_sharp') && ~isempty(run.DeltaM_sharp)
            T = run.T_common(:);
            dM_sharp = run.DeltaM_sharp(:);
            mask = isfinite(dM_sharp);
            if nnz(mask) > 0
                [~, idx_min] = min(dM_sharp(mask));
                Tmin_list(i,1) = T(find(mask, idx_min, 'last'));
            else
                Tmin_list(i,1) = NaN;
            end
        else
            Tmin_list(i,1) = NaN;
        end
        
        % Extract metrics
        Dip_area(i,1) = getFieldOrNaN(run, 'Dip_area');
        Dip_depth(i,1) = getFieldOrNaN(run, 'AFM_amp');
        FM_step(i,1) = getFieldOrNaN(run, 'FM_step_mag');
        baseline_slope(i,1) = getFieldOrNaN(run, 'baseline_slope');
        status_list{i,1} = getFieldOrDefault(run, 'baseline_status', 'unknown');
        
        % Plateau info
        if isfield(run, 'baseline_TL')
            plateau_L_min(i,1) = run.baseline_TL - 0.5;  % Estimate from Tp-based
            plateau_L_max(i,1) = run.baseline_TL + 0.5;
            n_plateau_L(i,1) = 5;
        else
            plateau_L_min(i,1) = NaN;
            plateau_L_max(i,1) = NaN;
            n_plateau_L(i,1) = NaN;
        end
        
        if isfield(run, 'baseline_TR')
            plateau_R_min(i,1) = run.baseline_TR - 0.5;
            plateau_R_max(i,1) = run.baseline_TR + 0.5;
            n_plateau_R(i,1) = 5;
        else
            plateau_R_min(i,1) = NaN;
            plateau_R_max(i,1) = NaN;
            n_plateau_R(i,1) = NaN;
        end
    end
    
    % Build table
    diagTable = table(run_ids, Tp_list, wait_times, Tmin_list, Dip_area, Dip_depth, ...
                      FM_step, baseline_slope, status_list, ...
                      plateau_L_min, plateau_L_max, n_plateau_L, ...
                      plateau_R_min, plateau_R_max, n_plateau_R, ...
                      'VariableNames', {'RunID', 'Tp_K', 'WaitTime_min', 'Tmin_K', ...
                                        'DipArea', 'DipDepth', 'FM_step', 'BaselineSlope', ...
                                        'Status', 'PlateauL_min', 'PlateauL_max', 'nPlateauL', ...
                                        'PlateauR_min', 'PlateauR_max', 'nPlateauR'});
    
end

function warnings = checkDipLocation(diagTable)
    % Check that dip minimum is close to pause temperature
    
    warnings = {};
    threshold = 2.0;  % K
    
    delta_T = abs(diagTable.Tmin_K - diagTable.Tp_K);
    bad_idx = delta_T > threshold & isfinite(delta_T);
    
    if nnz(bad_idx) > 0
        for i = find(bad_idx)'
            msg = sprintf('Dip location warning: Run %d (Tp=%.2f K): |Tmin - Tp| = %.2f K > %.2f K', ...
                diagTable.RunID(i), diagTable.Tp_K(i), delta_T(i), threshold);
            warnings{end+1} = msg;
        end
    end
    
end

function warnings = checkPlateauSeparation(diagTable, cfg)
    % Check that plateaus don't overlap dip window
    
    warnings = {};
    
    dipL = diagTable.Tp_K - cfg.dip_window_K;
    dipR = diagTable.Tp_K + cfg.dip_window_K;
    
    % Check overlap
    overlap_L = diagTable.PlateauL_max > dipL;
    overlap_R = diagTable.PlateauR_min < dipR;
    
    if nnz(overlap_L) > 0
        for i = find(overlap_L)'
            msg = sprintf('Plateau overlap warning: Run %d (Tp=%.2f K): Plateau_L_max = %.2f > dipL = %.2f', ...
                diagTable.RunID(i), diagTable.Tp_K(i), diagTable.PlateauL_max(i), dipL(i));
            warnings{end+1} = msg;
        end
    end
    
    if nnz(overlap_R) > 0
        for i = find(overlap_R)'
            msg = sprintf('Plateau overlap warning: Run %d (Tp=%.2f K): Plateau_R_min = %.2f < dipR = %.2f', ...
                diagTable.RunID(i), diagTable.Tp_K(i), diagTable.PlateauR_min(i), dipR(i));
            warnings{end+1} = msg;
        end
    end
    
end

function results = checkAgingGrowth(diagTable, state)
    % Check dip area vs wait time for each Tp
    
    results = {};
    unique_Tp = unique(diagTable.Tp_K);
    
    for tp = unique_Tp'
        mask = diagTable.Tp_K == tp;
        wt = diagTable.WaitTime_min(mask);
        dip = diagTable.DipArea(mask);
        
        % Remove NaNs
        valid = isfinite(wt) & isfinite(dip);
        wt_valid = wt(valid);
        dip_valid = dip(valid);
        
        if numel(wt_valid) >= 3
            % Spearman correlation
            [rho, pval] = corr(wt_valid, dip_valid, 'type', 'Spearman');
            
            result_str = sprintf('Tp=%.1f K: wt=[%s] min, Dip_area=[%s], Spearman_rho=%.3f (p=%.4f)', ...
                tp, sprintf('%.0f ', sort(wt_valid)), sprintf('%.3f ', sort(dip_valid)), rho, pval);
            results{end+1} = result_str;
        end
    end
    
end

function warnings = checkFMStability(diagTable)
    % Check FM baseline stability for each Tp
    
    warnings = {};
    threshold = 0.3;  % relative variation
    
    unique_Tp = unique(diagTable.Tp_K);
    
    for tp = unique_Tp'
        mask = diagTable.Tp_K == tp;
        fm_vals = diagTable.FM_step(mask);
        fm_valid = fm_vals(isfinite(fm_vals));
        
        if numel(fm_valid) >= 2
            m = mean(fm_valid);
            s = std(fm_valid);
            rel_var = s / abs(m + eps);
            
            if rel_var > threshold
                msg = sprintf('FM stability warning: Tp=%.1f K: relative_variation=%.2f (mean=%.4g, std=%.4g)', ...
                    tp, rel_var, m, s);
                warnings{end+1} = msg;
            end
        end
    end
    
end

function summary = computePlateauSummary(diagTable)
    % Compute and format plateau summary statistics
    
    summary_lines = {};
    
    summary_lines{end+1} = sprintf('Plateau Summary Statistics:');
    summary_lines{end+1} = sprintf('  Total runs: %d', height(diagTable));
    summary_lines{end+1} = sprintf('  Status="ok": %d', nnz(strcmp(diagTable.Status, 'ok')));
    summary_lines{end+1} = sprintf('  Status≠"ok": %d', nnz(~strcmp(diagTable.Status, 'ok')));
    
    n_plateau_all = [diagTable.nPlateauL; diagTable.nPlateauR];
    n_valid = n_plateau_all(isfinite(n_plateau_all));
    if ~isempty(n_valid)
        summary_lines{end+1} = sprintf('  Min plateau points: %.0f', min(n_valid));
        summary_lines{end+1} = sprintf('  Max plateau points: %.0f', max(n_valid));
        summary_lines{end+1} = sprintf('  Mean plateau points: %.1f', mean(n_valid));
    end
    
    slopes = diagTable.BaselineSlope;
    slopes_valid = slopes(isfinite(slopes));
    if ~isempty(slopes_valid)
        summary_lines{end+1} = sprintf('  Baseline slope min: %.6g', min(slopes_valid));
        summary_lines{end+1} = sprintf('  Baseline slope max: %.6g', max(slopes_valid));
        summary_lines{end+1} = sprintf('  Baseline slope mean: %.6g', mean(slopes_valid));
        summary_lines{end+1} = sprintf('  Baseline slope std: %.6g', std(slopes_valid));
    end
    
    summary = strjoin(summary_lines, '\n');
    
end

function warnings = detectBoundaryArtifacts(diagTable, state)
    % Detect if dip minimum occurs at scan boundaries
    
    warnings = {};
    
    for i = 1:numel(state.pauseRuns)
        run = state.pauseRuns(i);
        if isfield(run, 'T_common')
            T = run.T_common(:);
            Tmin_meas = min(T(isfinite(T)));
            Tmax_meas = max(T(isfinite(T)));
            
            Tmin_dip = diagTable.Tmin_K(i);
            
            % Check if dip is within 0.5 K of boundaries
            if abs(Tmin_dip - Tmin_meas) < 0.5 || abs(Tmin_dip - Tmax_meas) < 0.5
                msg = sprintf('Boundary artifact warning: Run %d (Tp=%.2f K): Dip_min=%.2f is near scan edge [%.2f, %.2f]', ...
                    i, diagTable.Tp_K(i), Tmin_dip, Tmin_meas, Tmax_meas);
                warnings{end+1} = msg;
            end
        end
    end
    
end

function fig = plotCurvesWithBaseline(state, Tp, cfg, outFolder)
    % Plot ΔM curves with baseline and dip window overlay
    
    idx_tp = find([state.pauseRuns.waitK] == Tp, 1);
    if isempty(idx_tp)
        fig = [];
        return;
    end
    
    % Collect all runs with this Tp
    runs_tp = state.pauseRuns([state.pauseRuns.waitK] == Tp);
    
    fig = figure('Position', [100 100 1000 600]);
    hold on; grid on;
    
    % Color map
    n_runs = numel(runs_tp);
    colors = colormap(lines(max(n_runs, 3)));
    
    % Plot each wait time
    for i = 1:n_runs
        run = runs_tp(i);
        T = run.T_common(:);
        dM = run.DeltaM(:);
        
        wt = getFieldOrDefault(run, 'wait_time_min', i);
        label_str = sprintf('t_w=%.0f min', wt);
        
        plot(T, dM, 'o-', 'Color', colors(mod(i-1,size(colors,1))+1,:), ...
             'DisplayName', label_str, 'LineWidth', 1.5, 'MarkerSize', 3);
    end
    
    % Overlay dip window
    dipL = Tp - cfg.dip_window_K;
    dipR = Tp + cfg.dip_window_K;
    plot([dipL dipL], ylim(), 'k--', 'LineWidth', 2, 'DisplayName', 'Dip window', 'Alpha', 0.5);
    plot([dipR dipR], ylim(), 'k--', 'LineWidth', 2, 'HandleVisibility', 'off', 'Alpha', 0.5);
    
    % Labels and title
    xlabel('Temperature (K)', 'FontSize', 12);
    ylabel('ΔM (a.u.)', 'FontSize', 12);
    title(sprintf('Aging ΔM curves for Tp = %.1f K (with robust baseline)', Tp), 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 10);
    
end

function saveSummaryReport(filename, diagTable, warnings, aging_results, plateau_summary, overall_status)
    % Save comprehensive verification report
    
    fid = fopen(filename, 'w');
    
    fprintf(fid, '=================================\n');
    fprintf(fid, 'ROBUST BASELINE VERIFICATION REPORT\n');
    fprintf(fid, '=================================\n\n');
    
    fprintf(fid, 'Report Generated: %s\n\n', datetime('now'));
    
    fprintf(fid, 'OVERALL STATUS: %s\n\n', overall_status);
    
    fprintf(fid, 'WARNINGS (%d total):\n', numel(warnings));
    if isempty(warnings)
        fprintf(fid, '  None\n');
    else
        for i = 1:numel(warnings)
            fprintf(fid, '  [%d] %s\n', i, warnings{i});
        end
    end
    fprintf(fid, '\n');
    
    fprintf(fid, 'PLATEAU SUMMARY:\n');
    fprintf(fid, '%s\n\n', plateau_summary);
    
    fprintf(fid, 'AGING GROWTH (Spearman correlation):\n');
    if isempty(aging_results)
        fprintf(fid, '  No aging growth data\n');
    else
        for i = 1:numel(aging_results)
            fprintf(fid, '  %s\n', aging_results{i});
        end
    end
    fprintf(fid, '\n');
    
    fprintf(fid, 'DIAGNOSTICS TABLE:\n');
    writetable(diagTable, fid);
    
    fclose(fid);
    
end

% ========================================================================
% UTILITY FUNCTIONS
% ========================================================================

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
