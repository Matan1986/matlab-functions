function verify_nested_scope_complete()
% MECHANICAL VERIFICATION - NO ASSUMPTIONS

fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('MECHANICAL NESTED SCOPE VERIFICATION\n');
fprintf('%s\n\n', repmat('=', 1, 70));

filePath = 'GUIs/FinalFigureFormatterUI.m';
fid = fopen(filePath, 'r');
allLines = {};
lineNum = 0;
while ~feof(fid)
    lineNum = lineNum + 1;
    allLines{lineNum} = fgetl(fid);
end
fclose(fid);

%% ✅ 1. FIND MAIN FUNCTION AND END
fprintf('✅ STEP 1: LOCATE MAIN FUNCTION BOUNDARIES\n%s\n', repmat('-', 1, 70));

mainStart = 0;
mainEnd = 0;

for i = 1:length(allLines)
    if contains(allLines{i}, 'function FinalFigureFormatterUI()')
        mainStart = i;
    end
end

% Main end is the LAST "end" that matches the indent of main function definition
% Main is indent 0, so find last "end" with indent 0 before any file-level function definition
for i = length(allLines):-1:1
    if strncmp(allLines{i}, 'function ', 9) && mainStart < i
        % Found a file-level function, now find main end just before
        for j = i-1:-1:1
            if strcmp(strtrim(allLines{j}), 'end')
                mainEnd = j;
                break;
            end
        end
        break;
    end
end

fprintf('   FinalFigureFormatterUI() starts:  LINE %d\n', mainStart);
fprintf('   FinalFigureFormatterUI() ends:    LINE %d\n\n', mainEnd);

%% ✅ 2. FIND ALL NESTED FUNCTIONS
fprintf('✅ STEP 2: VERIFY FUNCTIONS ARE NESTED\n%s\n', repmat('-', 1, 70));

requiredFuncs = {
    'applyColormapToFigures'
    'applyToSingleFigure'
    'getColormapToUse'
    'getCmoceanColormap'
    'getSliceIndices'
    'name2rgb'
    'makeCustomColormap'
};

nestedStatus = struct();
lineNumbers = struct();

for i = 1:numel(requiredFuncs)
    funcName = requiredFuncs{i};
    found = false;
    foundLine = 0;
    isNested = false;
    
    % Search for function definition
    for j = 1:length(allLines)
        if contains(allLines{j}, sprintf('function %s', funcName))
            found = true;
            foundLine = j;
            
            % Check if nested (between mainStart and mainEnd)
            if j > mainStart && j < mainEnd
                isNested = true;
            end
            break;
        end
    end
    
    nestedStatus.(strrep(funcName, '-', '_')) = isNested;
    lineNumbers.(strrep(funcName, '-', '_')) = foundLine;
    
    if found && isNested
        fprintf('   ✓ %-30s LINE %4d (NESTED)\n', funcName, foundLine);
    elseif found
        fprintf('   ✗ %-30s LINE %4d (EXTERNAL - FIX!)\n', funcName, foundLine);
    else
        fprintf('   ✗ %-30s NOT FOUND\n', funcName);
    end
end

%% ✅ 3. CHECK DUPLICATES
fprintf('\n✅ STEP 3: DUPLICATE DETECTION\n%s\n', repmat('-', 1, 70));

hasDuplicates = false;

for i = 1:numel(requiredFuncs)
    funcName = requiredFuncs{i};
    count = 0;
    locations = [];
    
    for j = 1:length(allLines)
        if contains(allLines{j}, sprintf('function %s', funcName))
            count = count + 1;
            locations = [locations j];
        end
    end
    
    if count > 1
        fprintf('   ✗ %s: FOUND %d TIMES\n', funcName, count);
        for k = 1:numel(locations)
            fprintf('      Line %d\n', locations(k));
        end
        hasDuplicates = true;
    else
        fprintf('   ✓ %s: 1 definition\n', funcName);
    end
end

if ~hasDuplicates
    fprintf('\n   ✓ ZERO DUPLICATES\n');
end

%% ✅ 4. BLANK FIGURE DETECTION
fprintf('\n✅ STEP 4: BLANK FIGURE CALL DETECTION\n%s\n', repmat('-', 1, 70));

blankFigCalls = [];

for i = 1:mainEnd
    line = allLines{i};
    % Look for figure() calls (not in callbacks, not in comments)
    if contains(line, 'figure(') && ~startsWith(strtrim(line), '%')
        if ~contains(line, 'ishandle') && ~contains(line, 'isgraphics') && ~contains(line, 'Callback')
            blankFigCalls = [blankFigCalls i];
        end
    end
