% smoke_test_annotation_style.m
% Smoke test to validate annotation textbox styling after SmartFigureEngine changes
% Tests that annotations use EXACT same FontSize logic as legend (via getSharedLegendTextFont)

%% Clear environment
clear all
close all
clc

fprintf('=== Annotation Styling Smoke Test ===\n\n');
fprintf('Goal: Annotations must follow EXACT legend FontSize resolution logic\n');
fprintf('Priority: style.legendFont -> SmartFigureEngine_GlobalLegendFont -> default(16)\n');
fprintf('Note: style.legendFont has HIGHEST priority and overrides appdata\n\n');

%% Create test figure
fprintf('Step 1: Creating test figure with annotation textbox and legend...\n');
fig = figure('Name', 'Annotation Style Test');
plot(1:10);
annotation('textbox', [0.2 0.7 0.2 0.1], 'String', 'Test Box');
lg = legend('Line');
fprintf('  ✓ Test figure created\n\n');

%% Test 1: style.legendFont set (highest priority)
fprintf('Step 2: Testing style.legendFont = 12 (highest priority)...\n');
style = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 1, 1, 'PRL');
style.legendFont = 12;
SmartFigureEngine.applyFullSmart(fig, style);
fprintf('  ✓ applyFullSmart completed\n\n');

fprintf('Step 3: Validating both legend and annotation FontSize = 12...\n');
ann = findall(fig, 'Type', 'textboxshape');
lg = findall(fig, 'Type', 'legend');

if isempty(ann)
    error('FAILED: No annotation textbox found.');
end
if isempty(lg)
    error('FAILED: No legend found.');
end

if lg.FontSize ~= 12
    error('FAILED: Legend FontSize incorrect. Expected 12, got %.1f', lg.FontSize);
end
if ann.FontSize ~= 12
    error('FAILED: Annotation FontSize does not match legend. Expected 12, got %.1f', ann.FontSize);
end
fprintf('  ✓ Legend FontSize = %g\n', lg.FontSize);
fprintf('  ✓ Annotation FontSize = %g (matches legend)\n\n', ann.FontSize);

%% Test 2: Global appdata (when style.legendFont not set)
fprintf('Step 4: Testing global appdata override (style.legendFont removed)...\n');
style2 = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 1, 1, 'PRL');
% Remove legendFont field to test appdata fallback
style2 = rmfield(style2, 'legendFont');
setappdata(0, 'SmartFigureEngine_GlobalLegendFont', 20);
SmartFigureEngine.applyFullSmart(fig, style2);
fprintf('  ✓ applyFullSmart with global appdata = 20 completed\n\n');

fprintf('Step 5: Validating both legend and annotation FontSize = 20...\n');
ann = findall(fig, 'Type', 'textboxshape');
lg = findall(fig, 'Type', 'legend');

if lg.FontSize ~= 20
    error('FAILED: Legend FontSize not using appdata. Expected 20, got %.1f', lg.FontSize);
end
if ann.FontSize ~= 20
    error('FAILED: Annotation FontSize does not match legend. Expected 20, got %.1f', ann.FontSize);
end
fprintf('  ✓ Legend FontSize = %g (from appdata)\n', lg.FontSize);
fprintf('  ✓ Annotation FontSize = %g (matches legend)\n\n', ann.FontSize);

%% Test 3: Verify style.legendFont overrides appdata
fprintf('Step 6: Testing style.legendFont overrides appdata...\n');
fprintf('        (appdata=20, but style.legendFont=14)\n');
style3 = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 1, 1, 'PRL');
style3.legendFont = 14;
% appdata still = 20 from previous test
SmartFigureEngine.applyFullSmart(fig, style3);
fprintf('  ✓ applyFullSmart completed\n\n');

fprintf('Step 7: Validating both use style.legendFont = 14 (not appdata 20)...\n');
ann = findall(fig, 'Type', 'textboxshape');
lg = findall(fig, 'Type', 'legend');

if lg.FontSize ~= 14
    error('FAILED: Legend not using style.legendFont. Expected 14, got %.1f', lg.FontSize);
end
if ann.FontSize ~= 14
    error('FAILED: Annotation FontSize does not match legend. Expected 14, got %.1f', ann.FontSize);
end
fprintf('  ✓ Legend FontSize = %g (style.legendFont overrides appdata)\n', lg.FontSize);
fprintf('  ✓ Annotation FontSize = %g (matches legend)\n\n', ann.FontSize);

%% Cleanup
rmappdata(0, 'SmartFigureEngine_GlobalLegendFont');

%% Success
fprintf('\n');
fprintf('================================================\n');
fprintf('✓ Annotation styling smoke test PASSED\n');
fprintf('================================================\n');
fprintf('\n');
fprintf('Summary:\n');
fprintf('  - Annotations use getSharedLegendTextFont: CONFIRMED\n');
fprintf('  - style.legendFont (highest priority): WORKING\n');
fprintf('  - Global appdata fallback: WORKING\n');
fprintf('  - Priority hierarchy: IDENTICAL TO LEGEND\n');
fprintf('  - Annotations always match legend FontSize: VERIFIED\n');
fprintf('\n');


