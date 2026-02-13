%% organize_appearance_files.m
% Automatically organizes GUI and formatting functions into clean folders.

root_app = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions\General ver1\appearanceControl";
root_general = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions\General ver1";

% === Define target folders ===
ctrlGUI_dir      = fullfile(root_app, "CtrlGUI");
refLineGUI_dir   = fullfile(root_app, "refLineGUI");
common_dir       = fullfile(root_app, "CommonFormatting");

% Create folders if needed
dirs = {ctrlGUI_dir, refLineGUI_dir, common_dir};
for i = 1:numel(dirs)
    if ~exist(dirs{i}, 'dir')
        mkdir(dirs{i});
        fprintf("Created folder: %s\n", dirs{i});
    end
end

%% === Files for CtrlGUI ===
ctrl_files = {
    "CtrlGUI.m"
    "applyColormapToFigures.m"
    "applyToSingleFigure.m"
    "getSliceIndices.m"
    "makeCustomColormap.m"
    "name2rgb.m"
};

%% === Files for refLineGUI ===
refline_files = {
    "refLineGUI.m"
    "addRefLine.m"
};

%% === Common formatting files (come from General ver1!) ===
common_files = {
    "formatAllFigures.m"
    "postFormatAllFigures.m"
    "convertCartesianFigureToPolar.m"
};

%% === Move GUI files ===
fprintf("\n=== Moving CtrlGUI-related files ===\n");
move_list(ctrl_files, root_app, ctrlGUI_dir);

fprintf("\n=== Moving refLineGUI-related files ===\n");
move_list(refline_files, root_app, refLineGUI_dir);

%% === Move common formatting files (from root_general, not root_app) ===
fprintf("\n=== Moving common formatting files ===\n");
move_list(common_files, root_general, common_dir);

fprintf("\n=== DONE! ===\n");


%% ====================================================================
%% Local helper function must be last
%% ====================================================================
function move_list(files, src_root, dst_folder)
    for k = 1:numel(files)
        src = fullfile(src_root, files{k});
        dst = fullfile(dst_folder, files{k});

        if exist(src, 'file')
            try
                movefile(src, dst);
                fprintf("Moved: %s\n", files{k});
            catch ME
                fprintf("FAILED to move %s: %s\n", files{k}, ME.message);
            end
        else
            fprintf("WARNING: File not found: %s\n", src);
        end
    end
end
