% NOTE:
% R_relax = time-dependent relaxation (-dM/dlog t)
% R_age   = aging scalar (tau ratio)
% These MUST NOT be confused

repoRoot = 'C:/Dev/matlab-functions';
docsPath = fullfile(repoRoot, 'docs', 'repo_execution_rules.md');
helperDir = fullfile(repoRoot, 'analysis', 'helpers');
helperPath = fullfile(helperDir, 'resolve_R_variable.m');
reportDir = fullfile(repoRoot, 'reports');
reportPath = fullfile(reportDir, 'R_variable_audit.md');
tablesDir = fullfile(repoRoot, 'tables');
statusPath = fullfile(tablesDir, 'R_variable_audit_status.csv');

if ~exist(reportDir, 'dir'), mkdir(reportDir); end
if ~exist(tablesDir, 'dir'), mkdir(tablesDir); end
if ~exist(helperDir, 'dir'), mkdir(helperDir); end

executionStatus = 'SUCCESS';
errorMessage = '';
filesScanned = 0;
ambiguousCount = 0;
ruleAdded = 'NO';

ambiguousFiles = {};
classifications = {};
mixingFlags = false(0,1);
topLevelCounts = zeros(0,1);

noteBlock = {
    '% NOTE:'
    '% R_relax = time-dependent relaxation (-dM/dlog t)'
    '% R_age   = aging scalar (tau ratio)'
    '% These MUST NOT be confused'
    ''
};
noteText = strjoin(noteBlock, newline);

