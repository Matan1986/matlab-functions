function [Time_table, Temp_table, Field_table, Moment_table, mass, loaderAudit] = ...
    importFiles_relaxation(directory, fileList, normalizeByMass, debugMode, varargin)
% importFiles_relaxation - Import MPMS/MPMS3 relaxation .dat files (R2C contract)
%
% Inputs:
%   directory        - folder containing .dat files
%   fileList         - list of filenames (deterministic order from getFileList_relaxation)
%   normalizeByMass  - true/false (divide by per-trace effective mass in mg)
%   debugMode        - true/false (print debug info)
%   varargin{1}      - optional opts struct:
%       .run_id              - char/string for deterministic trace_id (default 'no_run_id')
%       .n_min_points        - minimum samples after dedup (default 3)
%       .traceListing        - struct from getFileList_relaxation (7th output): per-file
%                             filename mass and raw_metadata_status
%
% Outputs:
%   Time_table, Temp_table, Field_table, Moment_table - cell arrays (empty [] on FAILED)
%   mass  - legacy scalar: if all successful traces share same mass_mg_effective within
%           1e-6 mg, that value; else NaN (per-trace masses are in loaderAudit.manifest)
%   loaderAudit - (nargout>=6) struct with tables:
%       .manifest - one row per file_index (identity + status + mass provenance)
%       .metrics  - per-trace raw audit metrics (timebase, signal stats)
%
% R2C: No silent continue — every file produces manifest + metrics rows.
% Fitting layer skips empty cells (existing fitAllRelaxations behavior).

if nargin < 5 || isempty(varargin)
    opts = struct();
else
    opts = varargin{1};
end
if isempty(opts), opts = struct(); end
if ~isfield(opts, 'run_id') || isempty(opts.run_id)
    opts.run_id = 'no_run_id';
end
if ~isfield(opts, 'n_min_points') || isempty(opts.n_min_points)
    opts.n_min_points = 3;
end

n = numel(fileList);
Time_table   = cell(n, 1);
Temp_table   = cell(n, 1);
Field_table  = cell(n, 1);
Moment_table = cell(n, 1);

manifest = table();
metrics  = table();

for i = 1:n
    [Time_table{i}, Temp_table{i}, Field_table{i}, Moment_table{i}, ...
        manRow, metRow] = relaxation_importOneTrace(directory, fileList{i}, i, ...
        normalizeByMass, debugMode, opts);

    if i == 1
        manifest = manRow;
        metrics  = metRow;
    else
        manifest = [manifest; manRow]; %#ok<AGROW>
        metrics  = [metrics; metRow]; %#ok<AGROW>
    end
end

% Legacy mass: agreement across LOADED traces only
okLoaded = strcmpi(string(manifest.loader_status), "LOADED");
eff = manifest.mass_mg_effective;
effOk = eff(okLoaded);
effFinite = effOk(isfinite(effOk));
if isempty(effFinite)
    mass = NaN;
else
    r0 = effFinite(1);
    if all(abs(effFinite - r0) < 1e-6)
        mass = r0;
    else
        mass = NaN;
    end
end

loaderAudit = struct('manifest', manifest, 'metrics', metrics);

end

%% ------------------------------------------------------------------------
function [tOut, TOut, HOut, MOut, manRow, metRow] = relaxation_importOneTrace( ...
    directory, fileName, fileIndex, normalizeByMass, debugMode, opts)

filePath = fullfile(directory, fileName);
runId = char(string(opts.run_id));
trace_id = relaxation_makeTraceId(runId, directory, fileName, fileIndex);

% Defaults (FAILED path)
tOut = []; TOut = []; HOut = []; MOut = [];
loader_status = 'FAILED';
failure_reason = 'OK';
nan_count_time = 0;
nan_count_signal = 0;
n_points = 0;
t_min = NaN; t_max = NaN; duration = NaN;
time_monotonic = false;
duplicate_time_count = 0;
nonpositive_dt_count = 0;
min_M = NaN; max_M = NaN; delta_M = NaN; std_M = NaN;
time_unit_policy = '';
time_unit_detected = '';
time_shifted_to_zero = false;
log_time_allowed = false;
normalize_by_mass_applied = false;
time_scale_branch = '';

