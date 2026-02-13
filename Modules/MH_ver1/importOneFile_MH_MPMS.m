function [TimeSec, SampleTempKelvin, MomentEmu, MagneticFieldOe] = importOneFile_MH_MPMS(filename, DC)
    % Import data from an MPMS .DAT file, dynamically detecting column indices.
    %
    % Inputs:
    %   filename - Path to the file
    %   DC - Boolean flag for selecting "DC Moment Free Ctr (emu)" when true
    %
    % Outputs:
    %   TimeSec - Column vector of time stamps in seconds
    %   SampleTempKelvin - Column vector of temperatures in Kelvin
    %   MomentEmu - Column vector of magnetic moments in emu
    %   MagneticFieldOe - Column vector of magnetic fields in Oe

    %% ==========================================================
    %  Locate [Data] section
    %% ==========================================================
    fid = fopen(filename, 'r');
    if fid == -1
        error(['Could not open file: ', filename]);
    end

    line = '';
    lineNum = 0;
    dataFound = false;

    % Find [Data]
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
        error('[Data] section not found in the file.');
    end

    % Header line = next line
    headerLine = fgetl(fid);
    fclose(fid);

    if ~ischar(headerLine)
        error('Header line could not be read from the file.');
    end

    %% ==========================================================
    %   Parse header → column names
    %% ==========================================================
    rawNames = strsplit(headerLine, ',');
    columnNames = strtrim(rawNames);  % remove whitespace

    nCols = numel(columnNames);

    % Prepare import options
    opts = delimitedTextImportOptions("NumVariables", nCols);
    opts.VariableNamingRule = 'preserve';
    opts.DataLines = [lineNum + 2, Inf];
    opts.Delimiter = ",";
    opts.VariableNames = columnNames;
    opts.VariableTypes = repmat("double", 1, nCols);

    %% ==========================================================
    %   Locate required columns (exact MPMS names)
    %% ==========================================================

    % Exact string match — your choice (like you wanted)
    timeIndex  = find(strcmp(columnNames, 'Time Stamp (sec)'), 1);
    tempIndex  = find(strcmp(columnNames, 'Temperature (K)'), 1);
    fieldIndex = find(strcmp(columnNames, 'Magnetic Field (Oe)'), 1);

    % Moment column (AC vs DC)
    if DC
        momentIndex = find(strcmp(columnNames, 'DC Moment Free Ctr (emu)'), 1);
    else
        momentIndex = find(strcmp(columnNames, 'Moment (emu)'), 1);
    end

    %% ==========================================================
    %   Error reporting if missing columns
    %% ==========================================================
    if any([isempty(timeIndex), isempty(tempIndex), isempty(fieldIndex), isempty(momentIndex)])
        disp('--- Column Names Found in File ---');
        disp(columnNames');
        error('One or more required columns were not found in the MPMS file.');
    end

    %% ==========================================================
    %   Select required columns
    %% ==========================================================
    opts.SelectedVariableNames = columnNames([timeIndex, tempIndex, momentIndex, fieldIndex]);

    %% ==========================================================
    %   Import table
    %% ==========================================================
    tbl = readtable(filename, opts);

    % Remove invalid rows
    tbl = rmmissing(tbl);

    %% ==========================================================
    %   Output variables
    %% ==========================================================
    TimeSec          = tbl.(columnNames{timeIndex});
    SampleTempKelvin = tbl.(columnNames{tempIndex});
    MomentEmu        = tbl.(columnNames{momentIndex});
    MagneticFieldOe  = tbl.(columnNames{fieldIndex});
end
