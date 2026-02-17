function test_ui_integration()
% TEST_UI_INTEGRATION - Verify Paper Layout Width Calculator UI integration

fprintf('\n=== PAPER WIDTH CALCULATOR UI INTEGRATION TEST ===\n\n');

fprintf('Testing UI component definitions...\n');

% Load the file and check for required strings
src = fileread('FinalFigureFormatterUI.m');

% Check 1: Panel definition
if contains(src, "pPaper = uipanel(gl,'Title','Paper Layout Width Calculator');")
    fprintf('✓ Paper Layout Width panel defined\n');
else
    error('Paper Layout Width panel not found');
end

% Check 2: Column mode dropdown
if contains(src, "hColMode = uidropdown(gPaper,'Items',{'Single column','Double column'}")
    fprintf('✓ Column mode dropdown defined\n');
else
    error('Column mode dropdown not found');
end

% Check 3: Figures across field
if contains(src, "hFigsAcross = uieditfield(gPaper,'numeric','Value',1,'Limits',[1 5])")
    fprintf('✓ Figures across field defined\n');
else
    error('Figures across field not found');
end

% Check 4: Apply button
if contains(src, "btnPaperWidth = uibutton(gPaper,'Text','Apply Paper Width','ButtonPushedFcn',@applyPaperWidth);")
    fprintf('✓ Apply Paper Width button defined\n');
else
    error('Apply Paper Width button not found');
end

% Check 5: Callback function
if contains(src, "function applyPaperWidth(~,~)")
    fprintf('✓ applyPaperWidth callback function defined\n');
else
    error('applyPaperWidth callback not found');
end

% Check 6: Preferences save
if contains(src, "setpref(prefGroup,'PaperColMode',hColMode.Value);") && ...
   contains(src, "setpref(prefGroup,'PaperFigsAcross',double(hFigsAcross.Value));")
    fprintf('✓ Preferences save implemented\n');
else
    error('Preferences save not implemented');
end

% Check 7: Preferences load
if contains(src, "hColMode.Value = cm;") && ...
   contains(src, "hFigsAcross.Value = fa(1);")
    fprintf('✓ Preferences load implemented\n');
else
    error('Preferences load not implemented');
end

% Check 8: Default values
if contains(src, "hColMode.Value = 'Single column'; hFigsAcross.Value = 1;")
    fprintf('✓ Default values set\n');
else
    error('Default values not set');
end

% Check 9: Panel row numbering
if contains(src, "pPaper.Layout.Row = 3;") && ...
   contains(src, "pAx.Layout.Row = 4;") && ...
   contains(src, "pApp.Layout.Row = 5;") && ...
   contains(src, "pTypo.Layout.Row = 7;") && ...
   contains(src, "pAdvanced.Layout.Row = 8;")
    fprintf('✓ Panel row numbering updated\n');
else
    error('Panel row numbering incorrect');
end

% Check 10: Constants used in calculation
if contains(src, 'singleColWidth') && contains(src, 'doubleColWidth')
    fprintf('✓ Column width constants available\n');
else
    error('Column width constants not found');
end

fprintf('\n=== UI INTEGRATION VERIFIED ===\n\n');

fprintf('New Feature Summary:\n');
fprintf('  Location: Row 3 (between Figure Size and Axes Size)\n');
fprintf('  Controls:\n');
fprintf('    - Column mode: Single/Double\n');
fprintf('    - Figures across: 1-5\n');
fprintf('    - Button: Apply Paper Width\n');
fprintf('  Calculation: width = columnWidth / figuresAcross\n');
fprintf('  Conversion: inches × screenDPI = pixels\n');
fprintf('  Integration: Full preferences persistence\n');
fprintf('\n');

end
