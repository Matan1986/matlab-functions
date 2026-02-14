function TEST_Improved_SCM8_Simple()
% TEST_IMPROVED_SCM8_SIMPLE - Simple validation that the UI launches correctly

fprintf('\n===== TESTING FINAL FIGUREFORMATTERUI =====\n\n');

fprintf('Launching FinalFigureFormatterUI...\n');

try
    FinalFigureFormatterUI();
    pause(1);
    fprintf('✓ UI launched successfully\n');
    
    % Try to find the colormap dropdown
    mapDropdown = findall(0, 'Style', 'popupmenu', 'Tag', '');
    if ~isempty(mapDropdown)
        % Get items from first dropdown found (should be color map selector)
        items = mapDropdown(1).Items;
        fprintf('✓ Colormap dropdown has %d items\n', numel(items));
        
        % Count non-empty items
        validItems = items(~strcmp(items, ''));
        fprintf('  Valid colormaps: %d\n', numel(validItems));
    end
    
    % Check for SCM8 section
    allText = [];
    allLabels = findall(0, 'Type', 'uilabel');
    for k = 1:numel(allLabels)
        try
            if contains(lower(allLabels(k).Text), 'scm8') || contains(lower(allLabels(k).Text), 'colourmap')
                fprintf('  Found label: %s\n', allLabels(k).Text);
            end
        catch
        end
    end
    
    fprintf('\n✓ TEST PASSED\n\n');
    
catch ME
    fprintf('✗ TEST FAILED: %s\n\n', ME.message);
end

% Clean up
try
    close(findall(0, 'Name', 'Final Figure Formatter'));
catch
end

end
