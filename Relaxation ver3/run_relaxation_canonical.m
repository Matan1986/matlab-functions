function run_relaxation_canonical(userCfg)

clc;

if nargin < 1 || isempty(userCfg)
    userCfg = struct();
end

% run_relaxation_canonical - Minimal canonical wrapper for Relaxation v3
% 
% Purpose: orchestrate Relaxation analysis under explicit config control
% for audit readiness. Produces audit-ready output bundles and explicitly
% records all key choices.
%
% Execution: tools/run_matlab_safe.bat "path/to/run_relaxation_canonical.m"
%
% This is a PURE SCRIPT (no function definitions). All logic is inline.

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
    error('Could not detect repo root - README.md not found');
end

%% ======================================================================
%% PATH SETUP
%% ======================================================================

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Relaxation ver3'));
addpath(fullfile(repoRoot, 'General ver2'));
addpath(fullfile(repoRoot, 'Tools ver1'));

%% ======================================================================
%% USER CONFIGURATION (AUDIT ENTRY POINT)
%% ======================================================================

% Define data directory. User can override via environment or edit here.
dataDir = '';
if ~isempty(dataDir) && ~exist(dataDir, 'dir')
    dataDir = '';
end

if isempty(dataDir)
    dataDir = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Relaxation TRM';
end

%% ======================================================================
%% CONFIG SETUP (CANONICAL DEFAULTS)
%% ======================================================================

% Start with defaults from helper
config = relaxation_config_helper(userCfg);

%% ======================================================================
%% RUN CONTEXT SETUP
%% ======================================================================

runLabel = 'canonical';
runCfg = struct();
runCfg.runLabel = runLabel;
runCfg.dataset = dataDir;
run = createRunContext('relaxation', runCfg);
runDir = run.run_dir;

if ~isfolder(runDir)
    mkdir(runDir);
end

logPath = run.log_path;
fprintf('Relaxation canonical run directory:\n%s\n', runDir);

%% ======================================================================
%% DATA LOADING (DELEGATED TO EXISTING HELPERS)
%% ======================================================================

try
    [fileList, temps, fields, types, colors, mass] = ...
        getFileList_relaxation(dataDir, config.color_scheme);
    
    fileListLower = lower(string(fileList));
    containsTRM = any(contains(fileListLower, 'trm'));
    containsIRM = any(contains(fileListLower, 'irm'));
    
    [Time_table, Temp_table, Field_table, Moment_table, massHeader] = ...
        importFiles_relaxation(dataDir, fileList, config.normalize_by_mass, false);
    
    if ~isnan(massHeader)
        mass = massHeader;
    end
    
    nfiles = numel(Time_table);
    fprintf('Loaded %d files\n', nfiles);
    
catch ME
    fid = fopen(logPath, 'a');
    fprintf(fid, '[ERROR] Data loading failed: %s\n', ME.message);
    fclose(fid);
    rethrow(ME);
end

%% ======================================================================
%% UNIT CONVERSION (BOHAR MAGNETON)
%% ======================================================================

if config.use_bohar_units
    x_Co = 1/3;
    m_mol = 58.9332/3 + 180.948 + 2*32.066;
    muB = 9.274e-21;
    NA = 6.022e23;
    convFactor = m_mol / (NA * muB * x_Co);
    
    for i = 1:numel(Moment_table)
        Moment_table{i} = Moment_table{i} * convFactor;
    end
end

%% ======================================================================
%% RELAXATION FITTING (MAIN ANALYSIS)
%% ======================================================================

fprintf('\nStarting relaxation fitting...\n');

fitParams = struct();
fitParams.betaBoost = config.beta_boost;
fitParams.tauBoost = config.tau_boost;
fitParams.timeWeight = config.time_weight;
fitParams.timeWeightFactor = config.time_weight_factor;
fitParams.debugFit = false;

allFits = table();
branch_usage = struct('field_based', 0, 'derivative_fallback', 0);

try
    allFits = fitAllRelaxations(Time_table, Moment_table, Temp_table, Field_table, ...
        false, config.field_threshold_Oe, fitParams, ...
        0, 0, config.abs_threshold, config.slope_threshold, ...
        fileList, config.model_family);
    
    nFits = height(allFits);
    fprintf('Completed %d fits\n', nFits);
    
