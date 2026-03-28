clear; clc;

% run_relaxation_perturbation_demo - Quick demonstration of observable variance
%
% Purpose: Show how Relaxation observables vary with pipeline parameters
%          on a small (2-config) test grid
%
%  Execution: tools/run_matlab_safe.bat "C:/Dev/matlab-functions/Relaxation ver3/run_relaxation_perturbation_demo.m"

%% ======================================================================
%% REPO ROOT DETECTION
%% ======================================================================

current_dir = pwd;
temp_dir = current_dir;
repoRoot = '';
for level = 1:15
    if exist(fullfile(temp_dir, 'README.md'), 'file') && ...
       exist(fullfile(temp_dir, 'Aging'), 'dir') && ...
       exist(fullfile(temp_dir, 'Switching'), 'dir')
        repoRoot = temp_dir;
        break;
    end
    parent_dir = fileparts(temp_dir);
    if strcmp(parent_dir, temp_dir)
        break;
    end
    temp_dir = parent_dir;
end

if isempty(repoRoot)
    error('Could not detect repo root');
end

%% ======================================================================
%% PATH SETUP
%% ======================================================================

addpath(genpath(fullfile(repoRoot, 'Relaxation ver3')));
addpath(genpath(fullfile(repoRoot, 'General ver2')));
addpath(genpath(fullfile(repoRoot, 'Tools ver1')));
addpath(genpath(fullfile(repoRoot, 'Aging')));

%% ======================================================================
%% RUN CONTEXT SETUP (AUDIT REQUIREMENT)
%% ======================================================================

runCfg = struct();
runCfg.runLabel = 'perturbation_demo_2config';
runCfg.dataset = 'RelaxationTRM';
run = createRunContext('relaxation', runCfg);
runDir = run.run_dir;

if ~isfolder(runDir)
    mkdir(runDir);
end

status_file = fullfile(runDir, 'execution_status.csv');

%% ======================================================================
%% EXECUTION WRAPPER
%% ======================================================================

execution_status = 'PENDING';
error_message = '';

