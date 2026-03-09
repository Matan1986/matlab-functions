function report = verify_stage4_refactor(mode)
% =========================================================
% verify_stage4_refactor
%
% PURPOSE:
%   Verify that stage4_analyzeAFM_FM refactoring preserved
%   pipeline behavior by comparing numerical outputs.
%
% USAGE:
%   verify_stage4_refactor('baseline')  - Save baseline results
%   verify_stage4_refactor('compare')   - Compare against baseline
%   verify_stage4_refactor('quick')     - Quick synthetic data test
%
% OUTPUTS:
%   report - struct with comparison results
%
% =========================================================

if nargin < 1
    mode = 'quick';
end

switch lower(mode)
    case 'baseline'
        report = generateBaseline();
    case 'compare'
        report = compareAgainstBaseline();
    case 'quick'
        report = quickSyntheticTest();
    otherwise
        error('Unknown mode: %s. Use ''baseline'', ''compare'', or ''quick''.', mode);
end

end

%% ====================== Quick Synthetic Test ======================
function report = quickSyntheticTest()
% Test with synthetic data to verify refactoring
fprintf('\n=== Stage4 Refactor Verification (Synthetic Data) ===\n');

% Create synthetic state
state = createSyntheticState();

% Create minimal config
cfg = createMinimalConfig();

% Run stage4 (refactored version)
fprintf('Running stage4_analyzeAFM_FM...\n');
try
    state_after = stage4_analyzeAFM_FM(state, cfg);
    fprintf('✓ Stage4 execution successful\n');
catch ME
    fprintf('✗ Stage4 execution failed: %s\n', ME.message);
    report.success = false;
    report.error = ME;
    return;
end

% Verify required fields exist
report = verifyFieldsExist(state_after);

if report.fieldsOK
    fprintf('✓ All required fields present\n');
else
    fprintf('✗ Missing fields detected\n');
    return;
end

% Verify numerical properties
report = verifyNumericalProperties(state_after, report);

% Report summary
printReport(report);

end

%% ====================== Generate Baseline ======================
function report = generateBaseline()
fprintf('\n=== Generating Baseline Results ===\n');
fprintf('This requires running the pipeline with real data.\n');
fprintf('Instructions:\n');
fprintf('1. Run Main_Aging.m with your data\n');
fprintf('2. After stage4 completes, save state to file:\n');
fprintf('   save(''baseline_stage4.mat'', ''state'', ''cfg'');\n');
fprintf('3. Place baseline_stage4.mat in Aging/tests/\n');

report.message = 'Baseline generation requires manual pipeline run';
report.success = false;
end

%% ====================== Compare Against Baseline ======================
function report = compareAgainstBaseline()
fprintf('\n=== Comparing Against Baseline ===\n');

baselineFile = fullfile(fileparts(mfilename('fullpath')), 'baseline_stage4.mat');

if ~exist(baselineFile, 'file')
    fprintf('✗ Baseline file not found: %s\n', baselineFile);
    fprintf('Run verify_stage4_refactor(''baseline'') first.\n');
    report.success = false;
    report.message = 'Baseline not found';
    return;
end

fprintf('Loading baseline...\n');
baseline = load(baselineFile);

fprintf('Running stage4 with same config...\n');
state_new = stage4_analyzeAFM_FM(baseline.state, baseline.cfg);

% Compare fields
report = compareStates(baseline.state.pauseRuns, state_new.pauseRuns);

printComparisonReport(report);

end

%% ====================== Field Verification ======================
function report = verifyFieldsExist(state)
report.fieldsOK = true;
report.missingFields = {};

requiredFields = {
    'AFM_amp', 'AFM_amp_err', 'AFM_area', 'AFM_area_err', ...
    'FM_step_raw', 'FM_step_mag', 'FM_step_err', ...
    'FM_plateau_valid', 'FM_plateau_reason', ...
    'DeltaM_smooth', 'DeltaM_sharp', ...
    'dip_window_K', 'smoothWindow_K', 'FM_plateau_K', 'FM_buffer_K', ...
    'excludeLowT_FM', 'excludeLowT_K', 'excludeLowT_mode'
};

for i = 1:numel(state.pauseRuns)
    for k = 1:numel(requiredFields)
        field = requiredFields{k};
        if ~isfield(state.pauseRuns(i), field)
            report.fieldsOK = false;
            if ~ismember(field, report.missingFields)
                report.missingFields{end+1} = field;
            end
        end
    end