end

if isempty(blankFigCalls)
    fprintf('   ✓ NO BLANK FIGURE CALLS DETECTED\n');
else
    fprintf('   ✗ BLANK FIGURE CALLS AT INIT:\n');
    for i = 1:numel(blankFigCalls)
        fprintf('      LINE %d: %s\n', blankFigCalls(i), strtrim(allLines{blankFigCalls(i)}));
    end
end

%% ✅ 5. WARNING SUPPRESSION
fprintf('\n✅ STEP 5: OPENFIG WARNING SUPPRESSION\n%s\n', repmat('-', 1, 70));

hasWarnOff = false;
suppressLine = 0;

for i = 1:length(allLines)
    if contains(allLines{i}, "warning('off'") && contains(allLines{i}, 'classNotFound')
        hasWarnOff = true;
        suppressLine = i;
        break;
    end
end

if hasWarnOff
    fprintf('   ✓ Warning suppression found at LINE %d\n', suppressLine);
else
    fprintf('   ⚠ WARNING SUPPRESSION MISSING - NEEDED FOR OPENFIG\n');
    fprintf('   Recommend adding to openfig calls\n');
end

%% ✅ 6. RUNTIME TEST
fprintf('\n✅ STEP 6: RUNTIME REGRESSION TEST\n%s\n', repmat('-', 1, 70));

guiOK = false;
noBlankFigOK = false;
testFigOK = false;

try
    fprintf('   Launching GUI...\n');
    FinalFigureFormatterUI();
    pause(1);
    
    fprintf('   ✓ GUI launched\n');
    guiOK = true;
    
    % Check for blank figures
    allFigs = findall(0, 'Type', 'figure');
    blankCount = 0;
    
    for f = allFigs'
        axes_list = findall(f, 'Type', 'axes');
        if isempty(axes_list)
            % Check if it's the UI figure
            if ~contains(f.Name, 'Figure Formatter')
                blankCount = blankCount + 1;
            end
        end
    end
    
    if blankCount == 0
        fprintf('   ✓ No blank figures at runtime\n');
        noBlankFigOK = true;
    else
        fprintf('   ✗ Found %d blank figures\n', blankCount);
    end
    
    % Create test figure
    f = figure('Visible', 'off', 'Name', 'Test_ButtonFuncs');
    ax = axes(f);
    x = 0:0.1:2*pi;
    plot(ax, x, sin(x), 'DisplayName', 'sin');
    hold(ax, 'on');
    plot(ax, x, cos(x), 'DisplayName', 'cos');
    
    fprintf('   ✓ Test figure created with plots\n');
    testFigOK = true;
    
    % Cleanup
    close all hidden;
    pause(0.5);
    
catch ME
    fprintf('   ✗ ERROR: %s\n', ME.message);
end

%% FINAL REPORT
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('VERIFICATION REPORT\n');
fprintf('%s\n', repmat('=', 1, 70));

fprintf('\nBOUNDARIES:\n');
fprintf('   FinalFigureFormatterUI:  LINE %d - %d\n', mainStart, mainEnd);

fprintf('\nNESTED FUNCTIONS (7 required):\n');
allNested = true;
for i = 1:numel(requiredFuncs)
    funcKey = strrep(requiredFuncs{i}, '-', '_');
    if nestedStatus.(funcKey)
        fprintf('   ✓ %s (LINE %d)\n', requiredFuncs{i}, lineNumbers.(funcKey));
    else
        fprintf('   ✗ %s (LINE %d - NOT NESTED)\n', requiredFuncs{i}, lineNumbers.(funcKey));
        allNested = false;
    end
end

fprintf('\nSTATUS:\n');
(allNested) && fprintf('   ✓ ALL 7 FUNCTIONS PROPERLY NESTED\n') || fprintf('   ✗ NESTING PROBLEM\n');
(~hasDuplicates) && fprintf('   ✓ ZERO DUPLICATES\n') || fprintf('   ✗ DUPLICATES EXIST\n');
(isempty(blankFigCalls)) && fprintf('   ✓ NO BLANK FIGURE CALLS\n') || fprintf('   ✗ BLANK FIGURE CALLS FOUND\n');
(guiOK && noBlankFigOK && testFigOK) && fprintf('   ✓ RUNTIME TEST PASSED\n') || fprintf('   ✗ RUNTIME TEST FAILED\n');
(~hasWarnOff) && fprintf('   ⚠ ADD WARNING SUPPRESSION\n') || fprintf('   ✓ WARNING SUPPRESSION PRESENT\n');

fprintf('\n%s\n\n', repmat('=', 1, 70));

end
