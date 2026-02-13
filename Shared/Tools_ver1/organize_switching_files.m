function organize_switching_files(baseFolder)
% ORGANIZE_SWITCHING_FILES
% Automatically organizes files in "Switching ver7" into:
%   main / parsing / plots / utils / tables / old_internal
%
% Safe: never deletes files, never overwrites, prints moves.

    if nargin < 1
        baseFolder = uigetdir(pwd, "Select 'Switching ver7' folder");
        if baseFolder == 0
            disp("Canceled.");
            return;
        end
    end

    fprintf("\n=== Organizing Switching ver7 ===\n");
    fprintf("Base folder: %s\n", baseFolder);

    % ---------- Create target folders ----------
    sub = struct();
    sub.main   = make_dir(baseFolder, "main");
    sub.parsing = make_dir(baseFolder, "parsing");
    sub.plots   = make_dir(baseFolder, "plots");
    sub.utils   = make_dir(baseFolder, "utils");
    sub.tables  = make_dir(baseFolder, "tables");
    sub.old_internal = make_dir(baseFolder, "old_internal");

    % ---------- List all .m and .asv files ----------
    files = dir(fullfile(baseFolder, "*.m"));
    files_asv = dir(fullfile(baseFolder, "*.asv"));
    allFiles = [files; files_asv];

    % ---------- Classification rules ----------
    keywords = struct();
    keywords.main = ["Switching_main", "processFilesSwitching"];
    keywords.parsing = ["extract_", "mapChannelName", "resolve_x_label"];
    keywords.plots = ["plot", "createFiltered", "createUnfiltered", "createFilteredCentered"];
    keywords.utils = ["convertDepUnits", "remove_outliers", "formatLegendEntry", "legendEntry", "build_legend"];
    keywords.tables = ["createTableSwitching"];
    keywords.old_internal = [".asv", "P2P", "createPlotsSwitching"];

    % ---------- Process each file ----------
    for k = 1:numel(allFiles)
        src = fullfile(baseFolder, allFiles(k).name);
        fname = allFiles(k).name;

        target = classify_file(fname, keywords);  % decide where it goes

        if target == "keep"
            fprintf("Leaving file in place (no rule matched): %s\n", fname);
            continue;
        end

        dstFolder = sub.(target);
        safe_move(src, dstFolder);
    end

    fprintf("\n=== DONE organizing Switching ver7 ===\n");
end

% ======================================================================
% ----------------- Helper: create directory if needed -----------------
function folder = make_dir(base, name)
    folder = fullfile(base, name);
    if ~exist(folder, "dir")
        mkdir(folder);
        fprintf("Created: %s\n", folder);
    end
end

% ======================================================================
% ----------------- Helper: classify file by name ----------------------
function target = classify_file(fname, keywords)

    % Old internal files
    if endsWith(fname, ".asv") || contains(fname, "old", "IgnoreCase", true)
        target = "old_internal";
        return;
    end

    if contains(fname, keywords.main)
        target = "main";
        return;
    end

    if contains_any(fname, keywords.parsing)
        target = "parsing";
        return;
    end

    if contains_any(fname, keywords.plots)
        target = "plots";
        return;
    end

    if contains_any(fname, keywords.utils)
        target = "utils";
        return;
    end

    if contains_any(fname, keywords.tables)
        target = "tables";
        return;
    end

    % Otherwise keep in place
    target = "keep";
end

% ======================================================================
% --------------------- Helper: safe move ------------------------------
function safe_move(src, dstFolder)
    % Make sure inputs are char (MATLAB older versions are picky)
    src = char(src);
    dstFolder = char(dstFolder);

    [~, name, ext] = fileparts(src);
    dst = fullfile(dstFolder, [name ext]);
    dst = char(dst);   % <-- FIX: guarantee char

    % Already in correct place
    if strcmp(src, dst)
        return;
    end

    % If destination exists, skip
    if exist(dst, 'file') == 2
        fprintf("SKIPPED (already exists): %s\n", dst);
        return;
    end

    % Perform move
    movefile(src, dst);
    fprintf("Moved: %s --> %s\n", name, dstFolder);
end


% ======================================================================
% --------------------- Helper: contains_any ---------------------------
function tf = contains_any(str, list)
    tf = false;
    list = cellstr(list);
    for i = 1:numel(list)
        if contains(str, list{i}, "IgnoreCase", true)
            tf = true;
            return;
        end
    end
end
