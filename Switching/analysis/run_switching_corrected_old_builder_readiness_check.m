clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

inputsOutPath = fullfile(tablesDir, 'switching_corrected_old_builder_readiness_inputs.csv');
gatesOutPath = fullfile(tablesDir, 'switching_corrected_old_builder_readiness_gates.csv');
statusOutPath = fullfile(tablesDir, 'switching_corrected_old_builder_readiness_status.csv');
windowOutPath = fullfile(tablesDir, 'switching_corrected_old_builder_temperature_window_check.csv');
reportOutPath = fullfile(reportsDir, 'switching_corrected_old_builder_readiness_check.md');

READINESS_ONLY_SCRIPT_IMPLEMENTED = "YES";
SOURCE_VIEW_USED = "NO";
SOURCE_VIEW_IS_CLEAN = "NO";
CANON_GEN_DIAGNOSTIC_OUTPUTS_USED = "NO";
EFFECTIVE_OBSERVABLE_INPUTS_FOUND = "NO";
EFFECTIVE_OBSERVABLE_INPUTS_VALIDATED = "NO";
LEGACY_PT_MATRIX_FOUND = "NO";
OLD_AUTHORITATIVE_BRANCH_PT_ONLY = "NO";
FALLBACK_ONLY_REPLAY_FORBIDDEN = "YES";
TEMPERATURE_WINDOW_MATCHES_OLD_RECIPE = "NO";
CORRECTED_OLD_AUTH_NAMESPACE_STILL_BLOCKED = "YES";
SAFE_TO_IMPLEMENT_FULL_BUILDER = "NO";
SAFE_TO_RUN_FULL_BUILDER = "NO";
PHYSICS_ARTIFACTS_GENERATED = "NO";
PHYSICS_LOGIC_CHANGED = "NO";
FILES_DELETED = "NO";

notes = strings(0,1);
sourceViewPath = "";
effectiveViewPath = "";
sourceViewRunId = "";

