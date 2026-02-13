function DIAGNOSE_SCM8_Path()
% DIAGNOSE_SCM8_PATH - Find where ScientificColourMaps8 actually is

fprintf('\n===== COMPREHENSIVE SCM8 PATH DIAGNOSIS =====\n\n');

% Get all path entries
pathEntries = strsplit(path, pathsep);
fprintf('Total MATLAB path entries: %d\n\n', numel(pathEntries));

% Look for folders with colormap-related names
fprintf('Searching for directories with "colourmap" or "colormap" in name...\n');
colormapFolders = {};
for p = 1:numel(pathEntries)
    folder = pathEntries{p};
    if ~isempty(folder)
        [~, folderName] = fileparts(folder);
        if contains(lower(folderName), 'colourmap') || contains(lower(folderName), 'colormap')
            colormapFolders{end+1} = folder;
            fprintf('  Found: %s\n', folder);
        end
    end
end

% Scan for .m files that look like colormaps
fprintf('\nSearching for potential colormap .m files...\n');
foundMaps = {};
for p = 1:numel(pathEntries)
    folder = pathEntries{p};
    if ~isempty(folder) && isfolder(folder)
        try
            files = dir(fullfile(folder, '*.m'));
            for f = 1:numel(files)
                fname = files(f).name(1:end-2);
                % Look for likely colormap names (short, uncommon MATLAB names)
                if numel(fname) < 15 && ~strcmp(fname, 'scientificColourMaps8')
                    % Try common colormap name patterns
                    if contains(lower(fname), {'colormaps8', 'scm', 'batlow', 'davos', 'roma', 'turku', 'oslo', 'nuuk'})
                        fprintf('  Found potential map: %s (in %s)\n', fname, folder);
                        foundMaps{end+1} = fname;
                    end
                end
            end
        catch
        end
    end
end

% Try running a few common colormap names directly
fprintf('\nAttempting to call common colormap functions directly...\n');
testNames = {'davos', 'batlow', 'roma', 'turku', 'oslo', 'nuuk', 'batlowS', 'romaO', 'oleron'};
for t = 1:numel(testNames)
    try
        cmap = feval(testNames{t}, 8);
        fprintf('  ✓ %s() works! (returned %dx3 array)\n', testNames{t}, size(cmap,1));
    catch
    end
end

% List what "which" can actually find
fprintf('\nTesting "which" for common names...\n');
for t = 1:numel(testNames)
    result = which(testNames{t}, '-all');
    if ~isempty(result)
        if ischar(result), result = {result}; end
        fprintf('  which(%s): %s\n', testNames{t}, result{1});
    end
end

end
