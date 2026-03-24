function repo_state_generator()
%REPO_STATE_GENERATOR Incrementally update observable definitions from known runs.
%   - Reads docs/repo_state.json
%   - Uses only modules.<name>.known_runs
%   - Reads observables.csv headers from canonical known-run locations:
%       results/<lower(module_name)>/runs/<run_name>/observables.csv
%   - Adds missing observable_definitions entries as:
%       "<observable>": { "type": "unknown" }
%   - Does not remove or overwrite existing definitions

    repoRoot = fileparts(mfilename('fullpath'));
    repoStatePath = fullfile(repoRoot, 'docs', 'repo_state.json');

    if ~isfile(repoStatePath)
        error('repo_state_generator:MissingRepoState', ...
            'Missing required file: %s', repoStatePath);
    end

    raw = fileread(repoStatePath);
    try
        state = jsondecode(raw);
    catch me
        error('repo_state_generator:InvalidJson', ...
            'Failed to parse %s: %s', repoStatePath, me.message);
    end

    if ~isfield(state, 'modules') || ~isstruct(state.modules)
        error('repo_state_generator:InvalidState', ...
            'repo_state.json missing valid "modules" object.');
    end

    stateChanged = false;
    if ~isfield(state, 'observable_definitions') || ~isstruct(state.observable_definitions)
        state.observable_definitions = struct();
        stateChanged = true;
    end

    moduleNames = fieldnames(state.modules);
    observableUnion = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    for i = 1:numel(moduleNames)
        moduleName = moduleNames{i};
        moduleData = state.modules.(moduleName);

        knownRuns = normalizeStringList(getFieldOrDefault(moduleData, 'known_runs', {}));
        if isempty(knownRuns)
            continue;
        end

        moduleDir = normalizePath(moduleName);
        for k = 1:numel(knownRuns)
            runName = knownRuns{k};
            runRel = sprintf('results/%s/runs/%s/observables.csv', moduleDir, char(runName));
            obsCsvPath = fullfile(repoRoot, strrep(runRel, '/', filesep));
            if ~isfile(obsCsvPath)
                continue;
            end

            cols = readCsvHeaders(obsCsvPath);
            for c = 1:numel(cols)
                key = cols{c};
                if ~isempty(key) && ~isKey(observableUnion, key)
                    observableUnion(key) = true;
                end
            end
        end
    end

    observedNames = keys(observableUnion);
    existingDefs = fieldnames(state.observable_definitions);
    existingMap = containers.Map(existingDefs, true(1, numel(existingDefs)));

    addedCount = 0;
    for i = 1:numel(observedNames)
        obsName = observedNames{i};
        if ~isKey(existingMap, obsName)
            state.observable_definitions.(obsName) = struct('type', 'unknown');
            existingMap(obsName) = true;
            addedCount = addedCount + 1;
            stateChanged = true;
        end
    end

    if stateChanged
        jsonOut = encodeJsonPretty(state);
        atomicWriteFile(repoStatePath, jsonOut);
    end

    fprintf('observables found: %d\n', numel(observedNames));
    fprintf('new observables added: %d\n', addedCount);
end

function value = getFieldOrDefault(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName)
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function out = normalizeStringList(val)
    out = {};
    if isempty(val)
        return;
    end

    if ischar(val)
        out = {val};
        return;
    end

    if isstring(val)
        if isscalar(val)
            out = {char(val)};
        else
            out = cellstr(val(:));
        end
        return;
    end

    if iscell(val)
        tmp = {};
        for i = 1:numel(val)
            if ischar(val{i}) || isstring(val{i})
                tmp{end+1} = char(val{i}); %#ok<AGROW>
            end
        end
        out = tmp;
    end
end

function cols = readCsvHeaders(csvPath)
    opts = detectImportOptions(csvPath);
    if isprop(opts, 'VariableNamingRule')
        opts.VariableNamingRule = 'preserve';
    end

    % Read only one data row to keep I/O small while preserving headers.
    if isprop(opts, 'DataLines')
        opts.DataLines = [2, 2];
    end

    t = readtable(csvPath, opts);
    cols = t.Properties.VariableNames;
end

function s = encodeJsonPretty(v)
    try
        s = jsonencode(v, PrettyPrint=true);
    catch
        s = jsonencode(v);
    end
end

function atomicWriteFile(targetPath, contents)
    targetDir = fileparts(targetPath);
    tmpPath = [tempname(targetDir), '.tmp'];
    fid = -1;
    try
        fid = fopen(tmpPath, 'w');
        if fid < 0
            error('repo_state_generator:WriteFailed', ...
                'Failed to open temp file for writing: %s', tmpPath);
        end

        fwrite(fid, contents, 'char');
        fclose(fid);
        fid = -1;

        if ~movefile(tmpPath, targetPath, 'f')
            error('repo_state_generator:WriteFailed', ...
                'Failed atomic replace of %s using temp file %s', targetPath, tmpPath);
        end
    catch me
        if fid >= 0
            fclose(fid);
        end
        if isfile(tmpPath)
            delete(tmpPath);
        end
        rethrow(me);
    end
end

function p = normalizePath(pIn)
    p = lower(strtrim(char(pIn)));
    p = strrep(p, '\', '/');
end
