function showRelaxationFitTable(fitResults, exportToExcel, showInFigure, saveDir)
% showRelaxationFitTable — display, export, and visualize relaxation fit summary
%
% Columns displayed (with units):
%   Temp_K [K]
%   M0 [μB/Co]
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
    'M0', 'M0_muBperCo';
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
cols = {'Temp_K', 'M0_muBperCo', 'tau_s', 'n', 'R2'};
cols = cols(ismember(cols, fitResults.Properties.VariableNames));
fitDisplay = fitResults(:, cols);

%% -------- Console summary --------
fprintf('\n=== Relaxation Fit Summary ===\n');
fprintf('   Temp(K)   M0(μB/Co)     tau(s)       n       R² \n');
fprintf('   ------------------------------------------------------\n');

for i = 1:height(fitDisplay)
    fprintf('   %6.2f   %12.3e   %8.2f   %6.3f   %6.3f\n', ...
        fitDisplay.Temp_K(i), ...
        fitDisplay.M0_muBperCo(i), ...
        fitDisplay.tau_s(i), ...
        fitDisplay.n(i), ...
        fitDisplay.R2(i));
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
        % Modern UIFigure
        fig = uifigure('Name','Relaxation Fit Table','Color','w','Position',[300 200 650 420]);
        gl = uigridlayout(fig,[2,1]);
        gl.RowHeight = {'fit','1x'};
        gl.Padding = [10 8 10 8];

        uilabel(gl, 'Text', sprintf('Relaxation Fit Summary (%d curves)', height(fitDisplay)), ...
            'FontWeight','bold', 'FontSize', 15, ...
            'HorizontalAlignment','center');

        uitable(gl, ...
            'Data', table2cell(fitDisplay), ...
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

        uitable(fig, ...
            'Data', table2cell(fitDisplay), ...
            'ColumnName', fitDisplay.Properties.VariableNames, ...
            'Units', 'normalized', ...
            'Position', [0.05 0.05 0.9 0.85], ...
            'FontSize', 12, ...
            'ColumnWidth', 'auto', ...
            'RowStriping', 'on');
    end
end

end
