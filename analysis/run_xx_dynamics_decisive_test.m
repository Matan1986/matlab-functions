fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXDecisive:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));

cfgRun = struct();
cfgRun.runLabel = 'xx_dynamics_decisive_test';
run = struct();

statusPath = fullfile(repoRoot, 'tables', 'xx_dynamics_decisive_status.csv');
alignmentPath = fullfile(repoRoot, 'tables', 'xx_dynamics_observable_alignment.csv');
metricsPath = fullfile(repoRoot, 'tables', 'xx_dynamics_metric_comparison.csv');
verdictsPath = fullfile(repoRoot, 'tables', 'xx_dynamics_decisive_verdicts.csv');
reportPath = fullfile(repoRoot, 'reports', 'xx_dynamics_decisive_test.md');

figDir = fullfile(repoRoot, 'figures');
if exist(figDir, 'dir') ~= 7
    mkdir(figDir);
end

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('analysis', cfgRun);

    slopePath = fullfile(repoRoot, 'tables', 'xx_drift_map.csv');
    cmPath = fullfile(repoRoot, 'tables', 'xx_decomposition_vs_temperature_35mA_drift.csv');

    if exist(slopePath, 'file') ~= 2
        error('XXDecisive:MissingSlope', 'Missing slopeRMS source table: %s', slopePath);
    end
    if exist(cmPath, 'file') ~= 2
        error('XXDecisive:MissingDecomp', 'Missing decomposition source table: %s', cmPath);
    end

    slopeTbl = readtable(slopePath, 'TextType', 'string');
    cmTbl = readtable(cmPath, 'TextType', 'string');

    reqSlope = {'temperature_K', 'current_mA', 'drift_slope_rms_median'};
    for i = 1:numel(reqSlope)
        if ~ismember(reqSlope{i}, slopeTbl.Properties.VariableNames)
            error('XXDecisive:MissingSlopeCol', 'Missing slope table column: %s', reqSlope{i});
        end
    end
    reqCm = {'temperature', 'mean_cm_drift_abs', 'mean_sw_drift_abs'};
    for i = 1:numel(reqCm)
        if ~ismember(reqCm{i}, cmTbl.Properties.VariableNames)
            error('XXDecisive:MissingDecompCol', 'Missing decomposition table column: %s', reqCm{i});
        end
    end

    slopeTbl.I_mA = double(slopeTbl.current_mA);
    slopeTbl.T_K = round(double(slopeTbl.temperature_K), 2);
    slopeTbl.slopeRMS = double(slopeTbl.drift_slope_rms_median);
    slopeTbl = slopeTbl(:, {'I_mA', 'T_K', 'slopeRMS'});
    slopeTbl = sortrows(slopeTbl, {'I_mA', 'T_K'});

    cmBaseT = round(double(cmTbl.temperature), 2);
    cmVal = double(cmTbl.mean_cm_drift_abs);
    swVal = double(cmTbl.mean_sw_drift_abs);
    finiteCm = isfinite(cmBaseT) & isfinite(cmVal);
    cmBaseT = cmBaseT(finiteCm);
    cmVal = cmVal(finiteCm);
    swVal = swVal(finiteCm);

    if isempty(cmBaseT)
        error('XXDecisive:NoCmData', 'No finite cm_drift_abs data available.');
    end

    overlapT = intersect(unique(slopeTbl.T_K(isfinite(slopeTbl.slopeRMS))), unique(cmBaseT));
    if isempty(overlapT)
        error('XXDecisive:NoOverlapT', 'No overlapping temperature support between slope and decomposition tables.');
    end

    iTarget = 35;
    idxSlopeAlign = abs(slopeTbl.I_mA - iTarget) < 1e-6 & ismember(slopeTbl.T_K, overlapT);
    slopeAlign = slopeTbl(idxSlopeAlign, :);
    if isempty(slopeAlign)
        error('XXDecisive:NoSlope35', 'No slopeRMS support at I=35 mA on overlap temperatures.');
    end

    allT = unique(slopeAlign.T_K);
    nT = numel(allT);
    I_mA = iTarget * ones(nT, 1);
    T_K = allT(:);
    slopeRMS = NaN(nT, 1);
    cm_drift_abs = NaN(nT, 1);
    sw_drift_abs = NaN(nT, 1);
    valid_slopeRMS = false(nT, 1);
    valid_cm_drift_abs = false(nT, 1);
    valid_sw_drift_abs = false(nT, 1);

    for k = 1:nT
        tk = T_K(k);
        idxS = abs(slopeAlign.T_K - tk) < 1e-9;
        if any(idxS)
            vS = slopeAlign.slopeRMS(idxS);
            if any(isfinite(vS))
                slopeRMS(k) = median(vS(isfinite(vS)), 'omitnan');
                valid_slopeRMS(k) = true;
            end
        end

        idxC = abs(cmBaseT - tk) < 1e-9;
        if any(idxC)
            vC = cmVal(idxC);
            if any(isfinite(vC))
                cm_drift_abs(k) = median(vC(isfinite(vC)), 'omitnan');
                valid_cm_drift_abs(k) = true;
            end
            vW = swVal(idxC);
            if any(isfinite(vW))
                sw_drift_abs(k) = median(vW(isfinite(vW)), 'omitnan');
                valid_sw_drift_abs(k) = true;
            end
        end
    end

    slopeRMS_norm = NaN(nT, 1);
    cm_drift_abs_norm = NaN(nT, 1);
    sw_drift_abs_norm = NaN(nT, 1);

    medS = median(slopeRMS(valid_slopeRMS), 'omitnan');
    medC = median(cm_drift_abs(valid_cm_drift_abs), 'omitnan');
    medW = median(sw_drift_abs(valid_sw_drift_abs), 'omitnan');
    if isfinite(medS) && medS > 0
        slopeRMS_norm = slopeRMS / medS;
    end
    if isfinite(medC) && medC > 0
        cm_drift_abs_norm = cm_drift_abs / medC;
    end
    if isfinite(medW) && medW > 0
        sw_drift_abs_norm = sw_drift_abs / medW;
    end

    alignTbl = table(I_mA, T_K, slopeRMS, cm_drift_abs, sw_drift_abs, ...
        valid_slopeRMS, valid_cm_drift_abs, valid_sw_drift_abs, ...
        slopeRMS_norm, cm_drift_abs_norm, sw_drift_abs_norm);
    alignTbl = sortrows(alignTbl, {'I_mA', 'T_K'});
    writetable(alignTbl, alignmentPath);

    observables = {'slopeRMS'; 'cm_drift_abs'; 'sw_drift_abs'};
    nObs = numel(observables);

    n_valid = zeros(nObs, 1);
    frac_valid = zeros(nObs, 1);
    nn_consistency_T = NaN(nObs, 1);
    nn_consistency_I = NaN(nObs, 1);
    roughness_tv_norm = NaN(nObs, 1);
    dynamic_range = NaN(nObs, 1);
    robust_std_mad = NaN(nObs, 1);
    snr_like = NaN(nObs, 1);
    hotspot_ratio = NaN(nObs, 1);
    connected_fraction = NaN(nObs, 1);

    valuesCell = {alignTbl.slopeRMS, alignTbl.cm_drift_abs, alignTbl.sw_drift_abs};
    validCell = {alignTbl.valid_slopeRMS, alignTbl.valid_cm_drift_abs, alignTbl.valid_sw_drift_abs};

    for i = 1:nObs
        v = valuesCell{i};
        m = validCell{i} & isfinite(v);
        n_valid(i) = sum(m);
        frac_valid(i) = sum(m) / max(height(alignTbl), 1);

        idx = find(m);
        if numel(idx) >= 2
            d = abs(diff(v(idx)));
            denom = mad(v(idx), 1) * 1.4826;
            if ~(isfinite(denom) && denom > 0)
                denom = max(std(v(idx), 'omitnan'), eps);
            end
            nn_consistency_T(i) = 1 / (1 + median(d, 'omitnan') / max(denom, eps));
            roughness_tv_norm(i) = sum(d, 'omitnan') / max(sum(abs(v(idx)), 'omitnan'), eps);
        else
            nn_consistency_T(i) = NaN;
            roughness_tv_norm(i) = NaN;
        end
        nn_consistency_I(i) = NaN;

        if any(m)
            vals = v(m);
            dynamic_range(i) = max(vals) - min(vals);
            robust_std_mad(i) = 1.4826 * mad(vals, 1);
            if isfinite(roughness_tv_norm(i)) && roughness_tv_norm(i) > 0
                snr_like(i) = robust_std_mad(i) / roughness_tv_norm(i);
            end

            medv = median(vals, 'omitnan');
            madv = mad(vals, 1);
            if ~(isfinite(madv) && madv > 0)
                madv = max(std(vals, 'omitnan'), eps);
            end
            z = abs(vals - medv) / max(madv, eps);
            hotspot = z > 3;
            hotspot_ratio(i) = mean(double(hotspot), 'omitnan');

            coherent = false(size(vals));
            if numel(vals) >= 3
                for j = 2:(numel(vals)-1)
                    if abs(vals(j) - vals(j-1)) <= madv && abs(vals(j+1) - vals(j)) <= madv
                        coherent(j) = true;
                    end
                end
            end
            connected_fraction(i) = mean(double(coherent), 'omitnan');
        end
    end

    idxSC = alignTbl.valid_slopeRMS & alignTbl.valid_cm_drift_abs & isfinite(alignTbl.slopeRMS) & isfinite(alignTbl.cm_drift_abs);
    idxCW = alignTbl.valid_cm_drift_abs & alignTbl.valid_sw_drift_abs & isfinite(alignTbl.cm_drift_abs) & isfinite(alignTbl.sw_drift_abs);
    idxSW = alignTbl.valid_slopeRMS & alignTbl.valid_sw_drift_abs & isfinite(alignTbl.slopeRMS) & isfinite(alignTbl.sw_drift_abs);

    pearson_SC = NaN; spearman_SC = NaN;
    pearson_CW = NaN; spearman_CW = NaN;
    pearson_SW = NaN; spearman_SW = NaN;
    nrmse_cm_vs_sw = NaN;
    nrmse_cm_vs_slope = NaN;

    if sum(idxSC) >= 3
        pearson_SC = corr(alignTbl.slopeRMS(idxSC), alignTbl.cm_drift_abs(idxSC), 'Type', 'Pearson');
        spearman_SC = corr(alignTbl.slopeRMS(idxSC), alignTbl.cm_drift_abs(idxSC), 'Type', 'Spearman');
        p = polyfit(alignTbl.cm_drift_abs(idxSC), alignTbl.slopeRMS(idxSC), 1);
        pred = polyval(p, alignTbl.cm_drift_abs(idxSC));
        nrmse_cm_vs_slope = sqrt(mean((alignTbl.slopeRMS(idxSC) - pred).^2, 'omitnan')) / max(dynamic_range(1), eps);
    end
    if sum(idxCW) >= 3
        pearson_CW = corr(alignTbl.cm_drift_abs(idxCW), alignTbl.sw_drift_abs(idxCW), 'Type', 'Pearson');
        spearman_CW = corr(alignTbl.cm_drift_abs(idxCW), alignTbl.sw_drift_abs(idxCW), 'Type', 'Spearman');
        p = polyfit(alignTbl.sw_drift_abs(idxCW), alignTbl.cm_drift_abs(idxCW), 1);
        pred = polyval(p, alignTbl.sw_drift_abs(idxCW));
        nrmse_cm_vs_sw = sqrt(mean((alignTbl.cm_drift_abs(idxCW) - pred).^2, 'omitnan')) / max(dynamic_range(2), eps);
    end
    if sum(idxSW) >= 3
        pearson_SW = corr(alignTbl.slopeRMS(idxSW), alignTbl.sw_drift_abs(idxSW), 'Type', 'Pearson');
        spearman_SW = corr(alignTbl.slopeRMS(idxSW), alignTbl.sw_drift_abs(idxSW), 'Type', 'Spearman');
    end

    metricsTbl = table(observables, n_valid, frac_valid, nn_consistency_T, nn_consistency_I, ...
        roughness_tv_norm, dynamic_range, robust_std_mad, snr_like, hotspot_ratio, connected_fraction, ...
        'VariableNames', {'observable', 'n_valid', 'frac_valid', 'nn_consistency_T', 'nn_consistency_I', ...
        'roughness_tv_norm', 'dynamic_range', 'robust_std_mad', 'snr_like', 'hotspot_ratio', 'connected_fraction'});

    metricsTbl.pearson_slope_vs_cm = repmat(pearson_SC, nObs, 1);
    metricsTbl.spearman_slope_vs_cm = repmat(spearman_SC, nObs, 1);
    metricsTbl.pearson_cm_vs_sw = repmat(pearson_CW, nObs, 1);
    metricsTbl.spearman_cm_vs_sw = repmat(spearman_CW, nObs, 1);
    metricsTbl.pearson_slope_vs_sw = repmat(pearson_SW, nObs, 1);
    metricsTbl.spearman_slope_vs_sw = repmat(spearman_SW, nObs, 1);
    metricsTbl.nrmse_cm_vs_sw_linear = repmat(nrmse_cm_vs_sw, nObs, 1);
    metricsTbl.nrmse_cm_vs_slope_linear = repmat(nrmse_cm_vs_slope, nObs, 1);
    writetable(metricsTbl, metricsPath);

    fig1 = figure('Visible', 'off', 'Color', [1 1 1]);
    scatter(alignTbl.T_K, alignTbl.I_mA, 140, alignTbl.slopeRMS, 'filled');
    xlabel('T (K)'); ylabel('I (mA)'); title('XX slopeRMS map (aligned support)');
    cb = colorbar; cb.Label.String = 'slopeRMS';
    grid on;
    savefig(fig1, fullfile(figDir, 'xx_decisive_map_slopeRMS.fig'));
    saveas(fig1, fullfile(figDir, 'xx_decisive_map_slopeRMS.png'));
    close(fig1);

    fig2 = figure('Visible', 'off', 'Color', [1 1 1]);
    scatter(alignTbl.T_K, alignTbl.I_mA, 140, alignTbl.cm_drift_abs, 'filled');
    xlabel('T (K)'); ylabel('I (mA)'); title('XX cm\_drift\_abs map (aligned support)');
    cb = colorbar; cb.Label.String = 'cm_drift_abs';
    grid on;
    savefig(fig2, fullfile(figDir, 'xx_decisive_map_cm_drift_abs.fig'));
    saveas(fig2, fullfile(figDir, 'xx_decisive_map_cm_drift_abs.png'));
    close(fig2);

    fig3 = figure('Visible', 'off', 'Color', [1 1 1]);
    scatter(alignTbl.T_K, alignTbl.I_mA, 140, alignTbl.sw_drift_abs, 'filled');
    xlabel('T (K)'); ylabel('I (mA)'); title('XX sw\_drift\_abs map (aligned support)');
    cb = colorbar; cb.Label.String = 'sw_drift_abs';
    grid on;
    savefig(fig3, fullfile(figDir, 'xx_decisive_map_sw_drift_abs.fig'));
    saveas(fig3, fullfile(figDir, 'xx_decisive_map_sw_drift_abs.png'));
    close(fig3);

    fig4 = figure('Visible', 'off', 'Color', [1 1 1]);
    if any(idxSC)
        scatter(alignTbl.slopeRMS(idxSC), alignTbl.cm_drift_abs(idxSC), 70, alignTbl.T_K(idxSC), 'filled');
        cb = colorbar; cb.Label.String = 'T (K)';
        xlabel('slopeRMS'); ylabel('cm_drift_abs');
        title('slopeRMS vs cm_drift_abs');
        grid on;
    else
        text(0.1, 0.5, 'No aligned finite points', 'FontSize', 12);
        axis off;
    end
    savefig(fig4, fullfile(figDir, 'xx_decisive_scatter_slope_vs_cm.fig'));
    saveas(fig4, fullfile(figDir, 'xx_decisive_scatter_slope_vs_cm.png'));
    close(fig4);

    fig5 = figure('Visible', 'off', 'Color', [1 1 1]);
    if any(idxCW)
        scatter(alignTbl.cm_drift_abs(idxCW), alignTbl.sw_drift_abs(idxCW), 70, alignTbl.T_K(idxCW), 'filled');
        cb = colorbar; cb.Label.String = 'T (K)';
        xlabel('cm_drift_abs'); ylabel('sw_drift_abs');
        title('cm_drift_abs vs sw_drift_abs');
        grid on;
    else
        text(0.1, 0.5, 'No aligned finite points', 'FontSize', 12);
        axis off;
    end
    savefig(fig5, fullfile(figDir, 'xx_decisive_scatter_cm_vs_sw.fig'));
    saveas(fig5, fullfile(figDir, 'xx_decisive_scatter_cm_vs_sw.png'));
    close(fig5);

    fig6 = figure('Visible', 'off', 'Color', [1 1 1]);
    if sum(idxSC) >= 3
        p = polyfit(alignTbl.cm_drift_abs(idxSC), alignTbl.slopeRMS(idxSC), 1);
        pred = polyval(p, alignTbl.cm_drift_abs(idxSC));
        residual = alignTbl.slopeRMS(idxSC) - pred;
        scatter(alignTbl.T_K(idxSC), alignTbl.I_mA(idxSC), 150, residual, 'filled');
        cb = colorbar; cb.Label.String = 'Residual (slopeRMS - linear(cm))';
        xlabel('T (K)'); ylabel('I (mA)');
        title('Residual map after best linear rescaling');
        grid on;
    else
        text(0.1, 0.5, 'Insufficient points for residual map', 'FontSize', 12);
        axis off;
    end
    savefig(fig6, fullfile(figDir, 'xx_decisive_residual_slope_minus_cm_linear.fig'));
    saveas(fig6, fullfile(figDir, 'xx_decisive_residual_slope_minus_cm_linear.png'));
    close(fig6);

    cmBetterCoherence = (nn_consistency_T(2) > nn_consistency_T(1)) && (snr_like(2) >= snr_like(1)) && (hotspot_ratio(2) <= hotspot_ratio(1));
    slopeBetterCoherence = (nn_consistency_T(1) >= nn_consistency_T(2)) && (snr_like(1) > snr_like(2));
    cmDiffRedundant = (isfinite(spearman_CW) && abs(spearman_CW) >= 0.90) && (isfinite(nrmse_cm_vs_sw) && nrmse_cm_vs_sw <= 0.20);
    cmDistinct = (isfinite(spearman_CW) && abs(spearman_CW) <= 0.80) || (isfinite(nrmse_cm_vs_sw) && nrmse_cm_vs_sw > 0.35);

    if cmBetterCoherence
        v1 = "YES";
    elseif slopeBetterCoherence
        v1 = "NO";
    else
        v1 = "PARTIAL";
    end
    if slopeBetterCoherence
        v2 = "YES";
    elseif cmBetterCoherence
        v2 = "NO";
    else
        v2 = "PARTIAL";
    end
    if cmDiffRedundant
        v3 = "YES";
    elseif cmDistinct
        v3 = "NO";
    else
        v3 = "PARTIAL";
    end
    if cmDistinct
        v4 = "YES";
    elseif cmDiffRedundant
        v4 = "NO";
    else
        v4 = "PARTIAL";
    end

    outputPromotable = cmBetterCoherence && ~cmDiffRedundant && sum(idxSC) >= 6;
    if outputPromotable
        v5 = "YES";
    elseif sum(idxSC) >= 6
        v5 = "PARTIAL";
    else
        v5 = "NO";
    end

    inconclusive = ~(cmBetterCoherence || slopeBetterCoherence);
    if inconclusive
        v6 = "YES";
    elseif outputPromotable
        v6 = "NO";
    else
        v6 = "PARTIAL";
    end

    verdict_name = ["XX_CM_OUTPERFORMS_SLOPERMS"; ...
                    "XX_SLOPERMS_REMAINS_BEST_CURRENT_PROXY"; ...
                    "XX_CM_AND_DIFF_ARE_EFFECTIVELY_REDUNDANT"; ...
                    "XX_CM_HAS_DISTINCT_STRUCTURE"; ...
                    "XX_DYNAMICS_OUTPUT_CAN_BE_PROMOTED"; ...
                    "XX_DYNAMICS_STILL_INCONCLUSIVE"];
    verdict_value = [v1; v2; v3; v4; v5; v6];
    evidence = [ ...
        "Based on coherence+SNR+hotspot metrics on aligned 35mA support"; ...
        "Based on coherence+SNR comparison against common-mode"; ...
        "Based on cm-vs-sw correlation and linear-rescale NRMSE"; ...
        "Based on cm-vs-sw low redundancy score"; ...
        "Requires clear win, non-redundancy, and enough aligned points"; ...
        "Raised when neither observable class shows decisive metric advantage" ...
        ];
    reason = [ ...
        "cmBetterCoherence=" + string(cmBetterCoherence) + ", snr(cm)=" + string(snr_like(2)) + ", snr(slope)=" + string(snr_like(1)); ...
        "slopeBetterCoherence=" + string(slopeBetterCoherence) + ", nnT(slope)=" + string(nn_consistency_T(1)) + ", nnT(cm)=" + string(nn_consistency_T(2)); ...
        "spearman_cm_sw=" + string(spearman_CW) + ", nrmse_cm_sw=" + string(nrmse_cm_vs_sw); ...
        "spearman_cm_sw=" + string(spearman_CW) + ", nrmse_cm_sw=" + string(nrmse_cm_vs_sw); ...
        "aligned_points=" + string(sum(idxSC)) + ", cmDistinct=" + string(cmDistinct); ...
        "cmBetter=" + string(cmBetterCoherence) + ", slopeBetter=" + string(slopeBetterCoherence) ...
        ];
    verdictTbl = table(verdict_name, verdict_value, evidence, reason);
    writetable(verdictTbl, verdictsPath);

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('XXDecisive:ReportOpenFailed', 'Unable to write report: %s', reportPath);
    end
    fprintf(fid, '# XX dynamics decisive test - slopeRMS vs common-mode\n\n');
    fprintf(fid, '## 1. Goal\n');
    fprintf(fid, 'Determine whether XX dynamics is better represented by slopeRMS or cm_drift_abs using one narrow aligned comparison test.\n\n');
    fprintf(fid, '## 2. Inputs used\n');
    fprintf(fid, '- tables/xx_drift_map.csv (slopeRMS map source)\n');
    fprintf(fid, '- tables/xx_decomposition_vs_temperature_35mA_drift.csv (cm/sw decomposition source)\n\n');
    fprintf(fid, '## 3. Reuse vs rerun\n');
    fprintf(fid, 'Reuse-only was sufficient. No new raw-data processing pipeline rerun was required.\n\n');
    fprintf(fid, '## 4. Alignment method\n');
    fprintf(fid, '- Overlap constrained by shared temperatures between slopeRMS and decomposition tables.\n');
    fprintf(fid, '- Because decomposition source is 35mA-only, decisive comparison is localized to I=35 mA.\n');
    fprintf(fid, '- Final aligned support points: %d\n\n', height(alignTbl));
    fprintf(fid, '## 5. Metric definitions\n');
    fprintf(fid, '- Coverage: n_valid and frac_valid.\n');
    fprintf(fid, '- Spatial coherence: nearest-neighbor consistency in T as 1/(1+median(|delta|)/robust_scale).\n');
    fprintf(fid, '- Roughness: total variation normalized by total magnitude.\n');
    fprintf(fid, '- Signal strength: dynamic range and robust std via MAD.\n');
    fprintf(fid, '- SNR-like: robust_std_mad / roughness_tv_norm.\n');
    fprintf(fid, '- Agreement/redundancy: Pearson/Spearman and linear-rescale NRMSE.\n');
    fprintf(fid, '- Readability proxy: hotspot ratio (z>3 by MAD scale) and connected_fraction.\n\n');
    fprintf(fid, '## 6. Figure list\n');
    fprintf(fid, '- figures/xx_decisive_map_slopeRMS.(fig,png)\n');
    fprintf(fid, '- figures/xx_decisive_map_cm_drift_abs.(fig,png)\n');
    fprintf(fid, '- figures/xx_decisive_map_sw_drift_abs.(fig,png)\n');
    fprintf(fid, '- figures/xx_decisive_scatter_slope_vs_cm.(fig,png)\n');
    fprintf(fid, '- figures/xx_decisive_scatter_cm_vs_sw.(fig,png)\n');
    fprintf(fid, '- figures/xx_decisive_residual_slope_minus_cm_linear.(fig,png)\n\n');
    fprintf(fid, '## 7. Main quantitative results\n');
    fprintf(fid, '- Pearson(slope,cm)=%.4f, Spearman(slope,cm)=%.4f\n', pearson_SC, spearman_SC);
    fprintf(fid, '- Pearson(cm,sw)=%.4f, Spearman(cm,sw)=%.4f\n', pearson_CW, spearman_CW);
    fprintf(fid, '- NRMSE(cm~sw linear)=%.4f, NRMSE(slope~cm linear)=%.4f\n', nrmse_cm_vs_sw, nrmse_cm_vs_slope);
    fprintf(fid, '- nn_consistency_T: slope=%.4f, cm=%.4f, sw=%.4f\n', nn_consistency_T(1), nn_consistency_T(2), nn_consistency_T(3));
    fprintf(fid, '- snr_like: slope=%.4f, cm=%.4f, sw=%.4f\n\n', snr_like(1), snr_like(2), snr_like(3));
    fprintf(fid, '## 8. Final verdicts\n');
    for i = 1:height(verdictTbl)
        fprintf(fid, '- %s = %s (%s)\n', verdictTbl.verdict_name(i), verdictTbl.verdict_value(i), verdictTbl.reason(i));
    end
    fprintf(fid, '\n## 9. Recommendation\n');
    if v1 == "YES" && v3 ~= "YES"
        fprintf(fid, 'Prefer cm_drift_abs as the current XX dynamics proxy (35mA-local), keep slopeRMS as secondary cross-check.\n');
    elseif v2 == "YES"
        fprintf(fid, 'Keep slopeRMS as current best XX dynamics proxy; common-mode does not provide decisive improvement.\n');
    elseif v6 == "YES"
        fprintf(fid, 'Inconclusive: keep both as non-canonical candidates and move to state-resolved next step.\n');
    else
        fprintf(fid, 'Keep both as non-canonical candidates; evidence is mixed.\n');
    end
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(alignTbl), {'XX decisive observable comparison completed on aligned support'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'XX decisive observable comparison failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, statusPath);
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
    end
    if exist(reportPath, 'file') ~= 2
        fid = fopen(reportPath, 'w');
        if fid >= 0
            fprintf(fid, '# XX dynamics decisive test - FAILED\n\n');
            fprintf(fid, '- ERROR: %s\n', ME.message);
            fclose(fid);
        end
    end
    rethrow(ME);
end

writetable(executionStatus, statusPath);
writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
