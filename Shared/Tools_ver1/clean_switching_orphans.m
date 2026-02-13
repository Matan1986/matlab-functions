function clean_switching_orphans(baseFolder)
% CLEAN_SWITCHING_ORPHANS  safely remove duplicate files in old_internal
%
% This script checks for files inside old_internal that have an active copy
% in any of the functional folders (plots, parsing, utils, main, or root).
%
% It only proposes deleting the *old_internal* versions.

    if nargin < 1
        baseFolder = pwd; % if user runs inside the folder
    end

    oldInt = fullfile(baseFolder, "old_internal");
    if ~isfolder(oldInt)
        error("old_internal folder not found!");
    end

    % folders where "active" files should exist
    activeFolders = {
        baseFolder
        fullfile(baseFolder, "main")
        fullfile(baseFolder, "plots")
        fullfile(baseFolder, "parsing")
        fullfile(baseFolder, "utils")
        fullfile(baseFolder, "tables")
    };

    fprintf("=== Searching for orphans inside: %s ===\n\n", oldInt);

    oldFiles = dir(fullfile(oldInt, "*.m"));
    toDelete = {};

    for k = 1:numel(oldFiles)
        fname = oldFiles(k).name;
        foundActive = false;

        for a = 1:numel(activeFolders)
            af = activeFolders{a};
            if af == oldInt
                continue; % skip old_internal itself
            end

            if isfile(fullfile(af, fname))
                foundActive = true;
                break;
            end
        end

        if foundActive
            fprintf("Orphan candidate: old_internal/%s  (active version exists elsewhere)\n", fname);
            toDelete{end+1} = fullfile(oldInt, fname);
        end
    end

    if isempty(toDelete)
        fprintf("\nNo orphan files found. Everything is clean.\n");
        return;
    end

    fprintf("\n=== Files proposed for deletion ===\n");
    for i = 1:numel(toDelete)
        fprintf("  %s\n", toDelete{i});
    end

    resp = input("\nDelete these old_internal duplicates? (Y/N): ", "s");
    if strcmpi(resp, "Y")
        for i = 1:numel(toDelete)
            delete(toDelete{i});
            fprintf("Deleted: %s\n", toDelete{i});
        end
        disp("=== Cleanup complete ===");
    else
        disp("Canceled. No files deleted.");
    end
end
