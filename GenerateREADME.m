% GenerateREADME.m
% Auto-generate README_GENERATED.md for the MATLAB Functions Library

% Start timer
startTime = tic;

% Root directory (folder containing this script)
rootDir = fileparts(mfilename('fullpath'));

% Folder patterns to scan
patterns = {"*ver*", "GUIs", "General*", "Tools*"};

% Collect module folders
moduleDirs = {};
for i = 1:numel(patterns)
    d = dir(fullfile(rootDir, patterns{i}));
    for k = 1:numel(d)
        if d(k).isdir && ~startsWith(d(k).name, ".")
            moduleDirs{end + 1} = d(k).name; %#ok<AGROW>
        end
    end
end

% Unique and sort
moduleDirs = unique(moduleDirs);

% Collect module rows + deviations
moduleRows = {};
nestedMainModules = {};
noMainModules = {};
namingAnomalies = {};
for i = 1:numel(moduleDirs)
    folderName = moduleDirs{i};
    folderPath = fullfile(rootDir, folderName);

    [allMainRel, rootMainRel, nestedMainRel] = findMainScripts(folderPath); %#ok<ASGLU>

    [moduleName, versionStr] = parseModuleNameVersion(folderName);

    if isempty(allMainRel)
        noMainModules{end + 1} = folderName; %#ok<AGROW>
        moduleRows(end + 1, :) = {moduleName, versionStr, "-", "none", "", ...
            sprintf("No main-like script found in %s", folderName)}; %#ok<AGROW>
        continue;
    end

    if ~isempty(nestedMainRel)
        nestedMainModules{end + 1} = folderName; %#ok<AGROW>
    end

    % Prefer root mains when both root and nested exist; still list all
    % (root first) and mark as multiple when applicable.
    if ~isempty(rootMainRel)
        preferred = [rootMainRel(:); setdiff(nestedMainRel(:), rootMainRel(:), 'stable')];
    else
        preferred = allMainRel(:);
    end

    hasMultiple = numel(preferred) > 1;
    if hasMultiple
        mainLocation = "multiple";
        warningFlag = "⚠ multiple mains";
    elseif ~isempty(rootMainRel)
        mainLocation = "root";
        warningFlag = "";
    else
        mainLocation = "nested";
        warningFlag = "";
    end

    for k = 1:numel(preferred)
        relPath = preferred{k};
        filePath = fullfile(folderPath, relPath);
        desc = extractDescription(filePath, moduleName);

        if contains(lower(relPath), "relexation")
            namingAnomalies{end + 1} = fullfile(folderName, relPath); %#ok<AGROW>
        end

        moduleRows(end + 1, :) = {moduleName, versionStr, relPath, mainLocation, warningFlag, desc}; %#ok<AGROW>
    end
end

% Sort alphabetically by module name
if ~isempty(moduleRows)
    [~, idx] = sort(lower(string(moduleRows(:, 1))));
    moduleRows = moduleRows(idx, :);
end

% Build README content
md = {};
md{end + 1} = "# MATLAB Functions Library";
md{end + 1} = "";
md{end + 1} = "## Quantum Materials Analysis Pipelines";
md{end + 1} = "";
md{end + 1} = "### Overview";
md{end + 1} = "This library provides MATLAB scripts and utilities for analyzing quantum materials experiments across multiple module pipelines and versions.";
md{end + 1} = "";
md{end + 1} = "### Module Table";
md{end + 1} = "| Module Name | Version | File | MainLocation | Warning | Description |";
md{end + 1} = "|---|---|---|---|---|---|";

if isempty(moduleRows)
    md{end + 1} = "| No modules found |  |  |  |  |  |";
else
    for i = 1:size(moduleRows, 1)
        md{end + 1} = sprintf("| %s | %s | `%s` | %s | %s | %s |", ...
            moduleRows{i, 1}, moduleRows{i, 2}, moduleRows{i, 3}, ...
            string(moduleRows{i, 4}), string(moduleRows{i, 5}), moduleRows{i, 6});
    end
end

md{end + 1} = "";
md{end + 1} = "### Deviations / Notes";

if isempty(nestedMainModules)
    md{end + 1} = "- Nested mains: none";
else
    md{end + 1} = sprintf("- Nested mains: %s", strjoin(unique(nestedMainModules), ", "));
end

if isempty(noMainModules)
    md{end + 1} = "- Modules with no main-like file: none";
else
    md{end + 1} = sprintf("- Modules with no main-like file: %s", strjoin(unique(noMainModules), ", "));
