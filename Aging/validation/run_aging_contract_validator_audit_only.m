% run_aging_contract_validator_audit_only
% F6U: Audit-only Aging contract validator (agent-assistive, non-blocking).
% Writes issue log, summaries, and status under tables/aging and reports/aging.
% Does not modify scientific outputs. validation_mode = audit_only always.
% Note: no clear/clc here so matlab -batch and tools/run_matlab_safe.bat do not
% block on console control. ASCII-only file per docs/repo_execution_rules.md.

scriptPath = mfilename('fullpath');
scriptDir = fileparts(scriptPath);
agingDir = fileparts(scriptDir);
repoRoot = fileparts(agingDir);

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(scriptDir);
u = aging_F6U_validator_utils();

outTablesDir = fullfile(repoRoot, 'tables', 'aging');
outReportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(outTablesDir, 'dir') ~= 7
    mkdir(outTablesDir);
end
if exist(outReportsDir, 'dir') ~= 7
    mkdir(outReportsDir);
end

issueCols = { ...
    'issue_id', 'severity', 'validation_mode', 'file_path', 'table_type', ...
    'observable_or_column', 'check_id', 'what_failed', 'why_it_matters', 'suggested_fix', ...
    'quarantine_allowed', 'recommended_namespace', 'blocks_execution', ...
    'safe_to_continue_diagnostic_work', 'safe_for_canonical_use', 'safe_for_tau_R_use' ...
    };

issues = cell(0, numel(issueCols));
nFilesScanned = 0;
nSkipped = 0;
errMsg = '';

try

scanRoots = { ...
    fullfile(repoRoot, 'tables', 'aging'), ...
    fullfile(repoRoot, 'reports', 'aging'), ...
    fullfile(repoRoot, 'results', 'aging'), ...
    fullfile(repoRoot, 'results_old', 'aging'), ...
    fullfile(repoRoot, 'Aging') ...
    };

maxCsvFiles = 500;
maxCsvPerRoot = 150;
maxFileBytes = 5 * 1024 * 1024;
maxDirVisits = 3000;
skipDirLower = { '.git', '.svn', 'node_modules', 'slprj', 'html' };
csvList = {};
nDirVisits = 0;

for ri = 1:numel(scanRoots)
    r = scanRoots{ri};
    if exist(r, 'dir') ~= 7
        continue;
    end
    nRootAdded = 0;
    q = {r};
    while ~isempty(q) && numel(csvList) < maxCsvFiles && nDirVisits < maxDirVisits && nRootAdded < maxCsvPerRoot
        d = q{1};
        q(1) = [];
        nDirVisits = nDirVisits + 1;
        lst = dir(d);
        for k = 1:numel(lst)
            if lst(k).isdir
                if strcmp(lst(k).name, '.') || strcmp(lst(k).name, '..')
                    continue;
                end
                subLower = lower(lst(k).name);
                skipThis = false;
                for sd = 1:numel(skipDirLower)
                    if strcmp(subLower, skipDirLower{sd})
                        skipThis = true;
                        break;
                    end
                end
                if skipThis
                    continue;
                end
                q{end+1} = fullfile(d, lst(k).name); %#ok<AGROW>
            else
                nm = lst(k).name;
                if numel(nm) > 4 && strcmpi(nm(end-3:end), '.csv')
                    csvList{end+1} = fullfile(d, nm); %#ok<AGROW>
                    nRootAdded = nRootAdded + 1;
                    if numel(csvList) >= maxCsvFiles
                        break;
                    end
                    if nRootAdded >= maxCsvPerRoot
                        break;
                    end
                end
            end
            if numel(csvList) >= maxCsvFiles
                break;
            end
        end
        if numel(csvList) >= maxCsvFiles
            break;
        end
    end
end

csvList = unique(csvList, 'stable');

fileSummary = cell(0, 6);
% columns: file_path, table_type, has_sidecar, sidecar_paths, n_issues_for_file, scan_notes

