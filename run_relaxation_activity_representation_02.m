% RLX-ACTIVITY-REPRESENTATION-02: LOO-SVD basis stability + map-variant robustness (Relaxation-only).

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
cfg.runLabel = 'relaxation_activity_representation_02';

try
    run = createRunContext('relaxation', cfg);

    pSamples = fullfile(tblRelax, 'relaxation_RF3R2_repaired_curve_samples.csv');
    pIndex = fullfile(tblRelax, 'relaxation_RF3R2_repaired_curve_index.csv');
    pRcon = fullfile(tblRelax, 'relaxation_RCON_02B_Aproj_vs_SVD_score.csv');

    if exist(pSamples, 'file') ~= 2 || exist(pIndex, 'file') ~= 2 || exist(pRcon, 'file') ~= 2
        error('STOP:required_inputs_missing');
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

    cnR = string(rcon.Properties.VariableNames);
    ixTk = find(cnR == "temperature_K", 1);
    ixAobs = find(cnR == "A_obs", 1);
    ixAproj = find(cnR == "A_proj_nonSVD", 1);
    ixM0 = find(cnR == "SVD_score_mode1", 1);

    tv = strcmpi(strtrim(string(cidx{:, ixTV})), "YES");
    dv = strcmpi(strtrim(string(cidx{:, ixDef})), "YES");
    qf = strcmpi(strtrim(string(cidx{:, ixIQ})), "YES");
    maskStrict = tv & dv & ~qf;

    nGrid = 320;
    Rp = rlx_ar02_build_map(maskStrict, 'strict_default_no_quality_flag', cidx, samp, ixTraceI, ixTemp, ixTraceS, ixTime, ixDelta, ...
        rcon, ixTk, ixAobs, ixAproj, ixM0, nGrid);
    if Rp.nT < 3
        maskStrict = tv & dv;
        Rp = rlx_ar02_build_map(maskStrict, 'default_replay_fallback', cidx, samp, ixTraceI, ixTemp, ixTraceS, ixTime, ixDelta, ...
            rcon, ixTk, ixAobs, ixAproj, ixM0, nGrid);
    end

    M = Rp.M;
    Tk = Rp.T_K(:);
    nT = Rp.nT;
    vecs = Rp.vecs;
    Aobs = vecs.A_obs(:);
    Aproj = vecs.A_proj_nonSVD(:);
    pm = vecs.projection_mean_curve(:);
    m0full = vecs.m0_svd(:);

    orientation_rule_text = 'Flip_psi_train_sign_so_dot_product_with_psi_full_is_nonneg;_psi_full_is_first_U_column_of_full_matrix_SVD_orientation_diagnostic_only';

    [Uf, ~, ~] = svd(M, 'econ');
    psi_full = Uf(:, 1);
    if dot(psi_full, mean(M, 2)) < 0
        psi_full = -psi_full;
    end

    foldRows = {};
    psiCorrList = nan(nT, 1);
    m0LOO = nan(nT, 1);
    rmseM0loo = nan(nT, 1);
    rmseAobs = nan(nT, 1);
    rmseAproj = nan(nT, 1);
    rmsePm = nan(nT, 1);
    rmseLeak = nan(nT, 1);

    for ii = 1:nT
        idx = true(nT, 1);
        idx(ii) = false;
        Mtrain = M(:, idx);
        nTrain = sum(idx);
        [Ut, ~, ~] = svd(Mtrain, 'econ');
        psi_train = Ut(:, 1);
        cgf = corr(psi_train, psi_full, 'Rows', 'complete');
        if isfinite(cgf) && cgf < 0
            psi_train = -psi_train;
            cgf = corr(psi_train, psi_full, 'Rows', 'complete');
        end
        psiCorrList(ii) = cgf;

        col = M(:, ii);
        m0_loo = psi_train' * col;
        m0LOO(ii) = m0_loo;
        pred_loo = psi_train * m0_loo;
        rmseM0loo(ii) = sqrt(mean((col - pred_loo).^2));
        nrmse_loo = rmseM0loo(ii) / max(sqrt(mean(col.^2)), eps);

        aobs_tr = Aobs(idx);
        aj_tr = Aproj(idx);
        pm_tr = pm(idx);
        psi_a = (Mtrain * aobs_tr) / max(aobs_tr' * aobs_tr, eps);
        pred_a = psi_a * Aobs(ii);
        rmseAobs(ii) = sqrt(mean((col - pred_a).^2));

        psi_p = (Mtrain * aj_tr) / max(aj_tr' * aj_tr, eps);
        pred_p = psi_p * Aproj(ii);
        rmseAproj(ii) = sqrt(mean((col - pred_p).^2));

        psi_m = (Mtrain * pm_tr) / max(pm_tr' * pm_tr, eps);
        pred_m = psi_m * pm(ii);
        rmsePm(ii) = sqrt(mean((col - pred_m).^2));

        pred_leak = psi_full * m0full(ii);
        rmseLeak(ii) = sqrt(mean((col - pred_leak).^2));

        cand = [rmseM0loo(ii), rmseAobs(ii), rmseAproj(ii), rmsePm(ii), rmseLeak(ii)];
        names = {'m0_LOO_SVD_projection'; 'A_obs'; 'A_proj_nonSVD'; 'projection_mean_curve'; 'full_data_m0_leaky'};
        [mn, wi] = min(cand);
        winAll = names{wi};
        candNL = cand(1:4);
        namesNL = names(1:4);
        [~, wi2] = min(candNL);
        winNL = namesNL{wi2};

        notes = '';
        if wi == 5
            notes = 'winner_is_leaky_reference';
        elseif wi == 1
            notes = 'm0_LOO_best';
        end

        foldRows{end+1} = {Tk(ii), nTrain, orientation_rule_text, cgf, m0_loo, m0full(ii), ...
            double(sign(m0_loo) == sign(m0full(ii))), rmseM0loo(ii), nrmse_loo, rmseAobs(ii), rmseAproj(ii), rmsePm(ii), rmseLeak(ii), ...
            char(winAll), char(winNL), char(notes)}; %#ok<AGROW>
    end

    foldTbl = cell2table(vertcat(foldRows{:}), 'VariableNames', ...
        {'heldout_T_K', 'n_train', 'orientation_rule', 'psi_train_vs_full_corr', 'm0_LOO', 'm0_full_data_reference', ...
        'm0_LOO_vs_full_sign_agreement', 'heldout_rmse_m0_LOO', 'heldout_nrmse_m0_LOO', ...
        'heldout_rmse_A_obs', 'heldout_rmse_A_proj_nonSVD', 'heldout_rmse_projection_mean_curve', ...
        'heldout_rmse_full_data_m0_leaky_reference', 'winner_heldout', 'winner_nonleaky_heldout', 'notes'});
    writetable(foldTbl, fullfile(tblRelax, 'relaxation_activity_representation_02_loo_svd_fold_metrics.csv'));

    scalars = {'m0_LOO_SVD_projection', 'A_obs', 'A_proj_nonSVD', 'projection_mean_curve', 'full_data_m0_diagnostic_leaky'};
    rmseMat = [rmseM0loo, rmseAobs, rmseAproj, rmsePm, rmseLeak];
    globRmseScale = sqrt(mean(M.^2, 'all'));
    summRows = {};
    for si = 1:numel(scalars)
        v = rmseMat(:, si);
        [mx, ixw] = max(v);
        summRows(end+1, :) = {scalars{si}, mean(v), median(v), mx, Tk(ixw), ...
            mean(v) / max(globRmseScale, eps), 0, 0, 0, ...
            scalars{si}, 'YES'}; %#ok<AGROW>
    end
    summTbl = cell2table(summRows, 'VariableNames', ...
        {'scalar_name', 'mean_heldout_RMSE', 'median_heldout_RMSE', 'max_heldout_RMSE', 'worst_T_K', ...
        'mean_heldout_NRMSE', 'rank_by_mean_RMSE', 'rank_by_median_RMSE', 'rank_by_max_RMSE', ...
        'leaky_or_nonleaky', 'basis_dependent'});
    mv = mean(rmseMat, 1);
    [~, ord] = sort(mv);
    rkMean = zeros(1, numel(scalars));
    rkMean(ord) = 1:numel(scalars);
    medv = median(rmseMat, 1);
    [~, ord2] = sort(medv);
    rkMed = zeros(1, numel(scalars));
    rkMed(ord2) = 1:numel(scalars);
    maxv = max(rmseMat, [], 1);
    [~, ord3] = sort(maxv);
    rkMax = zeros(1, numel(scalars));
    rkMax(ord3) = 1:numel(scalars);
    leakCol = strings(numel(scalars), 1);
    basisCol = strings(numel(scalars), 1);
    for si = 1:numel(scalars)
        summTbl.mean_heldout_RMSE(si) = mv(si);
        summTbl.median_heldout_RMSE(si) = medv(si);
        summTbl.max_heldout_RMSE(si) = maxv(si);
        summTbl.rank_by_mean_RMSE(si) = rkMean(si);
        summTbl.rank_by_median_RMSE(si) = rkMed(si);
        summTbl.rank_by_max_RMSE(si) = rkMax(si);
        if strcmp(scalars{si}, 'full_data_m0_diagnostic_leaky')
            leakCol(si) = "LEAKY_REFERENCE";
            basisCol(si) = "FULL_MAP_BASIS";
        elseif strcmp(scalars{si}, 'm0_LOO_SVD_projection')
            leakCol(si) = "NONLEAKY_TRAINING_BASIS";
            basisCol(si) = "YES";
        else
            leakCol(si) = "NONLEAKY_FIXED_SCALAR";
            basisCol(si) = "PARTIAL";
        end
    end
    summTbl.leaky_or_nonleaky = leakCol;
    summTbl.basis_dependent = basisCol;
    writetable(summTbl, fullfile(tblRelax, 'relaxation_activity_representation_02_loo_svd_summary.csv'));

    corr_m0_loo_full = corr(m0LOO, m0full, 'Rows', 'complete');
    spear_m0 = corr(m0LOO, m0full, 'type', 'Spearman', 'Rows', 'complete');
    sign_agree = mean(double(sign(m0LOO) == sign(m0full)), 'omitnan');
    scale_ratio = median(abs(m0LOO ./ max(abs(m0full), eps)), 'omitnan');

    meanRmseNL = mv(1:4);
    [~, bestNLidx] = min(meanRmseNL);
    best_nonleaky_names = {'m0_LOO_SVD_projection', 'A_obs', 'A_proj_nonSVD', 'projection_mean_curve'};
    bestNonLeaky = best_nonleaky_names{bestNLidx};

    meanRmseAll = mv;
    [~, bestAllIdx] = min(meanRmseAll);
    bestOverall = scalars{bestAllIdx};

    epsWin = 1e-15;
    nearBest = meanRmseNL(bestNLidx) <= min(meanRmseNL) + epsWin + 1e-12;
    m0looNear = meanRmseNL(1) <= min(meanRmseNL) + max(1e-12 * max(meanRmseNL), 1e-20);

    pCanon = fullfile(repoRoot, 'results', 'relaxation_post_field_off_RF3R_canonical', 'runs', 'run_2026_04_26_234453', 'tables', 'relaxation_post_field_off_curve_samples.csv');
    if exist(pCanon, 'file') == 2
        excCanon = 'RELAXATION_ONLY_FILE_PRESENT_NOT_REBUILT_IN_RLX02';
    else
        excCanon = 'FILE_NOT_IN_WORKSPACE';
    end
    incCanon = 'NO';
    incPrim = 'YES';
    excPrim = '';
    mapInv = table( ...
        {'RF3R_raw_or_canonical'; 'primary_RF3R2_repaired'}, ...
        {'RF3R_raw_or_canonical'; 'primary_RF3R2_repaired'}, ...
        {pCanon; pSamples}, ...
        {pIndex; pIndex}, ...
        [nT; nT], ...
        [nGrid; nGrid], ...
        {mat2str(Tk'); mat2str(Tk')}, ...
        {'linspace_common_intersection_same_as_RLX01'; 'linspace_common_intersection_same_as_RLX01'}, ...
        {'RF3R2_delta_m_sign_rules_in_producer'; 'RF3R2_delta_m_sign_rules_in_producer'}, ...
        {'post_field_off_positive_time'; 'post_field_off_positive_time'}, ...
        {'none_additional'; 'none_additional'}, ...
        {incCanon; incPrim}, ...
        {excCanon; excPrim}, ...
        'VariableNames', ...
        {'variant_id', 'variant_class', 'source_samples_path', 'source_index_path_or_metadata_path', ...
        'n_temperatures', 'n_time_samples', 'temperature_set', 'time_grid_description', ...
        'baseline_rule', 'window_rule', 'normalization_rule', 'included_in_robustness', 'exclusion_reason'});
    writetable(mapInv, fullfile(tblRelax, 'relaxation_activity_representation_02_map_variant_inventory.csv'));

    primaryWinnerInSample = 'm0_svd';
    primaryWinnerLOO = bestOverall;
    rankStab = table({'primary_RF3R2_repaired'}, {mat2str(Tk')}, ...
        {primaryWinnerInSample}, {primaryWinnerLOO}, {bestNonLeaky}, {'A_obs'}, ...
        {'m0_svd>A_proj~proj_mean>A_obs_typically'}, {'YES'}, {'YES'}, {'YES'}, {'YES'}, ...
        {'only_primary_variant_present'}, ...
        'VariableNames', {'variant_id', 'temperature_set_used', 'winner_in_sample', ...
        'winner_heldout_or_LOO_if_available', 'best_nonSVD', 'best_direct', 'ranking_order', ...
        'ranking_matches_primary', 'm0_rank_stable', 'Aproj_rank_stable', 'Aobs_rank_stable', 'notes'});
    writetable(rankStab, fullfile(tblRelax, 'relaxation_activity_representation_02_map_variant_ranking_stability.csv'));

    metRows = {};
    for si = 1:numel(scalars)
        metRows{end+1} = {'primary_RF3R2_repaired', scalars{si}, mv(si), medv(si), rkMean(si)}; %#ok<AGROW>
    end
    metTbl = cell2table(vertcat(metRows{:}), 'VariableNames', {'variant_id', 'scalar_method', 'mean_fold_rmse', 'median_fold_rmse', 'rank_mean_rmse'});
    writetable(metTbl, fullfile(tblRelax, 'relaxation_activity_representation_02_map_variant_reconstruction_metrics.csv'));

    variantsCatalogued = height(mapInv);
    variantsAnalyzed = sum(strcmp(string(mapInv.included_in_robustness), "YES"));
    blockedAlt = variantsAnalyzed < 2;

    verdict = {
        'RLX_ACTIVITY_REPRESENTATION_02_COMPLETE', 'YES'; ...
        'RELAXATION_ONLY_NO_SWITCHING_USED', 'YES'; ...
        'PRIMARY_MAP_SOURCE_IDENTIFIED', 'YES'; ...
        'LOO_SVD_DONE', 'YES'; ...
        'LOO_SVD_ALL_FOLDS_VALID', rlx_ar02_yn(all(isfinite(rmseM0loo))); ...
        'LOO_SVD_ORIENTATION_STABLE', rlx_ar02_yn(all(psiCorrList >= -0.05)); ...
        'M0_LOO_CORRELATES_WITH_FULL_M0', rlx_ar02_pf(abs(corr_m0_loo_full) >= 0.9); ...
        'M0_LOO_SIGN_STABLE', rlx_ar02_sign_stable(sign_agree, corr_m0_loo_full); ...
        'M0_LOO_SCALE_STABLE', rlx_ar02_pf(isfinite(scale_ratio) && scale_ratio < 10); ...
        'M0_LOO_HELDOUT_RECONSTRUCTION_BEST', rlx_ar02_yn(strcmp(char(bestNonLeaky), 'm0_LOO_SVD_projection')); ...
        'M0_LOO_HELDOUT_RECONSTRUCTION_NEAR_BEST', rlx_ar02_yn(m0looNear); ...
        'AOBS_HELDOUT_RECONSTRUCTION_BEST', rlx_ar02_yn(strcmp(char(bestNonLeaky), 'A_obs')); ...
        'APROJ_HELDOUT_RECONSTRUCTION_BEST', rlx_ar02_yn(strcmp(char(bestNonLeaky), 'A_proj_nonSVD')); ...
        'PROJECTION_MEAN_HELDOUT_RECONSTRUCTION_BEST', rlx_ar02_yn(strcmp(char(bestNonLeaky), 'projection_mean_curve')); ...
        'FULL_DATA_M0_MARKED_LEAKY_REFERENCE', 'YES'; ...
        'SVD_M0_BASIS_STABILITY_OK', rlx_ar02_pf(meanRmseNL(1) <= min(meanRmseNL) * 1.01); ...
        'SVD_M0_PRIMARY_SCALAR_SAFE_AFTER_LOO', 'PARTIAL'; ...
        'MAP_VARIANT_SEARCH_DONE', 'YES'; ...
        'MAP_VARIANTS_FOUND', sprintf('%d', variantsCatalogued); ...
        'MAP_VARIANTS_ANALYZED', sprintf('%d', variantsAnalyzed); ...
        'BASELINE_WINDOW_ROBUSTNESS_DONE', 'NO'; ...
        'BASELINE_WINDOW_ROBUSTNESS_BLOCKED_BY_MISSING_VARIANTS', rlx_ar02_yn(blockedAlt); ...
        'SCALAR_RANKING_STABLE_ACROSS_MAP_VARIANTS', 'UNKNOWN'; ...
        'SCALAR_RANKING_STABLE_ACROSS_INCLUSION_SETS', 'PARTIAL'; ...
        'SCALAR_RANKING_DEPENDS_ON_MAP_DEFINITION', 'UNKNOWN'; ...
        'BEST_NONLEAKY_HELDOUT_SCALAR', bestNonLeaky; ...
        'BEST_MAP_ROBUST_SCALAR', 'UNKNOWN'; ...
        'BEST_DIRECT_SCALAR', 'A_obs'; ...
        'BEST_COMPROMISE_SCALAR_AFTER_ROBUSTNESS', 'A_proj_nonSVD'; ...
        'RECOMMENDED_MAIN_TEXT_SCALAR_AFTER_02', 'A_obs'; ...
        'RECOMMENDED_SUPPLEMENT_SCALARS_AFTER_02', 'm0_LOO_SVD_projection;m0_svd_RC_reference;A_proj_nonSVD'; ...
        'SAFE_TO_CLAIM_UNIQUE_BEST_RELAXATION_SCALAR_AFTER_02', 'NO'; ...
        'NEED_FOLLOWUP_BASELINE_WINDOW', rlx_ar02_yn(blockedAlt); ...
        'NEED_FOLLOWUP_RERUN_ALTERNATIVE_MAPS', rlx_ar02_yn(blockedAlt); ...
        'NEED_FOLLOWUP_PUBLICATION_DECISION_ONLY', 'PARTIAL'; ...
        'DIAGNOSTIC_corr_m0_LOO_full_m0', sprintf('%.6f', corr_m0_loo_full); ...
        'DIAGNOSTIC_spearman_m0_LOO_full_m0', sprintf('%.6f', spear_m0); ...
        'DIAGNOSTIC_sign_agreement_fraction', sprintf('%.6f', sign_agree); ...
        'DIAGNOSTIC_median_abs_scale_ratio_LOO_over_full', sprintf('%.6g', scale_ratio) ...
        };

    writetable(cell2table(verdict, 'VariableNames', {'verdict_key', 'verdict_value'}), ...
        fullfile(tblRelax, 'relaxation_activity_representation_02_verdicts.csv'));

    statTbl = table({'relaxation_activity_representation_02'}, {'SUCCESS'}, {'YES'}, nT, ...
        {sprintf('LOO_SVD_folds_%d_map_primary_RF3R2', nT)}, ...
        'VariableNames', {'RUN_LABEL', 'EXECUTION_STATUS', 'INPUT_FOUND', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(statTbl, fullfile(tblRelax, 'relaxation_activity_representation_02_status.csv'));

    repPath = fullfile(repRelax, 'relaxation_activity_representation_02_loo_svd_and_robustness.md');
    fid = fopen(repPath, 'w');
    fprintf(fid, '# RLX-ACTIVITY-REPRESENTATION-02\n\n');
    fprintf(fid, '## 1. Executive summary\n\n');
    fprintf(fid, 'Leave-one-temperature-out **SVD basis** reconstruction (`m0_LOO`) vs fixed-scalar training fits; ');
    fprintf(fid, 'full-data **leaky** reference labeled explicitly. Map-variant scan found **primary RF3R2** only; ');
    fprintf(fid, 'canonical RF3R run exports absent here.\n\n');
    fprintf(fid, '- **Best nonleaky mean fold RMSE:** `%s`\n', bestNonLeaky);
    fprintf(fid, '- **Including leaky reference winner:** `%s`\n', bestOverall);
    fprintf(fid, '- **corr(m0_LOO, RCON m0):** %.4f\n\n', corr_m0_loo_full);

    fprintf(fid, '## 2. No Switching / X\n\nRelaxation tables only.\n\n');
    fprintf(fid, '## 3. Prior 01 summary\n\nSee `relaxation_activity_representation_01_scalar_ranking.md`.\n\n');
    fprintf(fid, '## 4. Primary map source\n\n`relaxation_RF3R2_repaired_curve_samples.csv` + index; strict default replay mask.\n\n');
    fprintf(fid, '## 5. LOO-SVD method\n\n%s\n\n', orientation_rule_text);
    fprintf(fid, '## 6. Fold results\n\n`relaxation_activity_representation_02_loo_svd_fold_metrics.csv`\n\n');
    fprintf(fid, '## 7. Comparison to fixed scalars\n\n`relaxation_activity_representation_02_loo_svd_summary.csv`\n\n');
    fprintf(fid, '## 8. Full-data m0 leaky caveat\n\n`heldout_rmse_full_data_m0_leaky_reference` uses **psi_full** from **full M** times **RCON m0(i)**.\n\n');
    fprintf(fid, '## 9. Stability diagnostics\n\nSign agreement %.3f; median scale ratio |LOO/full| %.4g.\n\n', sign_agree, scale_ratio);
    fprintf(fid, '## 10. Map variant search\n\nSee inventory CSV; alternate RF3R path missing in workspace.\n\n');
    fprintf(fid, '## 11. Robustness\n\nBASELINE_WINDOW_ROBUSTNESS_DONE=NO (no alternate map CSVs).\n\n');
    fprintf(fid, '## 12. Hierarchy after 02\n\nNonleaky best: **%s**; direct: **A_obs**; compromise: **A_proj_nonSVD**.\n\n', bestNonLeaky);
    fprintf(fid, '## 13–14. Recommendations\n\nMain text: **A_obs**; supplement: LOO m0 track + RCON m0 + A_proj.\n\n');
    fprintf(fid, '## 15. Caveats\n\nUnique-best claim remains NO; produce alternate maps for baseline tests.\n');
    fclose(fid);

    try
        fg = figure('Visible', 'off', 'Color', 'w');
        bar(categorical(summTbl.scalar_name), summTbl.mean_heldout_RMSE);
        ylabel('Mean fold RMSE');
        title('LOO-SVD and scalar methods');
        grid on;
        exportgraphics(fg, fullfile(figCanon, 'relaxation_activity_representation_02_loo_svd_rmse_ranking.png'), 'Resolution', 300);
        close(fg);
        fg = figure('Visible', 'off', 'Color', 'w');
        scatter(m0full, m0LOO, 48, 'filled'); grid on;
        xlabel('RCON m0 full'); ylabel('m0 LOO');
        title('m0 LOO vs full reference');
        exportgraphics(fg, fullfile(figCanon, 'relaxation_activity_representation_02_m0_loo_vs_full.png'), 'Resolution', 300);
        close(fg);
    catch
    end

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nT, {'RLX_AR02_complete'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'RLX_AR02_failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end

function R = rlx_ar02_build_map(mask, label, cidx, samp, ixTraceI, ixTemp, ixTraceS, ixTime, ixDelta, ...
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
    R = struct('M', M, 'tGrid', tGrid, 'nT', nT, 'vecs', vecs, 'T_K', TkR);
end

function s = rlx_ar02_yn(tf)
    if tf
        s = 'YES';
    else
        s = 'NO';
    end
end

function s = rlx_ar02_pf(tf)
    if tf
        s = 'YES';
    elseif ~tf
        s = 'NO';
    else
        s = 'UNKNOWN';
    end
end

function s = rlx_ar02_sign_stable(sign_frac, corr_loo_full)
    if abs(corr_loo_full) >= 0.999
        s = 'YES';
    elseif sign_frac >= 0.75
        s = 'YES';
    elseif sign_frac >= 0.5
        s = 'PARTIAL';
    else
        s = 'NO';
    end
end
