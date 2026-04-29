fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    scriptDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(scriptDir);
    if exist(repoRoot, 'dir') ~= 7
        repoRoot = pwd;
    end
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'switching_gauge_atlas_preview';
cfg.fingerprint_script_path = mfilename('fullpath');

statusPath = fullfile(repoRoot, 'tables', 'switching_gauge_atlas_preview_status.csv');
baselineVsPath = fullfile(repoRoot, 'tables', 'switching_gauge_atlas_baseline_vs_stabilized.csv');
top15Path = fullfile(repoRoot, 'tables', 'switching_gauge_atlas_top15_finite.csv');
reportPath = fullfile(repoRoot, 'reports', 'switching_gauge_atlas_preview.md');
figureDir = fullfile(repoRoot, 'figures', 'switching', 'diagnostics');
figurePath = fullfile(figureDir, 'switching_gauge_atlas_G001_G254_G014_preview.png');

if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7
    mkdir(fullfile(repoRoot, 'tables'));
end
if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7
    mkdir(fullfile(repoRoot, 'reports'));
end
if exist(figureDir, 'dir') ~= 7
    mkdir(figureDir);
end

verdictKeys = { ...
    'GAUGE_ATLAS_PREVIEW_COMPLETE'
    'G001_BASELINE_INCLUDED'
    'G254_BEST_INCLUDED'
    'G014_LESS_SMOOTHED_COMPARATOR_INCLUDED'
    'S_AREA_POSITIVE_DOMINATES_TOP15'
    'PREVIEW_FIGURE_WRITTEN'
    'X_EFF_DECOMPOSITION_INCLUDED'
    'X_EFF_G001_COMPUTED'
    'X_EFF_G254_COMPUTED'
    'X_EFF_G014_COMPUTED'
    'X_EFF_PRIMARY_DOMAIN_AXIS_SCALING'
    'X_EFF_LABEL_USED'
    'G254_CANONICAL_COORDINATE_CLAIMED'
    'G014_CANONICAL_COORDINATE_CLAIMED'
    'X_CANON_CLAIMED'
    'UNIQUE_W_CLAIMED'
    'UNIQUE_S0_CLAIMED'
    'SAFE_TO_WRITE_SCALING_CLAIM'
    'CROSS_MODULE_SYNTHESIS_PERFORMED'};
verdictVals = { ...
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'
    'NO'};

