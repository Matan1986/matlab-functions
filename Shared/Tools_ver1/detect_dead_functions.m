function detect_dead_functions(folder)
% DETECT_DEAD_FUNCTIONS – scans a folder tree for unused .m functions
% Safe: does not move/delete anything.
%
% Usage:
%    detect_dead_functions('C:\...\Switching ver7');

if nargin < 1
    error('Provide folder path.');
end

folder = char(folder);

% === 1. Collect all .m files ===
files = dir(fullfile(folder, '**', '*.m'));
funcNames = string([]);

for k = 1:numel(files)
    name = files(k).name;
    if endsWith(name, ".m")
        funcNames(end+1) = erase(name, ".m");
    end
end

fprintf("\n=== Found %d functions in %s ===\n", numel(funcNames), folder);

% === 2. Read all text content into one big string ===
allText = "";
for k = 1:numel(files)
    txt = fileread(fullfile(files(k).folder, files(k).name));
    allText = allText + newline + txt;
end

% === 3. Detect calls ===
called = false(size(funcNames));

for k = 1:numel(funcNames)
    fn = funcNames(k);
    % Regular expression: word boundary + function name + "("
    p = regexp(allText, ['\<' + fn + '\s*\('], 'once');
    if ~isempty(p)
        called(k) = true;
    end
end

% === 4. Report ===
unused = funcNames(~called);
used   = funcNames(called);

fprintf("\n=== USED functions (called somewhere) ===\n");
disp(used.')

fprintf("\n=== UNUSED functions (never called inside folder) ===\n");
disp(unused.')

fprintf("\nNOTE: functions may still be used by code OUTSIDE this folder.\n");
fprintf("      This scan is safe and does NOT delete/move anything.\n");
end
