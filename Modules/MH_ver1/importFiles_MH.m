function [Time_table, Temp_table, VSM_table, MagneticFieldOe_table] = ...
         importFiles_MH(directory, fileList, sortedTemperatures, MPMS_flag, DC_flag)

% IMPORTFILES_MH  Load MH curves from VSM/MPMS/PPMS automatically.
%
% Inputs:
%   directory          - folder path
%   fileList           - list of filenames
%   sortedTemperatures - vector of temps
%   MPMS_flag          - ignored (auto detected!)
%   DC_flag            - for MPMS DC-moment
%
% Outputs:
%   Time_table, Temp_table, VSM_table, MagneticFieldOe_table

    nFiles = numel(fileList);

    Time_table           = cell(nFiles,1);
    Temp_table           = cell(nFiles,1);
    VSM_table            = cell(nFiles,1);
    MagneticFieldOe_table = cell(nFiles,1);

    for i = 1:nFiles
        fname = fileList{i};
        fullpath = fullfile(directory, fname);

        % =============== AUTO-DETECT SYSTEM TYPE =====================
        systemType = detect_MH_file_type(directory, fname);
        isMPMS = strcmpi(systemType, 'MPMS');
        isPPMS = ~isMPMS;

        % =============== IMPORT ======================================
        try
            if isMPMS
                [TimeSec, T, M, H] = importOneFile_MH_MPMS(fullpath, DC_flag);
            else
                [TimeSec, T, M, H] = importOneFile_MH(fullpath);
            end
        catch ME
            fprintf("Error processing file: %s - %s\n", fname, ME.message);
            continue;
        end

        % =============== Store output ================================
        Time_table{i}           = TimeSec;
        Temp_table{i}           = T;
        VSM_table{i}            = M;
        MagneticFieldOe_table{i} = H;
    end
end
