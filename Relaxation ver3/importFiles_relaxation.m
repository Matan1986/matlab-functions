function [Time_table, Temp_table, Field_table, Moment_table, mass] = ...
    importFiles_relaxation(directory, fileList, normalizeByMass, debugMode)
% importFiles_relaxation - Import MPMS/MPMS3 relaxation .dat files
%
% Inputs:
%   directory        - folder containing .dat files
%   fileList         - list of filenames
%   normalizeByMass  - true/false (divide by mass)
%   debugMode        - true/false (print debug info)
%
% Outputs:
%   Time_table, Temp_table, Field_table, Moment_table - cell arrays
%   mass           - sample mass (mg) from header (if available)

Time_table  = cell(length(fileList), 1);
Temp_table  = cell(length(fileList), 1);
Field_table = cell(length(fileList), 1);
Moment_table= cell(length(fileList), 1);
mass = NaN;

for i = 1:length(fileList)
    filePath = fullfile(directory, fileList{i});

    % --- Header scan for sample mass ---
    fid = fopen(filePath, 'r');
    if fid < 0, error('Cannot open %s', filePath); end
    while true
        L = fgetl(fid);
        if ~ischar(L), break; end
        if contains(L,'SAMPLE_MASS','IgnoreCase',true)
            p = split(L,',');
            if numel(p)>=2
                val = str2double(p{2});
                if ~isnan(val), mass = val; end
            end
        end
        if contains(L,'[Data]'), break; end
    end
    fclose(fid);

    % --- Read numeric table ---
    opts = detectImportOptions(filePath,'Delimiter',',',...
        'VariableNamingRule','preserve');
    opts = setvartype(opts,'double');
    tbl  = readtable(filePath,opts);

    % --- Match columns (support both MPMS and MPMS3 names) ---
    names = lower(string(tbl.Properties.VariableNames));
    iTime   = find(contains(names, {'timestamp','time stamp'}), 1);
    iTemp = find(contains(names, {'sample_temperature','sample temperature (k)'}), 1);
    if isempty(iTemp)
        iTemp = find(contains(names, {'temperature (k)'}), 1);
    end
    iField  = find(contains(names, {'magneticfield_oe','magnetic field'}), 1);
    iMoment = find(contains(names, {'moment_emu','moment (emu)'}), 1);

    if any(isempty([iTime, iTemp, iField, iMoment]))
        if debugMode
            fprintf(2,'\n[DEBUG] Columns detected for %s:\n', fileList{i});
            disp(tbl.Properties.VariableNames(1:min(10,numel(tbl.Properties.VariableNames))));
        end
        error('Could not find required columns in %s', fileList{i});
    end

        % --- Extract numeric vectors ---
    tRaw = tbl{:, iTime};
    T = tbl{:, iTemp};
    H = tbl{:, iField};
    M = tbl{:, iMoment};

    % --- Keep only finite rows and sort by time ---
    ok = isfinite(tRaw) & isfinite(T) & isfinite(H) & isfinite(M);
    tRaw = tRaw(ok);
    T = T(ok);
    H = H(ok);
    M = M(ok);
    if isempty(tRaw)
        if debugMode
            warning('importFiles_relaxation:NoFiniteRows', ...
                'No finite data rows in %s', fileList{i});
        end
        continue;
    end

    [tRaw, ord] = sort(tRaw, 'ascend');
    T = T(ord);
    H = H(ord);
    M = M(ord);

    % Remove duplicate timestamps to keep derivatives stable downstream.
    [tRaw, iu] = unique(tRaw, 'stable');
    T = T(iu);
    H = H(iu);
    M = M(iu);

    % --- Fix and scale time ---
    idx0 = find(isfinite(tRaw), 1, 'first');
    t0 = tRaw(idx0);
    dtRaw = median(diff(tRaw), 'omitnan');
    meanRaw = mean(tRaw, 'omitnan');

    if meanRaw > 1e11 || dtRaw >= 1000
        t = (tRaw - t0) / 1000;   % epoch-ms or relative-ms -> seconds
    else
        t = tRaw - t0;            % epoch-seconds or already-seconds
    end
    total = max(t) - min(t);

    % --- Normalize by mass (emu/g) ---
    if normalizeByMass && ~isnan(mass)
        M = M ./ (mass * 1e-3);
    end

    % --- Store ---
    Time_table{i}  = t;
    Temp_table{i}  = T;
    Field_table{i} = H;
    Moment_table{i}= M;

    if debugMode
        fprintf('File %2d: %-60s span = %.1f seconds\n', ...
            i, fileList{i}, total);
    end
end
end
