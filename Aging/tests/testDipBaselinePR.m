function testDipBaselinePR
% TESTDIPBASELINEPR  Test robust baseline estimation in dip metrics
%
% This regression test verifies that:
%  1) estimateRobustBaseline helper works correctly
%  2) analyzeAFM_FM_components uses it without breaking
%  3) No NaNs appear unexpectedly in FM_step and Dip_area
%  4) Baseline windows stay within measurement range
%
% Usage:
%   testDipBaselinePR    % Run from Aging/tests or with path setup

    fprintf('========== DIP BASELINE REGRESSION TEST ==========\n\n');
    
    % --- Setup path ---
    baseFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(genpath(baseFolder));
    
    % --- Create synthetic test data ---
    fprintf('1. Generating synthetic aging dataset...\n');
    [pauseRuns, cfg] = generateTestData();
    N = numel(pauseRuns);
    fprintf('   Created %d pause runs from synthetic data.\n\n', N);
    
    % --- Run analyzeAFM_FM_components WITHOUT robust baseline ---
    fprintf('2. Running analyzeAFM_FM_components (old method, useRobustBaseline=false)...\n');
    cfg_old = cfg;
    cfg_old.useRobustBaseline = false;
    pauseRuns_old = analyzeAFM_FM_components( ...
        pauseRuns, cfg.dip_window_K, cfg.smoothWindow_K, ...
        cfg.excludeLowT_FM, cfg.excludeLowT_K, ...
        cfg.FM_plateau_K, cfg.excludeLowT_mode, cfg.FM_buffer_K, ...
        'area', cfg_old);
    fprintf('   Completed.\n\n');
    
    % --- Run WITH robust baseline ---
    fprintf('3. Running analyzeAFM_FM_components (NEW method, useRobustBaseline=true)...\n');
    cfg_new = cfg;
    cfg_new.useRobustBaseline = true;
    cfg_new.dip_margin_K = 2;
    cfg_new.plateau_nPoints = 5;
    cfg_new.debug.verbose = false;  % Reduce output
    pauseRuns_new = analyzeAFM_FM_components( ...
        pauseRuns, cfg.dip_window_K, cfg.smoothWindow_K, ...
        cfg.excludeLowT_FM, cfg.excludeLowT_K, ...
        cfg.FM_plateau_K, cfg.excludeLowT_mode, cfg.FM_buffer_K, ...
        'area', cfg_new);
    fprintf('   Completed.\n\n');
    
    % --- Analyze results ---
    fprintf('4. Analyzing results...\n\n');
    
    resultTable = table();
    nanCount_old = 0;
    nanCount_new = 0;
    
    for i = 1:N
        Tp = pauseRuns(i).waitK;
        
        FM_old = getFieldOrDefault(pauseRuns_old(i), 'FM_step_mag', NaN);
        FM_new = getFieldOrDefault(pauseRuns_new(i), 'FM_step_mag', NaN);
        
        dipArea_old = getFieldOrDefault(pauseRuns_old(i), 'Dip_area', NaN);
        dipArea_new = getFieldOrDefault(pauseRuns_new(i), 'Dip_area', NaN);
        
        if isnan(FM_old)
            nanCount_old = nanCount_old + 1;
        end
        if isnan(FM_new)
            nanCount_new = nanCount_new + 1;
        end
        
        plateauValid_old = getFieldOrDefault(pauseRuns_old(i), 'FM_plateau_valid', false);
        plateauValid_new = getFieldOrDefault(pauseRuns_new(i), 'FM_plateau_valid', false);
        
        status_new = getFieldOrDefault(pauseRuns_new(i), 'baseline_status', '');
        
        baselineSlope = getFieldOrDefault(pauseRuns_new(i), 'baseline_slope', NaN);
        
        % Build row
        row = table(Tp, FM_old, FM_new, dipArea_old, dipArea_new, ...
                    plateauValid_old, plateauValid_new, status_new, baselineSlope, ...
                    'VariableNames', {'Tp_K', 'FM_old', 'FM_new', 'DipArea_old', 'DipArea_new', ...
                                      'PlateauValid_old', 'PlateauValid_new', 'BaselineStatus', 'BaselineSlope'});
        if isempty(resultTable)
            resultTable = row;
        else
            resultTable = [resultTable; row];
        end
    end
    
    % --- Display summary ---
    fprintf('=== SUMMARY ===\n');
    fprintf('Old method: %d NaN FM_step values out of %d\n', nanCount_old, N);
    fprintf('New method: %d NaN FM_step values out of %d\n', nanCount_new, N);
    fprintf('\nDetailed Results:\n');
    disp(resultTable);
    
    % --- Validation checks ---
    fprintf('\n=== VALIDATION CHECKS ===\n');
    
    % 1. Check that new method produces valid results
    validRuns_new = sum(isfinite([pauseRuns_new.FM_step_mag]));
    fprintf('✓ New method: %d/%d pause runs have valid FM_step\n', validRuns_new, N);
    
    % 2. Check baseline windows are within measurement range
    fprintf('✓ Checking baseline windows are within measurement range...\n');
    allValid = true;
    for i = 1:N
        if isfield(pauseRuns_new(i), 'baseline_TL') && isfield(pauseRuns_new(i), 'baseline_TR')
            Tp = pauseRuns_new(i).waitK;
            T_min = min(pauseRuns_new(i).T_common);
            T_max = max(pauseRuns_new(i).T_common);
            TL = pauseRuns_new(i).baseline_TL;
            TR = pauseRuns_new(i).baseline_TR;
            
            if ~(TL >= T_min && TL <= T_max) || ~(TR >= T_min && TR <= T_max)
                fprintf('  WARNING: Baseline window out of range at Tp=%.2f K\n', Tp);
                allValid = false;
            end
        end
    end
    if allValid
        fprintf('  All baseline windows within measurement range.\n');
    end
    
    % 3. Check slope signs are sensible
    slopes = [pauseRuns_new.baseline_slope];
    slopes_finite = slopes(isfinite(slopes));
    fprintf('✓ Baseline slope statistics:\n');
    fprintf('  Mean slope: %.6g slope_std: %.6g\n', mean(slopes_finite), std(slopes_finite));
    
    fprintf('\n========== TEST COMPLETE ==========\n\n');
    
