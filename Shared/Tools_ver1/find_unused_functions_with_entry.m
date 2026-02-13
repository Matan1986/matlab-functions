function report = find_unused_functions_with_entry(rootFolder, entryPoints)
% FIND_UNUSED_FUNCTIONS_WITH_ENTRY
% Detects unused functions, excluding:
%   • scripts (no function keyword)
%   • known entry points (manual tools)
%   • functions used by any other file
%
% SAFE for your project.

if nargin < 1
    rootFolder = pwd;
end
if nargin < 2
    entryPoints = {};
end

files = dir(fullfile(rootFolder, '**', '*.m'));
N = numel(files);

filePaths = strings(N,1);
baseNames = strings(N,1);
isScript = false(N,1);

for i = 1:N
    filePaths(i) = fullfile(files(i).folder, files(i).name);
    [~, baseNames(i)] = fileparts(files(i).name);

    txt = fileread(filePaths(i));
    isScript(i) = isempty(regexp(txt,'^\s*function','once'));
end

% Mark entry points
used = containers.Map(baseNames, false(size(baseNames)));
for k = 1:numel(entryPoints)
    if isKey(used, entryPoints{k})
        used(entryPoints{k}) = true;
    end
end

% Search usage
for i = 1:N
    txt = eraseComments(fileread(filePaths(i)));

    for j = 1:N
        name = baseNames(j);

        if contains(txt, "function " + name)
            continue
        end

        pattern = sprintf('\\<%s\\s*\\(', name);
        if ~isempty(regexp(txt, pattern, 'once'))
            used(name) = true;
        end
    end
end

unused = {};
for j = 1:N
    if used(baseNames(j)) == false && isScript(j) == false
        unused{end+1} = filePaths(j); %#ok<AGROW>
    end
end

report.unused = unused;
report.scripts = filePaths(isScript);

fprintf('\n===== UNUSED FUNCTIONS (%d found) =====\n', numel(unused));
for k = 1:numel(unused)
    fprintf('%s\n', unused{k});
end

end


function out = eraseComments(txt)
    lines = splitlines(txt);
    for k = 1:numel(lines)
        L = strip(lines{k});
        if startsWith(L,'%')
            lines{k} = '';
        elseif contains(L,'%')
            parts = split(L, '%');
            lines{k} = parts{1};
        end
    end
    out = strjoin(lines, newline);
end