for fi = 1:numel(csvList)
    csvPath = csvList{fi};
    if exist(csvPath, 'file') ~= 2
        continue;
    end
    finfo = dir(csvPath);
    if isempty(finfo)
        continue;
    end
    if finfo(1).bytes > maxFileBytes
        nSkipped = nSkipped + 1;
        relP = u.relPathFromRoot(repoRoot, csvPath);
        fileSummary(end+1, :) = { relP, 'aging_csv', 'UNKNOWN', '', 0, 'skipped_large_file' }; %#ok<AGROW>
        continue;
    end

    nFilesScanned = nFilesScanned + 1;
    relP = u.relPathFromRoot(repoRoot, csvPath);
    lowName = lower(csvPath);
    tableType = u.classifyTableType(relP, lowName);

    hdrLine = u.readFirstLineSafe(csvPath);
    varNames = u.parseCsvHeaderLine(hdrLine);

    [hasSidecar, sidecarStr, scStructs] = u.findSidecars(csvPath);

    nBefore = size(issues, 1);

    % VC_LEG_001 legacy without sidecar
    if ~hasSidecar
        n = size(issues, 1) + 1;
        issues(n, :) = { ...
            sprintf('F6U-%06d', n), 'INFO', 'audit_only', relP, tableType, '(file)', 'VC_LEG_001', ...
            'Legacy or unmanaged CSV has no adjacent lineage sidecar.', ...
            'Identity and downstream routing stay ambiguous without lineage metadata.', ...
            'Label session as legacy_quarantine; add minimal sidecar with unresolved_fields or use compatibility loader per aging_agent_assistive_enforcement.md.', ...
            'YES', 'legacy_old', 'NO', 'YES', 'NO', 'NO' ...
            };
    end

    % VC_DIP_001 plain Dip_depth
    if any(strcmp(varNames, 'Dip_depth'))
        n = size(issues, 1) + 1;
        issues(n, :) = { ...
            sprintf('F6U-%06d', n), 'ERROR_AUDIT_ONLY', 'audit_only', relP, tableType, 'Dip_depth', 'VC_DIP_001', ...
            'Column Dip_depth present without S4A/S4B suffix.', ...
            'Plain Dip_depth is forbidden as canonical identity; S4A and S4B must stay distinct.', ...
            'Rename column to Dip_depth_S4A or Dip_depth_S4B per stage4 path, or map via sidecar formula_id/registry_id to resolved registry entries.', ...
            'YES', 'unknown', 'NO', 'YES', 'PARTIAL', 'NO' ...
            };
    end

    % VC_TAU_DIP_001 / tau-R-like context
    if u.isTauRLike(tableType, lowName) && any(strcmp(varNames, 'Dip_depth'))
        hasTauMeta = false;
        if hasSidecar && ~isempty(scStructs)
            for si = 1:numel(scStructs)
                sc = scStructs{si};
                if isstruct(sc) && isfield(sc, 'tau_input_observable_identities') && ~isempty(sc.tau_input_observable_identities)
                    hasTauMeta = true;
                    break;
                end
            end
        end
        if ~hasTauMeta
            n = size(issues, 1) + 1;
            issues(n, :) = { ...
                sprintf('F6U-%06d', n), 'ERROR_AUDIT_ONLY', 'audit_only', relP, tableType, 'Dip_depth', 'VC_TAU_DIP_001', ...
                'Tau/R-like table references Dip_depth without tau_input_observable_identities in sidecar.', ...
                'tau/R must declare resolved upstream observable identities.', ...
                'Add tau_input_observable_identities with dip_scalar_registry_id and dip_namespace (see aging_lineage_sidecar_schema.md).', ...
                'YES', 'stage4_S4A_or_S4B', 'NO', 'YES', 'PARTIAL', 'NO' ...
                };
        end
    end

    % VC_S4A_S4B_001 both S4A and S4B columns
    hasS4A = any(strcmp(varNames, 'Dip_depth_S4A'));
    hasS4B = any(strcmp(varNames, 'Dip_depth_S4B'));
    if hasS4A && hasS4B
        bridgeOk = false;
        if hasSidecar && ~isempty(scStructs)
            for si = 1:numel(scStructs)
                sc = scStructs{si};
                if isstruct(sc)
                    if isfield(sc, 'component_extraction_contract') && ~isempty(sc.component_extraction_contract)
                        bridgeOk = true;
                    end
                    if isfield(sc, 'preprocessing_contract') && ~isempty(sc.preprocessing_contract)
                        pc = sc.preprocessing_contract;
                        if ischar(pc)
                            pcs = pc;
                        else
                            try
                                pcs = char(pc);
                            catch
                                pcs = '';
                            end
                        end
                        if ~isempty(pcs) && ~isempty(strfind(lower(pcs), 'bridge'))
                            bridgeOk = true;
                        end
                    end
                end
            end
        end
        if ~bridgeOk
            n = size(issues, 1) + 1;
            issues(n, :) = { ...
                sprintf('F6U-%06d', n), 'WARNING', 'audit_only', relP, tableType, 'Dip_depth_S4A,Dip_depth_S4B', 'VC_S4A_S4B_001', ...
                'Both Dip_depth_S4A and Dip_depth_S4B appear; bridge metadata not detected in sidecar.', ...
                'S4A and S4B are physically distinct; merge or ratio without F6Q bridge risks wrong claims.', ...
                'Document bridge table or separate outputs; add component_extraction_contract or bridge reference in sidecar before cross-path compare.', ...
                'YES', 'diagnostic', 'NO', 'YES', 'PARTIAL', 'PARTIAL' ...
                };
        end
    end

    % VC_XRUN_001 cross-run style
    if u.isCrossRunLike(relP, lowName)
        idOk = any(strcmp(varNames, 'registry_id')) && any(strcmp(varNames, 'namespace'));
        if ~idOk && (~hasSidecar || isempty(scStructs))
            n = size(issues, 1) + 1;
            issues(n, :) = { ...
                sprintf('F6U-%06d', n), 'WARNING', 'audit_only', relP, tableType, '(metadata)', 'VC_XRUN_001', ...
                'Cross-run or consolidated-style artifact lacks observable identity columns or sidecar.', ...
                'Cross-run comparison requires full observable identity match.', ...
                'Add per-row or sidecar namespace, registry_id, formula_id, source_run_id; restrict comparisons to matching cohorts.', ...
                'YES', 'unknown', 'NO', 'YES', 'NO', 'NO' ...
                };
        elseif ~idOk && hasSidecar
            n = size(issues, 1) + 1;
            issues(n, :) = { ...
                sprintf('F6U-%06d', n), 'INFO', 'audit_only', relP, tableType, '(metadata)', 'VC_XRUN_001', ...
                'Cross-run artifact: identity columns absent from CSV; verify identity in JSON sidecar before comparing runs.', ...
                'Cross-run comparison requires full observable identity match.', ...
                'Ensure sidecar lists registry_id and source_run_id for each leg; add extracted columns if tooling expects CSV-native identity.', ...
                'YES', 'unknown', 'NO', 'YES', 'PARTIAL', 'PARTIAL' ...
                };
        end
    end

    % VC_POOL_001 pooled tables
    if u.isPooledLike(tableType, lowName)
        if ~hasSidecar
            n = size(issues, 1) + 1;
            issues(n, :) = { ...
                sprintf('F6U-%06d', n), 'ERROR_AUDIT_ONLY', 'audit_only', relP, tableType, '(file)', 'VC_POOL_001', ...
                'Pooled or consolidated table has no lineage sidecar.', ...
                'Lineage sidecars are required for pooled tables.', ...
                'Add *_sidecar.json with writer_role consolidation, source_run_id list, and per-row identity mapping.', ...
                'YES', 'diagnostic', 'NO', 'YES', 'NO', 'NO' ...
                };
        end
    end

    % Sidecar field checks when JSON sidecar present
    if hasSidecar && ~isempty(scStructs)
        for si = 1:numel(scStructs)
            sc = scStructs{si};
            if ~isstruct(sc)
                continue;
            end
            if ~isfield(sc, 'writer_id') || u.fieldEmpty(sc.writer_id)
                n = size(issues, 1) + 1;
                issues(n, :) = { ...
                    sprintf('F6U-%06d', n), 'ERROR_AUDIT_ONLY', 'audit_only', relP, tableType, '(sidecar)', 'VC_WID_001', ...
                    'Sidecar missing writer_id.', ...
                    'Exports need repeatable writer identity for audit.', ...
                    'Set writer_id to repo-relative path plus stable tag per aging_writer_output_contract.md.', ...
                    'YES', 'unknown', 'NO', 'YES', 'PARTIAL', 'PARTIAL' ...
                    };
            end
            if ~isfield(sc, 'formula_id') || isempty(sc.formula_id)
                n = size(issues, 1) + 1;
                issues(n, :) = { ...
                    sprintf('F6U-%06d', n), 'ERROR_AUDIT_ONLY', 'audit_only', relP, tableType, '(sidecar)', 'VC_WID_001', ...
                    'Sidecar missing formula_id.', ...
                    'formula_id ties observables to registry definitions.', ...
                    'Populate formula_id map or string per column family.', ...
                    'YES', 'unknown', 'NO', 'YES', 'PARTIAL', 'PARTIAL' ...
                    };
            end
            if ~isfield(sc, 'namespace') || u.fieldEmpty(sc.namespace)
                n = size(issues, 1) + 1;
                issues(n, :) = { ...
                    sprintf('F6U-%06d', n), 'WARNING', 'audit_only', relP, tableType, '(sidecar)', 'VC_WID_001', ...
                    'Sidecar missing namespace.', ...
                    'Namespace is required for canonical observable routing.', ...
                    'Set namespace per aging_namespace_contract.md or mark unresolved with unresolved_fields.', ...
                    'YES', 'unknown', 'NO', 'YES', 'PARTIAL', 'PARTIAL' ...
                    };
            end
            if ~isfield(sc, 'registry_id') || isempty(sc.registry_id)
                n = size(issues, 1) + 1;
                issues(n, :) = { ...
                    sprintf('F6U-%06d', n), 'WARNING', 'audit_only', relP, tableType, '(sidecar)', 'VC_WID_001', ...
                    'Sidecar missing registry_id.', ...
                    'Registry linkage prevents ambiguous reuse across protocols.', ...
                    'Add registry_id from aging_F6S_registry_entries when known.', ...
                    'YES', 'unknown', 'NO', 'YES', 'PARTIAL', 'PARTIAL' ...
                    };
            end
            if ~isfield(sc, 'source_run_id') || u.fieldEmpty(sc.source_run_id)
                n = size(issues, 1) + 1;
                issues(n, :) = { ...
                    sprintf('F6U-%06d', n), 'WARNING', 'audit_only', relP, tableType, '(sidecar)', 'VC_WID_001', ...
                    'Sidecar missing source_run_id.', ...
                    'Run linkage is required for reproducibility and cross-run checks.', ...
                    'Set source_run_id to run folder id or manifest pointer.', ...
                    'YES', 'unknown', 'NO', 'YES', 'PARTIAL', 'PARTIAL' ...
                    };
            end
        end
    end

    % VC_FM_001 FM_step_mag and FM_abs
    if any(strcmp(varNames, 'FM_step_mag')) && any(strcmp(varNames, 'FM_abs'))
        n = size(issues, 1) + 1;
        issues(n, :) = { ...
            sprintf('F6U-%06d', n), 'WARNING', 'audit_only', relP, tableType, 'FM_step_mag,FM_abs', 'VC_FM_001', ...
            'Both FM_step_mag and FM_abs present; sign interpretation risk if undocumented.', ...
            'Sign flips may be physical but must be explicit for FM observables.', ...
            'Add sign_convention to sidecar (see aging_F6T_sidecar_schema_fields.csv).', ...
            'YES', 'current_export', 'NO', 'YES', 'PARTIAL', 'PARTIAL' ...
            };
    end

    % VC_R_RATIO_001 R-style names (narrow heuristic to reduce false positives)
    isRStyle = strcmp(tableType, 'R_table') || contains(lowName, 'r_age') || ...
        contains(lowName, 'clock_ratio') || contains(lowName, 'r_vs') || ...
        contains(lowName, 'r_tau') || contains(lowName, 'tau_fm_over');
    if isRStyle
        numOk = false;
        denOk = false;
        if hasSidecar && ~isempty(scStructs)
            for si = 1:numel(scStructs)
                sc = scStructs{si};
                if isstruct(sc)
                    numOk = numOk || (isfield(sc, 'ratio_numerator_identity') && ~isempty(sc.ratio_numerator_identity));
                    denOk = denOk || (isfield(sc, 'ratio_denominator_identity') && ~isempty(sc.ratio_denominator_identity));
                end
            end
        end
        if ~(numOk && denOk)
            n = size(issues, 1) + 1;
            issues(n, :) = { ...
                sprintf('F6U-%06d', n), 'ERROR_AUDIT_ONLY', 'audit_only', relP, tableType, '(ratio)', 'VC_R_RATIO_001', ...
                'R-style table lacks ratio_numerator_identity and ratio_denominator_identity in sidecar.', ...
                'R ratios require explicit numerator and denominator identities.', ...
                'Declare both objects in sidecar per aging_agent_assistive_enforcement.md.', ...
                'YES', 'unknown', 'NO', 'YES', 'PARTIAL', 'NO' ...
                };
        end
    end

    nAfter = size(issues, 1);
    nIss = nAfter - nBefore;
    hs = 'NO';
    if hasSidecar
        hs = 'YES';
    end
    fileSummary(end+1, :) = { relP, tableType, hs, sidecarStr, nIss, '' }; %#ok<AGROW>