end

end

%% ====================== Numerical Property Verification ======================
function report = verifyNumericalProperties(state, report)

fprintf('\nVerifying numerical properties...\n');

pauseRuns = state.pauseRuns;
n = numel(pauseRuns);

% Check that metrics are finite or NaN (no unexpected values)
report.hasInf = false;
report.unexpectedValues = {};

for i = 1:n
    % AFM metrics
    if isfield(pauseRuns(i), 'AFM_amp') && isinf(pauseRuns(i).AFM_amp)
        report.hasInf = true;
        report.unexpectedValues{end+1} = sprintf('AFM_amp[%d] = Inf', i);
    end
    
    if isfield(pauseRuns(i), 'AFM_area') && isinf(pauseRuns(i).AFM_area)
        report.hasInf = true;
        report.unexpectedValues{end+1} = sprintf('AFM_area[%d] = Inf', i);
    end
    
    % FM metrics
    if isfield(pauseRuns(i), 'FM_step_mag') && isinf(pauseRuns(i).FM_step_mag)
        report.hasInf = true;
        report.unexpectedValues{end+1} = sprintf('FM_step_mag[%d] = Inf', i);
    end
    
    % Check logical fields
    if isfield(pauseRuns(i), 'FM_plateau_valid')
        if ~islogical(pauseRuns(i).FM_plateau_valid) && ...
           ~isnumeric(pauseRuns(i).FM_plateau_valid)
            report.unexpectedValues{end+1} = sprintf('FM_plateau_valid[%d] wrong type', i);
        end
    end
end

if ~report.hasInf
    fprintf('✓ No Inf values detected\n');
else
    fprintf('✗ Inf values found:\n');
    for k = 1:numel(report.unexpectedValues)
        fprintf('  %s\n', report.unexpectedValues{k});
    end
end

end

%% ====================== State Comparison ======================
function report = compareStates(pauseRuns_old, pauseRuns_new)

fprintf('\nComparing state.pauseRuns fields...\n');

report.identical = true;
report.maxRelDiff = struct();

fieldsToCompare = {
    'AFM_amp', 'AFM_area', 'AFM_amp_err', 'AFM_area_err', ...
    'FM_step_raw', 'FM_step_mag', 'FM_step_err', 'FM_plateau_valid'
};

for k = 1:numel(fieldsToCompare)
    field = fieldsToCompare{k};
    
    if ~isfield(pauseRuns_old(1), field) || ~isfield(pauseRuns_new(1), field)
        fprintf('  %s: MISSING in one version\n', field);
        report.identical = false;
        continue;
    end
    
    old_vals = [pauseRuns_old.(field)];
    new_vals = [pauseRuns_new.(field)];
    
    if strcmp(field, 'FM_plateau_valid')
        % Logical comparison
        if isequal(old_vals, new_vals)
            fprintf('  %s: IDENTICAL\n', field);
            report.maxRelDiff.(field) = 0;
        else
            fprintf('  %s: DIFFERENT\n', field);
            report.identical = false;
            report.maxRelDiff.(field) = NaN;
        end
    else
        % Numerical comparison
        [maxRelDiff, areEqual] = compareNumerical(old_vals, new_vals);
        
        if areEqual
            fprintf('  %s: IDENTICAL (max rel diff = %.2e)\n', field, maxRelDiff);
        else
            fprintf('  %s: DIFFERENT (max rel diff = %.2e)\n', field, maxRelDiff);
            report.identical = false;
        end
        
        report.maxRelDiff.(field) = maxRelDiff;
    end
end

% Check field set
fields_old = fieldnames(pauseRuns_old);
fields_new = fieldnames(pauseRuns_new);

missing_in_new = setdiff(fields_old, fields_new);
added_in_new = setdiff(fields_new, fields_old);

report.fieldsChanged = ~isempty(missing_in_new) || ~isempty(added_in_new);

if ~report.fieldsChanged
    fprintf('\n✓ Field set unchanged\n');
else
    fprintf('\n✗ Field set changed:\n');
    if ~isempty(missing_in_new)
        fprintf('  Missing in new: %s\n', strjoin(missing_in_new, ', '));
    end
    if ~isempty(added_in_new)
        fprintf('  Added in new: %s\n', strjoin(added_in_new, ', '));
    end
