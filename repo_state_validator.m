function repo_state_validator()
%REPO_STATE_VALIDATOR Validate docs/repo_state.json against repository state.
%   - Verifies module paths, entry points, and analysis scripts.
%   - Verifies known run folders and run-root observables.csv/observable_matrix.csv.
%   - Verifies module observables for modules with known runs appear in
%     known-run observables.csv data (wide headers or long-format values).

    repoRoot = fileparts(mfilename('fullpath'));
    repoStatePath = fullfile(repoRoot, 'docs', 'repo_state.json');

    if ~isfile(repoStatePath)
        txtFallback = fullfile(repoRoot, 'docs', 'repo_state.json.txt');
        if isfile(txtFallback)
            error('repo_state_validator:MissingRepoStateJson', ...
                ['Missing required file: %s\nFound fallback file but it is not accepted: %s'], ...
                repoStatePath, txtFallback);
        else
            error('repo_state_validator:MissingRepoStateJson', ...
                'Missing required file: %s', repoStatePath);
        end
    end

    raw = fileread(repoStatePath);
    try
        state = jsondecode(raw);
    catch me
        error('repo_state_validator:InvalidJson', ...
            'Failed to parse %s: %s', repoStatePath, me.message);
    end

    errs = {};

    requiredTopLevel = { ...
        'modules', ...
        'observable_definitions', ...
        'cross_experiment_physics', ...
        'physics_abstraction', ...
        'run_system', ...
        'agent_rules' ...
    };
    for i = 1:numel(requiredTopLevel)
        f = requiredTopLevel{i};
        if ~isfield(state, f)
            errs{end+1} = sprintf('Missing required top-level field: %s', f); %#ok<AGROW>
        end
    end

    if ~isfield(state, 'modules') || ~isstruct(state.modules)
        errs{end+1} = 'repo_state.modules is missing or not an object/struct.'; %#ok<AGROW>
        throwValidation(errs);
    end

    moduleNames = fieldnames(state.modules);

    % Collect known run folders that pass existence checks.
    knownRunDirs = {};
    modulesWithKnownRuns = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    for i = 1:numel(moduleNames)
        modName = moduleNames{i};
        mod = state.modules.(modName);

        if ~isfield(mod, 'path') || ~(ischar(mod.path) || isstring(mod.path))
            errs{end+1} = sprintf('Module "%s": missing string field "path".', modName); %#ok<AGROW>
            continue;
        end

        modPathAbs = fullfile(repoRoot, char(mod.path));
        if ~isfolder(modPathAbs)
            errs{end+1} = sprintf('Module "%s": path does not exist: %s', modName, modPathAbs); %#ok<AGROW>
        end

        % Requirement: each module must provide entry_points and analysis_scripts.
        if ~isfield(mod, 'entry_points')
            errs{end+1} = sprintf('Module "%s": missing field "entry_points".', modName); %#ok<AGROW>
        else
            entryPoints = normalizeStringList(mod.entry_points);
            if isempty(entryPoints)
                errs{end+1} = sprintf('Module "%s": "entry_points" is empty.', modName); %#ok<AGROW>
            else
                for k = 1:numel(entryPoints)
                    ep = entryPoints{k};
                    epPath = resolveModuleFile(repoRoot, modPathAbs, ep);
                    if isempty(epPath) || ~isfile(epPath)
                        errs{end+1} = sprintf( ...
                            'Module "%s": entry point not found: %s (checked under module and repo root).', ...
                            modName, ep); %#ok<AGROW>
                    elseif ~isMatlabFile(epPath)
                        errs{end+1} = sprintf( ...
                            'Module "%s": entry point exists but is not a .m file: %s', ...
                            modName, epPath); %#ok<AGROW>
                    end
                end
            end
        end

        if ~isfield(mod, 'analysis_scripts')
            errs{end+1} = sprintf('Module "%s": missing field "analysis_scripts".', modName); %#ok<AGROW>
        else
            analysisScripts = normalizeStringList(mod.analysis_scripts);
            if isempty(analysisScripts)
                errs{end+1} = sprintf('Module "%s": "analysis_scripts" is empty.', modName); %#ok<AGROW>
            else
                for k = 1:numel(analysisScripts)
                    as = analysisScripts{k};
                    asPath = resolveModuleFile(repoRoot, modPathAbs, as);
                    if isempty(asPath) || ~isfile(asPath)
                        errs{end+1} = sprintf( ...
                            'Module "%s": analysis script not found: %s (checked under module and repo root).', ...
                            modName, as); %#ok<AGROW>
                    elseif ~isMatlabFile(asPath)
                        errs{end+1} = sprintf( ...
                            'Module "%s": analysis script exists but is not a .m file: %s', ...
                            modName, asPath); %#ok<AGROW>
                    end
                end
            end
        end

        if isfield(mod, 'known_runs')
            knownRuns = normalizeStringList(mod.known_runs);
            if ~isempty(knownRuns)
                modulesWithKnownRuns(modName) = true;
            end

            for k = 1:numel(knownRuns)
                runName = knownRuns{k};
                [runDir, canonicalRunDir] = resolveRunDir(repoRoot, modName, runName);
                if isempty(runDir) || ~isfolder(runDir)
                    errs{end+1} = sprintf( ...
                        ['Module "%s": known run folder not found: %s. ' ...
                         'Expected canonical location: %s'], ...
                        modName, runName, canonicalRunDir); %#ok<AGROW>
                    continue;
                end

                if ~runBelongsToModule(repoRoot, modName, runDir)
                    errs{end+1} = sprintf( ...
                        ['Module "%s": known run resolved under wrong module: %s. ' ...
                         'Expected canonical location: %s'], ...
                        modName, runDir, canonicalRunDir); %#ok<AGROW>
                end

                knownRunDirs{end+1} = runDir; %#ok<AGROW>

                obsCsv = fullfile(runDir, 'observables.csv');
                if ~isfile(obsCsv)
                    errs{end+1} = sprintf( ...
                        'Module "%s": known run missing run-root observables.csv: %s', ...
                        modName, obsCsv); %#ok<AGROW>
                end

                matrixCsvRoot = fullfile(runDir, 'observable_matrix.csv');
                matrixCsvTables = fullfile(runDir, 'tables', 'observable_matrix.csv');
                if ~isfile(matrixCsvRoot) && ~isfile(matrixCsvTables)
                    errs{end+1} = sprintf( ...
                        ['Module "%s": known run missing observable_matrix.csv at either ' ...
                         'run root or tables/: %s'], ...
                        modName, runDir); %#ok<AGROW>
                end
            end
        end
    end

    % Observables to validate: module observables only for modules that
    % currently provide known runs.
    definedObservables = collectDefinedObservables(state, modulesWithKnownRuns);
    definedObservables = unique(definedObservables, 'stable');
    for i = 1:numel(definedObservables)
        obs = definedObservables{i};
        if ~isValidObservableName(obs)
            errs{end+1} = sprintf('Invalid observable name in repo_state: "%s".', obs); %#ok<AGROW>
        end
    end

    % Check observable columns using observables.csv from resolved known runs only.
    obsFiles = {};
    if ~isempty(knownRunDirs)
        knownRunDirs = unique(knownRunDirs, 'stable');
        for i = 1:numel(knownRunDirs)
            csvPath = fullfile(knownRunDirs{i}, 'observables.csv');
            if isfile(csvPath)
                obsFiles{end+1} = csvPath; %#ok<AGROW>
            end
        end
    end

    if isempty(obsFiles)
        errs{end+1} = 'No observables.csv files found in resolved known runs.'; %#ok<AGROW>
    else
        observedUnion = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        csvNameCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
        for i = 1:numel(obsFiles)
            csvPath = obsFiles{i};
            try
                names = getCsvObservableNamesCached(csvNameCache, csvPath);
            catch me
                errs{end+1} = sprintf('Failed reading observables.csv data: %s (%s)', csvPath, me.message); %#ok<AGROW>
                continue;
            end

            for c = 1:numel(names)
                key = names{c};
                if ~isValidObservableName(key)
                    errs{end+1} = sprintf('Invalid observable name in observables.csv: "%s" (%s)', key, csvPath); %#ok<AGROW>
                    continue;
                end
                if ~isKey(observedUnion, key)
                    observedUnion(key) = true;
                end
            end
        end

        for i = 1:numel(definedObservables)
            obs = definedObservables{i};
            if ~isKey(observedUnion, obs)
                errs{end+1} = sprintf( ...
                    'Observable "%s" not found in any known-run observables.csv.', ...
                    obs); %#ok<AGROW>
            end
        end
    end

    throwValidation(errs);

    fprintf('repo_state validation PASSED\n');
