clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
cd(repoRoot);

statusPath = fullfile(repoRoot, 'results', 'aging', 'figures', 'afm_rms_plot_execution_status.csv');
if exist(fullfile(repoRoot, 'results', 'aging', 'figures'), 'dir') ~= 7
    mkdir(fullfile(repoRoot, 'results', 'aging', 'figures'));
end

try
    addpath(fullfile(repoRoot, 'Aging'));
    addpath(fullfile(repoRoot, 'Aging', 'pipeline'));
    addpath(fullfile(repoRoot, 'Aging', 'plots'));
    addpath(fullfile(repoRoot, 'Aging', 'models'));
    addpath(fullfile(repoRoot, 'Aging', 'utils'));

    cfg = agingConfig('MG119_60min');
    cfg.AFM_metric_main = 'RMS';

    cfgRun = cfg;
    cfgRun.agingMetricMode = 'direct';
    cfgRun.AFM_metric_main = 'area';

    state = Main_Aging(cfgRun);
    pauseRuns = state.pauseRuns;

    if ~isfield(pauseRuns, 'AFM_RMS')
        error('AFM_RMSMissing:Field', 'pauseRuns does not contain AFM_RMS.');
    end

    plotAgingMemory_AFM_vs_FM(pauseRuns, cfg.fontsize, cfg.showAFM_errors, cfg.normalizeAFM_FM, cfg);

    outDir = fullfile(repoRoot, 'results', 'aging', 'figures');
    pngPath = fullfile(outDir, 'AFM_RMS_vs_Tp.png');
    figPath = fullfile(outDir, 'AFM_RMS_vs_Tp.fig');
    saveas(gcf, pngPath);
    savefig(gcf, figPath);

    Tp = [pauseRuns.waitK];
    AFM = [pauseRuns.AFM_RMS];

    useSignedFM = true;
    if isfield(cfg, 'allowSignedFM') && ~isempty(cfg.allowSignedFM)
        useSignedFM = logical(cfg.allowSignedFM);
    end

    if useSignedFM
        if isfield(pauseRuns, 'FM_signed')
            FM = [pauseRuns.FM_signed];
        elseif isfield(pauseRuns, 'FM_step_raw')
            FM = [pauseRuns.FM_step_raw];
        else
            FM = [pauseRuns.FM_step_mag];
        end
    else
        if isfield(pauseRuns, 'FM_abs')
            FM = [pauseRuns.FM_abs];
        elseif isfield(pauseRuns, 'FM_step_mag')
            FM = abs([pauseRuns.FM_step_mag]);
        else
            FM = abs([pauseRuns.FM_step_raw]);
        end
    end

    validAFM = isfinite(Tp) & isfinite(AFM);
    validFM = isfinite(Tp) & isfinite(FM);

    tpAFM = Tp(validAFM);
    tpFM = Tp(validFM);

    afmMin = NaN; afmMax = NaN;
    if any(validAFM)
        afmMin = min(AFM(validAFM));
        afmMax = max(AFM(validAFM));
    end

    fmMin = NaN; fmMax = NaN;
    if any(validFM)
        fmMin = min(FM(validFM));
        fmMax = max(FM(validFM));
    end

    fprintf('N_POINTS_AFM=%d\n', nnz(validAFM));
    fprintf('N_POINTS_FM=%d\n', nnz(validFM));
    fprintf('TP_AFM_USED=[%s]\n', strtrim(sprintf('%.6g ', tpAFM)));
    fprintf('TP_FM_USED=[%s]\n', strtrim(sprintf('%.6g ', tpFM)));
    fprintf('AFM_RANGE=[%.12g, %.12g]\n', afmMin, afmMax);
    fprintf('FM_RANGE=[%.12g, %.12g]\n', fmMin, fmMax);
    fprintf('FIG_PNG=%s\n', pngPath);
    fprintf('FIG_FIG=%s\n', figPath);

    statusTbl = table({'SUCCESS'}, {'YES'}, {''}, nnz(validAFM), {'AFM_RMS plot generated'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(statusTbl, statusPath);

catch ME
    statusTbl = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'AFM_RMS plot generation failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(statusTbl, statusPath);
    rethrow(ME);
end

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
