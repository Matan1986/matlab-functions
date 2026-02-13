function createTableSwitching(tableData_ch1, tableData_ch2, ch1_label, ch2_label)
% CREATETABLESWITCHING  Display sorted data tables for two channels with configurable labels
%   tableData_ch1, tableData_ch2: numeric arrays or tables with columns [x, peak2peak, mean, change]
%   ch1_label, ch2_label: channel names (e.g. 'Rxy1','Rzz1')

    % Sort by percentage change (4th column) descending
    tableData_ch1 = sortrows(tableData_ch1, 4, 'descend');
    tableData_ch2 = sortrows(tableData_ch2, 4, 'descend');

    % Column setup
    column_widths = {150, 200, 150, 150};
    col_names = { ['Pulse ' ch1_label ' [mA]'], 'Peak to Peak Val.', ['Mean ' ch1_label], 'Change [%]'};
    col_names2 = { ['Pulse ' ch2_label ' [mA]'], 'Peak to Peak Val.', ['Mean ' ch2_label], 'Change [%]'};

    % Table for channel 1
    figure('Name', sprintf('Amplitude Dependence Table for %s', ch1_label), ...
           'NumberTitle','off','Units','normalized','Position',[0.25,0.25,0.5,0.4]);
    uitable('Data', tableData_ch1, 'ColumnName', col_names, ...
            'RowName', [],'Units','normalized','Position',[0,0,1,1],...
            'FontSize',14,'ColumnWidth',column_widths);

    % Table for channel 2
    figure('Name', sprintf('Amplitude Dependence Table for %s', ch2_label), ...
           'NumberTitle','off','Units','normalized','Position',[0.25,0.25,0.5,0.4]);
    uitable('Data', tableData_ch2, 'ColumnName', col_names2, ...
            'RowName', [],'Units','normalized','Position',[0,0,1,1],...
            'FontSize',14,'ColumnWidth',column_widths);
end