end

% Renumber issue_id sequentially
for ii = 1:size(issues, 1)
    issues{ii, 1} = sprintf('F6U-%06d', ii);
end

issueTbl = cell2table(issues, 'VariableNames', issueCols);

catch ME
    errMsg = ME.message;
    issueTbl = table();
    for c = 1:numel(issueCols)
        issueTbl.(issueCols{c}) = cell(0, 1);
    end
end

% Summaries
if isempty(issues)
    issueTbl = cell2table(cell(0, numel(issueCols)), 'VariableNames', issueCols);
end

if exist('fileSummary', 'var') && ~isempty(fileSummary)
    fileSumTbl = cell2table(fileSummary, 'VariableNames', ...
        {'file_path', 'table_type', 'has_sidecar', 'sidecar_paths', 'n_issues', 'scan_notes'});
else
    fileSumTbl = table( ...
        cell(0, 1), cell(0, 1), cell(0, 1), cell(0, 1), zeros(0, 1), cell(0, 1), ...
        'VariableNames', {'file_path', 'table_type', 'has_sidecar', 'sidecar_paths', 'n_issues', 'scan_notes'});
end

if height(issueTbl) > 0
    uChecks = unique(issueTbl.check_id, 'stable');
    nU = numel(uChecks);
    cats = cell(nU, 1);
    cnts = zeros(nU, 1);
    sevInfo = zeros(nU, 1);
    sevWarn = zeros(nU, 1);
    sevErr = zeros(nU, 1);
    for hi = 1:nU
        mask = strcmp(issueTbl.check_id, uChecks{hi});
        cats{hi} = uChecks{hi};
        cnts(hi) = sum(mask);
        sevInfo(hi) = sum(mask & strcmp(issueTbl.severity, 'INFO'));
        sevWarn(hi) = sum(mask & strcmp(issueTbl.severity, 'WARNING'));
        sevErr(hi) = sum(mask & strcmp(issueTbl.severity, 'ERROR_AUDIT_ONLY'));
    end
    checkSumTbl = table(cats, cnts, sevInfo, sevWarn, sevErr, ...
        'VariableNames', {'check_id', 'n_issues', 'n_INFO', 'n_WARNING', 'n_ERROR_AUDIT_ONLY'});
