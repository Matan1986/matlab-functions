function [Time_table,Temp_table, VSM_table, MagneticFieldOe_table] = importFiles_MT(directory, fileList, sortedFields,MPMS,DC)
    % Initialize output arrays to store data from all files
    Time_table = cell(length(fileList), 1);
    Temp_table = cell(length(fileList), 1);
    VSM_table = cell(length(fileList), 1);
    MagneticFieldOe_table= cell(length(fileList), 1);

    % Loop over each file in the fileList
    for i = 1:length(fileList)
        % Check if the fileList already contains full file paths
        if isfile(fileList{i})
            filePath = fileList{i};  % Use the full path from fileList
        else
            filePath = fullfile(directory, fileList{i});  % Construct full file path
        end
        
        % Display progress
        % disp(['Processing file: ', filePath]);
        
        % Import the data using the importOneFileVSM function
        try
            if(~MPMS)
                [TimeSec,SampleTempKelvin, SampVSMMomentEmu,MagneticFieldOe] = importOneFile_MT(filePath);
            else
                 [TimeSec,SampleTempKelvin, SampVSMMomentEmu,MagneticFieldOe] = importOneFile_MT_MPMS(filePath,DC);
            end
            
            % Store data in the cell arrays
            Time_table{i} = TimeSec;
            Temp_table{i} = SampleTempKelvin;
            VSM_table{i} = SampVSMMomentEmu;
            MagneticFieldOe_table{i}=MagneticFieldOe;
        catch ME
            disp(['Error processing file: ', fileList{i}, ' - ', ME.message]);
            % Continue to next file in case of error
            continue;
        end
    end
end
