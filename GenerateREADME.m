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

% Collect module rows
moduleRows = {};
for i = 1:numel(moduleDirs)
    folderName = moduleDirs{i};
    folderPath = fullfile(rootDir, folderName);

    % Find main scripts
    mainFiles = [
        dir(fullfile(folderPath, "*_main.m"));
        dir(fullfile(folderPath, "Main_*.m"))
    ];

    for k = 1:numel(mainFiles)
        fileName = mainFiles(k).name;
        filePath = fullfile(folderPath, fileName);

        [moduleName, versionStr] = parseModuleNameVersion(folderName);
        desc = extractDescription(filePath, moduleName);

        moduleRows(end + 1, :) = {moduleName, versionStr, fileName, desc}; %#ok<AGROW>
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
md{end + 1} = "| Module Name | Version | File | Description |";
md{end + 1} = "|---|---|---|---|";

if isempty(moduleRows)
    md{end + 1} = "| No modules found |  |  |  |";
else
    for i = 1:size(moduleRows, 1)
        md{end + 1} = sprintf("| %s | %s | `%s` | %s |", ...
            moduleRows{i, 1}, moduleRows{i, 2}, moduleRows{i, 3}, moduleRows{i, 4});
    end
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
md{end + 1} = "run(fullfile('Aging ver2','Main_Aging.m'))";
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
