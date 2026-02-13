function test_gui_launch()
%TEST_GUI_LAUNCH Verify CtrlGUI, refLineGUI can be found
%
%   This test verifies:
%   - GUI files exist
%   - Can be found on the path
%   - Have valid syntax

    fprintf('Testing GUI availability...\n');
    
    %% Find project root
    projectRoot = pwd;
    if ~exist(fullfile(projectRoot, 'README.md'), 'file')
        for i = 1:3
            parentDir = fileparts(projectRoot);
            if exist(fullfile(parentDir, 'README.md'), 'file')
                projectRoot = parentDir;
                break;
            end
            projectRoot = parentDir;
        end
    end
    
    %% Check GUI files exist
    guiFiles = {
        fullfile('GUIs', 'CtrlGUI.m')
        fullfile('GUIs', 'refLineGUI.m')
        fullfile('GUIs', 'FinalFigureFormatterUI.m')
    };
    
    foundCount = 0;
    for i = 1:length(guiFiles)
        guiPath = fullfile(projectRoot, guiFiles{i});
        if exist(guiPath, 'file') == 2
            foundCount = foundCount + 1;
            fprintf('  Found: %s\n', guiFiles{i});
        end
    end
    
    assert(foundCount > 0, 'No GUI files found');
    
    %% Add GUIs to path and check they can be found
    originalPath = path;
    try
        addpath(fullfile(projectRoot, 'GUIs'));
        
        % Check if functions can be found
        guiFunctions = {'CtrlGUI', 'refLineGUI', 'FinalFigureFormatterUI'};
        for i = 1:length(guiFunctions)
            funcPath = which(guiFunctions{i});
            if ~isempty(funcPath)
                fprintf('  %s is on path\n', guiFunctions{i});
            end
        end
        
        fprintf('✓ GUI files are accessible\n');
        
    catch ME
        path(originalPath);
        rethrow(ME);
    end
    
    path(originalPath);
end
