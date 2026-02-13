function [TimeSec, SampleTempKelvin, MomentEmu, MagneticFieldOe] = importOneFile_MT_MPMS(filename, DC)
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

    %% Locate the start of the [Data] section
    fid = fopen(filename, 'r');
    if fid == -1
        error(['Could not open file: ', filename]);
    end

    line = '';
    lineNum = 0;
    dataFound = false;

    % Find the line after [Data]
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

    % Read the header line (the next line after [Data])
    headerLine = fgetl(fid);
    fclose(fid);

    if isempty(headerLine)
        error('Header line could not be read from the file.');
    end

    % Split header into column names
    columnNames = strsplit(headerLine, ',');

    % Preserve original column headers
    opts = delimitedTextImportOptions("NumVariables", numel(columnNames));
    opts.VariableNamingRule = 'preserve'; % Prevent MATLAB from modifying column names
    opts.DataLines = [lineNum + 2, Inf]; % Data starts two lines after [Data]
    opts.Delimiter = ",";

    % Assign column names dynamically
    opts.VariableNames = columnNames;
    opts.VariableTypes = repmat("double", 1, numel(columnNames));

    % Find column indices dynamically
    timeIndex = find(strcmp(columnNames, 'Time Stamp (sec)'), 1);
    tempIndex = find(strcmp(columnNames, 'Temperature (K)'), 1);
    fieldIndex = find(strcmp(columnNames, 'Magnetic Field (Oe)'), 1);
    
    if DC
        momentIndex = find(strcmp(columnNames, 'DC Moment Free Ctr (emu)'), 1);
    else
        momentIndex = find(strcmp(columnNames, 'Moment (emu)'), 1);
    end

    % Check if all required columns were found
    if isempty(timeIndex) || isempty(tempIndex) || isempty(fieldIndex) || isempty(momentIndex)
        error('One or more required columns were not found in the file.');
    end

    % Select required columns dynamically
    opts.SelectedVariableNames = columnNames([timeIndex, tempIndex, momentIndex, fieldIndex]);

    % Import the data
    tbl = readtable(filename, opts);

    %% Extract the desired columns
    TimeSec = tbl.(columnNames{timeIndex});
    SampleTempKelvin = tbl.(columnNames{tempIndex});
    MomentEmu = tbl.(columnNames{momentIndex});
    MagneticFieldOe = tbl.(columnNames{fieldIndex});
end