mass_mg_header = NaN;
mass_mg_filename = NaN;
mass_mg_effective = NaN;
mass_provenance = 'NONE';

parsed_temperature_K = NaN;
parsed_field_Oe = NaN;
trace_type = "Unknown";
raw_metadata_status = 'FILENAME_PARSE_FAILED';
source_directory = char(directory);

if isfield(opts, 'traceListing') && ~isempty(opts.traceListing) && ...
        isfield(opts.traceListing, 'parsed_temperature_K') && ...
        numel(opts.traceListing.parsed_temperature_K) >= fileIndex
    parsed_temperature_K = opts.traceListing.parsed_temperature_K(fileIndex);
    parsed_field_Oe = opts.traceListing.parsed_field_Oe(fileIndex);
    trace_type = opts.traceListing.trace_type(fileIndex);
    raw_metadata_status = char(opts.traceListing.raw_metadata_status(fileIndex));
    if isfield(opts.traceListing, 'mass_mg_filename')
        mass_mg_filename = opts.traceListing.mass_mg_filename(fileIndex);
    end
else
    meta = relaxation_parseFilenameMeta(fileName);
    parsed_temperature_K = meta.temp_K;
    parsed_field_Oe = meta.field_Oe;
    trace_type = meta.trace_type;
    raw_metadata_status = meta.raw_metadata_status;
    mass_mg_filename = meta.mass_mg_filename;
end

% --- Header scan for sample mass ---
fid = fopen(filePath, 'r');
if fid < 0
    failure_reason = 'FAIL_METADATA_INCOMPLETE';
    [manRow, metRow] = relaxation_packRows(trace_id, filePath, fileName, fileIndex, ...
        parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
        loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
        mass_mg_effective, mass_provenance, normalizeByMass, ...
        nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
        time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
        min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
        time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch);
    return;
end
while true
    L = fgetl(fid);
    if ~ischar(L), break; end
    if contains(L, 'SAMPLE_MASS', 'IgnoreCase', true)
        p = split(L, ',');
        if numel(p) >= 2
            val = str2double(p{2});
            if ~isnan(val), mass_mg_header = val; end
        end
    end
    if contains(L, '[Data]'), break; end
end
fclose(fid);

% --- Read numeric table ---
try
    optsRead = detectImportOptions(filePath, 'Delimiter', ',', ...
        'VariableNamingRule', 'preserve');
    optsRead = setvartype(optsRead, 'double');
    tbl = readtable(filePath, optsRead);
catch
    failure_reason = 'FAIL_METADATA_INCOMPLETE';
    [manRow, metRow] = relaxation_packRows(trace_id, filePath, fileName, fileIndex, ...
        parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
        loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
        mass_mg_effective, mass_provenance, normalizeByMass, ...
        nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
        time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
        min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
        time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch);
    return;
end

normNames = relaxation_normalizeVarNames(tbl.Properties.VariableNames);

[iTime, eTime] = relaxation_pickColumn(normNames, 'time');
[iTemp, eTemp] = relaxation_pickColumn(normNames, 'temp');
[iField, eField] = relaxation_pickColumn(normNames, 'field');
[iMoment, eMoment] = relaxation_pickColumn(normNames, 'moment');

failure_reason = relaxation_aggregateColumnFailures(eTime, eMoment, eTemp, eField);
if isempty(iTime) || isempty(iTemp) || isempty(iField) || isempty(iMoment)
    if strcmp(failure_reason, 'OK')
        failure_reason = 'FAIL_METADATA_INCOMPLETE';
    end
end

if ~strcmp(failure_reason, 'OK')
    [manRow, metRow] = relaxation_packRows(trace_id, filePath, fileName, fileIndex, ...
        parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
        loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
        mass_mg_effective, mass_provenance, normalizeByMass, ...
        nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
        time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
        min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
        time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch);
    return;
end

tRaw = tbl{:, iTime};
Tcol = tbl{:, iTemp};
Hcol = tbl{:, iField};
Mcol = tbl{:, iMoment};

nan_count_time = sum(~isfinite(tRaw(:)));
nan_count_signal = sum(~isfinite(Mcol(:)));

