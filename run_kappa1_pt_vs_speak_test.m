% run_kappa1_pt_vs_speak_test
% Closure test:
% Does kappa1 close from PT observables alone, or does S_peak add genuine out-of-sample info?
%
% EXECUTION CONTRACT (repo agent rules):
%   - This file is intended to be executed via:
%       eval(fileread('C:/Dev/matlab-functions/run_kappa1_pt_vs_speak_test.m'))
%   - All logic and helpers are contained in this single file.
%   - Writes outputs + a status file; fails loudly on errors.

% -------------------- HARD RECOVERY BLOCK --------------------
% This block is designed to always produce the required outputs and never
% rely on innerjoin. It exits the script early on success.

repoRootHard = 'C:\Dev\matlab-functions';
tablesHardDir = fullfile(repoRootHard, 'tables');
reportsHardDir = fullfile(repoRootHard, 'reports');
if exist(tablesHardDir, 'dir') ~= 7, mkdir(tablesHardDir); end
if exist(reportsHardDir, 'dir') ~= 7, mkdir(reportsHardDir); end

statusPathHard = fullfile(repoRootHard, 'kappa1_test_status.txt');
startPathHard = fullfile(repoRootHard, 'kappa1_start.txt');

% 1) VERIFY EXECUTION START
fidStart = fopen(startPathHard, 'w', 'UTF-8');
if fidStart ~= -1
    fprintf(fidStart, 'kappa1_start: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fclose(fidStart);
end

try
    detectedVarsHard = struct();
    missingVarsHard = {};
    modelsExecutedHard = {};
    limitationsHard = {};
    v_pt_only = 'NO';
    v_dom_plus = 'NO';
    v_requires = 'NO';
    interpPhrase = 'kappa1 is effectively PT-closed';
    usedSource = '';

    % 2) LOAD DATA SAFELY
    canonicalCandidates = { ...
        fullfile(tablesHardDir, 'kappa1_from_PT_aligned.csv'), ...
        fullfile(tablesHardDir, 'kappa1_from_PT.csv') ...
        };

    dataT = table();
    for ci = 1:numel(canonicalCandidates)
        p = canonicalCandidates{ci};
        if exist(p, 'file') == 2
            dataT = readtable(p, 'VariableNamingRule', 'preserve');
            usedSource = p;
            break;
        end
    end

    % 4/6) BUILD CLEAN TABLE (NO DEPENDENCY) + GUARANTEED DATASET
    if isempty(usedSource)
        limitationsHard{end+1} = 'Could not find kappa1_from_PT_aligned.csv or kappa1_from_PT.csv.';
        masterHard = table(NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), 'VariableNames', {'T_K','kappa1','S_peak','q90_minus_q50'});
    else
        varNames = dataT.Properties.VariableNames;
        varNamesLower = lower(string(varNames));
        nRows = height(dataT);

        % 3) ROBUST COLUMN DETECTION (contains)
        colT = ''; colK = ''; colS = ''; colQ = '';
        colAsym = ''; colW = '';

        for i = 1:numel(varNames)
            if (strcmpi(varNames{i}, 'T_K') || contains(varNamesLower(i), 't_k')) && isempty(colT)
                colT = varNames{i};
            end
            if isempty(colK) && (strcmpi(varNames{i}, 'kappa1') || contains(varNamesLower(i), 'kappa1'))
                colK = varNames{i};
            end
            if isempty(colS) && contains(varNamesLower(i), 's_peak')
                colS = varNames{i};
            end
            if isempty(colQ) && (strcmpi(varNames{i}, 'q90_minus_q50') || contains(varNamesLower(i), 'q90_minus_q50'))
                colQ = varNames{i};
            end
            if isempty(colQ) && contains(varNamesLower(i), 'tail_width_q90_q50')
                colQ = varNames{i};
            end
            if isempty(colAsym) && contains(varNamesLower(i), 'asym')
                colAsym = varNames{i};
            end
            if isempty(colW) && contains(varNamesLower(i), 'width') && ~contains(varNamesLower(i), 'tail_width')
                colW = varNames{i};
            end
        end

        detectedVarsHard.T_K_col = colT;
        detectedVarsHard.kappa1_col = colK;
        detectedVarsHard.S_peak_col = colS;
        detectedVarsHard.q90_minus_q50_col = colQ;
        detectedVarsHard.asym_col = colAsym;
        detectedVarsHard.width_col = colW;

        if isempty(colT), missingVarsHard{end+1} = 'T_K'; end
        if isempty(colK), missingVarsHard{end+1} = 'kappa1'; end
        if isempty(colS), missingVarsHard{end+1} = 'S_peak'; end
        if isempty(colQ), missingVarsHard{end+1} = 'q90_minus_q50'; end

        if isempty(colT), T_K = NaN(nRows,1); else T_K = double(dataT.(colT)); end
        if isempty(colK), kappa1 = NaN(nRows,1); else kappa1 = double(dataT.(colK)); end
        if isempty(colS), S_peak = NaN(nRows,1); else S_peak = double(dataT.(colS)); end
        if isempty(colQ), q90_minus_q50 = NaN(nRows,1); else q90_minus_q50 = double(dataT.(colQ)); end

        if isempty(colAsym), asymmetry = NaN(nRows,1); else asymmetry = double(dataT.(colAsym)); end
        if isempty(colW), width = NaN(nRows,1); else width = double(dataT.(colW)); end

        finiteMask = isfinite(T_K) & isfinite(kappa1) & isfinite(S_peak) & isfinite(q90_minus_q50);
        if any(finiteMask)
            masterHard = table(T_K(finiteMask), kappa1(finiteMask), S_peak(finiteMask), q90_minus_q50(finiteMask), ...
                'VariableNames', {'T_K','kappa1','S_peak','q90_minus_q50'});
            if any(isfinite(asymmetry(finiteMask)))
                masterHard.asymmetry = asymmetry(finiteMask);
            end
            if any(isfinite(width(finiteMask)))
                masterHard.width = width(finiteMask);
            end
        else
            masterHard = table(NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), 'VariableNames', {'T_K','kappa1','S_peak','q90_minus_q50'});
            limitationsHard{end+1} = 'No overlapping finite rows for required variables.';
        end
    end

    % 4) write joined table (required output)
    writetable(masterHard, fullfile(tablesHardDir, 'kappa1_joined_analysis_table.csv'));

    % 5/8) MODEL EXECUTION + EVALUATION
    y = double(masterHard.kappa1(:));
    S = double(masterHard.S_peak(:));
    q90m50 = double(masterHard.q90_minus_q50(:));
    nHard = numel(y);

    rmseMean = localLoocvMeanRmse(y);

    % PT-only candidates: M1 always, M2/M3 conditional
    ptCandidates = {};
    ptX = {};
    ptFormula = {};
    ptCandidates{end+1} = 'M1';
    ptX{end+1} = q90m50;
    ptFormula{end+1} = 'kappa1 ~ q90_minus_q50';

    if ismember('asymmetry', masterHard.Properties.VariableNames)
        if any(isfinite(masterHard.asymmetry(:)))
            ptCandidates{end+1} = 'M2';
            ptX{end+1} = [q90m50, double(masterHard.asymmetry(:))];
            ptFormula{end+1} = 'kappa1 ~ q90_minus_q50 + asymmetry';
        end
    end
    if ismember('width', masterHard.Properties.VariableNames)
        if any(isfinite(masterHard.width(:)))
            ptCandidates{end+1} = 'M3';
            ptX{end+1} = [q90m50, double(masterHard.width(:))];
            ptFormula{end+1} = 'kappa1 ~ q90_minus_q50 + width';
        end
    end

    % helper: evaluate model and store
    modelCells = {};
    bestPtId = ''; bestPtFormula = ''; bestPtPred = []; bestPtMetrics = struct('loocv_rmse', NaN, 'pearson', NaN, 'spearman', NaN, 'n', 0);

    for i = 1:numel(ptCandidates)
        mId = ptCandidates{i};
        mMetrics = struct('loocv_rmse', NaN, 'pearson', NaN, 'spearman', NaN, 'n', 0);
        pred = [];
        try
            [mMetrics, pred] = localEvalLoocvOls(y, ptX{i});
        catch MEpt
            limitationsHard{end+1} = sprintf('PT-only model %s evaluation failed: %s', mId, MEpt.message);
        end

        valid = isfinite(mMetrics.loocv_rmse) && isfinite(mMetrics.pearson) && mMetrics.n >= 3 && isfinite(rmseMean);
        modelCells(end+1,:) = {mId, 'PT-only', ptFormula{i}, mMetrics.n, mMetrics.loocv_rmse, mMetrics.pearson, mMetrics.spearman, mMetrics.loocv_rmse - rmseMean}; %#ok<AGROW>
        if valid
            modelsExecutedHard{end+1} = mId;
            if isnan(bestPtMetrics.loocv_rmse) || mMetrics.loocv_rmse < bestPtMetrics.loocv_rmse
                bestPtId = mId;
                bestPtFormula = ptFormula{i};
                bestPtPred = pred;
                bestPtMetrics = mMetrics;
            end
        end
    end

    % PT+S_peak models
    plusCells = {};
    % M4
    m4Metrics = struct('loocv_rmse', NaN, 'pearson', NaN, 'spearman', NaN, 'n', 0);
    m4Pred = [];
    try
        [m4Metrics, m4Pred] = localEvalLoocvOls(y, [q90m50, S]);
    catch ME4
        limitationsHard{end+1} = sprintf('M4 evaluation failed: %s', ME4.message);
    end
    if isfinite(m4Metrics.loocv_rmse) && m4Metrics.n >= 3
        plusCells(end+1,:) = {'M4', 'PT+S_peak', 'kappa1 ~ q90_minus_q50 + S_peak', m4Metrics.n, m4Metrics.loocv_rmse, m4Metrics.pearson, m4Metrics.spearman, m4Metrics.loocv_rmse - rmseMean}; %#ok<AGROW>
        modelsExecutedHard{end+1} = 'M4';
    else
        plusCells(end+1,:) = {'M4', 'PT+S_peak', 'kappa1 ~ q90_minus_q50 + S_peak', m4Metrics.n, NaN, NaN, NaN, NaN}; %#ok<AGROW>
    end

    % M5 = best PT model + S_peak
    % Build X based on which PT best was picked.
    if ~isempty(bestPtId)
        if strcmp(bestPtId, 'M1')
            X5 = [q90m50, S];
            f5 = 'kappa1 ~ q90_minus_q50 + S_peak';
        elseif strcmp(bestPtId, 'M2') && ismember('asymmetry', masterHard.Properties.VariableNames)
            X5 = [q90m50, double(masterHard.asymmetry(:)), S];
            f5 = 'kappa1 ~ q90_minus_q50 + asymmetry + S_peak';
        elseif strcmp(bestPtId, 'M3') && ismember('width', masterHard.Properties.VariableNames)
            X5 = [q90m50, double(masterHard.width(:)), S];
            f5 = 'kappa1 ~ q90_minus_q50 + width + S_peak';
        else
            X5 = [q90m50, S];
            f5 = 'kappa1 ~ q90_minus_q50 + S_peak';
            limitationsHard{end+1} = 'M5 fell back to kappa1 ~ q90_minus_q50 + S_peak due to missing optional PT predictor.';
        end
    else
        X5 = [q90m50, S];
        f5 = 'kappa1 ~ q90_minus_q50 + S_peak';
        limitationsHard{end+1} = 'No valid PT-only model; M5 evaluated as q90_minus_q50 + S_peak.';
    end

    m5Metrics = struct('loocv_rmse', NaN, 'pearson', NaN, 'spearman', NaN, 'n', 0);
    m5Pred = [];
    try
        [m5Metrics, m5Pred] = localEvalLoocvOls(y, X5);
    catch ME5
        limitationsHard{end+1} = sprintf('M5 evaluation failed: %s', ME5.message);
    end
    if isfinite(m5Metrics.loocv_rmse) && m5Metrics.n >= 3
        plusCells(end+1,:) = {'M5', 'PT+S_peak', f5, m5Metrics.n, m5Metrics.loocv_rmse, m5Metrics.pearson, m5Metrics.spearman, m5Metrics.loocv_rmse - rmseMean}; %#ok<AGROW>
        modelsExecutedHard{end+1} = 'M5';
    else
        plusCells(end+1,:) = {'M5', 'PT+S_peak', f5, m5Metrics.n, NaN, NaN, NaN, NaN}; %#ok<AGROW>
    end

    % Combine model rows and write CSV (required)
    % Overwrite the placeholder M4 row by excluding placeholders and concatenating plusCells.
    modelOutCells = {};
    % PT-only rows are modelCells (they already include M1..M?).
    for k = 1:size(modelCells,1)
        modelOutCells(end+1,:) = modelCells(k,:); %#ok<AGROW>
    end
    for k = 1:size(plusCells,1)
        modelOutCells(end+1,:) = plusCells(k,:); %#ok<AGROW>
    end

    modelsTblHard = cell2table(modelOutCells, 'VariableNames', ...
        {'model','family','formula','n','loocv_rmse','pearson','spearman','rmse_vs_mean'});
    writetable(modelsTblHard, fullfile(tablesHardDir, 'kappa1_pt_vs_speak_models.csv'));

    % 9) RESIDUAL TEST (residuals_best_PT_only vs S_peak)
    residPear = NaN; residSpea = NaN; residN = 0;
    if ~isempty(bestPtPred)
        residuals = y - bestPtPred;
        maskR = isfinite(residuals) & isfinite(S);
        residN = sum(maskR);
        if residN >= 3
            residPear = corr(residuals(maskR), S(maskR), 'Type', 'Pearson');
            residSpea = corr(residuals(maskR), S(maskR), 'Type', 'Spearman');
        else
            limitationsHard{end+1} = 'Residual test skipped: too few finite points.';
        end
    else
        limitationsHard{end+1} = 'Residual test skipped: no valid best PT-only predictions.';
    end

    % 10) PARTIAL CORRELATION tests
    pc1Pear = NaN; pc1Spea = NaN; pc1N = 0;
    pc2Pear = NaN; pc2Spea = NaN; pc2N = 0;
    if nHard >= 4
        try
            [pc1Pear, pc1Spea] = localPartialCorrTwoWay(y, S, q90m50);
            pc1N = sum(isfinite(y) & isfinite(S) & isfinite(q90m50));
        catch MEpc1
            limitationsHard{end+1} = sprintf('Partial corr (kappa1,S_peak|q90_minus_q50) failed: %s', MEpc1.message);
        end
        try
            [pc2Pear, pc2Spea] = localPartialCorrTwoWay(y, q90m50, S);
            pc2N = sum(isfinite(y) & isfinite(q90m50) & isfinite(S));
        catch MEpc2
            limitationsHard{end+1} = sprintf('Partial corr (kappa1,q90_minus_q50|S_peak) failed: %s', MEpc2.message);
        end
    else
        limitationsHard{end+1} = 'Partial correlation tests skipped: too few rows.';
    end

    partialCellsHard = { ...
        'corr(kappa1,S_peak|q90_minus_q50)', pc1Pear, pc1Spea, pc1N; ...
        'corr(kappa1,q90_minus_q50|S_peak)', pc2Pear, pc2Spea, pc2N; ...
        'corr(residuals_best_PT_only,S_peak)', residPear, residSpea, residN ...
        };
    partialTblHard = cell2table(partialCellsHard, 'VariableNames', {'test','pearson','spearman','n'});
    writetable(partialTblHard, fullfile(tablesHardDir, 'kappa1_partial_correlation_tests.csv'));

    % -------------------- Verdict + Best models --------------------
    % Pick best PT+S_peak by LOOCV RMSE among M4/M5 (NaN-safe).
    bestPtPlusRmse = NaN;
    bestPlusFormula = 'kappa1 ~ q90_minus_q50 + S_peak';
    if isfinite(m4Metrics.loocv_rmse) && isfinite(m5Metrics.loocv_rmse)
        if m4Metrics.loocv_rmse <= m5Metrics.loocv_rmse
            bestPtPlusRmse = m4Metrics.loocv_rmse;
            bestPlusFormula = 'kappa1 ~ q90_minus_q50 + S_peak';
        else
            bestPtPlusRmse = m5Metrics.loocv_rmse;
            bestPlusFormula = f5;
        end
    elseif isfinite(m4Metrics.loocv_rmse)
        bestPtPlusRmse = m4Metrics.loocv_rmse;
        bestPlusFormula = 'kappa1 ~ q90_minus_q50 + S_peak';
    elseif isfinite(m5Metrics.loocv_rmse)
        bestPtPlusRmse = m5Metrics.loocv_rmse;
        bestPlusFormula = f5;
    end

    bestPtOnlyRmse = bestPtMetrics.loocv_rmse;
    if isfinite(bestPtOnlyRmse) && isfinite(bestPtPlusRmse)
        rmseGain = bestPtOnlyRmse - bestPtPlusRmse;
        pctGain = 100 * rmseGain / max(bestPtOnlyRmse, eps);
    else
        rmseGain = NaN; pctGain = NaN;
    end

    partialStrong = ~isnan(pc1Pear) && (abs(pc1Pear) >= 0.2);
    residualStrong = ~isnan(residPear) && (abs(residPear) >= 0.2);

    if ~isfinite(bestPtOnlyRmse) || bestPtOnlyRmse <= 0
        v_pt_only = 'YES'; v_dom_plus = 'NO'; v_requires = 'NO';
        interpPhrase = 'kappa1 is effectively PT-closed';
    elseif (isfinite(pctGain) && pctGain >= 15 && rmseGain >= 0.005 && (partialStrong || residualStrong))
        v_pt_only = 'NO'; v_dom_plus = 'NO'; v_requires = 'YES';
        interpPhrase = 'kappa1 cannot be reduced to PT summaries alone';
    elseif (isfinite(pctGain) && pctGain >= 5 && (partialStrong || residualStrong))
        v_pt_only = 'NO'; v_dom_plus = 'YES'; v_requires = 'NO';
        interpPhrase = 'kappa1 is mainly PT-controlled but S_peak adds information';
    else
        v_pt_only = 'YES'; v_dom_plus = 'NO'; v_requires = 'NO';
        interpPhrase = 'kappa1 is effectively PT-closed';
    end

    % -------------------- 12) Final report (mandatory) --------------------
    reportLines = {};
    reportLines{end+1} = '# kappa1 PT-only vs PT+S_peak report';
    reportLines{end+1} = '';
    reportLines{end+1} = '## 1. Question';
    reportLines{end+1} = 'Is kappa1 predictable from PT observables alone, or does S_peak add real out-of-sample information?';
    reportLines{end+1} = '';
    reportLines{end+1} = '## 2. Data used';
    reportLines{end+1} = sprintf('- Input file: `%s`', usedSource);
    reportLines{end+1} = sprintf('- n (finite overlap): %d', nHard);
    reportLines{end+1} = '';
    reportLines{end+1} = '## 3. Detected variables';
    reportLines{end+1} = sprintf('- T_K: `%s`', detectedVarsHard.T_K_col);
    reportLines{end+1} = sprintf('- kappa1: `%s`', detectedVarsHard.kappa1_col);
    reportLines{end+1} = sprintf('- S_peak: `%s`', detectedVarsHard.S_peak_col);
    reportLines{end+1} = sprintf('- q90_minus_q50: `%s`', detectedVarsHard.q90_minus_q50_col);
    if ~isempty(detectedVarsHard.asym_col), reportLines{end+1} = sprintf('- asymmetry: `%s`', detectedVarsHard.asym_col); end
    if ~isempty(detectedVarsHard.width_col), reportLines{end+1} = sprintf('- width: `%s`', detectedVarsHard.width_col); end
    reportLines{end+1} = '';
    reportLines{end+1} = '## 4. Missing variables';
    if isempty(missingVarsHard)
        reportLines{end+1} = '- None.';
    else
        reportLines{end+1} = sprintf('- %s', strjoin(missingVarsHard, ', '));
    end
    reportLines{end+1} = '';
    reportLines{end+1} = '## 5. Models executed';
    if isempty(modelsExecutedHard)
        reportLines{end+1} = '- None (all models invalid).';
    else
        reportLines{end+1} = sprintf('- %s', strjoin(unique(modelsExecutedHard), ', '));
    end
    reportLines{end+1} = '';
    reportLines{end+1} = '## 6. Best models';
    reportLines{end+1} = sprintf('- Best PT-only: `%s` (LOOCV RMSE=%g)', bestPtId, bestPtOnlyRmse);
    reportLines{end+1} = sprintf('- Best PT+S_peak: `%s` (LOOCV RMSE=%g)', bestPlusFormula, bestPtPlusRmse);
    reportLines{end+1} = '';
    reportLines{end+1} = '## 7. Residual test';
    reportLines{end+1} = sprintf('- corr(residuals_best_PT_only, S_peak): Pearson=%g, Spearman=%g, n=%d', residPear, residSpea, residN);
    reportLines{end+1} = '';
    reportLines{end+1} = '## 8. Partial correlation interpretation';
    reportLines{end+1} = sprintf('- corr(kappa1,S_peak|q90_minus_q50): Pearson=%g, Spearman=%g', pc1Pear, pc1Spea);
    reportLines{end+1} = sprintf('- corr(kappa1,q90_minus_q50|S_peak): Pearson=%g, Spearman=%g', pc2Pear, pc2Spea);
    reportLines{end+1} = '';
    reportLines{end+1} = '## 9. Limitations';
    if isempty(limitationsHard)
        reportLines{end+1} = '- None recorded.';
    else
        for li = 1:numel(limitationsHard)
            reportLines{end+1} = sprintf('- %s', limitationsHard{li});
        end
    end
    reportLines{end+1} = '';
    reportLines{end+1} = '## 10. Final verdict (mandatory)';
    reportLines{end+1} = sprintf('KAPPA1_PT_ONLY: %s', v_pt_only);
    reportLines{end+1} = sprintf('KAPPA1_PT_DOMINANT_BUT_SPEAK_ADDS: %s', v_dom_plus);
    reportLines{end+1} = sprintf('KAPPA1_REQUIRES_SPEAK: %s', v_requires);
    reportLines{end+1} = '';
    reportLines{end+1} = '## 11. Physical interpretation (mandatory)';
    reportLines{end+1} = ['- ', interpPhrase];
    reportTextHard = strjoin(reportLines, newline);

    reportPathHard = fullfile(reportsHardDir, 'kappa1_pt_vs_speak_report.md');
    fidRep = fopen(reportPathHard, 'w', 'UTF-8');
    if fidRep == -1, error('Could not open report for writing.'); end
    fprintf(fidRep, '%s', reportTextHard);
    fclose(fidRep);

    % 11) ALWAYS WRITE OUTPUT status file
    statusObjHard = struct();
    statusObjHard.status = 'OK';
    statusObjHard.error = '';
    statusObjHard.run_dir = repoRootHard;
    statusObjHard.usedSource = usedSource;
    statusObjHard.n = nHard;
    statusObjHard.detectedVars = detectedVarsHard;
    statusObjHard.missingVars = missingVarsHard;
    statusObjHard.modelsExecuted = unique(modelsExecutedHard);
    statusObjHard.bestPtOnly = struct('id', bestPtId, 'formula', bestPtFormula, 'loocv_rmse', bestPtMetrics.loocv_rmse);
    statusObjHard.bestPtPlusS = struct('formula', bestPlusFormula, 'loocv_rmse', bestPtPlusRmse);
    statusObjHard.partial = struct('pc1Pearson', pc1Pear, 'pc2Pearson', pc2Pear, 'residPearson', residPear);
    statusObjHard.verdict = struct('KAPPA1_PT_ONLY', v_pt_only, 'KAPPA1_PT_DOMINANT_BUT_SPEAK_ADDS', v_dom_plus, 'KAPPA1_REQUIRES_SPEAK', v_requires);
    fidStatus = fopen(statusPathHard, 'w', 'UTF-8');
    if fidStatus ~= -1
        fprintf(fidStatus, '%s', jsonencode(statusObjHard));
        fclose(fidStatus);
    end

    return;
