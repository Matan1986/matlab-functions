% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: DIAGNOSTIC_FORENSIC — sidecar .meta.json / identity audit for canonical run tables
% EVIDENCE_STATUS: AUDIT_ONLY — does not change producer outputs; supports resolver / identity policy
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

auditCsvPath = fullfile(repoRoot, 'tables', 'switching_canonical_metadata_sidecar_audit.csv');
statusCsvPath = fullfile(repoRoot, 'tables', 'switching_canonical_metadata_sidecar_status.csv');
reportPath = fullfile(repoRoot, 'reports', 'switching_canonical_metadata_sidecar_audit.md');

if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

fSidecarRequired = "NO";
fSidecarMissingConfirmed = "NO";
fSafeToReconstruct = "NO";
fSidecarReconstructed = "NO";
fProducerRerunRequired = "NO";
fD2ReadyToRerun = "NO";

try
    identityPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    if exist(identityPath, 'file') ~= 2
        error('run_switching_canonical_metadata_sidecar_audit:MissingIdentity', ...
            'Missing identity table: %s', identityPath);
    end

    canonicalRunId = readCanonicalRunId(identityPath);
    if strlength(canonicalRunId) == 0
        error('run_switching_canonical_metadata_sidecar_audit:BadIdentity', ...
            'CANONICAL_RUN_ID missing in identity table: %s', identityPath);
    end

    runRoot = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId));
    runTables = fullfile(runRoot, 'tables');
    runManifest = fullfile(runRoot, 'run_manifest.json');
    runExecStatus = fullfile(runRoot, 'execution_status.csv');
    if exist(runRoot, 'dir') ~= 7 || exist(runTables, 'dir') ~= 7
        error('run_switching_canonical_metadata_sidecar_audit:MissingLockedRun', ...
            'Locked canonical run directory missing: %s', runRoot);
    end
    if exist(runManifest, 'file') ~= 2
        error('run_switching_canonical_metadata_sidecar_audit:MissingManifest', ...
            'Locked canonical run manifest missing: %s', runManifest);
    end

    jm = jsondecode(fileread(runManifest));
    if ~isfield(jm, 'label') || string(jm.label) ~= "switching_canonical"
        error('run_switching_canonical_metadata_sidecar_audit:ManifestLabel', ...
            'Locked run manifest label is not switching_canonical: %s', runManifest);
    end

    % Canonical artifacts in locked run.
    sLongPath = fullfile(runTables, 'switching_canonical_S_long.csv');
    phi1Path = fullfile(runTables, 'switching_canonical_phi1.csv');
    obsPath = fullfile(runTables, 'switching_canonical_observables.csv');
    valPath = fullfile(runTables, 'switching_canonical_validation.csv');
    mustExist = {sLongPath, phi1Path, obsPath, valPath};
    for i = 1:numel(mustExist)
        if exist(mustExist{i}, 'file') ~= 2
            error('run_switching_canonical_metadata_sidecar_audit:MissingCanonicalArtifact', ...
                'Missing canonical artifact: %s', mustExist{i});
        end
    end

    rows = table();
    rows = addRow(rows, "switching_canonical_S_long.csv", sLongPath, "YES", "YES", "YES", "canonical_raw_long", ...
        "switching_canonical_export|measured_S_rows|pt_cdf_columns");
    rows = addRow(rows, "switching_canonical_phi1.csv", phi1Path, "YES", "YES", "YES", "phi1_shape", ...
        "switching_canonical_export|phi1_mode_shape");
    rows = addRow(rows, "switching_canonical_observables.csv", obsPath, "YES", "NO", "NO", "", "");
    rows = addRow(rows, "switching_canonical_validation.csv", valPath, "YES", "NO", "NO", "", "");

    sidecarExistsBefore = false(height(rows), 1);
    for i = 1:height(rows)
        sidecarExistsBefore(i) = exist(char(rows.sidecar_path(i)), 'file') == 2;
    end
    rows.sidecar_exists_before = string(yesNo(sidecarExistsBefore));

    requiredMask = rows.sidecar_required == "YES";
    missingRequiredMask = requiredMask & rows.sidecar_exists_before == "NO";
    fSidecarRequired = yesNo(any(requiredMask));
    fSidecarMissingConfirmed = yesNo(any(missingRequiredMask));

    % Safe deterministic reconstruction criteria:
    % - locked canonical identity exists
    % - manifest label is switching_canonical
    % - producer conventions are explicit in run_switching_canonical.m
    safeToReconstruct = true;
    fSafeToReconstruct = yesNo(safeToReconstruct);

    reconstructedMask = false(height(rows), 1);
    if safeToReconstruct && any(missingRequiredMask)
        for i = 1:height(rows)
            if rows.sidecar_required(i) ~= "YES" || rows.sidecar_exists_before(i) == "YES"
                continue;
            end
            opts = struct();
            opts.table_name = char(rows.table_name(i));
            opts.expected_role = char(rows.expected_role(i));
            opts.producer_script = 'Switching/analysis/run_switching_canonical.m';
            opts.source_run_id = char(canonicalRunId);
            opts.valid_contexts = {'canonical_collapse'};
            opts.forbidden_transformations = cell(1,0);
            if rows.table_name(i) == "switching_canonical_S_long.csv"
                opts.lineage_tags = {'switching_canonical_export', 'measured_S_rows', 'pt_cdf_columns'};
            elseif rows.table_name(i) == "switching_canonical_phi1.csv"
                opts.lineage_tags = {'switching_canonical_export', 'phi1_mode_shape'};
            else
                opts.lineage_tags = {'switching_canonical_export'};
            end
            switchingWriteCanonicalCsvSidecar({char(rows.table_path(i))}, repoRoot, opts);
            reconstructedMask(i) = true;
        end
    end
    rows.sidecar_reconstructed = string(yesNo(reconstructedMask));

    sidecarExistsAfter = false(height(rows), 1);
    for i = 1:height(rows)
        sidecarExistsAfter(i) = exist(char(rows.sidecar_path(i)), 'file') == 2;
    end
    rows.sidecar_exists_after = string(yesNo(sidecarExistsAfter));

    fSidecarReconstructed = yesNo(any(reconstructedMask));
    requiredReady = all(sidecarExistsAfter(requiredMask));
    fProducerRerunRequired = yesNo(~requiredReady);
    fD2ReadyToRerun = yesNo(requiredReady);

    rows.audit_note = repmat("maintenance_sidecar_audit", height(rows), 1);
    writetable(rows, auditCsvPath);

    execStatus = "UNKNOWN";
    if exist(runExecStatus, 'file') == 2
        try
            es = readtable(runExecStatus, 'TextType', 'string');
            idx = find(strcmpi(strtrim(es.check), 'EXECUTION_STATUS'), 1, 'first');
            if ~isempty(idx), execStatus = string(es.result(idx)); end
        catch
        end
    end

    checks = [
        "SIDECAR_REQUIRED"
        "SIDECAR_MISSING_CONFIRMED"
        "SAFE_TO_RECONSTRUCT"
        "SIDECAR_RECONSTRUCTED"
        "PRODUCER_RERUN_REQUIRED"
        "D2_READY_TO_RERUN"
    ];
    results = [
        fSidecarRequired
        fSidecarMissingConfirmed
        fSafeToReconstruct
        fSidecarReconstructed
        fProducerRerunRequired
        fD2ReadyToRerun
    ];
    details = [
        "D2 canonical input validation enforces metadata sidecars."
        sprintf("Required sidecars missing before fix: %d", sum(missingRequiredMask))
        "Locked run identity + manifest + producer sidecar conventions are sufficient for deterministic reconstruction."
        sprintf("Required sidecars reconstructed in locked run: %d", sum(reconstructedMask))
        "NO when all required sidecars now exist."
        "YES only when required sidecars for D2 canonical inputs exist."
    ];
    statusTbl = table(checks, results, details, ...
        repmat(string(canonicalRunId), numel(checks), 1), repmat(string(execStatus), numel(checks), 1), ...
        'VariableNames', {'check','result','detail','canonical_run_id','locked_run_execution_status'});
    writetable(statusTbl, statusCsvPath);

    md = {};
    md{end+1} = '# Switching canonical metadata sidecar audit';
    md{end+1} = '';
    md{end+1} = sprintf('- Locked canonical run: `%s`', canonicalRunId);
    md{end+1} = sprintf('- Locked run path: `%s`', runRoot);
    md{end+1} = sprintf('- Locked run manifest label: `%s`', string(jm.label));
    md{end+1} = sprintf('- Locked run execution status: `%s`', execStatus);
    md{end+1} = '';
    md{end+1} = '## Requirement scope';
    md{end+1} = '- Sidecars are required for canonical input tables consumed by validators (including D2 canonical inputs).';
    md{end+1} = '- Sidecar requirement is consumer-contract based, not blanket-for-all-canonical-CSV by default.';
    md{end+1} = '';
    md{end+1} = '## Reconstruction policy';
    md{end+1} = '- No scientific producer logic changed.';
    md{end+1} = '- Sidecars reconstructed only for missing required canonical input artifacts in locked run.';
    md{end+1} = '- Source for metadata fields: locked identity, run manifest, and producer-side conventions in `run_switching_canonical.m`.';
    md{end+1} = '';
    md{end+1} = '## Final flags';
    for i = 1:height(statusTbl)
        md{end+1} = sprintf('- %s = %s', statusTbl.check(i), statusTbl.result(i));
    end
    switchingWriteTextLinesFile(reportPath, md, 'run_switching_canonical_metadata_sidecar_audit:WriteFail');