try
    if exist(docsPath, 'file')
        docsText = fileread(docsPath);
    else
        docsText = ['# Repository execution rules (MATLAB)' newline newline];
    end

    criticalHeader = '### CRITICAL: Distinction between R variables';
    criticalBlock = strjoin({
        '### CRITICAL: Distinction between R variables'
        ''
        'There are TWO different R variables in this repository:'
        ''
        '1. Relaxation:'
        '   R_relax(T,t) = -dM/dlog(t)'
        '   -> time-dependent dynamics'
        ''
        '2. Aging:'
        '   R_age(T)'
        '   -> scalar ratio of times'
        ''
        'Rules:'
        ''
        '* Any time-dependent quantity MUST be named R_relax'
        '* Any scalar aging quantity MUST be named R_age'
        '* Using plain "R" in NEW code is FORBIDDEN'
        '* Legacy code using "R" is allowed but must be explicitly clarified'
        ''
    }, newline);

    if ~contains(docsText, criticalHeader)
        if ~endsWith(docsText, newline)
            docsText = [docsText newline];
        end
        docsText = [docsText newline criticalBlock];
        fid = fopen(docsPath, 'w');
        fwrite(fid, docsText);
        fclose(fid);
        ruleAdded = 'YES';
    end

    helperLines = {
        'function [R_relax, R_age, detected_type] = resolve_R_variable(T)'
        ''
        'R_relax = [];'
        'R_age   = [];'
        'detected_type = "unknown";'
        ''
        'vars = T.Properties.VariableNames;'
        ''
        'if any(strcmp(vars, ''R_relax''))'
        '    R_relax = T.R_relax;'
        '    detected_type = "relax";'
        'elseif any(strcmp(vars, ''R''))'
        '    % heuristic: check if time column exists'
        '    if any(contains(vars, ''logt'')) || any(contains(vars, ''time''))'
        '        R_relax = T.R;'
        '        detected_type = "relax";'
        '    else'
        '        R_age = T.R;'
        '        detected_type = "aging";'
        '    end'
        'end'
        ''
        'if any(strcmp(vars, ''R_age''))'
        '    R_age = T.R_age;'
        '    detected_type = "aging";'
        'end'
        ''
        'end'
        ''
    };
    fid = fopen(helperPath, 'w');
    fwrite(fid, strjoin(helperLines, newline));
    fclose(fid);

    allM = dir(fullfile(repoRoot, '**', '*.m'));
    filesScanned = numel(allM);

    noteTargets = {};
    hasStandalonePattern = '(?<![A-Za-z0-9_])R(?![A-Za-z0-9_])';

    for k = 1:numel(allM)
        absPath = fullfile(allM(k).folder, allM(k).name);
        relPath = strrep(absPath, [repoRoot '/'], '');
        relPath = strrep(relPath, [repoRoot '\'], '');
        relPath = strrep(relPath, '\', '/');

        txt = fileread(absPath);
        if isempty(txt)
            continue;
        end

        hasStandaloneR = ~isempty(regexp(txt, hasStandalonePattern, 'once'));
        if ~hasStandaloneR
            continue;
        end

        ambiguousFiles{end+1,1} = relPath; %#ok<AGROW>
        topLevelCounts(end+1,1) = numel(regexp(txt, hasStandalonePattern)); %#ok<AGROW>
        ambiguousCount = ambiguousCount + topLevelCounts(end);

        hasTimeSignal = ~isempty(regexpi(txt, 'logt|time[-_ ]?dependent|dM/dlog|relaxation|R_relax|tau\(T,t\)|\bt\b', 'once'));
        hasAgingSignal = ~isempty(regexpi(txt, 'aging|clock ratio|tau ratio|R_age|tau_w|waiting', 'once'));

        if hasTimeSignal && hasAgingSignal
            classifications{end+1,1} = 'unclear (mixed time+aging signals)'; %#ok<AGROW>
            mixingFlags(end+1,1) = true; %#ok<AGROW>
        elseif hasTimeSignal
            classifications{end+1,1} = 'likely relax'; %#ok<AGROW>
            mixingFlags(end+1,1) = false; %#ok<AGROW>
        elseif hasAgingSignal
            classifications{end+1,1} = 'likely aging'; %#ok<AGROW>
            mixingFlags(end+1,1) = false; %#ok<AGROW>
        else
            classifications{end+1,1} = 'unclear'; %#ok<AGROW>
            mixingFlags(end+1,1) = false; %#ok<AGROW>
        end

        if startsWith(relPath, 'Switching/analysis/') || startsWith(relPath, 'analysis/')
            noteTargets{end+1,1} = absPath; %#ok<AGROW>
        end
    end

    noteTargets = unique(noteTargets);
    for k = 1:numel(noteTargets)
        p = noteTargets{k};
        original = fileread(p);
        if contains(original, '% R_relax = time-dependent relaxation (-dM/dlog t)')
            continue;
        end
        updated = [noteText original];
        fid = fopen(p, 'w');
        fwrite(fid, updated);
        fclose(fid);
    end

    reportLines = {};
    reportLines{end+1,1} = '# R Variable Audit';
    reportLines{end+1,1} = '';
    reportLines{end+1,1} = 'Scope: repository `.m` scripts scanned for ambiguous standalone `R` usage.';
    reportLines{end+1,1} = '';
    reportLines{end+1,1} = '## Summary';
    reportLines{end+1,1} = '';
    reportLines{end+1,1} = ['- Files scanned: ' num2str(filesScanned)];
    reportLines{end+1,1} = ['- Ambiguous standalone `R` count: ' num2str(ambiguousCount)];
    reportLines{end+1,1} = ['- Files with ambiguous standalone `R`: ' num2str(numel(ambiguousFiles))];
    reportLines{end+1,1} = '';
    reportLines{end+1,1} = '## Ambiguous `R` Usage';
    reportLines{end+1,1} = '';
    reportLines{end+1,1} = '| File | Classification | Standalone R occurrences | Mixes time + scalar signals |';
    reportLines{end+1,1} = '|---|---|---:|---|';

    if isempty(ambiguousFiles)
        reportLines{end+1,1} = '| _(none)_ | n/a | 0 | NO |';
    else
        [~, order] = sort(lower(ambiguousFiles));
        for i = 1:numel(order)
            idx = order(i);
            mixTxt = 'NO';
            if mixingFlags(idx), mixTxt = 'YES'; end
            reportLines{end+1,1} = ['| `' ambiguousFiles{idx} '` | ' classifications{idx} ' | ' num2str(topLevelCounts(idx)) ' | ' mixTxt ' |'];
        end
    end

    reportLines{end+1,1} = '';
    reportLines{end+1,1} = '## Notes';
    reportLines{end+1,1} = '';
    reportLines{end+1,1} = '- This step is scan-only for ambiguity classification.';
    reportLines{end+1,1} = '- No physics/computation logic was modified by the audit pass.';

    fid = fopen(reportPath, 'w');
    fwrite(fid, strjoin(reportLines, newline));
    fclose(fid);

catch ME
    executionStatus = 'FAILED';
    errorMessage = ME.message;
end

statusHeaders = {'EXECUTION_STATUS','FILES_SCANNED','AMBIGUOUS_R_COUNT','RULE_ADDED','ERROR_MESSAGE'};
statusValues = {char(executionStatus), filesScanned, ambiguousCount, char(ruleAdded), char(errorMessage)};
statusTable = cell2table(statusValues, 'VariableNames', statusHeaders);
writetable(statusTable, statusPath);
