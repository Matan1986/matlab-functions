function [Temp_table, HC_table] = importFilesHC(directory, fileList, sortedFields, unitsRatio)
% importFilesHC  –  Imports temperature + heat capacity data
% NOTE:
%   sortedFields may contain zeros if field is missing.
%   This function does NOT use the field at all.
%   Field handling is fully done in getFileListHC + main code.

    nFiles = length(fileList);

    Temp_table = cell(nFiles, 1);
    HC_table   = cell(nFiles, 1);

    for i = 1:nFiles
        
        % Build full path (robust to absolute or relative names)
        if isfile(fileList{i})
            filePath = fileList{i};   % already full path
        else
            filePath = fullfile(directory, fileList{i});
        end

        try
            % Import one file
            [SampleTempKelvin, SampHCJK] = importOneFileHC(filePath);

            % Store data
            Temp_table{i} = SampleTempKelvin;
            HC_table{i}   = SampHCJK * unitsRatio;

        catch ME
            fprintf('⚠ Error importing "%s" → %s\n', fileList{i}, ME.message);
            Temp_table{i} = [];
            HC_table{i}   = [];
        end
    end
end