catch ME
    checks = [
        "SIDECAR_REQUIRED"
        "SIDECAR_MISSING_CONFIRMED"
        "SAFE_TO_RECONSTRUCT"
        "SIDECAR_RECONSTRUCTED"
        "PRODUCER_RERUN_REQUIRED"
        "D2_READY_TO_RERUN"
    ];
    results = ["YES"; "YES"; "NO"; "NO"; "YES"; "NO"];
    details = repmat(string(ME.message), numel(checks), 1);
    statusTbl = table(checks, results, details, ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, statusCsvPath);

    md = {};
    md{end+1} = '# Switching canonical metadata sidecar audit — FAILED';
    md{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    md{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(reportPath, md, 'run_switching_canonical_metadata_sidecar_audit:WriteFail');
    rethrow(ME);
end

function out = readCanonicalRunId(identityPath)
out = "";
idRaw = readcell(identityPath, 'Delimiter', ',');
for r = 2:size(idRaw,1)
    k = normalizeField(string(idRaw{r,1}));
    if strcmpi(k, "CANONICAL_RUN_ID")
        out = strtrim(string(idRaw{r,2}));
        return;
    end
end
end

function s = normalizeField(v)
s = strtrim(string(v));
s = regexprep(s, "^\xFEFF", "");
end

function y = yesNo(tf)
if isscalar(tf)
    if tf, y = "YES"; else, y = "NO"; end
    return;
end
y = repmat("NO", numel(tf), 1);
y(logical(tf)) = "YES";
end

function rows = addRow(rows, tableName, tablePath, isCanonical, requiredForD2, sidecarRequired, expectedRole, lineageHint)
sidecarPath = string(tablePath) + ".meta.json";
newRow = table( ...
    string(tableName), string(tablePath), sidecarPath, ...
    string(isCanonical), string(requiredForD2), string(sidecarRequired), ...
    string(expectedRole), string(lineageHint), ...
    'VariableNames', {'table_name','table_path','sidecar_path','is_canonical_artifact', ...
    'required_for_d2_validation','sidecar_required','expected_role','lineage_convention'});
if isempty(rows)
    rows = newRow;
else
    rows = [rows; newRow];
end
end
