function [Time_table, Temp_table, Field_table, Moment_table, mass] = ...
    importFiles_relaxation(directory, fileList, normalizeByMass, debugMode)
% importFiles_relaxation — Import MPMS/MPMS3 relaxation .dat files
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
    t = tbl{:, iTime};
    T = tbl{:, iTemp};
    H = tbl{:, iField};
    M = tbl{:, iMoment};

    % --- Fix and scale time ---
    t = t - t(1);
    dt = median(diff(t), 'omitnan');
    total = max(t) - min(t);

    if mean(t) > 1e6
        t = t - t(1);          % epoch seconds
        total = max(t) - min(t);
    elseif dt > 1e3
        t = t / 1000;          % convert ms → s
        total = max(t) - min(t);
    end

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
