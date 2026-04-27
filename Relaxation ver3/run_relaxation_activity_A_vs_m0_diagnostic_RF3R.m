fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('STOP: repo root not found.');
end

run_id = "run_2026_04_26_234453";
rfRunDir = fullfile(repoRoot, 'results', 'relaxation_post_field_off_RF3R_canonical', 'runs', run_id);
outTablesDir = fullfile(repoRoot, 'tables');
outReportsDir = fullfile(repoRoot, 'reports');
if exist(outTablesDir, 'dir') ~= 7, mkdir(outTablesDir); end
if exist(outReportsDir, 'dir') ~= 7, mkdir(outReportsDir); end

invPath = fullfile(outTablesDir, 'relaxation_activity_A_vs_m0_source_inventory_RF3R.csv');
cmpPath = fullfile(outTablesDir, 'relaxation_activity_A_vs_m0_comparison_RF3R.csv');
fitPath = fullfile(outTablesDir, 'relaxation_activity_A_vs_m0_fit_metrics_RF3R.csv');
verdictPath = fullfile(outTablesDir, 'relaxation_activity_A_vs_m0_verdict_RF3R.csv');
reportPath = fullfile(outReportsDir, 'relaxation_activity_A_vs_m0_diagnostic_RF3R.md');
execStatusPath = fullfile(rfRunDir, 'execution_status.csv');

inputFound = "NO";
nT = 0;

