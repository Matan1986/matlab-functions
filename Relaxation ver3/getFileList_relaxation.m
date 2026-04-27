function [fileList, temps, fields, types, colors, mass, traceListing] = getFileList_relaxation(directory, color_scheme)
% getFileList_relaxation — Find relaxation .dat files and extract parameters (T, H, type, mass)
%
% R2C: Deterministic ordering — independent of raw dir() order:
%   1) Lexicographic sort of file names (case-sensitive strcmpi-style: use sort on char).
%   2) Sort by parsed temperature descending, NaN last.
%   3) Within equal temperature, ascending filename tie-break.
%   file_index = 1..N in final order.
%
% Outputs:
%   fileList — cell array of file names (deterministic order)
%   temps    — nominal temperatures (K) per file (same order)
%   fields   — nominal fields (Oe)
%   types    — 'TRM', 'IRM', or 'Unknown'
%   colors   — colormap
%   mass     — legacy scalar: NaN if filename-derived masses disagree or absent;
%              if all non-NaN filename masses agree within 1e-6 mg, that value.
%   traceListing — (optional, nargout>=7) struct with per-trace filename metadata:
%       .file_index, .file_name, .parsed_temperature_K, .parsed_field_Oe,
%       .trace_type, .mass_mg_filename, .raw_metadata_status, .source_directory

%% --- Auto detect TRM vs IRM mode from folder ---
dirLower = lower(directory);
autoCompare = contains(dirLower, "trm") && contains(dirLower, "irm");

files = dir(fullfile(directory, '*.dat'));
fileList = {files.name};
if isempty(fileList)
    error('No .dat files found in %s', directory);
end

%% R2C: stable lexicographic order (case-sensitive) before parsing
[~, lexOrd] = sort(fileList);
fileList = fileList(lexOrd);

n = numel(fileList);
temps  = nan(n,1);
fields = nan(n,1);
types  = strings(n,1);
massMgFilename = nan(n,1);
rawMetaStatus = strings(n,1);

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

    % ---- extract mass (per file, filename) ----
    Mmatch = regexp(name, '(\d+[pP]\d+|\d+\.\d+)\s*(?i)mg', 'match');
    if ~isempty(Mmatch)
        mStr = regexprep(Mmatch{1}, '(?i)mg', '');
        mStr = regexprep(mStr, '[pP]', '.');
        massMgFilename(i) = str2double(mStr);
    end

    % ---- raw_metadata_status (filename layer only) ----
    hasT = isfinite(temps(i));
    hasF = isfinite(fields(i));
    if hasT && hasF
        rawMetaStatus(i) = "FILENAME_PARSE_OK";
    elseif hasT && ~hasF
        rawMetaStatus(i) = "FILENAME_FIELD_MISSING";
    elseif ~hasT && hasF
        rawMetaStatus(i) = "FILENAME_TEMP_MISSING";
    else
        rawMetaStatus(i) = "FILENAME_PARSE_FAILED";
    end
end

%% R2C: temperature descending, NaN last; tie-break filename ascending
fnKey = string(fileList(:));
keyT = temps(:);
key1 = -keyT;
key1(~isfinite(keyT)) = inf; % NaN / Inf temps sort last on ascending key1
[~, ordFinal] = sortrows([key1, fnKey]);
fileList = fileList(ordFinal);
temps    = temps(ordFinal);
fields   = fields(ordFinal);
types    = types(ordFinal);
massMgFilename = massMgFilename(ordFinal);
rawMetaStatus = rawMetaStatus(ordFinal);

%% Legacy scalar mass (filename-derived only): single agreed value or NaN
finiteMass = massMgFilename(isfinite(massMgFilename));
if isempty(finiteMass)
    mass = NaN;
else
    ref = finiteMass(1);
    if all(abs(finiteMass - ref) < 1e-6)
        mass = ref;
    else
        mass = NaN;
    end
end

%% ---- Color logic ----
if autoCompare
    colors = lines(max(n,3));
else
    switch lower(color_scheme)
        case 'parula', colors = parula(max(n,3));
        case 'jet',    colors = jet(max(n,3));
        otherwise,     colors = lines(max(n,3));
    end
end

%% Trace listing for importFiles_relaxation / manifests (always assigned; 7th output)
traceListing = struct();
traceListing.file_index = (1:n)';
traceListing.file_name = fileList(:);
traceListing.parsed_temperature_K = temps;
traceListing.parsed_field_Oe = fields;
traceListing.trace_type = types;
traceListing.mass_mg_filename = massMgFilename;
traceListing.raw_metadata_status = rawMetaStatus;
traceListing.source_directory = repmat({char(directory)}, n, 1);

end
