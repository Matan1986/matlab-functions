clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

try
    cfg = struct();
    cfg.runLabel = 'switching_width_contamination_audit';
    cfg.dataset = 'repo_wide_width_leakage_survey';
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

    scopeDirs = { ...
        fullfile(repoRoot, 'Switching'), ...
        fullfile(repoRoot, 'analysis'), ...
        fullfile(repoRoot, 'analysis_new'), ...
        fullfile(repoRoot, 'canonical'), ...
        fullfile(repoRoot, 'tables'), ...
        fullfile(repoRoot, 'reports'), ...
        fullfile(repoRoot, 'results'), ...
        fullfile(repoRoot, 'docs')};

    textExt = {'.m','.md','.txt','.csv','.json','.yaml','.yml','.log','.tsv','.ps1','.py','.r'};
    figExt = {'.fig','.png','.jpg','.jpeg','.svg','.pdf'};

    directPatterns = { ...
        'width', ...
        'fwhm', ...
        'half max', ...
        'half-?max', ...
        'broadening', ...
        '\bW\b', ...
        '\(I\s*-\s*I_?peak\)\s*/', ...
        'I\s*/\s*width', ...
        'width_?used', ...
        'halfwidth', ...
        'sigma'};

    canonicalLabels = { ...
        'canonical', ...
        'trusted', ...
        'source_of_truth', ...
        'validated', ...
        'collapse verification', ...
        'scaling canonical'};

    files = listScopeFiles(scopeDirs, textExt, figExt);

    directRows = repmat(initDirectRow(), 0, 1);
    indirectRows = repmat(initIndirectRow(), 0, 1);
    misuseRows = repmat(initMisuseRow(), 0, 1);
    propRows = repmat(initPropRow(), 0, 1);
    priorityRows = repmat(initPriorityRow(), 0, 1);

    widthArtifactNames = strings(0,1);
    widthArtifactNames(end+1) = "switching_scaling_canonical_test.csv";
    widthArtifactNames(end+1) = "switching_collapse_verification.csv";
    widthArtifactNames(end+1) = "switching_collapse_error_vs_T.csv";
    widthArtifactNames(end+1) = "switching_collapse_local_breakdown.csv";

    itemCounter = 0;
    for iF = 1:numel(files)
        f = files{iF};
        [~, name, ext] = fileparts(f);
        relPath = toRel(repoRoot, f);
        extL = lower(ext);
        if any(strcmp(extL, figExt))
            % Figure-level label audit by filename only.
            fn = lower([name ext]);
            if contains(fn, 'width') || contains(fn, 'fwhm') || contains(fn, 'collapse') || contains(fn, 'scaling')
                r = initDirectRow();
                r.file_path = string(relPath);
                r.line_number_or_artifact_ref = "artifact_filename";
                r.match_text = string([name ext]);
                r.match_type = "figure_label";
                r.directly_uses_width_logic = "NO";
                if contains(fn, 'width') || contains(fn, 'fwhm')
                    r.directly_uses_width_logic = "YES";
                end
                r.note = "filename suggests width/collapse motif; inspect figure provenance";
                directRows(end+1,1) = r; %#ok<SAGROW>
            end
            continue;
        end

        txt = safeReadText(f);
        if strlength(txt) == 0
            continue;
        end
        lines = splitlines(txt);
        lowerTxt = lower(char(txt));

        % Part A: direct scan.
        for il = 1:numel(lines)
            ln = char(lines(il));
            lnl = lower(strtrim(ln));
            if isempty(lnl)
                continue;
            end
            for ip = 1:numel(directPatterns)
                pat = directPatterns{ip};
                if ~isempty(regexp(lnl, pat, 'once'))
                    r = initDirectRow();
                    r.file_path = string(relPath);
                    r.line_number_or_artifact_ref = string(il);
                    r.match_text = string(strtrim(ln));
                    r.match_type = inferMatchType(extL);
                    r.directly_uses_width_logic = "NO";
                    if isDirectWidthLogic(lnl)
                        r.directly_uses_width_logic = "YES";
                    end
                    r.note = "pattern match from direct leakage keyword set";
                    directRows(end+1,1) = r; %#ok<SAGROW>
                    break;
                end
            end
        end

        % Part B: indirect semantic suspicion.
        suspected = detectIndirectLogic(lowerTxt);
        for is = 1:numel(suspected)
            itemCounter = itemCounter + 1;
            ir = initIndirectRow();
            ir.item_id = sprintf('IND_%04d', itemCounter);
            ir.file_or_artifact = string(relPath);
            ir.suspected_logic = suspected(is).logic;
            ir.evidence = suspected(is).evidence;
            ir.confidence = suspected(is).confidence;
            ir.likely_noncanonical = suspected(is).likely_noncanonical;
            ir.note = "semantic heuristic detection";
            indirectRows(end+1,1) = ir; %#ok<SAGROW>
        end

        % Part C: canonical label misuse in same artifact.
        hasCanonicalLabel = false;
        for ic = 1:numel(canonicalLabels)
            if contains(lowerTxt, canonicalLabels{ic})
                hasCanonicalLabel = true;
                break;
            end
        end
        hasWidth = contains(lowerTxt, 'width') || contains(lowerTxt, 'fwhm') || ...
            contains(lowerTxt, '(i-i_peak)') || contains(lowerTxt, 'i_peak') && contains(lowerTxt, '/');
        if hasCanonicalLabel
            mr = initMisuseRow();
            mr.file_or_artifact = string(relPath);
            mr.canonical_label_used = "YES";
            mr.width_logic_present = string(yesno(hasWidth));
            misuse = hasWidth;
            % If file is explicitly legacy/archival docs, keep as non-misuse unless canonical claim is active.
            if contains(lower(relPath), 'legacy') || contains(lower(relPath), 'archive')
                misuse = false;
            end
            mr.misuse_flag = string(yesno(misuse));
            if misuse
                mr.justification = "canonical label coexists with width/collapse normalization motifs";
                mr.note = "potential canonical-label contradiction";
            else
                mr.justification = "no actionable contradiction detected";
                mr.note = "canonical label appears clean or legacy-scoped";
            end
            misuseRows(end+1,1) = mr; %#ok<SAGROW>
        end

        % Part D: propagation scan (downstream reads/references to width artifacts or width tables).
        for iw = 1:numel(widthArtifactNames)
            wname = lower(char(widthArtifactNames(iw)));
            if contains(lowerTxt, wname)
                pr = initPropRow();
                pr.downstream_artifact = string(relPath);
                pr.upstream_source = string(widthArtifactNames(iw));
                pr.contamination_path = "explicit reference to width/collapse artifact";
                pr.affects_current_canonical_results = "PARTIAL";
                sev = "MED";
                if isCurrentCanonicalPath(relPath)
                    pr.affects_current_canonical_results = "YES";
                    sev = "HIGH";
                end
                if contains(lower(relPath), 'run_switching_canonical.m')
                    pr.affects_current_canonical_results = "YES";
                    sev = "CRITICAL";
                end
                pr.severity = sev;
                pr.note = "artifact reference-based propagation detection";
                propRows(end+1,1) = pr; %#ok<SAGROW>
            end
        end
        if contains(lowerTxt, 'readtable') && contains(lowerTxt, 'width')
            pr = initPropRow();
            pr.downstream_artifact = string(relPath);
            pr.upstream_source = "unspecified_width_named_table";
            pr.contamination_path = "readtable(...) on width-named data source";
            pr.affects_current_canonical_results = "PARTIAL";
            pr.severity = "MED";
            if isCurrentCanonicalPath(relPath)
                pr.affects_current_canonical_results = "YES";
                pr.severity = "HIGH";
            end
            pr.note = "generic width table ingestion";
            propRows(end+1,1) = pr; %#ok<SAGROW>
        end
    end

    % Part E: priority classification from direct/indirect/misuse/propagation.
    priorityRows = buildPriorityRows(directRows, indirectRows, misuseRows, propRows);

    % Counts for status.
    nDirect = numel(directRows);
    nIndirect = numel(indirectRows);
    nMisuse = sum(arrayfun(@(x) strcmp(char(x.misuse_flag), 'YES'), misuseRows));
    nCurrentContam = sum(arrayfun(@(x) strcmp(char(x.affects_current_canonical_results), 'YES'), propRows));
    nCritical = sum(arrayfun(@(x) strcmp(char(x.severity), 'CRITICAL'), propRows)) + ...
        sum(arrayfun(@(x) strcmp(char(x.classification), 'NEEDS_IMMEDIATE_ISOLATION'), priorityRows));

    statusTbl = table( ...
        string('SUCCESS'), ...
        nDirect, ...
        nIndirect, ...
        nMisuse, ...
        nCurrentContam, ...
        nCritical, ...
        string('broad scan over code/docs/tables/reports/results using direct+indirect heuristics; audit-only no modifications'), ...
        'VariableNames', {'STATUS','N_direct_hits','N_indirect_suspicions','N_canonical_label_misuse','N_current_canonical_contaminations','N_critical_items','execution_notes'});

    widthLeakPresent = nDirect > 0 || nIndirect > 0;
    affectsCurrent = "NO";
    if nCurrentContam > 0
        affectsCurrent = "YES";
    elseif nMisuse > 0
        affectsCurrent = "PARTIAL";
    end
    collapseBranchContam = "UNKNOWN";
    if any(contains(string({propRows.upstream_source}'), "switching_scaling_canonical_test.csv")) || ...
            any(contains(string({propRows.upstream_source}'), "switching_collapse"))
        if nCurrentContam > 0
            collapseBranchContam = "YES";
        else
            collapseBranchContam = "PARTIAL";
        end
    end
    labelingClean = nMisuse == 0;
    immediateIsolation = nCritical > 0 || strcmp(affectsCurrent, "YES");
    safeContinue = "YES";
    if immediateIsolation
        safeContinue = "NO";
    elseif strcmp(affectsCurrent, "PARTIAL")
        safeContinue = "NO";
    end

    report = {};
    report{end+1} = '# Switching Width Contamination Audit';
    report{end+1} = '';
    report{end+1} = '## 1. Executive Summary';
    report{end+1} = sprintf('- width-based leakage present: %s', yesno(widthLeakPresent));
    report{end+1} = sprintf('- affects current canonical analysis: %s', affectsCurrent);
    report{end+1} = '';
    report{end+1} = '## 2. Direct Leakage';
    report{end+1} = sprintf('- direct keyword hits: %d', nDirect);
    report{end+1} = '- see `tables/switching_width_leakage_direct_scan.csv` for explicit references.';
    report{end+1} = '';
    report{end+1} = '## 3. Indirect Leakage';
    report{end+1} = sprintf('- indirect semantic suspicions: %d', nIndirect);
    report{end+1} = '- see `tables/switching_width_leakage_indirect_scan.csv` for confidence and non-canonical likelihood.';
    report{end+1} = '';
    report{end+1} = '## 4. Canonical Mislabeling';
    report{end+1} = sprintf('- canonical-label misuse flags: %d', nMisuse);
    report{end+1} = '- see `tables/switching_canonical_label_misuse.csv`.';
    report{end+1} = '';
    report{end+1} = '## 5. Propagation Paths';
    report{end+1} = sprintf('- propagation findings: %d', numel(propRows));
    report{end+1} = sprintf('- current-canonical contamination count: %d', nCurrentContam);
    report{end+1} = '- see `tables/switching_width_contamination_propagation.csv`.';
    report{end+1} = '';
    report{end+1} = '## 6. Risk Assessment';
    report{end+1} = '- priority classification is provided in `tables/switching_width_contamination_priority.csv`.';
    report{end+1} = sprintf('- critical items: %d', nCritical);
    report{end+1} = '';
    report{end+1} = '## 7. Immediate Conclusions';
    report{end+1} = '- Trust current analyses only after checking propagation table severity and priority class.';
    report{end+1} = '- Collapse/scaling branches referencing width-normalized artifacts are suspect unless explicitly isolated from canonical outputs.';
    report{end+1} = '- Isolation/documentation is recommended when canonical labels overlap with width logic.';
    report{end+1} = '';
    report{end+1} = '## Final Verdicts';
    report{end+1} = sprintf('- WIDTH_LEAKAGE_PRESENT = %s', yesno(widthLeakPresent));
    report{end+1} = sprintf('- WIDTH_LEAKAGE_AFFECTS_CURRENT_CANONICAL_ANALYSIS = %s', affectsCurrent);
    report{end+1} = sprintf('- CANONICAL_COLLAPSE_BRANCH_CONTAMINATED = %s', collapseBranchContam);
    report{end+1} = sprintf('- CANONICAL_LABELING_IS_CURRENTLY_CLEAN = %s', yesno(labelingClean));
    report{end+1} = sprintf('- IMMEDIATE_ISOLATION_OF_WIDTH_BASED_ARTIFACTS_NEEDED = %s', yesno(immediateIsolation));
    report{end+1} = sprintf('- SAFE_TO_CONTINUE_PHYSICS_INTERPRETATION_WITHOUT_CLEANUP = %s', safeContinue);

    directTbl = struct2table(directRows);
    indirectTbl = struct2table(indirectRows);
    misuseTbl = struct2table(misuseRows);
    propTbl = struct2table(propRows);
    priorityTbl = struct2table(priorityRows);

    writeBoth(directTbl, repoRoot, runTables, 'switching_width_leakage_direct_scan.csv');
    writeBoth(indirectTbl, repoRoot, runTables, 'switching_width_leakage_indirect_scan.csv');
    writeBoth(misuseTbl, repoRoot, runTables, 'switching_canonical_label_misuse.csv');
    writeBoth(propTbl, repoRoot, runTables, 'switching_width_contamination_propagation.csv');
    writeBoth(priorityTbl, repoRoot, runTables, 'switching_width_contamination_priority.csv');
    writeBoth(statusTbl, repoRoot, runTables, 'switching_width_contamination_audit_status.csv');
    writeLines(fullfile(runReports, 'switching_width_contamination_audit.md'), report);
    writeLines(fullfile(repoRoot, 'reports', 'switching_width_contamination_audit.md'), report);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, 0, {'switching width contamination audit completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_width_contamination_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end
    statusTbl = table(string('FAILED'), 0, 0, 0, 0, 0, string(ME.message), ...
        'VariableNames', {'STATUS','N_direct_hits','N_indirect_suspicions','N_canonical_label_misuse','N_current_canonical_contaminations','N_critical_items','execution_notes'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_width_contamination_audit_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_width_contamination_audit_status.csv'));
    lines = {};
    lines{end+1} = '# Switching Width Contamination Audit FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    writeLines(fullfile(runDir, 'reports', 'switching_width_contamination_audit.md'), lines);
    writeLines(fullfile(repoRoot, 'reports', 'switching_width_contamination_audit.md'), lines);
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'switching width contamination audit failed'}, true);
    rethrow(ME);
end

function files = listScopeFiles(scopeDirs, textExt, figExt)
files = {};
allExt = [textExt, figExt];
for i = 1:numel(scopeDirs)
    d = scopeDirs{i};
    if exist(d, 'dir') ~= 7
        continue;
    end
    stack = {d};
    while ~isempty(stack)
        curr = stack{1};
        stack(1) = [];
        items = dir(curr);
        for j = 1:numel(items)
            nm = items(j).name;
            if strcmp(nm, '.') || strcmp(nm, '..')
                continue;
            end
            fullp = fullfile(curr, nm);
            if items(j).isdir
                stack{end+1} = fullp; %#ok<AGROW>
            else
                [~, ~, ex] = fileparts(nm);
                if any(strcmpi(ex, allExt))
                    files{end+1,1} = fullp; %#ok<AGROW>
                end
            end
        end
    end
end
end

function txt = safeReadText(pathIn)
txt = "";
try
    txt = string(fileread(pathIn));
catch
    txt = "";
end
end

function rel = toRel(root, pathIn)
rel = strrep(pathIn, [root filesep], '');
rel = strrep(rel, '\', '/');
end

function tf = isDirectWidthLogic(lineLower)
tf = false;
if contains(lineLower, 'fwhm') || contains(lineLower, 'width_used') || contains(lineLower, 'halfwidth')
    tf = true;
    return;
end
if contains(lineLower, '(i-i_peak)/') || contains(lineLower, '(i - i_peak)/') || ...
        contains(lineLower, '/width') || contains(lineLower, 'i_peak') && contains(lineLower, 'width')
    tf = true;
end
end

function mt = inferMatchType(extLower)
if strcmp(extLower, '.m')
    mt = "code";
elseif any(strcmp(extLower, {'.md','.txt'}))
    mt = "report";
elseif any(strcmp(extLower, {'.csv','.tsv'}))
    mt = "table";
elseif any(strcmp(extLower, {'.json','.yaml','.yml','.log'}))
    mt = "run_metadata";
else
    mt = "doc";
end
end

function suspects = detectIndirectLogic(txtLower)
suspects = repmat(struct('logic',"",'evidence',"",'confidence',"",'likely_noncanonical',""), 0, 1);
if contains(txtLower, 'collapse_metric') && contains(txtLower, 'width')
    s = struct('logic',"collapse coordinate likely width-derived", ...
        'evidence',"collapse metric appears with width variable references", ...
        'confidence',"HIGH", ...
        'likely_noncanonical',"YES");
    suspects(end+1,1) = s; %#ok<AGROW>
end
if contains(txtLower, 'i_peak') && contains(txtLower, '/') && contains(txtLower, 'width')
    s = struct('logic',"spread-normalized current coordinate", ...
        'evidence',"I_peak and width appear in same normalization expression context", ...
        'confidence',"HIGH", ...
        'likely_noncanonical',"YES");
    suspects(end+1,1) = s; %#ok<AGROW>
end
if contains(txtLower, 'xgrid') && contains(txtLower, 'collapse')
    s = struct('logic',"hidden collapse coordinate preprocessing", ...
        'evidence',"xGrid + collapse narrative indicates pre-normalized coordinate flow", ...
        'confidence',"MED", ...
        'likely_noncanonical',"PARTIAL");
    suspects(end+1,1) = s; %#ok<AGROW>
end
if contains(txtLower, 'broadening') || contains(txtLower, 'spread')
    s = struct('logic',"spread/broadening proxy may act as width substitute", ...
        'evidence',"broadening/spread language in scaling/collapse context", ...
        'confidence',"LOW", ...
        'likely_noncanonical',"PARTIAL");
    suspects(end+1,1) = s; %#ok<AGROW>
end
end

function tf = isCurrentCanonicalPath(relPath)
p = lower(relPath);
tf = false;
if contains(p, 'switching/analysis/run_switching_') || contains(p, 'tables/switching_') || contains(p, 'reports/switching_')
    tf = true;
end
if contains(p, 'legacy') || contains(p, 'archive')
    tf = false;
end
end

function rows = buildPriorityRows(directRows, indirectRows, misuseRows, propRows)
rows = repmat(initPriorityRow(), 0, 1);
id = 0;
% Direct
for i = 1:numel(directRows)
    id = id + 1;
    r = initPriorityRow();
    r.item_id = sprintf('PRI_D_%04d', id);
    r.file_or_artifact = directRows(i).file_path;
    if strcmp(char(directRows(i).directly_uses_width_logic), 'YES')
        if isCurrentCanonicalPath(char(directRows(i).file_path))
            r.classification = "CURRENT_CANONICAL_CONTAMINATION";
            r.severity = "HIGH";
            r.why_it_matters = "explicit width logic appears in current canonical-path artifact";
            r.recommended_next_action = "isolate artifact from canonical branch and document scope";
        else
            r.classification = "LEGACY_BUT_CONFUSING";
            r.severity = "MED";
            r.why_it_matters = "width logic remains visible and may be mistaken as canonical";
            r.recommended_next_action = "tag as legacy-only and add clear provenance note";
        end
    else
        r.classification = "LEGACY_ONLY_SAFE";
        r.severity = "LOW";
        r.why_it_matters = "mention only; no direct width logic found";
        r.recommended_next_action = "no immediate action";
    end
    rows(end+1,1) = r; %#ok<SAGROW>
end
% Misuse
for i = 1:numel(misuseRows)
    if strcmp(char(misuseRows(i).misuse_flag), 'YES')
        id = id + 1;
        r = initPriorityRow();
        r.item_id = sprintf('PRI_M_%04d', id);
        r.file_or_artifact = misuseRows(i).file_or_artifact;
        r.classification = "CANONICAL_LABEL_CONTRADICTION";
        r.severity = "HIGH";
        r.why_it_matters = "canonical wording coexists with width-based logic";
        r.recommended_next_action = "separate canonical/non-canonical labels immediately";
        rows(end+1,1) = r; %#ok<SAGROW>
    end
end
% Propagation
for i = 1:numel(propRows)
    id = id + 1;
    r = initPriorityRow();
    r.item_id = sprintf('PRI_P_%04d', id);
    r.file_or_artifact = propRows(i).downstream_artifact;
    if strcmp(char(propRows(i).severity), 'CRITICAL')
        r.classification = "NEEDS_IMMEDIATE_ISOLATION";
        r.severity = "CRITICAL";
        r.why_it_matters = "critical propagation path into canonical entrypoint";
        r.recommended_next_action = "block path from canonical workflows before further interpretation";
    elseif strcmp(char(propRows(i).affects_current_canonical_results), 'YES')
        r.classification = "CURRENT_CANONICAL_CONTAMINATION";
        r.severity = "HIGH";
        r.why_it_matters = "downstream canonical artifact depends on width-tainted source";
        r.recommended_next_action = "replace source with width-free canonical equivalent";
    else
        r.classification = "LEGACY_BUT_CONFUSING";
        r.severity = propRows(i).severity;
        r.why_it_matters = "propagation path exists but canonical impact appears partial";
        r.recommended_next_action = "document boundary and prevent accidental reuse";
    end
    rows(end+1,1) = r; %#ok<SAGROW>
end
% Indirect
for i = 1:numel(indirectRows)
    id = id + 1;
    r = initPriorityRow();
    r.item_id = sprintf('PRI_I_%04d', id);
    r.file_or_artifact = indirectRows(i).file_or_artifact;
    if strcmp(char(indirectRows(i).likely_noncanonical), 'YES') && strcmp(char(indirectRows(i).confidence), 'HIGH')
        r.classification = "LEGACY_BUT_CONFUSING";
        r.severity = "MED";
        r.why_it_matters = "high-confidence hidden width-like logic suspicion";
        r.recommended_next_action = "manual review and provenance annotation";
    else
        r.classification = "LEGACY_ONLY_SAFE";
        r.severity = "LOW";
        r.why_it_matters = "low/medium confidence indirect signal";
        r.recommended_next_action = "defer unless referenced by canonical branch";
    end
    rows(end+1,1) = r; %#ok<SAGROW>
end
end

function row = initDirectRow()
row = struct('file_path',"",'line_number_or_artifact_ref',"",'match_text',"",'match_type',"",'directly_uses_width_logic',"",'note',"");
end

function row = initIndirectRow()
row = struct('item_id',"",'file_or_artifact',"",'suspected_logic',"",'evidence',"",'confidence',"",'likely_noncanonical',"",'note',"");
end

function row = initMisuseRow()
row = struct('file_or_artifact',"",'canonical_label_used',"",'width_logic_present',"",'misuse_flag',"",'justification',"",'note',"");
end

function row = initPropRow()
row = struct('downstream_artifact',"",'upstream_source',"",'contamination_path',"",'affects_current_canonical_results',"",'severity',"",'note',"");
end

function row = initPriorityRow()
row = struct('item_id',"",'file_or_artifact',"",'classification',"",'severity',"",'why_it_matters',"",'recommended_next_action',"");
end

function out = yesno(tf)
out = 'NO';
if tf
    out = 'YES';
end
end

function writeBoth(tbl, repoRoot, runTables, name)
writetable(tbl, fullfile(runTables, name));
writetable(tbl, fullfile(repoRoot, 'tables', name));
end

function writeLines(pathOut, lines)
fid = fopen(pathOut, 'w');
if fid < 0
    error('run_switching_width_contamination_audit:WriteFail', 'Cannot write %s', pathOut);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);
end
