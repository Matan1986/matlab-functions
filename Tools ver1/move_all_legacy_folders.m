function move_all_legacy_folders(matlabRoot)
% Move all legacy folders OUTSIDE the Matlab functions tree.
%
% Example:
%   move_all_legacy_folders("C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions")

    matlabRoot = string(matlabRoot);

    % Target folder to place all legacy folders
    archiveRoot = fullfile(matlabRoot, "..", "Matlab Legacy Archive");
    archiveRoot = string(fullfile(archiveRoot)); % normalize path

    if ~exist(archiveRoot, 'dir')
        mkdir(archiveRoot);
        fprintf("Created legacy archive folder:\n  %s\n\n", archiveRoot);
    end

    % Patterns of folder names considered legacy
    patterns = ["legacy", "Legacy", "old", "Old", "old_internal", "old functions", "old_functions"];

    % Find all subfolders recursively
    allDirs = strsplit(string(genpath(matlabRoot)), pathsep);

    fprintf("=== Scanning for legacy folders ===\n");

    for d = allDirs
        if d == "" || d == matlabRoot
            continue;
        end

        folderName = split(string(d), filesep);
        folderName = folderName(end);

        % Check if folder name matches any legacy pattern
        isLegacy = any(contains(folderName, patterns, 'IgnoreCase', true));
        if ~isLegacy
            continue;
        end

        % Don't move the archive itself if user re-runs the code
        if contains(d, archiveRoot)
            continue;
        end

        % Decide new destination path
        newDst = fullfile(archiveRoot, folderName);

        % If folder already exists → append timestamp
        if exist(newDst, 'dir')
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            newDst = fullfile(archiveRoot, folderName + "_" + timestamp);
        end

        % Perform move
        fprintf("Moving legacy folder:\n  %s\n  --> %s\n\n", d, newDst);
        movefile(d, newDst);
    end

    fprintf("\n=== DONE ===\nAll legacy folders have been moved outside Matlab functions.\n");
end