end

if isempty(namingAnomalies)
    md{end + 1} = "- Naming anomalies: none";
else
    md{end + 1} = sprintf("- Naming anomalies: %s", strjoin(unique(namingAnomalies), ", "));
end

md{end + 1} = "";
md{end + 1} = "### Utilities";
md{end + 1} = "- General ver2/ contains shared analysis helpers and plotting utilities.";
md{end + 1} = "- Tools ver1/ contains general purpose tools used across modules.";
md{end + 1} = "";
md{end + 1} = "### Usage";
md{end + 1} = "1. Open MATLAB and set the current folder to this repository root.";
md{end + 1} = "2. Run a module main script, for example:";
md{end + 1} = "";
md{end + 1} = "```matlab";
md{end + 1} = "run(fullfile('Aging','Main_Aging.m'))";
md{end + 1} = "```";
md{end + 1} = "";
md{end + 1} = "### Dependencies";
md{end + 1} = "- MATLAB base installation.";
md{end + 1} = "- Additional toolboxes may be required by specific modules.";
md{end + 1} = "";

% Write README_GENERATED.md
outPath = fullfile(rootDir, "README_GENERATED.md");
fid = fopen(outPath, "w");
for i = 1:numel(md)
    fprintf(fid, "%s\n", md{i});
end
fclose(fid);

% Console output
fprintf("Found %d modules\n", size(moduleRows, 1));
fprintf("Execution time: %.3f s\n", toc(startTime));

function desc = extractDescription(filePath, moduleName)
% Extract first continuous comment block after function declaration

    desc = "";
    try
        txt = fileread(filePath);
    catch
        desc = sprintf("Analysis module for %s", moduleName);
        return;
    end

    lines = splitlines(txt);
    inHeader = true;
    collecting = false;
    comments = {};

    for i = 1:numel(lines)
        line = strtrim(lines{i});

        if inHeader
            if startsWith(line, "function")
                inHeader = false;
                continue;
            end
            if startsWith(line, "%")
                inHeader = false;
            elseif ~isempty(line)
                inHeader = false;
            end
        end

        if ~inHeader
            if startsWith(line, "%")
                collecting = true;
                comments{end + 1} = strtrim(erase(line, "%")); %#ok<AGROW>
            else
                if collecting
                    break;
                end
            end
        end
    end

    if isempty(comments)
        desc = sprintf("Analysis module for %s", moduleName);
    else
        desc = strtrim(strjoin(comments, " "));
        if isempty(desc)
            desc = sprintf("Analysis module for %s", moduleName);
        end
    end
end

function [moduleName, versionStr] = parseModuleNameVersion(folderName)
% Split into module name and version string if pattern like "ver3" exists

    tokens = regexp(folderName, "(.*)\s+ver(\d+)", "tokens", "once");
    if ~isempty(tokens)
        moduleName = strtrim(tokens{1});
        versionStr = sprintf("ver%s", tokens{2});
    else
        moduleName = folderName;
        versionStr = "";
    end
end

function [allMainRel, rootMainRel, nestedMainRel] = findMainScripts(modulePath)
% Find main scripts recursively up to depth 2:
% - module root:           <module>/X.m
% - one nested level only: <module>/<subfolder>/X.m

    d = dir(fullfile(modulePath, '**', '*.m'));

    allMainRel = {};
    rootMainRel = {};
    nestedMainRel = {};

    for i = 1:numel(d)
        if d(i).isdir
            continue;
        end

        name = d(i).name;
        if ~(endsWith(name, '_main.m', 'IgnoreCase', true) || startsWith(name, 'Main_', 'IgnoreCase', true))
            continue;
        end

        absPath = fullfile(d(i).folder, d(i).name);
        relPath = strrep(absPath, [modulePath filesep], '');
        relParts = strsplit(relPath, filesep);

        % Ignore deeper than one nested directory
        if numel(relParts) > 2
            continue;
        end

        % Safety: ignore external package subtree if it appears
        if contains(lower(relPath), ['github_repo' filesep])
            continue;
        end

        allMainRel{end + 1} = relPath; %#ok<AGROW>
        if numel(relParts) == 1
            rootMainRel{end + 1} = relPath; %#ok<AGROW>
        else
            nestedMainRel{end + 1} = relPath; %#ok<AGROW>
        end
    end

    allMainRel = unique(allMainRel, 'stable');
    rootMainRel = unique(rootMainRel, 'stable');
    nestedMainRel = unique(nestedMainRel, 'stable');
end
