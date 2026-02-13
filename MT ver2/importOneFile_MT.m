function [TimeSec,SampleTempKelvin, MomentEmu,MagneticFieldOe] = importOneFile_MT(filename)
    % Import data from a VSM .DAT file starting after the [Data] section
    %
    % Inputs:
    %   filename - Path to the file
    %
    % Outputs:
    %   SampleTempKelvin - Column vector of temperatures in Kelvin
    %   MomentEmu - Column vector of magnetic moments in emu

    %% Locate the start of data
    fid = fopen(filename, 'r');
    line = '';
    lineNum = 0;

    % Find the line after [Data]
    while ischar(line)
        line = fgetl(fid);
        lineNum = lineNum + 1;
        if contains(line, '[Data]')
            break;
        end
    end
    fclose(fid);

    % Data starts two lines after [Data]
    dataStartLine = lineNum + 1;

    %% Set up the Import Options
    opts = delimitedTextImportOptions("NumVariables", 50);

    % Specify range and delimiter
    opts.DataLines = [dataStartLine, Inf];
    opts.Delimiter = ","; % Comma-delimited file

    % Specify variable names and types
    opts.VariableNames = ["Comment", "TimeStampSec", "TemperatureK", ...
                          "MagneticFieldOe", "MomentEmu", repmat("Var", 1, 45)];
    opts.VariableTypes = ["string", "double", "double", ...
                          "double", "double", repmat("double", 1, 45)];
    opts.SelectedVariableNames = ["TimeStampSec","TemperatureK", "MomentEmu","MagneticFieldOe"];

    % Import the data
    tbl = readtable(filename, opts);

    %% Remove rows with NaN values
    tbl = rmmissing(tbl);

    %% Extract the desired columns
    TimeSec=tbl.TimeStampSec;
    SampleTempKelvin = tbl.TemperatureK;
    MomentEmu = tbl.MomentEmu;
    MagneticFieldOe =tbl.MagneticFieldOe;
end
