% Define the directory containing the .mat files
directory = "J:\My Drive\Quantum materials lab\Projects\Magnetic Intercalated TMD\Co1_3TaS2\Transport comparison\Tables";

% Set the flag to export to PowerPoint
exportToPPT = true;  % Set to true to export the combined table to PowerPoint, false to skip

% Get a list of all .mat files in the directory
matFiles = dir(fullfile(directory, '*.mat'));

% Initialize an empty table to store combined results
combinedTable = table();

% Loop through each file and load the table
for i = 1:length(matFiles)
    % Load the .mat file
    filePath = fullfile(directory, matFiles(i).name);  % <-- Corrected this line
    data = load(filePath);
    
    % Extract the table (assuming the table is stored under a specific variable name)
    resultsTable = data.Results_Table;
    
    % Extract MG and FIB numbers from the filename (assuming a consistent naming pattern)
    tokens = regexp(matFiles(i).name, 'MG_(\d+)_FIB_(\d+)_', 'tokens');
    
    if ~isempty(tokens)
        MG_num = str2double(tokens{1}{1});
        FIB_num = str2double(tokens{1}{2});
    else
        % Case where FIB is not mentioned in the filename
        tokens = regexp(matFiles(i).name, 'MG_(\d+)_', 'tokens');
        if ~isempty(tokens)
            MG_num = str2double(tokens{1}{1});
            FIB_num = 0;  % Default FIB number when not specified
        else
            warning('Could not extract MG number from filename: %s', matFiles(i).name);
            continue;
        end
    end
    
    % Add MG and FIB numbers as the first columns
    numRows = height(resultsTable);
    MG_column = repmat(MG_num, numRows, 1);
    FIB_column = repmat(FIB_num, numRows, 1);
    
    % Combine MG, FIB columns with the results table
    resultsTable = [table(MG_column, FIB_column, 'VariableNames', {'MG', 'FIB'}), resultsTable];
    
    % Append the current results table to the combined table
    combinedTable = [combinedTable; resultsTable];
end

% Sort the combined table by MG and FIB
combinedTable = sortrows(combinedTable, {'MG', 'FIB'});

% Display the combined and sorted table
disp(combinedTable);

% Save the combined table to a new .mat file
outputFilePath = fullfile(directory, 'Combined_Transport_Results.mat');
save(outputFilePath, 'combinedTable');

% Export to PowerPoint if the flag is set
if exportToPPT
    % Create a PowerPoint presentation
    ppt = actxserver('PowerPoint.Application');
    presentation = ppt.Presentation.Add;

    % Add a slide
    slide = presentation.Slides.Add(1, 'ppLayoutText');
    
    % Set the title of the slide
    slide.Shapes.Title.TextFrame.TextRange.Text = 'Combined Transport Results';

    % Convert the table to a cell array for PowerPoint insertion
    cellData = [combinedTable.Properties.VariableNames; table2cell(combinedTable)];
    
    % Add the table to the slide
    tableShape = slide.Shapes.AddTable(size(cellData, 1), size(cellData, 2));
    tableObj = tableShape.Table;
    
    % Fill the PowerPoint table with data
    for row = 1:size(cellData, 1)
        for col = 1:size(cellData, 2)
            tableObj.Cell(row, col).Shape.TextFrame.TextRange.Text = cellData{row, col};
        end
    end

    % Save the PowerPoint presentation
    pptFilePath = fullfile(directory, 'Combined_Transport_Results.pptx');
    presentation.SaveAs(pptFilePath);
    presentation.Close;
    ppt.Quit;

    disp(['PowerPoint presentation saved as: ', pptFilePath]);
end
