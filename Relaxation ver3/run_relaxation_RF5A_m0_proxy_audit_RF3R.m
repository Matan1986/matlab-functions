fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;
rng(42, 'twister');

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('STOP: repo root not found.');
end
addpath(fullfile(repoRoot, 'tools', 'figures'));

run_id = "run_2026_04_26_234453";
rfRunDir = fullfile(repoRoot, 'results', 'relaxation_post_field_off_RF3R_canonical', 'runs', run_id);
rfTablesDir = fullfile(rfRunDir, 'tables');

outTablesDir = fullfile(repoRoot, 'tables');
outReportsDir = fullfile(repoRoot, 'reports');
figDir = fullfile(repoRoot, 'figures', 'relaxation', 'RF5A_m0_proxy_audit_RF3R', run_id);
if exist(outTablesDir, 'dir') ~= 7, mkdir(outTablesDir); end
if exist(outReportsDir, 'dir') ~= 7, mkdir(outReportsDir); end
if exist(figDir, 'dir') ~= 7, mkdir(figDir); end

scoresPath = fullfile(outTablesDir, 'relaxation_RF5A_m0_svd_scores_RF3R.csv');
cmpPath = fullfile(outTablesDir, 'relaxation_RF5A_m0_proxy_comparison_RF3R.csv');
recPath = fullfile(outTablesDir, 'relaxation_RF5A_m0_proxy_reconstruction_RF3R.csv');
diagPath = fullfile(outTablesDir, 'relaxation_RF5A_m0_proxy_failure_diagnostics_RF3R.csv');
verdictPath = fullfile(outTablesDir, 'relaxation_RF5A_m0_proxy_verdict_RF3R.csv');
reportPath = fullfile(outReportsDir, 'relaxation_RF5A_m0_proxy_audit_RF3R.md');
execStatusPath = fullfile(rfRunDir, 'execution_status.csv');

inputFound = "NO";
nT = 0;

