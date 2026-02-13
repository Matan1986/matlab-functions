function [fileList, temps, fields, types, colors, mass] = getFileList_relaxation(directory, color_scheme)
% getFileList_relaxation — Find relaxation .dat files and extract parameters (T, H, type, mass)
%
% Outputs:
%   fileList — cell array of file names
%   temps    — nominal temperatures (K)
%   fields   — nominal fields (Oe)
%   types    — 'TRM', 'IRM', or 'Unknown'
%   colors   — colormap
%   mass     — sample mass (mg, from filename if available)

%% --- Auto detect TRM vs IRM mode from folder ---
dirLower = lower(directory);
autoCompare = contains(dirLower, "trm") && contains(dirLower, "irm");

files = dir(fullfile(directory, '*.dat'));
fileList = {files.name};
if isempty(fileList)
    error('No .dat files found in %s', directory);
end

n = numel(fileList);
temps  = nan(n,1);
fields = nan(n,1);
types  = strings(n,1);
mass   = NaN;

for i = 1:n
    name = fileList{i};

    % ---- detect type (TRM / IRM) ----
    lname = lower(name);
    if contains(lname, 'afterfc') || contains(lname, 'trm')
        types(i) = "TRM";
    elseif contains(lname, 'afterzfc') || contains(lname, 'irm')
        types(i) = "IRM";
    else
        types(i) = "Unknown";
    end

    % ---- extract temperature ----
    tempMatch = regexp(name, '[_-]?(\d+(\.\d+)?)\s*[kK]', 'tokens', 'once');
    if ~isempty(tempMatch)
        temps(i) = str2double(tempMatch{1});
    else
        temps(i) = NaN;
    end

    % ---- extract field ----
    Fmatch = regexp(name, '(?<=FC)\d+(\.\d+)?[tT]', 'match');
    if ~isempty(Fmatch)
        val = regexprep(Fmatch{1}, '(?i)t', '');
        fields(i) = str2double(val) * 1e4; % Tesla → Oe
    else
        fields(i) = NaN;
    end

    % ---- extract mass ----
    Mmatch = regexp(name, '(\d+[pP]\d+|\d+\.\d+)\s*(?i)mg', 'match');
    if ~isempty(Mmatch)
        mStr = regexprep(Mmatch{1}, '(?i)mg', '');
        mStr = regexprep(mStr, '[pP]', '.');
        mass = str2double(mStr);
    end
end

%% ---- Sort by temperature ----
[temps, idx] = sort(temps, 'descend');
fileList = fileList(idx);
fields   = fields(idx);
types    = types(idx);

%% ---- Color logic ----
if autoCompare
    % Force MATLAB default colors (TRM = color 1, IRM = color 2)
    colors = lines(max(n,3));
else
    switch lower(color_scheme)
        case 'parula', colors = parula(max(n,3));
        case 'jet',    colors = jet(max(n,3));
        otherwise,     colors = lines(max(n,3));
    end
end

end