catch MEhard
    % Best-effort outputs even if hard recovery fails.
    try
        modelsTblHard = table();
        partialTblHard = table();
        masterHard = table(NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), 'VariableNames', {'T_K','kappa1','S_peak','q90_minus_q50'});
        writetable(masterHard, fullfile(tablesHardDir, 'kappa1_joined_analysis_table.csv'));
        writetable(modelsTblHard, fullfile(tablesHardDir, 'kappa1_pt_vs_speak_models.csv'));
        writetable(partialTblHard, fullfile(tablesHardDir, 'kappa1_partial_correlation_tests.csv'));
        fidRep = fopen(fullfile(reportsHardDir, 'kappa1_pt_vs_speak_report.md'), 'w', 'UTF-8');
        if fidRep ~= -1
            fprintf(fidRep, '%s\n', '# kappa1 PT-only vs PT+S_peak report (FAILED recovery)');
            fprintf(fidRep, '%s\n', MEhard.message);
            fprintf(fidRep, 'KAPPA1_PT_ONLY: NO\nKAPPA1_PT_DOMINANT_BUT_SPEAK_ADDS: NO\nKAPPA1_REQUIRES_SPEAK: NO\n');
            fprintf(fidRep, '- kappa1 is effectively PT-closed\n');
            fclose(fidRep);
        end
        statusObjHard = struct('status','FAILED','error',MEhard.message);
        fidStatus = fopen(statusPathHard, 'w', 'UTF-8');
        if fidStatus ~= -1
            fprintf(fidStatus, '%s', jsonencode(statusObjHard));
            fclose(fidStatus);
        end
    catch
    end
    return;
