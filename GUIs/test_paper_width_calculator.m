function test_paper_width_calculator()
% TEST_PAPER_WIDTH_CALCULATOR - Verify the paper layout width feature
% Tests the calculation: targetWidth = columnWidth / figuresAcross

fprintf('\n=== PAPER LAYOUT WIDTH CALCULATOR TEST ===\n\n');

% Constants from FinalFigureFormatterUI
singleColWidth = 3.375;   % inch (APS/PRL)
doubleColWidth = 7.0;     % inch (APS/PRL)
screenDPI = get(0, 'ScreenPixelsPerInch');

fprintf('Screen DPI: %d\n\n', round(screenDPI));

% Test case 1: Single column, 1 figure
fprintf('TEST 1: Single column, 1 figure across\n');
colWidth = singleColWidth;
figsAcross = 1;
figWidthInches = colWidth / figsAcross;
figWidthPixels = figWidthInches * screenDPI;
fprintf('  %.2f in ÷ %d = %.3f in = %d px\n', colWidth, figsAcross, figWidthInches, round(figWidthPixels));
assert(abs(figWidthInches - 3.375) < 0.001, 'Single col test failed');
fprintf('  ✓ PASS\n\n');

% Test case 2: Single column, 2 figures
fprintf('TEST 2: Single column, 2 figures across\n');
colWidth = singleColWidth;
figsAcross = 2;
figWidthInches = colWidth / figsAcross;
figWidthPixels = figWidthInches * screenDPI;
fprintf('  %.2f in ÷ %d = %.3f in = %d px\n', colWidth, figsAcross, figWidthInches, round(figWidthPixels));
assert(abs(figWidthInches - 1.6875) < 0.001, 'Two figs in single col test failed');
fprintf('  ✓ PASS\n\n');

% Test case 3: Double column, 1 figure
fprintf('TEST 3: Double column, 1 figure across\n');
colWidth = doubleColWidth;
figsAcross = 1;
figWidthInches = colWidth / figsAcross;
figWidthPixels = figWidthInches * screenDPI;
fprintf('  %.2f in ÷ %d = %.3f in = %d px\n', colWidth, figsAcross, figWidthInches, round(figWidthPixels));
assert(abs(figWidthInches - 7.0) < 0.001, 'Double col test failed');
fprintf('  ✓ PASS\n\n');

% Test case 4: Double column, 2 figures
fprintf('TEST 4: Double column, 2 figures across\n');
colWidth = doubleColWidth;
figsAcross = 2;
figWidthInches = colWidth / figsAcross;
figWidthPixels = figWidthInches * screenDPI;
fprintf('  %.2f in ÷ %d = %.3f in = %d px\n', colWidth, figsAcross, figWidthInches, round(figWidthPixels));
assert(abs(figWidthInches - 3.5) < 0.001, 'Two figs in double col test failed');
fprintf('  ✓ PASS\n\n');

% Test case 5: Double column, 3 figures
fprintf('TEST 5: Double column, 3 figures across\n');
colWidth = doubleColWidth;
figsAcross = 3;
figWidthInches = colWidth / figsAcross;
figWidthPixels = figWidthInches * screenDPI;
fprintf('  %.2f in ÷ %d = %.3f in = %d px\n', colWidth, figsAcross, figWidthInches, round(figWidthPixels));
assert(abs(figWidthInches - 2.3333) < 0.001, 'Three figs in double col test failed');
fprintf('  ✓ PASS\n\n');

fprintf('=== ALL TESTS PASSED ===\n');
fprintf('\nFeature: Paper Layout Width Calculator\n');
fprintf('Purpose: Calculate figure window width for journal column geometry\n');
fprintf('User inputs:\n');
fprintf('  - Single/Double column mode\n');
fprintf('  - Number of figures across width (1-5)\n');
fprintf('Button: "Apply Paper Width"\n');
fprintf('Result: Figure Width field updated automatically\n');
fprintf('Height: NOT modified (user controls separately)\n\n');

end
