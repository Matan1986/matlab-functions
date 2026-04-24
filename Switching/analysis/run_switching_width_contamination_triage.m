clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

try
    cfg = struct();
    cfg.runLabel = 'switching_width_contamination_triage';
    cfg.dataset = 'width_contamination_critical_isolation';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0, fprintf(fidTop, 'SCRIPT_ENTERED\n'); fclose(fidTop); end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    propPath = fullfile(repoRoot, 'tables', 'switching_width_contamination_propagation.csv');
    priPath = fullfile(repoRoot, 'tables', 'switching_width_contamination_priority.csv');
    if exist(propPath, 'file') ~= 2 || exist(priPath, 'file') ~= 2
        error('run_switching_width_contamination_triage:MissingInput', ...
            'Missing propagation/priority tables required for triage.');
    end

    propCols = {'downstream_artifact','upstream_source','contamination_path','affects_current_canonical_results','severity','note'};
    priCols = {'item_id','file_or_artifact','classification','severity','why_it_matters','recommended_next_action'};
    prop = readKnownCsv(propPath, propCols);
    pri = readKnownCsv(priPath, priCols);

    % Step 1: active contamination filter.
    aff = string(prop.affects_current_canonical_results);
    propActiveMask = aff == "YES" | aff == "PARTIAL";
    propA = prop(propActiveMask, :);

    cls = string(pri.classification);
    priActiveMask = cls == "CURRENT_CANONICAL_CONTAMINATION" | cls == "CANONICAL_LABEL_CONTRADICTION";
    priA = pri(priActiveMask, :);

    % Step 2: remove noise.
    keepProp = true(height(propA), 1);
    for i = 1:height(propA)
        p = lower(string(propA.downstream_artifact(i)));
        n = lower(string(propA.note(i)));
        isDoc = contains(p, "/docs/") || endsWith(p, ".md") || endsWith(p, ".txt");
        isPlotOnly = contains(p, "plot") && ~contains(p, "run_");
        isLegacy = contains(p, "legacy") || contains(p, "archive");
        isPureTableMeta = startsWith(p, "tables/") && contains(n, "artifact reference-based") && ~contains(p, "switching_canonical");
        if isDoc || isPlotOnly || isLegacy || isPureTableMeta
            keepProp(i) = false;
        end
    end
    propA = propA(keepProp, :);

    keepPri = true(height(priA), 1);
    for i = 1:height(priA)
        p = lower(string(priA.file_or_artifact(i)));
        isDoc = contains(p, "/docs/") || endsWith(p, ".md") || endsWith(p, ".txt");
        isLegacy = contains(p, "legacy") || contains(p, "archive");
        if isDoc || isLegacy
            keepPri(i) = false;
        end
    end
    priA = priA(keepPri, :);

    % Step 3: collapse to unique pipelines/scripts.
    scripts = string(propA.downstream_artifact);
    if isempty(scripts)
        criticalTbl = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
            string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
            'VariableNames', {'pipeline_or_script','contamination_type','where_width_enters','which_outputs_are_affected','severity','confidence'});
    else
        uScripts = unique(scripts, 'stable');
        rows = repmat(struct('pipeline_or_script',"",'contamination_type',"",'where_width_enters',"", ...
            'which_outputs_are_affected',"",'severity',"",'confidence',""), numel(uScripts), 1);
        for i = 1:numel(uScripts)
            s = uScripts(i);
            m = scripts == s;
            up = unique(string(propA.upstream_source(m)));
            cp = unique(string(propA.contamination_path(m)));
            sev = maxSeverity(string(propA.severity(m)));

            % Join with priority evidence if present.
            mp = string(priA.file_or_artifact) == s;
            ctype = "CURRENT_CANONICAL_CONTAMINATION";
            if any(mp)
                clsLocal = unique(string(priA.classification(mp)));
                if any(clsLocal == "CANONICAL_LABEL_CONTRADICTION")
                    ctype = "CANONICAL_LABEL_CONTRADICTION";
                end
            end

            affects = inferAffectedOutputs(s, up);
            conf = "MED";
            if sev == "CRITICAL" || sev == "HIGH"
                conf = "HIGH";
            elseif numel(up) == 1 && up == "unspecified_width_named_table"
                conf = "LOW";
            end

            rows(i).pipeline_or_script = s;
            rows(i).contamination_type = ctype;
            rows(i).where_width_enters = strjoin(up, '; ');
            rows(i).which_outputs_are_affected = affects;
            rows(i).severity = sev;
            rows(i).confidence = conf;
        end
        criticalTbl = struct2table(rows);
        criticalTbl = sortrows(criticalTbl, {'severity','confidence'}, {'descend','descend'});
    end

    % Step 4: output minimal list.
    writeBoth(criticalTbl, repoRoot, runTables, 'switching_width_contamination_critical_only.csv');

    % Step 5: top 10.
    topN = min(10, height(criticalTbl));
    top10Tbl = criticalTbl(1:topN, :);
    writeBoth(top10Tbl, repoRoot, runTables, 'switching_width_contamination_top10.csv');

    % Verdict synthesis.
    nCriticalPipelines = height(criticalTbl);
    collapseContam = any(contains(lower(criticalTbl.pipeline_or_script), 'collapse'));
    backboneContam = any(contains(lower(criticalTbl.pipeline_or_script), 'backbone')) || ...
        any(contains(lower(criticalTbl.which_outputs_are_affected), 'backbone'));
    residualContam = any(contains(lower(criticalTbl.pipeline_or_script), 'residual')) || ...
        any(contains(lower(criticalTbl.which_outputs_are_affected), 'residual'));

    safeTrust = "YES";
    if nCriticalPipelines > 0
        if any(string(criticalTbl.severity) == "CRITICAL" | string(criticalTbl.severity) == "HIGH")
            safeTrust = "NO";
        else
            safeTrust = "PARTIAL";
        end
    end

    report = {};
    report{end+1} = '# Width Contamination Triage (Critical Isolation)';
    report{end+1} = '';
    report{end+1} = '## Method';
    report{end+1} = '- Started from propagation + priority tables only.';
    report{end+1} = '- Kept active contamination entries (YES/PARTIAL + contamination/label-contradiction classes).';
    report{end+1} = '- Removed docs/comments/legacy-only/plot-only noise.';
    report{end+1} = '- Collapsed to unique downstream scripts/pipelines.';
    report{end+1} = '';
    report{end+1} = '## Real Contamination Points';
    report{end+1} = sprintf('- N_CRITICAL_PIPELINES = %d', nCriticalPipelines);
    report{end+1} = sprintf('- collapse-affected pipelines present: %s', yesno(collapseContam));
    report{end+1} = sprintf('- backbone-affected pipelines present: %s', yesno(backboneContam));
    report{end+1} = sprintf('- residual-affected pipelines present: %s', yesno(residualContam));
    report{end+1} = '';
    report{end+1} = '## Trust Scope';
    report{end+1} = '- Critical list is intentionally minimal relative to broad scan.';
    report{end+1} = '- See `tables/switching_width_contamination_critical_only.csv` and `tables/switching_width_contamination_top10.csv`.';
    report{end+1} = '';
    report{end+1} = '## Final Verdicts';
    report{end+1} = sprintf('- N_CRITICAL_PIPELINES = %d', nCriticalPipelines);
    report{end+1} = sprintf('- COLLAPSE_CONTAMINATED = %s', yesno(collapseContam));
    report{end+1} = sprintf('- BACKBONE_CONTAMINATED = %s', yesno(backboneContam));
    report{end+1} = sprintf('- RESIDUAL_ANALYSIS_CONTAMINATED = %s', yesno(residualContam));
    report{end+1} = sprintf('- SAFE_TO_TRUST_PREVIOUS_RESULTS_AFTER_FILTER = %s', safeTrust);

    statusTbl = table( ...
        string('SUCCESS'), ...
        nCriticalPipelines, ...
        string(yesno(collapseContam)), ...
        string(yesno(backboneContam)), ...
        string(yesno(residualContam)), ...
        safeTrust, ...
        string('triaged from propagation+priority tables; non-active and documentation-only entries removed'), ...
        'VariableNames', {'STATUS','N_CRITICAL_PIPELINES','COLLAPSE_CONTAMINATED','BACKBONE_CONTAMINATED','RESIDUAL_ANALYSIS_CONTAMINATED','SAFE_TO_TRUST_PREVIOUS_RESULTS_AFTER_FILTER','execution_notes'});

    writeBoth(statusTbl, repoRoot, runTables, 'switching_width_contamination_critical_status.csv');
    writeLines(fullfile(runReports, 'switching_width_contamination_critical_triage.md'), report);
    writeLines(fullfile(repoRoot, 'reports', 'switching_width_contamination_critical_triage.md'), report);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, 0, {'switching width contamination triage completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_width_contamination_triage_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    statusTbl = table(string('FAILED'), 0, string('NO'), string('NO'), string('NO'), string('NO'), string(ME.message), ...
        'VariableNames', {'STATUS','N_CRITICAL_PIPELINES','COLLAPSE_CONTAMINATED','BACKBONE_CONTAMINATED','RESIDUAL_ANALYSIS_CONTAMINATED','SAFE_TO_TRUST_PREVIOUS_RESULTS_AFTER_FILTER','execution_notes'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_width_contamination_critical_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_width_contamination_critical_status.csv'));

    lines = {};
    lines{end+1} = '# Width Contamination Triage FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    writeLines(fullfile(runDir, 'reports', 'switching_width_contamination_critical_triage.md'), lines);
    writeLines(fullfile(repoRoot, 'reports', 'switching_width_contamination_critical_triage.md'), lines);

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'switching width contamination triage failed'}, true);
    rethrow(ME);