executionStatus = table({'FAILED'}, {'NO'}, {'uninitialized'}, 0, {'preview not executed'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('switching', cfg);

    metricsPath = fullfile(repoRoot, 'tables', 'switching_gauge_definition_atlas_metrics.csv');
    bestPath = fullfile(repoRoot, 'tables', 'switching_gauge_definition_atlas_best_by_regime.csv');
    candidatesPath = fullfile(repoRoot, 'tables', 'switching_gauge_definition_atlas_candidates.csv');
    sLongPath = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_2026_04_03_000147_switching_canonical', 'tables', 'switching_canonical_S_long.csv');

    if exist(metricsPath, 'file') ~= 2
        error('Preview:MissingInput', 'Missing input: %s', metricsPath);
    end
    if exist(bestPath, 'file') ~= 2
        error('Preview:MissingInput', 'Missing input: %s', bestPath);
    end
    if exist(candidatesPath, 'file') ~= 2
        error('Preview:MissingInput', 'Missing input: %s', candidatesPath);
    end
    if exist(sLongPath, 'file') ~= 2
        error('Preview:MissingInput', 'Missing input: %s', sLongPath);
    end

    metricsTbl = readtable(metricsPath);
    bestTbl = readtable(bestPath);
    candTbl = readtable(candidatesPath); %#ok<NASGU>
    sTbl = readtable(sLongPath);

    tName = '';
    iName = '';
    sName = '';
    varNames = sTbl.Properties.VariableNames;
    for i = 1:numel(varNames)
        nm = lower(strtrim(varNames{i}));
        if strcmp(nm, 't_k') || strcmp(nm, 't') || strcmp(nm, 'temperature_k')
            tName = varNames{i};
        end
        if strcmp(nm, 'current_ma') || strcmp(nm, 'i_ma') || strcmp(nm, 'current') || strcmp(nm, 'i')
            iName = varNames{i};
        end
        if strcmp(nm, 's_percent') || strcmp(nm, 's') || strcmp(nm, 's_pct')
            sName = varNames{i};
        end
    end
    if isempty(tName) || isempty(iName) || isempty(sName)
        error('Preview:MissingColumns', 'Failed to resolve S_long columns.');
    end

    T = sTbl.(tName);
    I = sTbl.(iName);
    S = sTbl.(sName);
    valid = isfinite(T) & isfinite(I) & isfinite(S);
    T = T(valid);
    I = I(valid);
    S = S(valid);

    roundedT = round(T);
    uniqueT = unique(roundedT);
    uniqueT = sort(uniqueT);

    nT = numel(uniqueT);
    perT = table('Size', [nT 8], ...
        'VariableTypes', {'double','double','double','double','double','double','double','double'}, ...
        'VariableNames', {'T_K','I_peak_old','W_FWHM_crossing','S_peak_old','W_sigma_positive','S_area_positive','I_peak_smoothed_across_T','is_primary'});
    curveI = cell(nT,1);
    curveS = cell(nT,1);

    for it = 1:nT
        tk = uniqueT(it);
        idx = roundedT == tk;
        iVals = I(idx);
        sVals = S(idx);
        [iVals, ord] = sort(iVals);
        sVals = sVals(ord);

        if numel(iVals) < 4
            continue;
        end

        [sPeak, iMax] = max(sVals);
        iPeak = iVals(iMax);
        half = 0.5 * sPeak;

        leftX = NaN;
        for k = iMax:-1:2
            y1 = sVals(k-1);
            y2 = sVals(k);
            if (y1-half) * (y2-half) <= 0
                if abs(y2-y1) <= 1e-15
                    leftX = iVals(k);
                else
                    leftX = iVals(k-1) + (half-y1) * (iVals(k)-iVals(k-1)) / (y2-y1);
                end
                break;
            end
        end

        rightX = NaN;
        for k = iMax:(numel(iVals)-1)
            y1 = sVals(k);
            y2 = sVals(k+1);
            if (y1-half) * (y2-half) <= 0
                if abs(y2-y1) <= 1e-15
                    rightX = iVals(k);
                else
                    rightX = iVals(k) + (half-y1) * (iVals(k+1)-iVals(k)) / (y2-y1);
                end
                break;
            end
        end

        wFwhm = NaN;
        if isfinite(leftX) && isfinite(rightX) && rightX > leftX
            wFwhm = rightX - leftX;
        end

        wPos = max(sVals, 0);
        sumW = sum(wPos);
        wSigma = NaN;
        if sumW > 0 && isfinite(iPeak)
            wSigma = sqrt(sum(wPos .* (iVals - iPeak).^2) / sumW);
        end
        sAreaPositive = sum(wPos);

        perT.T_K(it) = tk;
        perT.I_peak_old(it) = iPeak;
        perT.W_FWHM_crossing(it) = wFwhm;
        perT.S_peak_old(it) = sPeak;
        perT.W_sigma_positive(it) = wSigma;
        perT.S_area_positive(it) = sAreaPositive;
        perT.is_primary(it) = double(tk < 31.5);
        curveI{it} = iVals;
        curveS{it} = sVals;
    end

    for it = 1:nT
        acc = [];
        for jt = max(1,it-1):min(nT,it+1)
            v = perT.I_peak_old(jt);
            if isfinite(v)
                acc = [acc; v]; %#ok<AGROW>
            end
        end
        if ~isempty(acc)
            perT.I_peak_smoothed_across_T(it) = mean(acc);
        else
            perT.I_peak_smoothed_across_T(it) = NaN;
        end
    end

    wanted = {'G001','G254','G014'};
    rows = [];
    for i = 1:numel(wanted)
        rr = find(strcmp(string(metricsTbl.combo_id), wanted{i}), 1, 'first');
        if ~isempty(rr)
            rows = [rows; rr]; %#ok<AGROW>
        end
    end
    if numel(rows) ~= 3
        error('Preview:MissingCombos', 'Required combo rows not found in metrics table.');
    end
    cmpTbl = metricsTbl(rows, :);
    cmpTbl = sortrows(cmpTbl, 'combo_id');

    finiteMask = isfinite(metricsTbl.primary_metric_mean_std) & isfinite(metricsTbl.high_primary_metric_mean_std) & metricsTbl.primary_valid_curves > 0;
    finiteTbl = metricsTbl(finiteMask, :);
    finiteTbl = sortrows(finiteTbl, {'high_primary_metric_mean_std','primary_metric_mean_std'}, {'ascend','ascend'});
    topN = min(15, height(finiteTbl));
    top15 = finiteTbl(1:topN, :);
    writetable(top15, top15Path);

    s0Top = string(top15.S0_candidate);
    uniqueS0 = unique(s0Top);
    counts = zeros(numel(uniqueS0),1);
    for i = 1:numel(uniqueS0)
        counts(i) = sum(s0Top == uniqueS0(i));
    end
    [maxCount, imax] = max(counts); %#ok<ASGLU>
    dominates = strcmp(uniqueS0(imax), "S_area_positive");

    g001Included = any(strcmp(string(cmpTbl.combo_id), 'G001'));
    g254Included = any(strcmp(string(cmpTbl.combo_id), 'G254'));
    g014Included = any(strcmp(string(cmpTbl.combo_id), 'G014'));

    if g001Included
        verdictVals{strcmp(verdictKeys,'G001_BASELINE_INCLUDED')} = {'YES'};
    end
    if g254Included
        verdictVals{strcmp(verdictKeys,'G254_BEST_INCLUDED')} = {'YES'};
    end
    if g014Included
        verdictVals{strcmp(verdictKeys,'G014_LESS_SMOOTHED_COMPARATOR_INCLUDED')} = {'YES'};
    end
    if dominates
        verdictVals{strcmp(verdictKeys,'S_AREA_POSITIVE_DOMINATES_TOP15')} = {'YES'};
    end

    xeffG001 = NaN(nT,1);
    xeffG254 = NaN(nT,1);
    xeffG014 = NaN(nT,1);
    for it = 1:nT
        iOld = perT.I_peak_old(it);
        iSm = perT.I_peak_smoothed_across_T(it);
        wF = perT.W_FWHM_crossing(it);
        wS = perT.W_sigma_positive(it);
        sPk = perT.S_peak_old(it);
        sAr = perT.S_area_positive(it);
        if isfinite(iOld) && isfinite(wF) && isfinite(sPk) && wF > 0 && abs(sPk) > 1e-15
            xeffG001(it) = iOld / (wF * sPk);
        end
        if isfinite(iSm) && isfinite(wS) && isfinite(sAr) && wS > 0 && abs(sAr) > 1e-15
            xeffG254(it) = iSm / (wS * sAr);
        end
        if isfinite(iOld) && isfinite(wS) && isfinite(sAr) && wS > 0 && abs(sAr) > 1e-15
            xeffG014(it) = iOld / (wS * sAr);
        end
    end

    baseVs = table();
    baseVs.T_K = perT.T_K;
    baseVs.X_eff_G001 = xeffG001;
    baseVs.X_eff_G254 = xeffG254;
    baseVs.X_eff_G014 = xeffG014;
    baseVs.ratio_X_G254_over_G001 = xeffG254 ./ xeffG001;
    baseVs.ratio_X_G014_over_G001 = xeffG014 ./ xeffG001;
    baseVs.delta_X_G254_minus_G001 = xeffG254 - xeffG001;
    baseVs.delta_X_G014_minus_G001 = xeffG014 - xeffG001;
    writetable(baseVs, baselineVsPath);

    if any(isfinite(xeffG001))
        verdictVals{strcmp(verdictKeys,'X_EFF_G001_COMPUTED')} = {'YES'};
    end
    if any(isfinite(xeffG254))
        verdictVals{strcmp(verdictKeys,'X_EFF_G254_COMPUTED')} = {'YES'};
    end
    if any(isfinite(xeffG014))
        verdictVals{strcmp(verdictKeys,'X_EFF_G014_COMPUTED')} = {'YES'};
    end
    verdictVals{strcmp(verdictKeys,'X_EFF_LABEL_USED')} = {'YES'};

    fig = figure('Visible', 'off', 'Position', [100 100 1700 1400]);

    gaugeIds = {'G001','G254','G014'};
    gaugeI0 = {'I_peak_old','I_peak_smoothed_across_T','I_peak_old'};
    gaugeW = {'W_FWHM_crossing','W_sigma_positive','W_sigma_positive'};
    gaugeS0 = {'S_peak_old','S_area_positive','S_area_positive'};

    for p = 1:3
        subplot(3,2,p);
        hold on;
        primaryIdx = find(perT.T_K < 31.5);
        if isempty(primaryIdx)
            error('Preview:NoPrimary', 'No primary-domain temperatures found.');
        end
        cmap = parula(numel(primaryIdx));
        ci = 1;
        for ii = 1:numel(primaryIdx)
            it = primaryIdx(ii);
            i0 = perT.(gaugeI0{p})(it);
            w0 = perT.(gaugeW{p})(it);
            s0 = perT.(gaugeS0{p})(it);
            if ~isfinite(i0) || ~isfinite(w0) || ~isfinite(s0) || w0 <= 0 || abs(s0) <= 1e-15
                continue;
            end
            iVals = curveI{it};
            sVals = curveS{it};
            if numel(iVals) < 4
                continue;
            end
            x = (iVals - i0) ./ w0;
            y = sVals ./ s0;
            keep = isfinite(x) & isfinite(y);
            if sum(keep) < 4
                continue;
            end
            x = x(keep);
            y = y(keep);
            if abs(perT.T_K(it) - 22.0) < 1e-6
                plot(x, y, 'k-', 'LineWidth', 2.2, 'DisplayName', '22K');
            else
                plot(x, y, '-', 'Color', cmap(ci,:), 'LineWidth', 1.1, 'HandleVisibility', 'off');
            end
            ci = min(ci + 1, size(cmap,1));
        end
        grid on;
        xlabel('(I-I0)/W');
        ylabel('S/S0');
        title(sprintf('%s primary collapse (T<31.5K)', gaugeIds{p}));
        legend('show', 'Location', 'best');
        hold off;
    end

    subplot(3,2,4);
    hold on;
    prim = perT.T_K < 31.5;
    diagMask = ~prim;
    plot(perT.T_K(diagMask), perT.S_peak_old(diagMask), 'o', 'Color', [0.6 0.6 0.6], 'DisplayName', 'S peak old (diag)');
    plot(perT.T_K(diagMask), perT.S_area_positive(diagMask), 's', 'Color', [0.6 0.6 0.6], 'DisplayName', 'S area positive (diag)');
    plot(perT.T_K(prim), perT.S_peak_old(prim), 'o-', 'Color', [0.1 0.35 0.8], 'LineWidth', 1.5, 'DisplayName', 'S peak old (primary)');
    plot(perT.T_K(prim), perT.S_area_positive(prim), 's-', 'Color', [0.85 0.33 0.1], 'LineWidth', 1.5, 'DisplayName', 'S area positive (primary)');
    xline(22, '--k', '22K', 'LabelVerticalAlignment', 'bottom');
    grid on;
    xlabel('T_K');
    ylabel('Amplitude/Area (arb.)');
    title('S_peak_old(T) vs S_area_positive(T)');
    legend('Location', 'best');
    hold off;

    subplot(3,2,5);
    hold on;
    plot(perT.T_K, xeffG001, 'o-', 'Color', [0.10 0.35 0.80], 'LineWidth', 1.3, 'DisplayName', 'X_eff G001');
    plot(perT.T_K, xeffG254, 's-', 'Color', [0.00 0.55 0.20], 'LineWidth', 1.3, 'DisplayName', 'X_eff G254');
    plot(perT.T_K, xeffG014, 'd-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.3, 'DisplayName', 'X_eff G014');
    xline(22, '--k', '22K', 'LabelVerticalAlignment', 'bottom');
    xline(31.5, ':k', '31.5K', 'LabelVerticalAlignment', 'bottom');
    d32 = abs(perT.T_K - 32) < 1e-6;
    d34 = abs(perT.T_K - 34) < 1e-6;
    if any(d32)
        plot(perT.T_K(d32), xeffG001(d32), 'ko', 'MarkerFaceColor', [0.8 0.8 0.8], 'HandleVisibility', 'off');
        plot(perT.T_K(d32), xeffG254(d32), 'ks', 'MarkerFaceColor', [0.8 0.8 0.8], 'HandleVisibility', 'off');
        plot(perT.T_K(d32), xeffG014(d32), 'kd', 'MarkerFaceColor', [0.8 0.8 0.8], 'HandleVisibility', 'off');
    end
    if any(d34)
        plot(perT.T_K(d34), xeffG001(d34), 'ko', 'MarkerFaceColor', [0.65 0.65 0.65], 'HandleVisibility', 'off');
        plot(perT.T_K(d34), xeffG254(d34), 'ks', 'MarkerFaceColor', [0.65 0.65 0.65], 'HandleVisibility', 'off');
        plot(perT.T_K(d34), xeffG014(d34), 'kd', 'MarkerFaceColor', [0.65 0.65 0.65], 'HandleVisibility', 'off');
    end
    primX = perT.T_K < 31.5;
    yPrim = [xeffG001(primX); xeffG254(primX); xeffG014(primX)];
    yPrim = yPrim(isfinite(yPrim));
    if ~isempty(yPrim)
        yLo = min(yPrim);
        yHi = max(yPrim);
        if yHi <= yLo
            yHi = yLo + 1.0;
        end
        pad = 0.08 * (yHi - yLo);
        ylim([yLo - pad, yHi + pad]);
        verdictVals{strcmp(verdictKeys,'X_EFF_PRIMARY_DOMAIN_AXIS_SCALING')} = {'YES'};
    end
    grid on;
    xlabel('T_K');
    ylabel('X_eff = I0/(W*S0)');
    title('F. X_eff(T) comparison (diagnostic gauge-specific)');
    legend('Location', 'best');
    hold off;

    subplot(3,2,6);
    hold on;
    primMask = perT.T_K < 31.5;
    medI001 = median(perT.I_peak_old(primMask & isfinite(perT.I_peak_old)));
    medW001 = median(perT.W_FWHM_crossing(primMask & isfinite(perT.W_FWHM_crossing) & perT.W_FWHM_crossing > 0));
    medS001 = median(perT.S_peak_old(primMask & isfinite(perT.S_peak_old) & abs(perT.S_peak_old) > 1e-15));
    medI254 = median(perT.I_peak_smoothed_across_T(primMask & isfinite(perT.I_peak_smoothed_across_T)));
    medW254 = median(perT.W_sigma_positive(primMask & isfinite(perT.W_sigma_positive) & perT.W_sigma_positive > 0));
    medS254 = median(perT.S_area_positive(primMask & isfinite(perT.S_area_positive) & abs(perT.S_area_positive) > 1e-15));
    medI014 = median(perT.I_peak_old(primMask & isfinite(perT.I_peak_old)));
    medW014 = medW254;
    medS014 = medS254;

    plot(perT.T_K, perT.I_peak_old ./ medI001, '-', 'Color', [0.10 0.35 0.80], 'LineWidth', 1.2, 'DisplayName', 'G001 I0/med');
    plot(perT.T_K, (1 ./ perT.W_FWHM_crossing) ./ (1 / medW001), '--', 'Color', [0.10 0.35 0.80], 'LineWidth', 1.2, 'DisplayName', 'G001 (1/W)/med');
    plot(perT.T_K, (1 ./ perT.S_peak_old) ./ (1 / medS001), ':', 'Color', [0.10 0.35 0.80], 'LineWidth', 1.2, 'DisplayName', 'G001 (1/S0)/med');

    plot(perT.T_K, perT.I_peak_smoothed_across_T ./ medI254, '-', 'Color', [0.00 0.55 0.20], 'LineWidth', 1.2, 'DisplayName', 'G254 I0/med');
    plot(perT.T_K, (1 ./ perT.W_sigma_positive) ./ (1 / medW254), '--', 'Color', [0.00 0.55 0.20], 'LineWidth', 1.2, 'DisplayName', 'G254 (1/W)/med');
    plot(perT.T_K, (1 ./ perT.S_area_positive) ./ (1 / medS254), ':', 'Color', [0.00 0.55 0.20], 'LineWidth', 1.2, 'DisplayName', 'G254 (1/S0)/med');

    plot(perT.T_K, perT.I_peak_old ./ medI014, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.2, 'DisplayName', 'G014 I0/med');
    plot(perT.T_K, (1 ./ perT.W_sigma_positive) ./ (1 / medW014), '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.2, 'DisplayName', 'G014 (1/W)/med');
    plot(perT.T_K, (1 ./ perT.S_area_positive) ./ (1 / medS014), ':', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.2, 'DisplayName', 'G014 (1/S0)/med');

    xline(22, '--k', '22K', 'LabelVerticalAlignment', 'bottom');
    xline(31.5, ':k', '31.5K', 'LabelVerticalAlignment', 'bottom');
    grid on;
    xlabel('T_K');
    ylabel('Normalized factor contribution');
    title('G. X_eff factor decomposition (gauge-specific)');
    legend('Location', 'eastoutside');
    hold off;
    verdictVals{strcmp(verdictKeys,'X_EFF_DECOMPOSITION_INCLUDED')} = {'YES'};

    exportgraphics(fig, figurePath, 'Resolution', 250);
    close(fig);
    if exist(figurePath, 'file') == 2
        verdictVals{strcmp(verdictKeys,'PREVIEW_FIGURE_WRITTEN')} = {'YES'};
    end

    if g001Included && g254Included && g014Included && exist(figurePath, 'file') == 2
        verdictVals{strcmp(verdictKeys,'GAUGE_ATLAS_PREVIEW_COMPLETE')} = {'YES'};
    end

    keyCol = string(verdictKeys(:));
    valCol = string(verdictVals(:));
    statusTbl = table(keyCol, valCol, 'VariableNames', {'verdict_key','verdict_value'});
    writetable(statusTbl, statusPath);

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('Preview:ReportWriteFail', 'Failed to write report.');
    end
    fprintf(fid, '# Switching gauge atlas preview (diagnostic only)\n\n');
    fprintf(fid, 'This preview compares baseline G001 against stabilized diagnostic candidates G254 and G014.\n');
    fprintf(fid, 'Interpretation boundary: G254/G014 are diagnostic stabilized effective gauges only. Canonical P0 gauge is unchanged.\n\n');
    fprintf(fid, '## Required comparisons\n');
    fprintf(fid, '- G001 = I_peak_old + W_FWHM_crossing + S_peak_old\n');
    fprintf(fid, '- G254 = I_peak_smoothed_across_T + W_sigma_positive + S_area_positive\n');
    fprintf(fid, '- G014 = I_peak_old + W_sigma_positive + S_area_positive\n\n');
    fprintf(fid, 'X_eff interpretation used: X_eff[I0,W,S0] = I0/(W*S0), gauge-specific diagnostic only (not canonical coordinate).\n\n');
    fprintf(fid, '## Best-by-regime reference\n');
    if height(bestTbl) > 0
        for i = 1:height(bestTbl)
            fprintf(fid, '- %s: %s\n', string(bestTbl.regime(i)), string(bestTbl.combo_id(i)));
        end
    else
        fprintf(fid, '- (empty)\n');
    end
    fprintf(fid, '\n## Top15 finite summary\n');
    fprintf(fid, '- rows: %d\n', height(top15));
    fprintf(fid, '- S_area_positive dominates top15: %s\n', string(statusTbl.verdict_value(statusTbl.verdict_key=="S_AREA_POSITIVE_DOMINATES_TOP15")));
    fprintf(fid, '\n## X_eff summary\n');
    fprintf(fid, '- finite X_eff G001 points: %d\n', sum(isfinite(xeffG001)));
    fprintf(fid, '- finite X_eff G254 points: %d\n', sum(isfinite(xeffG254)));
    fprintf(fid, '- finite X_eff G014 points: %d\n', sum(isfinite(xeffG014)));
    fprintf(fid, '\n## Verdicts\n');
    for i = 1:height(statusTbl)
        fprintf(fid, '- %s=%s\n', statusTbl.verdict_key(i), statusTbl.verdict_value(i));
    end
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nT, {'preview artifacts written'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    keyCol = string(verdictKeys(:));
    valCol = string(verdictVals(:));
    statusTbl = table(keyCol, valCol, 'VariableNames', {'verdict_key','verdict_value'});
    writetable(statusTbl, statusPath);

    if exist(baselineVsPath, 'file') ~= 2
        writetable(table(), baselineVsPath);
    end
    if exist(top15Path, 'file') ~= 2
        writetable(table(), top15Path);
    end

    fid = fopen(reportPath, 'w');
    if fid >= 0
        fprintf(fid, '# Switching gauge atlas preview (diagnostic only)\n\n');
        fprintf(fid, 'Execution failed.\n\n');
        fprintf(fid, '- ERROR: %s\n', ME.message);
        fclose(fid);
    end

    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'preview execution failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
