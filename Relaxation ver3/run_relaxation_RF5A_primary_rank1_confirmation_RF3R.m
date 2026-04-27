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

run_id = "run_2026_04_26_234453";
rfRunDir = fullfile(repoRoot, 'results', 'relaxation_post_field_off_RF3R_canonical', 'runs', run_id);
rfTablesDir = fullfile(rfRunDir, 'tables');
outTablesDir = fullfile(repoRoot, 'tables');
outReportsDir = fullfile(repoRoot, 'reports');
if exist(outTablesDir, 'dir') ~= 7, mkdir(outTablesDir); end
if exist(outReportsDir, 'dir') ~= 7, mkdir(outReportsDir); end

spectrumPath = fullfile(outTablesDir, 'relaxation_RF5A_primary_rank1_spectrum_RF3R.csv');
reconPath = fullfile(outTablesDir, 'relaxation_RF5A_primary_rank1_reconstruction_RF3R.csv');
vsAmpPath = fullfile(outTablesDir, 'relaxation_RF5A_primary_rank1_vs_amplitude_RF3R.csv');
verdictPath = fullfile(outTablesDir, 'relaxation_RF5A_primary_rank1_verdict_RF3R.csv');
reportPath = fullfile(outReportsDir, 'relaxation_RF5A_primary_rank1_confirmation_RF3R.md');
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

    % Primary SVD on DeltaM directly
    [U, S, V] = svd(X, 'econ');
    svals = diag(S);
    eFrac = (svals.^2) / max(sum(svals.^2), eps);
    cFrac = cumsum(eFrac);
    k = (1:numel(svals)).';
    specTbl = table(repmat(string(run_id), numel(svals), 1), k, svals, eFrac, cFrac, ...
        'VariableNames', {'run_id','mode_index','singular_value','energy_fraction','cumulative_energy_fraction'});
    writetable(specTbl, spectrumPath);

    X1 = U(:,1) * S(1,1) * V(:,1).';
    errF = norm(X - X1, 'fro') / max(norm(X, 'fro'), eps);
    r2 = 1 - sum((X(:) - X1(:)).^2) / max(sum(X(:).^2), eps);

    psi0 = U(:,1);
    A0 = S(1,1) * V(:,1);
    reconTbl = table(repmat(string(run_id), nT, 1), temps, A0, ...
        repmat(errF, nT, 1), repmat(r2, nT, 1), ...
        'VariableNames', {'run_id','temperature','A0_from_primary_svd','rank1_relative_fro_error','rank1_variance_explained'});
    writetable(reconTbl, reconPath);

    % Compare primary SVD rank1 vs RF5A amplitude-only replay (recomputed here)
    f0 = mean(XtempTime, 1, 'omitnan');
    den = sum(f0.^2, 'omitnan');
    if den <= eps, den = eps; end
    Aamp = nan(nT,1);
    for i = 1:nT
        Aamp(i) = sum(XtempTime(i,:) .* f0, 2, 'omitnan') / den;
    end
    Aamp(abs(Aamp) < 1e-15) = 1e-15;
    XampTempTime = Aamp * mean(XtempTime ./ Aamp, 1, 'omitnan');
    Xamp = XampTempTime.';
    errAmp = norm(X - Xamp, 'fro') / max(norm(X, 'fro'), eps);
    r2Amp = 1 - sum((X(:) - Xamp(:)).^2) / max(sum(X(:).^2), eps);

    cosPsi = abs(sum(U(:,1) .* mean(XtempTime ./ Aamp, 1, 'omitnan').') / ...
        (norm(U(:,1)) * norm(mean(XtempTime ./ Aamp, 1, 'omitnan').')));
    vsAmpTbl = table(string(run_id), errF, r2, errAmp, r2Amp, cosPsi, ...
        'VariableNames', {'run_id','primary_svd_rank1_error','primary_svd_rank1_variance_explained', ...
        'amplitude_only_error','amplitude_only_variance_explained','cosine_primary_mode_vs_amplitude_shape'});
    writetable(vsAmpTbl, vsAmpPath);

    v_rank1 = "NO";
    if eFrac(1) >= 0.85
        v_rank1 = "YES";
    end
    v_recon = "NO";
    if errF <= 0.25
        v_recon = "YES";
    end
    v_shape_match = "NO";
    if cosPsi >= 0.90
        v_shape_match = "YES";
    end
    v_amp_replay_match = "NO";
    if abs(errF - errAmp) <= 0.08
        v_amp_replay_match = "YES";
    end
    v_agree = "NO";
    if v_shape_match == "YES" && v_amp_replay_match == "YES"
        v_agree = "YES";
    end
    v_old = "NO";
    if v_rank1 == "YES" && v_recon == "YES"
        v_old = "YES";
    end

    verdict = table(v_rank1, v_recon, v_agree, v_old, v_shape_match, v_amp_replay_match, "NO", ...
        eFrac(1), errF, r2, errAmp, r2Amp, cosPsi, nT, ...
        'VariableNames', {'PRIMARY_RELAXATION_RANK1_DOMINANT', ...
        'PRIMARY_MODE_RECONSTRUCTION_GOOD', ...
        'PRIMARY_SVD_AGREES_WITH_AMPLITUDE_ONLY', ...
        'OLD_RANK1_CONCLUSION_SURVIVES_RF3R', ...
        'PRIMARY_MODE_SHAPE_MATCHES_AMPLITUDE_SHAPE', ...
        'PRIMARY_AMPLITUDE_REPLAY_MATCHES_SVD_RECONSTRUCTION', ...
        'RESIDUAL_SECOND_MODE_ESTABLISHED', ...
        'primary_rank1_energy_fraction', ...
        'primary_rank1_reconstruction_error', ...
        'primary_rank1_variance_explained', ...
        'amplitude_only_reconstruction_error', ...
        'amplitude_only_variance_explained', ...
        'cosine_primary_mode_vs_amplitude_shape', ...
        'N_DEFAULT_REPLAY_TRACES'});
    writetable(verdict, verdictPath);

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('STOP: cannot write report.');
    end
    fprintf(fid, '# RF5A Primary Rank-1 Confirmation on RF3R Object\n\n');
    fprintf(fid, '- Run used: `%s`\n', rfRunDir);
    fprintf(fid, '- Default replay traces used: %d\n', nT);
    fprintf(fid, '- Common positive-time grid: [%.6g, %.6g] s with %d points\n', tMinCommon, tMaxCommon, nGrid);
    fprintf(fid, '- Primary rank-1 energy fraction: %.6f\n', eFrac(1));
    fprintf(fid, '- Primary SVD rank-1 reconstruction error: %.6f\n', errF);
    fprintf(fid, '- Amplitude-only reconstruction error (recomputed): %.6f\n', errAmp);
    fprintf(fid, '- Primary mode vs amplitude-shape cosine: %.6f\n', cosPsi);
    fprintf(fid, '\n## Required verdicts\n');
    fprintf(fid, '- PRIMARY_RELAXATION_RANK1_DOMINANT: `%s`\n', v_rank1);
    fprintf(fid, '- PRIMARY_MODE_RECONSTRUCTION_GOOD: `%s`\n', v_recon);
    fprintf(fid, '- PRIMARY_SVD_AGREES_WITH_AMPLITUDE_ONLY: `%s`\n', v_agree);
    fprintf(fid, '- OLD_RANK1_CONCLUSION_SURVIVES_RF3R: `%s`\n', v_old);
    fprintf(fid, '- PRIMARY_MODE_SHAPE_MATCHES_AMPLITUDE_SHAPE: `%s`\n', v_shape_match);
    fprintf(fid, '- PRIMARY_AMPLITUDE_REPLAY_MATCHES_SVD_RECONSTRUCTION: `%s`\n', v_amp_replay_match);
    fprintf(fid, '- RESIDUAL_SECOND_MODE_ESTABLISHED: `NO`\n');
    fprintf(fid, '\n## Interpretation constraints\n');
    fprintf(fid, '- This report addresses rank-1 dominance and reconstruction agreement only.\n');
    fprintf(fid, '- No mechanism claims, no RF5B conclusion, no collapse analysis, and no cross-module interpretation.\n');
    fclose(fid);

    execTbl = table({'SUCCESS'}, {char(inputFound)}, {''}, nT, {'Primary rank-1 confirmation completed'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
    writetable(execTbl, execStatusPath);

catch ME
    emptySpec = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'run_id','mode_index','singular_value','energy_fraction','cumulative_energy_fraction'});
    writetable(emptySpec, spectrumPath);
    emptyRecon = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'run_id','temperature','A0_from_primary_svd','rank1_relative_fro_error','rank1_variance_explained'});
    writetable(emptyRecon, reconPath);
    emptyVs = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'run_id','primary_svd_rank1_error','primary_svd_rank1_variance_explained', ...
        'amplitude_only_error','amplitude_only_variance_explained','cosine_primary_mode_vs_amplitude_shape'});
    writetable(emptyVs, vsAmpPath);
    failVerdict = table("NO","NO","NO","NO","NO","NO","NO",NaN,NaN,NaN,NaN,NaN,NaN,0, ...
        'VariableNames', {'PRIMARY_RELAXATION_RANK1_DOMINANT', ...
        'PRIMARY_MODE_RECONSTRUCTION_GOOD', ...
        'PRIMARY_SVD_AGREES_WITH_AMPLITUDE_ONLY', ...
        'OLD_RANK1_CONCLUSION_SURVIVES_RF3R', ...
        'PRIMARY_MODE_SHAPE_MATCHES_AMPLITUDE_SHAPE', ...
        'PRIMARY_AMPLITUDE_REPLAY_MATCHES_SVD_RECONSTRUCTION', ...
        'RESIDUAL_SECOND_MODE_ESTABLISHED', ...
        'primary_rank1_energy_fraction', ...
        'primary_rank1_reconstruction_error', ...
        'primary_rank1_variance_explained', ...
        'amplitude_only_reconstruction_error', ...
        'amplitude_only_variance_explained', ...
        'cosine_primary_mode_vs_amplitude_shape', ...
        'N_DEFAULT_REPLAY_TRACES'});
    writetable(failVerdict, verdictPath);

    fid = fopen(reportPath, 'w');
    if fid >= 0
        fprintf(fid, '# RF5A Primary Rank-1 Confirmation on RF3R Object\n\n');
        fprintf(fid, '- STATUS: FAILED\n');
        fprintf(fid, '- ERROR: `%s`\n', ME.message);
        fprintf(fid, '- Run target: `%s`\n', rfRunDir);
        fclose(fid);
    end
    execTbl = table({'FAILED'}, {char(inputFound)}, {ME.message}, nT, {'Primary rank-1 confirmation failed'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
    writetable(execTbl, execStatusPath);
    rethrow(ME);
end

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
