clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('F4B:RepoRootMissing', 'Repository root not found: %s', repoRoot);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_F4B_FM_physical_tau_replay';
cfg.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F4B_FM_physical_tau_replay.m');

executionStatus = table({'FAILED'}, {'NO'}, {'Not started'}, 0, {'F4B FM physical tau replay not executed'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('aging', cfg);

    runTablesDir = fullfile(run.run_dir, 'tables');
    runReportsDir = fullfile(run.run_dir, 'reports');
    if exist(runTablesDir, 'dir') ~= 7
        mkdir(runTablesDir);
    end
    if exist(runReportsDir, 'dir') ~= 7
        mkdir(runReportsDir);
    end

    pointerPath = fullfile(run.repo_root, 'run_dir_pointer.txt');
    fidPointer = fopen(pointerPath, 'w');
    if fidPointer < 0
        error('F4B:PointerWriteFailed', 'Failed to write run_dir_pointer.txt');
    end
    fprintf(fidPointer, '%s\n', run.run_dir);
    fclose(fidPointer);

    signAlignedPath = fullfile(repoRoot, 'tables', 'aging', 'aging_F3b_FM_sign_aligned_candidate.csv');
    gatePath = fullfile(repoRoot, 'tables', 'aging', 'aging_F3b_FM_tau_tw_gate_revised.csv');
    statusPath = fullfile(repoRoot, 'tables', 'aging', 'aging_F3b_FM_signed_rescue_status.csv');

    if exist(signAlignedPath, 'file') ~= 2
        error('F4B:MissingInput', 'Missing F3b sign-aligned table: %s', signAlignedPath);
    end
    if exist(gatePath, 'file') ~= 2
        error('F4B:MissingInput', 'Missing F3b revised gate table: %s', gatePath);
    end
    if exist(statusPath, 'file') ~= 2
        error('F4B:MissingInput', 'Missing F3b status table: %s', statusPath);
    end

    signAligned = readtable(signAlignedPath, 'VariableNamingRule', 'preserve');
    gateTbl = readtable(gatePath, 'VariableNamingRule', 'preserve');
    f3bStatus = readtable(statusPath, 'VariableNamingRule', 'preserve');

    if ~ismember('READY_TO_BUILD_FM_PHYSICAL_TAU_REPLAY', f3bStatus.Properties.VariableNames)
        error('F4B:F3bStatusMalformed', 'F3b status missing READY_TO_BUILD_FM_PHYSICAL_TAU_REPLAY.');
    end
    readyFlag = string(f3bStatus.READY_TO_BUILD_FM_PHYSICAL_TAU_REPLAY(1));
    if ~strcmpi(readyFlag, "YES")
        error('F4B:F3bGateClosed', 'F3b does not allow FM physical tau replay.');
    end

    gateMask = strcmp(string(gateTbl.eligible_min3), 'YES') & strcmp(string(gateTbl.tp_scope_allowed_for_physical_tau), 'YES');
    eligibleTps = gateTbl.Tp(gateMask);
    eligibleTps = sort(eligibleTps);

    if isempty(eligibleTps)
        error('F4B:NoEligibleTp', 'No F3b-eligible Tp values for FM replay.');
    end

    inputMask = ismember(signAligned.Tp, eligibleTps);
    fmInput = signAligned(inputMask, :);
    fmInput = sortrows(fmInput, {'Tp', 'tw'});

    fmInputDomain = table( ...
        fmInput.Tp, fmInput.tw, fmInput.FM_signed_direct_TrackB_sign_aligned, fmInput.source_run_TrackB, ...
        fmInput.sign_aligned_finite, repmat("YES", height(fmInput), 1), repmat("tau_FM_physical_canon_replay", height(fmInput), 1), ...
        'VariableNames', {'Tp', 'tw', 'FM_signed_direct_TrackB_sign_aligned', 'source_run_TrackB', ...
        'finite_fm_signed', 'F3b_domain_eligible', 'candidate_namespace'});

    qualityThresholdR2 = 0.6;
    twMinRequired = 3;

    modelFitsTp = [];
    modelFitsFamily = strings(0, 1);
    modelFitsNPoints = [];
    modelFitsTau = [];
    modelFitsA = [];
    modelFitsB = [];
    modelFitsRmse = [];
    modelFitsR2 = [];
    modelFitsQualityPass = strings(0, 1);
    modelFitsSupportClass = strings(0, 1);
    modelFitsRole = strings(0, 1);

    selectedTp = [];
    selectedTau = [];
    selectedModel = strings(0, 1);
    selectedNPoints = [];
    selectedR2 = [];
    selectedStatus = strings(0, 1);
    selectedNote = strings(0, 1);

    qualityTp = [];
    qualityNPoints = [];
    qualityR2 = [];
    qualityRmse = [];
    qualityThresholdCol = [];
    qualityTauPositiveRequired = strings(0, 1);
    qualityTwMinRequired = [];
    qualityPass = strings(0, 1);
    qualitySupportClass = strings(0, 1);

    failureTp = [];
    failureStage = strings(0, 1);
    failureReason = strings(0, 1);
    failureTwCount = [];
    failureTauSelected = strings(0, 1);

    for i = 1:numel(eligibleTps)
        tpVal = eligibleTps(i);
        tpMask = (fmInputDomain.Tp == tpVal) & strcmp(fmInputDomain.finite_fm_signed, 'YES');
        twVals = fmInputDomain.tw(tpMask);
        yVals = fmInputDomain.FM_signed_direct_TrackB_sign_aligned(tpMask);
        finiteMask = isfinite(twVals) & isfinite(yVals);
        twVals = double(twVals(finiteMask));
        yVals = double(yVals(finiteMask));
        [twVals, sortIdx] = sort(twVals);
        yVals = yVals(sortIdx);
        nPoints = numel(twVals);

        if nPoints >= 4
            supportClass = "PREFERRED_TW_SUPPORT";
        else
            supportClass = "MIN_TW_SUPPORT_ONLY";
        end

        if nPoints < twMinRequired
            failureTp(end+1, 1) = tpVal; %#ok<AGROW>
            failureStage(end+1, 1) = "input_gate";
            failureReason(end+1, 1) = "INSUFFICIENT_FINITE_TW_POINTS";
            failureTwCount(end+1, 1) = nPoints;
            failureTauSelected(end+1, 1) = "NO";
            continue;
        end

        xLog = log10(twVals);
        pLin = polyfit(xLog, yVals, 1);
        yLin = polyval(pLin, xLog);
        rmseLin = sqrt(mean((yVals - yLin).^2));
        sst = sum((yVals - mean(yVals)).^2);
        if sst > 0
            r2Lin = 1 - sum((yVals - yLin).^2) / sst;
        else
            r2Lin = 1;
        end

        modelFitsTp(end+1, 1) = tpVal; %#ok<AGROW>
        modelFitsFamily(end+1, 1) = "log10_tw_linear_diagnostic_non_primary";
        modelFitsNPoints(end+1, 1) = nPoints;
        modelFitsTau(end+1, 1) = NaN;
        modelFitsA(end+1, 1) = pLin(2);
        modelFitsB(end+1, 1) = pLin(1);
        modelFitsRmse(end+1, 1) = rmseLin;
        modelFitsR2(end+1, 1) = r2Lin;
        modelFitsQualityPass(end+1, 1) = "NA_DIAGNOSTIC";
        modelFitsSupportClass(end+1, 1) = supportClass;
        modelFitsRole(end+1, 1) = "NON_PRIMARY_CONTEXT_ONLY";

        yMin = min(yVals);
        yMax = max(yVals);
        yRange = yMax - yMin;
        if yRange == 0
            yRange = max(abs(yVals));
        end
        if yRange == 0
            yRange = 1e-12;
        end
        tauInit = median(twVals);
        if ~isfinite(tauInit) || tauInit <= 0
            tauInit = 360;
        end
        AInit = yVals(1);
        BInit = yVals(end) - yVals(1);
        if ~isfinite(BInit) || abs(BInit) < 1e-12
            BInit = yRange;
        end
        theta0 = [AInit, BInit, log(tauInit)];

        objective = @(theta) sum((yVals - (theta(1) + theta(2) .* (1 - exp(-twVals ./ exp(theta(3)))))).^2);
        opts = optimset('Display', 'off', 'MaxIter', 5000, 'MaxFunEvals', 20000, 'TolX', 1e-12, 'TolFun', 1e-12);
        [thetaFit, sseFit] = fminsearch(objective, theta0, opts);

        AFit = thetaFit(1);
        BFit = thetaFit(2);
        tauFit = exp(thetaFit(3));
        yHat = AFit + BFit .* (1 - exp(-twVals ./ tauFit));
        rmsePrimary = sqrt(mean((yVals - yHat).^2));
        if sst > 0
            r2Primary = 1 - sseFit / sst;
        else
            r2Primary = 1;
        end

        qualityOk = (nPoints >= twMinRequired) && isfinite(tauFit) && (tauFit > 0) && isfinite(r2Primary) && (r2Primary >= qualityThresholdR2);
        if qualityOk
            qualityText = "YES";
        else
            qualityText = "NO";
        end

        modelFitsTp(end+1, 1) = tpVal;
        modelFitsFamily(end+1, 1) = "single_exponential_approach_primary";
        modelFitsNPoints(end+1, 1) = nPoints;
        modelFitsTau(end+1, 1) = tauFit;
        modelFitsA(end+1, 1) = AFit;
        modelFitsB(end+1, 1) = BFit;
        modelFitsRmse(end+1, 1) = rmsePrimary;
        modelFitsR2(end+1, 1) = r2Primary;
        modelFitsQualityPass(end+1, 1) = qualityText;
        modelFitsSupportClass(end+1, 1) = supportClass;
        modelFitsRole(end+1, 1) = "PRIMARY_PHYSICAL_CANDIDATE";

        qualityTp(end+1, 1) = tpVal; %#ok<AGROW>
        qualityNPoints(end+1, 1) = nPoints;
        qualityR2(end+1, 1) = r2Primary;
        qualityRmse(end+1, 1) = rmsePrimary;
        qualityThresholdCol(end+1, 1) = qualityThresholdR2;
        qualityTauPositiveRequired(end+1, 1) = "YES";
        qualityTwMinRequired(end+1, 1) = twMinRequired;
        qualityPass(end+1, 1) = qualityText;
        qualitySupportClass(end+1, 1) = supportClass;

        if qualityOk
            selectedTp(end+1, 1) = tpVal; %#ok<AGROW>
            selectedTau(end+1, 1) = tauFit;
            selectedModel(end+1, 1) = "single_exponential_approach_primary";
            selectedNPoints(end+1, 1) = nPoints;
            selectedR2(end+1, 1) = r2Primary;
            selectedStatus(end+1, 1) = "SELECTED";
            selectedNote(end+1, 1) = "Passed tw-domain and fit-quality gates";
        else
            failureTp(end+1, 1) = tpVal; %#ok<AGROW>
            failureStage(end+1, 1) = "fit_quality_gate";
            failureReason(end+1, 1) = "PRIMARY_MODEL_QUALITY_FAIL_OR_INVALID_TAU";
            failureTwCount(end+1, 1) = nPoints;
            failureTauSelected(end+1, 1) = "NO";
        end
    end

    fmModelFits = table(modelFitsTp, modelFitsFamily, modelFitsNPoints, modelFitsTau, modelFitsA, modelFitsB, ...
        modelFitsRmse, modelFitsR2, modelFitsQualityPass, modelFitsSupportClass, modelFitsRole, ...
        'VariableNames', {'Tp', 'model_family', 'n_points', 'tau_candidate', 'param_A', 'param_B', ...
        'rmse', 'r2', 'quality_pass', 'tw_support_class', 'model_role'});

    fmSelected = table(selectedTp, selectedTau, selectedModel, selectedNPoints, selectedR2, selectedStatus, selectedNote, ...
        'VariableNames', {'Tp', 'tau_FM_physical_canon_replay', 'selected_model', 'n_points', ...
        'r2_primary', 'selection_status', 'selection_note'});

    fmFitQuality = table(qualityTp, qualityNPoints, qualityR2, qualityRmse, qualityThresholdCol, ...
        qualityTauPositiveRequired, qualityTwMinRequired, qualityPass, qualitySupportClass, ...
        'VariableNames', {'Tp', 'n_points', 'r2_primary', 'rmse_primary', 'quality_threshold_r2', ...
        'tau_positive_required', 'tw_min_required', 'quality_pass', 'support_class'});

    fmFailureReasons = table(failureTp, failureStage, failureReason, failureTwCount, failureTauSelected, ...
        'VariableNames', {'Tp', 'failure_stage', 'failure_reason', 'tw_count', 'tau_selected'});

    selectedCount = height(fmSelected);
    failedCount = height(fmFailureReasons);
    if failedCount == 0
        qualitySummary = "YES";
    else
        qualitySummary = "PARTIAL";
    end

    selectedAny = "NO";
    if selectedCount > 0
        selectedAny = "YES";
    end

    fmStatus = table( ...
        "YES", ...
        "YES", ...
        "YES", ...
        selectedAny, ...
        selectedCount, ...
        failedCount, ...
        qualitySummary, ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "FM-only replay built on F3b sign-aligned direct TrackB signed channel; no AFM changes and no AFM/FM comparison performed." ...
        , 'VariableNames', { ...
        'F4B_FM_PHYSICAL_TAU_REPLAY_COMPLETED', ...
        'FM_INPUT_DOMAIN_MATCHES_F3B_GATE', ...
        'FM_TAU_FIT_PERFORMED', ...
        'FM_TAU_PHYSICAL_VALUES_SELECTED', ...
        'FM_TAU_SELECTED_TP_COUNT', ...
        'FM_TAU_FAILED_TP_COUNT', ...
        'FM_TAU_MODEL_QUALITY_SUFFICIENT', ...
        'AFM_TAU_MODIFIED', ...
        'AFM_FM_TAU_COMPARISON_PERFORMED', ...
        'FM_ABS_USED_AS_SIGNED_REPLACEMENT', ...
        'PER_ROW_SIGN_FLIPPING_USED', ...
        'TAU_PROXY_AS_PHYSICAL_TAU_USED', ...
        'TRACKA_USED_AS_DIRECT_TAU_SOURCE', ...
        'CROSS_MODULE_ANALYSIS_PERFORMED', ...
        'GLOBAL_AGING_MECHANISM_CLAIMED', ...
        'NOTES'});

    repoTablesDir = fullfile(repoRoot, 'tables', 'aging');
    repoReportsDir = fullfile(repoRoot, 'reports', 'aging');
    if exist(repoTablesDir, 'dir') ~= 7
        mkdir(repoTablesDir);
    end
    if exist(repoReportsDir, 'dir') ~= 7
        mkdir(repoReportsDir);
    end

    pInput = fullfile(repoTablesDir, 'aging_F4B_FM_tau_input_domain.csv');
    pFits = fullfile(repoTablesDir, 'aging_F4B_FM_tau_model_fits.csv');
    pSelected = fullfile(repoTablesDir, 'aging_F4B_FM_tau_selected_values.csv');
    pQuality = fullfile(repoTablesDir, 'aging_F4B_FM_tau_fit_quality.csv');
    pFailure = fullfile(repoTablesDir, 'aging_F4B_FM_tau_failure_reasons.csv');
    pStatus = fullfile(repoTablesDir, 'aging_F4B_FM_tau_status.csv');

    writetable(fmInputDomain, pInput);
    writetable(fmModelFits, pFits);
    writetable(fmSelected, pSelected);
    writetable(fmFitQuality, pQuality);
    writetable(fmFailureReasons, pFailure);
    writetable(fmStatus, pStatus);

    writetable(fmInputDomain, fullfile(runTablesDir, 'aging_F4B_FM_tau_input_domain.csv'));
    writetable(fmModelFits, fullfile(runTablesDir, 'aging_F4B_FM_tau_model_fits.csv'));
    writetable(fmSelected, fullfile(runTablesDir, 'aging_F4B_FM_tau_selected_values.csv'));
    writetable(fmFitQuality, fullfile(runTablesDir, 'aging_F4B_FM_tau_fit_quality.csv'));
    writetable(fmFailureReasons, fullfile(runTablesDir, 'aging_F4B_FM_tau_failure_reasons.csv'));
    writetable(fmStatus, fullfile(runTablesDir, 'aging_F4B_FM_tau_status.csv'));

    reportPath = fullfile(repoReportsDir, 'aging_F4B_FM_physical_tau_replay.md');
    fidReport = fopen(reportPath, 'w');
    if fidReport < 0
        error('F4B:ReportWriteFailed', 'Failed to write report: %s', reportPath);
    end
    fprintf(fidReport, '# Aging F4B FM physical tau replay\n\n');
    fprintf(fidReport, '## Scope and constraints\n');
    fprintf(fidReport, '- FM-side only: `tau_FM_physical_canon_replay`.\n');
    fprintf(fidReport, '- Input signal only: `FM_signed_direct_TrackB_sign_aligned` from `FM_step_mag` basis.\n');
    fprintf(fidReport, '- No AFM tau modification and no AFM/FM tau comparison.\n');
    fprintf(fidReport, '- No Track A direct tau source and no absolute-value signed replacement.\n');
    fprintf(fidReport, '- No cross-module analysis and no global mechanism claims.\n\n');
    fprintf(fidReport, '## Input domain\n');
    fprintf(fidReport, '- Domain restricted to F3b gate rows with `eligible_min3=YES` and `tp_scope_allowed_for_physical_tau=YES`.\n');
    fprintf(fidReport, '- Eligible Tp values used: ');
    for i = 1:numel(eligibleTps)
        if i > 1
            fprintf(fidReport, ', ');
        end
        fprintf(fidReport, '%g', eligibleTps(i));
    end
    fprintf(fidReport, '\n');
    fprintf(fidReport, '- Per-Tp minimum finite tw points for fitting: %d.\n\n', twMinRequired);
    fprintf(fidReport, '## Model families used\n');
    fprintf(fidReport, '- Primary physical candidate: single exponential approach/saturation vs tw.\n');
    fprintf(fidReport, '- Non-primary diagnostic context: log10(tw) linear model.\n\n');
    fprintf(fidReport, '## Selection policy\n');
    fprintf(fidReport, '- tau selected only when primary model passes quality gates.\n');
    fprintf(fidReport, '- Quality gate: r2 >= %.3f, finite positive tau, and tw support >= %d.\n', qualityThresholdR2, twMinRequired);
    fprintf(fidReport, '- Failed Tp rows are recorded with explicit failure reasons.\n\n');
    fprintf(fidReport, '## Outcome summary\n');
    fprintf(fidReport, '- Selected Tp count: %d\n', selectedCount);
    fprintf(fidReport, '- Failed Tp count: %d\n', failedCount);
    fprintf(fidReport, '- FM_TAU_MODEL_QUALITY_SUFFICIENT = %s\n\n', qualitySummary);
    fprintf(fidReport, '## Required verdicts\n');
    for vn = 1:numel(fmStatus.Properties.VariableNames)
        col = fmStatus.Properties.VariableNames{vn};
        val = fmStatus{1, vn};
        if isnumeric(val)
            fprintf(fidReport, '- %s = %g\n', col, val);
        else
            fprintf(fidReport, '- %s = %s\n', col, string(val));
        end
    end
    fclose(fidReport);

    fidRunReport = fopen(fullfile(runReportsDir, 'aging_F4B_FM_physical_tau_replay.md'), 'w');
    if fidRunReport >= 0
        fidSrc = fopen(reportPath, 'r');
        if fidSrc >= 0
            while ~feof(fidSrc)
                lineText = fgetl(fidSrc);
                if ischar(lineText)
                    fprintf(fidRunReport, '%s\n', lineText);
                end
            end
            fclose(fidSrc);
        end
        fclose(fidRunReport);
    end

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(fmInputDomain), ...
        {'F4B FM physical tau replay completed and outputs written'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_F4B_FM_physical_tau_replay_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'F4B FM physical tau replay failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
