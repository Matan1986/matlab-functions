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
figDir = fullfile(repoRoot, 'figures', 'relaxation', 'RF5A_residual_structure_RF3R', run_id);
if exist(outTablesDir, 'dir') ~= 7, mkdir(outTablesDir); end
if exist(outReportsDir, 'dir') ~= 7, mkdir(outReportsDir); end
if exist(figDir, 'dir') ~= 7, mkdir(figDir); end

spectrumPath = fullfile(outTablesDir, 'relaxation_RF5A_residual_svd_spectrum_RF3R.csv');
stabilityPath = fullfile(outTablesDir, 'relaxation_RF5A_residual_mode_stability_RF3R.csv');
ampInvPath = fullfile(outTablesDir, 'relaxation_RF5A_residual_amplitude_invariance_RF3R.csv');
subsetPath = fullfile(outTablesDir, 'relaxation_RF5A_residual_subset_robustness_RF3R.csv');
negPath = fullfile(outTablesDir, 'relaxation_RF5A_residual_negative_controls_RF3R.csv');
verdictPath = fullfile(outTablesDir, 'relaxation_RF5A_residual_mode_verdict_RF3R.csv');
reportPath = fullfile(outReportsDir, 'relaxation_RF5A_residual_structure_RF3R.md');
execStatusPath = fullfile(rfRunDir, 'execution_status.csv');

runSummary = 'RF5A residual structure not executed';
nT = 0;
inputFound = "NO";