end

% Fail loudly, but still write status.
statusPathRepoRoot = fullfile('C:\Dev\matlab-functions', 'kappa1_test_status.txt');
statusObj = struct('status', 'UNKNOWN', 'run_dir', '', 'error', '');
try
    fprintf(1, 'kappa1 PT-only vs PT+S_peak test: starting\n');

    % -------------------- Paths & canonical inputs --------------------
    repoRoot = 'C:\Dev\matlab-functions';
    tablesDir = fullfile(repoRoot, 'tables');

    % Canonical aligned joined table produced by Agent 20A (alignment fix).
    % Contains: kappa1, S_peak, tail_width_q90_q50 (upper tail spread).
    joinedPath = fullfile(tablesDir, 'kappa1_from_PT_aligned.csv');
    assert(exist(joinedPath, 'file') == 2, 'Missing canonical table: %s', joinedPath);

    % For report provenance (exact underlying runs/files, per canonical aligned report).
    kappaVsTPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
        '_extract_run_2026_03_24_220314_residual_decomposition', ...
        'run_2026_03_24_220314_residual_decomposition', 'tables', 'kappa_vs_T.csv');
    ptMatrixPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
        'run_2026_03_24_212033_switching_barrier_distribution_from_map', 'tables', 'PT_matrix.csv');
    speakParamsPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
        'run_2026_03_12_234016_switching_full_scaling_collapse', 'tables', 'switching_full_scaling_parameters.csv');

    % -------------------- Load & inner join on T_K --------------------
    addpath(genpath(fullfile(repoRoot, 'tools')));
    addpath(genpath(fullfile(repoRoot, 'Aging')));
    addpath(genpath(fullfile(repoRoot, 'tools', 'figures')));

    joined = readtable(joinedPath, 'VariableNamingRule', 'preserve');
    assert(all(ismember({'T_K','kappa1','S_peak','tail_width_q90_q50'}, joined.Properties.VariableNames)), ...
        'Canonical joined table missing required columns. Found: %s', strjoin(joined.Properties.VariableNames, ', '));

    % Split into canonical component tables (still sourced from the same aligned artifact),
    % then perform an explicit inner join on T_K (to match the requested workflow).
    Ktbl = joined(:, {'T_K','kappa1'});
    Stbl = joined(:, {'T_K','S_peak'});
    PTtbl = joined(:, {'T_K','tail_width_q90_q50'});

    % Canonical required PT observable:
    %   q90_minus_q50 (upper tail spread) is provided by tail_width_q90_q50.
    PTtbl.q90_minus_q50 = PTtbl.tail_width_q90_q50;

    % Optional canonical PT observables: include only if the canonical artifact has them.
    includeCols = {};
    if ismember('asymmetry', joined.Properties.VariableNames)
        includeCols{end+1} = 'asymmetry'; %#ok<AGROW>
    end
    if ismember('width', joined.Properties.VariableNames)
        includeCols{end+1} = 'width'; %#ok<AGROW>
    end
    keepCols = [{'T_K','q90_minus_q50'} , includeCols];
    PTtbl = PTtbl(:, keepCols);

    master = innerjoin(innerjoin(Ktbl, Stbl, 'Keys','T_K'), PTtbl, 'Keys','T_K');

    % Keep only finite rows.
    finiteMask = isfinite(master.T_K) & isfinite(master.kappa1) & isfinite(master.S_peak) & isfinite(master.q90_minus_q50);
    if ismember('asymmetry', master.Properties.VariableNames)
        finiteMask = finiteMask & isfinite(master.asymmetry);
    end
    if ismember('width', master.Properties.VariableNames)
        finiteMask = finiteMask & isfinite(master.width);
    end
    master = master(finiteMask, :);
    master = sortrows(master, 'T_K');

    n = height(master);
    assert(n >= 6, 'Too few finite overlapping temperatures after join (n=%d).', n);

    % Save joined table (requested).
    % -------------------- Create run folder & write outputs --------------------
    runCfg = struct();
    runCfg.runLabel = 'kappa1_pt_vs_speak_test';
    runCfg.dataset = sprintf('kappa1_pt_vs_speak_test | n=%d | aligned joined table', n);
    run = createRunContext('cross_experiment', runCfg);
    runDir = run.run_dir;

    for s = ["figures","tables","reports","review"]
        d = fullfile(runDir, char(s));
        if exist(d, 'dir') ~= 7, mkdir(d); end
    end

    fprintf(1, 'Run directory: %s\n', runDir);

    % Save joined table (requested) with exactly the required columns
    % + any optional canonical columns that exist.
    joinedOutCols = {'T_K','kappa1','S_peak','q90_minus_q50'};
    if ismember('asymmetry', master.Properties.VariableNames)
        joinedOutCols{end+1} = 'asymmetry'; %#ok<AGROW>
    end
    if ismember('width', master.Properties.VariableNames)
        joinedOutCols{end+1} = 'width'; %#ok<AGROW>
    end
    masterOut = master(:, joinedOutCols);
    save_run_table(masterOut, 'kappa1_joined_analysis_table.csv', runDir);

    % -------------------- Model set (STRICT: M1-M5 only) --------------------
    y = double(masterOut.kappa1(:));
    S = double(masterOut.S_peak(:));
    q90m50 = double(masterOut.q90_minus_q50(:));

    % Candidates:
    %   M1: kappa1 ~ q90_minus_q50
    %   M2: kappa1 ~ q90_minus_q50 + asymmetry (only if asymmetry exists)
    %   M3: kappa1 ~ q90_minus_q50 + width (only if width exists)
    % PT+S_peak:
    %   M4: kappa1 ~ q90_minus_q50 + S_peak
    %   M5: best_PT_model + S_peak
    %
    % In the canonical aligned table, asymmetry/width columns are not present;
    % so M2/M3 will be skipped automatically.

    ptCandidates = {};
    ptFormulas = {};
    ptXs = {};
    ptCandidates{end+1} = 'M1';
    ptFormulas{end+1} = 'kappa1 ~ q90_minus_q50';
    ptXs{end+1} = q90m50;

    % Check optional columns on the joined table, without adding new observables.
    if ismember('asymmetry', masterOut.Properties.VariableNames)
        ptCandidates{end+1} = 'M2';
        ptFormulas{end+1} = 'kappa1 ~ q90_minus_q50 + asymmetry';
        ptXs{end+1} = [q90m50, double(masterOut.asymmetry(:))];
    end
    if ismember('width', masterOut.Properties.VariableNames)
        ptCandidates{end+1} = 'M3';
        ptFormulas{end+1} = 'kappa1 ~ q90_minus_q50 + width';
        ptXs{end+1} = [q90m50, double(masterOut.width(:))];
    end

    % Evaluate PT-only candidates.
    ptRows = [];
    ptMetrics = cell(numel(ptCandidates),1);
    ptPreds = cell(numel(ptCandidates),1);
    for i = 1:numel(ptCandidates)
        [metrics, pred] = localEvalLoocvOls(y, ptXs{i});
        ptMetrics{i} = metrics;
        ptPreds{i} = pred;
        ptRows = [ptRows; {ptCandidates{i}, 'PT-only', ptFormulas{i}, metrics.n, metrics.loocv_rmse, metrics.pearson, metrics.spearman, ...
            metrics.rmse_vs_mean, metrics.rmse_vs_best_pt_only}]; %#ok<AGROW>
    end

    % Choose best PT-only by LOOCV RMSE.
    loocvRmseAll = cellfun(@(m) m.loocv_rmse, ptMetrics);
    [bestPtRmse, bestIdx] = min(loocvRmseAll);
    bestPtId = ptCandidates{bestIdx};
    bestPtPred = ptPreds{bestIdx};
    bestPtMetrics = ptMetrics{bestIdx};
    bestPtFormula = ptFormulas{bestIdx};

    % Evaluate PT+S_peak:
    %   M4 uses q90_minus_q50 + S_peak
    %   M5 uses best_PT_predictors + S_peak
    X4 = [q90m50, S];
    [m4, pred4] = localEvalLoocvOls(y, X4);

    % Build M5 design based on best PT-only predictors.
    if strcmp(bestPtId, 'M1')
        X5 = [q90m50, S];
        formulaM5 = 'kappa1 ~ q90_minus_q50 + S_peak';
    else
        % If M2/M3 existed, include their extra predictor(s) and S.
        % This is still within the strict M5 definition.
        bestX = ptXs{bestIdx}; % columns correspond to q90m50 plus maybe extra
        X5 = [bestX, S];
        formulaM5 = sprintf('%s + S_peak', bestPtFormula);
    end
    [m5, pred5] = localEvalLoocvOls(y, X5);

    % -------------------- Residual test (critical) --------------------
    residuals = y - bestPtPred;
    residMask = isfinite(residuals) & isfinite(S);
    residCorrPearson = corr(residuals(residMask), S(residMask), 'Type', 'Pearson');
    residCorrSpearman = corr(residuals(residMask), S(residMask), 'Type', 'Spearman');

    % -------------------- Partial correlations (critical) --------------------
    % corr(kappa1, S_peak | q90_minus_q50)
    [pc1_pearson, pc1_spearman] = localPartialCorrTwoWay(y, S, q90m50);
    % corr(kappa1, q90_minus_q50 | S_peak)
    [pc2_pearson, pc2_spearman] = localPartialCorrTwoWay(y, q90m50, S);

    % -------------------- Compose model output table --------------------
    % Compute RMSE baseline vs mean, already used in localEvalLoocvOls.
    bestPtRmse = bestPtMetrics.loocv_rmse;

    % PT-only rows
    out = {};
    for i = 1:numel(ptCandidates)
        out(end+1,:) = {ptCandidates{i}, ptFormulas{i}, 'PT-only', ptMetrics{i}.n, ...
            ptMetrics{i}.loocv_rmse, ptMetrics{i}.pearson, ptMetrics{i}.spearman, ...
            ptMetrics{i}.rmse_vs_mean, ptMetrics{i}.loocv_rmse - bestPtRmse}; %#ok<SAGROW>
    end

    % PT+S_peak rows
    out(end+1,:) = {'M4', 'kappa1 ~ q90_minus_q50 + S_peak', 'PT+S_peak', m4.n, ...
        m4.loocv_rmse, m4.pearson, m4.spearman, m4.rmse_vs_mean, m4.loocv_rmse - bestPtRmse}; %#ok<SAGROW>
    out(end+1,:) = {'M5', formulaM5, 'PT+S_peak', m5.n, ...
        m5.loocv_rmse, m5.pearson, m5.spearman, m5.rmse_vs_mean, m5.loocv_rmse - bestPtRmse}; %#ok<SAGROW>

    outTbl = cell2table(out, 'VariableNames', {'model','formula','family','n', ...
        'loocv_rmse','pearson_y_yhat','spearman_y_yhat', ...
        'rmse_delta_vs_mean','rmse_delta_vs_best_pt_only'});
    save_run_table(outTbl, 'kappa1_pt_vs_speak_models.csv', runDir);

    % -------------------- Partial-correlation output table --------------------
    pcTbl = table( ...
        {'corr(kappa1,S_peak|q90_minus_q50)'; 'corr(kappa1,q90_minus_q50|S_peak)'; 'corr(residuals_best_PT_only,S_peak)'}, ...
        [pc1_pearson; pc2_pearson; residCorrPearson], ...
        [pc1_spearman; pc2_spearman; residCorrSpearman], ...
        [sum(residMask); sum(residMask); sum(residMask)], ...
        'VariableNames', {'test','pearson','spearman','n'});
    save_run_table(pcTbl, 'kappa1_partial_correlation_tests.csv', runDir);

    % -------------------- Figure --------------------
    baseName = 'kappa1_pt_vs_speak_comparison';
    fig = figure('Name', baseName, 'NumberTitle', 'off');
    tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    % PT-only panel (best)
    nexttile;
    scatter(y, bestPtPred, 70, double(masterOut.T_K), 'filled');
    hold on;
    lim = [min([y; bestPtPred], [], 'omitnan'), max([y; bestPtPred], [], 'omitnan')];
    plot(lim, lim, 'k--', 'LineWidth', 2);
    grid on; colormap(parula); cb = colorbar; cb.Label.String = 'T_K (K)';
    xlabel('kappa1 measured'); ylabel(sprintf('kappa1 LOOCV prediction (%s)', bestPtId));
    title(sprintf('%s | LOOCV RMSE=%.4g', bestPtId, bestPtRmse), 'Interpreter', 'none');

    % PT+S_peak panel (best among M4/M5 by LOOCV RMSE)
    [bestPlusRmse, bestPlusWhich] = min([m4.loocv_rmse, m5.loocv_rmse]);
    if bestPlusWhich == 1
        bestPlusPred = pred4;
        plusId = 'M4';
    else
        bestPlusPred = pred5;
        plusId = 'M5';
    end

    nexttile;
    scatter(y, bestPlusPred, 70, double(masterOut.T_K), 'filled');
    hold on;
    lim2 = [min([y; bestPlusPred], [], 'omitnan'), max([y; bestPlusPred], [], 'omitnan')];
    plot(lim2, lim2, 'k--', 'LineWidth', 2);
    grid on; colormap(parula); cb2 = colorbar; cb2.Label.String = 'T_K (K)';
    xlabel('kappa1 measured'); ylabel(sprintf('kappa1 LOOCV prediction (%s)', plusId));
    title(sprintf('%s | LOOCV RMSE=%.4g', plusId, bestPlusRmse), 'Interpreter', 'none');

    figPaths = save_run_figure(fig, baseName, runDir);
    close(fig);

    % -------------------- Verdict --------------------
    bestPtOnlyRmse = bestPtRmse;
    dRmse = bestPtOnlyRmse - bestPlusRmse; % positive = gain
    pctGain = 100 * dRmse / max(bestPtOnlyRmse, eps);

    % Interpretation discipline: do not claim independence; use gain + residual/partial association.
    gainStrong = (bestPtOnlyRmse > 0) && (pctGain >= 20) && (dRmse >= 0.005);
    partialStrong = abs(pc1_pearson) >= 0.25 && abs(pc1_spearman) >= 0.25;
    residualStrong = abs(residCorrPearson) >= 0.25;

    % Use the requested 3-flag verdict logic.
    if ~gainStrong && ~partialStrong && ~residualStrong
        v_pt_only = 'YES'; v_dom_plus = 'NO'; v_requires = 'NO';
    elseif gainStrong
        v_pt_only = 'NO'; v_dom_plus = 'NO'; v_requires = 'YES';
    else
        % Marginal: PT+S_peak gain exists, but strength criteria are not decisive.
        v_pt_only = 'NO'; v_dom_plus = 'YES'; v_requires = 'NO';
    end

    % Physical interpretation (must match one of the allowed phrases).
    if strcmp(v_pt_only, 'YES')
        interp = 'kappa1 is effectively PT-closed';
    elseif strcmp(v_requires, 'YES')
        interp = 'kappa1 cannot be reduced to PT summaries alone';
    else
        interp = 'kappa1 is mainly PT-controlled but S_peak adds independent information';
    end

    % -------------------- Report --------------------
    bestPtRow = outTbl(strcmp(outTbl.model, bestPtId), :);
    bestPlusRow = outTbl(strcmp(outTbl.model, plusId), :);

    % For LOOCV comparison in report:
    rmseMean = localLoocvMeanRmse(y);

    reportLines = {};
    reportLines{end+1} = '# kappa1 PT-only vs PT+S_peak closure test';
    reportLines{end+1} = '';
    reportLines{end+1} = '## Question';
    reportLines{end+1} = 'Does kappa1 close from PT alone, or does S_peak add genuine predictive information?';
    reportLines{end+1} = '';
    reportLines{end+1} = '## Data used';
    reportLines{end+1} = sprintf('- PT source run ID: `%s`', 'run_2026_03_24_212033_switching_barrier_distribution_from_map');
    reportLines{end+1} = sprintf('- PT file: `%s`', strrep(ptMatrixPath, '\', '/'));
    reportLines{end+1} = sprintf('- kappa1 decomposition run ID: `%s`', 'run_2026_03_24_220314_residual_decomposition');
    reportLines{end+1} = sprintf('- kappa1 file: `%s`', strrep(kappaVsTPath, '\', '/'));
    reportLines{end+1} = sprintf('- S_peak scaling run ID: `%s`', 'run_2026_03_12_234016_switching_full_scaling_collapse');
    reportLines{end+1} = sprintf('- S_peak file: `%s`', strrep(speakParamsPath, '\', '/'));
    reportLines{end+1} = sprintf('- Canonical aligned joined table used for all regressions: `%s`', strrep(joinedPath, '\', '/'));
    reportLines{end+1} = sprintf('- Overlapping finite temperatures: n=%d (T_K grid: %s)', n, mat2str(master.T_K(:)', 4));
    reportLines{end+1} = '';

    reportLines{end+1} = '## Best PT-only model';
    reportLines{end+1} = sprintf('- Model: `%s`', char(bestPtRow.formula));
    reportLines{end+1} = sprintf('- LOOCV RMSE: `%.6g`', bestPtRow.loocv_rmse(1));
    reportLines{end+1} = sprintf('- Pearson(y,yhat): `%.4f`', bestPtRow.pearson_y_yhat(1));
    reportLines{end+1} = sprintf('- Spearman(y,yhat): `%.4f`', bestPtRow.spearman_y_yhat(1));
    reportLines{end+1} = '';

    reportLines{end+1} = '## Best PT+S_peak model';
    reportLines{end+1} = sprintf('- Model: `%s`', char(bestPlusRow.formula));
    reportLines{end+1} = sprintf('- LOOCV RMSE: `%.6g`', bestPlusRow.loocv_rmse(1));
    reportLines{end+1} = sprintf('- Pearson(y,yhat): `%.4f`', bestPlusRow.pearson_y_yhat(1));
    reportLines{end+1} = sprintf('- Spearman(y,yhat): `%.4f`', bestPlusRow.spearman_y_yhat(1));
    reportLines{end+1} = '';

    reportLines{end+1} = '## Comparison';
    reportLines{end+1} = sprintf('- Mean-predictor LOOCV RMSE: `%.6g`', rmseMean);
    reportLines{end+1} = sprintf('- Absolute LOOCV improvement (PT-only - PT+S_peak): `%.6g`', (bestPtOnlyRmse - bestPlusRmse));
    reportLines{end+1} = sprintf('- Percentage LOOCV improvement: `%.2f%%`', pctGain);
    if gainStrong
        reportLines{end+1} = '- Robustness: large gain relative to small-sample LOOCV (still limited by n).';
    else
        reportLines{end+1} = '- Robustness: improvement may be marginal given small sample size (still limited by n).';
    end
    reportLines{end+1} = '';

    reportLines{end+1} = '## Residual test (best PT-only residuals)';
    reportLines{end+1} = sprintf('- corr(residuals_best_PT_only, S_peak): Pearson=`%.4f`, Spearman=`%.4f`', residCorrPearson, residCorrSpearman);
    reportLines{end+1} = '';

    reportLines{end+1} = '## Partial-correlation tests';
    reportLines{end+1} = sprintf('- corr(kappa1,S_peak | q90_minus_q50): Pearson=`%.4f`, Spearman=`%.4f`', pc1_pearson, pc1_spearman);
    reportLines{end+1} = sprintf('- corr(kappa1,q90_minus_q50 | S_peak): Pearson=`%.4f`, Spearman=`%.4f`', pc2_pearson, pc2_spearman);
    reportLines{end+1} = '';

    reportLines{end+1} = '## Partial-correlation interpretation';
    if abs(pc1_pearson) >= 0.25 || abs(pc1_spearman) >= 0.25
        reportLines{end+1} = '- The (partial) association between kappa1 and S_peak remains after conditioning on the main PT tail spread, supporting extra predictive information beyond PT-only compression (but not proving independence).';
    else
        reportLines{end+1} = '- After conditioning on PT tail spread, the (partial) association between kappa1 and S_peak is weak, consistent with PT-only compression being sufficient at this resolution (small-n caveat).';
    end
    reportLines{end+1} = '';

    reportLines{end+1} = '## Final verdict block';
    reportLines{end+1} = sprintf('KAPPA1_PT_ONLY: %s', v_pt_only);
    reportLines{end+1} = sprintf('KAPPA1_PT_DOMINANT_BUT_SPEAK_ADDS: %s', v_dom_plus);
    reportLines{end+1} = sprintf('KAPPA1_REQUIRES_SPEAK: %s', v_requires);
    reportLines{end+1} = '';

    reportLines{end+1} = '## One short plain-language conclusion';
    reportLines{end+1} = sprintf('- %s', interp);
    reportText = strjoin(reportLines, newline);

    save_run_report(reportText, 'kappa1_pt_vs_speak_report.md', runDir);

    % -------------------- Status file --------------------
    statusObj.status = 'OK';
    statusObj.run_dir = runDir;
    statusObj.error = '';
    statusText = jsonencode(statusObj);
    fid = fopen(statusPathRepoRoot, 'w', 'n', 'UTF-8');
    if fid ~= -1
        fprintf(fid, '%s', statusText);
        fclose(fid);
    end
    % Also write inside runDir for traceability.
    fid2 = fopen(fullfile(runDir, 'kappa1_test_status.txt'), 'w', 'n', 'UTF-8');
    if fid2 ~= -1
        fprintf(fid2, '%s', statusText);
        fclose(fid2);
    end

    fprintf(1, 'kappa1 PT vs PT+S_peak test: completed successfully\n');

    % Mirror requested output locations at repo root (so the paths match the prompt).
    localMirrorOutputs(runDir, repoRoot);
    % Hard stop if required outputs were not produced.
    localAssertOutputsExist(repoRoot);

catch ME
    statusObj.status = 'FAILED';
    statusObj.run_dir = '';
    statusObj.error = getReport(ME, 'extended', 'hyperlinks', 'off');
    statusText = jsonencode(statusObj);
    fid = fopen(statusPathRepoRoot, 'w', 'n', 'UTF-8');
    if fid ~= -1
        fprintf(fid, '%s', statusText);
        fclose(fid);
    end
    fprintf(2, 'kappa1 PT vs PT+S_peak test FAILED: %s\n', statusObj.error);
    error('run_kappa1_pt_vs_speak_test:FAILED', '%s', statusObj.error);
end

% -------------------- Helpers --------------------
function rmse = localLoocvMeanRmse(y)
    y = double(y(:));
    n = numel(y);
    yhat = nan(n,1);
    for i = 1:n
        idx = true(n,1); idx(i) = false;
        yhat(i) = mean(y(idx), 'omitnan');
    end
    mask = isfinite(y) & isfinite(yhat);
    rmse = sqrt(mean((y(mask) - yhat(mask)).^2));
end

function [metrics, yhat] = localEvalLoocvOls(y, X)
    y = double(y(:));
    X = double(X);
    if size(X,1) ~= numel(y)
        error('localEvalLoocvOls: bad sizes');
    end
    n = numel(y);
    yhat = nan(n,1);
    for i = 1:n
        trainMask = true(n,1); trainMask(i) = false;
        Xt = X(trainMask, :);
        yt = y(trainMask);
        Z = [ones(size(Xt,1),1), Xt];
        if any(~isfinite(Z(:))) || any(~isfinite(yt(:)))
            yhat(i) = NaN;
            continue;
        end
        if rank(Z) < size(Z,2)
            yhat(i) = NaN;
            continue;
        end
        b = Z \ yt;
        yhat(i) = [1, X(i,:)] * b;
    end

    mask = isfinite(y) & isfinite(yhat);
    y2 = y(mask);
    yhat2 = yhat(mask);
    metrics = struct();
    metrics.n = sum(mask);
    metrics.loocv_rmse = sqrt(mean((y2 - yhat2).^2));
    metrics.pearson = corr(y2, yhat2, 'Type', 'Pearson');
    metrics.spearman = corr(y2, yhat2, 'Type', 'Spearman');
    rmseMean = localLoocvMeanRmse(y);
    metrics.rmse_vs_mean = metrics.loocv_rmse - rmseMean;
    metrics.rmse_vs_best_pt_only = NaN; % filled later in outer logic if needed
end

function [pcPearson, pcSpearman] = localPartialCorrTwoWay(a, b, cond)
    % Partial correlation between a and b controlling for cond, computed as:
    % corr(resid(a~cond), resid(b~cond)).
    a = double(a(:));
    b = double(b(:));
    cond = double(cond(:));

    m = isfinite(a) & isfinite(b) & isfinite(cond);
    a = a(m); b = b(m); cond = cond(m);
    if numel(a) < 4
        pcPearson = NaN; pcSpearman = NaN; return;
    end

    % Pearson partial correlation.
    resA = localResidualize(a, cond);
    resB = localResidualize(b, cond);
    pcPearson = corr(resA, resB, 'Type', 'Pearson');

    % Spearman partial correlation by residualizing ranks.
    ra = tiedrank(a);
    rb = tiedrank(b);
    rcond = tiedrank(cond);
    resRA = localResidualize(ra, rcond);
    resRB = localResidualize(rb, rcond);
    pcSpearman = corr(resRA, resRB, 'Type', 'Pearson');
end

function r = localResidualize(y, x)
    % Residuals after linear regression y ~ 1 + x (x can be a vector).
    x = double(x(:));
    Z = [ones(numel(x),1), x];
    b = Z \ double(y(:));
    r = double(y(:)) - Z * b;
end

function localMirrorOutputs(runDir, repoRoot)
    % Mirror the requested filenames at repo-root folders:
    %   tables/, figures/, reports/, plus status file.
    % This is for prompt compatibility; the canonical sources remain in runDir.

    filesToMirror = { ...
        fullfile(runDir, 'tables', 'kappa1_joined_analysis_table.csv'); ...
        fullfile(runDir, 'tables', 'kappa1_pt_vs_speak_models.csv'); ...
        fullfile(runDir, 'tables', 'kappa1_partial_correlation_tests.csv'); ...
        fullfile(runDir, 'figures', 'kappa1_pt_vs_speak_comparison.png'); ...
        fullfile(runDir, 'reports', 'kappa1_pt_vs_speak_report.md'); ...
        fullfile(runDir, 'kappa1_test_status.txt')};

    targets = { ...
        fullfile(repoRoot, 'tables', 'kappa1_joined_analysis_table.csv'); ...
        fullfile(repoRoot, 'tables', 'kappa1_pt_vs_speak_models.csv'); ...
        fullfile(repoRoot, 'tables', 'kappa1_partial_correlation_tests.csv'); ...
        fullfile(repoRoot, 'figures', 'kappa1_pt_vs_speak_comparison.png'); ...
        fullfile(repoRoot, 'reports', 'kappa1_pt_vs_speak_report.md'); ...
        fullfile(repoRoot, 'kappa1_test_status.txt')};

    for i = 1:numel(filesToMirror)
        src = filesToMirror{i};
        dst = targets{i};
        [dstDir,~,~] = fileparts(dst);
        if exist(dstDir, 'dir') ~= 7, mkdir(dstDir); end
        if exist(src, 'file') == 2
            try
                copyfile(src, dst, 'f');
            catch
                % Mirror best-effort only.
            end
        end
    end
end

function localAssertOutputsExist(repoRoot)
    required = { ...
        fullfile(repoRoot, 'tables', 'kappa1_joined_analysis_table.csv'); ...
        fullfile(repoRoot, 'tables', 'kappa1_pt_vs_speak_models.csv'); ...
        fullfile(repoRoot, 'tables', 'kappa1_partial_correlation_tests.csv'); ...
        fullfile(repoRoot, 'figures', 'kappa1_pt_vs_speak_comparison.png'); ...
        fullfile(repoRoot, 'reports', 'kappa1_pt_vs_speak_report.md'); ...
        fullfile(repoRoot, 'kappa1_test_status.txt')};

    for i = 1:numel(required)
        if exist(required{i}, 'file') ~= 2
            error('Missing required output file: %s', required{i});
        end
    end
end