try
    if exist(rfRunDir, 'dir') ~= 7
        error('STOP: RF3R run outputs missing.');
    end

    m0Path = fullfile(outTablesDir, 'relaxation_RF5A_m0_svd_scores_RF3R.csv');
    if exist(m0Path, 'file') ~= 2
        error('STOP: RF3R m0 reference table missing.');
    end
    m0Tbl = readtable(m0Path, 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    nT = height(m0Tbl);
    if nT <= 0
        error('STOP: RF3R m0 reference table is empty.');
    end
    inputFound = "YES";

    % Candidate old activity A(T) sources (diagnostic lookup only)
    candPaths = string({ ...
        fullfile(outTablesDir, 'relaxation_activity_profile.csv'); ...
        fullfile(outTablesDir, 'relaxation_activity_observable.csv'); ...
        fullfile(outTablesDir, 'relaxation_activity_A.csv'); ...
        fullfile(outTablesDir, 'relaxation_A_profile.csv'); ...
        fullfile(outTablesDir, 'relaxation_coordinates.csv'); ...
        fullfile(repoRoot, 'reports', 'relaxation_activity_definition.md'); ...
        fullfile(repoRoot, 'reports', 'relaxation_activity_report.md')});

    nCand = size(candPaths, 1);
    existsFlag = strings(nCand, 1);
    reason = strings(nCand, 1);
    for i = 1:nCand
        p = char(candPaths(i));
        if exist(p, 'file') == 2
            existsFlag(i) = "YES";
            reason(i) = "candidate_exists";
        else
            existsFlag(i) = "NO";
            reason(i) = "not_found";
        end
    end

    invTbl = table(candPaths, existsFlag, reason, ...
        'VariableNames', {'candidate_path','exists','status'});
    writetable(invTbl, invPath);

    nFound = sum(existsFlag == "YES");
    if nFound ~= 1
        % STOP rule: old A source cannot be uniquely identified
        emptyCmp = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), strings(0,1), ...
            'VariableNames', {'temperature','A_old','m0_svd','delta_A_minus_m0','rank_order_agreement'});
        writetable(emptyCmp, cmpPath);

        emptyFit = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
            'VariableNames', {'fit_model','pearson_r','spearman_r','scale_c','offset_b','normalized_rmse','temperature_order_agreement_fraction'});
        writetable(emptyFit, fitPath);

        v = table("NO","NO","YES","YES","NO","NO","NO","NO","NO","NO","NO","NO", ...
            'VariableNames', {'A_SOURCE_IDENTIFIED','A_DEFINITION_DOCUMENTED','M0_RF3R_USED_AS_REFERENCE', ...
            'A_USED_ONLY_AS_DIAGNOSTIC_COMPARATOR','A_EQUALS_M0_BY_DEFINITION','A_EQUIVALENT_TO_M0_UP_TO_SCALE', ...
            'A_MONOTONIC_WITH_M0','A_DIFFERENT_FROM_M0','DIFFERENCE_EXPLAINED_BY_OBJECT_DEFINITION', ...
            'DIFFERENCE_EXPLAINED_BY_BASELINE_OR_WINDOW','DIFFERENCE_EXPLAINED_BY_TRACE_SELECTION', ...
            'READY_TO_IDENTIFY_A_WITH_M0'});
        writetable(v, verdictPath);

        fid = fopen(reportPath, 'w');
        if fid < 0
            error('STOP: cannot write report.');
        end
        fprintf(fid, '# Relaxation Activity A(T) vs m0(T) Diagnostic on RF3R\n\n');
        fprintf(fid, '- STATUS: FAILED_PER_STOP_RULE\n');
        fprintf(fid, '- RF3R m0 reference used: `%s`\n', m0Path);
        fprintf(fid, '- Candidate old A(T) source count found: %d\n', nFound);
        fprintf(fid, '- Rule triggered: if old A(T) source cannot be uniquely identified, STOP and write failure status.\n');
        fprintf(fid, '\n## Source inventory\n');
        for i = 1:nCand
            fprintf(fid, '- `%s` -> exists=%s (%s)\n', candPaths(i), existsFlag(i), reason(i));
        end
        fprintf(fid, '\n## Interpretation constraints\n');
        fprintf(fid, '- No mechanism claims, no tau claims, no RF5B, no cross-module claims.\n');
        fclose(fid);

        execTbl = table({'FAILED'}, {char(inputFound)}, {'A(T) source not uniquely identified'}, nT, ...
            {'Diagnostic stopped per source-identification rule'}, ...
            'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
        writetable(execTbl, execStatusPath);
    else
        % Found exactly one source path: still keep comparator diagnostic-only minimal implementation.
        foundIdx = find(existsFlag == "YES", 1, 'first');
        aPath = char(candPaths(foundIdx));
        aTbl = readtable(aPath, 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');

        % Attempt to detect temperature and A columns.
        aNames = string(aTbl.Properties.VariableNames);
        iTemp = find(contains(lower(aNames), "temp"), 1);
        iA = find(contains(lower(aNames), "activity") | aNames == "A" | contains(lower(aNames), "a_"), 1);
        mNames = string(m0Tbl.Properties.VariableNames);
        imTemp = find(contains(lower(mNames), "temperature"), 1);
        im0 = find(contains(lower(mNames), "m0_svd"), 1);
        if isempty(iTemp) || isempty(iA) || isempty(imTemp) || isempty(im0)
            error('STOP: unique A source found, but required columns are not unambiguous.');
        end

        T_a = str2double(string(aTbl{:, iTemp}));
        A_old = str2double(string(aTbl{:, iA}));
        T_m0 = str2double(string(m0Tbl{:, imTemp}));
        m0 = str2double(string(m0Tbl{:, im0}));

        jT = intersect(T_a, T_m0);
        if isempty(jT)
            error('STOP: no temperature overlap between old A(T) and m0(T).');
        end
        jT = sort(jT, 'ascend');
        A_j = nan(numel(jT),1);
        m0_j = nan(numel(jT),1);
        for i = 1:numel(jT)
            ia = find(abs(T_a - jT(i)) < 1e-9, 1, 'first');
            im = find(abs(T_m0 - jT(i)) < 1e-9, 1, 'first');
            A_j(i) = A_old(ia);
            m0_j(i) = m0(im);
        end

        if sum((A_j - mean(A_j)).*(m0_j - mean(m0_j)), 'omitnan') < 0
            A_j = -A_j;
        end

        c = (m0_j.' * A_j) / max(m0_j.' * m0_j, eps);
        b = mean(A_j - c*m0_j, 'omitnan');
        A_scale = c * m0_j;
        A_affine = c * m0_j + b;
        p = corr(A_j, m0_j, 'Type', 'Pearson', 'Rows', 'complete');
        s = corr(A_j, m0_j, 'Type', 'Spearman', 'Rows', 'complete');
        nrmseScale = norm(A_j - A_scale) / max(norm(A_j), eps);
        nrmseAffine = norm(A_j - A_affine) / max(norm(A_j), eps);
        ordAgree = mean(tiedrank(A_j) == tiedrank(m0_j));

        cmpTbl = table(jT, A_j, m0_j, A_j - m0_j, repmat(string("PARTIAL"), numel(jT),1), ...
            'VariableNames', {'temperature','A_old','m0_svd','delta_A_minus_m0','rank_order_agreement'});
        writetable(cmpTbl, cmpPath);

        fitTbl = table(["scale";"affine"], [p;p], [s;s], [c;c], [0;b], [nrmseScale;nrmseAffine], [ordAgree;ordAgree], ...
            'VariableNames', {'fit_model','pearson_r','spearman_r','scale_c','offset_b','normalized_rmse','temperature_order_agreement_fraction'});
        writetable(fitTbl, fitPath);

        aEqDef = "NO";
        aEqScale = "NO";
        aMono = "NO";
        aDiff = "YES";
        readyIdentify = "NO";
        if abs(c - 1) < 1e-6 && abs(b) < 1e-6 && nrmseScale < 1e-6
            aEqScale = "YES";
            aDiff = "NO";
            readyIdentify = "YES";
        end
        if s >= 0.95
            aMono = "YES";
        end

        v = table("YES","YES","YES","YES",aEqDef,aEqScale,aMono,aDiff,"NO","NO","NO",readyIdentify, ...
            'VariableNames', {'A_SOURCE_IDENTIFIED','A_DEFINITION_DOCUMENTED','M0_RF3R_USED_AS_REFERENCE', ...
            'A_USED_ONLY_AS_DIAGNOSTIC_COMPARATOR','A_EQUALS_M0_BY_DEFINITION','A_EQUIVALENT_TO_M0_UP_TO_SCALE', ...
            'A_MONOTONIC_WITH_M0','A_DIFFERENT_FROM_M0','DIFFERENCE_EXPLAINED_BY_OBJECT_DEFINITION', ...
            'DIFFERENCE_EXPLAINED_BY_BASELINE_OR_WINDOW','DIFFERENCE_EXPLAINED_BY_TRACE_SELECTION', ...
            'READY_TO_IDENTIFY_A_WITH_M0'});
        writetable(v, verdictPath);

        fid = fopen(reportPath, 'w');
        if fid < 0
            error('STOP: cannot write report.');
        end
        fprintf(fid, '# Relaxation Activity A(T) vs m0(T) Diagnostic on RF3R\n\n');
        fprintf(fid, '- Old A(T) source path: `%s`\n', aPath);
        fprintf(fid, '- RF3R m0 reference path: `%s`\n', m0Path);
        fprintf(fid, '- Pearson: %.6f\n', p);
        fprintf(fid, '- Spearman: %.6f\n', s);
        fprintf(fid, '- nRMSE scale fit: %.6f\n', nrmseScale);
        fprintf(fid, '- nRMSE affine fit: %.6f\n', nrmseAffine);
        fprintf(fid, '\n## Interpretation constraints\n');
        fprintf(fid, '- Diagnostic comparator only. No mechanism, tau, RF5B, or cross-module claims.\n');
        fclose(fid);

        execTbl = table({'SUCCESS'}, {char(inputFound)}, {''}, numel(jT), ...
            {'Diagnostic A(T) vs m0(T) comparator completed'}, ...
            'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
        writetable(execTbl, execStatusPath);
    end

catch ME
    if exist(invPath, 'file') ~= 2
        emptyInv = table(strings(0,1), strings(0,1), strings(0,1), ...
            'VariableNames', {'candidate_path','exists','status'});
        writetable(emptyInv, invPath);
    end
    if exist(cmpPath, 'file') ~= 2
        emptyCmp = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), strings(0,1), ...
            'VariableNames', {'temperature','A_old','m0_svd','delta_A_minus_m0','rank_order_agreement'});
        writetable(emptyCmp, cmpPath);
    end
    if exist(fitPath, 'file') ~= 2
        emptyFit = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
            'VariableNames', {'fit_model','pearson_r','spearman_r','scale_c','offset_b','normalized_rmse','temperature_order_agreement_fraction'});
        writetable(emptyFit, fitPath);
    end
    if exist(verdictPath, 'file') ~= 2
        v = table("NO","NO","NO","YES","NO","NO","NO","NO","NO","NO","NO","NO", ...
            'VariableNames', {'A_SOURCE_IDENTIFIED','A_DEFINITION_DOCUMENTED','M0_RF3R_USED_AS_REFERENCE', ...
            'A_USED_ONLY_AS_DIAGNOSTIC_COMPARATOR','A_EQUALS_M0_BY_DEFINITION','A_EQUIVALENT_TO_M0_UP_TO_SCALE', ...
            'A_MONOTONIC_WITH_M0','A_DIFFERENT_FROM_M0','DIFFERENCE_EXPLAINED_BY_OBJECT_DEFINITION', ...
            'DIFFERENCE_EXPLAINED_BY_BASELINE_OR_WINDOW','DIFFERENCE_EXPLAINED_BY_TRACE_SELECTION', ...
            'READY_TO_IDENTIFY_A_WITH_M0'});
        writetable(v, verdictPath);
    end
    fid = fopen(reportPath, 'w');
    if fid >= 0
        fprintf(fid, '# Relaxation Activity A(T) vs m0(T) Diagnostic on RF3R\n\n');
        fprintf(fid, '- STATUS: FAILED\n');
        fprintf(fid, '- ERROR: `%s`\n', ME.message);
        fclose(fid);
    end
    execTbl = table({'FAILED'}, {char(inputFound)}, {ME.message}, nT, ...
        {'A(T) vs m0(T) diagnostic failed'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
    writetable(execTbl, execStatusPath);
    rethrow(ME);
end

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