try
    if exist(rfRunDir, 'dir') ~= 7
        error('STOP: RF3R run outputs missing.');
    end

    rf3rGate = readtable(fullfile(outTablesDir, 'relaxation_RF3R_gate_audit_status.csv'), 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    rf4bGate = readtable(fullfile(outTablesDir, 'relaxation_RF4B_visualization_status.csv'), 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    creation = readtable(fullfile(rfTablesDir, 'relaxation_post_field_off_creation_status.csv'), 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    manifest = readtable(fullfile(rfTablesDir, 'relaxation_event_origin_manifest.csv'), 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    curveIndex = readtable(fullfile(rfTablesDir, 'relaxation_post_field_off_curve_index.csv'), 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    curveQuality = readtable(fullfile(rfTablesDir, 'relaxation_post_field_off_curve_quality.csv'), 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    curveSamples = readtable(fullfile(rfTablesDir, 'relaxation_post_field_off_curve_samples.csv'), 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');

    if ~strcmpi(strtrim(rf3rGate.RF3R_RUN_AUDIT_COMPLETE(1)), "YES")
        error('STOP: RF3R audit failed.');
    end
    if ~strcmpi(strtrim(rf4bGate.RF4B_RERUN_COMPLETE(1)), "YES")
        error('STOP: RF4B rerun gate missing or failed.');
    end
    if ~strcmpi(strtrim(rf4bGate.RF3R_RUN_USED(1)), "YES")
        error('STOP: RF3R_RUN_USED gate failed.');
    end
    if ~strcmpi(strtrim(rf4bGate.DEFAULT_REPLAY_SET_ENFORCED(1)), "YES")
        error('STOP: DEFAULT_REPLAY_SET_ENFORCED gate failed.');
    end
    if ~strcmpi(strtrim(rf4bGate.FLAGGED_TRACES_EXCLUDED(1)), "YES")
        error('STOP: FLAGGED_TRACES_EXCLUDED gate failed.');
    end
    creationNames = string(creation.Properties.VariableNames);
    idxRF5B = find(contains(creationNames, "READY_FOR_RF5B_EFFECTIVE_RANK", 'IgnoreCase', true), 1);
    if ~isempty(idxRF5B)
        valRF5B = string(creation{1, idxRF5B});
        if ~strcmpi(strtrim(valRF5B), "NO")
            error('STOP: READY_FOR_RF5B_EFFECTIVE_RANK must remain NO.');
        end
    end
    if ~strcmpi(strtrim(creation.READY_FOR_COLLAPSE_REPLAY(1)), "NO")
        error('STOP: READY_FOR_COLLAPSE_REPLAY must remain NO.');
    end

    manifestNames = string(manifest.Properties.VariableNames);
    idxManifestTraceValid = find(contains(manifestNames, "trace_valid_for_relaxation", 'IgnoreCase', true), 1);
    idxManifestTraceId = find(contains(manifestNames, "trace_id", 'IgnoreCase', true), 1);
    idxManifestTemp = find(contains(manifestNames, "temperature", 'IgnoreCase', true), 1);
    if isempty(idxManifestTraceValid) || isempty(idxManifestTraceId) || isempty(idxManifestTemp)
        error('STOP: required manifest columns missing.');
    end

    curveIndexNames = string(curveIndex.Properties.VariableNames);
    idxCurveIndexTraceId = find(contains(curveIndexNames, "trace_id", 'IgnoreCase', true), 1);
    idxCurveIndexDefault = find(contains(curveIndexNames, "valid_for_default_replay", 'IgnoreCase', true), 1);
    if isempty(idxCurveIndexTraceId) || isempty(idxCurveIndexDefault)
        error('STOP: required curve_index columns missing.');
    end

    curveQualityNames = string(curveQuality.Properties.VariableNames);
    idxCurveQualityTraceId = find(contains(curveQualityNames, "trace_id", 'IgnoreCase', true), 1);
    idxCurveQualityFlag = find(contains(curveQualityNames, "quality_flag", 'IgnoreCase', true), 1);
    if isempty(idxCurveQualityTraceId) || isempty(idxCurveQualityFlag)
        error('STOP: required curve_quality columns missing.');
    end

    curveSampleNames = string(curveSamples.Properties.VariableNames);
    idxCurveSampleTraceId = find(contains(curveSampleNames, "trace_id", 'IgnoreCase', true), 1);
    idxCurveSampleTime = find(contains(curveSampleNames, "time_since_field_off", 'IgnoreCase', true), 1);
    idxCurveSampleDelta = find(contains(curveSampleNames, "delta_m", 'IgnoreCase', true), 1);
    if isempty(idxCurveSampleTraceId) || isempty(idxCurveSampleTime) || isempty(idxCurveSampleDelta)
        error('STOP: required curve_samples columns missing.');
    end

    validMask = strcmpi(strtrim(string(manifest{:, idxManifestTraceValid})), "YES");
    validManifestAll = manifest(validMask, :);
    includeMask = false(height(validManifestAll), 1);
    exclReason = strings(height(validManifestAll), 1);

    for i = 1:height(validManifestAll)
        tid = string(validManifestAll{i, idxManifestTraceId});
        ix = find(strcmp(string(curveIndex{:, idxCurveIndexTraceId}), tid), 1);
        qx = find(strcmp(string(curveQuality{:, idxCurveQualityTraceId}), tid), 1);
        if isempty(ix) || isempty(qx)
            exclReason(i) = "MISSING_INDEX_OR_QUALITY";
            continue;
        end
        isDefault = strcmpi(strtrim(string(curveIndex{ix, idxCurveIndexDefault})), "YES");
        isFlagged = strcmpi(strtrim(string(curveQuality{qx, idxCurveQualityFlag})), "YES");
        if ~isDefault
            exclReason(i) = "NOT_VALID_FOR_DEFAULT_REPLAY";
            continue;
        end
        if isFlagged
            exclReason(i) = "QUALITY_FLAGGED";
            continue;
        end
        includeMask(i) = true;
    end

    validManifest = validManifestAll(includeMask, :);
    if isempty(validManifest)
        error('STOP: default replay set cannot be resolved (empty).');
    end

    traceIds = string(validManifest{:, idxManifestTraceId});
    temps = str2double(string(validManifest{:, idxManifestTemp}));
    [temps, ord] = sort(temps, 'ascend');
    traceIds = traceIds(ord);
    validManifest = validManifest(ord, :);
    nT = numel(traceIds);
    inputFound = "YES";
    if nT < 3
        error('STOP: need at least 3 traces for LOO and subset tests.');
    end

    for i = 1:nT
        qx = find(strcmp(string(curveQuality{:, idxCurveQualityTraceId}), traceIds(i)), 1);
        if isempty(qx) || strcmpi(strtrim(string(curveQuality{qx, idxCurveQualityFlag})), "YES")
            error('STOP: quality_flag == YES trace entered default RF5A analysis.');
        end
    end

    curveSamples.time_s = str2double(string(curveSamples{:, idxCurveSampleTime}));
    curveSamples.delta_m_num = str2double(string(curveSamples{:, idxCurveSampleDelta}));

    tMinEach = nan(nT, 1);
    tMaxEach = nan(nT, 1);
    for i = 1:nT
        s = curveSamples(strcmp(string(curveSamples{:, idxCurveSampleTraceId}), traceIds(i)), :);
        t = s.time_s;
        t = t(isfinite(t) & t > 0);
        tMinEach(i) = min(t);
        tMaxEach(i) = max(t);
    end
    tMinCommon = max(tMinEach);
    tMaxCommon = min(tMaxEach);
    if ~isfinite(tMinCommon) || ~isfinite(tMaxCommon) || tMinCommon <= 0 || tMaxCommon <= tMinCommon
        error('STOP: invalid common time grid.');
    end

    nGrid = 320;
    tGrid = linspace(tMinCommon, tMaxCommon, nGrid);
    X = nan(nT, nGrid);
    for i = 1:nT
        s = curveSamples(strcmp(string(curveSamples{:, idxCurveSampleTraceId}), traceIds(i)), :);
        t = s.time_s;
        x = s.delta_m_num;
        m = isfinite(t) & isfinite(x) & t > 0;
        [tU, ia] = unique(t(m), 'stable');
        xU = x(m);
        xU = xU(ia);
        X(i, :) = interp1(tU, xU, tGrid, 'linear', 'extrap');
    end

    % Best amplitude from RF5A: projection_onto_corrected_mean_curve
    f0 = mean(X, 1, 'omitnan');
    den = sum(f0.^2, 'omitnan');
    if den <= eps
        den = eps;
    end
    A = nan(nT, 1);
    for i = 1:nT
        A(i) = sum(X(i, :) .* f0, 2, 'omitnan') / den;
    end
    A(abs(A) < 1e-15) = 1e-15;

    Xhat = A * mean(X ./ A, 1, 'omitnan');
    R_temp_time = X - Xhat;
    R_time_temp = R_temp_time.';

    % T1 SVD rank structure
    [U, S, V] = svd(R_time_temp, 'econ');
    svals = diag(S);
    totalEnergy = sum(svals.^2);
    if totalEnergy <= eps
        totalEnergy = eps;
    end
    frac = (svals.^2) ./ totalEnergy;
    cumFrac = cumsum(frac);

    modeIdx = (1:numel(svals)).';
    specTbl = table(repmat(string(run_id), numel(svals), 1), modeIdx, svals, frac, cumFrac, ...
        'VariableNames', {'run_id','mode_index','singular_value','energy_fraction','cumulative_energy_fraction'});
    writetable(specTbl, spectrumPath);

    psi1_ref = U(:, 1);
    b1_ref = S(1,1) * V(:,1);
    rank1Dominant = "NO";
    if frac(1) >= 0.60
        rank1Dominant = "YES";
    end

    % T2 Mode stability (LOO)
    looTemp = nan(nT, 1);
    looCos = nan(nT, 1);
    for i = 1:nT
        keep = true(nT, 1);
        keep(i) = false;
        Rloo = R_time_temp(:, keep);
        [Uloo, ~, ~] = svd(Rloo, 'econ');
        psi = Uloo(:, 1);
        c = abs(sum(psi .* psi1_ref) / (norm(psi) * norm(psi1_ref)));
        looTemp(i) = temps(i);
        looCos(i) = c;
    end
    stableLOO = "NO";
    if min(looCos) >= 0.90
        stableLOO = "YES";
    end
    looTbl = table(repmat(string(run_id), nT, 1), looTemp, looCos, ...
        'VariableNames', {'run_id','left_out_temperature','psi1_cosine_similarity_to_full'});
    writetable(looTbl, stabilityPath);

    % T3 Amplitude invariance
    A_l2 = sqrt(mean(X.^2, 2, 'omitnan'));
    A_l2(abs(A_l2) < 1e-15) = 1e-15;
    Xhat_l2 = A_l2 * mean(X ./ A_l2, 1, 'omitnan');
    R_l2 = (X - Xhat_l2).';
    [U_l2, ~, ~] = svd(R_l2, 'econ');
    psi_l2 = U_l2(:, 1);
    cos_l2 = abs(sum(psi_l2 .* psi1_ref) / (norm(psi_l2) * norm(psi1_ref)));

    A_p2p = nan(nT, 1);
    for i = 1:nT
        xi = X(i, :);
        A_p2p(i) = max(xi) - min(xi);
    end
    A_p2p(abs(A_p2p) < 1e-15) = 1e-15;
    Xhat_p2p = A_p2p * mean(X ./ A_p2p, 1, 'omitnan');
    R_p2p = (X - Xhat_p2p).';
    [U_p2p, ~, ~] = svd(R_p2p, 'econ');
    psi_p2p = U_p2p(:, 1);
    cos_p2p = abs(sum(psi_p2p .* psi1_ref) / (norm(psi_p2p) * norm(psi1_ref)));

    ampInv = table(["projection_onto_corrected_mean_curve";"l2_norm";"peak_to_peak"], ...
        [1; cos_l2; cos_p2p], ...
        'VariableNames', {'amplitude_method','psi1_cosine_similarity_to_projection'});
    writetable(ampInv, ampInvPath);
    invariantAmp = "NO";
    if min([cos_l2, cos_p2p]) >= 0.90
        invariantAmp = "YES";
    end

    % T4 Subset robustness
    keepLow = true(nT,1);
    keepLow(1) = false;
    keepHigh = true(nT,1);
    keepHigh(end) = false;
    [U_noLow, S_noLow, ~] = svd(R_time_temp(:, keepLow), 'econ');
    [U_noHigh, S_noHigh, ~] = svd(R_time_temp(:, keepHigh), 'econ');
    psi_noLow = U_noLow(:,1);
    psi_noHigh = U_noHigh(:,1);
    cos_noLow = abs(sum(psi_noLow .* psi1_ref) / (norm(psi_noLow) * norm(psi1_ref)));
    cos_noHigh = abs(sum(psi_noHigh .* psi1_ref) / (norm(psi_noHigh) * norm(psi1_ref)));
    s_noLow = diag(S_noLow);
    s_noHigh = diag(S_noHigh);
    frac_noLow = (s_noLow(1)^2) / max(sum(s_noLow.^2), eps);
    frac_noHigh = (s_noHigh(1)^2) / max(sum(s_noHigh.^2), eps);
    subsetTbl = table(["drop_lowest_T";"drop_highest_T"], [cos_noLow; cos_noHigh], [frac_noLow; frac_noHigh], ...
        'VariableNames', {'subset_case','psi1_cosine_similarity_to_full','rank1_energy_fraction'});
    writetable(subsetTbl, subsetPath);
    robustSubset = "NO";
    if min([cos_noLow, cos_noHigh]) >= 0.90
        robustSubset = "YES";
    end

    % T5 Negative controls (tightened)
    nCtrl = 250;
    controlNames = ["column_sign_randomization"; ...
        "circular_time_shift_per_trace"; ...
        "residual_column_permutation_mc"; ...
        "phase_random_fourier_surrogate"];
    nCtl = numel(controlNames);
    ctrlFracDist = nan(nCtrl, nCtl);
    ctrlPass = strings(nCtl, 1);
    ctrlMean = nan(nCtl, 1);
    ctrlStd = nan(nCtl, 1);
    ctrlZ = nan(nCtl, 1);
    ctrlP = nan(nCtl, 1);

    for k = 1:nCtrl
        % 1) Column-sign randomization
        signs = ones(1, nT);
        flipMask = rand(1, nT) > 0.5;
        signs(flipMask) = -1;
        Rc = R_time_temp .* signs;
        [~, Sc, ~] = svd(Rc, 'econ');
        sv = diag(Sc);
        ctrlFracDist(k, 1) = (sv(1)^2) / max(sum(sv.^2), eps);

        % 2) Circular time shifts per trace (column)
        Rc = nan(size(R_time_temp));
        for j = 1:nT
            shift = randi([0, nGrid - 1], 1, 1);
            Rc(:, j) = circshift(R_time_temp(:, j), shift);
        end
        [~, Sc, ~] = svd(Rc, 'econ');
        sv = diag(Sc);
        ctrlFracDist(k, 2) = (sv(1)^2) / max(sum(sv.^2), eps);

        % 3) Residual column permutation Monte Carlo
        p = randperm(nT);
        Rc = R_time_temp(:, p);
        [~, Sc, ~] = svd(Rc, 'econ');
        sv = diag(Sc);
        ctrlFracDist(k, 3) = (sv(1)^2) / max(sum(sv.^2), eps);

        % 4) Optional deterministic phase-random Fourier surrogate
        Rc = nan(size(R_time_temp));
        for j = 1:nT
            x = R_time_temp(:, j);
            Xf = fft(x);
            n = numel(x);
            if mod(n, 2) == 0
                kmax = n / 2;
            else
                kmax = (n - 1) / 2;
            end
            ph = 2*pi*rand(kmax - 1, 1);
            Xnew = Xf;
            for kk = 2:kmax
                mag = abs(Xf(kk));
                Xnew(kk) = mag * exp(1i * ph(kk - 1));
                Xnew(n - kk + 2) = conj(Xnew(kk));
            end
            Rc(:, j) = real(ifft(Xnew));
        end
        [~, Sc, ~] = svd(Rc, 'econ');
        sv = diag(Sc);
        ctrlFracDist(k, 4) = (sv(1)^2) / max(sum(sv.^2), eps);
    end

    obsFrac = frac(1);
    for c = 1:nCtl
        d = ctrlFracDist(:, c);
        ctrlMean(c) = mean(d, 'omitnan');
        ctrlStd(c) = std(d, 'omitnan');
        ctrlZ(c) = (obsFrac - ctrlMean(c)) / max(ctrlStd(c), eps);
        ctrlP(c) = (sum(d >= obsFrac) + 1) / (numel(d) + 1);
        if ctrlP(c) < 0.05
            ctrlPass(c) = "PASS";
        else
            ctrlPass(c) = "FAIL";
        end
    end

    negTbl = table(controlNames, repmat(obsFrac, nCtl, 1), ctrlMean, ctrlStd, ctrlZ, ctrlP, ctrlPass, repmat(nCtrl, nCtl, 1), ...
        'VariableNames', {'control_type','observed_leading_singular_energy_fraction', ...
        'control_mean','control_std','z_score','empirical_p_value','pass_p_lt_0p05','n_monte_carlo'});
    writetable(negTbl, negPath);

    requiredControls = ismember(controlNames, ["column_sign_randomization","circular_time_shift_per_trace","residual_column_permutation_mc"]);
    failsNeg = "NO";
    if all(ctrlP(requiredControls) < 0.05)
        failsNeg = "YES";
    end
    worstRequiredP = max(ctrlP(requiredControls));

    stableMode = "NO";
    if stableLOO == "YES"
        stableMode = "YES";
    end

    finalMode = "NO";
    if rank1Dominant == "YES" && stableMode == "YES" && invariantAmp == "YES" && robustSubset == "YES" && failsNeg == "YES"
        finalMode = "YES";
    end

    verdict = table( ...
        rank1Dominant, ...
        stableMode, ...
        invariantAmp, ...
        robustSubset, ...
        failsNeg, ...
        finalMode, ...
        frac(1), ...
        min(looCos), ...
        min([cos_l2, cos_p2p]), ...
        min([cos_noLow, cos_noHigh]), ...
        max(ctrlMean(requiredControls)), ...
        worstRequiredP, ...
        "projection_onto_corrected_mean_curve", ...
        nT, ...
        'VariableNames', { ...
        'RESIDUAL_RANK1_DOMINANT', ...
        'MODE_SHAPE_STABLE', ...
        'MODE_INVARIANT_TO_AMPLITUDE', ...
        'MODE_ROBUST_TO_SUBSET', ...
        'MODE_FAILS_NEGATIVE_CONTROL', ...
        'FINAL_VERDICT_MODE_EXISTS', ...
        'rank1_energy_fraction_real', ...
        'loo_min_cosine_similarity', ...
        'amplitude_invariance_min_cosine', ...
        'subset_robustness_min_cosine', ...
        'negative_control_required_max_mean_rank1_energy', ...
        'negative_control_required_worst_empirical_p', ...
        'BEST_AMPLITUDE_CHOICE', ...
        'N_DEFAULT_REPLAY_TRACES'});
    writetable(verdict, verdictPath);

    fig1 = create_figure('Name', 'rf5a_residual_svd_spectrum_rf3r', 'NumberTitle', 'off', 'Position', [2 2 17.8 8.8]);
    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    nexttile;
    semilogy(modeIdx, svals, 'o-', 'LineWidth', 2.0);
    xlabel('Mode index');
    ylabel('Singular value');
    title('Residual SVD spectrum');
    grid on;
    nexttile;
    plot(modeIdx, frac, 'o-', 'LineWidth', 2.0);
    hold on;
    plot(modeIdx, cumFrac, '-', 'LineWidth', 1.6);
    xlabel('Mode index');
    ylabel('Energy fraction');
    title('Mode energy fractions');
    legend({'fraction','cumulative'}, 'Location', 'best');
    grid on;
    apply_publication_style(fig1);
    exportgraphics(fig1, fullfile(figDir, 'rf5a_residual_svd_spectrum_rf3r.png'), 'Resolution', 600);
    savefig(fig1, fullfile(figDir, 'rf5a_residual_svd_spectrum_rf3r.fig'));
    close(fig1);

    fig2 = create_figure('Name', 'rf5a_residual_mode_shape_rf3r', 'NumberTitle', 'off', 'Position', [2 2 17.8 8.8]);
    plot(tGrid, psi1_ref, 'k-', 'LineWidth', 2.2);
    xlabel('time\_since\_field\_off (s)');
    ylabel('Psi1(t) [arb.]');
    title('Residual dominant mode shape Psi1(t)');
    grid on;
    apply_publication_style(fig2);
    exportgraphics(fig2, fullfile(figDir, 'rf5a_residual_mode_shape_rf3r.png'), 'Resolution', 600);
    savefig(fig2, fullfile(figDir, 'rf5a_residual_mode_shape_rf3r.fig'));
    close(fig2);

    fig3 = create_figure('Name', 'rf5a_residual_mode_loadings_rf3r', 'NumberTitle', 'off', 'Position', [2 2 17.8 8.8]);
    plot(temps, b1_ref, 'o-', 'LineWidth', 2.2);
    xlabel('Temperature (K)');
    ylabel('b1(T) [arb.]');
    title('Residual dominant loading b1(T)');
    grid on;
    apply_publication_style(fig3);
    exportgraphics(fig3, fullfile(figDir, 'rf5a_residual_mode_loadings_rf3r.png'), 'Resolution', 600);
    savefig(fig3, fullfile(figDir, 'rf5a_residual_mode_loadings_rf3r.fig'));
    close(fig3);

    fig4 = create_figure('Name', 'rf5a_residual_negative_controls_rf3r', 'NumberTitle', 'off', 'Position', [2 2 17.8 8.8]);
    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    nexttile;
    bar(categorical(negTbl.control_type), negTbl.control_mean);
    hold on;
    er = errorbar(categorical(negTbl.control_type), negTbl.control_mean, negTbl.control_std, '.');
    er.Color = [0.2 0.2 0.2];
    er.LineWidth = 1.5;
    yline(frac(1), 'r-', 'LineWidth', 2.0);
    ylabel('Rank1 energy fraction');
    title('Control mean +/- std vs observed');
    grid on;
    nexttile;
    bar(categorical(negTbl.control_type), negTbl.empirical_p_value);
    hold on;
    yline(0.05, 'r--', 'LineWidth', 1.5);
    ylabel('Empirical p-value');
    title('Negative-control significance (p < 0.05)');
    grid on;
    apply_publication_style(fig4);
    exportgraphics(fig4, fullfile(figDir, 'rf5a_residual_negative_controls_rf3r.png'), 'Resolution', 600);
    savefig(fig4, fullfile(figDir, 'rf5a_residual_negative_controls_rf3r.fig'));
    close(fig4);

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('STOP: cannot write report.');
    end
    fprintf(fid, '# RF5A Residual Structure on RF3R Default Replay\n\n');
    fprintf(fid, '- Run used: `%s`\n', rfRunDir);
    fprintf(fid, '- Default replay traces: %d\n', nT);
    fprintf(fid, '- Amplitude method fixed: `projection_onto_corrected_mean_curve`\n');
    fprintf(fid, '- Rank-1 energy fraction (real residual): %.6f\n', frac(1));
    fprintf(fid, '- LOO min Psi1 cosine: %.6f\n', min(looCos));
    fprintf(fid, '- Amplitude invariance min cosine (L2 / peak-to-peak): %.6f\n', min([cos_l2, cos_p2p]));
    fprintf(fid, '- Subset robustness min cosine: %.6f\n', min([cos_noLow, cos_noHigh]));
    fprintf(fid, '- Negative-control worst required empirical p-value: %.6f\n', worstRequiredP);
    fprintf(fid, '\n## Negative control summary (observed leading singular energy: %.6f)\n', obsFrac);
    for c = 1:nCtl
        fprintf(fid, '- %s: mean=%.6f, std=%.6f, z=%.6f, p=%.6f, pass=%s\n', ...
            controlNames(c), ctrlMean(c), ctrlStd(c), ctrlZ(c), ctrlP(c), ctrlPass(c));
    end
    fprintf(fid, '\n## Verdicts\n');
    fprintf(fid, '- RESIDUAL_RANK1_DOMINANT: `%s`\n', rank1Dominant);
    fprintf(fid, '- MODE_SHAPE_STABLE: `%s`\n', stableMode);
    fprintf(fid, '- MODE_INVARIANT_TO_AMPLITUDE: `%s`\n', invariantAmp);
    fprintf(fid, '- MODE_ROBUST_TO_SUBSET: `%s`\n', robustSubset);
    fprintf(fid, '- MODE_FAILS_NEGATIVE_CONTROL: `%s`\n', failsNeg);
    fprintf(fid, '- FINAL_VERDICT_MODE_EXISTS: `%s`\n', finalMode);
    fprintf(fid, '\n## Interpretation constraints\n');
    fprintf(fid, '- This report states only rank dominance, mode stability, and residual structure status.\n');
    fprintf(fid, '- No mechanism claims, no cross-module links, and no RF5B conclusions are made.\n');
    fclose(fid);

    runSummary = sprintf('Residual mode tests completed on %d default-replay traces', nT);
    executionStatus = table({'SUCCESS'}, {char(inputFound)}, {''}, nT, {runSummary}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, execStatusPath);

catch ME
    emptySpec = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'run_id','mode_index','singular_value','energy_fraction','cumulative_energy_fraction'});
    writetable(emptySpec, spectrumPath);

    emptyStab = table(strings(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'run_id','left_out_temperature','psi1_cosine_similarity_to_full'});
    writetable(emptyStab, stabilityPath);

    emptyAmp = table(strings(0,1), zeros(0,1), ...
        'VariableNames', {'amplitude_method','psi1_cosine_similarity_to_projection'});
    writetable(emptyAmp, ampInvPath);

    emptySubset = table(strings(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'subset_case','psi1_cosine_similarity_to_full','rank1_energy_fraction'});
    writetable(emptySubset, subsetPath);

    emptyNeg = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), strings(0,1), zeros(0,1), ...
        'VariableNames', {'control_type','observed_leading_singular_energy_fraction', ...
        'control_mean','control_std','z_score','empirical_p_value','pass_p_lt_0p05','n_monte_carlo'});
    writetable(emptyNeg, negPath);

    failVerdict = table("NO","NO","NO","NO","NO","NO",NaN,NaN,NaN,NaN,NaN,NaN, ...
        "projection_onto_corrected_mean_curve",0, ...
        'VariableNames', {'RESIDUAL_RANK1_DOMINANT','MODE_SHAPE_STABLE','MODE_INVARIANT_TO_AMPLITUDE', ...
        'MODE_ROBUST_TO_SUBSET','MODE_FAILS_NEGATIVE_CONTROL','FINAL_VERDICT_MODE_EXISTS', ...
        'rank1_energy_fraction_real','loo_min_cosine_similarity','amplitude_invariance_min_cosine', ...
        'subset_robustness_min_cosine','negative_control_required_max_mean_rank1_energy', ...
        'negative_control_required_worst_empirical_p','BEST_AMPLITUDE_CHOICE','N_DEFAULT_REPLAY_TRACES'});
    writetable(failVerdict, verdictPath);

    fid = fopen(reportPath, 'w');
    if fid >= 0
        fprintf(fid, '# RF5A Residual Structure on RF3R Default Replay\n\n');
        fprintf(fid, '- STATUS: FAILED\n');
        fprintf(fid, '- ERROR: `%s`\n', ME.message);
        fprintf(fid, '- Run target: `%s`\n', rfRunDir);
        fprintf(fid, '- No out-of-scope inputs were used.\n');
        fclose(fid);
    end

    executionStatus = table({'FAILED'}, {char(inputFound)}, {ME.message}, nT, {'Residual mode execution failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, execStatusPath);
    rethrow(ME);
end

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
