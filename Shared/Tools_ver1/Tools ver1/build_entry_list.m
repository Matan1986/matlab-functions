function entryPoints = build_entry_list(rootFolder)
% BUILD_ENTRY_LIST  Return a column cell array of entry-point function names.

    if nargin < 1
        rootFolder = pwd;
    end

    entryPoints = {};   % always column format
    entryPoints = entryPoints(:);  % force column

    % -------- Add all fitting functions automatically --------
    fittingFolder = fullfile(rootFolder, 'Fitting ver1');
    F = dir(fullfile(fittingFolder, '*.m'));

    for i = 1:numel(F)
        [~, name] = fileparts(F(i).name);
        entryPoints{end+1,1} = name;   % force column
    end

    % -------- Add GUI/tools you run manually --------
    manualTools = {
        'refLineGUI'
        'CtrlGUI'
        'convertCartesianFigureToPolar'
        'formatAllFigures'
        'postFormatAllFigures'
    };
    entryPoints = [entryPoints; manualTools(:)];

    % -------- Add save utilities --------
    saveTools = {
        'save_all'
        'save_figs'
        'save_figs_and_JPEG'
        'save_JPEG'
        'save_PNG'
    };
    entryPoints = [entryPoints; saveTools(:)];

    % -------- Add cmocean --------
    entryPoints = [entryPoints; {'cmocean'}];

    % Remove duplicates
    entryPoints = unique(entryPoints, 'stable');
end
