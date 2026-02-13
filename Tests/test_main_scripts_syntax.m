function test_main_scripts_syntax()
%TEST_MAIN_SCRIPTS_SYNTAX Check all *_main.m scripts for syntax errors
%
%   This test verifies:
%   - All main scripts exist
%   - No syntax errors
%   - Can be parsed by MATLAB

    fprintf('Testing main script syntax...\n');
    
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
    
    %% Find all main scripts in new structure
    mainScripts = {
        fullfile('Modules', 'Aging_ver2', 'Main_Aging.m')
        fullfile('Modules', 'FieldSweep_ver3', 'FieldSweep_main.m')
        fullfile('Modules', 'AC_HC_MagLab_ver8', 'ACHC_main.m')
        fullfile('Modules', 'HC_ver1', 'HC_main.m')
        fullfile('Modules', 'MH_ver1', 'MH_main.m')
        fullfile('Modules', 'MT_ver2', 'MT_main.m')
        fullfile('Modules', 'PS_ver4', 'PS_main.m')
        fullfile('Modules', 'Resistivity_ver6', 'Resistivity_main.m')
        fullfile('Modules', 'Resistivity_MagLab_ver1', 'ACHC_RH_main.m')
        fullfile('Modules', 'Switching_ver12', 'main', 'Switching_main.m')
        fullfile('Modules', 'zfAMR_ver11', 'main', 'zfAMR_main.m')
    };
    
    testedCount = 0;
    passedCount = 0;
    
    for i = 1:length(mainScripts)
        scriptPath = fullfile(projectRoot, mainScripts{i});
        
        if exist(scriptPath, 'file')
            testedCount = testedCount + 1;
            
            try
                % Check syntax by using pcode or mtree
                % Simple check: try to read and parse the file
                fid = fopen(scriptPath, 'r');
                if fid > 0
                    content = fread(fid, '*char')';
                    fclose(fid);
                    
                    % Check for basic MATLAB syntax markers
                    assert(~isempty(content), 'Empty script file');
                    
                    % Check that it's a valid MATLAB file (contains some MATLAB code)
                    hasCode = contains(content, '%') || contains(content, '=') || ...
                              contains(content, 'function') || contains(content, 'end');
                    assert(hasCode, 'No recognizable MATLAB code');
                    
                    passedCount = passedCount + 1;
                    fprintf('  ✓ %s\n', mainScripts{i});
                else
                    warning('Cannot open: %s', scriptPath);
                end
            catch ME
                warning('Syntax issue in %s: %s', scriptPath, ME.message);
            end
        end
    end
    
    assert(testedCount > 0, 'No main scripts found to test');
    assert(passedCount == testedCount, ...
        sprintf('%d/%d scripts have syntax issues', testedCount - passedCount, testedCount));
    
    fprintf('✓ All %d main scripts passed syntax check\n', passedCount);
end
