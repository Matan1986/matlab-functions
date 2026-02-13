function flip_L1X_in_folder(folderPath, overwrite)
% flip_L1X_in_folder
% Goes over all data files in a folder, finds the column corresponding to
% 'LI1_X (V)' (robust name matching), multiplies it by -1, and saves fixed files.
%
% folderPath : string/char, folder to scan
% overwrite  : true  -> overwrite original files
%              false -> save as *_fixed.ext (default)

if nargin < 2 || isempty(overwrite)
    overwrite = false;
end

assert(isfolder(folderPath), 'Folder does not exist: %s', folderPath);

% ---- file types to scan ----
extList = ["*.dat","*.DAT","*.txt","*.TXT","*.csv","*.CSV"];

files = [];
for e = extList
    files = [files; dir(fullfile(folderPath, e))]; %#ok<AGROW>
end

if isempty(files)
    warning('No data files found in folder: %s', folderPath);
    return;
end

fprintf('Found %d files\n', numel(files));

for k = 1:numel(files)

    filePath = fullfile(files(k).folder, files(k).name);

    % ---- read first line (header) ----
    fid = fopen(filePath,'r');
    if fid < 0
        warning('Could not open %s', files(k).name);
        continue;
    end

    headerLine = fgetl(fid);
    fclose(fid);

    if ~ischar(headerLine) || isempty(strtrim(headerLine))
        warning('Empty or invalid header in: %s', files(k).name);
        continue;
    end

    % ---- detect delimiter (tab preferred if exists) ----
    if contains(headerLine, sprintf('\t'))
        delim = '\t';
    else
        delim = ' ';
    end

    headers = strsplit(strtrim(headerLine), delim);
    headers = headers(~cellfun('isempty', headers));

    % ---- robust header matching ----
    normHeaders = cellfun(@normalizeHeaderToken, headers, 'UniformOutput', false);

    % target normalized tokens that should match your "LI1_X (V)"
    targets = ["li1_x","l1x"];  % keep both just in case
    idx = [];

    for t = 1:numel(targets)
        ii = find(strcmpi(normHeaders, targets(t)), 1);
        if ~isempty(ii)
            idx = ii;
            break;
        end
    end

    if isempty(idx)
        fprintf('Skipping %-35s (no LI1_X/L1X)\n', files(k).name);
        continue;
    end

    % ---- read numeric data ----
    data = readmatrix(filePath, 'FileType','text', ...
        'Delimiter', delim, 'NumHeaderLines', 1);

    if isempty(data) || size(data,2) < idx
        warning('Column mismatch / empty data in %s', files(k).name);
        continue;
    end

    % ---- flip sign ----
    data(:,idx) = -data(:,idx);

    % ---- output filename ----
    if overwrite
        outFile = filePath;
    else
        [p,n,e] = fileparts(filePath);
        outFile = fullfile(p, n + "_fixed" + e);
    end

    % ---- write: header + numeric body safely ----
    fid = fopen(outFile,'w');
    if fid < 0
        warning('Could not write %s', outFile);
        continue;
    end

    % write header exactly as tokens
    fprintf(fid, '%s\n', strjoin(headers, delim));
    fclose(fid);

    % append numeric matrix (no headers)
    writematrix(data, outFile, ...
        'FileType','text', ...
        'Delimiter', delim, ...
        'WriteMode','append');

    fprintf('✔ Fixed %-35s → %s\n', files(k).name, outFile);
end

fprintf('Done.\n');

end


% =====================================================================
function s = normalizeHeaderToken(h)
% normalizeHeaderToken
% Example: 'LI1_X (V)' -> 'li1_x'
% Removes parentheses, lowercases, and normalizes separators.

h = string(h);

% remove parentheses and contents: (V), (Ohm), etc.
h = regexprep(h, '\(.*?\)', '');

% lowercase + trim
h = lower(strtrim(h));

% replace any run of non [a-z0-9_] with underscore
h = regexprep(h, '[^a-z0-9_]+', '_');

% remove leading/trailing underscores
h = regexprep(h, '^_+|_+$', '');

% collapse multiple underscores
h = regexprep(h, '_+', '_');

s = char(h);
end
