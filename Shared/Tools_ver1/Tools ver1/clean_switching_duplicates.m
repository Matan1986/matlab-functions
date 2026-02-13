function clean_switching_duplicates()

base = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions\Switching ver7";

% folders
root      = base;
old_int   = fullfile(base, "old_internal");
plots_dir = fullfile(base, "plots");

% candidate filenames known to create duplicates
suspects = ["createP2PSwitching.m", ...
            "createPlotsSwitching.m", ...
            "plotFilteredData.m"];

fprintf("=== Checking for duplicates in Switching ver7 ===\n\n");

toDelete = [];

for f = suspects
    f_root  = fullfile(root,      f);
    f_old   = fullfile(old_int,   f);
    f_plots = fullfile(plots_dir, f);

    exists_root  = exist(f_root,  "file") == 2;
    exists_old   = exist(f_old,   "file")  == 2;
    exists_plots = exist(f_plots, "file") == 2;

    % report
    fprintf("File: %s\n", f);
    fprintf("  In root?      %d\n", exists_root);
    fprintf("  In old_internal? %d\n", exists_old);
    fprintf("  In plots?     %d\n", exists_plots);

    % logic:
    % ----------------------------------------------
    % createP2PSwitching.m  -> keep ONLY old_internal
    % createPlotsSwitching.m -> keep ONLY old_internal
    % plotFilteredData.m -> keep ONLY plots/
    % ----------------------------------------------

    if f == "plotFilteredData.m"
        % keep plots version
        if exists_old
            toDelete(end+1) = string(f_old);
        end
        if exists_root
            toDelete(end+1) = string(f_root);
        end

    else
        % the other two: keep old_internal only
        if exists_root
            toDelete(end+1) = string(f_root);
        end
    end

    fprintf("\n");
end

% summary
fprintf("\n=== Files marked for deletion ===\n");
disp(toDelete');

if isempty(toDelete)
    fprintf("No duplicates found. Nothing to delete.\n");
    return;
end

% ask user
resp = input("Delete these files? (Y/N): ", "s");

if strcmpi(resp, "Y")
    for f = toDelete
        if exist(f, "file")
            delete(f);
            fprintf("Deleted: %s\n", f);
        end
    end
    fprintf("\n=== Cleanup complete ===\n");
else
    fprintf("Aborted. No files were deleted.\n");
end

end