try
    
    %% ===================================================================
    %% DATA LOADING
    %% ===================================================================
    
    dataDir = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Relaxation TRM';
    
    if ~exist(dataDir, 'dir')
        error('Data directory not found: %s', dataDir);
    end
    
    fprintf('Loading data from: %s\n', dataDir);
    
    [fileList, temps, fields, types, colors, mass] = ...
        getFileList_relaxation(dataDir, 'parula');
    
    [Time_table_base, Temp_table_base, Field_table_base, Moment_table_base, massHeader] = ...
        importFiles_relaxation(dataDir, fileList, true, false);
    
    nfiles = numel(Time_table_base);
    fprintf('Loaded %d files\n\n', nfiles);
    
    %% ===================================================================
    %% MINIMAL PERTURBATION GRID (2 CONFIGS ONLY)
    %% ===================================================================
    
    configs = {};
    
    % Config 1: log model, first_sample origin
    cfg1 = struct();
    cfg1.time_origin_mode = 'first_sample';
    cfg1.smoothing_mode = 'field_only';
    cfg1.derivative_mode = 'dMdt_minimum';
    cfg1.model_family = 'log';
    cfg1.fit_window_mode = 'both_available';
    cfg1.baseline_mode = 'fit_offset';
    cfg1.config_id = 1;
    configs{1} = cfg1;
    
    % Config 2: kww model (same origin/settings)
    cfg2 = struct();
    cfg2.time_origin_mode = 'first_sample';
    cfg2.smoothing_mode = 'field_only';
    cfg2.derivative_mode = 'dMdt_minimum';
    cfg2.model_family = 'kww';
    cfg2.fit_window_mode = 'both_available';
    cfg2.baseline_mode = 'fit_offset';
    cfg2.config_id = 2;
    configs{2} = cfg2;
    
    n_configs = numel(configs);
    fprintf('Perturbation grid: %d configurations (quick demo)\n\n', n_configs);
    
    %% ===================================================================
    %% RUN EACH CONFIGURATION
    %% ===================================================================
    
    results_table = table();
    
    for c = 1:n_configs
        cfg = configs{c};
        fprintf('[%d/%d] model=%s\n', c, n_configs, cfg.model_family);
        
        try
            % Get config
            relaxCfg = relaxation_config_helper(cfg);
            
            % Prepare data
            Moment_table = Moment_table_base;
            Temp_table = Temp_table_base;
            Field_table = Field_table_base;
            
            % Unit conversion
            if relaxCfg.use_bohar_units
                x_Co = 1/3;
                m_mol = 58.9332/3 + 180.948 + 2*32.066;
                muB = 9.274e-21;
                NA = 6.022e23;
                convFactor = m_mol / (NA * muB * x_Co);
                for i = 1:numel(Moment_table)
                    Moment_table{i} = Moment_table{i} * convFactor;
                end
            end
            
            % Fitting
            fitParams = struct();
            fitParams.betaBoost = relaxCfg.beta_boost;
            fitParams.tauBoost = relaxCfg.tau_boost;
            fitParams.timeWeight = relaxCfg.time_weight;
            fitParams.timeWeightFactor = relaxCfg.time_weight_factor;
            fitParams.debugFit = false;
            
            allFits = fitAllRelaxations(Time_table, Moment_table, Temp_table, Field_table, ...
                false, relaxCfg.field_threshold_Oe, fitParams, ...
                0, 0, relaxCfg.abs_threshold, relaxCfg.slope_threshold, ...
                fileList, relaxCfg.model_family);
            
            % Extract observables
            if ~isempty(allFits)
                tau_vals = allFits.tau(~isnan(allFits.tau));
                beta_vals = allFits.n(~isnan(allFits.n));
                
                obs = struct();
                obs.config_id = cfg.config_id;
                obs.model_family = cfg.model_family;
                obs.n_fits = height(allFits);
                obs.n_good = sum(allFits.R2 >= 0.90, 'omitnan');
                obs.tau_median = nanmedian(tau_vals);
                obs.beta_median = nanmedian(beta_vals);
                
                results_table = [results_table; struct2table(obs)];
                fprintf('  -> OK (%d fits)\n', obs.n_fits);
            else
                fprintf('  -> ERROR: Empty fit table\n');
            end
            
        catch ME
            fprintf('  -> ERROR: %s\n', ME.message);
            rethrow(ME);
        end
    end
    
    %% ===================================================================
    %% ANALYSIS
    %% ===================================================================
    
    fprintf('\nResults table:\n');
    disp(results_table);
    
    % Model comparison
    if height(results_table) >= 2
        log_tau = results_table.tau_median(results_table.config_id == 1);
        kww_tau = results_table.tau_median(results_table.config_id == 2);
        if ~isempty(log_tau) && ~isempty(kww_tau) && kww_tau ~= 0
            ratio = log_tau / kww_tau;
            fprintf('\nTau ratio (log/kww): %.3f\n', ratio);
            if ratio > 0.95 && ratio < 1.05
                verdict = 'LOW';
            elseif ratio > 0.85 && ratio < 1.15
                verdict = 'MEDIUM';
            else
                verdict = 'HIGH';
            end
            fprintf('RELAXATION_MODEL_DEPENDENCE: %s\n', verdict);
        end
    end
    
    %% ===================================================================
    %% WRITE OUTPUTS
    %% ===================================================================
    
    outDir = fullfile(runDir);
    
    % Results table
    matrixPath = fullfile(outDir, 'relaxation_perturbation_matrix.csv');
    writetable(results_table, matrixPath);
    
    % Summary
    summaryT = table();
    summaryT.parameter = {'configs_tested'; 'configs_successful'};
    summaryT.value = {num2str(n_configs); num2str(height(results_table))};
    summaryPath = fullfile(outDir, 'relaxation_stability_summary.csv');
    writetable(summaryT, summaryPath);
    
    % Verdict
    verdictT = table();
    verdictT.verdict = {'RELAXATION_DEMO_COMPLETE'};
    verdictT.value = {'YES'};
    verdictPath = fullfile(outDir, 'relaxation_verdict.csv');
    writetable(verdictT, verdictPath);
    
    fprintf('\n%s\n', repmat('=', 1, 70));
    fprintf('RELAXATION PERTURBATION DEMO - COMPLETED\n');
    fprintf('Outputs:\n');
    fprintf('  %s\n', matrixPath);
    fprintf('  %s\n', summaryPath);
    fprintf('  %s\n', verdictPath);
    fprintf('%s\n', repmat('=', 1, 70));
    
    execution_status = 'SUCCESS';
    
catch ME
    execution_status = 'FAILURE';
    error_message = ME.message;
    fprintf('\nEXECUTION FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% ======================================================================
%% STATUS FILE (AUDIT REQUIREMENT)
%% ======================================================================

executionT = table();
executionT.field = {'status'; 'error'; 'run_dir'; 'timestamp'};
executionT.value = {execution_status; error_message; runDir; datetime('now')};
writetable(executionT, status_file);
