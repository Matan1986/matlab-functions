% RLX-ACTIVITY-LINEAGE-06: Canonical A_T = sigma1*U(:,1) on RF3R2 (rows=T, cols=time).
% Runnable name <=63 chars (MATLAB run() limit); task token lineage_06 preserved.
% Relaxation-only. No Switching, no X, no AX/power-law fits.

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    scriptFull = mfilename('fullpath');
    scriptDir = fileparts(scriptFull);
    repoRoot = fileparts(fileparts(scriptDir));
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

tblRelax = fullfile(repoRoot, 'tables', 'relaxation');
repRelax = fullfile(repoRoot, 'reports', 'relaxation');
figCanon = fullfile(repoRoot, 'figures', 'relaxation', 'canonical');
for d = {tblRelax, repRelax, figCanon}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

cfg = struct();
cfg.runLabel = 'relaxation_AT_canon_lineage_06';

pearTh = 0.995;
nrmseAffineTh = 0.02;
nrmseScaleTh = 0.02;
nrmseSignTh = 0.02;
spearMono = 0.9;
relIdentTh = 1e-5;

outAudit = fullfile(tblRelax, 'relaxation_AT_canon_lineage_06_input_audit.csv');
outScalar = fullfile(tblRelax, 'relaxation_AT_canon_lineage_06_scalar_table.csv');
outSvd = fullfile(tblRelax, 'relaxation_AT_canon_lineage_06_svd_summary.csv');
outCmp = fullfile(tblRelax, 'relaxation_AT_canon_lineage_06_scalar_comparison.csv');
outVer = fullfile(tblRelax, 'relaxation_AT_canon_lineage_06_equivalence_verdicts.csv');
outStat = fullfile(tblRelax, 'relaxation_AT_canon_lineage_06_status.csv');
outRep = fullfile(repRelax, 'relaxation_AT_canon_lineage_06_legacy_definition_reconstruction.md');
figOverlay = fullfile(figCanon, 'relaxation_AT_canon_lineage_06_scalar_overlay.png');
figRmse = fullfile(figCanon, 'relaxation_AT_canon_lineage_06_comparison_rmse.png');

