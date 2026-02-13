function organize_figure_saving_files()

disp("=== Organizing figure-saving utilities ===");

%% ROOT paths
root = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions\General ver1";
saveRoot = fullfile(root, "figureSaving");

%% 1) Create folder if missing
if ~exist(saveRoot, 'dir')
    mkdir(saveRoot);
    fprintf("Created folder: %s\n", saveRoot);
end

%% 2) Files that should be moved
fileList = {
    "save_all.m"
    "save_figs.m"
    "save_figs_and_JPEG.m"
    "save_JPEG.m"
    "save_PNG.m"
    "quickSaveFigsPPT_simple.m"
    "applyFormattingToAllFigures_old.m"   % optional/legacy
};

%% 3) Move loop
sourceDir = root;
for i = 1:numel(fileList)
    f = fileList{i};

    src = fullfile(sourceDir, f);
    dst = fullfile(saveRoot, f);

    if ~exist(src, "file")
        warning("NOT FOUND: %s", src);
        continue;
    end

    try
        movefile(src, dst);
        fprintf("Moved: %s\n", f);
    catch ME
        fprintf("FAILED to move %s\nReason: %s\n", f, ME.message);
    end
end

disp("=== DONE organizing saving utilities ===");

end
