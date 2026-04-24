clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
cd(repoRoot);

outDir = fullfile(repoRoot, 'results', 'aging', 'figures');
if exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

statusPath = fullfile(outDir, 'fm_missing_diagnosis_status.csv');
rowsPath = fullfile(outDir, 'fm_missing_diagnosis_pauseRuns.csv');
reportPath = fullfile(outDir, 'fm_missing_diagnosis_report.md');

try
    addpath(fullfile(repoRoot, 'Aging'));
    addpath(fullfile(repoRoot, 'Aging', 'pipeline'));

    cfg = agingConfig('MG119_60min');
    cfgRun = cfg;
    cfgRun.agingMetricMode = 'direct';
    cfgRun.AFM_metric_main = 'area';

    state = Main_Aging(cfgRun);
    pauseRuns = state.pauseRuns;

    n = numel(pauseRuns);
    Tp = nan(n,1);
    hasAFM_RMS = strings(n,1);
    hasFM = strings(n,1);
    FM_value = nan(n,1);
    FM_field_used = strings(n,1);
    FM_plateau_reason = strings(n,1);
    FM_plateau_n_left = nan(n,1);
    FM_plateau_n_right = nan(n,1);

    useSignedFM = true;
    if isfield(cfg, 'allowSignedFM') && ~isempty(cfg.allowSignedFM)
        useSignedFM = logical(cfg.allowSignedFM);
    end

    for i = 1:n
        pr = pauseRuns(i);
        if isfield(pr, 'waitK')
            Tp(i) = pr.waitK;
        end

        afmExists = isfield(pr, 'AFM_RMS') && ~isempty(pr.AFM_RMS) && isfinite(pr.AFM_RMS);
        if afmExists
            hasAFM_RMS(i) = "YES";
        else
            hasAFM_RMS(i) = "NO";
        end

        if useSignedFM
            if isfield(pr, 'FM_signed')
                FM_value(i) = pr.FM_signed;
                FM_field_used(i) = "FM_signed";
            elseif isfield(pr, 'FM_step_raw')
                FM_value(i) = pr.FM_step_raw;
                FM_field_used(i) = "FM_step_raw";
            elseif isfield(pr, 'FM_step_mag')
                FM_value(i) = pr.FM_step_mag;
                FM_field_used(i) = "FM_step_mag";
            else
                FM_field_used(i) = "none";
            end
        else
            if isfield(pr, 'FM_abs')
                FM_value(i) = pr.FM_abs;
                FM_field_used(i) = "FM_abs";
            elseif isfield(pr, 'FM_step_mag')
                FM_value(i) = abs(pr.FM_step_mag);
                FM_field_used(i) = "FM_step_mag_abs";
            elseif isfield(pr, 'FM_step_raw')
                FM_value(i) = abs(pr.FM_step_raw);
                FM_field_used(i) = "FM_step_raw_abs";
            else
                FM_field_used(i) = "none";
            end
        end

        if isfinite(FM_value(i))
            hasFM(i) = "YES";
        else
            hasFM(i) = "NO";
        end

        if isfield(pr, 'FM_plateau_reason') && ~isempty(pr.FM_plateau_reason)
            FM_plateau_reason(i) = string(pr.FM_plateau_reason);
        else
            FM_plateau_reason(i) = "";
        end

        if isfield(pr, 'FM_plateau_n_left')
            FM_plateau_n_left(i) = pr.FM_plateau_n_left;
        end
        if isfield(pr, 'FM_plateau_n_right')
            FM_plateau_n_right(i) = pr.FM_plateau_n_right;
        end

        fprintf('Tp=%.6g | has AFM_RMS=%s | has FM=%s | FM=%.12g\n', Tp(i), hasAFM_RMS(i), hasFM(i), FM_value(i));
    end

    outTbl = table(Tp, hasAFM_RMS, hasFM, FM_value, FM_field_used, FM_plateau_reason, FM_plateau_n_left, FM_plateau_n_right);
    writetable(outTbl, rowsPath);

    missingMask = strcmp(hasFM, "NO");
    missingTp = Tp(missingMask);

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('ReportWriteFailed:IO', 'Failed to write diagnosis report.');
    end
    fprintf(fid, '# FM Missing Diagnosis\n\n');
    fprintf(fid, '- Dataset: MG119_60min\n');
    fprintf(fid, '- n pause runs: %d\n', n);
    fprintf(fid, '- n AFM_RMS finite: %d\n', nnz(strcmp(hasAFM_RMS, "YES")));
    fprintf(fid, '- n FM finite: %d\n', nnz(strcmp(hasFM, "YES")));
    fprintf(fid, '- Missing FM Tp: %s\n', strtrim(sprintf('%.6g ', missingTp)));
    fclose(fid);

    statusTbl = table({'SUCCESS'}, {'YES'}, {''}, n, {'FM missing diagnosis completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(statusTbl, statusPath);

catch ME
    statusTbl = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'FM missing diagnosis failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(statusTbl, statusPath);
    rethrow(ME);
end

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
