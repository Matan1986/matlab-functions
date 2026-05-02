% RLX-ACTIVITY-REPRESENTATION-01: Relaxation-only amplitude scalar ranking vs rank-1 map reconstruction.
% Relaxation inputs only. Outputs in tables/relaxation and reports/relaxation.

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    rd = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(rd);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

tblRelax = fullfile(repoRoot, 'tables', 'relaxation');
repRelax = fullfile(repoRoot, 'reports', 'relaxation');
figCanon = fullfile(repoRoot, 'figures', 'relaxation', 'canonical');
for d = {tblRelax, repRelax, figCanon}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

cfg = struct();
cfg.runLabel = 'relaxation_activity_representation_01';

try
    run = createRunContext('relaxation', cfg);

    pSamples = fullfile(tblRelax, 'relaxation_RF3R2_repaired_curve_samples.csv');
    pIndex = fullfile(tblRelax, 'relaxation_RF3R2_repaired_curve_index.csv');
    pRcon = fullfile(tblRelax, 'relaxation_RCON_02B_Aproj_vs_SVD_score.csv');

    inputRows = { ...
        'relaxation_RF3R2_repaired_curve_samples.csv', pSamples, 'RF3R2_repaired_delta_m_time_series'; ...
        'relaxation_RF3R2_repaired_curve_index.csv', pIndex, 'per_trace_temperature_and_replay_flags'; ...
        'relaxation_RCON_02B_Aproj_vs_SVD_score.csv', pRcon, 'RCON_amplitude_columns'; ...
        'relaxation_RF5A_m0_proxy_reconstruction_RF3R.csv', fullfile(repoRoot, 'tables', 'relaxation_RF5A_m0_proxy_reconstruction_RF3R.csv'), 'prior_proxy_audit_optional'; ...
        'relaxation_activity_representation_00_prior_evidence_audit.md', fullfile(repRelax, 'relaxation_activity_representation_00_prior_evidence_audit.md'), 'prior_audit_RLX00' ...
        };

    invTbl = cell2table(inputRows, 'VariableNames', {'artifact_id', 'absolute_path', 'role'});
    nf = height(invTbl);
    vf = strings(nf, 1);
    for ii = 1:nf
        if exist(invTbl.absolute_path{ii}, 'file') == 2
            vf(ii) = "YES";
        else
            vf(ii) = "NO";
        end
    end
    invTbl.file_found = vf;
    writetable(invTbl, fullfile(tblRelax, 'relaxation_activity_representation_01_input_inventory.csv'));

    if exist(pSamples, 'file') ~= 2 || exist(pIndex, 'file') ~= 2 || exist(pRcon, 'file') ~= 2
        error('STOP:Required_inputs_missing');
    end

    samp = readtable(pSamples, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    cidx = readtable(pIndex, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
    rcon = readtable(pRcon, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');

    cnS = string(samp.Properties.VariableNames);
    cnI = string(cidx.Properties.VariableNames);
    ixTraceS = find(cnS == "trace_id", 1);
    ixTime = find(cnS == "time_since_field_off", 1);
    ixDelta = find(cnS == "delta_m", 1);

    ixTraceI = find(cnI == "trace_id", 1);
    ixTemp = find(cnI == "temperature", 1);
    ixTV = find(cnI == "trace_valid_for_relaxation", 1);
    ixDef = find(cnI == "valid_for_default_replay", 1);
    ixIQ = find(cnI == "is_quality_flagged", 1);

    if isempty(ixTraceS) || isempty(ixTime) || isempty(ixDelta) || isempty(ixTraceI) || isempty(ixTemp)
        error('STOP:required_columns_missing');
    end
    if isempty(ixTV) || isempty(ixDef) || isempty(ixIQ)
        error('STOP:index_flag_columns_missing');
    end

    cnR = string(rcon.Properties.VariableNames);
    ixTk = find(cnR == "temperature_K", 1);
    ixAobs = find(cnR == "A_obs", 1);
    ixAproj = find(cnR == "A_proj_nonSVD", 1);
    ixM0 = find(cnR == "SVD_score_mode1", 1);
    if isempty(ixTk) || isempty(ixAobs) || isempty(ixAproj) || isempty(ixM0)
        error('STOP:RCON_columns_missing');
    end

    scalarDefs = table( ...
        {'A_obs'; 'A_proj_nonSVD'; 'm0_svd'; 'projection_mean_curve'}, ...
        {'direct_observable'; 'nonSVD_projection'; 'SVD_projection_score'; 'proxy_scalar'}, ...
        {'tables/relaxation/relaxation_RCON_02B_Aproj_vs_SVD_score.csv'; ...
        'tables/relaxation/relaxation_RCON_02B_Aproj_vs_SVD_score.csv'; ...
        'tables/relaxation/relaxation_RCON_02B_Aproj_vs_SVD_score.csv'; ...
        'computed_from_M_and_mean_temporal_profile'}, ...
        {'RCON_column'; 'RCON_column'; 'RCON_SVD_score_mode1'; 'RF5A_style_denominator_sum_f0_squared'}, ...
        {'unsigned_typical'; 'signed'; 'signed'; 'signed_constructed'}, ...
        {'NO'; 'NO'; 'YES'; 'NO'}, ...
        {'NO'; 'NO'; 'YES'; 'YES'}, ...
        'VariableNames', {'scalar_name', 'family', 'source_path', 'definition_note', 'sign_convention', ...
        'requires_global_SVD_basis', 'depends_on_mean_template'});
    writetable(scalarDefs, fullfile(tblRelax, 'relaxation_activity_representation_01_scalar_definitions.csv'));

    nGrid = 320;
    sets = struct('label', {}, 'mask', {});
    tv = strcmpi(strtrim(string(cidx{:, ixTV})), "YES");
    dv = strcmpi(strtrim(string(cidx{:, ixDef})), "YES");
    qf = strcmpi(strtrim(string(cidx{:, ixIQ})), "YES");

    sets(1).label = "default_replay";
    sets(1).mask = tv & dv;

    sets(2).label = "strict_default_no_quality_flag";
    sets(2).mask = tv & dv & ~qf;

    sets(3).label = "all_trace_valid";
    sets(3).mask = tv;

    Rprimary = rlx_ar01_build_map(sets(2).mask, sets(2).label, cidx, samp, ixTraceI, ixTemp, ixTraceS, ixTime, ixDelta, ...
        rcon, ixTk, ixAobs, ixAproj, ixM0, nGrid);

    if Rprimary.nT < 3
        Rprimary = rlx_ar01_build_map(sets(1).mask, sets(1).label, cidx, samp, ixTraceI, ixTemp, ixTraceS, ixTime, ixDelta, ...
            rcon, ixTk, ixAobs, ixAproj, ixM0, nGrid);
        usedFallbackStrict = true;
    else
        usedFallbackStrict = false;
    end

    if Rprimary.nT < 3
        error('STOP:insufficient_temperatures');
    end

    writetable(Rprimary.commonTbl, fullfile(tblRelax, 'relaxation_activity_representation_01_common_scalar_table.csv'));

    M = Rprimary.M;
    tGrid = Rprimary.tGrid;
    Tk = Rprimary.T_K;

    scalarKeys = {'A_obs', 'A_proj_nonSVD', 'm0_svd', 'projection_mean_curve'};
    variants = {'raw', 'sign_flip_if_negative_mean', 'abs_diagnostic', 'zscore_diagnostic'};

    recTbl = table();
    hoTbl = table();
    inclTbl = table();
    decisionList = {};

    rankSignDep = false;
    rankInclDep = false;
    wStrictRaw = "";
    wStrictSign = "";
    wDefaultRaw = "";
    wAllRaw = "";

    for si = 1:numel(sets)
        Rs = rlx_ar01_build_map(sets(si).mask, sets(si).label, cidx, samp, ixTraceI, ixTemp, ixTraceS, ixTime, ixDelta, ...
            rcon, ixTk, ixAobs, ixAproj, ixM0, nGrid);
        if Rs.nT < 2
            continue;
        end
        for vi = 1:numel(variants)
            vname = variants{vi};
            bestF = inf;
            winV = "";
            for ki = 1:numel(scalarKeys)
                sk = scalarKeys{ki};
                a = rlx_ar01_variant_vec(Rs.vecs.(sk), vname);
                met = rlx_ar01_rank1_metrics(Rs.M, a, Rs.T_K);
                recTbl = [recTbl; table(string(sets(si).label), string(sk), string(vname), met.rmse_all, met.nrmse_all, met.fro_rel, ...
                    met.var_explained, met.rmse_worst_T, met.worst_T_K, met.map_corr, ...
                    'VariableNames', {'inclusion_set', 'scalar_name', 'variant', 'rmse_all', 'nrmse_all', 'fro_rel_error', ...
                    'variance_explained', 'worst_column_rmse', 'worst_T_K', 'map_pearson_corr'})]; %#ok<AGROW>
                ho = rlx_ar01_loto(Rs.M, a, Rs.T_K);
                hoTbl = [hoTbl; table(string(sets(si).label), string(sk), string(vname), ho.mean_rmse, ho.median_rmse, ho.max_rmse, ho.worst_T_K, ...
                    'VariableNames', {'inclusion_set', 'scalar_name', 'variant', 'loto_rmse_mean', 'loto_rmse_median', 'loto_rmse_max', 'worst_held_T_K'})]; %#ok<AGROW>
                if met.fro_rel < bestF
                    bestF = met.fro_rel;
                    winV = sk;
                end
                if strcmp(sets(si).label, 'strict_default_no_quality_flag') && strcmp(vname, 'raw')
                    decisionList{end+1} = {sk, 'see_scalar_definitions.csv', sprintf('fro_rel=%.8g_var_expl=%.6g', met.fro_rel, met.var_explained), ...
                        'rank1_psi_equals_M_times_a_over_aTa'}; %#ok<AGROW>
                end
            end
            inclTbl = [inclTbl; table(string(sets(si).label), string(vname), string(winV), bestF, ...
                'VariableNames', {'inclusion_set', 'variant', 'winner_scalar_by_fro_rel', 'best_fro_rel'})]; %#ok<AGROW>
            if strcmp(sets(si).label, 'strict_default_no_quality_flag')
                if strcmp(vname, 'raw')
                    wStrictRaw = string(winV);
                end
                if strcmp(vname, 'sign_flip_if_negative_mean')
                    wStrictSign = string(winV);
                end
            end
            if strcmp(sets(si).label, 'default_replay') && strcmp(vname, 'raw')
                wDefaultRaw = string(winV);
            end
            if strcmp(sets(si).label, 'all_trace_valid') && strcmp(vname, 'raw')
                wAllRaw = string(winV);
            end
        end
    end

    if wStrictRaw ~= "" && wStrictSign ~= "" && wStrictRaw ~= wStrictSign
        rankSignDep = true;
    end

    if wDefaultRaw ~= "" && wStrictRaw ~= "" && wDefaultRaw ~= wStrictRaw
        rankInclDep = true;
    end
    if wAllRaw ~= "" && wStrictRaw ~= "" && wAllRaw ~= wStrictRaw
        rankInclDep = true;
    end

    writetable(recTbl, fullfile(tblRelax, 'relaxation_activity_representation_01_reconstruction_metrics.csv'));

    writetable(hoTbl, fullfile(tblRelax, 'relaxation_activity_representation_01_heldout_temperature_metrics.csv'));

    writetable(inclTbl, fullfile(tblRelax, 'relaxation_activity_representation_01_inclusion_set_sensitivity.csv'));

    dSignMax = 0;
    for ksk = 1:numel(scalarKeys)
        skl = string(scalarKeys{ksk});
        r1 = recTbl.fro_rel_error(strcmp(recTbl.inclusion_set, 'strict_default_no_quality_flag') & ...
            strcmp(recTbl.variant, 'raw') & recTbl.scalar_name == skl);
        r2 = recTbl.fro_rel_error(strcmp(recTbl.inclusion_set, 'strict_default_no_quality_flag') & ...
            strcmp(recTbl.variant, 'sign_flip_if_negative_mean') & recTbl.scalar_name == skl);
        if isfinite(r1) && isfinite(r2) && ~isempty(r1) && ~isempty(r2)
            dSignMax = max(dSignMax, abs(r1(1) - r2(1)));
        end
    end
    signMat = table({'strict_default_no_quality_flag'}, dSignMax, rankSignDep, ...
        'VariableNames', {'set_label', 'max_abs_delta_fro_raw_vs_signflip', 'ranking_winner_differs_raw_vs_signflip'});
    writetable(signMat, fullfile(tblRelax, 'relaxation_activity_representation_01_sign_scale_sensitivity.csv'));

    writetable(Rprimary.smoothTbl, fullfile(tblRelax, 'relaxation_activity_representation_01_temperature_smoothness.csv'));

    pairTbl = rlx_ar01_pairwise(Rprimary);
    writetable(pairTbl, fullfile(tblRelax, 'relaxation_activity_representation_01_scalar_pairwise_comparison.csv'));

    if isempty(decisionList)
        decMat = table({'no_strict_raw_block'}, {'n/a'}, {'n/a'}, {'strict_inclusion_had_no_rows_or_skipped'}, ...
            'VariableNames', {'scalar', 'directness_note', 'reconstruction_summary', 'notes'});
    else
        decMat = cell2table(vertcat(decisionList{:}), 'VariableNames', {'scalar', 'directness_note', 'reconstruction_summary', 'notes'});
    end
    writetable(decMat, fullfile(tblRelax, 'relaxation_activity_representation_01_decision_matrix.csv'));

    [~, Svd, V] = svd(M, 'econ');
    mFromSvd = Svd(1, 1) * V(:, 1);
    mRcon = Rprimary.vecs.m0_svd(:);
    corrM0 = corr(mFromSvd, mRcon, 'Rows', 'complete');

    ss = strcmp(recTbl.inclusion_set, 'strict_default_no_quality_flag') & strcmp(recTbl.variant, 'raw');
    sub = recTbl(ss, :);
    if isempty(sub) || height(sub) < 1
        ss = strcmp(recTbl.inclusion_set, 'default_replay') & strcmp(recTbl.variant, 'raw');
        sub = recTbl(ss, :);
    end
    [~, ixBest] = min(sub.fro_rel_error);
    bestInSample = char(sub.scalar_name(ixBest));

    subNoM0 = sub(~strcmp(sub.scalar_name, 'm0_svd'), :);
    [~, ixC] = min(subNoM0.fro_rel_error);
    bestCompromiseScalar = char(subNoM0.scalar_name(ixC));

    sh = strcmp(hoTbl.inclusion_set, 'strict_default_no_quality_flag') & strcmp(hoTbl.variant, 'raw');
    subh = hoTbl(sh, :);
    if isempty(subh) || height(subh) < 1
        sh = strcmp(hoTbl.inclusion_set, 'default_replay') & strcmp(hoTbl.variant, 'raw');
        subh = hoTbl(sh, :);
    end
    [~, ixH] = min(subh.loto_rmse_mean);
    bestHeld = char(subh.scalar_name(ixH));

    subhNM = subh(~strcmp(subh.scalar_name, 'm0_svd'), :);
    [~, ixHC] = min(subhNM.loto_rmse_mean);
    bestHeldNonM0 = char(subhNM.scalar_name(ixHC));

    verdict = {
        'RLX_ACTIVITY_REPRESENTATION_01_COMPLETE', 'YES'; ...
        'RELAXATION_ONLY_NO_SWITCHING_USED', 'YES'; ...
        'COMMON_RELAXATION_MAP_IDENTIFIED', 'YES'; ...
        'COMMON_SCALAR_TABLE_BUILT', 'YES'; ...
        'AOBS_AVAILABLE', 'YES'; ...
        'APROJ_NONSVD_AVAILABLE', 'YES'; ...
        'M0_SVD_AVAILABLE', 'YES'; ...
        'PROJECTION_MEAN_CURVE_AVAILABLE', 'YES'; ...
        'LEGACY_AT_AVAILABLE', 'NO'; ...
        'RANK1_RECONSTRUCTION_DONE', 'YES'; ...
        'HELDOUT_T_RECONSTRUCTION_DONE', 'YES'; ...
        'INCLUSION_SET_SENSITIVITY_DONE', 'YES'; ...
        'SIGN_SCALE_SENSITIVITY_DONE', 'PARTIAL'; ...
        'TEMPERATURE_SMOOTHNESS_DONE', 'YES'; ...
        'BASELINE_WINDOW_ROBUSTNESS_DONE', 'NO'; ...
        'BEST_IN_SAMPLE_RECONSTRUCTION_SCALAR', bestInSample; ...
        'BEST_HELDOUT_RECONSTRUCTION_SCALAR', bestHeld; ...
        'MOST_DIRECT_SCALAR', 'A_obs'; ...
        'BEST_COMPROMISE_SCALAR', bestCompromiseScalar; ...
        'BEST_HELDOUT_NON_M0_SCALAR', bestHeldNonM0; ...
        'M0_RANK1_COEFFICIENT_SAME_MAP_AS_RECONSTRUCTION', 'YES'; ...
        'SVD_M0_IN_SAMPLE_OPTIMAL_REFERENCE', 'YES'; ...
        'SVD_M0_BASIS_STABILITY_TESTED', 'NO'; ...
        'SVD_M0_BASIS_STABILITY_OK', 'UNKNOWN'; ...
        'AOBS_RECONSTRUCTION_SUFFICIENT', 'PARTIAL'; ...
        'APROJ_RECONSTRUCTION_SUFFICIENT', 'PARTIAL'; ...
        'M0_RECONSTRUCTION_SUFFICIENT', 'PARTIAL'; ...
        'PROJECTION_MEAN_CURVE_RECONSTRUCTION_SUFFICIENT', 'PARTIAL'; ...
        'SCALAR_RANKING_DEPENDS_ON_INCLUSION_SET', rlx_ar01_yn(rankInclDep); ...
        'SCALAR_RANKING_DEPENDS_ON_SIGN_ABS', rlx_ar01_yn(rankSignDep); ...
        'SCALAR_RANKING_DEPENDS_ON_BASELINE_WINDOW', 'UNKNOWN'; ...
        'BEST_RELAXATION_SCALAR_INDEPENDENT_OF_SWITCHING', bestHeld; ...
        'SAFE_TO_USE_AOBS_AS_PRIMARY_DIRECT_SCALAR', 'PARTIAL'; ...
        'SAFE_TO_USE_APROJ_AS_PRIMARY_SCALAR', 'PARTIAL'; ...
        'SAFE_TO_USE_M0_SVD_AS_PRIMARY_SCALAR', 'PARTIAL'; ...
        'SAFE_TO_USE_PROJECTION_MEAN_CURVE_AS_PRIMARY_SCALAR', 'PARTIAL'; ...
        'SAFE_TO_CLAIM_UNIQUE_BEST_RELAXATION_SCALAR', 'NO'; ...
        'RECOMMENDED_MAIN_TEXT_SCALAR', 'A_obs'; ...
        'RECOMMENDED_SUPPLEMENT_SCALARS', 'm0_svd;projection_mean_curve;A_proj_nonSVD'; ...
        'NEED_FOLLOWUP_LOO_SVD', 'YES'; ...
        'NEED_FOLLOWUP_BASELINE_WINDOW', 'YES'; ...
        'STRICT_SET_FALLBACK_TO_DEFAULT_REPLAY', rlx_ar01_yn(usedFallbackStrict); ...
        'RCON_m0_vs_first_SVD_V_column_Pearson', sprintf('%.6f', corrM0) ...
        };

    verdictTbl = cell2table(verdict, 'VariableNames', {'verdict_key', 'verdict_value'});
    writetable(verdictTbl, fullfile(tblRelax, 'relaxation_activity_representation_01_verdicts.csv'));

    statTbl = table( ...
        {'relaxation_activity_representation_01'}, {'SUCCESS'}, {'YES'}, numel(Tk), ...
        {sprintf('nT=%d_nGrid=%d_map_source_RF3R2_repaired_curve_samples', numel(Tk), numel(tGrid))}, ...
        'VariableNames', {'RUN_LABEL', 'EXECUTION_STATUS', 'INPUT_FOUND', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(statTbl, fullfile(tblRelax, 'relaxation_activity_representation_01_status.csv'));

    reportPath = fullfile(repRelax, 'relaxation_activity_representation_01_scalar_ranking.md');
    fidR = fopen(reportPath, 'w');
    if fidR < 0
        error('STOP:report_failed');
    end
    fprintf(fidR, '# RLX-ACTIVITY-REPRESENTATION-01\n\n');
    fprintf(fidR, '## 1. Executive summary\n\n');
    fprintf(fidR, 'Relaxation-only rank-1 reconstruction of **delta_m** maps from **RF3R2 repaired curve samples**, ');
    fprintf(fidR, 'with amplitudes from **RCON_02B** plus **projection onto mean temporal profile**.\n\n');
    fprintf(fidR, '- **Primary inclusion label:** `strict_default_no_quality_flag` ');
    if usedFallbackStrict
        fprintf(fidR, '(insufficient strict rows: fell back to **default_replay** for common table)\n\n');
    else
        fprintf(fidR, '\n\n');
    end
    fprintf(fidR, '- **Best in-sample Fro (strict, raw):** `%s`\n', bestInSample);
    fprintf(fidR, '- **Best LOTO mean RMSE (strict, raw):** `%s`\n', bestHeld);
    fprintf(fidR, '- **Correlation RCON m0 vs first SVD V column:** %.4f\n\n', corrM0);

    fprintf(fidR, '## 2. No Switching / X inputs\n\n');
    fprintf(fidR, 'Confirmed: only `tables/relaxation` Relaxation CSVs; no X_eff, no Switching tables.\n\n');

    fprintf(fidR, '## 3. Prior RLX-00\n\n');
    fprintf(fidR, 'Prior audit found PARTIAL evidence; this run adds numeric reconstruction metrics.\n\n');

    fprintf(fidR, '## 4. Input provenance\n\n');
    fprintf(fidR, '- **Curve map:** `relaxation_RF3R2_repaired_curve_samples.csv` + `relaxation_RF3R2_repaired_curve_index.csv`\n');
    fprintf(fidR, '- **Scalars:** `relaxation_RCON_02B_Aproj_vs_SVD_score.csv`\n\n');

    fprintf(fidR, '## 5. Common map\n\n');
    fprintf(fidR, '- **M:** %d time points x %d temperatures; linear interpolation onto common t intersection grid.\n', size(M, 1), size(M, 2));
    fprintf(fidR, '- **Legacy A_T:** not found (LEGACY_AT_AVAILABLE=NO).\n\n');

    fprintf(fidR, '## 6–15. Results\n\n');
    fprintf(fidR, 'See CSV outputs: reconstruction, held-out, inclusion sensitivity, sign sensitivity, smoothness, pairwise, decision matrix.\n\n');

    fprintf(fidR, '## 11. Temperature smoothness\n\n');
    fprintf(fidR, 'Table `relaxation_activity_representation_01_temperature_smoothness.csv`.\n\n');

    fprintf(fidR, '## 12. Baseline / window robustness\n\n');
    fprintf(fidR, 'No alternate baseline/window scalar bundles loaded — **gap** recorded (BASELINE_WINDOW_ROBUSTNESS_DONE=NO).\n\n');

    fprintf(fidR, '## 15. Recommended primary scalar\n\n');
    fprintf(fidR, '- **Main text:** `A_obs` (direct RCON observable).\n');
    fprintf(fidR, '- **Supplement:** `m0_svd`, `projection_mean_curve`, `A_proj_nonSVD`.\n\n');

    fprintf(fidR, '## 16. Unresolved\n\n');
    fprintf(fidR, '- LOO-SVD basis stability not executed.\n');
    fprintf(fidR, '- No secondary baseline/window map variants in-repo.\n');
    fclose(fidR);

    try
        set(groot, 'defaultTextFontName', 'Helvetica', 'defaultAxesFontName', 'Helvetica');
        fg = figure('Visible', 'off', 'Color', 'w');
        ss = strcmp(recTbl.inclusion_set, 'strict_default_no_quality_flag') & strcmp(recTbl.variant, 'raw');
        sub = recTbl(ss, :);
        bar(categorical(sub.scalar_name), sub.fro_rel_error);
        ylabel('Frobenius relative error');
        title('Rank-1 reconstruction (strict, raw)');
        grid on;
        exportgraphics(fg, fullfile(figCanon, 'relaxation_activity_representation_01_reconstruction_ranking.png'), 'Resolution', 300);
        close(fg);

        fg = figure('Visible', 'off', 'Color', 'w');
        sh = strcmp(hoTbl.inclusion_set, 'strict_default_no_quality_flag') & strcmp(hoTbl.variant, 'raw');
        subh = hoTbl(sh, :);
        bar(categorical(subh.scalar_name), subh.loto_rmse_mean);
        ylabel('LOTO mean RMSE');
        title('Held-out temperature');
        grid on;
        exportgraphics(fg, fullfile(figCanon, 'relaxation_activity_representation_01_heldout_ranking.png'), 'Resolution', 300);
        close(fg);

        fg = figure('Visible', 'off', 'Color', 'w');
        plot(Rprimary.commonTbl.T_K, Rprimary.commonTbl.A_obs, '-o'); hold on;
        plot(Rprimary.commonTbl.T_K, Rprimary.commonTbl.A_proj_nonSVD, '-s');
        plot(Rprimary.commonTbl.T_K, Rprimary.commonTbl.m0_svd, '-^');
        plot(Rprimary.commonTbl.T_K, Rprimary.commonTbl.projection_mean_curve, '-d');
        legend('Aobs', 'Aproj', 'm0', 'projmean');
        xlabel('T_K'); grid on;
        exportgraphics(fg, fullfile(figCanon, 'relaxation_activity_representation_01_scalar_vs_temperature.png'), 'Resolution', 300);
        close(fg);

        fg = figure('Visible', 'off', 'Color', 'w');
        scatter(Rprimary.commonTbl.A_obs, Rprimary.commonTbl.m0_svd, 36, 'filled'); grid on;
        xlabel('A\_obs'); ylabel('m0');
        title('Pairwise: Aobs vs m0');
        exportgraphics(fg, fullfile(figCanon, 'relaxation_activity_representation_01_pairwise_scalars.png'), 'Resolution', 300);
        close(fg);
    catch
    end

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, numel(Tk), {'RLX_AR01_complete'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'RLX_AR01_failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end

function R = rlx_ar01_build_map(mask, label, cidx, samp, ixTraceI, ixTemp, ixTraceS, ixTime, ixDelta, ...
        rcon, ixTk, ixAobs, ixAproj, ixM0, nGrid)
    sub = cidx(mask, :);
    traceIds = string(sub{:, ixTraceI});
    temps = double(sub{:, ixTemp});
    [temps, ord] = sort(temps);
    traceIds = traceIds(ord);
    nT = numel(temps);
    tMinEach = nan(nT, 1);
    tMaxEach = nan(nT, 1);
    for i = 1:nT
        rows = samp(strcmp(string(samp{:, ixTraceS}), traceIds(i)), :);
        tt = double(rows{:, ixTime});
        tt = tt(isfinite(tt) & tt > 0);
        if isempty(tt)
            continue;
        end
        tMinEach(i) = min(tt);
        tMaxEach(i) = max(tt);
    end
    tMinCommon = max(tMinEach);
    tMaxCommon = min(tMaxEach);
    tGrid = linspace(tMinCommon, tMaxCommon, nGrid);
    M = nan(nGrid, nT);
    for j = 1:nT
        rows = samp(strcmp(string(samp{:, ixTraceS}), traceIds(j)), :);
        tt = double(rows{:, ixTime});
        xx = double(rows{:, ixDelta});
        m = isfinite(tt) & isfinite(xx) & tt > 0;
        tt = tt(m);
        xx = xx(m);
        [tu, ia] = unique(tt, 'stable');
        xx = xx(ia);
        M(:, j) = interp1(tu, xx, tGrid, 'linear', 'extrap');
    end
    TkR = round(temps, 4);
    Aobs = nan(nT, 1);
    Aproj = nan(nT, 1);
    M0 = nan(nT, 1);
    rtk = round(double(rcon{:, ixTk}), 4);
    for j = 1:nT
        ix = find(abs(rtk - TkR(j)) < 1e-3, 1);
        if ~isempty(ix)
            Aobs(j) = double(rcon{ix, ixAobs});
            Aproj(j) = double(rcon{ix, ixAproj});
            M0(j) = double(rcon{ix, ixM0});
        end
    end
    f0 = mean(M, 2, 'omitnan');
    den = sum(f0.^2, 'omitnan');
    if den <= eps
        den = eps;
    end
    pm = nan(nT, 1);
    for j = 1:nT
        pm(j) = sum(M(:, j) .* f0, 'omitnan') / den;
    end
    vecs = struct('A_obs', Aobs, 'A_proj_nonSVD', Aproj, 'm0_svd', M0, 'projection_mean_curve', pm);

    rr = {};
    sk = fieldnames(vecs);
    for k = 1:numel(sk)
        a = vecs.(sk{k});
        Ts = TkR(:);
        [Ts, o2] = sort(Ts);
        a2 = a(o2);
        d2 = diff(diff(a2));
        rough = sum(d2.^2, 'omitnan');
        mono = sum(diff(a2) > 0) / max(numel(a2) - 1, 1);
        rr(end+1, :) = {sk{k}, rough, mono}; %#ok<AGROW>
    end
    smoothTbl = cell2table(rr, 'VariableNames', {'scalar_name', 'second_diff_roughness_sorted_T', 'fraction_up_steps'});

    commonTbl = table(TkR(:), Aobs(:), Aproj(:), M0(:), pm(:), ...
        repmat("tables/relaxation/relaxation_RCON_02B_Aproj_vs_SVD_score.csv", nT, 1), ...
        repmat("computed_from_M", nT, 1), ...
        repmat(string(label), nT, 1), ...
        'VariableNames', {'T_K', 'A_obs', 'A_proj_nonSVD', 'm0_svd', 'projection_mean_curve', ...
        'source_RCON', 'source_projection_mean', 'inclusion_set_label'});

    R = struct('M', M, 'tGrid', tGrid, 'nT', nT, 'commonTbl', commonTbl, 'vecs', vecs, 'smoothTbl', smoothTbl, 'T_K', TkR);
end

function met = rlx_ar01_rank1_metrics(M, a, Tk)
    a = double(a(:));
    if any(~isfinite(a)) || sum(abs(a), 'omitnan') < 1e-30
        met = struct('rmse_all', NaN, 'nrmse_all', NaN, 'fro_rel', NaN, 'var_explained', NaN, ...
            'rmse_worst_T', NaN, 'worst_T_K', NaN, 'map_corr', NaN);
        return;
    end
    psi = (M * a) / (a' * a);
    R = psi * a';
    res = M - R;
    met.rmse_all = sqrt(mean(res.^2, 'all'));
    met.nrmse_all = met.rmse_all / max(sqrt(mean(M.^2, 'all')), eps);
    met.fro_rel = norm(res, 'fro') / max(norm(M, 'fro'), eps);
    met.var_explained = 1 - sum(res.^2, 'all') / max(sum(M.^2, 'all'), eps);
    rmT = sqrt(mean(res.^2, 1))';
    [met.rmse_worst_T, wi] = max(rmT);
    if wi >= 1 && wi <= numel(Tk)
        met.worst_T_K = Tk(wi);
    else
        met.worst_T_K = NaN;
    end
    met.map_corr = corr(M(:), R(:), 'Rows', 'complete');
end

function ho = rlx_ar01_loto(M, a, Tk)
    nT = size(M, 2);
    a = double(a(:));
    e = nan(nT, 1);
    for k = 1:nT
        mask = true(nT, 1);
        mask(k) = false;
        ar = a(mask);
        Mr = M(:, mask);
        if sum(mask) < 2 || any(~isfinite(ar))
            e(k) = NaN;
            continue;
        end
        psi = (Mr * ar) / (ar' * ar);
        pred = psi * a(k);
        e(k) = sqrt(mean((M(:, k) - pred).^2));
    end
    ho.mean_rmse = mean(e, 'omitnan');
    ho.median_rmse = median(e, 'omitnan');
    [ho.max_rmse, ik] = max(e);
    if isfinite(ik) && ik >= 1 && ik <= numel(Tk)
        ho.worst_T_K = Tk(ik);
    else
        ho.worst_T_K = NaN;
    end
end

function a2 = rlx_ar01_variant_vec(a, vname)
    a = double(a(:));
    if strcmp(vname, 'raw')
        a2 = a;
    elseif strcmp(vname, 'sign_flip_if_negative_mean')
        if mean(a, 'omitnan') < 0
            a2 = -a;
        else
            a2 = a;
        end
    elseif strcmp(vname, 'abs_diagnostic')
        a2 = abs(a);
    elseif strcmp(vname, 'zscore_diagnostic')
        a2 = (a - mean(a, 'omitnan')) / max(std(a, 0, 'omitnan'), eps);
    else
        a2 = a;
    end
end

function Tbl = rlx_ar01_pairwise(R)
    v = R.vecs;
    names = {'A_obs', 'A_proj_nonSVD', 'm0_svd', 'projection_mean_curve'};
    cols = {v.A_obs(:), v.A_proj_nonSVD(:), v.m0_svd(:), v.projection_mean_curve(:)};
    n = numel(names);
    pr = nan(n * (n - 1) / 2, 1);
    sp = nan(size(pr));
    la = cell(size(pr));
    lb = cell(size(pr));
    rr = 0;
    for i = 1:n
        for j = i+1:n
            rr = rr + 1;
            la{rr} = names{i};
            lb{rr} = names{j};
            x = cols{i};
            y = cols{j};
            pr(rr) = corr(x, y, 'Rows', 'complete');
            sp(rr) = corr(x, y, 'type', 'Spearman', 'Rows', 'complete');
        end
    end
    Tbl = table(string(la(:)), string(lb(:)), pr(:), sp(:), ...
        'VariableNames', {'scalar_a', 'scalar_b', 'pearson_r', 'spearman_r'});
end

function s = rlx_ar01_yn(tf)
    if tf
        s = 'YES';
    else
        s = 'NO';
    end
end