end

function tf = isMatlabFile(p)
    [~, ~, ext] = fileparts(p);
    tf = strcmpi(ext, '.m');
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
        return;
    end
end

function p = resolveModuleFile(repoRoot, moduleRoot, relOrAbs)
    p = '';
    candidate = char(relOrAbs);

    if isAbsolutePath(candidate)
        if isfile(candidate)
            p = candidate;
        end
        return;
    end

    c1 = fullfile(moduleRoot, candidate);
    if isfile(c1)
        p = c1;
        return;
    end

    c2 = fullfile(repoRoot, candidate);
    if isfile(c2)
        p = c2;
        return;
    end
end

function tf = isAbsolutePath(p)
    tf = false;
    if isempty(p)
        return;
    end
    p = char(p);
    tf = startsWith(p, filesep) || ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once'));
end

function [runDir, canonicalRunDir] = resolveRunDir(repoRoot, moduleName, runName)
    runDir = '';
    canonicalRunDir = canonicalRunPath(repoRoot, moduleName, char(runName));
    if isfolder(canonicalRunDir)
        runDir = canonicalRunDir;
    end
end

function p = canonicalRunPath(repoRoot, moduleName, runName)
    moduleDir = normalizePath(moduleName);
    relPath = sprintf('results/%s/runs/%s', moduleDir, char(runName));
    p = fullfile(repoRoot, strrep(relPath, '/', filesep));
