%% Simple test: Load data and run three methods
% This is a minimal test to verify the script works
clearvars; clc;

outFile = 'C:\Dev\matlab-functions\scripts\validation_output.txt';
diary(outFile);

fprintf('===============================================\n');
fprintf('DIRECT METHOD STABILITY VALIDATION\n');
fprintf('===============================================\n\n');

try
    %% Setup paths
    thisFile = mfilename('fullpath');
    scriptsDir = fileparts(thisFile);
    repoRoot = fileparts(fileparts(scriptsDir));
    addpath(genpath(fullfile(repoRoot, 'Aging')));
    addpath(genpath(fullfile(repoRoot, 'General ver2')));
    
    fprintf('[SETUP] Paths configured\n');
    
    %% Generate synthetic data with realistic structure
    fprintf('[STEP 1] Generating synthetic data...\n');
    
    Tmin = 5;
    Tmax = 25;
    nT = 150;
    T = linspace(Tmin, Tmax, nT)';
    
    % Realistic dip structure
    Tp = 10;
    dip_depth = -0.5;
    dip_width = 1.5;
    background = -0.1 * (T - Tmin) / (Tmax - Tmin);
    dip = dip_depth * exp(-((T - Tp).^2) / (2 * dip_width^2));
    DeltaM = background + dip + 0.02 * randn(size(T));
    DeltaM_signed = DeltaM;
    
    fprintf('  T range: [%.2f, %.2f] K, %d points\n', min(T), max(T), numel(T));
    fprintf('  Tp (pause temp): %.2f K\n', Tp);
    fprintf('  ✓ Data generated\n\n');
    
    %% Setup config
    fprintf('[STEP 2] Setting up configuration...\n');
    
    cfg = struct();
    cfg.dip_window_K = 1;
    cfg.smoothWindow_K = 2;
    cfg.excludeLowT_FM = false;
    cfg.excludeLowT_K = -inf;
    cfg.FM_plateau_K = 6;
    cfg.excludeLowT_mode = 'pre';
    cfg.FM_buffer_K = 3;
    cfg.AFM_metric_main = 'area';
    cfg.FMConvention = 'leftMinusRight';
    cfg.dip_margin_K = 2;
    cfg.plateau_nPoints = 6;
    cfg.dropLowestN = 1;
    cfg.dropHighestN = 0;
    cfg.plateau_agg = 'median';
    cfg.FM_plateau_minWidth_K = 1.0;
    cfg.FM_plateau_minPoints = 12;
    cfg.FM_plateau_maxAllowedSlope = 0.02;
    cfg.FM_plateau_allowNarrowFallback = true;
    
    fprintf('  Config prepared\n');
    fprintf('  smoothWindow_K = %d, dip_window_K = %.2f\n', cfg.smoothWindow_K, cfg.dip_window_K);
    fprintf('  ✓ Ready\n\n');
    
    %% Test three methods
    fprintf('[STEP 3] Testing baseline run with three methods...\n\n');
    
    % Core direct
    fprintf('  Testing core direct method...\n');
    try
        runIn = struct();
        runIn.T_common = T;
        runIn.DeltaM = DeltaM;
        runIn.waitK = Tp;
        runIn.DeltaM_signed = DeltaM_signed;
        
        out_core = analyzeAFM_FM_components( ...
            runIn, cfg.dip_window_K, cfg.smoothWindow_K, ...
            cfg.excludeLowT_FM, cfg.excludeLowT_K, ...
            cfg.FM_plateau_K, cfg.excludeLowT_mode, cfg.FM_buffer_K, ...
            cfg.AFM_metric_main, cfg);
        
        % Extract AFM and FM
        AFM_core = NaN;
        if isfield(out_core, 'AFM_area') && isfinite(out_core.AFM_area)
            AFM_core = out_core.AFM_area;
        elseif isfield(out_core, 'AFM_amp') && isfinite(out_core.AFM_amp)
            AFM_core = out_core.AFM_amp;
        end
        
        FM_core = NaN;
        if isfield(out_core, 'FM_step_raw') && isfinite(out_core.FM_step_raw)
            FM_core = out_core.FM_step_raw;
        elseif isfield(out_core, 'FM_step_mag') && isfinite(out_core.FM_step_mag)
            FM_core = out_core.FM_step_mag;
        elseif isfield(out_core, 'FM_abs') && isfinite(out_core.FM_abs)
            FM_core = out_core.FM_abs;
        end
        
        fprintf('    AFM = %.6g, FM = %.6g\n', AFM_core, FM_core);
        if isfinite(AFM_core) && isfinite(FM_core)
            fprintf('    ✓ PASS\n\n');
        else
            fprintf('    ⚠ PARTIAL (missing fields)\n\n');
        end
    catch ME
        fprintf('    ✗ FAIL: %s\n\n', ME.message);
        AFM_core = NaN;
        FM_core = NaN;
    end
    
    % Derivative-assisted
    fprintf('  Testing derivative-assisted method...\n');
    try
        out_deriv = analyzeAFM_FM_derivative(T, DeltaM, Tp, cfg);
        
        % Extract AFM and FM
        AFM_deriv = NaN;
        if isfield(out_deriv, 'AFM_area') && isfinite(out_deriv.AFM_area)
            AFM_deriv = out_deriv.AFM_area;
        elseif isfield(out_deriv, 'AFM_amp') && isfinite(out_deriv.AFM_amp)
            AFM_deriv = out_deriv.AFM_amp;
        end
        
        FM_deriv = NaN;
        if isfield(out_deriv, 'FM_step_raw') && isfinite(out_deriv.FM_step_raw)
            FM_deriv = out_deriv.FM_step_raw;
        elseif isfield(out_deriv, 'FM_step_mag') && isfinite(out_deriv.FM_step_mag)
            FM_deriv = out_deriv.FM_step_mag;
        elseif isfield(out_deriv, 'FM_abs') && isfinite(out_deriv.FM_abs)
            FM_deriv = out_deriv.FM_abs;
        end
        
        fprintf('    AFM = %.6g, FM = %.6g\n', AFM_deriv, FM_deriv);
        if isfinite(AFM_deriv) && isfinite(FM_deriv)
            fprintf('    ✓ PASS\n\n');
        else
            fprintf('    ⚠ PARTIAL (missing fields)\n\n');
        end
    catch ME
        fprintf('    ✗ FAIL: %s\n\n', ME.message);
        AFM_deriv = NaN;
        FM_deriv = NaN;
    end
    
    % Robust-baseline
    fprintf('  Testing robust-baseline method...\n');
    try
        cfg_robust = cfg;
        cfg_robust.useRobustBaseline = true;
        
        runIn_robust = struct();
        runIn_robust.T_common = T;
        runIn_robust.DeltaM = DeltaM;
        runIn_robust.waitK = Tp;
        runIn_robust.DeltaM_signed = DeltaM_signed;
        
        out_robust = analyzeAFM_FM_components( ...
            runIn_robust, cfg_robust.dip_window_K, cfg_robust.smoothWindow_K, ...
            cfg_robust.excludeLowT_FM, cfg_robust.excludeLowT_K, ...
            cfg_robust.FM_plateau_K, cfg_robust.excludeLowT_mode, cfg_robust.FM_buffer_K, ...
            cfg_robust.AFM_metric_main, cfg_robust);
        
        % Extract AFM and FM
        AFM_robust = NaN;
        if isfield(out_robust, 'AFM_area') && isfinite(out_robust.AFM_area)
            AFM_robust = out_robust.AFM_area;
        elseif isfield(out_robust, 'AFM_amp') && isfinite(out_robust.AFM_amp)
            AFM_robust = out_robust.AFM_amp;
        end
        
        FM_robust = NaN;
        if isfield(out_robust, 'FM_step_raw') && isfinite(out_robust.FM_step_raw)
            FM_robust = out_robust.FM_step_raw;
        elseif isfield(out_robust, 'FM_step_mag') && isfinite(out_robust.FM_step_mag)
            FM_robust = out_robust.FM_step_mag;
        elseif isfield(out_robust, 'FM_abs') && isfinite(out_robust.FM_abs)
            FM_robust = out_robust.FM_abs;
        end
        
        fprintf('    AFM = %.6g, FM = %.6g\n', AFM_robust, FM_robust);
        if isfinite(AFM_robust) && isfinite(FM_robust)
            fprintf('    ✓ PASS\n\n');
        else
            fprintf('    ⚠ PARTIAL (missing fields)\n\n');
        end
    catch ME
        fprintf('    ✗ FAIL: %s\n\n', ME.message);
        AFM_robust = NaN;
        FM_robust = NaN;
    end
    
    %% Summary
    fprintf('===============================================\n');
    fprintf('BASELINE RESULTS SUMMARY\n');
    fprintf('===============================================\n\n');
    
    fprintf('%-25s %15s %15s\n', 'Method', 'AFM', 'FM');
    fprintf('%s\n', repmat('-', 55, 1));
    fprintf('%-25s %15.6g %15.6g\n', 'Core direct', AFM_core, FM_core);
    fprintf('%-25s %15.6g %15.6g\n', 'Derivative-assisted', AFM_deriv, FM_deriv);
    fprintf('%-25s %15.6g %15.6g\n', 'Robust-baseline', AFM_robust, FM_robust);
    fprintf('\n');
    
    % Count valid results
    nValid = nnz(isfinite([AFM_core, FM_core, AFM_deriv, FM_deriv, AFM_robust, FM_robust]));
    fprintf('Valid results: %d / 6\n', nValid);
    
    if nValid == 6
        fprintf('\n✓✓✓ ALL TESTS PASSED ✓✓✓\n');
        fprintf('\nInterpretation:\n');
        fprintf('- All three methods successfully computed AFM and FM values\n');
        fprintf('- Core and robust methods use same dip backbone but different FM\n');
        fprintf('- Derivative method redefines FM from outside-dip median\n');
        fprintf('\nDifferences in AFM and FM values show sensitivity to method choice.\n');
        fprintf('Use compare_direct_method_stability.m for full parameter sweep\n');
        fprintf('and noise robustness analysis.\n\n');
    else
        fprintf('\n⚠ Some methods did not produce valid outputs.\n');
        fprintf('Check that analyzeAFM_FM_components and analyzeAFM_FM_derivative\n');
        fprintf('are returning expected fields (AFM_area/AFM_amp, FM_step_raw/FM_abs).\n\n');
    end
    
    fprintf('Validation complete at %s\n', datestr(now));
    
catch ME
    fprintf('\nERROR: %s\n', ME.message);
    fprintf('Stack trace:\n%s\n', ME.getReport);
end

diary off;
disp(['Output written to: ' outFile]);