ok = isfinite(tRaw) & isfinite(Tcol) & isfinite(Hcol) & isfinite(Mcol);
tRaw = tRaw(ok);
Tcol = Tcol(ok);
Hcol = Hcol(ok);
Mcol = Mcol(ok);

if isempty(tRaw)
    failure_reason = 'FAIL_NO_FINITE_ROWS';
    [manRow, metRow] = relaxation_packRows(trace_id, filePath, fileName, fileIndex, ...
        parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
        loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
        mass_mg_effective, mass_provenance, normalizeByMass, ...
        nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
        time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
        min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
        time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch);
    return;
end

[tRaw, ord] = sort(tRaw(:), 'ascend');
Tcol = Tcol(ord);
Hcol = Hcol(ord);
Mcol = Mcol(ord);

nBeforeDup = numel(tRaw);
[tRaw, iu] = unique(tRaw, 'stable');
Tcol = Tcol(iu);
Hcol = Hcol(iu);
Mcol = Mcol(iu);
duplicate_time_count = nBeforeDup - numel(tRaw);

if isempty(tRaw)
    failure_reason = 'FAIL_EMPTY_TIME';
    [manRow, metRow] = relaxation_packRows(trace_id, filePath, fileName, fileIndex, ...
        parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
        loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
        mass_mg_effective, mass_provenance, normalizeByMass, ...
        nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
        time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
        min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
        time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch);
    return;
end

if isempty(Mcol)
    failure_reason = 'FAIL_EMPTY_SIGNAL';
    [manRow, metRow] = relaxation_packRows(trace_id, filePath, fileName, fileIndex, ...
        parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
        loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
        mass_mg_effective, mass_provenance, normalizeByMass, ...
        nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
        time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
        min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
        time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch);
    return;
end

% --- Mass provenance (per trace) ---
epsMg = 1e-6;
hasH = isfinite(mass_mg_header);
hasF = isfinite(mass_mg_filename);
if hasH && hasF && abs(mass_mg_header - mass_mg_filename) > epsMg
    failure_reason = 'FAIL_METADATA_INCOMPLETE'; % mass header vs filename conflict
    [manRow, metRow] = relaxation_packRows(trace_id, filePath, fileName, fileIndex, ...
        parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
        loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
        mass_mg_effective, 'CONFLICT', normalizeByMass, ...
        nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
        time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
        min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
        time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch);
    return;
elseif hasH
    mass_mg_effective = mass_mg_header;
    mass_provenance = 'HEADER';
elseif hasF
    mass_mg_effective = mass_mg_filename;
    mass_provenance = 'FILENAME';
else
    mass_mg_effective = NaN;
    mass_provenance = 'NONE';
end

if normalizeByMass && ~isfinite(mass_mg_effective)
    failure_reason = 'FAIL_METADATA_INCOMPLETE';
    [manRow, metRow] = relaxation_packRows(trace_id, filePath, fileName, fileIndex, ...
        parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
        loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
        mass_mg_effective, mass_provenance, normalizeByMass, ...
        nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
        time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
        min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
        time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch);
    return;
end

% --- Timebase: raw features before origin shift ---
idx0 = find(isfinite(tRaw), 1, 'first');
t0 = tRaw(idx0);
dtRaw = median(diff(tRaw), 'omitnan');
meanRaw = mean(tRaw, 'omitnan');
time_unit_detected = sprintf('meanRaw=%.6g;median_dt=%.6g', meanRaw, dtRaw);

if meanRaw > 1e11 || dtRaw >= 1000
    t = (tRaw - t0) / 1000;
    time_scale_branch = 'TIME_SCALE_MS_EPOCH';
    time_unit_policy = 'divide_ms_to_s_after_t0';
else
    t = tRaw - t0;
    time_scale_branch = 'TIME_SCALE_S_EPOCH';
    time_unit_policy = 'subtract_t0_seconds';
end
time_shifted_to_zero = true;

if numel(t) < opts.n_min_points
    failure_reason = 'FAIL_INSUFFICIENT_POINTS';
    [manRow, metRow] = relaxation_packRows(trace_id, filePath, fileName, fileIndex, ...
        parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
        loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
        mass_mg_effective, mass_provenance, normalizeByMass, ...
        nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
        time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
        min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
        time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch);
    return;
