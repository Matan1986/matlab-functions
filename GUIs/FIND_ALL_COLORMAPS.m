function FIND_ALL_COLORMAPS()
% FIND_ALL_COLORMAPS - Exhaustively search for all potential colormaps

fprintf('\n===== EXHAUSTIVE COLORMAP SEARCH =====\n\n');

% Get all path entries
pathEntries = strsplit(path, pathsep);

% Search every directory for .m files
fprintf('Searching %d path directories for potential colormaps...\n\n', numel(pathEntries));

allPotentialMaps = {};
scm8Directory = '';

for p = 1:numel(pathEntries)
    folder = pathEntries{p};
    if ~isempty(folder) && isfolder(folder)
        try
            files = dir(fullfile(folder, '*.m'));
            if numel(files) > 0
                % Look for specific path patterns
                if contains(folder, 'scientificColourMaps', 'IgnoreCase', true) || ...
                   contains(folder, 'scientificColorMaps', 'IgnoreCase', true)
                    fprintf('✓ Found potential SCM8 folder: %s\n', folder);
                    fprintf('  Contains %d .m files:\n', numel(files));
                    for f = 1:min(10, numel(files))
                        fname = files(f).name(1:end-2);
                        fprintf('    - %s\n', fname);
                    end
                    scm8Directory = folder;
                    break;
                end
            end
        catch
        end
    end
end

if isempty(scm8Directory)
    fprintf('ScientificColourMaps8 folder not found in path.\n');
    fprintf('Checking current directory and immediate subfolders...\n\n');
    
    cwd = pwd;
    fprintf('Current directory: %s\n', cwd);
    
    % Check if ScientificColourMaps8 is in current dir or parent
    testPaths = {
        fullfile(cwd, 'scientificColourMaps8')
        fullfile(cwd, 'ScientificColourMaps8')
        fullfile(cwd, 'scientificColorMaps8')
        fullfile(fileparts(cwd), 'scientificColourMaps8')
    };
    
    for t = 1:numel(testPaths)
        if isfolder(testPaths{t})
            fprintf('\n✓ Found folder: %s\n', testPaths{t});
            files = dir(fullfile(testPaths{t}, '*.m'));
            fprintf('  Contains %d .m files\n', numel(files));
            scm8Directory = testPaths{t};
            break;
        end
    end
end

% If found, list all and test a couple
if ~isempty(scm8Directory)
    fprintf('\n===== TESTING COLORMAPS FROM: %s =====\n\n', scm8Directory);
    
    files = dir(fullfile(scm8Directory, '*.m'));
    mapNames = {};
    for f = 1:numel(files)
        fname = files(f).name(1:end-2);
        if ~strcmpi(fname, 'scientificColourMaps8')
            mapNames{end+1} = fname;
        end
    end
    
    fprintf('Found %d potential colormaps\n\n', numel(mapNames));
    
    % Test first 3
    for t = 1:min(3, numel(mapNames))
        mapName = mapNames{t};
        try
            % Add directory to path temporarily to test
            addpath(scm8Directory);
            cmap = feval(mapName, 32);
            rmpath(scm8Directory);
            
            if ismatrix(cmap) && size(cmap,2) == 3
                fprintf('✓ %s(): OK (%dx3 double)\n', mapName, size(cmap,1));
            else
                fprintf('✗ %s(): Bad format (%s)\n', mapName, class(cmap));
            end
        catch ME
            rmpath(scm8Directory);
            fprintf('✗ %s(): %s\n', mapName, ME.message);
        end
    end
else
    fprintf('\n===== NO SCIENTIFICCOLOURMAPS8 FOUND =====\n');
    fprintf('The folder is not on the MATLAB path and not in standard locations.\n');
    fprintf('User must add it manually using addpath() or install it.\n');
end

end
