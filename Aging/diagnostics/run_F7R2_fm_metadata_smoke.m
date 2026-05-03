% run_F7R2_fm_metadata_smoke
% Minimal smoke: FM tau hardened metadata schema (F7R2). Not physics / not ratio.
% Runnable script only (no local functions).

clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    scriptDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(fileparts(scriptDir));
end

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfg = struct();
cfg.runLabel = 'F7R2_FM_METADATA_SMOKE_30ROW';
cfg.branch_id = 'FM_O_30row_B';
cfg.datasetPath = fullfile(repoRoot, 'results_old', 'aging', 'runs', 'run_2026_03_12_211204_aging_dataset_build', 'tables', 'aging_observable_dataset.csv');
cfg.dipTauPath = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_2026_05_01_231444_aging_timescale_extraction', 'tables', 'tau_vs_Tp.csv');
cfg.failedDipClockMetricsPath = fullfile(repoRoot, 'results_old', 'aging', 'runs', 'run_2026_03_13_005134_aging_fm_using_dip_clock', 'tables', 'fm_collapse_using_dip_tau_metrics.csv');

try
    out = aging_fm_timescale_analysis(cfg);
    runDir = char(out.run_dir);
    nTauRows = height(out.fm_tau_table);
    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nTauRows, {'F7R2 hardened tau_FM_vs_Tp smoke'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDir, 'execution_status.csv'));
catch ME
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'F7R2 smoke failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    fallbackDir = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_F7R2_smoke_failure_placeholder');
    if exist(fallbackDir, 'dir') ~= 7
        mkdir(fallbackDir);
    end
    writetable(executionStatus, fullfile(fallbackDir, 'execution_status.csv'));
    rethrow(ME);
end

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
