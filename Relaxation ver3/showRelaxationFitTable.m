function showRelaxationFitTable(fitResults, exportToExcel, showInFigure, saveDir)
% showRelaxationFitTable — display, export, and visualize relaxation fit summary
%
% Columns displayed (with units):
%   Temp_K [K]
%   model_type [text]
%   M0 [μB/Co]
%   S [μB/Co]
%   tau_s [s]
%   n (dimensionless)
%   R2 (dimensionless)

if nargin < 2, exportToExcel = false; end
if nargin < 3, showInFigure = false; end
if nargin < 4, saveDir = pwd; end

if isempty(fitResults)
    warning('No fit results to display.');
    return;
end

%% -------- Normalize to table --------
if isstruct(fitResults)
    fitResults = struct2table(fitResults);
end

%% -------- Sorting --------
if ismember('Temp_K', fitResults.Properties.VariableNames)
    fitResults = sortrows(fitResults, 'Temp_K');
end

%% -------- Column renaming + units --------
renameMap = {
    'Temp_K', 'Temp_K';
    'model_type', 'model_type';
    'M0', 'M0_muBperCo';
    'S', 'S_muBperCo';
    'tau', 'tau_s';
    'n', 'n';
    'R2', 'R2';
};

for k = 1:size(renameMap,1)
    old = renameMap{k,1};
    new = renameMap{k,2};
    if ismember(old, fitResults.Properties.VariableNames)
        fitResults.Properties.VariableNames{strcmp(fitResults.Properties.VariableNames,old)} = new;
    end
end

%% -------- Keep only available columns --------
cols = {'Temp_K', 'model_type', 'M0_muBperCo', 'S_muBperCo', 'tau_s', 'n', 'R2'};
cols = cols(ismember(cols, fitResults.Properties.VariableNames));
fitDisplay = fitResults(:, cols);

%% -------- Console summary --------
fprintf('\n=== Relaxation Fit Summary ===\n');

% Model distribution summary (backward compatible)
if ismember('model_type', fitResults.Properties.VariableNames)
    modelVals = lower(string(fitResults.model_type));
else
    modelVals = repmat("kww", height(fitResults), 1);
end
nLog = sum(modelVals == "log");
nKww = sum(modelVals == "kww");
nFallback = sum(modelVals == "fallback");

fprintf('Model counts:\n');
fprintf('   log: %d\n', nLog);
fprintf('   kww: %d\n', nKww);
fprintf('   fallback: %d\n\n', nFallback);

headerParts = strings(0,1);
if ismember('Temp_K', fitDisplay.Properties.VariableNames), headerParts(end+1) = "Temp(K)"; end
if ismember('model_type', fitDisplay.Properties.VariableNames), headerParts(end+1) = "model"; end
if ismember('M0_muBperCo', fitDisplay.Properties.VariableNames), headerParts(end+1) = "M0(μB/Co)"; end
if ismember('S_muBperCo', fitDisplay.Properties.VariableNames), headerParts(end+1) = "S(μB/Co)"; end
if ismember('tau_s', fitDisplay.Properties.VariableNames), headerParts(end+1) = "tau(s)"; end
if ismember('n', fitDisplay.Properties.VariableNames), headerParts(end+1) = "n"; end
if ismember('R2', fitDisplay.Properties.VariableNames), headerParts(end+1) = "R²"; end
fprintf('   %s\n', strjoin(cellstr(headerParts), '   '));
fprintf('   ------------------------------------------------------------------------------\n');

