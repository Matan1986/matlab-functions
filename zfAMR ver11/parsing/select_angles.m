function [selected_angles, selected_data] = select_angles(unique_angles)
    % Create figure for interactive angle and data selection
    f = figure('Name', 'Select Angles and Data for Plotting', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none');
    movegui(f, 'center');

    % Create list box for angle selection
    uicontrol('Style', 'text', 'String', 'Select Angles:', 'Position', [20 340 100 30], 'FontSize', 12, 'HorizontalAlignment', 'left');
    listbox = uicontrol('Style', 'listbox', 'Position', [20 160 150 180], 'String', strcat(string(unique_angles'), '^{\circ}'), 'Max', length(unique_angles), 'Min', 1, 'FontSize', 12);

    % Create radio buttons for data selection
    uicontrol('Style', 'text', 'String', 'Select Data:', 'Position', [200 340 100 30], 'FontSize', 12, 'HorizontalAlignment', 'left');
    button_group = uibuttongroup('Position', [0.35 0.5 0.5 0.35]);
    rxy1_button = uicontrol(button_group, 'Style', 'radiobutton', 'String', 'Rxy1', 'Position', [10 80 100 30], 'FontSize', 12);
    rxx2_button = uicontrol(button_group, 'Style', 'radiobutton', 'String', 'Rxx2', 'Position', [10 50 100 30], 'FontSize', 12);
    both_button = uicontrol(button_group, 'Style', 'radiobutton', 'String', 'Both', 'Position', [10 20 100 30], 'FontSize', 12);
    set(button_group, 'SelectedObject', both_button);

    % Create OK button
    uicontrol('Style', 'pushbutton', 'String', 'OK', 'Position', [20 20 70 30], 'Callback', @okButtonCallback);

    % Create Cancel button
    uicontrol('Style', 'pushbutton', 'String', 'Cancel', 'Position', [100 20 70 30], 'Callback', @cancelButtonCallback);

    % Wait for user to select angles and data
    uiwait(f);

    function okButtonCallback(~, ~)
        % Retrieve selected angles and data, then close the figure
        selected_indices = get(listbox, 'Value');
        selected_angles = unique_angles(selected_indices);
        selected_data = get(get(button_group, 'SelectedObject'), 'String');
        uiresume(f);
        close(f);
    end

    function cancelButtonCallback(~, ~)
        % Set selected angles and data to empty, then close the figure
        selected_angles = [];
        selected_data = [];
        uiresume(f);
        close(f);
    end
end