catch ME
    fid = fopen(logPath, 'a');
    fprintf(fid, '[ERROR] Fitting failed: %s\n', ME.message);
    fclose(fid);
    rethrow(ME);
end

%% ======================================================================
%% AUDIT OUTPUT BUNDLE CONSTRUCTION
%% ======================================================================

auditData = struct();

% Inputs
auditData.raw_source_identifier = dataDir;
auditData.n_files_loaded = nfiles;
auditData.n_files_fit = nFits;
auditData.contains_trm = containsTRM;
auditData.contains_irm = containsIRM;

% Config used (9 key parameters + supplementary)
auditData.config = config;

% Output handles (primary deliverables)
auditData.fit_table = allFits;
auditData.fit_table_path = fullfile(runDir, 'allFits.csv');
if ~isempty(allFits)
    writetable(allFits, auditData.fit_table_path);
end

% Branch identity explicit
auditData.branch_identity = 'core_fit_pipeline';
auditData.window_detection_strategy = config.fit_window_mode;
auditData.model_selection_strategy = config.model_family;
if strcmpi(config.model_family, 'compare')
    auditData.model_selection_criterion = config.model_selection_criterion;
else
    auditData.model_selection_criterion = 'N/A (single model only)';
end

% Canonical summary observables
if ~isempty(allFits)
    auditData.n_good_fits = sum(allFits.R2 >= 0.90, 'omitnan');
    auditData.n_no_relax = sum(isnan(allFits.tau), 'omitnan');
    auditData.median_tau = nanmedian(allFits.tau);
    auditData.median_beta = nanmedian(allFits.n);
    auditData.median_R2 = nanmedian(allFits.R2);
else
    auditData.n_good_fits = 0;
    auditData.n_no_relax = 0;
    auditData.median_tau = NaN;
    auditData.median_beta = NaN;
    auditData.median_R2 = NaN;
end

% Status flags
auditData.execution_status = 'SUCCESS';
auditData.data_loaded_ok = ~isempty(Moment_table);
auditData.fits_produced_ok = ~isempty(allFits);
auditData.audit_bundle_complete = true;

% Time-origin rule used
auditData.time_origin_rule = config.time_origin_mode;

% Window rule used
auditData.window_rule = config.fit_window_mode;

%% ======================================================================
%% WRITE AUDIT OUTPUT FILES
%% ======================================================================

% 1. Save fit table (already done above)

% 2. Save config snapshot
configPath = fullfile(runDir, 'config_snapshot.m');
fid = fopen(configPath, 'w');
if fid < 0
    error('could not write config snapshot');
end
fprintf(fid, '%%%% CONFIG SNAPSHOT - %s\n', datetime('now'));
fprintf(fid, '%%%% This file documents all choices made for this relaxation canonical run\n\n');
fprintf(fid, 'cfg = struct();\n\n');
fprintf(fid, '%%%% === 9 KEY AUDIT PARAMETERS ===\n');
fprintf(fid, 'cfg.time_origin_mode = ''%s'';\n', config.time_origin_mode);
fprintf(fid, 'cfg.fit_window_mode = ''%s'';\n', config.fit_window_mode);
fprintf(fid, 'cfg.baseline_mode = ''%s'';\n', config.baseline_mode);
fprintf(fid, 'cfg.interpolation_mode = ''%s'';\n', config.interpolation_mode);
fprintf(fid, 'cfg.smoothing_mode = ''%s'';\n', config.smoothing_mode);
fprintf(fid, 'cfg.derivative_mode = ''%s'';\n', config.derivative_mode);
fprintf(fid, 'cfg.model_family = ''%s'';\n', config.model_family);
fprintf(fid, 'cfg.model_selection_criterion = ''%s'';\n', config.model_selection_criterion);
fprintf(fid, 'cfg.no_relax_threshold_mode = ''%s'';\n', config.no_relax_threshold_mode);
fprintf(fid, '\n%%%% === SUPPLEMENTARY NUMERIC PARAMETERS ===\n');
fprintf(fid, 'cfg.field_threshold_Oe = %.2f;\n', config.field_threshold_Oe);
fprintf(fid, 'cfg.derivative_fallback_fraction = %.2f;\n', config.derivative_fallback_fraction);
fprintf(fid, 'cfg.abs_threshold = %.2e;\n', config.abs_threshold);
fprintf(fid, 'cfg.slope_threshold = %.2e;\n', config.slope_threshold);
fclose(fid);

