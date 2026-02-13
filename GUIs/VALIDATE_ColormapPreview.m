%% MANUAL VALIDATION: Test colormap preview button and key features
% Run this to manually inspect the "Show All Colormaps" window

function VALIDATE_ColormapPreview()
    
    disp('====================================');
    disp('MANUAL VALIDATION: Colormap Preview');
    disp('====================================');
    disp(' ');
    
    % Create test figures with different styles
    createSampleScientificFigures();
    pause(1);
    
    % Launch the main UI
    disp('Launching FinalFigureFormatterUI...');
    FinalFigureFormatterUI();
    pause(2);
    disp(' ');
    
    % Get the UI figure
    allFigs = findall(0,'Type','figure');
    uiFig = [];
    for k = 1:numel(allFigs)
        if ~strcmp(allFigs(k).Name,'Test Figure 1') && ~strcmp(allFigs(k).Name,'Test Figure 2') && ~strcmp(allFigs(k).Name,'Test Figure 3')
            uiFig = allFigs(k);
            break;
        end
    end
    
    if isempty(uiFig)
        disp('ERROR: UI figure not found');
        return;
    end
    
    disp('INSTRUCTIONS FOR MANUAL VALIDATION:');
    disp('====================================');
    disp(' ');
    disp('TEST 1: Test "Show All Maps" button');
    disp('  1. In the Appearance panel (middle right),');
    disp('     look for button labeled "Show All Maps"');
    disp('  2. Click "Show All Maps"');
    disp('  3. A NEW WINDOW should open showing ALL colormaps');
    disp('  4. Window should display ~80 colormaps as horizontal bars');
    disp('  5. Each colormap should be clearly visible and labeled');
    disp('  6. Window should be scrollable if contains >40 maps');
    disp(' ');
    
    disp('TEST 2: Test colormap application');
    disp('  1. In Appearance panel, select a colormap (e.g., ''jet'')');
    disp('  2. Select "Spread: wide"');
    disp('  3. Select ''Open figs'' target');
    disp('  4. Click "Apply Appearance"');
    disp('  5. Check sample figures - colormaps should be applied');
    disp(' ');
    
    disp('TEST 3: Test legend/plot reversal');
    disp('  1. Check "Reverse Legend" checkbox');
    disp('  2. Check "Reverse Plot" checkbox');
    disp('  3. Click "Apply Appearance"');
    disp('  4. Check Test Figure 2 - legend order should be reversed');
    disp(' ');
    
    disp('TEST 4: Test SMART Layout');
    disp('  1. In SMART Layout panel (top right),');
    disp('     set Panel X=2, Panel Y=2');
    disp('  2. Click "Apply SMART"');
    disp('  3. Check sample figures - font should auto-scale');
    disp(' ');
    
    disp('TEST 5: Test Typography controls');
    disp('  1. Select font size (e.g., 14)');
    disp('  2. Click "Apply" next to font size');
    disp('  3. All text should resize in figures');
    disp('  4. Select legend size (e.g., 12)');
    disp('  5. Click "Apply" next to legend size');
    disp(' ');
    
    disp('TEST 6: Test folder processing');
    disp('  1. Check "Folder:" radio button');
    disp('  2. Click folder browse button');
    disp('  3. Select a folder with .fig files');
    disp('  4. Select colormap and spread mode');
    disp('  5. Click "Apply Appearance"');
    disp('  6. .fig files should be processed');
    disp(' ');
    
    disp('TEST 7: Test Export formats');
    disp('  1. Click any sample figure to focus it');
    disp('  2. In Save & Export panel, click "PDF"');
    disp('  3. Browse and save');
    disp('  4. Repeat for PNG, JPEG, FIG');
    disp(' ');
    
    disp('VALIDATION CHECKLIST:');
    disp('====================================');
    disp('[ ] "Show All Maps" button opens colormap preview');
    disp('[ ] Colormap preview shows 80+ colormaps as bars');
    disp('[ ] Colormap selection and apply works');
    disp('[ ] Spread modes produce different effects');
    disp('[ ] Legend reversal works correctly');
    disp('[ ] Plot reversal works correctly');
    disp('[ ] SMART layout auto-scales fonts');
    disp('[ ] Typography controls work');
    disp('[ ] Folder processing works for .fig files');
    disp('[ ] Export to PDF works');
    disp('[ ] Export to PNG works');
    disp('[ ] Export to JPEG works');
    disp('[ ] Export to FIGworks');
    disp('[ ] Preferences save/load between sessions');
    disp(' ');
    disp('UI is ready for production validation!');
    disp(' ');
    
end

function createSampleScientificFigures()
    % Create realistic scientific figures for testing
    
    % Figure 1: Scatter plot with colormap
    f1 = figure('Name','Test Figure 1');
    x = randn(100,1);
    y = randn(100,1);
    c = x + y;
    scatter(x, y, 50, c, 'filled');
    colorbar;
    title('Test Figure 1: Scatter Plot with Colormap');
    xlabel('X value');
    ylabel('Y value');
    
    % Figure 2: Multiple lines with legend
    f2 = figure('Name','Test Figure 2');
    t = linspace(0,4*pi,200);
    for n = 1:4
        amp = n;
        freq = n;
        plot(t, amp*sin(freq*t), 'LineWidth',2, 'DisplayName',sprintf('n=%d',n));
        hold on;
    end
    legend('Location','best');
    title('Test Figure 2: Multiple Sine Waves');
    xlabel('Time');
    ylabel('Amplitude');
    grid on;
    
    % Figure 3: Surface/contour plot
    f3 = figure('Name','Test Figure 3');
    [X,Y] = meshgrid(-3:0.1:3, -3:0.1:3);
    Z = sin(sqrt(X.^2+Y.^2)) ./ sqrt(X.^2+Y.^2+0.1);
    contourf(X, Y, Z, 20);
    colorbar;
    title('Test Figure 3: Contour Plot');
    xlabel('X');
    ylabel('Y');
    
end