for i = 1:height(fitDisplay)
    rowParts = strings(0,1);
    if ismember('Temp_K', fitDisplay.Properties.VariableNames)
        rowParts(end+1) = string(sprintf('%6.2f', fitDisplay.Temp_K(i)));
    end
    if ismember('model_type', fitDisplay.Properties.VariableNames)
        rowParts(end+1) = string(fitDisplay.model_type(i));
    end
    if ismember('M0_muBperCo', fitDisplay.Properties.VariableNames)
        rowParts(end+1) = string(sprintf('%12.3e', fitDisplay.M0_muBperCo(i)));
    end
    if ismember('S_muBperCo', fitDisplay.Properties.VariableNames)
        rowParts(end+1) = string(sprintf('%12.3e', fitDisplay.S_muBperCo(i)));
    end
    if ismember('tau_s', fitDisplay.Properties.VariableNames)
        rowParts(end+1) = string(sprintf('%8.2f', fitDisplay.tau_s(i)));
    end
    if ismember('n', fitDisplay.Properties.VariableNames)
        rowParts(end+1) = string(sprintf('%6.3f', fitDisplay.n(i)));
    end
    if ismember('R2', fitDisplay.Properties.VariableNames)
        rowParts(end+1) = string(sprintf('%6.3f', fitDisplay.R2(i)));
    end
    fprintf('   %s\n', strjoin(cellstr(rowParts), '   '));
end
fprintf('\n');

%% -------- Export to Excel --------
if exportToExcel
    filePath = fullfile(saveDir, 'Relaxation_summary.xlsx');
    try
        writetable(fitDisplay, filePath);
        fprintf('✅ Summary table saved to: %s\n', filePath);
    catch ME
        warning('❌ Failed to export to Excel: %s', ME.message);
    end
end

%% -------- Visualization --------
if showInFigure
    try
        % Convert table to cell array and sanitize for uitable compatibility
        tableData = table2cell(fitDisplay);
        
        % Sanitize cell array: uitable only accepts numeric, logical, or char
        for row = 1:size(tableData, 1)
            for col = 1:size(tableData, 2)
                val = tableData{row, col};
                if isstring(val)
                    % Convert string to char
                    tableData{row, col} = char(val);
                elseif iscategorical(val)
                    % Convert categorical to char
                    tableData{row, col} = char(string(val));
                elseif isnumeric(val) || islogical(val)
                    % Already compatible, keep as-is
                    continue;
                elseif ischar(val)
                    % Already compatible, keep as-is
                    continue;
                else
                    % Fallback: convert to char
                    tableData{row, col} = char(string(val));
                end
            end
        end
        
        % Modern UIFigure
        fig = uifigure('Name','Relaxation Fit Table','Color','w','Position',[300 200 650 420]);
        gl = uigridlayout(fig,[2,1]);
        gl.RowHeight = {'fit','1x'};
        gl.Padding = [10 8 10 8];

        uilabel(gl, 'Text', sprintf('Relaxation Fit Summary (%d curves)', height(fitDisplay)), ...
            'FontWeight','bold', 'FontSize', 15, ...
            'HorizontalAlignment','center');

        uitable(gl, ...
            'Data', tableData, ...
            'ColumnName', fitDisplay.Properties.VariableNames, ...
            'ColumnWidth', 'auto', ...
            'FontSize', 12, ...
            'RowStriping', 'on');

    catch
        % Fallback
        fig = figure('Name','Relaxation Fit Table','Color','w','NumberTitle','off', ...
                     'Units','normalized','Position',[0.35 0.32 0.35 0.45]);

        uicontrol('Style','text', 'String', ...
            sprintf('Relaxation Fit Summary (%d curves)', height(fitDisplay)), ...
            'Units','normalized', 'Position',[0.05 0.91 0.9 0.08], ...
            'FontWeight','bold','FontSize',14,'BackgroundColor','w', ...
            'HorizontalAlignment','center');

        % Sanitize data for fallback uitable as well
        tableData = table2cell(fitDisplay);
        for row = 1:size(tableData, 1)
            for col = 1:size(tableData, 2)
                val = tableData{row, col};
                if isstring(val)
                    tableData{row, col} = char(val);
                elseif iscategorical(val)
                    tableData{row, col} = char(string(val));
                elseif ~(isnumeric(val) || islogical(val) || ischar(val))
                    tableData{row, col} = char(string(val));
                end
            end
        end

        uitable(fig, ...
            'Data', tableData, ...
            'ColumnName', fitDisplay.Properties.VariableNames, ...
            'Units', 'normalized', ...
            'Position', [0.05 0.05 0.9 0.85], ...
            'FontSize', 12, ...
            'ColumnWidth', 'auto', ...
            'RowStriping', 'on');
    end
end

end