end

M = Mcol(:);
if normalizeByMass && isfinite(mass_mg_effective)
    M = M ./ (mass_mg_effective * 1e-3);
    normalize_by_mass_applied = true;
end

n_points = numel(t);
t_min = min(t);
t_max = max(t);
duration = t_max - t_min;
if n_points >= 2
    dtv = diff(t);
    nonpositive_dt_count = sum(dtv <= 1e-12);
    time_monotonic = all(dtv > 1e-12);
else
    nonpositive_dt_count = 0;
    time_monotonic = true;
end

if nonpositive_dt_count > 0
    failure_reason = 'FAIL_TIMEBASE_INVALID';
    [manRow, metRow] = relaxation_packRows(trace_id, filePath, fileName, fileIndex, ...
        parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
        loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
        mass_mg_effective, mass_provenance, normalizeByMass, ...
        nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
        time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
        min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
        time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch);
    return;
end

min_M = min(M);
max_M = max(M);
delta_M = max_M - min_M;
if n_points >= 2
    std_M = std(M);
else
    std_M = NaN;
end

log_time_allowed = time_monotonic && (t_min > 0);

loader_status = 'LOADED';
failure_reason = 'OK';

tOut = t;
TOut = Tcol;
HOut = Hcol;
MOut = M;

if debugMode
    fprintf('File %2d: %-60s span = %.1f seconds [%s]\n', ...
        fileIndex, fileName, duration, time_scale_branch);
end

table_median_T_K = median(Tcol, 'omitnan');
table_median_H_Oe = median(Hcol, 'omitnan');

[manRow, metRow] = relaxation_packRowsFull(trace_id, filePath, fileName, fileIndex, ...
    parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
    loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
    mass_mg_effective, mass_provenance, normalizeByMass, ...
    nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
    time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
    min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
    time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch, ...
    table_median_T_K, table_median_H_Oe);

end

%% ------------------------------------------------------------------------
function fr = relaxation_aggregateColumnFailures(eTime, eMoment, eTemp, eField)
% Priority: time, moment, temp, field. Map non-user-listed temp/field errors to FAIL_METADATA_INCOMPLETE.
order = {eTime, eMoment, eTemp, eField};
for k = 1:numel(order)
    e = order{k};
    if isempty(e)
        continue;
    end
    if strcmp(e, 'FAIL_MISSING_TIME_COLUMN') || strcmp(e, 'FAIL_AMBIGUOUS_TIME_COLUMN') || ...
            strcmp(e, 'FAIL_MISSING_MOMENT_COLUMN') || strcmp(e, 'FAIL_AMBIGUOUS_MOMENT_COLUMN')
        fr = e;
        return;
    end
    fr = 'FAIL_METADATA_INCOMPLETE';
    return;
end
fr = 'OK';
end

%% ------------------------------------------------------------------------
function normNames = relaxation_normalizeVarNames(names)
n = numel(names);
normNames = strings(n, 1);
for k = 1:n
    s = string(names{k});
    s = lower(strtrim(s));
    s = regexprep(s, '\s+', ' ');
    normNames(k) = s;
end
end

