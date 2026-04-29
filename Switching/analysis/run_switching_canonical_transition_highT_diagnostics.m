% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: DIAGNOSTIC_FORENSIC / CANON_COLLAPSE_FAMILY reads — high-T transition diagnostics on gated canonical inputs
% EVIDENCE_STATUS: DIAGNOSTIC — hierarchy / width usage must stay labeled per switching_analysis_map.md
% UNSAFE_USE: universal backbone or corrected-old authority claims without authoritative tables
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
baseName = 'switching_canonical_transition_highT_diagnostics';

vHierarchyStatusConfirmed = 'NO';
vWidthScalingUsed = 'NO';
vGatePassConfirmed = 'NO';
vTransitionBandEvaluated = 'NO';
vHighTBandEvaluated = 'NO';
vTransitionSpecial = 'NO';
vHighTHotspot = 'NO';
vPhi2Localized = 'NO';
vFiguresWritten = 'NO';
vReadyBoundedPhysics = 'NO';

errPath = '';
domPath = '';
statusPath = '';
gatePath = '';
transitionPath = '';
figPath = '';
pngPath = '';

gateRows = struct('table_name', string.empty(0,1), 'table_path', string.empty(0,1), ...
    'validation_status', string.empty(0,1), 'failure_code', string.empty(0,1), ...
    'failure_message', string.empty(0,1), 'metadata_path', string.empty(0,1));

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'canonical_transition_highT_diagnostics';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    runFigures = fullfile(runDir, 'figures');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(runFigures, 'dir') ~= 7, mkdir(runFigures); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0, fprintf(fidTop, 'SCRIPT_ENTERED\n'); fclose(fidTop); end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    errPath = fullfile(repoRoot, 'tables', 'switching_canonical_collapse_hierarchy_error_vs_T.csv');
    domPath = fullfile(repoRoot, 'tables', 'switching_canonical_collapse_hierarchy_dominance.csv');
    statusPath = fullfile(repoRoot, 'tables', 'switching_canonical_collapse_hierarchy_status.csv');
    gatePath = fullfile(repoRoot, 'tables', 'switching_canonical_input_gate_status.csv');
    transitionPath = fullfile(repoRoot, 'tables', 'switching_transition_detection.csv');

    reqPaths = {errPath, domPath, statusPath, gatePath};
    reqNames = {'switching_canonical_collapse_hierarchy_error_vs_T.csv', ...
        'switching_canonical_collapse_hierarchy_dominance.csv', ...
        'switching_canonical_collapse_hierarchy_status.csv', ...
        'switching_canonical_input_gate_status.csv'};
    for i = 1:numel(reqPaths)
        if exist(reqPaths{i}, 'file') ~= 2
            error('run_switching_canonical_transition_highT_diagnostics:MissingInput', ...
                'Missing required canonical hierarchy input: %s (%s)', reqNames{i}, reqPaths{i});
        end
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    for i = 1:numel(reqPaths)
        metaPath = [reqPaths{i} '.meta.json'];
        if exist(metaPath, 'file') == 2
            try
                validateCanonicalInputTable(reqPaths{i}, switchingMergeStructCtx(ctxBase, struct('table_name', reqNames{i})));
                gateRows = switchingAddInputGateRow(gateRows, reqNames{i}, reqPaths{i}, 'PASS', '', '', metaPath);
            catch MEv
                gateRows = switchingAddInputGateRow(gateRows, reqNames{i}, reqPaths{i}, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), metaPath);
                rethrow(MEv);
            end
        else
            gateRows = switchingAddInputGateRow(gateRows, reqNames{i}, reqPaths{i}, 'PARTIAL', 'MISSING_METADATA', 'No metadata sidecar found for this table.', '');
        end
    end

    transitionLineageStatus = "NOT_USED";
    transitionNotes = "switching_transition_detection.csv not required for this bounded diagnostic.";
    if exist(transitionPath, 'file') == 2
        transitionMeta = [transitionPath '.meta.json'];
        if exist(transitionMeta, 'file') == 2
            try
                validateCanonicalInputTable(transitionPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_transition_detection.csv')));
                transitionLineageStatus = "VALIDATED";
                transitionNotes = "Transition table validated as canonical-context input.";
            catch
                transitionLineageStatus = "PARTIAL";
                transitionNotes = "Transition table present but validation for canonical_collapse context failed; not used as gated truth.";
            end
        else
            transitionLineageStatus = "PARTIAL";
            transitionNotes = "Transition table present but no metadata sidecar; treated as lineage-partial and not used as gated truth.";
        end
    end

    errCell = readcell(errPath, 'Delimiter', ',');
    if isempty(errCell) || size(errCell,1) < 2
        error('run_switching_canonical_transition_highT_diagnostics:BadErrorCsv', ...
            'Hierarchy error-vs-T CSV is empty or missing data rows.');
    end
    errHeaders = string(errCell(1,:));
    errNorm = lower(regexprep(errHeaders, '[^a-z0-9]', ''));
    if size(errCell,2) < 6
        error('run_switching_canonical_transition_highT_diagnostics:BadErrorCsvShape', ...
            'Hierarchy error-vs-T CSV has fewer than 6 columns.');
    end
    reqIdx = [1 2 3 4 5 6];
    errData = errCell(2:end,:);

    statusCell = readcell(statusPath, 'Delimiter', ',');
    if isempty(statusCell) || size(statusCell,1) < 2
        error('run_switching_canonical_transition_highT_diagnostics:BadStatusCsv', ...
            'Hierarchy status CSV is empty or missing data rows.');
    end
    statusHeaders = string(statusCell(1,:));
    statusNorm = lower(regexprep(statusHeaders, '[^a-z0-9]', ''));
    idxStatus = find(statusNorm == "status", 1, 'first');
    if isempty(idxStatus)
        idxStatus = 1;
    end
    statusRows = statusCell(2:end,:);
    statusOk = any(strcmpi(string(statusRows(:, idxStatus)), "SUCCESS"));
    widthOk = true;
    idxWidth = find(statusNorm == "usedwidthscaling", 1, 'first');
    idxNotes = find(statusNorm == "executionnotes", 1, 'first');
    if ~isempty(idxWidth)
        widthOk = all(strcmpi(string(statusRows(:, idxWidth)), "NO"));
    elseif ~isempty(idxNotes)
        widthOk = ~any(contains(lower(string(statusRows(:, idxNotes))), "width"));
    end
    if statusOk && widthOk
        vHierarchyStatusConfirmed = 'YES';
    end

    gatePass = false;
    gateCell = readcell(gatePath, 'Delimiter', ',');
    if ~isempty(gateCell) && size(gateCell,1) >= 2
        gateHeaders = string(gateCell(1,:));
        gateNorm = lower(regexprep(gateHeaders, '[^a-z0-9]', ''));
        idxGateVal = find(gateNorm == "validationstatus", 1, 'first');
        if isempty(idxGateVal) && size(gateCell,2) >= 3
            idxGateVal = 3;
        end
        if ~isempty(idxGateVal)
            gatePass = all(strcmpi(string(gateCell(2:end, idxGateVal)), "PASS"));
        end
    end
    if gatePass
        vGatePassConfirmed = 'YES';
    end

    idxErrWidth = find(errNorm == "usedwidthscaling", 1, 'first');
    if ~isempty(idxErrWidth)
        if any(strcmpi(string(errData(:, idxErrWidth)), "YES"))
            vWidthScalingUsed = 'YES';
        else
            vWidthScalingUsed = 'NO';
        end
    end
    vLegacyAlignmentUsed = 'NO';

    T = str2double(string(errData(:,reqIdx(1))));
    rmse0 = str2double(string(errData(:,reqIdx(2))));
    rmse1 = str2double(string(errData(:,reqIdx(3))));
    rmse2 = str2double(string(errData(:,reqIdx(4))));
    gain1 = str2double(string(errData(:,reqIdx(5))));
    gain2 = str2double(string(errData(:,reqIdx(6))));
    gain1Frac = NaN(size(gain1));
    gain2Frac = NaN(size(gain2));
    idxGain1Frac = find(errNorm == "gainphi1fraction", 1, 'first');
    if ~isempty(idxGain1Frac)
        gain1Frac = str2double(string(errData(:,idxGain1Frac)));
    else
        den0 = rmse0;
        m0 = isfinite(den0) & abs(den0) > eps;
        gain1Frac(m0) = gain1(m0) ./ den0(m0);
    end
    idxGain2Frac = find(errNorm == "gainphi2fraction", 1, 'first');
    if ~isempty(idxGain2Frac)
        gain2Frac = str2double(string(errData(:,idxGain2Frac)));
    else
        den1 = rmse1;
        m1 = isfinite(den1) & abs(den1) > eps;
        gain2Frac(m1) = gain2(m1) ./ den1(m1);
    end

    [T, ord] = sort(T, 'ascend');
    rmse0 = rmse0(ord);
    rmse1 = rmse1(ord);
    rmse2 = rmse2(ord);
    gain1 = gain1(ord);
    gain2 = gain2(ord);
    gain1Frac = gain1Frac(ord);
    gain2Frac = gain2Frac(ord);

    lowMask = T <= 12;
    transMask = T >= 22 & T <= 24;
    highMask = T >= 28;

    if ~any(transMask)
        [~, idt] = min(abs(T - 23));
        transMask = false(size(T));
        transMask(idt) = true;
    end
    if ~any(lowMask)
        [~, idl] = min(T);
        lowMask = false(size(T));
        lowMask(idl) = true;
    end
    if ~any(highMask)
        [~, idh] = max(T);
        highMask = false(size(T));
        highMask(idh) = true;
    end

    band = strings(size(T));
    band(:) = "other";
    band(lowMask) = "low_cold";
    band(transMask) = "transition_candidate";
    band(highMask) = "high_T";

    vTransitionBandEvaluated = 'YES';
    vHighTBandEvaluated = 'YES';

    bandOrder = ["low_cold","transition_candidate","high_T","other"];
    nB = numel(bandOrder);
    bandName = strings(nB,1);
    binsIncluded = strings(nB,1);
    nBins = zeros(nB,1);
    meanRmse0 = NaN(nB,1); medianRmse0 = NaN(nB,1); maxRmse0 = NaN(nB,1);
    meanRmse1 = NaN(nB,1); medianRmse1 = NaN(nB,1); maxRmse1 = NaN(nB,1);
    meanRmse2 = NaN(nB,1); medianRmse2 = NaN(nB,1); maxRmse2 = NaN(nB,1);
    meanGain1 = NaN(nB,1); medianGain1 = NaN(nB,1);
    meanGain2 = NaN(nB,1); medianGain2 = NaN(nB,1);
    meanGain1Frac = NaN(nB,1); meanGain2Frac = NaN(nB,1);

    for ib = 1:nB
        bandName(ib) = bandOrder(ib);
        m = band == bandOrder(ib);
        nBins(ib) = sum(m);
        if any(m)
            binsIncluded(ib) = strjoin(string(T(m)), ',');
            meanRmse0(ib) = mean(rmse0(m), 'omitnan');
            medianRmse0(ib) = median(rmse0(m), 'omitnan');
            maxRmse0(ib) = max(rmse0(m), [], 'omitnan');
            meanRmse1(ib) = mean(rmse1(m), 'omitnan');
            medianRmse1(ib) = median(rmse1(m), 'omitnan');
            maxRmse1(ib) = max(rmse1(m), [], 'omitnan');
            meanRmse2(ib) = mean(rmse2(m), 'omitnan');
            medianRmse2(ib) = median(rmse2(m), 'omitnan');
            maxRmse2(ib) = max(rmse2(m), [], 'omitnan');
            meanGain1(ib) = mean(gain1(m), 'omitnan');
            medianGain1(ib) = median(gain1(m), 'omitnan');
            meanGain2(ib) = mean(gain2(m), 'omitnan');
            medianGain2(ib) = median(gain2(m), 'omitnan');
            meanGain1Frac(ib) = mean(gain1Frac(m), 'omitnan');
            meanGain2Frac(ib) = mean(gain2Frac(m), 'omitnan');
        else
            binsIncluded(ib) = "";
        end
    end

    summaryBand = table( ...
        repmat("band_summary", nB, 1), bandName, binsIncluded, nBins, ...
        meanRmse0, medianRmse0, maxRmse0, ...
        meanRmse1, medianRmse1, maxRmse1, ...
        meanRmse2, medianRmse2, maxRmse2, ...
        meanGain1, medianGain1, meanGain2, medianGain2, ...
        meanGain1Frac, meanGain2Frac, repmat("", nB, 1), ...
        'VariableNames', {'row_type','band','T_bins_included','n_bins', ...
        'mean_rmse_backbone','median_rmse_backbone','max_rmse_backbone', ...
        'mean_rmse_backbone_phi1','median_rmse_backbone_phi1','max_rmse_backbone_phi1', ...
        'mean_rmse_backbone_phi1_phi2','median_rmse_backbone_phi1_phi2','max_rmse_backbone_phi1_phi2', ...
        'mean_gain_phi1','median_gain_phi1','mean_gain_phi2','median_gain_phi2', ...
        'mean_gain_phi1_fraction','mean_gain_phi2_fraction','notes'});

    [~, iTop0] = sort(rmse0, 'descend');
    [~, iTop1] = sort(rmse1, 'descend');
    [~, iTop2] = sort(rmse2, 'descend');
    [~, iTopG2] = sort(gain2, 'descend');
    kTop = min(5, numel(T));
    topNotes = strings(kTop,1);
    for it = 1:kTop
        topNotes(it) = sprintf('top_backbone_T=%g (%.6g); top_phi1_T=%g (%.6g); top_phi2_T=%g (%.6g); top_phi2_gain_T=%g (%.6g)', ...
            T(iTop0(it)), rmse0(iTop0(it)), ...
            T(iTop1(it)), rmse1(iTop1(it)), ...
            T(iTop2(it)), rmse2(iTop2(it)), ...
            T(iTopG2(it)), gain2(iTopG2(it)));
    end
    topTbl = table( ...
        repmat("hotspot", kTop, 1), repmat("hotspot_rank", kTop, 1), repmat("", kTop, 1), (1:kTop)', ...
        nan(kTop,1), nan(kTop,1), nan(kTop,1), ...
        nan(kTop,1), nan(kTop,1), nan(kTop,1), ...
        nan(kTop,1), nan(kTop,1), nan(kTop,1), ...
        nan(kTop,1), nan(kTop,1), nan(kTop,1), nan(kTop,1), ...
        nan(kTop,1), nan(kTop,1), string(topNotes), ...
        'VariableNames', summaryBand.Properties.VariableNames);

    summaryTbl = [summaryBand; topTbl];
    switchingWriteTableBothPaths(summaryTbl, repoRoot, runTables, 'switching_canonical_transition_highT_diagnostics_summary.csv');

    nonTransMask = band ~= "transition_candidate";
    if ~any(nonTransMask)
        nonTransMask = true(size(T));
    end
    transMean2 = mean(rmse2(transMask), 'omitnan');
    nonTransMed2 = median(rmse2(nonTransMask), 'omitnan');
    transitionTop = any(transMask(iTop2(1:min(3,numel(T)))));
    if isfinite(transMean2) && isfinite(nonTransMed2) && (transMean2 > 1.2 * nonTransMed2 || transitionTop)
        vTransitionSpecial = 'YES';
    end

    nonHighMask = band ~= "high_T";
    if ~any(nonHighMask)
        nonHighMask = true(size(T));
    end
    highMean2 = mean(rmse2(highMask), 'omitnan');
    nonHighMed2 = median(rmse2(nonHighMask), 'omitnan');
    highTop = any(highMask(iTop2(1:min(3,numel(T)))));
    if isfinite(highMean2) && isfinite(nonHighMed2) && (highMean2 > 1.2 * nonHighMed2 || highTop)
        vHighTHotspot = 'YES';
    end

    bandGain2 = [mean(gain2(lowMask), 'omitnan'), mean(gain2(transMask), 'omitnan'), mean(gain2(highMask), 'omitnan'), mean(gain2(band=="other"), 'omitnan')];
    [maxBandGain2, iBandMax] = max(bandGain2);
    medBandGain2 = median(bandGain2, 'omitnan');
    phi2LocalizationLabel = "broad_or_unclear";
    if isfinite(maxBandGain2) && isfinite(medBandGain2) && maxBandGain2 > 1.5 * max(medBandGain2, eps)
        vPhi2Localized = 'YES';
    end
    if iBandMax >= 1 && iBandMax <= numel(bandOrder)
        phi2LocalizationLabel = bandOrder(iBandMax);
    end

    if strcmp(vHierarchyStatusConfirmed, 'YES') && strcmp(vGatePassConfirmed, 'YES') && ...
       strcmp(vWidthScalingUsed, 'NO') && strcmp(vLegacyAlignmentUsed, 'NO')
        vReadyBoundedPhysics = 'YES';
    end

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [90, 90, 1200, 760]);
    tl = tiledlayout(2,1,'Parent',fig,'TileSpacing','compact','Padding','compact');

    nexttile(tl);
    hold on;
    plot(T, rmse0, '-o', 'LineWidth', 1.8);
    plot(T, rmse1, '-s', 'LineWidth', 1.8);
    plot(T, rmse2, '-d', 'LineWidth', 1.8);
    xline(22, '--', 'Color', [0.4 0.4 0.4]);
    xline(24, '--', 'Color', [0.4 0.4 0.4]);
    xline(28, '--', 'Color', [0.4 0.4 0.4]);
    hold off;
    xlabel('Temperature (K)');
    ylabel('RMSE');
    title('Canonical RMSE hierarchy vs T');
    legend({'backbone','+Phi1','+Phi2','22K','24K','28K'}, 'Location', 'best');
    grid on;

    nexttile(tl);
    hold on;
    plot(T, gain1, '-o', 'LineWidth', 1.8);
    plot(T, gain2, '-s', 'LineWidth', 1.8);
    yline(0, '--k');
    xline(22, '--', 'Color', [0.4 0.4 0.4]);
    xline(24, '--', 'Color', [0.4 0.4 0.4]);
    xline(28, '--', 'Color', [0.4 0.4 0.4]);
    hold off;
    xlabel('Temperature (K)');
    ylabel('RMSE gain');
    title('Gain by level vs T');
    legend({'gain Phi1','gain Phi2','zero','22K','24K','28K'}, 'Location', 'best');
    grid on;

    sgtitle(tl, 'Canonical transition/high-T diagnostics (bounded)', 'Interpreter', 'none');
    figPath = fullfile(runFigures, [baseName '.fig']);
    pngPath = fullfile(runFigures, [baseName '.png']);
    savefig(fig, figPath);
    exportgraphics(fig, pngPath, 'Resolution', 300);
    close(fig);
    vFiguresWritten = 'YES';

    statusTbl = table( ...
        {'CANONICAL_HIERARCHY_STATUS_CONFIRMED'; 'WIDTH_SCALING_USED'; 'GATE_PASS_CONFIRMED'; ...
         'TRANSITION_BAND_EVALUATED'; 'HIGH_T_BAND_EVALUATED'; 'TRANSITION_REMAINS_SPECIAL'; ...
         'HIGH_T_RESIDUAL_HOTSPOT'; 'PHI2_HELP_LOCALIZED'; 'FIGURES_WRITTEN'; ...
         'READY_FOR_BOUNDED_PHYSICS_INTERPRETATION'}, ...
        {vHierarchyStatusConfirmed; vWidthScalingUsed; vGatePassConfirmed; ...
         vTransitionBandEvaluated; vHighTBandEvaluated; vTransitionSpecial; ...
         vHighTHotspot; vPhi2Localized; vFiguresWritten; vReadyBoundedPhysics}, ...
        {sprintf('Hierarchy status SUCCESS=%d; used_width_scaling_NO=%d', statusOk, widthOk); ...
         'NO width coordinates, normalization, or shift-scale used'; ...
         sprintf('Input gate rows all PASS=%d', gatePass); ...
         sprintf('Transition bins included: %s', strjoin(string(T(transMask)), ',')); ...
         sprintf('High-T bins included: %s', strjoin(string(T(highMask)), ',')); ...
         sprintf('Criterion: transition mean rmse_phi2=%.6g vs non-transition median=%.6g; top3 includes transition=%d', transMean2, nonTransMed2, transitionTop); ...
         sprintf('Criterion: high-T mean rmse_phi2=%.6g vs non-high median=%.6g; top3 includes high-T=%d', highMean2, nonHighMed2, highTop); ...
         sprintf('Band with max mean Phi2 gain: %s (mean=%.6g)', phi2LocalizationLabel, maxBandGain2); ...
         char(pngPath); ...
         sprintf('bounded-ready=%s; transition_lineage=%s', vReadyBoundedPhysics, transitionLineageStatus)}, ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_canonical_transition_highT_diagnostics_status.csv');
    switchingWriteTableBothPaths(switchingInputGateRowsToTable(gateRows), repoRoot, runTables, 'switching_canonical_transition_highT_diagnostics_input_validation.csv');

    lines = {};
    lines{end+1} = '# Canonical Switching transition/high-T diagnostics (Stage 3)';
    lines{end+1} = '';
    lines{end+1} = '## Inputs';
    lines{end+1} = sprintf('- `%s`', errPath);
    lines{end+1} = sprintf('- `%s`', domPath);
    lines{end+1} = sprintf('- `%s`', statusPath);
    lines{end+1} = sprintf('- `%s`', gatePath);
    lines{end+1} = sprintf('- optional `%s` lineage status: `%s`', transitionPath, transitionLineageStatus);
    lines{end+1} = sprintf('- optional transition notes: %s', transitionNotes);
    lines{end+1} = '';
    lines{end+1} = '## Temperature bands (actual bins)';
    lines{end+1} = sprintf('- low/cold (<=12 K): `%s`', strjoin(string(T(lowMask)), ','));
    lines{end+1} = sprintf('- transition candidate (22-24 K or nearest): `%s`', strjoin(string(T(transMask)), ','));
    lines{end+1} = sprintf('- high-T (>=28 K or nearest): `%s`', strjoin(string(T(highMask)), ','));
    lines{end+1} = sprintf('- other baseline: `%s`', strjoin(string(T(band=="other")), ','));
    lines{end+1} = '';
    lines{end+1} = '## Global hierarchy check';
    lines{end+1} = sprintf('- rmse_backbone_global = %.6g', sqrt(mean(rmse0.^2, 'omitnan')));
    lines{end+1} = sprintf('- rmse_backbone_phi1_global = %.6g', sqrt(mean(rmse1.^2, 'omitnan')));
    lines{end+1} = sprintf('- rmse_backbone_phi1_phi2_global = %.6g', sqrt(mean(rmse2.^2, 'omitnan')));
    lines{end+1} = '';
    lines{end+1} = '## Hotspots';
    lines{end+1} = sprintf('- top backbone residual T bins: `%s`', strjoin(string(T(iTop0(1:kTop))), ','));
    lines{end+1} = sprintf('- top post-Phi1 residual T bins: `%s`', strjoin(string(T(iTop1(1:kTop))), ','));
    lines{end+1} = sprintf('- top post-Phi2 residual T bins: `%s`', strjoin(string(T(iTop2(1:kTop))), ','));
    lines{end+1} = sprintf('- top Phi2-gain T bins: `%s`', strjoin(string(T(iTopG2(1:kTop))), ','));
    lines{end+1} = '';
    lines{end+1} = '## Band interpretation';
    lines{end+1} = sprintf('- transition remains special: `%s`', vTransitionSpecial);
    lines{end+1} = sprintf('- high-T residual hotspot: `%s`', vHighTHotspot);
    lines{end+1} = sprintf('- Phi2 help localized: `%s` (max band=`%s`)', vPhi2Localized, phi2LocalizationLabel);
    lines{end+1} = '';
    lines{end+1} = '## Outputs';
    lines{end+1} = sprintf('- Figure `.fig`: `%s`', figPath);
    lines{end+1} = sprintf('- Figure `.png`: `%s`', pngPath);
    lines{end+1} = '- `tables/switching_canonical_transition_highT_diagnostics_summary.csv`';
    lines{end+1} = '- `tables/switching_canonical_transition_highT_diagnostics_status.csv`';
    lines{end+1} = '- `reports/switching_canonical_transition_highT_diagnostics.md`';
    lines{end+1} = '';
    lines{end+1} = '## Final verdicts';
    lines{end+1} = sprintf('- CANONICAL_HIERARCHY_STATUS_CONFIRMED = %s', vHierarchyStatusConfirmed);
    lines{end+1} = sprintf('- WIDTH_SCALING_USED = %s', vWidthScalingUsed);
    lines{end+1} = sprintf('- GATE_PASS_CONFIRMED = %s', vGatePassConfirmed);
    lines{end+1} = sprintf('- TRANSITION_BAND_EVALUATED = %s', vTransitionBandEvaluated);
    lines{end+1} = sprintf('- HIGH_T_BAND_EVALUATED = %s', vHighTBandEvaluated);
    lines{end+1} = sprintf('- TRANSITION_REMAINS_SPECIAL = %s', vTransitionSpecial);
    lines{end+1} = sprintf('- HIGH_T_RESIDUAL_HOTSPOT = %s', vHighTHotspot);
    lines{end+1} = sprintf('- PHI2_HELP_LOCALIZED = %s', vPhi2Localized);
    lines{end+1} = sprintf('- FIGURES_WRITTEN = %s', vFiguresWritten);
    lines{end+1} = sprintf('- READY_FOR_BOUNDED_PHYSICS_INTERPRETATION = %s', vReadyBoundedPhysics);

    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_canonical_transition_highT_diagnostics:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_transition_highT_diagnostics.md'), lines, 'run_switching_canonical_transition_highT_diagnostics:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, numel(T), {'canonical transition/high-T diagnostics completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_canonical_transition_highT_diagnostics_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    failMsg = char(string(ME.message));
    statusTbl = table( ...
        {'CANONICAL_HIERARCHY_STATUS_CONFIRMED'; 'WIDTH_SCALING_USED'; 'GATE_PASS_CONFIRMED'; ...
         'TRANSITION_BAND_EVALUATED'; 'HIGH_T_BAND_EVALUATED'; 'TRANSITION_REMAINS_SPECIAL'; ...
         'HIGH_T_RESIDUAL_HOTSPOT'; 'PHI2_HELP_LOCALIZED'; 'FIGURES_WRITTEN'; ...
         'READY_FOR_BOUNDED_PHYSICS_INTERPRETATION'}, ...
        {vHierarchyStatusConfirmed; vWidthScalingUsed; vGatePassConfirmed; ...
         vTransitionBandEvaluated; vHighTBandEvaluated; vTransitionSpecial; ...
         vHighTHotspot; vPhi2Localized; vFiguresWritten; vReadyBoundedPhysics}, ...
        {failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg}, ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_canonical_transition_highT_diagnostics_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_canonical_transition_highT_diagnostics_status.csv'));

    if isempty(gateRows.table_name)
        gateRows = switchingAddInputGateRow(gateRows, 'unknown', 'unknown', 'FAIL', char(string(ME.identifier)), failMsg, '');
    end
    gateFailTbl = switchingInputGateRowsToTable(gateRows);
    writetable(gateFailTbl, fullfile(runDir, 'tables', 'switching_canonical_transition_highT_diagnostics_input_validation.csv'));
    writetable(gateFailTbl, fullfile(repoRoot, 'tables', 'switching_canonical_transition_highT_diagnostics_input_validation.csv'));

    sumFail = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), string.empty(0,1), ...
        'VariableNames', {'row_type','band','T_bins_included','n_bins', ...
        'mean_rmse_backbone','median_rmse_backbone','max_rmse_backbone', ...
        'mean_rmse_backbone_phi1','median_rmse_backbone_phi1','max_rmse_backbone_phi1', ...
        'mean_rmse_backbone_phi1_phi2','median_rmse_backbone_phi1_phi2','max_rmse_backbone_phi1_phi2', ...
        'mean_gain_phi1','median_gain_phi1','mean_gain_phi2','median_gain_phi2', ...
        'mean_gain_phi1_fraction','mean_gain_phi2_fraction','notes'});
    writetable(sumFail, fullfile(runDir, 'tables', 'switching_canonical_transition_highT_diagnostics_summary.csv'));
    writetable(sumFail, fullfile(repoRoot, 'tables', 'switching_canonical_transition_highT_diagnostics_summary.csv'));

    lines = {};
    lines{end+1} = '# Canonical Switching transition/high-T diagnostics — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_canonical_transition_highT_diagnostics:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_canonical_transition_highT_diagnostics.md'), lines, 'run_switching_canonical_transition_highT_diagnostics:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'canonical transition/high-T diagnostics failed'}, true);
    rethrow(ME);
end
