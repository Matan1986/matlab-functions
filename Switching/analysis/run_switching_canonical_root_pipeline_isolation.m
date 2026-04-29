% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: DIAGNOSTIC_FORENSIC — pipeline isolation / routing audit for canonical run roots
% EVIDENCE_STATUS: INFRASTRUCTURE_AUDIT — prevents mistaken wiring; not manuscript physics claim
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

try
    cfg = struct();
    cfg.runLabel = 'switching_canonical_root_pipeline_isolation';
    cfg.dataset = 'canonical_root_pipeline_isolation';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'root pipeline isolation initialized'}, false);

    targetOutputs = string({
        'switching_canonical_S_long.csv';
        'switching_residual_global_rank_structure.csv';
        'switching_residual_rank_structure_by_regime.csv';
        'switching_mode_amplitudes_vs_T.csv';
        'switching_collapse_error_vs_T.csv'
        });

    scriptFiles = listMatlabScripts(fullfile(repoRoot, 'Switching', 'analysis'));
    if isempty(scriptFiles)
        error('run_switching_canonical_root_pipeline_isolation:NoScripts', ...
            'No MATLAB scripts found under Switching/analysis.');
    end

    % Step 1+2: direct writer detection.
    outToWriter = containers.Map('KeyType', 'char', 'ValueType', 'char');
    rootScripts = strings(0,1);
    for i = 1:numel(targetOutputs)
        out = targetOutputs(i);
        writer = findWriterForOutput(scriptFiles, out);
        if strlength(writer) > 0
            outToWriter(char(out)) = char(writer);
            rootScripts(end+1,1) = writer; %#ok<AGROW>
        end
    end
    rootScripts = unique(rootScripts, 'stable');

    % One-level upstream tracing from direct writers.
    upstreamScripts = strings(0,1);
    unresolvedInputs = strings(0,1);
    for i = 1:numel(rootScripts)
        p = rootScripts(i);
        inputCsvs = parseReadtableCsvs(p);
        for j = 1:numel(inputCsvs)
            inCsv = inputCsvs(j);
            % Prefer canonical-output dependencies relevant to this scope.
            if ~contains(inCsv, "switching_")
                continue;
            end
            upWriter = findWriterForOutput(scriptFiles, inCsv);
            if strlength(upWriter) > 0 && upWriter ~= p
                upstreamScripts(end+1,1) = upWriter; %#ok<AGROW>
            else
                if inCsv == "switching_scaling_canonical_test.csv"
                    unresolvedInputs(end+1,1) = inCsv; %#ok<AGROW>
                end
            end
        end
    end
    rootScripts = unique([rootScripts; upstreamScripts], 'stable');

    % Keep minimal true root set tied to requested target families.
    keep = false(numel(rootScripts), 1);
    for i = 1:numel(rootScripts)
        p = rootScripts(i);
        txt = lower(readTextSafe(p));
        keep(i) = contains(txt, 'switching_canonical_s_long.csv') || ...
                  contains(txt, 'switching_mode_amplitudes_vs_t.csv') || ...
                  contains(txt, 'switching_residual_global_rank_structure.csv') || ...
                  contains(txt, 'switching_collapse_error_vs_t.csv') || ...
                  contains(txt, 'switching_transition_detection.csv');
    end
    rootScripts = rootScripts(keep);

    % Step 3+4: width influence and contamination reality.
    n = numel(rootScripts);
    rows = repmat(struct('script_path',"", 'produces_output',"", ...
        'width_used_in_computation',"NO", 'width_used_in_plot_only',"NO", ...
        'contamination_real',"NO", 'confidence',"MED"), n, 1);

    for i = 1:n
        p = rootScripts(i);
        outs = outputsProducedByScript(p, targetOutputs);
        if isempty(outs)
            % Upstream roots may produce non-target but critical dependencies.
            if contains(lower(readTextSafe(p)), 'switching_transition_detection.csv')
                outs = "switching_transition_detection.csv";
            else
                outs = "dependency_only";
            end
        end

        [widthComp, widthPlot] = classifyWidthUsage(p);
        contam = widthComp;
        conf = "HIGH";
        if p == "" || any(outs == "dependency_only")
            conf = "MED";
        end
        if p == "Switching/analysis/run_switching_collapse_breakdown_analysis.m" && ~isempty(unresolvedInputs)
            conf = "MED";
        end

        rows(i).script_path = p;
        rows(i).produces_output = strjoin(outs, '; ');
        rows(i).width_used_in_computation = yesno(widthComp);
        rows(i).width_used_in_plot_only = yesno(widthPlot && ~widthComp);
        rows(i).contamination_real = yesno(contam);
        rows(i).confidence = conf;
    end

    rootTbl = struct2table(rows);
    rootTbl = sortrows(rootTbl, {'contamination_real','script_path'}, {'descend','ascend'});

    writetable(rootTbl, fullfile(runTables, 'switching_canonical_root_pipelines.csv'));
    writetable(rootTbl, fullfile(repoRoot, 'tables', 'switching_canonical_root_pipelines.csv'));

    % Verdicts.
    nRoot = height(rootTbl);
    nReal = sum(string(rootTbl.contamination_real) == "YES");
    isBackbone = contains(lower(string(rootTbl.produces_output)), 'switching_canonical_s_long.csv');
    isResidual = contains(lower(string(rootTbl.produces_output)), 'switching_residual_') | ...
                 contains(lower(string(rootTbl.produces_output)), 'switching_mode_amplitudes_vs_t.csv');
    isCollapse = contains(lower(string(rootTbl.produces_output)), 'switching_collapse_error_vs_t.csv');
    backCont = any(isBackbone & string(rootTbl.contamination_real) == "YES");
    resCont = any(isResidual & string(rootTbl.contamination_real) == "YES");
    colCont = any(isCollapse & string(rootTbl.contamination_real) == "YES");

    statusTbl = table( ...
        string('SUCCESS'), ...
        nRoot, ...
        nReal, ...
        string(yesno(backCont)), ...
        string(yesno(resCont)), ...
        string(yesno(colCont)), ...
        string(strjoin(unique(unresolvedInputs), '; ')), ...
        'VariableNames', {'STATUS','N_ROOT_PIPELINES','N_REAL_CONTAMINATIONS','BACKBONE_CONTAMINATED','RESIDUAL_ANALYSIS_CONTAMINATED','COLLAPSE_CONTAMINATED','UNRESOLVED_ONE_LEVEL_INPUTS'});
    writetable(statusTbl, fullfile(runTables, 'switching_canonical_root_pipelines_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_canonical_root_pipelines_status.csv'));

    report = {};
    report{end+1} = '# Root-Level Canonical Pipeline Isolation';
    report{end+1} = '';
    report{end+1} = '## Scope';
    report{end+1} = '- Restricted to direct producers of canonical reconstruction, residual/mode outputs, and collapse breakdown outputs.';
    report{end+1} = '- Added one-level upstream tracing via `readtable(...)` CSV dependencies.';
    report{end+1} = '';
    report{end+1} = '## Final Verdicts';
    report{end+1} = sprintf('- N_ROOT_PIPELINES = %d', nRoot);
    report{end+1} = sprintf('- N_REAL_CONTAMINATIONS = %d', nReal);
    report{end+1} = sprintf('- BACKBONE_CONTAMINATED = %s', yesno(backCont));
    report{end+1} = sprintf('- RESIDUAL_ANALYSIS_CONTAMINATED = %s', yesno(resCont));
    report{end+1} = sprintf('- COLLAPSE_CONTAMINATED = %s', yesno(colCont));
    if ~isempty(unresolvedInputs)
        report{end+1} = sprintf('- unresolved one-level inputs: %s', strjoin(unique(unresolvedInputs), '; '));
    end
    report{end+1} = '';
    report{end+1} = '## Output';
    report{end+1} = '- `tables/switching_canonical_root_pipelines.csv`';
    report{end+1} = '- `tables/switching_canonical_root_pipelines_status.csv`';

    writeLines(fullfile(runReports, 'switching_canonical_root_pipeline_isolation.md'), report);
    writeLines(fullfile(repoRoot, 'reports', 'switching_canonical_root_pipeline_isolation.md'), report);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nRoot, {'root pipeline isolation completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_canonical_root_pipeline_isolation_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    statusTbl = table(string('FAILED'), 0, 0, string('NO'), string('NO'), string('NO'), string(ME.message), ...
        'VariableNames', {'STATUS','N_ROOT_PIPELINES','N_REAL_CONTAMINATIONS','BACKBONE_CONTAMINATED','RESIDUAL_ANALYSIS_CONTAMINATED','COLLAPSE_CONTAMINATED','UNRESOLVED_ONE_LEVEL_INPUTS'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_canonical_root_pipelines_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_canonical_root_pipelines_status.csv'));

    lines = {};
    lines{end+1} = '# Root-Level Canonical Pipeline Isolation FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    writeLines(fullfile(runDir, 'reports', 'switching_canonical_root_pipeline_isolation.md'), lines);
    writeLines(fullfile(repoRoot, 'reports', 'switching_canonical_root_pipeline_isolation.md'), lines);

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'root pipeline isolation failed'}, true);
    rethrow(ME);