end

function sev = maxSeverity(sevs)
order = ["LOW","MED","HIGH","CRITICAL"];
idx = 1;
for i = 1:numel(sevs)
    j = find(order == string(sevs(i)), 1);
    if ~isempty(j) && j > idx
        idx = j;
    end
end
sev = order(idx);
end

function out = inferAffectedOutputs(scriptPath, upstream)
p = lower(char(scriptPath));
if contains(p, 'collapse')
    out = "collapse_metrics_and_figures";
elseif contains(p, 'backbone')
    out = "backbone_diagnostics";
elseif contains(p, 'residual') || contains(p, 'mode')
    out = "residual_mode_analysis_outputs";
elseif any(contains(lower(string(upstream)), 'switching_scaling_canonical_test.csv')) || ...
        any(contains(lower(string(upstream)), 'switching_collapse'))
    out = "collapse_derived_artifacts";
else
    out = "canonical_switching_auxiliary_outputs";
end
end

function out = yesno(tf)
out = 'NO';
if tf, out = 'YES'; end
end

function tbl = readKnownCsv(pathIn, expectedCols)
opts = detectImportOptions(pathIn, 'Delimiter', ',');
opts = setvartype(opts, 'char');
opts.VariableNamesLine = 1;
opts.DataLine = 2;
opts.ExtraColumnsRule = 'ignore';
opts.EmptyLineRule = 'read';
tbl = readtable(pathIn, opts);
if width(tbl) == numel(expectedCols)
    tbl.Properties.VariableNames = matlab.lang.makeUniqueStrings(expectedCols);
end

% Fallback for malformed import where first row became headers.
if height(tbl) == 0 || ~ismember('severity', tbl.Properties.VariableNames)
    C = readcell(pathIn, 'Delimiter', ',');
    if isempty(C) || size(C,1) < 2
        tbl = cell2table(cell(0, numel(expectedCols)), 'VariableNames', expectedCols);
        return;
    end
    header = string(C(1,1:min(numel(expectedCols), size(C,2))));
    if ~all(lower(header) == lower(string(expectedCols(1:numel(header)))))
        C = [expectedCols; C];
    end
    D = C(2:end, :);
    if size(D,2) < numel(expectedCols)
        D(:, end+1:numel(expectedCols)) = {''};
    elseif size(D,2) > numel(expectedCols)
        D = D(:, 1:numel(expectedCols));
    end
    tbl = cell2table(D, 'VariableNames', expectedCols);
end
end

function writeBoth(tbl, repoRoot, runTables, name)
writetable(tbl, fullfile(runTables, name));
writetable(tbl, fullfile(repoRoot, 'tables', name));
end

function writeLines(pathOut, lines)
fid = fopen(pathOut, 'w');
if fid < 0
    error('run_switching_width_contamination_triage:WriteFail', 'Cannot write %s', pathOut);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);
end