end

end

%% ====================== Numerical Comparison Helper ======================
function [maxRelDiff, areEqual] = compareNumerical(old_vals, new_vals)

% Handle NaN values
old_finite = isfinite(old_vals);
new_finite = isfinite(new_vals);

% Check NaN pattern is same
if ~isequal(old_finite, new_finite)
    maxRelDiff = Inf;
    areEqual = false;
    return;
end

% Compare finite values
old_finite_vals = old_vals(old_finite);
new_finite_vals = new_vals(new_finite);

if isempty(old_finite_vals)
    maxRelDiff = 0;
    areEqual = true;
    return;
end

% Compute relative difference
absDiff = abs(old_finite_vals - new_finite_vals);
scale = max(abs(old_finite_vals), abs(new_finite_vals));
scale(scale == 0) = 1; % Avoid division by zero

relDiff = absDiff ./ scale;
maxRelDiff = max(relDiff);

% Threshold for "identical" (accounting for floating point)
areEqual = maxRelDiff < 1e-14;

end

%% ====================== Synthetic State Generator ======================
function state = createSyntheticState()

n = 5; % 5 pause runs
pauseRuns = repmat(struct(), n, 1);

for i = 1:n
    Tp = 10 + 5*i; % 15, 20, 25, 30, 35 K
    
    T = linspace(5, 45, 200)';
    
    % Synthetic DeltaM with dip at Tp
    dM = 0.01 * (T - 30).^2 / 100; % Background parabola
    dip = -0.05 * exp(-((T - Tp).^2) / (2*2^2)); % Gaussian dip
    dM = dM + dip + 0.001*randn(size(T)); % Add noise
    
    pauseRuns(i).waitK = Tp;
    pauseRuns(i).T_common = T;
    pauseRuns(i).DeltaM = dM;
    pauseRuns(i).file = sprintf('synthetic_Tp_%d.dat', Tp);
end

state.pauseRuns = pauseRuns;
state.noPause_T = linspace(5, 45, 200)';
state.noPause_M = 0.5 + 0.001*state.noPause_T;

end

%% ====================== Minimal Config Generator ======================
function cfg = createMinimalConfig()

cfg.dip_window_K = 3;
cfg.smoothWindow_K = 8;
cfg.excludeLowT_FM = false;
cfg.excludeLowT_K = 0;
cfg.FM_plateau_K = 6;
cfg.excludeLowT_mode = 'pre';
cfg.FM_buffer_K = 3;
cfg.AFM_metric_main = 'height';
cfg.fontsize = 12;
cfg.linewidth = 1.5;
cfg.outputFolder = pwd;

% Disable optional features
cfg.debug.enable = false;
cfg.doPlotting = false;
cfg.RobustnessCheck = false;
cfg.showAFM_FM_example = false;

end

%% ====================== Report Printing ======================
function printReport(report)

fprintf('\n=== Verification Report ===\n');

if report.fieldsOK
    fprintf('✓ All required fields present\n');
else
    fprintf('✗ Missing fields: %s\n', strjoin(report.missingFields, ', '));
end

if ~report.hasInf
    fprintf('✓ No unexpected Inf values\n');
else
    fprintf('✗ Unexpected values found\n');
end

fprintf('\nConclusion: ');
if report.fieldsOK && ~report.hasInf
    fprintf('PASS - Refactoring preserved structure\n');
else
    fprintf('FAIL - Issues detected\n');
end

fprintf('\n');

end

function printComparisonReport(report)

fprintf('\n=== Comparison Report ===\n');

if report.identical
    fprintf('✓ All numerical fields IDENTICAL\n');
else
    fprintf('✗ Differences detected\n');
end

if ~report.fieldsChanged
    fprintf('✓ Field set UNCHANGED\n');
else
    fprintf('✗ Field set CHANGED\n');
end

fprintf('\nMax Relative Differences:\n');
fields = fieldnames(report.maxRelDiff);
for k = 1:numel(fields)
    fprintf('  %s: %.2e\n', fields{k}, report.maxRelDiff.(fields{k}));
end

fprintf('\nConclusion: ');
if report.identical && ~report.fieldsChanged
    fprintf('PASS - Refactoring is NUMERICALLY IDENTICAL\n');
else
    fprintf('WARNING - Check differences carefully\n');
end

fprintf('\n');

end
