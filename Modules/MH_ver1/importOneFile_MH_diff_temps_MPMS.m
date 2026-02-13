function [TimeSec, SampleTempKelvin, MomentEmu, MagneticFieldOe] = ...
         importOneFile_MH_diff_temps_MPMS(filename, DC)
    % Import MPMS .DAT file with dynamic header detection.
    %
    % Inputs:
    %   filename - full path to MPMS data file
    %   DC       - true -> use "DC Moment Free Ctr (emu)"
    %
    % Outputs:
    %   TimeSec, SampleTempKelvin, MomentEmu, MagneticFieldOe

    %% ============================
    %   Locate [Data] section
    % =============================
    fid = fopen(filename, 'r');
    if fid == -1
        error(['Could not open file: ', filename]);
    end

    line = '';
    lineNum = 0;
    dataFound = false;

    while ischar(line)
        line = fgetl(fid);
        lineNum = lineNum + 1;
        if contains(line, '[Data]')
            dataFound = true;
            break;
        end
    end

    if ~dataFound
        fclose(fid);
        error('[Data] section not found in file.');
    end

    % Header line is NEXT line
    headerLine = fgetl(fid);
    fclose(fid);

    if ~ischar(headerLine)
        error('Could not read header line.');
    end

    %% ============================
    %   Parse header into names
    % =============================
    rawNames = strsplit(headerLine, ',');
    columnNames = strtrim(rawNames);  % remove whitespace

    nCols = numel(columnNames);

    % Prepare import options
    opts = delimitedTextImportOptions("NumVariables", nCols);
    opts.VariableNamingRule = 'preserve';
    opts.Delimiter = ",";
    opts.VariableNames = columnNames;
    opts.VariableTypes = repmat("double", 1, nCols);
    opts.DataLines = [lineNum + 2, Inf];

    %% ============================
    %   Find required columns
    % =============================

    % Acceptable aliases
    timeCandidates = {
        'Time Stamp (sec)'
        'Time (s)'
        'TimeStamp'
        };

    tempCandidates = {
        'Temperature (K)'
        'Sample Temp (K)'
        'Temp (K)'
        };

    fieldCandidates = {
        'Magnetic Field (Oe)'
        'Field (Oe)'
        'H (Oe)'
        };

    momentCandidates_AC = {
        'Moment (emu)'
        'AC Moment (emu)'
        };

    momentCandidates_DC = {
        'DC Moment Free Ctr (emu)'
        'DC Moment (emu)'
        };

    timeIndex  = findMatchingColumn(columnNames, timeCandidates);
    tempIndex  = findMatchingColumn(columnNames, tempCandidates);
    fieldIndex = findMatchingColumn(columnNames, fieldCandidates);

    if DC
        momentIndex = findMatchingColumn(columnNames, momentCandidates_DC);
    else
        momentIndex = findMatchingColumn(columnNames, momentCandidates_AC);
    end

    if any([timeIndex, tempIndex, fieldIndex, momentIndex] == 0)
        disp(columnNames');
        error('One or more required columns could not be found.');
    end

    %% Select just the columns we need
    opts.SelectedVariableNames = columnNames([timeIndex, tempIndex, momentIndex, fieldIndex]);

    %% ============================
    %   Read table
    % =============================
    tbl = readtable(filename, opts);

    % Remove NaNs
    tbl = rmmissing(tbl);

    %% Extract outputs
    TimeSec           = tbl.(columnNames{timeIndex});
    SampleTempKelvin  = tbl.(columnNames{tempIndex});
    MomentEmu         = tbl.(columnNames{momentIndex});
    MagneticFieldOe   = tbl.(columnNames{fieldIndex});
end


%% =============================================================
% Helper: find first matching header name
% =============================================================
function idx = findMatchingColumn(columnNames, candidates)
    idx = 0;
    for k = 1:numel(candidates)
        hit = find(strcmp(columnNames, candidates{k}), 1);
        if ~isempty(hit)
            idx = hit;
            return;
        end
    end
end