try
    run = createRunContext('relaxation', cfg);

    pSamples = fullfile(tblRelax, 'relaxation_RF3R2_repaired_curve_samples.csv');
    pIndex = fullfile(tblRelax, 'relaxation_RF3R2_repaired_curve_index.csv');
    pRcon = fullfile(tblRelax, 'relaxation_RCON_02B_Aproj_vs_SVD_score.csv');
    pRf5a = fullfile(repoRoot, 'tables', 'relaxation_RF5A_m0_svd_scores_RF3R.csv');
    pLooFold = fullfile(tblRelax, 'relaxation_activity_representation_02_loo_svd_fold_metrics.csv');

    rf3r2Found = exist(pSamples, 'file') == 2 && exist(pIndex, 'file') == 2;
    rconFound = exist(pRcon, 'file') == 2;
    rf5aFound = exist(pRf5a, 'file') == 2;
    looFound = exist(pLooFold, 'file') == 2;

    auditRows = {
        'sample_table_path', pSamples, 'RF3R2 repaired curve samples';
        'index_table_path', pIndex, 'RF3R2 index with replay flags';
        'rcon_table_path', pRcon, 'RCON scalar bundle';
        'rf5a_m0_table_path', pRf5a, 'optional RF5A m0 scores';
        'loo_fold_table_path', pLooFold, 'optional AR02 fold metrics for m0_LOO';
        'expected_rf3r2_run_context', 'rf3r2_repaired_20260427_193555_src_run_2026_04_26_234453', 'audit note only'
        };

    matrixBuilt = false;
    atComputed = false;
    sigma1 = NaN;
    r1Energy = NaN;
    nT = 0;
    nTime = 0;
    signFlipApplied = false;
    signRef = '';
    D = [];
    Tk = [];
    AT_raw = [];
    AT_orient = [];
    psi_time = [];
    m0_vec = [];
    m0loo_vec = [];
    svd1_vec = [];
    aobs_vec = [];
    aproj_vec = [];
    m0_rf5a_vec = [];
    inclLabel = '';
    usedFallbackStrict = false;
    excludedNote = '';

    if ~rf3r2Found || ~rconFound
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

    if isempty(ixTraceS) || isempty(ixTime) || isempty(ixDelta) || isempty(ixTraceI) || isempty(ixTemp)
        error('STOP:required_columns_missing_samples_or_index');
    end
    if isempty(ixTV) || isempty(ixDef) || isempty(ixIQ)
        error('STOP:index_flag_columns_missing');
    end

    cnR = string(rcon.Properties.VariableNames);
    ixTk = find(cnR == "temperature_K", 1);
    ixAobs = find(cnR == "A_obs", 1);
    ixAproj = find(cnR == "A_proj_nonSVD", 1);
    ixSvd1 = find(cnR == "SVD_score_mode1", 1);
    if isempty(ixTk) || isempty(ixAobs) || isempty(ixAproj) || isempty(ixSvd1)
        error('STOP:RCON_columns_missing');
    end

    tv = strcmpi(strtrim(string(cidx{:, ixTV})), "YES");
    dv = strcmpi(strtrim(string(cidx{:, ixDef})), "YES");
    qf = strcmpi(strtrim(string(cidx{:, ixIQ})), "YES");
    maskStrict = tv & dv & ~qf;
    maskDefault = tv & dv;

    nGrid = 320;
    Rb = rlx_l06_build_map(maskStrict, 'strict_default_no_quality_flag', cidx, samp, ixTraceI, ixTemp, ixTraceS, ixTime, ixDelta, ...
        rcon, ixTk, ixAobs, ixAproj, ixSvd1, nGrid);
    usedFallbackStrict = false;
    if Rb.nT < 3
        Rb = rlx_l06_build_map(maskDefault, 'default_replay_fallback', cidx, samp, ixTraceI, ixTemp, ixTraceS, ixTime, ixDelta, ...
            rcon, ixTk, ixAobs, ixAproj, ixSvd1, nGrid);
        usedFallbackStrict = true;
        inclLabel = 'default_replay_fallback_strict_insufficient';
    else
        inclLabel = 'strict_default_no_quality_flag';
    end

    if Rb.nT < 3
        error('STOP:insufficient_temperatures');
    end

    M = Rb.M;
    nT = Rb.nT;
    nTime = size(M, 1);
    Tk = Rb.T_K(:);
    m0_vec = Rb.m0_svd(:);
    svd1_vec = Rb.SVD_mode1(:);
    aobs_vec = Rb.A_obs(:);
    aproj_vec = Rb.A_proj(:);

    % Legacy orientation: rows = temperature, columns = time
    D = M.';
    matrixBuilt = true;

    [U, S, V] = svd(D, 'econ');
    sigma1 = S(1, 1);
    AT_raw = sigma1 * U(:, 1);
    psi_time = V(:, 1);
    froAll = sum(diag(S).^2);
    if froAll > 0
        r1Energy = (sigma1^2) / froAll;
    else
        r1Energy = NaN;
    end

    c0 = corr(AT_raw, m0_vec, 'Rows', 'complete');
    if isfinite(c0) && c0 < 0
        AT_orient = -AT_raw;
        psi_time = -psi_time;
        signFlipApplied = true;
    else
        AT_orient = AT_raw;
        signFlipApplied = false;
    end
    signRef = 'm0_svd_from_RCON_SVD_score_mode1_aligned_by_Pearson_sign';
    atComputed = true;

    m0loo_vec = nan(nT, 1);
    if looFound
        looT = readtable(pLooFold, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
        cnL = string(looT.Properties.VariableNames);
        ixHT = find(cnL == "heldout_T_K", 1);
        ixML = find(cnL == "m0_LOO", 1);
        if ~isempty(ixHT) && ~isempty(ixML)
            for jj = 1:nT
                hit = find(abs(double(looT{:, ixHT}) - Tk(jj)) < 1e-3, 1);
                if ~isempty(hit)
                    m0loo_vec(jj) = double(looT{hit, ixML});
                end
            end
        end
    end

    m0_rf5a_vec = nan(nT, 1);
    if rf5aFound
        t5 = readtable(pRf5a, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
        cn5 = string(t5.Properties.VariableNames);
        ixT5 = find(cn5 == "temperature", 1);
        ixM5 = find(cn5 == "m0_svd_score", 1);
        if ~isempty(ixT5) && ~isempty(ixM5)
            for jj = 1:nT
                hit = find(abs(double(t5{:, ixT5}) - Tk(jj)) < 1e-3, 1);
                if ~isempty(hit)
                    m0_rf5a_vec(jj) = double(t5{hit, ixM5});
                end
            end
        end
    end

    nAvail = height(cidx);
    nIncl = Rb.nT;
    subStrict = cidx(maskStrict, :);
    subIncl = cidx(Rb.index_rows_mask, :);
    TempsStrict = sort(unique(double(subStrict{:, ixTemp})));
    TempsIncl = sort(unique(double(subIncl{:, ixTemp})));
    exclSet = setdiff(TempsStrict, TempsIncl);
    if isempty(exclSet)
        excludedNote = 'none_relative_to_strict_set';
    else
        excludedNote = sprintf('count=%d_first_example=%.6g', numel(exclSet), exclSet(1));
    end

    auditRows = [auditRows; {
        'n_temperatures_available_index_rows', sprintf('%d', nAvail), 'index table rows';
        'n_temperatures_included', sprintf('%d', nIncl), inclLabel;
        'included_temperatures_csv', strjoin(arrayfun(@(x) sprintf('%.6g', x), Tk, 'UniformOutput', false), ';'), 'sorted_K';
        'excluded_temperatures_note', excludedNote, 'strict vs final inclusion';
        'inclusion_rule', 'trace_valid_for_relaxation==YES AND valid_for_default_replay==YES AND is_quality_flagged==NO; fallback default_replay if nT<3', 'matches AR01 strict default';
        'time_grid_length', sprintf('%d', nTime), 'linear_interp_points_per_trace';
        'matrix_orientation_D', 'rows_temperature_columns_time', 'D = M_transpose_AR01';
        'interpolation_method', 'linear_on_common_t_intersection_linspace', 'same as AR01 rlx_ar01_build_map';
        'nGrid_match_AR01', sprintf('%d', nGrid), '320';
        'used_strict_fallback_to_default_replay', rlx_l06_yn(usedFallbackStrict), '';
        'rf3r2_run_id_filter_applied', 'NO', 'full repaired index as published';
        'matlab_script_file', 'Relaxation ver3/diagnostics/run_relaxation_AT_canon_lineage_06.m', 'MATLAB_identifiers_limited_to_63_chars_long_name_not_runnable_via_run'
        }];

    auditTbl = cell2table(auditRows, 'VariableNames', {'key', 'value', 'notes'});
    writetable(auditTbl, outAudit);

    inclStr = repmat("INCLUDED", nT, 1);
    notesCol = repmat("", nT, 1);
    for ii = 1:nT
        if ~isnan(m0_rf5a_vec(ii))
            notesCol(ii) = strtrim(sprintf('RF5A_m0_svd_score_present'));
        else
            notesCol(ii) = "RCON_only_no_RF5A_row";
        end
    end

    scalarTbl = table(Tk(:), AT_raw(:), AT_orient(:), m0_vec(:), m0loo_vec(:), svd1_vec(:), aobs_vec(:), aproj_vec(:), inclStr(:), notesCol(:), ...
        'VariableNames', {'T_K', 'A_T_canon_raw', 'A_T_canon_oriented', 'm0_svd', 'm0_LOO_SVD_projection', ...
        'SVD_score_mode1', 'A_obs', 'A_proj_nonSVD', 'inclusion_status', 'notes'});
    writetable(scalarTbl, outScalar);

    svdRows = {
        'sigma1', sprintf('%.16g', sigma1), 'largest singular value of D';
        'rank1_energy_fraction', sprintf('%.16g', r1Energy), 'sigma1^2/sum(sigma_k^2)';
        'n_temperatures', sprintf('%d', nT), '';
        'n_time_points', sprintf('%d', nTime), '';
        'sign_reference', signRef, '';
        'sign_flip_applied', rlx_l06_yn(signFlipApplied), 'flip if corr(raw,m0_svd)<0'
        };
    svdTbl = cell2table(svdRows, 'VariableNames', {'key', 'value', 'notes'});
    writetable(svdTbl, outSvd);

    targets = {'m0_svd', 'm0_LOO_SVD_projection', 'SVD_score_mode1', 'A_obs', 'A_proj_nonSVD'};
    vecCell = {m0_vec, m0loo_vec, svd1_vec, aobs_vec, aproj_vec};
    cmpRows = cell(0, 16);
    relM0 = '';
    relLoo = '';
    relSvd = '';
    relAobs = '';
    relAproj = '';

    for ti = 1:numel(targets)
        y = vecCell{ti};
        Rm = rlx_l06_compare(AT_orient, y, Tk, pearTh, nrmseAffineTh, nrmseScaleTh, nrmseSignTh, spearMono, relIdentTh);
        cmpRows(end+1, :) = {targets{ti}, Rm.n_common, Rm.raw_pearson, Rm.raw_spearman, Rm.sign_aligned_pearson, Rm.sign_aligned_spearman, ...
            Rm.scale_c, Rm.affine_b, Rm.affine_c, Rm.nrmse_raw, Rm.nrmse_sign_aligned, Rm.nrmse_scale, Rm.nrmse_affine, Rm.largest_residual_T, ...
            Rm.relationship_class, Rm.notes}; %#ok<AGROW>
        if strcmp(targets{ti}, 'm0_svd')
            relM0 = Rm.relationship_class;
        elseif strcmp(targets{ti}, 'm0_LOO_SVD_projection')
            relLoo = Rm.relationship_class;
        elseif strcmp(targets{ti}, 'SVD_score_mode1')
            relSvd = Rm.relationship_class;
        elseif strcmp(targets{ti}, 'A_obs')
            relAobs = Rm.relationship_class;
        elseif strcmp(targets{ti}, 'A_proj_nonSVD')
            relAproj = Rm.relationship_class;
        end
    end

    cmpTbl = cell2table(cmpRows, 'VariableNames', ...
        {'target_scalar', 'n_common', 'raw_pearson', 'raw_spearman', 'sign_aligned_pearson', 'sign_aligned_spearman', ...
        'scale_c', 'affine_intercept_b', 'affine_slope_c', 'nrmse_raw', 'nrmse_sign_aligned', 'nrmse_scale', 'nrmse_affine', ...
        'largest_residual_T', 'relationship_class', 'notes'});
    writetable(cmpTbl, outCmp);

    eqM0 = rlx_l06_equiv_yesno(relM0);
    eqLoo = rlx_l06_equiv_yesno(relLoo);
    eqSvd = rlx_l06_equiv_yesno(relSvd);
    distAobs = rlx_l06_distinct_yesno(relAobs);
    distAproj = rlx_l06_distinct_yesno(relAproj);

    classOk = ~isempty(relM0) && ~strcmp(relM0, 'insufficient_overlap');
    if ~looFound || ~any(isfinite(m0loo_vec))
        classLooOk = true;
    else
        classLooOk = ~isempty(relLoo) && ~strcmp(relLoo, 'insufficient_overlap');
    end
    looOptionalOk = classLooOk;
    readyAx = atComputed && classOk && looOptionalOk;
    readyPl = atComputed && classOk && true;

    verdictRows = {
        'LEGACY_AT_DEFINITION_RECONSTRUCTED', 'YES', 'sigma1*U(:,1) from svd(D,econ) on D=M transpose', 'definition applied to RF3R2';
        'AT_CANON_EQUIVALENT_TO_M0_SVD', eqM0, relM0, '|Pearson|>=0.995 and low NRMSE per class';
        'AT_CANON_EQUIVALENT_TO_M0_LOO', eqLoo, relLoo, 'requires AR02 fold table';
        'AT_CANON_EQUIVALENT_TO_RCON_SVD_SCORE', eqSvd, relSvd, 'SVD_score_mode1 column';
        'AT_CANON_DISTINCT_FROM_AOBS', distAobs, relAobs, 'YES if not sign/scale/affine equiv';
        'AT_CANON_DISTINCT_FROM_APROJ', distAproj, relAproj, 'YES if not sign/scale/affine equiv';
        'READY_FOR_AX_REINTERPRETATION', rlx_l06_yn(readyAx), 'A_T computed and m0 class clear', 'no AX run here';
        'READY_FOR_POWERLAW_RETEST', rlx_l06_yn(readyPl), 'canon exists; m0 relation classified', 'no power-law run here';
        'EXACT_OLD_AT_RECOVERED', 'NO', 'no historical temperature_observables.csv', 'LINEAGE-05'
        };
    verTbl = cell2table(verdictRows, 'VariableNames', {'verdict_key', 'value', 'evidence', 'notes'});
    writetable(verTbl, outVer);

    statRows = {
        'TASK_COMPLETED', 'YES';
        'RELAXATION_MODULE_ONLY', 'YES';
        'SWITCHING_USED', 'NO';
        'X_USED', 'NO';
        'AX_FIT_RUN', 'NO';
        'POWERLAW_FIT_RUN', 'NO';
        'CROSS_MODULE_CLAIM_CREATED', 'NO';
        'RF3R2_INPUTS_FOUND', rlx_l06_yn(rf3r2Found);
        'RF3R2_MATRIX_BUILT', rlx_l06_yn(matrixBuilt);
        'LEGACY_AT_DEFINITION_RECONSTRUCTED', 'YES';
        'A_T_CANON_COMPUTED', rlx_l06_yn(atComputed);
        'CURRENT_M0_SVD_FOUND', rlx_l06_yn(rconFound);
        'CURRENT_M0_LOO_FOUND', rlx_l06_yn(looFound && any(isfinite(m0loo_vec)));
        'RCON_SVD_SCORE_FOUND', rlx_l06_yn(rconFound);
        'AOBS_FOUND', rlx_l06_yn(rconFound);
        'APROJ_FOUND', rlx_l06_yn(rconFound);
        'AT_CANON_EQUIVALENT_TO_M0_SVD', eqM0;
        'AT_CANON_EQUIVALENT_TO_M0_LOO', eqLoo;
        'AT_CANON_EQUIVALENT_TO_RCON_SVD_SCORE', eqSvd;
        'AT_CANON_DISTINCT_FROM_AOBS', distAobs;
        'AT_CANON_DISTINCT_FROM_APROJ', distAproj;
        'READY_FOR_AX_REINTERPRETATION', rlx_l06_yn(readyAx);
        'READY_FOR_POWERLAW_RETEST', rlx_l06_yn(readyPl);
        'EXACT_OLD_AT_RECOVERED', 'NO'
        };
    statTbl = cell2table(statRows, 'VariableNames', {'key', 'value'});
    writetable(statTbl, outStat);

    fidR = fopen(outRep, 'w');
    if fidR < 0
        error('STOP:report_open_failed');
    end
    fprintf(fidR, '# RLX-ACTIVITY-LINEAGE-06: Legacy A_T definition on RF3R2\n\n');
    fprintf(fidR, '## 1. Purpose and scope\n\n');
    fprintf(fidR, 'Reconstruct **A_T_canon = sigma1 * U(:,1)** from **D(T,t)** with rows=temperature, columns=time, ');
    fprintf(fidR, 'using the same RF3R2 curve inclusion and time grid as RLX-AR01 (`strict_default_no_quality_flag` ');
    fprintf(fidR, 'with fallback to default replay if fewer than 3 temperatures). Relaxation module only.\n\n');

    fprintf(fidR, '## 2. Not recovery of missing A_T_old\n\n');
    fprintf(fidR, 'This is a **new canonical reconstruction** on the current RF3R2 object. ');
    fprintf(fidR, 'It does **not** recover the missing exported legacy `temperature_observables.csv` artifact.\n\n');

    fprintf(fidR, '## 3. RF3R2 input and inclusion audit\n\n');
    fprintf(fidR, 'See `%s`.\n\n', 'relaxation_AT_canon_lineage_06_input_audit.csv');

    fprintf(fidR, '## 4. Construction of D(T,t)\n\n');
    fprintf(fidR, '- Build **M** as AR01: columns are traces vs common **linspace** time grid (**nGrid=%d**) on intersection of per-trace time support.\n', nGrid);
    fprintf(fidR, '- **D = M.''** so **rows = temperature**, **columns = time** (legacy orientation).\n\n');

    fprintf(fidR, '## 5. Legacy definition reconstruction\n\n');
    fprintf(fidR, '`[U,S,V] = svd(D,''econ'')`, **A_T_canon_raw = S(1,1)*U(:,1)**.\n\n');

    fprintf(fidR, '## 6. Sign convention\n\n');
    fprintf(fidR, '- Compare raw vector to **RCON SVD_score_mode1** (`m0_svd`).\n');
    fprintf(fidR, '- If Pearson correlation is negative, flip **A_T** and **V(:,1)**.\n');
    fprintf(fidR, '- Recorded in `%s`.\n\n', 'relaxation_AT_canon_lineage_06_svd_summary.csv');

    fprintf(fidR, '## 7. Rank-1 SVD summary\n\n');
    fprintf(fidR, '- **sigma1** = %.16g\n', sigma1);
    fprintf(fidR, '- **rank-1 energy fraction** = %.16g\n\n', r1Energy);

    fprintf(fidR, '## 8. Comparison to m0_svd\n\n');
    fprintf(fidR, 'Relationship class: **%s** (see scalar comparison table).\n\n', relM0);

    fprintf(fidR, '## 9. Comparison to m0_LOO_SVD_projection\n\n');
    fprintf(fidR, 'Relationship class: **%s**. LOO table present: **%s**.\n\n', relLoo, rlx_l06_yn(looFound));

    fprintf(fidR, '## 10. Comparison to SVD_score_mode1\n\n');
    fprintf(fidR, 'Relationship class: **%s**.\n\n', relSvd);

    fprintf(fidR, '## 11. Comparison to A_obs and A_proj_nonSVD\n\n');
    fprintf(fidR, '- **A_obs:** %s\n', relAobs);
    fprintf(fidR, '- **A_proj_nonSVD:** %s\n\n', relAproj);

    fprintf(fidR, '## 12. Relationship classification\n\n');
    fprintf(fidR, 'Thresholds (conservative): **|Pearson|** >= %.3f for equivalence claims; ', pearTh);
    fprintf(fidR, 'affine NRMSE vs **std(y)** <= %.3f for affine-equivalent; Spearman >= %.2f suggests monotonic-only if affine fails.\n\n', nrmseAffineTh, spearMono);

    fprintf(fidR, '## 13. Equivalence to current m0/SVD coordinates\n\n');
    if strcmp(eqM0, 'YES')
        fprintf(fidR, 'On this RF3R2 object, **A_T_canon** matches current **m0_svd / SVD_score_mode1** within the stated thresholds. ');
        fprintf(fidR, 'The gap noted in LINEAGE-05 vs missing **A_T_old** was therefore likely dominated by **source object / artifact lineage** ');
        fprintf(fidR, 'rather than a different SVD temperature-amplitude definition.\n\n');
    else
        fprintf(fidR, '**A_T_canon** is **not** equivalent to current **m0_svd** under conservative thresholds: ');
        fprintf(fidR, 'the legacy row-oriented definition yields a **distinct scalarization** even on the canonical RF3R2 matrix.\n\n');
    end

    fprintf(fidR, '## 14. Future AX reinterpretation\n\n');
    fprintf(fidR, '**READY_FOR_AX_REINTERPRETATION = %s** (task does not run AX).\n\n', rlx_l06_yn(readyAx));

    fprintf(fidR, '## 15. Future power-law retest\n\n');
    fprintf(fidR, '**READY_FOR_POWERLAW_RETEST = %s** (authorization only; no fit run).\n\n', rlx_l06_yn(readyPl));

    fprintf(fidR, '## 16. Final verdicts\n\n');
    fprintf(fidR, '- **Legacy definition reconstructed on RF3R2:** YES.\n');
    fprintf(fidR, '- **Exact old A_T table recovered:** NO.\n');
    fclose(fidR);

    try
        fg = figure('Visible', 'off', 'Color', 'w');
        plot(Tk, AT_orient, '-o', 'LineWidth', 1.2); hold on;
        plot(Tk, m0_vec, '-s', 'LineWidth', 1.2);
        plot(Tk, aobs_vec, '--', 'LineWidth', 1.0);
        legend('A_T_canon\_oriented', 'm0\_svd', 'A\_obs', 'Location', 'best');
        xlabel('T\_K'); grid on;
        title('LINEAGE-06 scalar overlay');
        print(fg, figOverlay, '-dpng', '-r300');
        close(fg);

        fg = figure('Visible', 'off', 'Color', 'w');
        bar(categorical(string(cmpTbl.target_scalar)), cmpTbl.nrmse_affine);
        ylabel('NRMSE affine (normalized by std(y))');
        grid on;
        title('LINEAGE-06 affine NRMSE by target');
        print(fg, figRmse, '-dpng', '-r300');
        close(fg);
    catch
    end

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nT, {'LINEAGE_06_complete'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'LINEAGE_06_failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    runDirFail = fullfile(repoRoot, 'results', 'relaxation', 'runs', 'run_lineage06_failure');
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirFail = run.run_dir;
        if exist(runDirFail, 'dir') ~= 7
            mkdir(runDirFail);
        end
    end
    writetable(executionStatus, fullfile(runDirFail, 'execution_status.csv'));
    rlx_l06_write_minimal_outputs(repoRoot, tblRelax, repRelax, ME.message);
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end

function R = rlx_l06_build_map(mask, label, cidx, samp, ixTraceI, ixTemp, ixTraceS, ixTime, ixDelta, ...
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
    R = struct('M', M, 'tGrid', tGrid, 'nT', nT, 'T_K', TkR, ...
        'm0_svd', M0, 'SVD_mode1', M0, 'A_obs', Aobs, 'A_proj', Aproj, ...
        'index_rows_mask', mask, 'label', label);
end

function Rm = rlx_l06_compare(at, y, Tk, pearTh, nrmseAffineTh, nrmseScaleTh, nrmseSignTh, spearMono, relIdentTh)
    at = double(at(:));
    y = double(y(:));
    Tk = double(Tk(:));
    keep = isfinite(at) & isfinite(y);
    at = at(keep);
    y = y(keep);
    Tk = Tk(keep);
    Rm = struct('n_common', 0, 'raw_pearson', NaN, 'raw_spearman', NaN, ...
        'sign_aligned_pearson', NaN, 'sign_aligned_spearman', NaN, ...
        'scale_c', NaN, 'affine_b', NaN, 'affine_c', NaN, ...
        'nrmse_raw', NaN, 'nrmse_sign_aligned', NaN, 'nrmse_scale', NaN, 'nrmse_affine', NaN, ...
        'largest_residual_T', NaN, 'relationship_class', 'insufficient_overlap', 'notes', '');
    if numel(at) < 3
        Rm.notes = 'fewer_than_3_finite_pairs';
        return;
    end
    Rm.n_common = numel(at);
    sy = std(y, 0, 'omitnan');
    if sy <= eps
        sy = eps;
    end

    Rm.raw_pearson = corr(at, y, 'Rows', 'complete');
    Rm.raw_spearman = corr(at, y, 'type', 'Spearman', 'Rows', 'complete');

    sf = 1;
    if isfinite(Rm.raw_pearson) && Rm.raw_pearson < 0
        sf = -1;
    end
    ats = sf * at;
    Rm.sign_aligned_pearson = corr(ats, y, 'Rows', 'complete');
    Rm.sign_aligned_spearman = corr(ats, y, 'type', 'Spearman', 'Rows', 'complete');

    den = sum(ats.^2);
    if den > eps
        sc = sum(ats .* y) / den;
    else
        sc = NaN;
    end
    Rm.scale_c = sc;
    pc = polyfit(ats, y, 1);
    Rm.affine_b = pc(2);
    Rm.affine_c = pc(1);

    Rm.nrmse_raw = sqrt(mean((at - y).^2)) / sy;
    Rm.nrmse_sign_aligned = sqrt(mean((ats - y).^2)) / sy;
    ysc = sc * ats;
    Rm.nrmse_scale = sqrt(mean((ysc - y).^2)) / sy;
    yaf = pc(1) * ats + pc(2);
    Rm.nrmse_affine = sqrt(mean((yaf - y).^2)) / sy;

    res = abs(yaf - y);
    [mxv, ixm] = max(res);
    Rm.largest_residual_T = Tk(ixm);
    if mxv < 1e-12
        Rm.notes = sprintf('max_abs_affine_residual=%.3g', mxv);
    else
        Rm.notes = sprintf('max_abs_affine_residual=%.3g_at_T=%.6g', mxv, Tk(ixm));
    end

    relAt = sqrt(mean((at - y).^2)) / max(sqrt(mean(at.^2)), eps);
    relY = sqrt(mean((at - y).^2)) / max(sqrt(mean(y.^2)), eps);
    if relAt < relIdentTh && relY < relIdentTh
        Rm.relationship_class = 'identical';
        return;
    end

    ap = abs(Rm.sign_aligned_pearson);
    sp = abs(Rm.raw_spearman);
    if ap >= pearTh && Rm.nrmse_affine <= nrmseAffineTh
        Rm.relationship_class = 'affine-equivalent';
    elseif ap >= pearTh && Rm.nrmse_scale <= nrmseScaleTh
        Rm.relationship_class = 'scale-equivalent';
    elseif ap >= pearTh && Rm.nrmse_sign_aligned <= nrmseSignTh
        Rm.relationship_class = 'sign-equivalent';
    elseif sp >= spearMono && Rm.nrmse_affine > nrmseAffineTh
        Rm.relationship_class = 'monotonic-only';
    else
        Rm.relationship_class = 'not_equivalent';
    end
end

function s = rlx_l06_yn(tf)
    if tf
        s = 'YES';
    else
        s = 'NO';
    end
end

function s = rlx_l06_equiv_yesno(rel)
    if strcmp(rel, 'affine-equivalent') || strcmp(rel, 'scale-equivalent') || strcmp(rel, 'sign-equivalent') || strcmp(rel, 'identical')
        s = 'YES';
    else
        s = 'NO';
    end
end

function s = rlx_l06_distinct_yesno(rel)
    if strcmp(rel, 'affine-equivalent') || strcmp(rel, 'scale-equivalent') || strcmp(rel, 'sign-equivalent') || strcmp(rel, 'identical')
        s = 'NO';
    else
        s = 'YES';
    end
end

function rlx_l06_write_minimal_outputs(repoRoot, tblRelax, repRelax, msg)
    outAudit = fullfile(tblRelax, 'relaxation_AT_canon_lineage_06_input_audit.csv');
    outScalar = fullfile(tblRelax, 'relaxation_AT_canon_lineage_06_scalar_table.csv');
    outSvd = fullfile(tblRelax, 'relaxation_AT_canon_lineage_06_svd_summary.csv');
    outCmp = fullfile(tblRelax, 'relaxation_AT_canon_lineage_06_scalar_comparison.csv');
    outVer = fullfile(tblRelax, 'relaxation_AT_canon_lineage_06_equivalence_verdicts.csv');
    outStat = fullfile(tblRelax, 'relaxation_AT_canon_lineage_06_status.csv');
    outRep = fullfile(repRelax, 'relaxation_AT_canon_lineage_06_legacy_definition_reconstruction.md');
    try
        writetable(table({'failure'}, {msg}, {'execution_error'}, 'VariableNames', {'key', 'value', 'notes'}), outAudit);
        writetable(table(NaN, NaN, 'VariableNames', {'T_K', 'A_T_canon_raw'}), outScalar);
        writetable(table({'error'}, {msg}, {'fail'}, 'VariableNames', {'key', 'value', 'notes'}), outSvd);
        writetable(table({'none'}, 0, NaN, 'VariableNames', {'target_scalar', 'n_common', 'raw_pearson'}), outCmp);
        writetable(table({'TASK_FAILED'}, {'NO'}, {msg}, {'error'}, 'VariableNames', {'verdict_key', 'value', 'evidence', 'notes'}), outVer);
        ks = {'TASK_COMPLETED'; 'RELAXATION_MODULE_ONLY'; 'SWITCHING_USED'; 'X_USED'; 'AX_FIT_RUN'; 'POWERLAW_FIT_RUN'; ...
            'CROSS_MODULE_CLAIM_CREATED'; 'RF3R2_INPUTS_FOUND'; 'RF3R2_MATRIX_BUILT'; 'LEGACY_AT_DEFINITION_RECONSTRUCTED'; ...
            'A_T_CANON_COMPUTED'; 'CURRENT_M0_SVD_FOUND'; 'CURRENT_M0_LOO_FOUND'; 'RCON_SVD_SCORE_FOUND'; 'AOBS_FOUND'; ...
            'APROJ_FOUND'; 'AT_CANON_EQUIVALENT_TO_M0_SVD'; 'AT_CANON_EQUIVALENT_TO_M0_LOO'; 'AT_CANON_EQUIVALENT_TO_RCON_SVD_SCORE'; ...
            'AT_CANON_DISTINCT_FROM_AOBS'; 'AT_CANON_DISTINCT_FROM_APROJ'; 'READY_FOR_AX_REINTERPRETATION'; ...
            'READY_FOR_POWERLAW_RETEST'; 'EXACT_OLD_AT_RECOVERED'};
        vs = repmat({'NO'}, numel(ks), 1);
        writetable(table(ks, vs, 'VariableNames', {'key', 'value'}), outStat);
        fid = fopen(outRep, 'w');
        if fid >= 0
            fprintf(fid, 'LINEAGE-06 failed: %s\n', msg);
            fclose(fid);
        end
    catch
    end
end