end

function files = listMatlabScripts(rootDir)
d = dir(fullfile(rootDir, '*.m'));
files = strings(numel(d), 1);
for i = 1:numel(d)
    files(i) = strrep(fullfile(d(i).folder, d(i).name), '\', '/');
end
files = strrep(files, strrep(rootDir, '\', '/') + "/", "Switching/analysis/");
end

function txt = readTextSafe(relPath)
absPath = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), relPath);
if exist(absPath, 'file') ~= 2
    txt = "";
    return;
end
txt = join(string(readlines(absPath)), newline);
end

function writer = findWriterForOutput(scriptFiles, outName)
writer = "";
needle = lower(char(outName));
for i = 1:numel(scriptFiles)
    p = scriptFiles(i);
    if hasOutputWriteLine(p, needle)
        writer = p;
        return;
    end
end
end

function outputs = outputsProducedByScript(scriptPath, targets)
txt = string(readTextSafe(scriptPath));
lines = lower(splitlines(txt));
outputs = strings(0,1);
for i = 1:numel(targets)
    t = targets(i);
    needle = lower(char(t));
    hit = false;
    for j = 1:numel(lines)
        ln = strtrim(lines(j));
        if contains(ln, needle) && (contains(ln, 'writetable(') || contains(ln, 'atomic_writetable(') || contains(ln, 'writeboth('))
            hit = true;
            break;
        end
    end
    if hit
        outputs(end+1,1) = t; %#ok<AGROW>
    end
end
outputs = unique(outputs, 'stable');
end

function csvs = parseReadtableCsvs(scriptPath)
txt = string(readTextSafe(scriptPath));
lines = splitlines(txt);
csvs = strings(0,1);
for i = 1:numel(lines)
    ln = lower(strtrim(lines(i)));
    if contains(ln, 'readtable(') && contains(ln, '.csv')
        k = regexp(char(ln), '([a-z0-9_]+\.csv)', 'tokens', 'once');
        if ~isempty(k)
            csvs(end+1,1) = string(k{1}); %#ok<AGROW>
        end
    end
end
csvs = unique(csvs, 'stable');
end

function [widthComp, widthPlotOnly] = classifyWidthUsage(scriptPath)
txt = string(readTextSafe(scriptPath));
lines = splitlines(txt);
widthComp = false;
widthAny = false;
plotOnly = true;
for i = 1:numel(lines)
    ln = lower(strtrim(lines(i)));
    if ~(contains(ln, 'width') || contains(ln, 'fwhm') || contains(ln, 'halfwidth'))
        continue;
    end
    widthAny = true;
    isComment = startsWith(ln, '%');
    isPlot = contains(ln, 'plot(') || contains(ln, 'imagesc(') || contains(ln, 'xlabel(') || ...
             contains(ln, 'ylabel(') || contains(ln, 'title(') || contains(ln, 'legend(');
    isTextOnly = contains(ln, 'report{') || contains(ln, 'fprintf(');
    if ~isComment && ~isPlot && ~isTextOnly
        % width participates in logic/math/indexing.
        widthComp = true;
        plotOnly = false;
    end
end
widthPlotOnly = widthAny && plotOnly;
end

function out = yesno(tf)
out = 'NO';
if tf, out = 'YES'; end
end

function writeLines(pathOut, lines)
fid = fopen(pathOut, 'w');
if fid < 0
    error('run_switching_canonical_root_pipeline_isolation:WriteFail', ...
        'Cannot write %s', pathOut);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);
end

function tf = hasOutputWriteLine(scriptPath, needleLower)
txt = string(readTextSafe(scriptPath));
lines = lower(splitlines(txt));
tf = false;
for i = 1:numel(lines)
    ln = strtrim(lines(i));
    if contains(ln, needleLower) && (contains(ln, 'writetable(') || contains(ln, 'atomic_writetable(') || contains(ln, 'writeboth('))
        tf = true;
        return;
    end
end
end