end

function tf = runBelongsToModule(repoRoot, moduleName, runDir)
    expectedBase = fullfile(repoRoot, 'results', lower(strtrim(char(moduleName))), 'runs');
    tf = startsWith(normalizePath(runDir), normalizePath(expectedBase));
end

function p = normalizePath(pIn)
    p = lower(strrep(char(pIn), '\', '/'));
end

function obsNames = collectDefinedObservables(state, modulesWithKnownRuns)
    obsNames = {};

    if isfield(state, 'modules') && isstruct(state.modules)
        modNames = fieldnames(state.modules);
        for i = 1:numel(modNames)
            modName = modNames{i};
            if ~isKey(modulesWithKnownRuns, modName)
                continue;
            end

            mod = state.modules.(modNames{i});
            if isfield(mod, 'observables') && isstruct(mod.observables)
                sub = fieldnames(mod.observables);
                for j = 1:numel(sub)
                    vals = normalizeStringList(mod.observables.(sub{j}));
                    obsNames = [obsNames; vals(:)]; %#ok<AGROW>
                end
            end
        end
    end

    obsNames = obsNames(~cellfun(@isempty, obsNames));
end

function names = readCsvObservableNames(csvPath)
    opts = detectImportOptions(csvPath);
    if isprop(opts, 'VariableNamingRule')
        opts.VariableNamingRule = 'preserve';
    end

    namesMap = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    % Wide-format support: column names.
    cols = opts.VariableNames;
    for i = 1:numel(cols)
        c = strtrim(char(cols{i}));
        if ~isempty(c) && ~isKey(namesMap, c)
            namesMap(c) = true;
        end
    end

    % Long-format support: include values from "observable" column when present.
    if any(strcmp(cols, 'observable'))
        if isprop(opts, 'DataLines')
            opts.DataLines = [2, Inf];
        end
        t = readtable(csvPath, opts);
        if ~isempty(t) && any(strcmp(t.Properties.VariableNames, 'observable'))
            vals = t.observable;
            if ischar(vals) || isstring(vals)
                vals = cellstr(string(vals));
            end
            if iscell(vals)
                for i = 1:numel(vals)
                    v = strtrim(char(vals{i}));
                    if ~isempty(v) && ~isKey(namesMap, v)
                        namesMap(v) = true;
                    end
                end
            end
        end
    end

    names = keys(namesMap);
end

function names = getCsvObservableNamesCached(cache, csvPath)
    key = normalizePath(csvPath);
    if isKey(cache, key)
        names = cache(key);
        return;
    end

    names = readCsvObservableNames(csvPath);
    cache(key) = names;
end

function tf = isValidObservableName(name)
    tf = ischar(name) || isstring(name);
    if ~tf
        return;
    end

    s = strtrim(char(name));
    if isempty(s)
        tf = false;
        return;
    end

    tf = ~isempty(regexp(s, '^[A-Za-z][A-Za-z0-9_]*$', 'once'));
end

function throwValidation(errs)
    if isempty(errs)
        return;
    end

    msg = sprintf('repo_state validation FAILED (%d issue(s)):\n', numel(errs));
    for i = 1:numel(errs)
        msg = [msg, sprintf(' - %s\n', errs{i})]; %#ok<AGROW>
    end
    error('repo_state_validator:ValidationFailed', '%s', msg);
end
