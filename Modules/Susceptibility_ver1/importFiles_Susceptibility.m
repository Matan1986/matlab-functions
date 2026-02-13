function [Temp_table, chiP_table, chiPP_table, freq_table, mass] = ...
         importFiles_Susceptibility(directory, fileList, normalizeByMass)
% importFiles_Susceptibility — Import MPMS3 AC susceptibility data
% Handles both single- and multi-frequency .dat files
%
% Inputs:
%   directory        - Folder containing .dat files
%   fileList         - Cell array of filenames
%   normalizeByMass  - true: convert to emu/Oe/g using sample mass
%
% Outputs:
%   Temp_table  - {k} Temperature (K)
%   chiP_table  - {k} χ′ (emu/Oe or emu/Oe/g)
%   chiPP_table - {k} χ″ (emu/Oe or emu/Oe/g)
%   freq_table  - {k} frequency values (Hz)
%   mass        - sample mass (mg)

Temp_table = {};
chiP_table = {};
chiPP_table = {};
freq_table = {};
mass = NaN;

for iFile = 1:length(fileList)
    filePath = fullfile(directory, fileList{iFile});
    fid = fopen(filePath, 'r');
    if fid == -1
        error('Cannot open %s', filePath);
    end

    % --- Read header until [Data] ---
    while true
        line = fgetl(fid);
        if ~ischar(line), break; end
        if contains(line, 'SAMPLE_MASS', 'IgnoreCase', true)
            parts = split(line, ',');
            if numel(parts) >= 2
                val = str2double(parts{2});
                if ~isnan(val), mass = val; end
            end
        end
        if contains(line, '[Data]')
            break
        end
    end

    % --- Read the header line after [Data] ---
    headerLine = fgetl(fid);
    fclose(fid);
    headers = strsplit(headerLine, ',');

    % --- Dynamically find column indices ---
    idxT     = find(strcmpi(strtrim(headers), 'Temperature (K)'), 1);
    idxChiP  = find(strcmpi(strtrim(headers), "AC X' (emu/Oe)"), 1);
    idxChiPP = find(strcmpi(strtrim(headers), "AC X'' (emu/Oe)"), 1);
    idxFreq  = find(strcmpi(strtrim(headers), 'AC Frequency (Hz)'), 1);

    if any(isempty([idxT, idxChiP, idxChiPP, idxFreq]))
        error('One or more required columns missing in %s', fileList{iFile});
    end

    % --- Define import options dynamically for all columns ---
    opts = delimitedTextImportOptions('NumVariables', numel(headers));
    opts.VariableNamingRule = 'preserve';
    opts.Delimiter = ',';
    opts.DataLines = [find(contains(headers,'Temperature'),1)+2, Inf];
    opts.VariableNames = headers;
    opts.VariableTypes = repmat("double", 1, numel(headers));
    opts.SelectedVariableNames = headers([idxT, idxChiP, idxChiPP, idxFreq]);

    % --- Import the table ---
    tbl = readtable(filePath, opts);

    temp = tbl{:,1};
    chiP = tbl{:,2};
    chiPP = tbl{:,3};
    freq = tbl{:,4};

    % --- Normalize if needed ---
    if normalizeByMass && ~isnan(mass)
        chiP = chiP ./ (mass * 1e-3);
        chiPP = chiPP ./ (mass * 1e-3);
    end

    % --- Handle multiple frequencies ---
    uniqueFreqs = unique(round(freq,6)); % tolerance for float errors
    for f = 1:numel(uniqueFreqs)
        sel = abs(freq - uniqueFreqs(f)) < 1e-6;
        if sum(sel) < 5
            continue; % skip short/noisy fragments
        end
        Temp_table{end+1} = temp(sel);
        chiP_table{end+1} = chiP(sel);
        chiPP_table{end+1} = chiPP(sel);
        freq_table{end+1} = repmat(uniqueFreqs(f), sum(sel), 1);
    end
end
end