% 3. Save audit summary table
summaryPath = fullfile(runDir, 'audit_summary.csv');
summaryT = table();
summaryT.parameter = {
    'execution_status';
    'n_files_loaded';
    'n_files_fit';
    'n_good_fits';
    'n_no_relax';
    'median_tau';
    'median_beta';
    'median_R2';
    'model_family';
    'model_selection_criterion';
    'window_mode';
    'time_origin_mode';
    'data_source'
};
summaryT.value = {
    auditData.execution_status;
    num2str(auditData.n_files_loaded);
    num2str(auditData.n_files_fit);
    num2str(auditData.n_good_fits);
    num2str(auditData.n_no_relax);
    num2str(auditData.median_tau);
    num2str(auditData.median_beta);
    num2str(auditData.median_R2);
    config.model_family;
    auditData.model_selection_criterion;
    config.fit_window_mode;
    config.time_origin_mode;
    dataDir
};
writetable(summaryT, summaryPath);

% 4. Write run manifest (standard Aging infrastructure)
manifestPath = fullfile(runDir, 'run_manifest.json');
outputsList = {
    auditData.fit_table_path;
    configPath;
    summaryPath;
    logPath
};
manifest = struct('outputs', {outputsList}, 'audit_ready', true);
jsonStr = jsonencode(manifest);
fid = fopen(manifestPath, 'w');
if fid < 0
    error('failed to write manifest');
end
fprintf(fid, '%s', jsonStr);
fclose(fid);

% 5. Write execution status artifact
statusPath = fullfile(runDir, 'execution_status.csv');
statusT = table();
statusT.EXECUTION_STATUS = {'SUCCESS'};
statusT.INPUT_FOUND = {'YES'};
statusT.N_FITS = {num2str(nFits)};
statusT.AUDIT_READY = {'YES'};
statusT.ERROR_MESSAGE = {''};
writetable(statusT, statusPath);

% 6. Add run_dir_pointer for infrastructure consistency
runDirPointerPath = fullfile(repoRoot, 'run_dir_pointer.txt');
fidp = fopen(runDirPointerPath, 'w');
if fidp < 0
    error('failed to write run_dir_pointer');
end
nw = fprintf(fidp, '%s', runDir);
fclose(fidp);
if nw <= 0
    error('run_dir_pointer write failed');
end

%% ======================================================================
%% EXECUTION SUMMARY
%% ======================================================================

fprintf('\n');
fprintf('===== RELAXATION CANONICAL RUN COMPLETE =====\n');
fprintf('Run ID: %s\n', run.run_id);
fprintf('Run dir: %s\n', runDir);
fprintf('\nAUDIT SUMMARY:\n');
fprintf('  Data source: %s\n', dataDir);
fprintf('  Files loaded: %d\n', auditData.n_files_loaded);
fprintf('  Files fit: %d\n', auditData.n_files_fit);
fprintf('  Good fits (R2 >= 0.90): %d\n', auditData.n_good_fits);
fprintf('  No-relax curves: %d\n', auditData.n_no_relax);
fprintf('\nCONFIG USED:\n');
fprintf('  time_origin_mode: %s\n', config.time_origin_mode);
fprintf('  fit_window_mode: %s\n', config.fit_window_mode);
fprintf('  model_family: %s\n', config.model_family);
fprintf('  model_selection_criterion: %s\n', auditData.model_selection_criterion);
fprintf('  window rule: %s\n', config.fit_window_mode);
fprintf('\nOUTPUT FILES:\n');
fprintf('  fit_table: %s\n', auditData.fit_table_path);
fprintf('  config_snapshot: %s\n', configPath);
fprintf('  audit_summary: %s\n', summaryPath);
fprintf('  run_manifest: %s\n', manifestPath);
fprintf('  execution_status: %s\n', statusPath);
fprintf('\n');

end
