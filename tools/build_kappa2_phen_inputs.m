% build_kappa2_phen_inputs.m
% Build canonical inputs for phenomenological closure audit of kappa2.
%
% Status / failure contract (self-heal):
% - Always writes: kappa2_build_status.txt
% - On error writes: kappa2_build_error.log
% - Always attempts to write: kappa2_phen_inputs.mat and tables/kappa2_phen_inputs_check.csv
%
% Execution contract:
% - Must be runnable via: eval(fileread('absolute_path_to_script.m'))

repoRoot = 'C:/Dev/matlab-functions';
if ~exist(fullfile(repoRoot, 'tables', 'alpha_structure.csv'), 'file')
    error('build_kappa2_phen_inputs:badWorkingDir', ...
        'Run this script from the repo root; missing %s', fullfile(repoRoot, 'tables', 'alpha_structure.csv'));
end
statusFileAbs = fullfile(repoRoot, 'kappa2_build_status.txt');
errFileAbs = fullfile(repoRoot, 'kappa2_build_error.log');
matFileAbs = fullfile(repoRoot, 'kappa2_phen_inputs.mat');
checkCsvAbs = fullfile(repoRoot, 'tables', 'kappa2_phen_inputs_check.csv');
columnsDebugAbs = fullfile(repoRoot, 'kappa2_columns_debug.txt');
selectedInputAbs = fullfile(repoRoot, 'kappa2_selected_input.txt');
schemaDebugAbs = fullfile(repoRoot, 'kappa2_schema_debug.txt');

fid = fopen(statusFileAbs, 'w');
fprintf(fid, 'START %s\n', datestr(now));
fclose(fid);

% Fail-safe defaults: always define variables so MAT/CSV writing works.
T_K = NaN(0,1);
kappa2 = NaN(0,1);
I_peak = NaN(0,1);
width_asymmetry = NaN(0,1);
slope_asymmetry = NaN(0,1);
local_curvature = NaN(0,1);
antisym_area_res2 = NaN(0,1);

% Track what we recovered for reporting
recovered = strings(0,1);