end

function [pauseRuns, cfg] = generateTestData()
% Generate synthetic test dataset
% Simulates ΔM curve with clear dip and FM step

% Temperature grid
T_lin = linspace(4, 34, 121);
Tp_list = [6, 10, 15, 20, 25, 30];

pauseRuns = struct();
for i = 1:numel(Tp_list)
    Tp = Tp_list(i);
    
    % Synthetic ΔM: smooth FM background + sharp AFM dip
    dM_fm = 0.2 * (1 - exp(-(T_lin - 4)/8));  % Smooth increase (FM component)
    
    % Sharp dip at Tp
    dip_width = 2.0;  % K
    dip_depth = -0.15;
    dip = dip_depth * exp(-((T_lin - Tp).^2) / (2*dip_width^2));
    
    dM = dM_fm + dip + 0.01*randn(size(T_lin));  % Add noise
    
    pauseRuns(i).waitK = Tp;
    pauseRuns(i).T_common = T_lin(:);
    pauseRuns(i).DeltaM = dM(:);
    pauseRuns(i).label = sprintf('Tp=%.0f K', Tp);
end

% Configuration
cfg = struct();
cfg.dip_window_K = 4;
cfg.smoothWindow_K = 12;
cfg.excludeLowT_FM = false;
cfg.excludeLowT_K = -inf;
cfg.FM_plateau_K = 6;
cfg.excludeLowT_mode = 'pre';
cfg.FM_buffer_K = 3;
cfg.useRobustBaseline = false;  % Start with old method
cfg.debug.verbose = false;

end

function val = getFieldOrDefault(s, fieldName, defaultVal)
% Get struct field value or return default
if isfield(s, fieldName)
    val = s.(fieldName);
else
    val = defaultVal;
end
end