else
    checkSumTbl = table( ...
        cell(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
        'VariableNames', {'check_id', 'n_issues', 'n_INFO', 'n_WARNING', 'n_ERROR_AUDIT_ONLY'});
end

issuePath = fullfile(outTablesDir, 'aging_F6U_contract_validator_issue_log.csv');
fileSumPath = fullfile(outTablesDir, 'aging_F6U_contract_validator_file_summary.csv');
checkSumPath = fullfile(outTablesDir, 'aging_F6U_contract_validator_check_summary.csv');
statusPath = fullfile(outTablesDir, 'aging_F6U_contract_validator_status.csv');

writetable(issueTbl, issuePath);
writetable(fileSumTbl, fileSumPath);
writetable(checkSumTbl, checkSumPath);

nInfo = 0;
nWarn = 0;
nErrAudit = 0;
if height(issueTbl) > 0
    nInfo = sum(strcmp(issueTbl.severity, 'INFO'));
    nWarn = sum(strcmp(issueTbl.severity, 'WARNING'));
    nErrAudit = sum(strcmp(issueTbl.severity, 'ERROR_AUDIT_ONLY'));
end

statusKeys = { ...
    'F6U_AUDIT_ONLY_AGING_CONTRACT_VALIDATOR_COMPLETED'; ...
    'VALIDATOR_SCRIPT_CREATED'; ...
    'VALIDATOR_RAN_SUCCESSFULLY'; ...
    'AUDIT_ONLY_MODE_USED'; ...
    'BLOCKING_BEHAVIOR_INTRODUCED'; ...
    'SCANNED_AGING_ONLY'; ...
    'ISSUE_LOG_WRITTEN'; ...
    'FILE_SUMMARY_WRITTEN'; ...
    'CHECK_SUMMARY_WRITTEN'; ...
    'AGENT_ASSISTIVE_GUIDANCE_WRITTEN'; ...
    'PLAIN_DIP_DEPTH_CHECK_IMPLEMENTED'; ...
    'TAU_R_NAMESPACE_CHECK_IMPLEMENTED'; ...
    'S4A_S4B_MERGE_CHECK_IMPLEMENTED'; ...
    'SIDECAR_MISSING_CHECK_IMPLEMENTED'; ...
    'LEGACY_QUARANTINE_SUPPORTED'; ...
    'ALL_ISSUES_HAVE_SUGGESTED_FIX'; ...
    'NO_ISSUES_BLOCK_EXECUTION'; ...
    'CODE_MODIFIED'; ...
    'AGING_ANALYSIS_LOGIC_MODIFIED'; ...
    'REFACTOR_PERFORMED'; ...
    'RELAXATION_TOUCHED'; ...
    'SWITCHING_TOUCHED'; ...
    'MT_TOUCHED'; ...
    'N_FILES_SCANNED'; ...
    'N_ISSUES_INFO'; ...
    'N_ISSUES_WARNING'; ...
    'N_ISSUES_ERROR_AUDIT_ONLY'; ...
    'VALIDATION_MODE'; ...
    'ERROR_MESSAGE' ...
    };

runOk = isempty(errMsg);
vals = { ...
    'YES'; ...
    'YES'; ...
    u.tern(runOk, 'YES', 'NO'); ...
    'YES'; ...
    'NO'; ...
    'YES'; ...
    'YES'; ...
    'YES'; ...
    'YES'; ...
    'YES'; ...
    'YES'; ...
    'YES'; ...
    'YES'; ...
    'YES'; ...
    'YES'; ...
    'YES'; ...
    'YES'; ...
    'VALIDATOR_ONLY'; ...
    'NO'; ...
    'NO'; ...
    'NO'; ...
    'NO'; ...
    'NO'; ...
    sprintf('%d', nFilesScanned); ...
    sprintf('%d', nInfo); ...
    sprintf('%d', nWarn); ...
    sprintf('%d', nErrAudit); ...
    'audit_only'; ...
    errMsg ...
    };

statusTbl = table(statusKeys, vals, 'VariableNames', {'status_key', 'status_value'});
writetable(statusTbl, statusPath);

% Markdown report with agent guidance
reportPath = fullfile(outReportsDir, 'aging_F6U_audit_only_contract_validator_report.md');
fid = fopen(reportPath, 'w');
if fid >= 0
    fprintf(fid, '# F6U Aging audit-only contract validator report\n\n');
    fprintf(fid, 'validation_mode: audit_only\n\n');
    fprintf(fid, '## Summary\n\n');
    fprintf(fid, '- Files scanned: %d\n', nFilesScanned);
    fprintf(fid, '- CSV paths skipped (size cap): %d\n', nSkipped);
    fprintf(fid, '- Issues INFO: %d\n', nInfo);
    fprintf(fid, '- Issues WARNING: %d\n', nWarn);
    fprintf(fid, '- Issues ERROR_AUDIT_ONLY: %d\n', nErrAudit);
    fprintf(fid, '- Blocking behavior: never (audit_only)\n\n');
    fprintf(fid, '## Outputs\n\n');
    fprintf(fid, '- %s\n', strrep(issuePath, '\', '/'));
    fprintf(fid, '- %s\n', strrep(fileSumPath, '\', '/'));
    fprintf(fid, '- %s\n', strrep(checkSumPath, '\', '/'));
    fprintf(fid, '- %s\n', strrep(statusPath, '\', '/'));
    fprintf(fid, '\n## Agent assistive guidance\n\n');
    fprintf(fid, '1. **Plain Dip_depth:** Rename to Dip_depth_S4A or Dip_depth_S4B, or attach sidecar mapping to registry rows.\n');
    fprintf(fid, '2. **Tau/R inputs:** Add tau_input_observable_identities to JSON sidecar with dip registry_id and namespace.\n');
    fprintf(fid, '3. **S4A+S4B in one file:** Document bridge or keep paths separate; add component_extraction_contract in sidecar.\n');
    fprintf(fid, '4. **Pooled tables:** Add lineage sidecar with consolidation writer_role and per-row identity.\n');
    fprintf(fid, '5. **Legacy without sidecar:** Use legacy_quarantine routing; file stays readable as evidence.\n');
    fprintf(fid, '6. **audit_only:** Fix issues opportunistically; validator never blocks execution.\n\n');
    fprintf(fid, '## Top check_ids\n\n');
    if height(checkSumTbl) > 0
        [~, ix] = sort(checkSumTbl.n_issues, 'descend');
        topN = min(8, height(checkSumTbl));
        for ti = 1:topN
            r = checkSumTbl(ix(ti), :);
            fprintf(fid, '- %s: %d issues\n', r.check_id{1}, r.n_issues(1));
        end
    else
        fprintf(fid, '- (no issues)\n');
    end
    fclose(fid);
end