function [idx, errTag] = relaxation_pickColumn(normNames, role)
idx = [];
errTag = '';
switch lower(char(role))
    case 'time'
        allow = ["time stamp (sec)", "time stamp", "timestamp", "sample timestamp", ...
            "elapsed time (s)", "elapsed time"];
        idxHits = find(ismember(normNames, allow));
        if numel(idxHits) > 1
            errTag = 'FAIL_AMBIGUOUS_TIME_COLUMN';
            return
        elseif numel(idxHits) == 1
            idx = idxHits;
            return
        end
        mask = (strlength(normNames) >= 8) & ...
            startsWith(normNames, "time", 'IgnoreCase', true) & ...
            contains(normNames, "stamp", 'IgnoreCase', true);
        idxHits = find(mask);
        if numel(idxHits) > 1
            errTag = 'FAIL_AMBIGUOUS_TIME_COLUMN';
        elseif numel(idxHits) == 1
            idx = idxHits;
        else
            errTag = 'FAIL_MISSING_TIME_COLUMN';
        end

    case 'temp'
        allow = ["sample temperature (k)", "sample temperature", "temperature (k)", ...
            "temperature", "sample temp (k)"];
        idxHits = find(ismember(normNames, allow));
        if numel(idxHits) > 1
            errTag = 'FAIL_AMBIGUOUS_TEMP_COLUMN';
        elseif numel(idxHits) == 1
            idx = idxHits;
        else
            mask = contains(normNames, "temperature", 'IgnoreCase', true) & ...
                contains(normNames, "(k)", 'IgnoreCase', true);
            idxHits = find(mask);
            if numel(idxHits) > 1
                errTag = 'FAIL_AMBIGUOUS_TEMP_COLUMN';
            elseif numel(idxHits) == 1
                idx = idxHits;
            else
                errTag = 'FAIL_MISSING_TEMP_COLUMN';
            end
        end

    case 'field'
        allow = ["magnetic field (oe)", "magnetic field", "magneticfield_oe"];
        idxHits = find(ismember(normNames, allow));
        if numel(idxHits) > 1
            errTag = 'FAIL_AMBIGUOUS_FIELD_COLUMN';
        elseif numel(idxHits) == 1
            idx = idxHits;
        else
            mask = contains(normNames, "magnetic", 'IgnoreCase', true) & ...
                (contains(normNames, "oe", 'IgnoreCase', true) | contains(normNames, "field", 'IgnoreCase', true));
            idxHits = find(mask);
            if numel(idxHits) > 1
                errTag = 'FAIL_AMBIGUOUS_FIELD_COLUMN';
            elseif numel(idxHits) == 1
                idx = idxHits;
            else
                errTag = 'FAIL_MISSING_FIELD_COLUMN';
            end
        end

    case 'moment'
        allow = ["moment (emu)", "moment_emu", "moment(emu)", "moment ( emu )"];
        idxHits = find(ismember(normNames, allow));
        if numel(idxHits) > 1
            errTag = 'FAIL_AMBIGUOUS_MOMENT_COLUMN';
        elseif numel(idxHits) == 1
            idx = idxHits;
        else
            mask = startsWith(normNames, "moment", 'IgnoreCase', true) & ...
                contains(normNames, "emu", 'IgnoreCase', true);
            idxHits = find(mask);
            if numel(idxHits) > 1
                errTag = 'FAIL_AMBIGUOUS_MOMENT_COLUMN';
            elseif numel(idxHits) == 1
                idx = idxHits;
            else
                errTag = 'FAIL_MISSING_MOMENT_COLUMN';
            end
        end
end
end

function tid = relaxation_makeTraceId(runId, directory, fileName, fileIndex)
payload = sprintf('%s|%s|%s|%d', runId, directory, fileName, fileIndex);
tid = ['r2c_' relaxation_shortHash(payload)];
end

function h = relaxation_shortHash(str)
try
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(uint8(char(str)));
    dg = typecast(md.digest, 'uint8');
    h = sprintf('%02x', dg(1:8));
catch
    s = double(char(str));
    h = sprintf('%08x', mod(sum(s .* (1:numel(s))), 2^32 - 1));
end
end

function meta = relaxation_parseFilenameMeta(name)
meta.temp_K = NaN;
meta.field_Oe = NaN;
meta.mass_mg_filename = NaN;
meta.trace_type = "Unknown";
meta.raw_metadata_status = 'FILENAME_PARSE_FAILED';

lname = lower(name);
if contains(lname, 'afterfc') || contains(lname, 'trm')
    meta.trace_type = "TRM";
elseif contains(lname, 'afterzfc') || contains(lname, 'irm')
    meta.trace_type = "IRM";
end

tempMatch = regexp(name, '[_-]?(\d+(\.\d+)?)\s*[kK]', 'tokens', 'once');
if ~isempty(tempMatch)
    meta.temp_K = str2double(tempMatch{1});
end
Fmatch = regexp(name, '(?<=FC)\d+(\.\d+)?[tT]', 'match');
if ~isempty(Fmatch)
    val = regexprep(Fmatch{1}, '(?i)t', '');
    meta.field_Oe = str2double(val) * 1e4;