try
    if exist(rfRunDir, 'dir') ~= 7
        error('STOP: RF3R run outputs missing.');
    end

    manifest = readtable(fullfile(rfTablesDir, 'relaxation_event_origin_manifest.csv'), ...
        'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    curveIndex = readtable(fullfile(rfTablesDir, 'relaxation_post_field_off_curve_index.csv'), ...
        'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    curveQuality = readtable(fullfile(rfTablesDir, 'relaxation_post_field_off_curve_quality.csv'), ...
        'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    curveSamples = readtable(fullfile(rfTablesDir, 'relaxation_post_field_off_curve_samples.csv'), ...
        'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');

    mNames = string(manifest.Properties.VariableNames);
    iNames = string(curveIndex.Properties.VariableNames);
    qNames = string(curveQuality.Properties.VariableNames);
    sNames = string(curveSamples.Properties.VariableNames);

    imTraceValid = find(contains(mNames, "trace_valid_for_relaxation", 'IgnoreCase', true), 1);
    imTraceId = find(contains(mNames, "trace_id", 'IgnoreCase', true), 1);
    imTemp = find(contains(mNames, "temperature", 'IgnoreCase', true), 1);
    iiTraceId = find(contains(iNames, "trace_id", 'IgnoreCase', true), 1);
    iiDefault = find(contains(iNames, "valid_for_default_replay", 'IgnoreCase', true), 1);
    iqTraceId = find(contains(qNames, "trace_id", 'IgnoreCase', true), 1);
    iqFlag = find(contains(qNames, "quality_flag", 'IgnoreCase', true), 1);
    iqReason = find(contains(qNames, "quality_flag_reason", 'IgnoreCase', true), 1);
    isTraceId = find(contains(sNames, "trace_id", 'IgnoreCase', true), 1);
    isTime = find(contains(sNames, "time_since_field_off", 'IgnoreCase', true), 1);
    isDelta = find(contains(sNames, "delta_m", 'IgnoreCase', true), 1);

    if isempty(imTraceValid) || isempty(imTraceId) || isempty(imTemp) || isempty(iiTraceId) || isempty(iiDefault) || ...
            isempty(iqTraceId) || isempty(iqFlag) || isempty(isTraceId) || isempty(isTime) || isempty(isDelta)
        error('STOP: required RF3R canonical columns missing.');
    end

    validMask = strcmpi(strtrim(string(manifest{:, imTraceValid})), "YES");
    validManifest = manifest(validMask, :);
    includeMask = false(height(validManifest), 1);
    for i = 1:height(validManifest)
        tid = string(validManifest{i, imTraceId});
        ix = find(strcmp(string(curveIndex{:, iiTraceId}), tid), 1);
        qx = find(strcmp(string(curveQuality{:, iqTraceId}), tid), 1);
        if isempty(ix) || isempty(qx)
            continue;
        end
        isDefault = strcmpi(strtrim(string(curveIndex{ix, iiDefault})), "YES");
        isFlagged = strcmpi(strtrim(string(curveQuality{qx, iqFlag})), "YES");
        if isDefault && ~isFlagged
            includeMask(i) = true;
        end
    end
    validManifest = validManifest(includeMask, :);
    if isempty(validManifest)
        error('STOP: default replay set cannot be resolved.');
    end

    traceIds = string(validManifest{:, imTraceId});
    temps = str2double(string(validManifest{:, imTemp}));
    [temps, ord] = sort(temps, 'ascend');
    traceIds = traceIds(ord);
    nT = numel(traceIds);
    inputFound = "YES";
    if nT < 2
        error('STOP: default replay set too small.');
    end

    for i = 1:nT
        qx = find(strcmp(string(curveQuality{:, iqTraceId}), traceIds(i)), 1);
        if isempty(qx) || strcmpi(strtrim(string(curveQuality{qx, iqFlag})), "YES")
            error('STOP: quality_flag == YES trace entered analysis.');
        end
    end

    curveSamples.time_s = str2double(string(curveSamples{:, isTime}));
    curveSamples.delta_m_num = str2double(string(curveSamples{:, isDelta}));

    tMinEach = nan(nT,1);
    tMaxEach = nan(nT,1);
    for i = 1:nT
        s = curveSamples(strcmp(string(curveSamples{:, isTraceId}), traceIds(i)), :);
        t = s.time_s;
        t = t(isfinite(t) & t > 0);
        tMinEach(i) = min(t);
        tMaxEach(i) = max(t);
    end
    tMinCommon = max(tMinEach);
    tMaxCommon = min(tMaxEach);
    if ~isfinite(tMinCommon) || ~isfinite(tMaxCommon) || tMinCommon <= 0 || tMaxCommon <= tMinCommon
        error('STOP: invalid common post-field-off time grid.');
    end

    nGrid = 320;
    tGrid = linspace(tMinCommon, tMaxCommon, nGrid);
    XtempTime = nan(nT, nGrid);
    for i = 1:nT
        s = curveSamples(strcmp(string(curveSamples{:, isTraceId}), traceIds(i)), :);
        t = s.time_s;
        x = s.delta_m_num;
        m = isfinite(t) & isfinite(x) & t > 0;
        [tU, ia] = unique(t(m), 'stable');
        xU = x(m);
        xU = xU(ia);
        XtempTime(i, :) = interp1(tU, xU, tGrid, 'linear', 'extrap');
    end
    X = XtempTime.'; % rows=time, cols=temperature

    [U, S, V] = svd(X, 'econ');
    psi0 = U(:,1);
    m0_svd = S(1,1) * V(:,1);
    if sum(psi0, 'omitnan') < 0
        psi0 = -psi0;
        m0_svd = -m0_svd;
    end
    Xhat_svd = psi0 * m0_svd.';
    err_svd = norm(X - Xhat_svd, 'fro') / max(norm(X, 'fro'), eps);

    m0Tbl = table(repmat(string(run_id), nT, 1), temps, m0_svd, ...
        'VariableNames', {'run_id','temperature','m0_svd_score'});
    writetable(m0Tbl, scoresPath);

    proxyNames = ["peak_to_peak","l2_norm","mad_scale","endpoint_difference","projection_onto_corrected_mean_curve"];
    nProxy = numel(proxyNames);
    signFlip = strings(nProxy,1);
    cScale = nan(nProxy,1);
    pearsonR = nan(nProxy,1);
    spearmanR = nan(nProxy,1);
    nrmse = nan(nProxy,1);
    errRec = nan(nProxy,1);
    preserveOrder = strings(nProxy,1);
    needsOffset = strings(nProxy,1);
    nonlinearMono = strings(nProxy,1);
    endpointSensitive = strings(nProxy,1);
    signMismatch = strings(nProxy,1);

    for p = 1:nProxy
        name = proxyNames(p);
        proxy = nan(nT,1);
        if name == "peak_to_peak"
            for i = 1:nT
                xi = XtempTime(i,:);
                proxy(i) = max(xi) - min(xi);
            end
        elseif name == "l2_norm"
            proxy = sqrt(mean(XtempTime.^2, 2, 'omitnan'));
        elseif name == "mad_scale"
            for i = 1:nT
                xi = XtempTime(i,:);
                proxy(i) = median(abs(xi - median(xi, 'omitnan')), 'omitnan');
            end
        elseif name == "endpoint_difference"
            proxy = XtempTime(:,end) - XtempTime(:,1);
        elseif name == "projection_onto_corrected_mean_curve"
            f0 = mean(XtempTime, 1, 'omitnan');
            den = sum(f0.^2, 'omitnan');
            if den <= eps, den = eps; end
            for i = 1:nT
                proxy(i) = sum(XtempTime(i,:) .* f0, 2, 'omitnan') / den;
            end
        else
            error('Unknown proxy.');
        end

        proxy(~isfinite(proxy)) = 0;
        if sum((proxy - mean(proxy)).*(m0_svd - mean(m0_svd)), 'omitnan') < 0
            proxy = -proxy;
            signFlip(p) = "YES";
            signMismatch(p) = "YES";
        else
            signFlip(p) = "NO";
            signMismatch(p) = "NO";
        end

        c = (proxy.' * m0_svd) / max(proxy.' * proxy, eps);
        cScale(p) = c;
        m_fit = c * proxy;

        pearsonR(p) = corr(m_fit, m0_svd, 'Type', 'Pearson', 'Rows', 'complete');
        spearmanR(p) = corr(m_fit, m0_svd, 'Type', 'Spearman', 'Rows', 'complete');
        nrmse(p) = norm(m_fit - m0_svd) / max(norm(m0_svd), eps);

        Xhat_proxy = psi0 * m_fit.';
        errRec(p) = norm(X - Xhat_proxy, 'fro') / max(norm(X, 'fro'), eps);

        rankM0 = tiedrank(m0_svd);
        rankP = tiedrank(m_fit);
        if all(rankM0 == rankP)
            preserveOrder(p) = "YES";
        else
            preserveOrder(p) = "NO";
        end

        beta = [ones(nT,1), proxy] \ m0_svd;
        m_fit_off = beta(1) + beta(2) * proxy;
        nrmseOff = norm(m_fit_off - m0_svd) / max(norm(m0_svd), eps);
        if (nrmse(p) - nrmseOff) >= 0.05
            needsOffset(p) = "YES";
        else
            needsOffset(p) = "NO";
        end

        if abs(spearmanR(p) - pearsonR(p)) > 0.15
            nonlinearMono(p) = "YES";
        else
            nonlinearMono(p) = "NO";
        end

        if name == "endpoint_difference" || name == "peak_to_peak"
            endpointSensitive(p) = "YES";
        else
            endpointSensitive(p) = "NO";
        end
    end

    cmpTbl = table(proxyNames.', signFlip, cScale, pearsonR, spearmanR, nrmse, preserveOrder, ...
        'VariableNames', {'proxy_name','sign_flipped','calibration_scale_c', ...
        'pearson_r_with_m0_svd','spearman_r_with_m0_svd','normalized_rmse_vs_m0_svd', ...
        'preserves_temperature_ordering'});
    writetable(cmpTbl, cmpPath);

    recTbl = table(proxyNames.', errRec, repmat(err_svd, nProxy, 1), ...
        errRec - repmat(err_svd, nProxy, 1), ...
        'VariableNames', {'proxy_name','proxy_rank1_reconstruction_error', ...
        'svd_rank1_reconstruction_error','error_gap_vs_svd'});
    writetable(recTbl, recPath);

    diagTbl = table(proxyNames.', signMismatch, repmat("YES",nProxy,1), needsOffset, nonlinearMono, endpointSensitive, ...
        'VariableNames', {'proxy_name','sign_mismatch_detected','global_scale_fitted', ...
        'offset_intercept_needed','nonlinear_monotonic_relation_indicated','endpoint_sensitivity_indicated'});
    writetable(diagTbl, diagPath);

    [~, bestIdx] = min(nrmse);
    bestProxy = proxyNames(bestIdx);
    bestCorr = pearsonR(bestIdx) >= 0.9 && spearmanR(bestIdx) >= 0.9;
    bestReconClose = (errRec(bestIdx) - err_svd) <= 0.03;
    bestCorrTxt = "NO";
    if bestCorr
        bestCorrTxt = "YES";
    end
    bestReconTxt = "NO";
    if bestReconClose
        bestReconTxt = "YES";
    end

    bestScaleExpl = "NO";
    if nrmse(bestIdx) <= 0.20 && needsOffset(bestIdx) == "NO" && nonlinearMono(bestIdx) == "NO"
        bestScaleExpl = "YES";
    end

    verdict = table( ...
        "YES", ... RF5A_M0_PROXY_AUDIT_COMPLETE
        "YES", ... RF3R_RUN_USED
        "YES", ... DEFAULT_REPLAY_SET_ENFORCED
        "YES", ... FLAGGED_TRACES_EXCLUDED
        "YES", ... PRIMARY_MODE_USED_AS_REFERENCE
        "YES", ... M0_SVD_DEFINED
        string(bestProxy), ...
        bestCorrTxt, ...
        bestReconTxt, ...
        bestScaleExpl, ...
        needsOffset(bestIdx), ...
        nonlinearMono(bestIdx), ...
        endpointSensitive(bestIdx), ...
        "YES", ... CANONICAL_RELAXATION_AMPLITUDE_RENAMED_TO_M0
        "YES", ... ACTIVITY_A_NOT_USED_AS_RELAXATION_AMPLITUDE
        "NO", ... READY_FOR_TAU_AUDIT
        "NO", ... READY_FOR_RF5B
        "NO", ... READY_FOR_COLLAPSE
        'VariableNames', { ...
        'RF5A_M0_PROXY_AUDIT_COMPLETE', ...
        'RF3R_RUN_USED', ...
        'DEFAULT_REPLAY_SET_ENFORCED', ...
        'FLAGGED_TRACES_EXCLUDED', ...
        'PRIMARY_MODE_USED_AS_REFERENCE', ...
        'M0_SVD_DEFINED', ...
        'BEST_M0_PROXY', ...
        'BEST_PROXY_CORRELATES_WITH_M0_SVD', ...
        'BEST_PROXY_RECONSTRUCTION_CLOSE_TO_SVD', ...
        'PROXY_FAILURE_EXPLAINED_BY_SCALE', ...
        'PROXY_FAILURE_EXPLAINED_BY_OFFSET', ...
        'PROXY_FAILURE_EXPLAINED_BY_NONLINEARITY', ...
        'PROXY_FAILURE_EXPLAINED_BY_ENDPOINT_SENSITIVITY', ...
        'CANONICAL_RELAXATION_AMPLITUDE_RENAMED_TO_M0', ...
        'ACTIVITY_A_NOT_USED_AS_RELAXATION_AMPLITUDE', ...
        'READY_FOR_TAU_AUDIT', ...
        'READY_FOR_RF5B', ...
        'READY_FOR_COLLAPSE'});
    writetable(verdict, verdictPath);

    fig1 = create_figure('Name', 'rf5a_m0_svd_score_vs_temperature_rf3r', 'NumberTitle', 'off', 'Position', [2 2 17.8 8.8]);
    plot(temps, m0_svd, 'o-', 'LineWidth', 2.2);
    xlabel('Temperature (K)');
    ylabel('m0\_svd(T)');
    title('Primary SVD score m0(T)');
    grid on;
    apply_publication_style(fig1);
    exportgraphics(fig1, fullfile(figDir, 'rf5a_m0_svd_score_vs_temperature_rf3r.png'), 'Resolution', 600);
    savefig(fig1, fullfile(figDir, 'rf5a_m0_svd_score_vs_temperature_rf3r.fig'));
    close(fig1);

    fig2 = create_figure('Name', 'rf5a_m0_proxy_vs_svd_rf3r', 'NumberTitle', 'off', 'Position', [2 2 17.8 10.5]);
    tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
    for p = 1:nProxy
        nexttile;
        name = proxyNames(p);
        proxy = nan(nT,1);
        if name == "peak_to_peak"
            for i = 1:nT
                xi = XtempTime(i,:);
                proxy(i) = max(xi) - min(xi);
            end
        elseif name == "l2_norm"
            proxy = sqrt(mean(XtempTime.^2, 2, 'omitnan'));
        elseif name == "mad_scale"
            for i = 1:nT
                xi = XtempTime(i,:);
                proxy(i) = median(abs(xi - median(xi, 'omitnan')), 'omitnan');
            end
        elseif name == "endpoint_difference"
            proxy = XtempTime(:,end) - XtempTime(:,1);
        else
            f0 = mean(XtempTime, 1, 'omitnan');
            den = sum(f0.^2, 'omitnan');
            if den <= eps, den = eps; end
            for i = 1:nT
                proxy(i) = sum(XtempTime(i,:) .* f0, 2, 'omitnan') / den;
            end
        end
        if signFlip(p) == "YES"
            proxy = -proxy;
        end
        proxyFit = cScale(p) * proxy;
        scatter(m0_svd, proxyFit, 45, temps, 'filled');
        xlabel('m0\_svd');
        ylabel('c * proxy');
        title(strrep(name, '_', '\_'));
        grid on;
    end
    colormap(parula);
    apply_publication_style(fig2);
    exportgraphics(fig2, fullfile(figDir, 'rf5a_m0_proxy_vs_svd_rf3r.png'), 'Resolution', 600);
    savefig(fig2, fullfile(figDir, 'rf5a_m0_proxy_vs_svd_rf3r.fig'));
    close(fig2);

    fig3 = create_figure('Name', 'rf5a_m0_proxy_reconstruction_error_rf3r', 'NumberTitle', 'off', 'Position', [2 2 17.8 8.8]);
    b = bar(categorical(proxyNames), errRec);
    b.FaceColor = [0.2 0.4 0.7];
    hold on;
    yline(err_svd, 'r-', 'LineWidth', 2.0);
    ylabel('Rank-1 reconstruction error');
    title('Proxy-calibrated reconstruction vs SVD rank-1');
    grid on;
    apply_publication_style(fig3);
    exportgraphics(fig3, fullfile(figDir, 'rf5a_m0_proxy_reconstruction_error_rf3r.png'), 'Resolution', 600);
    savefig(fig3, fullfile(figDir, 'rf5a_m0_proxy_reconstruction_error_rf3r.fig'));
    close(fig3);

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('STOP: cannot write report.');
    end
    fprintf(fid, '# RF5A m0 Proxy Audit on RF3R\n\n');
    fprintf(fid, '- Run used: `%s`\n', rfRunDir);
    fprintf(fid, '- Default replay traces used: %d\n', nT);
    fprintf(fid, '- Primary model: `DeltaM(t,T) ~= m0(T) * Psi0(t)`\n');
    fprintf(fid, '- `m0_svd(T)` is defined from direct primary SVD score (`s1 * V(:,1)`) with fixed sign convention.\n');
    fprintf(fid, '- Best proxy: `%s`\n', bestProxy);
    fprintf(fid, '- SVD rank-1 reconstruction error: %.6f\n', err_svd);
    fprintf(fid, '\n## Proxy summary\n');
    for p = 1:nProxy
        fprintf(fid, '- %s: pearson=%.6f, spearman=%.6f, nRMSE=%.6f, recon_err=%.6f\n', ...
            proxyNames(p), pearsonR(p), spearmanR(p), nrmse(p), errRec(p));
    end
    fprintf(fid, '\n## Required verdict fields\n');
    fprintf(fid, '- RF5A_M0_PROXY_AUDIT_COMPLETE: `YES`\n');
    fprintf(fid, '- RF3R_RUN_USED: `YES`\n');
    fprintf(fid, '- DEFAULT_REPLAY_SET_ENFORCED: `YES`\n');
    fprintf(fid, '- FLAGGED_TRACES_EXCLUDED: `YES`\n');
    fprintf(fid, '- PRIMARY_MODE_USED_AS_REFERENCE: `YES`\n');
    fprintf(fid, '- M0_SVD_DEFINED: `YES`\n');
    fprintf(fid, '- BEST_M0_PROXY: `%s`\n', bestProxy);
    fprintf(fid, '- BEST_PROXY_CORRELATES_WITH_M0_SVD: `%s`\n', bestCorrTxt);
    fprintf(fid, '- BEST_PROXY_RECONSTRUCTION_CLOSE_TO_SVD: `%s`\n', bestReconTxt);
    fprintf(fid, '- PROXY_FAILURE_EXPLAINED_BY_SCALE: `%s`\n', bestScaleExpl);
    fprintf(fid, '- PROXY_FAILURE_EXPLAINED_BY_OFFSET: `%s`\n', needsOffset(bestIdx));
    fprintf(fid, '- PROXY_FAILURE_EXPLAINED_BY_NONLINEARITY: `%s`\n', nonlinearMono(bestIdx));
    fprintf(fid, '- PROXY_FAILURE_EXPLAINED_BY_ENDPOINT_SENSITIVITY: `%s`\n', endpointSensitive(bestIdx));
    fprintf(fid, '- CANONICAL_RELAXATION_AMPLITUDE_RENAMED_TO_M0: `YES`\n');
    fprintf(fid, '- ACTIVITY_A_NOT_USED_AS_RELAXATION_AMPLITUDE: `YES`\n');
    fprintf(fid, '- READY_FOR_TAU_AUDIT: `NO`\n');
    fprintf(fid, '- READY_FOR_RF5B: `NO`\n');
    fprintf(fid, '- READY_FOR_COLLAPSE: `NO`\n');
    fprintf(fid, '\n## Interpretation constraints\n');
    fprintf(fid, '- This report identifies proxy quality relative to `m0_svd(T)` only.\n');
    fprintf(fid, '- No mechanism claims, no tau claim, no KWW fitting, no collapse, and no cross-module interpretation.\n');
    fclose(fid);

    execTbl = table({'SUCCESS'}, {char(inputFound)}, {''}, nT, {'RF5A m0 proxy audit completed'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
    writetable(execTbl, execStatusPath);

catch ME
    emptyScores = table(strings(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'run_id','temperature','m0_svd_score'});
    writetable(emptyScores, scoresPath);
    emptyCmp = table(strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), strings(0,1), ...
        'VariableNames', {'proxy_name','sign_flipped','calibration_scale_c', ...
        'pearson_r_with_m0_svd','spearman_r_with_m0_svd','normalized_rmse_vs_m0_svd', ...
        'preserves_temperature_ordering'});
    writetable(emptyCmp, cmpPath);
    emptyRec = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'proxy_name','proxy_rank1_reconstruction_error', ...
        'svd_rank1_reconstruction_error','error_gap_vs_svd'});
    writetable(emptyRec, recPath);
    emptyDiag = table(strings(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
        'VariableNames', {'proxy_name','sign_mismatch_detected','global_scale_fitted', ...
        'offset_intercept_needed','nonlinear_monotonic_relation_indicated','endpoint_sensitivity_indicated'});
    writetable(emptyDiag, diagPath);
    failVerdict = table("NO","NO","NO","NO","NO","NO","NA","NO","NO","NO","NO","NO","NO","NO","NO","NO","NO","NO", ...
        'VariableNames', { ...
        'RF5A_M0_PROXY_AUDIT_COMPLETE', ...
        'RF3R_RUN_USED', ...
        'DEFAULT_REPLAY_SET_ENFORCED', ...
        'FLAGGED_TRACES_EXCLUDED', ...
        'PRIMARY_MODE_USED_AS_REFERENCE', ...
        'M0_SVD_DEFINED', ...
        'BEST_M0_PROXY', ...
        'BEST_PROXY_CORRELATES_WITH_M0_SVD', ...
        'BEST_PROXY_RECONSTRUCTION_CLOSE_TO_SVD', ...
        'PROXY_FAILURE_EXPLAINED_BY_SCALE', ...
        'PROXY_FAILURE_EXPLAINED_BY_OFFSET', ...
        'PROXY_FAILURE_EXPLAINED_BY_NONLINEARITY', ...
        'PROXY_FAILURE_EXPLAINED_BY_ENDPOINT_SENSITIVITY', ...
        'CANONICAL_RELAXATION_AMPLITUDE_RENAMED_TO_M0', ...
        'ACTIVITY_A_NOT_USED_AS_RELAXATION_AMPLITUDE', ...
        'READY_FOR_TAU_AUDIT', ...
        'READY_FOR_RF5B', ...
        'READY_FOR_COLLAPSE'});
    writetable(failVerdict, verdictPath);

    fid = fopen(reportPath, 'w');
    if fid >= 0
        fprintf(fid, '# RF5A m0 Proxy Audit on RF3R\n\n');
        fprintf(fid, '- STATUS: FAILED\n');
        fprintf(fid, '- ERROR: `%s`\n', ME.message);
        fprintf(fid, '- Run target: `%s`\n', rfRunDir);
        fclose(fid);
    end
    execTbl = table({'FAILED'}, {char(inputFound)}, {ME.message}, nT, {'RF5A m0 proxy audit failed'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
    writetable(execTbl, execStatusPath);
    rethrow(ME);
end

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