try
    alphaTbl = readtable(fullfile(repoRoot, 'tables', 'alpha_structure.csv'));
    resTbl = readtable(fullfile(repoRoot, 'results', 'switching', 'runs', 'run_2026_03_25_043610_kappa_phi_temperature_structure_test', 'tables', 'residual_rank_structure_vs_T.csv'));

    % 1) FULL COLUMN DISCOVERY (MANDATORY)
    dbg = struct();
    dbg.alphaColumns = string(alphaTbl.Properties.VariableNames);
    dbg.residualColumns = string(resTbl.Properties.VariableNames);
    dbg.mapping = struct();
    dbg.missingVariables = strings(0,1);
    dbg.warnings = strings(0,1);

    try
        fidDbg = fopen(columnsDebugAbs, 'w');
        fprintf(fidDbg, 'alpha_structure.csv columns (%d):\n', numel(dbg.alphaColumns));
        fprintf(fidDbg, '%s\n', dbg.alphaColumns);
        fprintf(fidDbg, '\nresidual_rank_structure_vs_T.csv columns (%d):\n', numel(dbg.residualColumns));
        fprintf(fidDbg, '%s\n', dbg.residualColumns);
        fclose(fidDbg);
    catch
        % non-fatal
    end

    % Restrict to canonical low-T subset if subset column exists
    if ismember('subset', string(resTbl.Properties.VariableNames))
        resLowT = resTbl(strcmp(string(resTbl.subset), 'T_le_30'), :);
    else
        resLowT = resTbl;
    end

    alphaTbl.T_K = double(alphaTbl.T_K);
    resLowT.T_K = double(resLowT.T_K);

    % Align by T_K intersection (avoids innerjoin variable name issues)
    [T_Kcommon, ia, ib] = intersect(alphaTbl.T_K, resLowT.T_K);
    T_K = T_Kcommon(:);
    if isempty(T_K)
        dbg.warnings(end+1) = "No common T_K intersection; outputs will be empty NaNs.";
    end

    % --------- Detect columns in alpha table (contains-based) ---------
    aVn = string(alphaTbl.Properties.VariableNames);
    % kappa2 is sourced from residual table, but descriptors are from alpha.

    idxIpeak = find(contains(aVn, 'I_peak', 'IgnoreCase', true) | contains(aVn, 'peak', 'IgnoreCase', true), 1, 'first');
    idxW = find(contains(aVn, 'width', 'IgnoreCase', true) | contains(aVn, 'asymmetry_q_spread', 'IgnoreCase', true) | contains(aVn, 'asymmetry', 'IgnoreCase', true), 1, 'first');
    idxS = find(contains(aVn, 'slope', 'IgnoreCase', true) | contains(aVn, 'skew_I_weighted', 'IgnoreCase', true) | contains(aVn, 'skew', 'IgnoreCase', true), 1, 'first');
    idxQ90 = find(contains(aVn, 'q90_minus_q50', 'IgnoreCase', true), 1, 'first');
    idxQ75 = find(contains(aVn, 'q75_minus_q25', 'IgnoreCase', true), 1, 'first');

    if ~isempty(idxIpeak)
        I_peak = alphaTbl{ia, idxIpeak};
        dbg.mapping.I_peak = aVn(idxIpeak);
        recovered(end+1) = "I_peak";
    else
        I_peak = NaN(size(T_K));
        dbg.missingVariables(end+1) = "I_peak";
    end
    if ~isempty(idxW)
        width_asymmetry = alphaTbl{ia, idxW};
        dbg.mapping.width_asymmetry = aVn(idxW);
        recovered(end+1) = "width_asymmetry";
    else
        width_asymmetry = NaN(size(T_K));
        dbg.missingVariables(end+1) = "width_asymmetry";
    end
    if ~isempty(idxS)
        slope_asymmetry = alphaTbl{ia, idxS};
        dbg.mapping.slope_asymmetry = aVn(idxS);
        recovered(end+1) = "slope_asymmetry";
    else
        slope_asymmetry = NaN(size(T_K));
        dbg.missingVariables(end+1) = "slope_asymmetry";
    end
    if ~isempty(idxQ90) && ~isempty(idxQ75)
        local_curvature = alphaTbl{ia, idxQ90} - alphaTbl{ia, idxQ75};
        dbg.mapping.local_curvature = "q90_minus_q50 - q75_minus_q25 (constructed)";
        recovered(end+1) = "local_curvature";
    else
        local_curvature = NaN(size(T_K));
        dbg.missingVariables(end+1) = "local_curvature";
    end

    % --------- Detect columns in residual table ---------
    rVn = string(resLowT.Properties.VariableNames);
    % canonical kappa2(T) is typically stored as `kappa` in this table
    idxK2 = find(contains(rVn, 'kappa2', 'IgnoreCase', true), 1, 'first');
    if isempty(idxK2)
        idxK2 = find(contains(rVn, 'kappa', 'IgnoreCase', true) & ~contains(rVn, 'kappa1', 'IgnoreCase', true), 1, 'first');
    end
    if isempty(idxK2)
        kappa2 = NaN(size(T_K));
        dbg.missingVariables(end+1) = "kappa2";
        dbg.warnings(end+1) = "Could not detect kappa2-like column in residual_rank_structure_vs_T.csv.";
    else
        kappa2 = resLowT{ib, idxK2};
        dbg.mapping.kappa2 = rVn(idxK2);
        recovered(end+1) = "kappa2";
    end

    idxAnti = find(contains(rVn, 'rel_orth_leftover', 'IgnoreCase', true), 1, 'first');
    if ~isempty(idxAnti)
        antisym_area_res2 = resLowT{ib, idxAnti};
        dbg.mapping.antisym_area_res2 = rVn(idxAnti);
        recovered(end+1) = "antisym_area_res2";
    else
        antisym_area_res2 = NaN(size(T_K));
        dbg.missingVariables(end+1) = "antisym_area_res2";
    end

    % Save outputs and check CSV
    save(matFileAbs, 'T_K', 'kappa2', 'I_peak', 'width_asymmetry', 'slope_asymmetry', 'local_curvature', 'antisym_area_res2', 'dbg');

    verifyTbl = table(T_K, kappa2, I_peak, width_asymmetry, slope_asymmetry, local_curvature, antisym_area_res2, ...
        'VariableNames', {'T_K','kappa2','I_peak','width_asymmetry','slope_asymmetry','local_curvature','antisym_area_res2'});
    writetable(verifyTbl, checkCsvAbs);

    fid = fopen(statusFileAbs, 'a');
    fprintf(fid, 'DONE recovered=%s n=%d\n', strjoin(unique(recovered), ','), numel(T_K));
    fclose(fid);
catch ME
    fid = fopen(errFileAbs, 'w');
    fprintf(fid, 'ERROR %s\n\n', datestr(now));
    fprintf(fid, '%s\n', getReport(ME));
    fclose(fid);

    % Best-effort MAT/CSV even if partial: keep NaN vectors but ensure files exist.
    if isempty(T_K)
        verifyTbl = table(NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), NaN(0,1), ...
            'VariableNames', {'T_K','kappa2','I_peak','width_asymmetry','slope_asymmetry','local_curvature','antisym_area_res2'});
    else
        verifyTbl = table(T_K, kappa2, I_peak, width_asymmetry, slope_asymmetry, local_curvature, antisym_area_res2, ...
            'VariableNames', {'T_K','kappa2','I_peak','width_asymmetry','slope_asymmetry','local_curvature','antisym_area_res2'});
    end
    try
        save(matFileAbs, 'T_K', 'kappa2', 'I_peak', 'width_asymmetry', 'slope_asymmetry', 'local_curvature', 'antisym_area_res2');
        writetable(verifyTbl, checkCsvAbs);
    catch
        % last resort: ignore
    end

    fid = fopen(statusFileAbs, 'a');
    fprintf(fid, 'FAIL_RECOVERED\n');
    fclose(fid);
end