end
Mmatch = regexp(name, '(\d+[pP]\d+|\d+\.\d+)\s*(?i)mg', 'match');
if ~isempty(Mmatch)
    mStr = regexprep(Mmatch{1}, '(?i)mg', '');
    mStr = regexprep(mStr, '[pP]', '.');
    meta.mass_mg_filename = str2double(mStr);
end

hasT = isfinite(meta.temp_K);
hasF = isfinite(meta.field_Oe);
if hasT && hasF
    meta.raw_metadata_status = 'FILENAME_PARSE_OK';
elseif hasT && ~hasF
    meta.raw_metadata_status = 'FILENAME_FIELD_MISSING';
elseif ~hasT && hasF
    meta.raw_metadata_status = 'FILENAME_TEMP_MISSING';
end
end

function [manRow, metRow] = relaxation_packRows(trace_id, filePath, fileName, fileIndex, ...
    parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
    loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
    mass_mg_effective, mass_provenance, normalizeByMass, ...
    nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
    time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
    min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
    time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch)

table_median_T_K = NaN;
table_median_H_Oe = NaN;
[manRow, metRow] = relaxation_packRowsFull(trace_id, filePath, fileName, fileIndex, ...
    parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
    loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
    mass_mg_effective, mass_provenance, normalizeByMass, ...
    nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
    time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
    min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
    time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch, ...
    table_median_T_K, table_median_H_Oe);
end

function [manRow, metRow] = relaxation_packRowsFull(trace_id, filePath, fileName, fileIndex, ...
    parsed_temperature_K, parsed_field_Oe, source_directory, raw_metadata_status, ...
    loader_status, failure_reason, trace_type, mass_mg_header, mass_mg_filename, ...
    mass_mg_effective, mass_provenance, normalizeByMass, ...
    nan_count_time, nan_count_signal, n_points, t_min, t_max, duration, ...
    time_monotonic, duplicate_time_count, nonpositive_dt_count, ...
    min_M, max_M, delta_M, std_M, time_unit_policy, time_unit_detected, ...
    time_shifted_to_zero, log_time_allowed, normalize_by_mass_applied, time_scale_branch, ...
    table_median_T_K, table_median_H_Oe)

manRow = table({trace_id}, {filePath}, {fileName}, fileIndex, parsed_temperature_K, ...
    parsed_field_Oe, {source_directory}, {raw_metadata_status}, {loader_status}, ...
    {failure_reason}, trace_type, mass_mg_header, mass_mg_filename, mass_mg_effective, ...
    {mass_provenance}, logical(normalizeByMass), ...
    'VariableNames', {'trace_id', 'file_path', 'file_name', 'file_index', ...
    'parsed_temperature_K', 'parsed_field_Oe', 'source_directory', 'raw_metadata_status', ...
    'loader_status', 'failure_reason', 'trace_type', 'mass_mg_header', 'mass_mg_filename', ...
    'mass_mg_effective', 'mass_provenance', 'normalize_by_mass_requested'});

metRow = table({trace_id}, fileIndex, n_points, t_min, t_max, duration, logical(time_monotonic), ...
    duplicate_time_count, nonpositive_dt_count, min_M, max_M, delta_M, std_M, ...
    nan_count_time, nan_count_signal, {loader_status}, {failure_reason}, ...
    logical(normalize_by_mass_applied), {time_scale_branch}, {time_unit_policy}, ...
    {time_unit_detected}, logical(time_shifted_to_zero), logical(log_time_allowed), ...
    table_median_T_K, table_median_H_Oe, ...
    'VariableNames', {'trace_id', 'file_index', 'n_points', 't_min', 't_max', 'duration', ...
    'time_monotonic', 'duplicate_time_count', 'nonpositive_dt_count', 'min_M', 'max_M', ...
    'delta_M', 'std_M', 'nan_count_time', 'nan_count_signal', 'loader_status', ...
    'failure_reason', 'normalize_by_mass_applied', 'time_scale_branch', 'time_unit_policy', ...
    'time_unit_detected', 'time_shifted_to_zero', 'log_time_allowed', ...
    'table_median_T_K', 'table_median_H_Oe'});
end