try
    contractsPath = fullfile(tablesDir, 'switching_canonical_output_view_contracts.csv');
    blockedMarkerPath = fullfile(tablesDir, 'switching_corrected_old_namespace_blocked_marker.csv');
    provenancePath = fullfile(tablesDir, 'switching_corrected_old_recipe_provenance_verification.csv');

    if exist(contractsPath, 'file') ~= 2
        error('readiness:MissingContracts', 'Missing contracts table: %s', contractsPath);
    end
    contractsCell = readcell(contractsPath, 'FileType', 'text', 'Delimiter', ',');
    if size(contractsCell, 1) < 2
        error('readiness:EmptyContracts', 'Contracts table is empty: %s', contractsPath);
    end
    contractNames = string(contractsCell(1, :));
    contractNamesNorm = lower(replace(strtrim(contractNames), char(65279), ""));
    cViewId = find(contractNamesNorm == "view_id", 1, 'first');
    cViewPath = find(contractNamesNorm == "view_path", 1, 'first');
    if isempty(cViewId) || isempty(cViewPath)
        error('readiness:MissingContractColumns', 'Contracts table missing view_id/view_path columns.');
    end
    viewIdVals = string(contractsCell(2:end, cViewId));
    viewPathVals = string(contractsCell(2:end, cViewPath));

    idxSource = find(viewIdVals == "A_CANONICAL_SOURCE_VIEW", 1, 'first');
    if isempty(idxSource)
        error('readiness:MissingSourceContract', 'Missing A_CANONICAL_SOURCE_VIEW row in %s', contractsPath);
    end
    sourceRel = viewPathVals(idxSource);
    sourceRel = replace(sourceRel, '/', filesep);
    sourceViewPath = string(fullfile(repoRoot, char(sourceRel)));

    idxEff = find(viewIdVals == "B_EFFECTIVE_OBSERVABLE_VIEW", 1, 'first');
    if ~isempty(idxEff)
        effRel = viewPathVals(idxEff);
        effRel = replace(effRel, '/', filesep);
        effectiveViewPath = string(fullfile(repoRoot, char(effRel)));
    end

    if strlength(sourceViewPath) == 0 || exist(char(sourceViewPath), 'file') ~= 2
        error('readiness:MissingSourceView', 'Missing canonical source view: %s', sourceViewPath);
    end

    SOURCE_VIEW_USED = "YES";

    src = readtable(char(sourceViewPath), 'TextType', 'string', 'VariableNamingRule', 'preserve');
    srcNames = string(src.Properties.VariableNames);
    srcNamesNorm = lower(replace(strtrim(srcNames), char(65279), ""));
    reqCols = ["T_K", "current_mA", "S_percent"];
    for iReq = 1:numel(reqCols)
        if ~any(srcNamesNorm == lower(reqCols(iReq)))
            error('readiness:MissingRequiredSourceCol', 'Source view missing required column: %s', reqCols(iReq));
        end
    end

    forbiddenExact = ["S_model_pt_percent", "residual_percent", "PT_pdf", "CDF_pt", "S_model_full_percent"];
    forbiddenFound = strings(0,1);
    for iF = 1:numel(forbiddenExact)
        if any(srcNamesNorm == lower(forbiddenExact(iF)))
            forbiddenFound(end+1,1) = forbiddenExact(iF); %#ok<AGROW>
        end
    end
    for iN = 1:numel(srcNamesNorm)
        nLow = srcNamesNorm(iN);
        if startsWith(nLow, "phi") || startsWith(nLow, "kappa")
            forbiddenFound(end+1,1) = srcNames(iN); %#ok<AGROW>
        end
    end
    forbiddenFound = unique(forbiddenFound);

    if isempty(forbiddenFound)
        SOURCE_VIEW_IS_CLEAN = "YES";
    else
        SOURCE_VIEW_IS_CLEAN = "NO";
        notes(end+1,1) = "Forbidden columns found in source view: " + strjoin(forbiddenFound, ', '); %#ok<AGROW>
    end

    srcRunTokens = split(sourceViewPath, filesep);
    for iTok = 1:numel(srcRunTokens)
        tok = srcRunTokens(iTok);
        if startsWith(tok, "run_") && endsWith(tok, "_switching_canonical")
            sourceViewRunId = tok;
            break;
        end
    end

    if strlength(effectiveViewPath) == 0 || exist(char(effectiveViewPath), 'file') ~= 2
        EFFECTIVE_OBSERVABLE_INPUTS_FOUND = "NO";
        EFFECTIVE_OBSERVABLE_INPUTS_VALIDATED = "NO";
        notes(end+1,1) = "Effective observable view path missing from contracts or file not found."; %#ok<AGROW>
    else
        effCell = readcell(char(effectiveViewPath), 'FileType', 'text', 'Delimiter', ',');
        if size(effCell, 1) < 2
            EFFECTIVE_OBSERVABLE_INPUTS_FOUND = "NO";
            EFFECTIVE_OBSERVABLE_INPUTS_VALIDATED = "NO";
            notes(end+1,1) = "Effective observable view is empty."; %#ok<AGROW>
        else
        effNames = string(effCell(1, :));
        effNamesNorm = lower(replace(strtrim(effNames), char(65279), ""));
        needEffCols = ["I_peak_mA", "S_peak"];
        widthColExists = any(effNamesNorm == "width_chosen_ma") || any(effNamesNorm == "w_i_ma");
        if all(ismember(lower(needEffCols), effNamesNorm)) && widthColExists
            EFFECTIVE_OBSERVABLE_INPUTS_FOUND = "YES";
        elseif all(ismember(lower(needEffCols), effNamesNorm))
            EFFECTIVE_OBSERVABLE_INPUTS_FOUND = "PARTIAL";
        else
            EFFECTIVE_OBSERVABLE_INPUTS_FOUND = "NO";
        end

        idxValidationStatus = find(effNamesNorm == "validation_status", 1, 'first');
        if ~isempty(idxValidationStatus)
            vs = upper(strtrim(string(effCell(2:end, idxValidationStatus))));
            if all(vs == "VALIDATED")
                EFFECTIVE_OBSERVABLE_INPUTS_VALIDATED = "YES";
            elseif any(vs == "VALIDATED") || any(vs == "PARTIAL")
                EFFECTIVE_OBSERVABLE_INPUTS_VALIDATED = "PARTIAL";
            else
                EFFECTIVE_OBSERVABLE_INPUTS_VALIDATED = "NO";
            end
        else
            EFFECTIVE_OBSERVABLE_INPUTS_VALIDATED = "PARTIAL";
            notes(end+1,1) = "validation_status column missing from effective observable view."; %#ok<AGROW>
        end
        end
    end

    if exist(provenancePath, 'file') ~= 2
        error('readiness:MissingProvenance', 'Missing provenance verification table: %s', provenancePath);
    end
    prov = readtable(provenancePath, 'TextType', 'string', 'VariableNamingRule', 'preserve');

    idxPtPath = find(prov.verification_item == "legacy_template_pt_matrix_file", 1, 'first');
    idxPtOnly = find(prov.verification_item == "old_execution_mode", 1, 'first');
    idxPtRows = find(prov.verification_item == "old_execution_pt_rows", 1, 'first');
    idxFbRows = find(prov.verification_item == "old_execution_fallback_rows", 1, 'first');

    ptMatrixPath = "";
    if ~isempty(idxPtPath)
        ptMatrixPath = prov.result(idxPtPath);
        if exist(char(ptMatrixPath), 'file') == 2
            LEGACY_PT_MATRIX_FOUND = "YES";
        else
            LEGACY_PT_MATRIX_FOUND = "NO";
            notes(end+1,1) = "Legacy PT_matrix path from provenance not found: " + ptMatrixPath; %#ok<AGROW>
        end
    else
        LEGACY_PT_MATRIX_FOUND = "NO";
        notes(end+1,1) = "legacy_template_pt_matrix_file row missing in provenance table."; %#ok<AGROW>
    end

    if ~isempty(idxPtOnly)
        modeVal = upper(strtrim(prov.result(idxPtOnly)));
        if modeVal == "PT_ONLY"
            OLD_AUTHORITATIVE_BRANCH_PT_ONLY = "YES";
        else
            OLD_AUTHORITATIVE_BRANCH_PT_ONLY = "NO";
        end
    end

    if ~isempty(idxPtRows) && ~isempty(idxFbRows)
        ptRows = str2double(prov.result(idxPtRows));
        fbRows = str2double(prov.result(idxFbRows));
        if ~(isfinite(ptRows) && ptRows > 0 && isfinite(fbRows) && fbRows == 0)
            OLD_AUTHORITATIVE_BRANCH_PT_ONLY = "NO";
            notes(end+1,1) = "PT/fallback row counts do not match PT-only legacy branch requirement."; %#ok<AGROW>
        end
    end

    srcT = unique(str2double(string(src.T_K)));
    srcT = sort(srcT(isfinite(srcT)));
    expectedT = (4:2:30)';
    missingT = expectedT(~ismember(expectedT, srcT));
    extraInPrimary = srcT(srcT <= 30 & ~ismember(srcT, expectedT));

    if isempty(missingT) && isempty(extraInPrimary)
        TEMPERATURE_WINDOW_MATCHES_OLD_RECIPE = "YES";
    elseif numel(missingT) <= 2
        TEMPERATURE_WINDOW_MATCHES_OLD_RECIPE = "PARTIAL";
    else
        TEMPERATURE_WINDOW_MATCHES_OLD_RECIPE = "NO";
    end

    nRows = numel(srcT);
    tmpExpected = repmat("YES", numel(expectedT), 1);
    tmpPresent = repmat("NO", numel(expectedT), 1);
    tmpInWindow = repmat("YES", numel(expectedT), 1);
    for iT = 1:numel(expectedT)
        if ismember(expectedT(iT), srcT)
            tmpPresent(iT) = "YES";
        end
    end
    winTbl = table(expectedT, tmpExpected, tmpPresent, tmpInWindow, ...
        'VariableNames', {'T_expected_K','in_old_recipe','present_in_source_view','in_T_le_30_window'});
    writetable(winTbl, windowOutPath);

    if exist(blockedMarkerPath, 'file') == 2
        marker = readtable(blockedMarkerPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
        mkNames = string(marker.Properties.VariableNames);
        mkNamesNorm = lower(replace(strtrim(mkNames), char(65279), ""));
        idxBuildBlocked = find(mkNamesNorm == "build_blocked", 1, 'first');
        if ~isempty(idxBuildBlocked)
            mk = upper(strtrim(string(marker.(mkNames(idxBuildBlocked))(1))));
            if mk == "YES"
                CORRECTED_OLD_AUTH_NAMESPACE_STILL_BLOCKED = "YES";
            else
                CORRECTED_OLD_AUTH_NAMESPACE_STILL_BLOCKED = "NO";
            end
        else
            CORRECTED_OLD_AUTH_NAMESPACE_STILL_BLOCKED = "NO";
            notes(end+1,1) = "build_blocked column missing in corrected-old namespace marker."; %#ok<AGROW>
        end
    else
        CORRECTED_OLD_AUTH_NAMESPACE_STILL_BLOCKED = "NO";
        notes(end+1,1) = "Missing corrected-old namespace blocked marker file."; %#ok<AGROW>
    end

    if SOURCE_VIEW_IS_CLEAN == "YES" && LEGACY_PT_MATRIX_FOUND == "YES" && OLD_AUTHORITATIVE_BRANCH_PT_ONLY == "YES"
        if EFFECTIVE_OBSERVABLE_INPUTS_VALIDATED == "YES" && TEMPERATURE_WINDOW_MATCHES_OLD_RECIPE == "YES"
            SAFE_TO_IMPLEMENT_FULL_BUILDER = "YES";
        elseif EFFECTIVE_OBSERVABLE_INPUTS_VALIDATED == "PARTIAL" || TEMPERATURE_WINDOW_MATCHES_OLD_RECIPE == "PARTIAL"
            SAFE_TO_IMPLEMENT_FULL_BUILDER = "PARTIAL";
        else
            SAFE_TO_IMPLEMENT_FULL_BUILDER = "NO";
        end
    else
        SAFE_TO_IMPLEMENT_FULL_BUILDER = "NO";
    end

    SAFE_TO_RUN_FULL_BUILDER = "NO";

    inputRows = strings(0,1);
    inputKind = strings(0,1);
    inputPath = strings(0,1);
    inputExists = strings(0,1);
    inputDetails = strings(0,1);

    inputRows(end+1,1) = "canonical_source_view"; inputKind(end+1,1) = "SEPARATED_SOURCE"; inputPath(end+1,1) = sourceViewPath; inputExists(end+1,1) = string(SOURCE_VIEW_USED == "YES"); inputDetails(end+1,1) = "Must contain only T_K/current_mA/S_percent plus identity."; %#ok<AGROW>
    inputRows(end+1,1) = "effective_observable_view"; inputKind(end+1,1) = "EFFECTIVE_OBSERVABLE"; inputPath(end+1,1) = effectiveViewPath; inputExists(end+1,1) = string(exist(char(effectiveViewPath), 'file') == 2); inputDetails(end+1,1) = "Validation status required before builder run."; %#ok<AGROW>
    inputRows(end+1,1) = "legacy_pt_matrix"; inputKind(end+1,1) = "LEGACY_TEMPLATE"; inputPath(end+1,1) = ptMatrixPath; inputExists(end+1,1) = string(LEGACY_PT_MATRIX_FOUND == "YES"); inputDetails(end+1,1) = "Must match verified old PT source."; %#ok<AGROW>
    inputRows(end+1,1) = "provenance_verification_table"; inputKind(end+1,1) = "GOVERNANCE"; inputPath(end+1,1) = provenancePath; inputExists(end+1,1) = string(exist(provenancePath, 'file') == 2); inputDetails(end+1,1) = "Used to verify PT-only legacy branch."; %#ok<AGROW>
    inputRows(end+1,1) = "corrected_old_block_marker"; inputKind(end+1,1) = "GOVERNANCE"; inputPath(end+1,1) = blockedMarkerPath; inputExists(end+1,1) = string(exist(blockedMarkerPath, 'file') == 2); inputDetails(end+1,1) = "Namespace must stay blocked in readiness-only step."; %#ok<AGROW>

    inputsTbl = table(inputRows, inputKind, inputPath, inputExists, inputDetails, ...
        'VariableNames', {'input_id','input_kind','input_path','input_exists','input_requirement'});
    writetable(inputsTbl, inputsOutPath);

    gateId = [
        "GATE_SOURCE_VIEW_USED";
        "GATE_SOURCE_VIEW_CLEAN";
        "GATE_NO_CANON_GEN_DIAGNOSTIC_USAGE";
        "GATE_EFFECTIVE_OBS_FOUND";
        "GATE_EFFECTIVE_OBS_VALIDATED";
        "GATE_LEGACY_PT_MATRIX_FOUND";
        "GATE_OLD_BRANCH_PT_ONLY";
        "GATE_FALLBACK_FORBIDDEN";
        "GATE_TEMPERATURE_WINDOW";
        "GATE_NAMESPACE_BLOCKED"
    ];
    gateStatus = [
        SOURCE_VIEW_USED;
        SOURCE_VIEW_IS_CLEAN;
        "YES";
        EFFECTIVE_OBSERVABLE_INPUTS_FOUND;
        EFFECTIVE_OBSERVABLE_INPUTS_VALIDATED;
        LEGACY_PT_MATRIX_FOUND;
        OLD_AUTHORITATIVE_BRANCH_PT_ONLY;
        FALLBACK_ONLY_REPLAY_FORBIDDEN;
        TEMPERATURE_WINDOW_MATCHES_OLD_RECIPE;
        CORRECTED_OLD_AUTH_NAMESPACE_STILL_BLOCKED
    ];
    gateDetail = [
        "Read separated source view from contracts table.";
        "Checked forbidden columns and phi*/kappa* patterns.";
        "Readiness script does not consume canonical diagnostic columns as corrected-old evidence.";
        "Checked I_peak/S_peak/width availability.";
        "Checked validation_status from effective observable view.";
        "Checked provenance-locked legacy PT_matrix path.";
        "Checked provenance old_execution_mode and PT/fallback counts.";
        "Fallback-only replay remains forbidden by governance/spec.";
        "Compared source temperatures against old recipe T=4:2:30 and T<=30.";
        "Checked corrected-old blocked marker build_blocked=YES.";
    ];
    gatesTbl = table(gateId, gateStatus, gateDetail, 'VariableNames', {'gate_id','gate_status','gate_detail'});
    writetable(gatesTbl, gatesOutPath);

catch ME
    notes(end+1,1) = "Readiness check error: " + string(ME.message); %#ok<AGROW>
    SOURCE_VIEW_USED = "NO";
    SAFE_TO_IMPLEMENT_FULL_BUILDER = "NO";
    SAFE_TO_RUN_FULL_BUILDER = "NO";
end

statusKey = [
    "READINESS_ONLY_SCRIPT_IMPLEMENTED";
    "SOURCE_VIEW_USED";
    "SOURCE_VIEW_IS_CLEAN";
    "CANON_GEN_DIAGNOSTIC_OUTPUTS_USED";
    "EFFECTIVE_OBSERVABLE_INPUTS_FOUND";
    "EFFECTIVE_OBSERVABLE_INPUTS_VALIDATED";
    "LEGACY_PT_MATRIX_FOUND";
    "OLD_AUTHORITATIVE_BRANCH_PT_ONLY";
    "FALLBACK_ONLY_REPLAY_FORBIDDEN";
    "TEMPERATURE_WINDOW_MATCHES_OLD_RECIPE";
    "CORRECTED_OLD_AUTH_NAMESPACE_STILL_BLOCKED";
    "SAFE_TO_IMPLEMENT_FULL_BUILDER";
    "SAFE_TO_RUN_FULL_BUILDER";
    "PHYSICS_ARTIFACTS_GENERATED";
    "PHYSICS_LOGIC_CHANGED";
    "FILES_DELETED"
];
statusVal = [
    READINESS_ONLY_SCRIPT_IMPLEMENTED;
    SOURCE_VIEW_USED;
    SOURCE_VIEW_IS_CLEAN;
    CANON_GEN_DIAGNOSTIC_OUTPUTS_USED;
    EFFECTIVE_OBSERVABLE_INPUTS_FOUND;
    EFFECTIVE_OBSERVABLE_INPUTS_VALIDATED;
    LEGACY_PT_MATRIX_FOUND;
    OLD_AUTHORITATIVE_BRANCH_PT_ONLY;
    FALLBACK_ONLY_REPLAY_FORBIDDEN;
    TEMPERATURE_WINDOW_MATCHES_OLD_RECIPE;
    CORRECTED_OLD_AUTH_NAMESPACE_STILL_BLOCKED;
    SAFE_TO_IMPLEMENT_FULL_BUILDER;
    SAFE_TO_RUN_FULL_BUILDER;
    PHYSICS_ARTIFACTS_GENERATED;
    PHYSICS_LOGIC_CHANGED;
    FILES_DELETED
];

statusDetails = strings(size(statusKey));
for iS = 1:numel(statusKey)
    statusDetails(iS) = "";
end
if ~isempty(notes)
    statusDetails(1) = strjoin(notes, ' | ');
end

statusTbl = table(statusKey, statusVal, statusDetails, 'VariableNames', {'status_key','status_value','details'});
writetable(statusTbl, statusOutPath);

fid = fopen(reportOutPath, 'w');
if fid >= 0
    fprintf(fid, '# Switching corrected-old builder readiness check\n\n');
    fprintf(fid, '- Mode: readiness-only\n');
    fprintf(fid, '- Source view path: `%s`\n', char(sourceViewPath));
    fprintf(fid, '- Effective view path: `%s`\n', char(effectiveViewPath));
    fprintf(fid, '- Source run id: `%s`\n\n', char(sourceViewRunId));

    fprintf(fid, '## Required verdicts\n\n');
    for iS = 1:height(statusTbl)
        fprintf(fid, '- %s=%s\n', statusTbl.status_key(iS), statusTbl.status_value(iS));
    end

    fprintf(fid, '\n## Artifacts\n\n');
    fprintf(fid, '- `%s`\n', inputsOutPath);
    fprintf(fid, '- `%s`\n', gatesOutPath);
    fprintf(fid, '- `%s`\n', statusOutPath);
    fprintf(fid, '- `%s`\n', windowOutPath);

    if ~isempty(notes)
        fprintf(fid, '\n## Notes\n\n');
        for iN = 1:numel(notes)
            fprintf(fid, '- %s\n', notes(iN));
        end
    end

    fclose(fid);
end
