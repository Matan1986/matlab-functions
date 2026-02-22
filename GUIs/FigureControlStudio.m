function FigureControlStudio()
% FigureControlStudio
% Modern uifigure-based control studio for existing MATLAB figures.
% Orchestrates only explicit target resolution + adapter actions.
% NOTE:
%   ComposeSpec v0 extraction implemented via i_buildComposeSpecFromUI.
%   This supports future artifact-level reproducibility.
%   See documentation generator for ComposeSpec section.

    ui = uifigure('Name', 'FigureControlStudio', 'Position', [100 100 900 600]);
    % Deterministic GUI marker (more robust than Name matching).
    ui.Tag = "FCS_ROOT";
    setappdata(ui, 'FCS_Root', true);
    if isprop(ui, 'WindowKeyPressFcn')
        ui.WindowKeyPressFcn = @onWindowKeyPressDiagnostic;
    end

    root = uigridlayout(ui, [1 2]);
    root.ColumnWidth = {280, '1x'};
    root.RowHeight = {'1x'};
    root.Padding = [8 8 8 8];
    root.ColumnSpacing = 10;

    targetPanel = uipanel(root, 'Title', 'Targets');
    targetPanel.Layout.Row = 1;
    targetPanel.Layout.Column = 1;

    tabs = uitabgroup(root);
    tabs.Layout.Row = 1;
    tabs.Layout.Column = 2;

    % ---------------- Left: Targets ----------------
    tgtGrid = uigridlayout(targetPanel, [11 1]);
    tgtGrid.RowHeight = {22, 22, 22, 22, 28, '1x', 24, 22, 22, 24, 'fit'};
    tgtGrid.ColumnWidth = {'1x'};
    tgtGrid.Padding = [8 8 8 8];

uilabel(tgtGrid, 'Text', 'Scope Mode');

ddScope = uidropdown(tgtGrid, ...
    'Items', {'Explicit List', ...
              'Current Figure', ...
              'All Open Figures', ...
              'By Tag', ...
              'By Name Contains'}, ...
    'Value', 'Explicit List', ...
    'ValueChangedFcn', @onScopeModeChanged);

    efTag = uieditfield(tgtGrid, 'text', 'Placeholder', 'Tag (for By Tag)');
    efNameContains = uieditfield(tgtGrid, 'text', 'Placeholder', 'Name substring (for By Name Contains)');

    btnRefreshExplicit = uibutton(tgtGrid, 'Text', 'Refresh Explicit List', 'ButtonPushedFcn', @onRefreshExplicit);

    moveGrid = uigridlayout(tgtGrid, [1 2]);
    moveGrid.ColumnWidth = {'1x', '1x'};
    moveGrid.RowHeight = {24};
    moveGrid.Padding = [0 0 0 0];
    moveGrid.ColumnSpacing = 6;

    btnMoveUp = uibutton(moveGrid, 'Text', 'Move Up', 'ButtonPushedFcn', @onMoveUp);
    btnMoveDown = uibutton(moveGrid, 'Text', 'Move Down', 'ButtonPushedFcn', @onMoveDown);

    lbFigures = uilistbox(tgtGrid, 'Multiselect', 'on');
    lbFigures.Items = {};
    lbFigures.ItemsData = [];
    lbFigures.Value = {};

    lbFigures.Layout.Row = 6;
    lbFigures.Layout.Column = 1;

    moveGrid.Layout.Row = 7;
    moveGrid.Layout.Column = 1;

    cbExcludeGUIs = uicheckbox(tgtGrid, 'Text', 'Exclude Known GUIs', 'Value', true, 'ValueChangedFcn', @onExcludeChanged);
    cbExcludeGUIs.Layout.Row = 8;
    cbExcludeGUIs.Layout.Column = 1;

    lblDetected = uilabel(tgtGrid, 'Text', 'Detected: 0');
    lblDetected.Layout.Row = 9;
    lblDetected.Layout.Column = 1;

    btnAdvancedToggle = uibutton(tgtGrid, 'Text', 'Advanced ▸', 'ButtonPushedFcn', @onToggleAdvanced);
    btnAdvancedToggle.Layout.Row = 10;
    btnAdvancedToggle.Layout.Column = 1;

    pAdvanced = uipanel(tgtGrid, 'Title', 'Advanced');
    pAdvanced.Layout.Row = 11;
    pAdvanced.Layout.Column = 1;
    pAdvanced.Visible = 'off';

    advancedGrid = uigridlayout(pAdvanced, [2 1]);
    advancedGrid.ColumnWidth = {'1x'};
    advancedGrid.RowHeight = {'fit', 'fit'};
    advancedGrid.Padding = [8 8 8 8];
    advancedGrid.RowSpacing = 6;

    btnResetDefaults = uibutton(advancedGrid, 'Text', 'Reset to Defaults', 'ButtonPushedFcn', @onResetDefaults);

    sizeGrid = uigridlayout(advancedGrid, [1 4]);
    sizeGrid.ColumnWidth = {42, '1x', 48, '1x'};
    sizeGrid.RowHeight = {24};
    sizeGrid.Padding = [0 0 0 0];
    sizeGrid.ColumnSpacing = 6;

    uilabel(sizeGrid, 'Text', 'Width');
    nfGlobalFigWidth = uieditfield(sizeGrid, 'numeric', ...
        'Value', 1200, ...
        'Limits', [1 Inf], ...
        'RoundFractionalValues', true);
    uilabel(sizeGrid, 'Text', 'Height');
    nfGlobalFigHeight = uieditfield(sizeGrid, 'numeric', ...
        'Value', 900, ...
        'Limits', [1 Inf], ...
        'RoundFractionalValues', true);

    % explicit-list cache
    explicitHandleCache = gobjects(0,1);

    % ---------------- Main tabs (creation order) ----------------
    tLayoutGeometry = uitab(tabs, 'Title', 'Layout');
    tTextLegend = uitab(tabs, 'Title', 'Text');
    tColorsBackground = uitab(tabs, 'Title', 'Style');
    tCompose = uitab(tabs, 'Title', 'Compose');
    tExport = uitab(tabs, 'Title', 'Export');

    % ---------------- Text ----------------
    tabRootTextLegend = uigridlayout(tTextLegend, [3 1]);
    tabRootTextLegend.RowHeight = {'fit', 'fit', '1x'};
    tabRootTextLegend.ColumnWidth = {'1x'};
    tabRootTextLegend.Padding = [12 12 12 12];
    tabRootTextLegend.RowSpacing = 16;
    tabRootTextLegend.Scrollable = 'on';

    pTextAxis = uipanel(tabRootTextLegend, 'Title', 'Text & Axis');
    pTextAxis.Layout.Row = 1;
    pTextAxis.Layout.Column = 1;

    textAxisRoot = uigridlayout(pTextAxis, [2 1]);
    textAxisRoot.RowHeight = {'fit', 'fit'};
    textAxisRoot.ColumnWidth = {'1x'};
    textAxisRoot.Padding = [10 10 10 10];
    textAxisRoot.RowSpacing = 10;

    secTypoMain = uigridlayout(textAxisRoot, [3 2]);
    secTypoMain.Layout.Row = 1;
    secTypoMain.Layout.Column = 1;
    secTypoMain.ColumnWidth = {170, '1x'};
    secTypoMain.RowHeight = {'fit', 'fit', 'fit'};
    secTypoMain.Padding = [0 0 0 0];

    lblTypoFontSize = uilabel(secTypoMain, 'Text', 'Font Size', 'HorizontalAlignment', 'left');
    lblTypoFontSize.Layout.Row = 1;
    lblTypoFontSize.Layout.Column = 1;
    nfFontSize = uieditfield(secTypoMain, 'numeric', 'Value', 11, 'Limits', [1 Inf], 'RoundFractionalValues', true, ...
        'ValueChangedFcn', @onTypographyControlChanged);
    nfFontSize.Layout.Row = 1;
    nfFontSize.Layout.Column = 2;

    lblTypoAxisPreset = uilabel(secTypoMain, 'Text', 'Axis Policy preset', 'HorizontalAlignment', 'left');
    lblTypoAxisPreset.Layout.Row = 2;
    lblTypoAxisPreset.Layout.Column = 1;
    ddAxisPreset = uidropdown(secTypoMain, 'Items', {'paper'}, 'Value', 'paper', ...
        'ValueChangedFcn', @onTypographyControlChanged);
    ddAxisPreset.Layout.Row = 2;
    ddAxisPreset.Layout.Column = 2;

    lblTypoProfile = uilabel(secTypoMain, 'Text', 'Typography profile', 'HorizontalAlignment', 'left');
    lblTypoProfile.Layout.Row = 3;
    lblTypoProfile.Layout.Column = 1;
    ddTypoProfile = uidropdown(secTypoMain, 'Items', cellstr(FCS_listTypographyProfiles()), 'Value', 'Default', ...
        'ValueChangedFcn', @onTypographyControlChanged);
    ddTypoProfile.Layout.Row = 3;
    ddTypoProfile.Layout.Column = 2;

    secAnnotationText = uigridlayout(textAxisRoot, [2 1]);
    secAnnotationText.Layout.Row = 2;
    secAnnotationText.Layout.Column = 1;
    secAnnotationText.ColumnWidth = {'1x'};
    secAnnotationText.RowHeight = {'fit', 'fit'};
    secAnnotationText.Padding = [0 0 0 0];
    secAnnotationText.RowSpacing = 6;

    lblSecAnnotationText = uilabel(secAnnotationText, 'Text', 'Annotation Text', 'HorizontalAlignment', 'left');
    lblSecAnnotationText.FontWeight = 'bold';
    lblSecAnnotationText.Layout.Row = 1;
    lblSecAnnotationText.Layout.Column = 1;

    secAnnotationTextBody = uigridlayout(secAnnotationText, [5 2]);
    secAnnotationTextBody.Layout.Row = 2;
    secAnnotationTextBody.Layout.Column = 1;
    secAnnotationTextBody.ColumnWidth = {170, '1x'};
    secAnnotationTextBody.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};
    secAnnotationTextBody.Padding = [0 0 0 0];

    lblAnnFontName = uilabel(secAnnotationTextBody, 'Text', 'Font name', 'HorizontalAlignment', 'left');
    lblAnnFontName.Layout.Row = 1;
    lblAnnFontName.Layout.Column = 1;
    efAnnFontName = uieditfield(secAnnotationTextBody, 'text', 'Value', 'Helvetica', ...
        'ValueChangedFcn', @onTypographyControlChanged);
    efAnnFontName.Layout.Row = 1;
    efAnnFontName.Layout.Column = 2;

    lblAnnFontSize = uilabel(secAnnotationTextBody, 'Text', 'Font size', 'HorizontalAlignment', 'left');
    lblAnnFontSize.Layout.Row = 2;
    lblAnnFontSize.Layout.Column = 1;
    nfAnnFontSize = uieditfield(secAnnotationTextBody, 'numeric', 'Value', 11, 'Limits', [1 Inf], ...
        'ValueChangedFcn', @onTypographyControlChanged);
    nfAnnFontSize.Layout.Row = 2;
    nfAnnFontSize.Layout.Column = 2;

    lblAnnFontWeight = uilabel(secAnnotationTextBody, 'Text', 'Font weight', 'HorizontalAlignment', 'left');
    lblAnnFontWeight.Layout.Row = 3;
    lblAnnFontWeight.Layout.Column = 1;
    ddAnnFontWeight = uidropdown(secAnnotationTextBody, 'Items', {'normal','bold'}, 'Value', 'normal', ...
        'ValueChangedFcn', @onTypographyControlChanged);
    ddAnnFontWeight.Layout.Row = 3;
    ddAnnFontWeight.Layout.Column = 2;

    lblAnnInterpreter = uilabel(secAnnotationTextBody, 'Text', 'Interpreter', 'HorizontalAlignment', 'left');
    lblAnnInterpreter.Layout.Row = 4;
    lblAnnInterpreter.Layout.Column = 1;
    ddAnnInterpreter = uidropdown(secAnnotationTextBody, 'Items', {'tex','latex','none'}, 'Value', 'tex', ...
        'ValueChangedFcn', @onTypographyControlChanged);
    ddAnnInterpreter.Layout.Row = 4;
    ddAnnInterpreter.Layout.Column = 2;

    lblAnnColor = uilabel(secAnnotationTextBody, 'Text', 'Color (RGB)', 'HorizontalAlignment', 'left');
    lblAnnColor.Layout.Row = 5;
    lblAnnColor.Layout.Column = 1;
    efAnnColor = uieditfield(secAnnotationTextBody, 'text', 'Value', '[0 0 0]', ...
        'ValueChangedFcn', @onTypographyControlChanged);
    efAnnColor.Tooltip = 'RGB format: 0..1. Examples: [0.9 0.2 0.1] or 0.9 0.2 0.1 or 0.9,0.2,0.1.';
    efAnnColor.Layout.Row = 5;
    efAnnColor.Layout.Column = 2;

    pLegend = uipanel(tabRootTextLegend, 'Title', 'Legend');
    pLegend.Layout.Row = 2;
    pLegend.Layout.Column = 1;

    legendRoot = uigridlayout(pLegend, [2 1]);
    legendRoot.RowHeight = {'fit', 'fit'};
    legendRoot.ColumnWidth = {'1x'};
    legendRoot.Padding = [10 10 10 10];
    legendRoot.RowSpacing = 10;

    secLegendA = uigridlayout(legendRoot, [2 2]);
    secLegendA.Layout.Row = 1;
    secLegendA.Layout.Column = 1;
    secLegendA.ColumnWidth = {170, '1x'};
    secLegendA.RowHeight = {'fit', 'fit'};
    secLegendA.Padding = [0 0 0 0];

    lblLegendFontOverride = uilabel(secLegendA, 'Text', 'Font Size (override)', 'HorizontalAlignment', 'left');
    lblLegendFontOverride.Layout.Row = 1;
    lblLegendFontOverride.Layout.Column = 1;
    efLegendFontSize = uieditfield(secLegendA, 'text', 'Placeholder', '(inherit base)', ...
        'ValueChangedFcn', @onTypographyControlChanged);
    efLegendFontSize.Layout.Row = 1;
    efLegendFontSize.Layout.Column = 2;

    lblLegendPlacementMode = uilabel(secLegendA, 'Text', 'Placement mode', 'HorizontalAlignment', 'left');
    lblLegendPlacementMode.Layout.Row = 2;
    lblLegendPlacementMode.Layout.Column = 1;
    ddLegendPlacementMode = uidropdown(secLegendA, 'Items', {'Inside','Outside'}, 'Value', 'Inside', ...
        'ValueChangedFcn', @onLegendPlacementModeChanged);
    ddLegendPlacementMode.Layout.Row = 2;
    ddLegendPlacementMode.Layout.Column = 2;

    secLegendB = uigridlayout(legendRoot, [1 1]);
    secLegendB.Layout.Row = 2;
    secLegendB.Layout.Column = 1;
    secLegendB.RowHeight = {'fit'};
    secLegendB.ColumnWidth = {'1x'};
    secLegendB.Padding = [0 0 0 0];

    legendArrowGrid = uigridlayout(secLegendB, [3 3]);
    legendArrowGrid.Layout.Row = 1;
    legendArrowGrid.Layout.Column = 1;
    legendArrowGrid.RowHeight = {24, 24, 24};
    legendArrowGrid.ColumnWidth = {24, 24, 24};
    legendArrowGrid.RowSpacing = 6;
    legendArrowGrid.ColumnSpacing = 6;
    legendArrowGrid.Padding = [0 0 0 0];

    btnLegendNW = uibutton(legendArrowGrid, 'Text', '↖', 'ButtonPushedFcn', @(~,~) onLegendArrow('NW'));
    btnLegendNW.Layout.Row = 1;
    btnLegendNW.Layout.Column = 1;
    btnLegendN  = uibutton(legendArrowGrid, 'Text', '↑', 'ButtonPushedFcn', @(~,~) onLegendArrow('N'));
    btnLegendN.Layout.Row = 1;
    btnLegendN.Layout.Column = 2;
    btnLegendNE = uibutton(legendArrowGrid, 'Text', '↗', 'ButtonPushedFcn', @(~,~) onLegendArrow('NE'));
    btnLegendNE.Layout.Row = 1;
    btnLegendNE.Layout.Column = 3;
    btnLegendW  = uibutton(legendArrowGrid, 'Text', '←', 'ButtonPushedFcn', @(~,~) onLegendArrow('W'));
    btnLegendW.Layout.Row = 2;
    btnLegendW.Layout.Column = 1;
    btnLegendC  = uibutton(legendArrowGrid, 'Text', 'C', 'ButtonPushedFcn', @(~,~) onLegendArrow('C'));
    btnLegendC.Layout.Row = 2;
    btnLegendC.Layout.Column = 2;
    btnLegendE  = uibutton(legendArrowGrid, 'Text', '→', 'ButtonPushedFcn', @(~,~) onLegendArrow('E'));
    btnLegendE.Layout.Row = 2;
    btnLegendE.Layout.Column = 3;
    btnLegendSW = uibutton(legendArrowGrid, 'Text', '↙', 'ButtonPushedFcn', @(~,~) onLegendArrow('SW'));
    btnLegendSW.Layout.Row = 3;
    btnLegendSW.Layout.Column = 1;
    btnLegendS  = uibutton(legendArrowGrid, 'Text', '↓', 'ButtonPushedFcn', @(~,~) onLegendArrow('S'));
    btnLegendS.Layout.Row = 3;
    btnLegendS.Layout.Column = 2;
    btnLegendSE = uibutton(legendArrowGrid, 'Text', '↘', 'ButtonPushedFcn', @(~,~) onLegendArrow('SE'));
    btnLegendSE.Layout.Row = 3;
    btnLegendSE.Layout.Column = 3;

    % ---------------- Style ----------------
    tabRootStyle = uigridlayout(tColorsBackground, [3 1]);
    tabRootStyle.RowHeight = {'fit', 'fit', 'fit'};
    tabRootStyle.ColumnWidth = {'1x'};
    tabRootStyle.Padding = [12 12 12 12];
    tabRootStyle.RowSpacing = 12;
    tabRootStyle.Scrollable = 'on';

    % ---------------- Layout ----------------
    tabRootLayoutGeometry = uigridlayout(tLayoutGeometry, [5 1]);
    tabRootLayoutGeometry.RowHeight = {'fit', 14, 'fit', 14, 'fit'};
    tabRootLayoutGeometry.ColumnWidth = {'1x'};
    tabRootLayoutGeometry.Padding = [12 12 12 12];
    tabRootLayoutGeometry.RowSpacing = 0;
    tabRootLayoutGeometry.Scrollable = 'on';

    cmapItems = i_getAvailableColormapNames();
    if isempty(cmapItems)
        cmapItems = {'parula'};
    end
    cmapDefault = 'parula';
    if ~any(strcmp(cmapItems, cmapDefault))
        cmapDefault = cmapItems{1};
    end
    cmapItems = [{'keep'}, cmapItems];

    secColors = uigridlayout(tabRootStyle, [2 1]);
    secColors.Layout.Row = 1;
    secColors.Layout.Column = 1;
    secColors.ColumnWidth = {'1x'};
    secColors.RowHeight = {'fit', 'fit'};
    secColors.Padding = [0 0 0 0];
    secColors.RowSpacing = 6;

    lblSecColors = uilabel(secColors, 'Text', 'Colors', 'HorizontalAlignment', 'left');
    lblSecColors.FontWeight = 'bold';
    lblSecColors.Layout.Row = 1;
    lblSecColors.Layout.Column = 1;

    secColorsBody = uigridlayout(secColors, [1 1]);
    secColorsBody.Layout.Row = 2;
    secColorsBody.Layout.Column = 1;
    secColorsBody.ColumnWidth = {'1x'};
    secColorsBody.RowHeight = {'fit'};
    secColorsBody.Padding = [0 0 0 0];
    secColorsBody.RowSpacing = 0;

    secAppA = uigridlayout(secColorsBody, [3 2]);
    secAppA.Layout.Row = 1;
    secAppA.Layout.Column = 1;
    secAppA.ColumnWidth = {170, '1x'};
    secAppA.RowHeight = {'fit', 'fit', 'fit'};
    secAppA.Padding = [0 0 0 0];

    lblAppColormap = uilabel(secAppA, 'Text', 'Colormap', 'HorizontalAlignment', 'left');
    lblAppColormap.Layout.Row = 1;
    lblAppColormap.Layout.Column = 1;
    ddCmap = uidropdown(secAppA, 'Items', cmapItems, 'Value', cmapDefault, ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    ddCmap.Layout.Row = 1;
    ddCmap.Layout.Column = 2;

    lblAppSpread = uilabel(secAppA, 'Text', 'Colormap spread', 'HorizontalAlignment', 'left');
    lblAppSpread.Layout.Row = 2;
    lblAppSpread.Layout.Column = 1;
    ddSpreadMode = uidropdown(secAppA, ...
        'Items', {'keep','ultra-narrow','ultra-narrow-rev','narrow','narrow-rev','medium','medium-rev', ...
                  'wide','wide-rev','ultra','ultra-rev','full','full-rev'}, ...
        'Value', 'medium', ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    ddSpreadMode.Layout.Row = 2;
    ddSpreadMode.Layout.Column = 2;

    cbSpreadReverse = uicheckbox(secAppA, 'Text', 'Reverse spread order', 'Value', false, ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    cbSpreadReverse.Layout.Row = 3;
    cbSpreadReverse.Layout.Column = [1 2];

    secBackground = uigridlayout(tabRootStyle, [2 1]);
    secBackground.Layout.Row = 2;
    secBackground.Layout.Column = 1;
    secBackground.ColumnWidth = {'1x'};
    secBackground.RowHeight = {'fit', 'fit'};
    secBackground.Padding = [0 0 0 0];
    secBackground.RowSpacing = 6;

    lblSecBackground = uilabel(secBackground, 'Text', 'Background', 'HorizontalAlignment', 'left');
    lblSecBackground.FontWeight = 'bold';
    lblSecBackground.Layout.Row = 1;
    lblSecBackground.Layout.Column = 1;

    secBackgroundBody = uigridlayout(secBackground, [2 1]);
    secBackgroundBody.Layout.Row = 2;
    secBackgroundBody.Layout.Column = 1;
    secBackgroundBody.ColumnWidth = {'1x'};
    secBackgroundBody.RowHeight = {'fit', 'fit'};
    secBackgroundBody.Padding = [0 0 0 0];
    secBackgroundBody.RowSpacing = 6;

    cbBgWhiteFigure = uicheckbox(secBackgroundBody, 'Text', 'Background white (figure)', 'Value', false, ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    cbBgWhiteFigure.Layout.Row = 1;
    cbBgWhiteFigure.Layout.Column = 1;

    cbBgTransparentAxes = uicheckbox(secBackgroundBody, 'Text', 'Transparent axes background', 'Value', false, ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    cbBgTransparentAxes.Layout.Row = 2;
    cbBgTransparentAxes.Layout.Column = 1;

    secLinesAxes = uigridlayout(tabRootStyle, [13 2]);
    secLinesAxes.Layout.Row = 3;
    secLinesAxes.Layout.Column = 1;
    secLinesAxes.ColumnWidth = {'1x','1x'};
    secLinesAxes.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
    secLinesAxes.Padding = [12 12 12 12];
    secLinesAxes.RowSpacing = 6;

    lblSecLinesAxes = uilabel(secLinesAxes, 'Text', 'Lines & References', 'HorizontalAlignment', 'left');
    lblSecLinesAxes.FontWeight = 'bold';
    lblSecLinesAxes.Layout.Row = 1;
    lblSecLinesAxes.Layout.Column = [1 2];

    lblDataLineStyle = uilabel(secLinesAxes, 'Text', 'Data line style', 'HorizontalAlignment', 'left');
    lblDataLineStyle.Layout.Row = 2;
    lblDataLineStyle.Layout.Column = 1;
    ddDataLineStyle = uidropdown(secLinesAxes, 'Items', {'(keep)','-','--',':','-.'}, 'Value', '(keep)', ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    ddDataLineStyle.Layout.Row = 2;
    ddDataLineStyle.Layout.Column = 2;

    lblDataLineWidth = uilabel(secLinesAxes, 'Text', 'Data line width', 'HorizontalAlignment', 'left');
    lblDataLineWidth.Layout.Row = 3;
    lblDataLineWidth.Layout.Column = 1;
    nfDataLineWidth = uieditfield(secLinesAxes, 'numeric', 'Value', 1.5, 'Limits', [0 Inf], ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    nfDataLineWidth.Layout.Row = 3;
    nfDataLineWidth.Layout.Column = 2;

    lblDataMarkerSize = uilabel(secLinesAxes, 'Text', 'Data marker size', 'HorizontalAlignment', 'left');
    lblDataMarkerSize.Layout.Row = 4;
    lblDataMarkerSize.Layout.Column = 1;
    nfDataMarkerSize = uieditfield(secLinesAxes, 'numeric', 'Value', 6, 'Limits', [0 Inf], ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    nfDataMarkerSize.Layout.Row = 4;
    nfDataMarkerSize.Layout.Column = 2;

    lblFitLineStyle = uilabel(secLinesAxes, 'Text', 'Fit line style', 'HorizontalAlignment', 'left');
    lblFitLineStyle.Layout.Row = 5;
    lblFitLineStyle.Layout.Column = 1;
    ddFitLineStyle = uidropdown(secLinesAxes, 'Items', {'(keep)','-','--',':','-.'}, 'Value', '(keep)', ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    ddFitLineStyle.Layout.Row = 5;
    ddFitLineStyle.Layout.Column = 2;

    lblFitLineWidth = uilabel(secLinesAxes, 'Text', 'Fit line width', 'HorizontalAlignment', 'left');
    lblFitLineWidth.Layout.Row = 6;
    lblFitLineWidth.Layout.Column = 1;
    nfFitLineWidth = uieditfield(secLinesAxes, 'numeric', 'Value', 1.5, 'Limits', [0 Inf], ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    nfFitLineWidth.Layout.Row = 6;
    nfFitLineWidth.Layout.Column = 2;

    lblFitMarkerSize = uilabel(secLinesAxes, 'Text', 'Fit marker size', 'HorizontalAlignment', 'left');
    lblFitMarkerSize.Layout.Row = 7;
    lblFitMarkerSize.Layout.Column = 1;
    nfFitMarkerSize = uieditfield(secLinesAxes, 'numeric', 'Value', 6, 'Limits', [0 Inf], ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    nfFitMarkerSize.Layout.Row = 7;
    nfFitMarkerSize.Layout.Column = 2;

    lblSecReferenceLines = uilabel(secLinesAxes, 'Text', 'Reference Lines', 'HorizontalAlignment', 'left');
    lblSecReferenceLines.FontWeight = 'bold';
    lblSecReferenceLines.Layout.Row = 8;
    lblSecReferenceLines.Layout.Column = [1 2];

    lblRefLineWidth = uilabel(secLinesAxes, 'Text', 'Line width', 'HorizontalAlignment', 'left');
    lblRefLineWidth.Layout.Row = 9;
    lblRefLineWidth.Layout.Column = 1;
    nfRefLineWidth = uieditfield(secLinesAxes, 'numeric', 'Value', 1.0, 'Limits', [0 Inf], ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    nfRefLineWidth.Layout.Row = 9;
    nfRefLineWidth.Layout.Column = 2;

    styleNumericImmediateFields = [nfDataLineWidth; nfDataMarkerSize; nfFitLineWidth; nfFitMarkerSize; nfRefLineWidth];
    for iStyleField = 1:numel(styleNumericImmediateFields)
        fld = styleNumericImmediateFields(iStyleField);
        if isprop(fld, 'Tag')
            fld.Tag = 'FCS_STYLE_NUMERIC_ENTER_APPLY';
        end
        if isprop(fld, 'KeyPressFcn')
            fld.KeyPressFcn = @onStyleNumericEnterKey;
        end
    end

    lblRefLineStyle = uilabel(secLinesAxes, 'Text', 'Line style', 'HorizontalAlignment', 'left');
    lblRefLineStyle.Layout.Row = 10;
    lblRefLineStyle.Layout.Column = 1;
    ddRefLineStyle = uidropdown(secLinesAxes, 'Items', {'-','--',':','-.'}, 'Value', '--', ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    ddRefLineStyle.Layout.Row = 10;
    ddRefLineStyle.Layout.Column = 2;

    lblRefLineColor = uilabel(secLinesAxes, 'Text', 'Color (RGB or keep)', 'HorizontalAlignment', 'left');
    lblRefLineColor.Layout.Row = 11;
    lblRefLineColor.Layout.Column = 1;
    efRefLineColor = uieditfield(secLinesAxes, 'text', 'Value', '(keep)', ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    efRefLineColor.Tooltip = 'RGB format: 0..1. Examples: [0.9 0.2 0.1] or 0.9 0.2 0.1 or 0.9,0.2,0.1. Use ''keep'' to leave unchanged.';
    efRefLineColor.Layout.Row = 11;
    efRefLineColor.Layout.Column = 2;

    lblPanelsPerRow = uilabel(secLinesAxes, 'Text', 'Panels per row:', 'HorizontalAlignment', 'left');
    lblPanelsPerRow.Layout.Row = 12;
    lblPanelsPerRow.Layout.Column = 1;
    ddPanelsPerRow = uidropdown(secLinesAxes, 'Items', {'1','2','3'}, 'Value', '2', ...
        'ValueChangedFcn', @onPersistedControlChanged);
    ddPanelsPerRow.Layout.Row = 12;
    ddPanelsPerRow.Layout.Column = 2;

    cbReversePlotOrder = uicheckbox(secLinesAxes, 'Text', 'Reverse plot order', 'Value', false, ...
        'ValueChangedFcn', @onAppearanceControlChanged);
    cbReversePlotOrder.Layout.Row = 13;
    cbReversePlotOrder.Layout.Column = [1 2];

    secFigureSize = uigridlayout(tabRootLayoutGeometry, [2 1]);
    secFigureSize.Layout.Row = 1;
    secFigureSize.Layout.Column = 1;
    secFigureSize.ColumnWidth = {'1x'};
    secFigureSize.RowHeight = {'fit', 'fit'};
    secFigureSize.Padding = [0 0 0 0];
    secFigureSize.RowSpacing = 6;

    lblSecFigureSize = uilabel(secFigureSize, 'Text', 'Figure Geometry', 'HorizontalAlignment', 'left');
    lblSecFigureSize.FontWeight = 'bold';
    lblSecFigureSize.Layout.Row = 1;
    lblSecFigureSize.Layout.Column = 1;

    secAppD = uigridlayout(secFigureSize, [4 2]);
    secAppD.Layout.Row = 2;
    secAppD.Layout.Column = 1;
    secAppD.ColumnWidth = {170, '1x'};
    secAppD.RowHeight = {'fit', 'fit', 'fit', 'fit'};
    secAppD.Padding = [0 0 0 0];

    lblWsWidth = uilabel(secAppD, 'Text', 'Target Width (cm)', 'HorizontalAlignment', 'left');
    lblWsWidth.Layout.Row = 1;
    lblWsWidth.Layout.Column = 1;
    nfWsWidth = uieditfield(secAppD, 'numeric', 'Value', 12, 'Limits', [5 40], ...
        'ValueChangedFcn', @onWorkspaceGeometryChanged);
    nfWsWidth.Layout.Row = 1;
    nfWsWidth.Layout.Column = 2;

    lblWsBaseRatio = uilabel(secAppD, 'Text', 'Base ratio (H/W)', 'HorizontalAlignment', 'left');
    lblWsBaseRatio.Layout.Row = 2;
    lblWsBaseRatio.Layout.Column = 1;
    nfWsBaseRatio = uieditfield(secAppD, 'numeric', 'Value', 0.75, 'Limits', [0.3 2], ...
        'ValueChangedFcn', @onWorkspaceGeometryChanged);
    nfWsBaseRatio.Layout.Row = 2;
    nfWsBaseRatio.Layout.Column = 2;

    lblWsHeight = uilabel(secAppD, 'Text', 'Height (computed cm)', 'HorizontalAlignment', 'left');
    lblWsHeight.Layout.Row = 3;
    lblWsHeight.Layout.Column = 1;
    lblWsHeightComputed = uilabel(secAppD, 'Text', '9.00', 'HorizontalAlignment', 'left');
    lblWsHeightComputed.Layout.Row = 3;
    lblWsHeightComputed.Layout.Column = 2;

    btnApplyWorkspaceSize = uibutton(secAppD, 'Text', 'Apply Size', 'ButtonPushedFcn', @onApplyWorkspaceSize);
    btnApplyWorkspaceSize.Layout.Row = 4;
    btnApplyWorkspaceSize.Layout.Column = [1 2];

    secEqualize = uigridlayout(tabRootLayoutGeometry, [2 1]);
    secEqualize.Layout.Row = 3;
    secEqualize.Layout.Column = 1;
    secEqualize.ColumnWidth = {'1x'};
    secEqualize.RowHeight = {'fit', 'fit'};
    secEqualize.Padding = [0 4 0 4];
    secEqualize.RowSpacing = 8;

    lblSecEqualize = uilabel(secEqualize, 'Text', 'Base Layout', 'HorizontalAlignment', 'left');
    lblSecEqualize.FontWeight = 'bold';
    lblSecEqualize.Layout.Row = 1;
    lblSecEqualize.Layout.Column = 1;

    btnEqualizeCenterAxesGroup = uibutton(secEqualize, ...
        'Text', 'Equalize & Center Axes Group (All Figures)', ...
        'ButtonPushedFcn', @onEqualizeCenterAxesGroup);
    btnEqualizeCenterAxesGroup.Layout.Row = 2;
    btnEqualizeCenterAxesGroup.Layout.Column = 1;

    secAxesTransform = uigridlayout(tabRootLayoutGeometry, [2 1]);
    secAxesTransform.Layout.Row = 5;
    secAxesTransform.Layout.Column = 1;
    secAxesTransform.ColumnWidth = {'1x'};
    secAxesTransform.RowHeight = {'fit', 'fit'};
    secAxesTransform.Padding = [0 0 0 0];
    secAxesTransform.RowSpacing = 6;

    lblSecAxesTransform = uilabel(secAxesTransform, 'Text', 'Transform', 'HorizontalAlignment', 'left');
    lblSecAxesTransform.FontWeight = 'bold';
    lblSecAxesTransform.Layout.Row = 1;
    lblSecAxesTransform.Layout.Column = 1;

    secAxesTransformBody = uigridlayout(secAxesTransform, [5 3]);
    secAxesTransformBody.Layout.Row = 2;
    secAxesTransformBody.Layout.Column = 1;
    secAxesTransformBody.ColumnWidth = {170, '1x', 60};
    secAxesTransformBody.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};
    secAxesTransformBody.Padding = [0 0 0 0];
    secAxesTransformBody.RowSpacing = 6;
    secAxesTransformBody.ColumnSpacing = 8;

    lblAxScaleX = uilabel(secAxesTransformBody, 'Text', 'Scale X', 'HorizontalAlignment', 'left');
    lblAxScaleX.Layout.Row = 1;
    lblAxScaleX.Layout.Column = 1;
    slAxScaleX = uislider(secAxesTransformBody, ...
        'Limits', [0.5 1.5], ...
        'Value', 1.0, ...
        'ValueChangingFcn', @onAxesTransformValueChanging, ...
        'ValueChangedFcn', @onAxesTransformChanged);
    slAxScaleX.Layout.Row = 1;
    slAxScaleX.Layout.Column = 2;
    lblAxScaleXValue = uilabel(secAxesTransformBody, 'Text', '1.00', 'HorizontalAlignment', 'right');
    lblAxScaleXValue.Layout.Row = 1;
    lblAxScaleXValue.Layout.Column = 3;

    lblAxScaleY = uilabel(secAxesTransformBody, 'Text', 'Scale Y', 'HorizontalAlignment', 'left');
    lblAxScaleY.Layout.Row = 2;
    lblAxScaleY.Layout.Column = 1;
    slAxScaleY = uislider(secAxesTransformBody, ...
        'Limits', [0.5 1.5], ...
        'Value', 1.0, ...
        'ValueChangingFcn', @onAxesTransformValueChanging, ...
        'ValueChangedFcn', @onAxesTransformChanged);
    slAxScaleY.Layout.Row = 2;
    slAxScaleY.Layout.Column = 2;
    lblAxScaleYValue = uilabel(secAxesTransformBody, 'Text', '1.00', 'HorizontalAlignment', 'right');
    lblAxScaleYValue.Layout.Row = 2;
    lblAxScaleYValue.Layout.Column = 3;

    lblAxOffsetX = uilabel(secAxesTransformBody, 'Text', 'Horizontal Offset', 'HorizontalAlignment', 'left');
    lblAxOffsetX.Layout.Row = 3;
    lblAxOffsetX.Layout.Column = 1;
    slAxOffsetX = uislider(secAxesTransformBody, ...
        'Limits', [-0.2 0.2], ...
        'Value', 0.0, ...
        'ValueChangingFcn', @onAxesTransformValueChanging, ...
        'ValueChangedFcn', @onAxesTransformChanged);
    slAxOffsetX.Layout.Row = 3;
    slAxOffsetX.Layout.Column = 2;
    lblAxOffsetXValue = uilabel(secAxesTransformBody, 'Text', '0.00', 'HorizontalAlignment', 'right');
    lblAxOffsetXValue.Layout.Row = 3;
    lblAxOffsetXValue.Layout.Column = 3;

    lblAxOffsetY = uilabel(secAxesTransformBody, 'Text', 'Vertical Offset', 'HorizontalAlignment', 'left');
    lblAxOffsetY.Layout.Row = 4;
    lblAxOffsetY.Layout.Column = 1;
    slAxOffsetY = uislider(secAxesTransformBody, ...
        'Limits', [-0.2 0.2], ...
        'Value', 0.0, ...
        'ValueChangingFcn', @onAxesTransformValueChanging, ...
        'ValueChangedFcn', @onAxesTransformChanged);
    slAxOffsetY.Layout.Row = 4;
    slAxOffsetY.Layout.Column = 2;
    lblAxOffsetYValue = uilabel(secAxesTransformBody, 'Text', '0.00', 'HorizontalAlignment', 'right');
    lblAxOffsetYValue.Layout.Row = 4;
    lblAxOffsetYValue.Layout.Column = 3;

    btnResetTransform = uibutton(secAxesTransformBody, 'Text', 'Reset Transform', 'ButtonPushedFcn', @onResetTransform);
    btnResetTransform.Layout.Row = 5;
    btnResetTransform.Layout.Column = [2 3];

    % ---------------- Export ----------------
    tabRootExport = uigridlayout(tExport, [5 1]);
    tabRootExport.ColumnWidth = {'1x'};
    tabRootExport.RowHeight = {'fit', 'fit', 'fit', '1x', 'fit'};
    tabRootExport.Padding = [12 12 12 12];

    secExportA = uigridlayout(tabRootExport, [8 2]);
    secExportA.Layout.Row = 1;
    secExportA.Layout.Column = 1;
    secExportA.ColumnWidth = {140, '1x'};
    secExportA.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
    secExportA.Padding = [0 0 0 0];

    lblExportFormat = uilabel(secExportA, 'Text', 'Format', 'HorizontalAlignment', 'left');
    lblExportFormat.Layout.Row = 1;
    lblExportFormat.Layout.Column = 1;
    ddExportFmt = uidropdown(secExportA, 'Items', {'pdf','png','fig'}, 'Value', 'pdf');
    ddExportFmt.Layout.Row = 1;
    ddExportFmt.Layout.Column = 2;

    lblExportJournal = uilabel(secExportA, 'Text', 'Journal', 'HorizontalAlignment', 'left');
    lblExportJournal.Layout.Row = 2;
    lblExportJournal.Layout.Column = 1;
    ddExportJournal = uidropdown(secExportA, 'Items', {'PRL','Nature'}, 'Value', 'PRL', ...
        'ValueChangedFcn', @onPersistedControlChanged);
    ddExportJournal.Layout.Row = 2;
    ddExportJournal.Layout.Column = 2;

    lblExportColumn = uilabel(secExportA, 'Text', 'Column', 'HorizontalAlignment', 'left');
    lblExportColumn.Layout.Row = 3;
    lblExportColumn.Layout.Column = 1;
    ddExportColumn = uidropdown(secExportA, 'Items', {'Single Column','Double Column'}, 'Value', 'Single Column', ...
        'ValueChangedFcn', @onPersistedControlChanged);
    ddExportColumn.Layout.Row = 3;
    ddExportColumn.Layout.Column = 2;

    cbVector = uicheckbox(secExportA, 'Text', 'Vector mode (PDF only)', 'Value', true);
    cbVector.Layout.Row = 4;
    cbVector.Layout.Column = [1 2];

    cbOverwrite = uicheckbox(secExportA, 'Text', 'Overwrite', 'Value', false);
    cbOverwrite.Layout.Row = 5;
    cbOverwrite.Layout.Column = [1 2];

    lblExportFilenameSource = uilabel(secExportA, 'Text', 'Filename source', 'HorizontalAlignment', 'left');
    lblExportFilenameSource.Layout.Row = 6;
    lblExportFilenameSource.Layout.Column = 1;
    ddFilenameFrom = uidropdown(secExportA, 'Items', {'Name','Number'}, 'Value', 'Name');
    ddFilenameFrom.Layout.Row = 6;
    ddFilenameFrom.Layout.Column = 2;

    cbExportComposedOnly = uicheckbox(secExportA, 'Text', 'Export composed file only', 'Value', false, ...
        'ValueChangedFcn', @onPersistedControlChanged);
    cbExportComposedOnly.Layout.Row = 7;
    cbExportComposedOnly.Layout.Column = [1 2];

    secExportB = uigridlayout(tabRootExport, [2 1]);
    secExportB.Layout.Row = 2;
    secExportB.Layout.Column = 1;
    secExportB.ColumnWidth = {'1x'};
    secExportB.RowHeight = {'fit', 'fit'};
    secExportB.Padding = [0 0 0 0];

    btnChooseFolder = uibutton(secExportB, 'Text', 'Choose Folder', 'ButtonPushedFcn', @onChooseFolder);
    btnChooseFolder.Layout.Row = 1;
    btnChooseFolder.Layout.Column = 1;

    efExportDir = uieditfield(secExportB, 'text', 'Value', pwd, ...
        'ValueChangedFcn', @onPersistedControlChanged);
    efExportDir.Layout.Row = 2;
    efExportDir.Layout.Column = 1;

    secExportC = uigridlayout(tabRootExport, [1 1]);
    secExportC.Layout.Row = 3;
    secExportC.Layout.Column = 1;
    secExportC.ColumnWidth = {'1x'};
    secExportC.RowHeight = {'fit'};
    secExportC.Padding = [0 0 0 0];

    exportActionBar = uigridlayout(tabRootExport, [1 1]);
    exportActionBar.Layout.Row = 5;
    exportActionBar.Layout.Column = 1;
    exportActionBar.ColumnWidth = {'1x'};
    exportActionBar.RowHeight = {'fit'};
    exportActionBar.Padding = [0 0 0 0];

    btnApplyExport = uibutton(exportActionBar, 'Text', 'Apply', 'ButtonPushedFcn', @onApplyExport);
    btnApplyExport.Layout.Row = 1;
    btnApplyExport.Layout.Column = 1;

    % ---------------- Compose ----------------
    tabRootCompose = uigridlayout(tCompose, [5 1]);
    tabRootCompose.ColumnWidth = {'1x'};
    tabRootCompose.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};
    tabRootCompose.Padding = [12 12 12 12];

    secComposeA = uigridlayout(tabRootCompose, [5 2]);
    secComposeA.Layout.Row = 1;
    secComposeA.Layout.Column = 1;
    secComposeA.ColumnWidth = {190, '1x'};
    secComposeA.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};
    secComposeA.Padding = [0 0 0 0];

    lblComposeRows = uilabel(secComposeA, 'Text', 'Rows', 'HorizontalAlignment', 'left');
    lblComposeRows.Layout.Row = 1;
    lblComposeRows.Layout.Column = 1;
    nfRows = uieditfield(secComposeA, 'numeric', 'Value', 2, 'Limits', [1 Inf], 'RoundFractionalValues', true, ...
        'ValueChangedFcn', @onPersistedControlChanged);
    nfRows.Layout.Row = 1;
    nfRows.Layout.Column = 2;

    lblComposeCols = uilabel(secComposeA, 'Text', 'Columns', 'HorizontalAlignment', 'left');
    lblComposeCols.Layout.Row = 2;
    lblComposeCols.Layout.Column = 1;
    nfCols = uieditfield(secComposeA, 'numeric', 'Value', 2, 'Limits', [1 Inf], 'RoundFractionalValues', true, ...
        'ValueChangedFcn', @onPersistedControlChanged);
    nfCols.Layout.Row = 2;
    nfCols.Layout.Column = 2;

    cbAutoLabel = uicheckbox(secComposeA, 'Text', 'Auto label panels', 'Value', true, ...
        'ValueChangedFcn', @onPersistedControlChanged);
    cbAutoLabel.Layout.Row = 3;
    cbAutoLabel.Layout.Column = [1 2];

    lblComposeLabelPos = uilabel(secComposeA, 'Text', 'Label position', 'HorizontalAlignment', 'left');
    lblComposeLabelPos.Layout.Row = 4;
    lblComposeLabelPos.Layout.Column = 1;
    ddLabelPos = uidropdown(secComposeA, 'Items', {'Top-left','Top-right'}, 'Value', 'Top-left', ...
        'ValueChangedFcn', @onPersistedControlChanged);
    ddLabelPos.Layout.Row = 4;
    ddLabelPos.Layout.Column = 2;

    lblComposeLabelFs = uilabel(secComposeA, 'Text', 'Label font size', 'HorizontalAlignment', 'left');
    lblComposeLabelFs.Layout.Row = 5;
    lblComposeLabelFs.Layout.Column = 1;
    nfLabelFont = uieditfield(secComposeA, 'numeric', 'Value', 11, 'Limits', [1 Inf], 'RoundFractionalValues', true, ...
        'ValueChangedFcn', @onPersistedControlChanged);
    nfLabelFont.Layout.Row = 5;
    nfLabelFont.Layout.Column = 2;

    secComposeB = uigridlayout(tabRootCompose, [4 2]);
    secComposeB.Layout.Row = 2;
    secComposeB.Layout.Column = 1;
    secComposeB.ColumnWidth = {190, '1x'};
    secComposeB.RowHeight = {'fit', 'fit', 'fit', 'fit'};
    secComposeB.Padding = [0 0 0 0];

    lblComposeWidthPreset = uilabel(secComposeB, 'Text', 'Manuscript width preset', 'HorizontalAlignment', 'left');
    lblComposeWidthPreset.Layout.Row = 1;
    lblComposeWidthPreset.Layout.Column = 1;
    ddWidthPreset = uidropdown(secComposeB, 'Items', {'Single column','Double column','Custom'}, 'Value', 'Single column', ...
        'ValueChangedFcn', @onWidthPresetChanged);
    ddWidthPreset.Layout.Row = 1;
    ddWidthPreset.Layout.Column = 2;

    lblComposeCustomWidth = uilabel(secComposeB, 'Text', 'Custom width (cm)', 'HorizontalAlignment', 'left');
    lblComposeCustomWidth.Layout.Row = 2;
    lblComposeCustomWidth.Layout.Column = 1;
    nfCustomWidth = uieditfield(secComposeB, 'numeric', 'Value', 12.0, 'Limits', [0.1 Inf], ...
        'ValueChangedFcn', @onPersistedControlChanged);
    nfCustomWidth.Layout.Row = 2;
    nfCustomWidth.Layout.Column = 2;

    lblComposeDensity = uilabel(secComposeB, 'Text', 'Layout density', 'HorizontalAlignment', 'left');
    lblComposeDensity.Layout.Row = 3;
    lblComposeDensity.Layout.Column = 1;
    ddLayoutDensity = uidropdown(secComposeB, 'Items', {'Tight','Normal','Spacious'}, 'Value', 'Normal', ...
        'ValueChangedFcn', @onPersistedControlChanged);
    ddLayoutDensity.Layout.Row = 3;
    ddLayoutDensity.Layout.Column = 2;

    lblComposeOverallSize = uilabel(secComposeB, 'Text', 'Overall size (%)', 'HorizontalAlignment', 'left');
    lblComposeOverallSize.Layout.Row = 4;
    lblComposeOverallSize.Layout.Column = 1;
    nfOverallSizePct = uieditfield(secComposeB, 'numeric', 'Value', 100, 'Limits', [80 130], ...
        'ValueChangedFcn', @onPersistedControlChanged);
    nfOverallSizePct.Layout.Row = 4;
    nfOverallSizePct.Layout.Column = 2;

    secComposeC = uigridlayout(tabRootCompose, [1 2]);
    secComposeC.Layout.Row = 3;
    secComposeC.Layout.Column = 1;
    secComposeC.ColumnWidth = {'1x', '1x'};
    secComposeC.RowHeight = {'fit'};
    secComposeC.Padding = [0 0 0 0];

    btnSaveLayout = uibutton(secComposeC, 'Text', 'Save Layout...', 'ButtonPushedFcn', @onSaveLayout);
    btnSaveLayout.Layout.Row = 1;
    btnSaveLayout.Layout.Column = 1;

    btnLoadLayout = uibutton(secComposeC, 'Text', 'Load Layout...', 'ButtonPushedFcn', @onLoadLayout);
    btnLoadLayout.Layout.Row = 1;
    btnLoadLayout.Layout.Column = 2;

    secComposeSpacing = uigridlayout(tabRootCompose, [2 1]);
    secComposeSpacing.Layout.Row = 4;
    secComposeSpacing.Layout.Column = 1;
    secComposeSpacing.ColumnWidth = {'1x'};
    secComposeSpacing.RowHeight = {'fit', 'fit'};
    secComposeSpacing.Padding = [0 0 0 0];
    secComposeSpacing.RowSpacing = 6;

    lblSecComposeSpacing = uilabel(secComposeSpacing, 'Text', 'Compose Layout Spacing', 'HorizontalAlignment', 'left');
    lblSecComposeSpacing.FontWeight = 'bold';
    lblSecComposeSpacing.Layout.Row = 1;
    lblSecComposeSpacing.Layout.Column = 1;

    secComposeSpacingBody = uigridlayout(secComposeSpacing, [2 3]);
    secComposeSpacingBody.Layout.Row = 2;
    secComposeSpacingBody.Layout.Column = 1;
    secComposeSpacingBody.ColumnWidth = {190, '1x', 60};
    secComposeSpacingBody.RowHeight = {'fit', 'fit'};
    secComposeSpacingBody.Padding = [0 0 0 0];
    secComposeSpacingBody.RowSpacing = 6;
    secComposeSpacingBody.ColumnSpacing = 8;

    lblComposeHGap = uilabel(secComposeSpacingBody, 'Text', 'Horizontal Gap', 'HorizontalAlignment', 'left');
    lblComposeHGap.Layout.Row = 1;
    lblComposeHGap.Layout.Column = 1;
    slComposeHGap = uislider(secComposeSpacingBody, ...
        'Limits', [0 0.1], ...
        'Value', 0.02, ...
        'ValueChangingFcn', @onComposeGapValueChanging, ...
        'ValueChangedFcn', @onComposeGapChanged);
    slComposeHGap.Layout.Row = 1;
    slComposeHGap.Layout.Column = 2;
    lblComposeHGapValue = uilabel(secComposeSpacingBody, 'Text', '0.020', 'HorizontalAlignment', 'right');
    lblComposeHGapValue.Layout.Row = 1;
    lblComposeHGapValue.Layout.Column = 3;

    lblComposeVGap = uilabel(secComposeSpacingBody, 'Text', 'Vertical Gap', 'HorizontalAlignment', 'left');
    lblComposeVGap.Layout.Row = 2;
    lblComposeVGap.Layout.Column = 1;
    slComposeVGap = uislider(secComposeSpacingBody, ...
        'Limits', [0 0.1], ...
        'Value', 0.02, ...
        'ValueChangingFcn', @onComposeGapValueChanging, ...
        'ValueChangedFcn', @onComposeGapChanged);
    slComposeVGap.Layout.Row = 2;
    slComposeVGap.Layout.Column = 2;
    lblComposeVGapValue = uilabel(secComposeSpacingBody, 'Text', '0.020', 'HorizontalAlignment', 'right');
    lblComposeVGapValue.Layout.Row = 2;
    lblComposeVGapValue.Layout.Column = 3;

    composeActionBar = uigridlayout(tabRootCompose, [1 1]);
    composeActionBar.Layout.Row = 5;
    composeActionBar.Layout.Column = 1;
    composeActionBar.ColumnWidth = {'1x'};
    composeActionBar.RowHeight = {'fit'};
    composeActionBar.Padding = [0 0 0 0];

    btnCompose = uibutton(composeActionBar, 'Text', 'Compose', 'ButtonPushedFcn', @onCompose);
    btnCompose.Layout.Row = 1;
    btnCompose.Layout.Column = 1;

    diagSink = uipanel(ui, 'Visible', 'off');
    taDiag = uitextarea(diagSink, 'Editable', 'off', 'Visible', 'off');
    taDiag.Value = {'Status ready.'};

    defaultUIState = struct( ...
        'scopeMode', "Explicit List", ...
        'excludeKnownGUIs', true, ...
        'gridRows', 2, ...
        'gridCols', 2, ...
        'widthPreset', "Single column", ...
        'customWidth', 12.0, ...
        'autoLabels', true, ...
        'labelPosition', "Top-left", ...
        'labelFontSize', 11, ...
        'composeHGap', 0.02, ...
        'composeVGap', 0.02, ...
        'legendPlacementMode', "Inside", ...
        'legendLocation', "best", ...
        'legendReverse', false, ...
        'legendAllowRebuild', false, ...
        'moveManualLegend', false, ...
        'manualLegendPositions', struct('figureKey', {}, 'position', {}), ...
        'appearanceMapName', string(cmapDefault), ...
        'appearanceSpreadMode', "medium", ...
        'appearanceSpreadReverse', false, ...
        'bgWhiteFigure', false, ...
        'bgTransparentAxes', false, ...
        'dataLineStyle', "(keep)", ...
        'dataLineWidth', 1.5, ...
        'dataMarkerSize', 6, ...
        'fitLineStyle', "(keep)", ...
        'fitLineWidth', 1.5, ...
        'fitMarkerSize', 6, ...
        'refLineWidth', 1.0, ...
        'refLineStyle', "--", ...
        'refLineColor', "(keep)", ...
        'annFontName', "Helvetica", ...
        'annFontSize', 11, ...
        'annFontWeight', "normal", ...
        'annInterpreter', "tex", ...
        'annColor', "[0 0 0]", ...
        'targetWidthCm', 12, ...
        'widthCm', 12, ...
        'baseRatio', 0.75, ...
        'axesTransformScaleX', 1.0, ...
        'axesTransformScaleY', 1.0, ...
        'axesTransformOffsetX', 0.0, ...
        'axesTransformOffsetY', 0.0, ...
        'reversePlotOrder', false, ...
        'panelsPerRow', "2", ...
        'exportComposedOnly', false, ...
        'exportJournal', "PRL", ...
        'exportColumn', "Single Column", ...
        'exportOutDir', string(pwd));
    suppressUIStateSave = false;
    isRestoringUIState = false;
    enableUIDiag = false;
    pendingRestore = struct('lbFigures', []);
    hasPendingRestore = false;
    legendLocationState = char(defaultUIState.legendLocation);
    axesBasePositions = containers.Map('KeyType', 'char', 'ValueType', 'any');
    manualLegendPositions = containers.Map('KeyType', 'char', 'ValueType', 'any');
    manualLegendDragState = struct('active', false, 'fig', gobjects(0,1), 'ax', gobjects(0,1), 'startPoint', [0 0], 'startPos', [0 0 1 1]);
    lastComposedFigure = gobjects(0,1);

    % ---------------- Initialize ----------------
    i_loadUIState();
    i_updateAxesTransformLabels();
    i_updateComposeGapLabels();
    i_updateWorkspaceHeightDisplay();
    onScopeModeChanged();
    onWidthPresetChanged();
    onLegendPlacementModeChanged();
    onRefreshExplicit();
    i_applyManualLegendDragModeToFigures(explicitHandleCache);

    % =========================================================
    % Nested callbacks and helpers
    % =========================================================

    function onScopeModeChanged(~, ~)
        mode = string(ddScope.Value);
        efTag.Enable = matlab.lang.OnOffSwitchState.off;
        efNameContains.Enable = matlab.lang.OnOffSwitchState.off;
        btnRefreshExplicit.Enable = matlab.lang.OnOffSwitchState.off;
        lbFigures.Enable = matlab.lang.OnOffSwitchState.off;
        btnMoveUp.Enable = matlab.lang.OnOffSwitchState.off;
        btnMoveDown.Enable = matlab.lang.OnOffSwitchState.off;

        switch mode
            case "By Tag"
                efTag.Enable = matlab.lang.OnOffSwitchState.on;
            case "By Name Contains"
                efNameContains.Enable = matlab.lang.OnOffSwitchState.on;
            case "Explicit List"
                btnRefreshExplicit.Enable = matlab.lang.OnOffSwitchState.on;
                lbFigures.Enable = matlab.lang.OnOffSwitchState.on;
                btnMoveUp.Enable = matlab.lang.OnOffSwitchState.on;
                btnMoveDown.Enable = matlab.lang.OnOffSwitchState.on;
        end
        i_saveUIState();
        i_debugUIStateDiff('after onScopeModeChanged');
    end

    function onExcludeChanged(~, ~)
        if string(ddScope.Value) == "Explicit List"
            onRefreshExplicit();
        end
        i_saveUIState();
    end

    function onToggleAdvanced(~, ~)
        isExpanded = strcmp(char(pAdvanced.Visible), 'on');
        if isExpanded
            pAdvanced.Visible = 'off';
            btnAdvancedToggle.Text = 'Advanced ▸';
        else
            pAdvanced.Visible = 'on';
            btnAdvancedToggle.Text = 'Advanced ▾';
        end
    end

    function onRefreshExplicit(~, ~)
        try
            % INCREMENTAL UPDATE LOGIC:
            % - Use existing list order as base reference
            % - Remove entries for closed figures (preserving order of remaining)
            % - Append newly opened figures at END only
            % - Do NOT sort, do NOT rebuild from scratch
            % - Preserve selection if figure still exists

            % Step 1: Capture currently selected figure handles (not indices)
            selectedFigHandles = gobjects(0,1);
            try
                sel = lbFigures.Value;
                sel = double(sel(:));
                sel = sel(sel >= 1 & sel <= numel(explicitHandleCache));
                if ~isempty(sel)
                    selectedFigHandles = explicitHandleCache(sel);
                    selectedFigHandles = selectedFigHandles(isgraphics(selectedFigHandles, 'figure'));
                end
            catch
            end

            % Step 2: Get all currently open figures (for comparison only)
            tmpSpec = struct('mode', 'allOpen', 'excludeKnownGUIs', cbExcludeGUIs.Value);
            allOpenFigs = FCS_resolveTargets(tmpSpec);
            allOpenFigs = allOpenFigs(isgraphics(allOpenFigs, 'figure'));
            allOpenFigs(allOpenFigs == ui) = [];

            % Step 3: Remove closed figures while preserving order of existing entries
            % This is a minimal diff operation - only removes invalids, no reordering
            stillValid = isgraphics(explicitHandleCache, 'figure');
            explicitHandleCache = explicitHandleCache(stillValid);

            % Step 4: Find new figures not currently in the list
            % We check against existing list to identify additions only
            newFigs = gobjects(0,1);
            for k = 1:numel(allOpenFigs)
                fig = allOpenFigs(k);
                if ~any(explicitHandleCache == fig)
                    newFigs(end+1,1) = fig; %#ok<AGROW>
                end
            end

            % Step 5: Append new figures at the END (no reordering of existing)
            if ~isempty(newFigs)
                explicitHandleCache = [explicitHandleCache; newFigs];
            end

            i_captureAxesBasePositionsIfMissing(explicitHandleCache);

            % Step 6: Restore selection based on figure handles (not auto-change)
            % Selected figures that still exist will remain selected at their new indices
            selectedIndices = [];
            for k = 1:numel(selectedFigHandles)
                idx = find(explicitHandleCache == selectedFigHandles(k), 1);
                if ~isempty(idx)
                    selectedIndices(end+1) = idx; %#ok<AGROW>
                end
            end
            if isempty(selectedIndices)
                selectedIndices = [];
            end

            refreshExplicitListbox(selectedIndices);
            i_applyPendingRestoreAfterPopulation();
            i_applyManualLegendDragModeToFigures(explicitHandleCache);
            i_debugUIStateDiff('after onRefreshExplicit');

        catch ME
            uialert(ui, ME.message, 'Refresh Failed');
        end
    end

    function i_applyPendingRestoreAfterPopulation()
        if ~hasPendingRestore
            return;
        end
        if ~isstruct(pendingRestore) || ~isfield(pendingRestore, 'lbFigures') || isempty(pendingRestore.lbFigures)
            i_clearPendingRestore();
            return;
        end

        oldSuppressUIStateSave = suppressUIStateSave;
        oldIsRestoringUIState = isRestoringUIState;
        suppressUIStateSave = true;
        isRestoringUIState = true;
        restoreGuard = onCleanup(@() i_restoreUIStateFlags(oldSuppressUIStateSave, oldIsRestoringUIState)); %#ok<NASGU>

        savedValue = pendingRestore.lbFigures;
        if i_tryAssignListboxValue(lbFigures, savedValue, 'lbFigures')
            i_clearPendingRestore();
        end
    end

    function i_clearPendingRestore()
        pendingRestore = struct('lbFigures', []);
        hasPendingRestore = false;
    end

    function i_restoreUIStateFlags(oldSuppressValue, oldRestoringValue)
        suppressUIStateSave = oldSuppressValue;
        isRestoringUIState = oldRestoringValue;
    end

    function refreshExplicitListbox(selectedIdx)
        if isempty(explicitHandleCache)
            lbFigures.Items = {};
            lbFigures.ItemsData = [];
            lbFigures.Value = {};
            lblDetected.Text = 'Detected: 0';
            return;
        end

        n = numel(explicitHandleCache);
        labels = strings(n,1);
        ids = (1:n)';
        for k = 1:n
            f = explicitHandleCache(k);
            % Some figures have empty Number -> string([]) returns 0x0, causing assignment mismatch.
            numTxt = "UI";
            nameTxt = "";
            try
                if isprop(f, 'Number')
                    nVal = f.Number;
                    if isnumeric(nVal) && isscalar(nVal) && ~isempty(nVal)
                        numTxt = string(nVal);
                    end
                end
            catch
            end
            try
                if isprop(f, 'Name')
                    nName = string(f.Name);
                    if ~isempty(nName)
                        nameTxt = nName(1);
                    end
                end
            catch
            end
            if strlength(strtrim(nameTxt)) == 0
                nameTxt = '(unnamed)';
            end
            labels(k) = "#" + numTxt + " | " + nameTxt;
        end

        lbFigures.Items = cellstr(labels);
        lbFigures.ItemsData = ids;

        if nargin < 1 || isempty(selectedIdx)
            lbFigures.Value = ids;
        else
            selectedIdx = double(selectedIdx(:));
            selectedIdx = selectedIdx(selectedIdx >= 1 & selectedIdx <= n);
            selectedIdx = unique(selectedIdx, 'stable');
            if isempty(selectedIdx)
                lbFigures.Value = ids;
            else
                lbFigures.Value = selectedIdx;
            end
        end

        lblDetected.Text = sprintf('Detected: %d', n);
    end

    function onMoveUp(~, ~)
        if string(ddScope.Value) ~= "Explicit List"
            return;
        end
        if isempty(explicitHandleCache) || numel(explicitHandleCache) < 2
            return;
        end

        sel = lbFigures.Value;
        if isempty(sel)
            return;
        end
        sel = unique(double(sel(:))', 'stable');
        if any(sel == 1)
            return;
        end

        for idx = sel
            tmp = explicitHandleCache(idx-1);
            explicitHandleCache(idx-1) = explicitHandleCache(idx);
            explicitHandleCache(idx) = tmp;
        end
        refreshExplicitListbox(sel - 1);
    end

    function onMoveDown(~, ~)
        if string(ddScope.Value) ~= "Explicit List"
            return;
        end
        if isempty(explicitHandleCache) || numel(explicitHandleCache) < 2
            return;
        end

        sel = lbFigures.Value;
        if isempty(sel)
            return;
        end
        sel = unique(double(sel(:))', 'stable');
        n = numel(explicitHandleCache);
        if any(sel == n)
            return;
        end

        for idx = fliplr(sel)
            tmp = explicitHandleCache(idx+1);
            explicitHandleCache(idx+1) = explicitHandleCache(idx);
            explicitHandleCache(idx) = tmp;
        end
        refreshExplicitListbox(sel + 1);
    end

    function onWidthPresetChanged(~, ~)
        if string(ddWidthPreset.Value) == "Custom"
            nfCustomWidth.Enable = matlab.lang.OnOffSwitchState.on;
        else
            nfCustomWidth.Enable = matlab.lang.OnOffSwitchState.off;
        end
        i_saveUIState();
    end

    function onLegendPlacementModeChanged(~, ~)
        i_updateLegendArrowAvailability();
        i_saveUIState();

        figs = i_getExplicitListTargetsNoAlert();
        if isempty(figs)
            return;
        end
        i_applyLegendLocationExistingOnly(figs, legendLocationState);
    end

    function onPersistedControlChanged(~, ~)
        i_saveUIState();
    end

    function onTypographyControlChanged(~, ~)
        i_saveUIState();
        onApplyTypography([], []);
    end

    function onAppearanceControlChanged(~, ~)
        i_saveUIState();
        onApplyAppearance([], []);
    end

    function onStyleNumericEnterKey(src, evt)
        % Some uifigure runtime states may not dispatch ValueChanged on the
        % first Enter; this Enter-only hook safely reuses the normal apply path.
        keyName = "";
        if nargin >= 2 && isstruct(evt) && isfield(evt, 'Key')
            keyName = lower(string(evt.Key));
        end

        try
            fprintf('[FCS-KEY][Field] key=%s src=%s tag=%s\n', char(keyName), class(src), string(src.Tag));
        catch
            try
                fprintf('[FCS-KEY][Field] key=%s src=%s\n', char(keyName), class(src));
            catch
            end
        end

        if ~(keyName == "return" || keyName == "enter")
            return;
        end

        if isempty(src) || ~isgraphics(src)
            return;
        end

        isStyleNumericField = ...
            isequal(src, nfDataLineWidth) || ...
            isequal(src, nfDataMarkerSize) || ...
            isequal(src, nfFitLineWidth) || ...
            isequal(src, nfFitMarkerSize) || ...
            isequal(src, nfRefLineWidth);
        if ~isStyleNumericField
            return;
        end

        try
            src.Value = double(src.Value);
        catch
        end

        onAppearanceControlChanged([], []);
    end

    function onWindowKeyPressDiagnostic(src, evt)
        keyName = "";
        if nargin >= 2 && isstruct(evt) && isfield(evt, 'Key')
            keyName = lower(string(evt.Key));
        end

        focusedClass = "";
        focusedTag = "";
        try
            focusedObj = [];
            if isprop(src, 'CurrentObject')
                focusedObj = src.CurrentObject;
            end
            if ~isempty(focusedObj) && isgraphics(focusedObj)
                focusedClass = string(class(focusedObj));
                if isprop(focusedObj, 'Tag')
                    focusedTag = string(focusedObj.Tag);
                end
            end
        catch
        end

        try
            fprintf('[FCS-KEY][Window] key=%s focusedClass=%s focusedTag=%s\n', char(keyName), char(focusedClass), char(focusedTag));
        catch
            try
                fprintf('[FCS-KEY][Window] key=%s\n', char(keyName));
            catch
            end
        end
    end

    function onAxesTransformValueChanging(src, evt)
        if nargin >= 2 && isstruct(evt) && isfield(evt, 'Value')
            if isequal(src, slAxScaleX)
                src.Value = i_quantizeSliderValue(double(evt.Value), [0.5 1.5], 0.01);
            elseif isequal(src, slAxScaleY)
                src.Value = i_quantizeSliderValue(double(evt.Value), [0.5 1.5], 0.01);
            elseif isequal(src, slAxOffsetX)
                src.Value = i_quantizeSliderValue(double(evt.Value), [-0.2 0.2], 0.01);
            elseif isequal(src, slAxOffsetY)
                src.Value = i_quantizeSliderValue(double(evt.Value), [-0.2 0.2], 0.01);
            end
        end
        i_updateAxesTransformLabels();
    end

    function onAxesTransformChanged(src, ~)
        if isequal(src, slAxScaleX)
            src.Value = i_quantizeSliderValue(double(src.Value), [0.5 1.5], 0.01);
        elseif isequal(src, slAxScaleY)
            src.Value = i_quantizeSliderValue(double(src.Value), [0.5 1.5], 0.01);
        elseif isequal(src, slAxOffsetX)
            src.Value = i_quantizeSliderValue(double(src.Value), [-0.2 0.2], 0.01);
        elseif isequal(src, slAxOffsetY)
            src.Value = i_quantizeSliderValue(double(src.Value), [-0.2 0.2], 0.01);
        end
        i_updateAxesTransformLabels();
        i_saveUIState();

        figs = resolveTargetsOrAlert("Layout");
        if isempty(figs)
            return;
        end
        for k = 1:numel(figs)
            fig = figs(k);
            if isgraphics(fig, 'figure')
                i_applyManualAxesTransform(fig);
            end
        end
    end

    function onResetTransform(~, ~)
        figs = resolveTargetsOrAlert("Layout");
        if isempty(figs)
            return;
        end

        i_resetManualTransformToIdentityAndApply(figs);
    end

    function i_resetManualTransformToIdentityAndApply(figs)
        slAxScaleX.Value = 1.0;
        slAxScaleY.Value = 1.0;
        slAxOffsetX.Value = 0.0;
        slAxOffsetY.Value = 0.0;
        i_updateAxesTransformLabels();
        i_saveUIState();

        if isempty(figs)
            return;
        end

        for k = 1:numel(figs)
            fig = figs(k);
            if isgraphics(fig, 'figure')
                i_applyManualAxesTransform(fig);
            end
        end
    end

    function i_updateAxesTransformLabels()
        lblAxScaleXValue.Text = sprintf('%.2f', double(slAxScaleX.Value));
        lblAxScaleYValue.Text = sprintf('%.2f', double(slAxScaleY.Value));
        lblAxOffsetXValue.Text = sprintf('%.2f', double(slAxOffsetX.Value));
        lblAxOffsetYValue.Text = sprintf('%.2f', double(slAxOffsetY.Value));
    end

    function onComposeGapValueChanging(src, evt)
        if nargin >= 2 && isstruct(evt) && isfield(evt, 'Value')
            if isequal(src, slComposeHGap)
                src.Value = i_quantizeSliderValue(double(evt.Value), [0 0.1], 0.001);
            elseif isequal(src, slComposeVGap)
                src.Value = i_quantizeSliderValue(double(evt.Value), [0 0.1], 0.001);
            end
        end
        i_updateComposeGapLabels();
    end

    function onComposeGapChanged(src, ~)
        if isequal(src, slComposeHGap)
            src.Value = i_quantizeSliderValue(double(src.Value), [0 0.1], 0.001);
        elseif isequal(src, slComposeVGap)
            src.Value = i_quantizeSliderValue(double(src.Value), [0 0.1], 0.001);
        end
        i_updateComposeGapLabels();
        i_saveUIState();
    end

    function i_updateComposeGapLabels()
        lblComposeHGapValue.Text = sprintf('%.3f', double(slComposeHGap.Value));
        lblComposeVGapValue.Text = sprintf('%.3f', double(slComposeVGap.Value));
    end

    function v = i_quantizeSliderValue(v, lims, step)
        v = round(v / step) * step;
        v = min(max(v, lims(1)), lims(2));
    end

    function onWorkspaceGeometryChanged(~, ~)
        i_updateWorkspaceHeightDisplay();
        i_saveUIState();
    end

    function i_updateWorkspaceHeightDisplay()
        heightCm = i_computeWorkspaceHeightCm();
        if ~isfinite(heightCm) || heightCm <= 0
            lblWsHeightComputed.Text = '--';
            return;
        end
        lblWsHeightComputed.Text = sprintf('%.2f', heightCm);
    end

    function heightCm = i_computeWorkspaceHeightCm()
        heightCm = NaN;
        widthCm = double(nfWsWidth.Value);
        baseRatioHW = double(nfWsBaseRatio.Value);
        if ~isfinite(widthCm) || widthCm <= 0 || ~isfinite(baseRatioHW) || baseRatioHW <= 0
            return;
        end
        heightCm = widthCm * baseRatioHW;
    end

    function onBackgroundToggleChanged(~, ~)
        % Deferred execution model:
        % Background toggles only update stored state.
        % Actual application occurs when user clicks the main Apply button.
        i_saveUIState();
    end

    function i_applyManualLegendDragModeToFigures(figs)
        dragEnabled = false;
        if isempty(figs)
            return;
        end

        for k = 1:numel(figs)
            fig = figs(k);
            if ~isgraphics(fig, 'figure')
                continue;
            end

            axList = findall(fig, 'Type', 'axes');
            for a = 1:numel(axList)
                ax = axList(a);
                if ~isgraphics(ax, 'axes') || ~i_isManualLegendAxes(ax)
                    continue;
                end

                try
                    ax.Units = 'normalized';
                catch
                end

                i_applySavedManualLegendPosition(ax);
                i_configureManualLegendAxesInteractivity(ax, dragEnabled);
            end
        end

        if ~dragEnabled
            i_stopManualLegendDrag();
        end
    end

    function i_applySavedManualLegendPosition(ax)
        if isempty(ax) || ~isgraphics(ax, 'axes')
            return;
        end

        fig = ancestor(ax, 'figure');
        if isempty(fig) || ~isgraphics(fig, 'figure')
            return;
        end

        key = i_manualLegendFigureKey(fig);
        key = char(key);
        if ~isKey(manualLegendPositions, key)
            return;
        end

        pos = manualLegendPositions(key);
        if ~isnumeric(pos) || numel(pos) < 4 || any(~isfinite(pos(1:4)))
            return;
        end

        try
            ax.Units = 'normalized';
            ax.Position = i_clampAxesPositionIfNeeded(double(pos(1:4)));
        catch
        end
    end

    function i_configureManualLegendAxesInteractivity(ax, dragEnabled)
        if isempty(ax) || ~isgraphics(ax, 'axes')
            return;
        end

        if dragEnabled
            try, ax.PickableParts = 'all'; catch, end
            try, ax.HitTest = 'on'; catch, end
            try, ax.ButtonDownFcn = @onManualLegendAxesButtonDown; catch, end
        else
            try, ax.ButtonDownFcn = []; catch, end
            try, ax.PickableParts = 'none'; catch, end
            try, ax.HitTest = 'off'; catch, end
        end

        kids = allchild(ax);
        for iKid = 1:numel(kids)
            h = kids(iKid);
            if ~isgraphics(h)
                continue;
            end
            try, h.PickableParts = 'none'; catch, end
            try, h.HitTest = 'off'; catch, end
        end
    end

    function onManualLegendAxesButtonDown(src, ~)
        if ~isgraphics(src, 'axes')
            return;
        end

        fig = ancestor(src, 'figure');
        if isempty(fig) || ~isgraphics(fig, 'figure')
            return;
        end

        try
            src.Units = 'normalized';
            startPos = double(src.Position);
        catch
            return;
        end

        manualLegendDragState.active = true;
        manualLegendDragState.fig = fig;
        manualLegendDragState.ax = src;
        manualLegendDragState.startPoint = i_getFigurePointerNormalized(fig);
        manualLegendDragState.startPos = startPos;

        try
            fig.WindowButtonMotionFcn = @onManualLegendDragMotion;
            fig.WindowButtonUpFcn = @onManualLegendDragStop;
        catch
            i_stopManualLegendDrag();
        end
    end

    function onManualLegendDragMotion(~, ~)
        if ~manualLegendDragState.active
            return;
        end

        ax = manualLegendDragState.ax;
        fig = manualLegendDragState.fig;
        if ~isgraphics(fig, 'figure') || ~isgraphics(ax, 'axes')
            i_stopManualLegendDrag();
            return;
        end

        pNow = i_getFigurePointerNormalized(fig);
        delta = pNow - manualLegendDragState.startPoint;
        newPos = manualLegendDragState.startPos;
        newPos(1:2) = newPos(1:2) + delta;
        newPos = i_clampAxesPositionIfNeeded(newPos);

        try
            ax.Units = 'normalized';
            ax.Position = newPos;
        catch
            i_stopManualLegendDrag();
        end
    end

    function onManualLegendDragStop(~, ~)
        if manualLegendDragState.active && isgraphics(manualLegendDragState.ax, 'axes')
            ax = manualLegendDragState.ax;
            fig = ancestor(ax, 'figure');
            if ~isempty(fig) && isgraphics(fig, 'figure')
                try
                    ax.Units = 'normalized';
                    pos = double(ax.Position);
                    manualLegendPositions(char(i_manualLegendFigureKey(fig))) = pos;
                catch
                end
            end
        end

        i_stopManualLegendDrag();
        i_saveUIState();
    end

    function i_stopManualLegendDrag()
        if manualLegendDragState.active && isgraphics(manualLegendDragState.fig, 'figure')
            try, manualLegendDragState.fig.WindowButtonMotionFcn = []; catch, end
            try, manualLegendDragState.fig.WindowButtonUpFcn = []; catch, end
        end
        manualLegendDragState = struct('active', false, 'fig', gobjects(0,1), 'ax', gobjects(0,1), 'startPoint', [0 0], 'startPos', [0 0 1 1]);
    end

    function pNorm = i_getFigurePointerNormalized(fig)
        pNorm = [0 0];
        if isempty(fig) || ~isgraphics(fig, 'figure')
            return;
        end
        try
            oldUnits = fig.Units;
            fig.Units = 'pixels';
            figPos = fig.Position;
            cp = fig.CurrentPoint;
            fig.Units = oldUnits;
            if numel(figPos) >= 4 && figPos(3) > 0 && figPos(4) > 0
                pNorm = [cp(1) / figPos(3), cp(2) / figPos(4)];
            end
        catch
            pNorm = [0 0];
        end
    end

    function key = i_manualLegendFigureKey(fig)
        key = "";
        if isempty(fig) || ~isgraphics(fig, 'figure')
            return;
        end
        numTxt = "?";
        nameTxt = "";
        try, numTxt = string(fig.Number); catch, end
        try, nameTxt = strtrim(string(fig.Name)); catch, end
        key = "fig:" + numTxt + "|" + lower(nameTxt);
    end

    function i_restoreManualLegendPositionState(savedState)
        manualLegendPositions = containers.Map('KeyType', 'char', 'ValueType', 'any');
        if ~isstruct(savedState) || isempty(savedState)
            return;
        end

        for i = 1:numel(savedState)
            if ~isfield(savedState, 'figureKey') || ~isfield(savedState, 'position')
                continue;
            end
            key = string(savedState(i).figureKey);
            pos = savedState(i).position;
            if strlength(strtrim(key)) == 0
                continue;
            end
            if ~isnumeric(pos) || numel(pos) < 4 || any(~isfinite(pos(1:4)))
                continue;
            end
            manualLegendPositions(char(key)) = double(pos(1:4));
        end
    end

    function out = i_serializeManualLegendPositionState()
        out = struct('figureKey', {}, 'position', {});
        if isempty(manualLegendPositions)
            return;
        end

        keys = manualLegendPositions.keys;
        if isempty(keys)
            return;
        end

        out = repmat(struct('figureKey', '', 'position', [0 0 1 1]), numel(keys), 1);
        idx = 0;
        for i = 1:numel(keys)
            key = keys{i};
            pos = manualLegendPositions(key);
            if ~isnumeric(pos) || numel(pos) < 4 || any(~isfinite(pos(1:4)))
                continue;
            end
            idx = idx + 1;
            out(idx).figureKey = key;
            out(idx).position = double(pos(1:4));
        end
        out = out(1:idx);
    end

    function onResetDefaults(~, ~)
        suppressUIStateSave = true;
        ddScope.Value = char(defaultUIState.scopeMode);
        cbExcludeGUIs.Value = logical(defaultUIState.excludeKnownGUIs);
        nfRows.Value = double(defaultUIState.gridRows);
        nfCols.Value = double(defaultUIState.gridCols);
        ddWidthPreset.Value = char(defaultUIState.widthPreset);
        nfCustomWidth.Value = double(defaultUIState.customWidth);
        cbAutoLabel.Value = logical(defaultUIState.autoLabels);
        ddLabelPos.Value = char(defaultUIState.labelPosition);
        nfLabelFont.Value = double(defaultUIState.labelFontSize);
        slComposeHGap.Value = double(defaultUIState.composeHGap);
        slComposeVGap.Value = double(defaultUIState.composeVGap);
        i_updateComposeGapLabels();
        ddLegendPlacementMode.Value = char(defaultUIState.legendPlacementMode);
        legendLocationState = char(defaultUIState.legendLocation);
        manualLegendPositions = containers.Map('KeyType', 'char', 'ValueType', 'any');
        ddCmap.Value = char(defaultUIState.appearanceMapName);
        ddSpreadMode.Value = char(defaultUIState.appearanceSpreadMode);
        cbSpreadReverse.Value = logical(defaultUIState.appearanceSpreadReverse);
        cbBgWhiteFigure.Value = logical(defaultUIState.bgWhiteFigure);
        cbBgTransparentAxes.Value = logical(defaultUIState.bgTransparentAxes);
        ddDataLineStyle.Value = char(defaultUIState.dataLineStyle);
        nfDataLineWidth.Value = double(defaultUIState.dataLineWidth);
        nfDataMarkerSize.Value = double(defaultUIState.dataMarkerSize);
        ddFitLineStyle.Value = char(defaultUIState.fitLineStyle);
        nfFitLineWidth.Value = double(defaultUIState.fitLineWidth);
        nfFitMarkerSize.Value = double(defaultUIState.fitMarkerSize);
        nfRefLineWidth.Value = double(defaultUIState.refLineWidth);
        ddRefLineStyle.Value = char(defaultUIState.refLineStyle);
        efRefLineColor.Value = char(defaultUIState.refLineColor);
        efAnnFontName.Value = char(defaultUIState.annFontName);
        nfAnnFontSize.Value = double(defaultUIState.annFontSize);
        ddAnnFontWeight.Value = char(defaultUIState.annFontWeight);
        ddAnnInterpreter.Value = char(defaultUIState.annInterpreter);
        efAnnColor.Value = char(defaultUIState.annColor);
        nfWsWidth.Value = double(defaultUIState.targetWidthCm);
        nfWsBaseRatio.Value = double(defaultUIState.baseRatio);
        i_updateWorkspaceHeightDisplay();
        cbReversePlotOrder.Value = logical(defaultUIState.reversePlotOrder);
        slAxScaleX.Value = double(defaultUIState.axesTransformScaleX);
        slAxScaleY.Value = double(defaultUIState.axesTransformScaleY);
        slAxOffsetX.Value = double(defaultUIState.axesTransformOffsetX);
        slAxOffsetY.Value = double(defaultUIState.axesTransformOffsetY);
        i_updateAxesTransformLabels();
        ddPanelsPerRow.Value = char(defaultUIState.panelsPerRow);
        cbExportComposedOnly.Value = logical(defaultUIState.exportComposedOnly);
        ddExportJournal.Value = char(defaultUIState.exportJournal);
        ddExportColumn.Value = char(defaultUIState.exportColumn);
        efExportDir.Value = char(defaultUIState.exportOutDir);

        onScopeModeChanged();
        onWidthPresetChanged();
        onLegendPlacementModeChanged();
        onRefreshExplicit();
        i_applyManualLegendDragModeToFigures(explicitHandleCache);
        suppressUIStateSave = false;
        i_saveUIState();
    end

    function scopeSpec = buildScopeSpecFromUI()
        mode = string(ddScope.Value);

        switch mode
            case "Current Figure"
                scopeSpec = struct('mode', 'current');

            case "All Open Figures"
                scopeSpec = struct('mode', 'allOpen');

            case "By Tag"
                scopeSpec = struct('mode', 'byTag', 'tag', string(efTag.Value));

            case "By Name Contains"
                scopeSpec = struct('mode', 'byNameContains', 'nameContains', string(efNameContains.Value));

            case "Explicit List"
                selected = lbFigures.Value;
                if isempty(selected)
                    selectedHandles = gobjects(0,1);
                else
                    selected = double(selected(:));
                    selected = selected(selected >= 1 & selected <= numel(explicitHandleCache));
                    selected = unique(selected, 'stable');
                    selectedHandles = explicitHandleCache(selected);
                end
                scopeSpec = struct('mode', 'explicitList', 'explicitList', selectedHandles);

            otherwise
                scopeSpec = struct('mode', 'current');
        end

        scopeSpec.excludeKnownGUIs = logical(cbExcludeGUIs.Value);
    end

    function figs = resolveTargetsOrAlert(actionName)
        if nargin < 1 || strlength(string(actionName)) == 0
            actionName = "Targets";
        end
        scopeSpec = buildScopeSpecFromUI();
        figs = FCS_resolveTargets(scopeSpec);
        figs = figs(isgraphics(figs, 'figure'));
        figs(figs == ui) = [];

        if isempty(figs)
            uialert(ui, 'No target figures found for the selected scope.', char(actionName));
            return;
        end

        valid = false(size(figs));
        for k = 1:numel(figs)
            try
                valid(k) = isvalid(figs(k)) && isgraphics(figs(k), 'figure');
            catch
                valid(k) = false;
            end
        end
        figs = figs(valid);

        if isempty(figs)
            uialert(ui, 'Resolved targets are not valid figure handles.', char(actionName));
        end
    end

    function figs = resolveExplicitListTargetsOrAlert(actionName)
        if string(ddScope.Value) ~= "Explicit List"
            uialert(ui, actionName + " is available only in Explicit List scope mode.", actionName);
            figs = gobjects(0,1);
            return;
        end

        selected = lbFigures.Value;
        if isempty(selected)
            uialert(ui, 'Select at least one figure from the explicit list.', actionName);
            figs = gobjects(0,1);
            return;
        end

        selected = double(selected(:));
        selected = selected(selected >= 1 & selected <= numel(explicitHandleCache));
        selected = unique(selected, 'stable');
        figs = explicitHandleCache(selected);
        figs = figs(isgraphics(figs, 'figure'));

        if isempty(figs)
            uialert(ui, 'Selected explicit-list figures are not valid.', actionName);
        end
    end

    function [overrideFontSize, hasOverride, errMsg] = i_parseLegendOverrideFontSize()
        overrideFontSize = NaN;
        hasOverride = false;
        errMsg = "";

        raw = string(efLegendFontSize.Value);
        raw = strtrim(raw);
        if strlength(raw) == 0
            return;
        end

        val = str2double(raw);
        if ~isfinite(val) || val <= 0
            errMsg = "Legend Font Size override must be empty or a positive number.";
            return;
        end

        overrideFontSize = double(val);
        hasOverride = true;
    end

    function [effectiveLegendFontSize, ok] = i_resolveEffectiveLegendFontSize(baseFontSize)
        effectiveLegendFontSize = NaN;
        ok = false;

        [overrideFontSize, hasOverride, errMsg] = i_parseLegendOverrideFontSize();
        if strlength(errMsg) > 0
            uialert(ui, char(errMsg), 'Legend');
            return;
        end

        if hasOverride
            effectiveLegendFontSize = overrideFontSize;
        else
            effectiveLegendFontSize = baseFontSize;
        end
        ok = true;
    end

    function i_applyLegendFontSize(figs, legendFontSize)
        if ~isfinite(legendFontSize) || legendFontSize <= 0
            return;
        end

        for k = 1:numel(figs)
            try
                lgds = findall(figs(k), 'Type', 'legend');
                for j = 1:numel(lgds)
                    if isprop(lgds(j), 'FontSize')
                        lgds(j).FontSize = legendFontSize;
                    end
                end
            catch
            end
        end
    end

    function i_applyLegendLocationExistingOnly(figs, locationString)
        for k = 1:numel(figs)
            try
                lgds = findall(figs(k), 'Type', 'legend');
                if isempty(lgds)
                    continue;
                end

                for j = 1:numel(lgds)
                    lg = lgds(j);
                    if isprop(lg, 'Location')
                        lg.Location = locationString;
                    end
                end
            catch
                continue;
            end
        end
    end

    function i_updateLegendArrowAvailability()
        isOutside = string(ddLegendPlacementMode.Value) == "Outside";
        if isOutside
            disabled = matlab.lang.OnOffSwitchState.off;
            enabled = matlab.lang.OnOffSwitchState.on;

            btnLegendNW.Enable = disabled;
            btnLegendNE.Enable = disabled;
            btnLegendSW.Enable = disabled;
            btnLegendSE.Enable = disabled;
            btnLegendC.Enable = disabled;

            btnLegendN.Enable = enabled;
            btnLegendS.Enable = enabled;
            btnLegendW.Enable = enabled;
            btnLegendE.Enable = enabled;
        else
            enabled = matlab.lang.OnOffSwitchState.on;
            btnLegendNW.Enable = enabled;
            btnLegendN.Enable = enabled;
            btnLegendNE.Enable = enabled;
            btnLegendW.Enable = enabled;
            btnLegendC.Enable = enabled;
            btnLegendE.Enable = enabled;
            btnLegendSW.Enable = enabled;
            btnLegendS.Enable = enabled;
            btnLegendSE.Enable = enabled;
        end
    end

    function [locationString, ok] = i_resolveLegendLocationFromArrow(arrowToken)
        ok = true;
        mode = string(ddLegendPlacementMode.Value);
        key = upper(string(arrowToken));

        if mode == "Outside"
            switch key
                case "N"
                    locationString = 'northoutside';
                case "S"
                    locationString = 'southoutside';
                case "W"
                    locationString = 'westoutside';
                case "E"
                    locationString = 'eastoutside';
                otherwise
                    locationString = '';
                    ok = false;
            end
            return;
        end

        switch key
            case "NW"
                locationString = 'northwest';
            case "N"
                locationString = 'north';
            case "NE"
                locationString = 'northeast';
            case "W"
                locationString = 'west';
            case "C"
                locationString = 'best';
            case "E"
                locationString = 'east';
            case "SW"
                locationString = 'southwest';
            case "S"
                locationString = 'south';
            case "SE"
                locationString = 'southeast';
            otherwise
                locationString = '';
                ok = false;
        end
    end

    function i_applyLegendSettingsExistingOnly(figs, locationValue)
        i_applyLegendLocationExistingOnly(figs, locationValue);
    end

    function i_applyLegendReverseExistingOnly(figs, allowRebuild, preferredLocation)
        for k = 1:numel(figs)
            fig = figs(k);
            if ~isgraphics(fig, 'figure')
                continue;
            end

            axList = findall(fig, 'Type', 'axes');
            for a = 1:numel(axList)
                ax = axList(a);
                if ~isgraphics(ax, 'axes') || ~i_isPrimaryPlotAxes(ax)
                    continue;
                end

                lgd = i_findLegendForAxes(fig, ax);
                if isempty(lgd) || ~isgraphics(lgd, 'legend')
                    continue;
                end

                reversedInPlace = i_tryReverseLegendInPlace(lgd);
                if reversedInPlace || ~allowRebuild
                    continue;
                end

                i_rebuildLegendForAxis(ax, lgd, preferredLocation);
            end
        end
    end

    function lgd = i_findLegendForAxes(fig, ax)
        lgd = [];
        allLegends = findall(fig, 'Type', 'legend');
        if isempty(allLegends)
            return;
        end

        for i = 1:numel(allLegends)
            L = allLegends(i);
            try
                if isprop(L, 'Axes') && ~isempty(L.Axes) && L.Axes == ax
                    lgd = L;
                    return;
                end
            catch
            end

            try
                if isprop(L, 'PlotChildren')
                    pc = L.PlotChildren;
                    for p = 1:numel(pc)
                        hostAx = ancestor(pc(p), 'axes');
                        if ~isempty(hostAx) && hostAx == ax
                            lgd = L;
                            return;
                        end
                    end
                end
            catch
            end
        end
    end

    function ok = i_tryReverseLegendInPlace(lgd)
        ok = false;

        if ~(isprop(lgd, 'PlotChildren') && isprop(lgd, 'String'))
            return;
        end

        try
            pc = lgd.PlotChildren;
            labels = lgd.String;
            if ischar(labels)
                labels = {labels};
            elseif isstring(labels)
                labels = cellstr(labels(:));
            end

            % Pairing guard: reverse only when handles and labels are 1:1.
            if numel(pc) > 1 && numel(labels) == numel(pc)
                lgd.PlotChildren = flipud(pc);
                lgd.String = flipud(labels(:));
                ok = true;
            end
        catch
        end
        % Limitation: some MATLAB versions do not expose a safe writable in-place order API.
    end

    function i_rebuildLegendForAxis(ax, lgdOld, preferredLocation)
        if isempty(lgdOld) || ~isgraphics(lgdOld, 'legend') || isempty(ax) || ~isgraphics(ax, 'axes')
            return;
        end

        [dataLines, dataNames] = i_collectDataLinesWithNames(ax);
        if isempty(dataLines)
            return;
        end

        dataLines = flipud(dataLines(:));
        dataNames = flipud(dataNames(:));

        oldProps = struct();
        try, oldProps.Location = lgdOld.Location; catch, end
        try, oldProps.Position = lgdOld.Position; catch, end
        try, oldProps.Orientation = lgdOld.Orientation; catch, end
        try, oldProps.Box = lgdOld.Box; catch, end
        try, oldProps.NumColumns = lgdOld.NumColumns; catch, end
        try, oldProps.FontSize = lgdOld.FontSize; catch, end
        try, oldProps.Interpreter = lgdOld.Interpreter; catch, end
        try, oldProps.AutoUpdate = lgdOld.AutoUpdate; catch, end
        try, oldProps.Color = lgdOld.Color; catch, end
        try, oldProps.EdgeColor = lgdOld.EdgeColor; catch, end

        delete(lgdOld);
        newLeg = legend(ax, dataLines, dataNames);
        if isempty(newLeg) || ~isgraphics(newLeg, 'legend')
            return;
        end

        if isprop(newLeg, 'AutoUpdate')
            newLeg.AutoUpdate = 'off';
        end

        if isprop(newLeg, 'Location') && ~isempty(preferredLocation)
            try
                newLeg.Location = preferredLocation;
            catch
                if isfield(oldProps, 'Location')
                    try, newLeg.Location = oldProps.Location; catch, end
                end
            end
        end

        if isfield(oldProps, 'Position') && isprop(newLeg, 'Position')
            try, newLeg.Position = oldProps.Position; catch, end
        end
        if isfield(oldProps, 'Orientation') && isprop(newLeg, 'Orientation')
            try, newLeg.Orientation = oldProps.Orientation; catch, end
        end
        if isfield(oldProps, 'Box') && isprop(newLeg, 'Box')
            try, newLeg.Box = oldProps.Box; catch, end
        end
        if isfield(oldProps, 'NumColumns') && isprop(newLeg, 'NumColumns')
            try, newLeg.NumColumns = oldProps.NumColumns; catch, end
        end
        if isfield(oldProps, 'FontSize') && isprop(newLeg, 'FontSize')
            try, newLeg.FontSize = oldProps.FontSize; catch, end
        end
        if isfield(oldProps, 'Interpreter') && isprop(newLeg, 'Interpreter')
            try, newLeg.Interpreter = oldProps.Interpreter; catch, end
        end
        if isfield(oldProps, 'AutoUpdate') && isprop(newLeg, 'AutoUpdate')
            try, newLeg.AutoUpdate = oldProps.AutoUpdate; catch, end
        end
        if isfield(oldProps, 'Color') && isprop(newLeg, 'Color')
            try, newLeg.Color = oldProps.Color; catch, end
        end
        if isfield(oldProps, 'EdgeColor') && isprop(newLeg, 'EdgeColor')
            try, newLeg.EdgeColor = oldProps.EdgeColor; catch, end
        end
    end

    function [dataLines, dataNames] = i_collectDataLinesWithNames(ax)
        dataLines = gobjects(0,1);
        dataNames = strings(0,1);

        if isempty(ax) || ~isgraphics(ax, 'axes')
            return;
        end

        allLines = findall(ax, 'Type', 'line');
        if isempty(allLines)
            return;
        end

        names = get(allLines, 'DisplayName');
        if ischar(names)
            names = {names};
        elseif isstring(names)
            names = cellstr(names(:));
        end

        keep = false(numel(allLines), 1);
        outNames = strings(numel(allLines), 1);
        for i = 1:numel(allLines)
            nm = strtrim(string(names{i}));
            keep(i) = strlength(nm) > 0;
            outNames(i) = nm;
        end

        dataLines = allLines(keep);
        dataNames = outNames(keep);
    end

    function stats = i_applyAppearanceSettings(figs, opts)
        stats = struct('figuresTouched', 0, 'axesTouched', 0, 'linesTouched', 0, 'colorbarsTouched', 0);

        mapNameKey = lower(strtrim(char(string(opts.mapName))));
        spreadModeKey = lower(strtrim(char(string(opts.spreadMode))));
        applyColormap = ~strcmp(mapNameKey, 'keep');
        reverseSpread = endsWith(spreadModeKey, '-rev');
        spreadModeBase = spreadModeKey;
        if reverseSpread
            spreadModeBase = extractBefore(string(spreadModeKey), strlength(string(spreadModeKey)) - 3);
            spreadModeBase = lower(strtrim(char(spreadModeBase)));
        end

        cmapSlice = [];
        if applyColormap
            cmapFull = i_getColormapByName(opts.mapName);
            if strcmp(spreadModeBase, 'keep')
                cmapSlice = cmapFull;
            else
                M = size(cmapFull, 1);
                idx = i_getSliceIndices(M, spreadModeBase);
                cmapSlice = cmapFull(idx, :);
            end
            if reverseSpread
                cmapSlice = flipud(cmapSlice);
            end
        end

        for k = 1:numel(figs)
            fig = figs(k);
            if ~isgraphics(fig, 'figure')
                continue;
            end

            stats.figuresTouched = stats.figuresTouched + 1;
            if isfield(opts, 'figureColor') && ~isempty(opts.figureColor) && isprop(fig, 'Color')
                try
                    fig.Color = opts.figureColor;
                catch
                end
            end
            i_applyBackgroundAppearance(fig, opts);

            axList = findall(fig, 'Type', 'axes');
            for a = 1:numel(axList)
                ax = axList(a);
                if ~isgraphics(ax, 'axes')
                    continue;
                end

                stats.axesTouched = stats.axesTouched + 1;
                isPrimaryAxes = i_isPrimaryPlotAxes(ax);
                
                % Style settings (optional):
                % When invoked from style apply callback, opts contains
                % additional fields for font sizes and axis appearance.
                if isPrimaryAxes && isfield(opts, 'axesFont') && isfinite(opts.axesFont) && opts.axesFont > 0
                    if isprop(ax, 'FontSize')
                        ax.FontSize = opts.axesFont;
                    end
                end
                
                if isPrimaryAxes && isfield(opts, 'tickDir') && ~isempty(opts.tickDir)
                    if isprop(ax, 'TickDir')
                        ax.TickDir = char(opts.tickDir);
                    end
                end
                
                if isPrimaryAxes && isfield(opts, 'box') && ~isempty(opts.box)
                    if isprop(ax, 'Box')
                        ax.Box = char(opts.box);
                    end
                end
                
                if isPrimaryAxes && isfield(opts, 'axesLineWidth') && isfinite(opts.axesLineWidth) && opts.axesLineWidth > 0
                    if isprop(ax, 'LineWidth')
                        ax.LineWidth = opts.axesLineWidth;
                    end
                end

                if isPrimaryAxes && isfield(opts, 'layer') && ~isempty(opts.layer)
                    if isprop(ax, 'Layer')
                        ax.Layer = char(opts.layer);
                    end
                end

                if isPrimaryAxes && isfield(opts, 'tickLength') && isnumeric(opts.tickLength) && numel(opts.tickLength) >= 2
                    if isprop(ax, 'TickLength')
                        try
                            ax.TickLength = double(opts.tickLength(1:2));
                        catch
                        end
                    end
                end

                if isPrimaryAxes && isfield(opts, 'xMinorTick') && ~isempty(opts.xMinorTick)
                    if isprop(ax, 'XMinorTick')
                        ax.XMinorTick = char(opts.xMinorTick);
                    end
                end

                if isPrimaryAxes && isfield(opts, 'yMinorTick') && ~isempty(opts.yMinorTick)
                    if isprop(ax, 'YMinorTick')
                        ax.YMinorTick = char(opts.yMinorTick);
                    end
                end

                if isPrimaryAxes && isfield(opts, 'axesColor') && ~isempty(opts.axesColor)
                    if isprop(ax, 'Color')
                        try
                            ax.Color = opts.axesColor;
                        catch
                        end
                    end
                end
                
                if isPrimaryAxes && isfield(opts, 'labelFont') && isfinite(opts.labelFont) && opts.labelFont > 0
                    if isprop(ax, 'XLabel')
                        xl = ax.XLabel;
                        if ~isempty(xl) && isgraphics(xl) && isprop(xl, 'FontSize')
                            xl.FontSize = opts.labelFont;
                        end
                    end
                    if isprop(ax, 'YLabel')
                        yl = ax.YLabel;
                        if ~isempty(yl) && isgraphics(yl) && isprop(yl, 'FontSize')
                            yl.FontSize = opts.labelFont;
                        end
                    end
                    if isprop(ax, 'Title')
                        ttl = ax.Title;
                        if ~isempty(ttl) && isgraphics(ttl) && isprop(ttl, 'FontSize')
                            ttl.FontSize = opts.labelFont;
                        end
                    end
                end
                
                if applyColormap
                    colormap(ax, cmapSlice);

                    cbList = i_getColorbarsForAxes(fig, ax);
                    for c = 1:numel(cbList)
                        cb = cbList(c);
                        if isgraphics(cb, 'colorbar')
                            colormap(cb, flipud(cmapSlice));
                            stats.colorbarsTouched = stats.colorbarsTouched + 1;
                        end
                    end
                end

                [dataLines, fitLines] = i_getDataAndFitLines(ax);
                stats.linesTouched = stats.linesTouched + numel(dataLines) + numel(fitLines);

                if isfield(opts, 'reversePlotOrder') && logical(opts.reversePlotOrder) && ~isempty(dataLines)
                    i_reverseDataLinesZOrder(ax, dataLines);
                end

                % Legacy reverse-spread behavior when keeping existing colormap:
                % reverse current data-line colors in deterministic dataLines order.
                if ~applyColormap && reverseSpread && ~isempty(dataLines)
                    validIdx = false(numel(dataLines), 1);
                    colors = cell(numel(dataLines), 1);
                    for iLine = 1:numel(dataLines)
                        ln = dataLines(iLine);
                        if isgraphics(ln, 'line') && isprop(ln, 'Color')
                            try
                                colors{iLine} = ln.Color;
                                validIdx(iLine) = true;
                            catch
                                validIdx(iLine) = false;
                            end
                        end
                    end

                    idxValid = find(validIdx);
                    if numel(idxValid) > 1
                        reversedColors = flipud(colors(idxValid));
                        for iLine = 1:numel(idxValid)
                            ln = dataLines(idxValid(iLine));
                            if isgraphics(ln, 'line') && isprop(ln, 'Color')
                                try
                                    ln.Color = reversedColors{iLine};
                                catch
                                end
                            end
                        end
                    end
                end

                % CtrlGUI-compatible colormap-to-data-lines behavior:
                % Recolor only data lines (non-empty DisplayName) from the
                % currently applied colormap slice using evenly spaced samples.
                if ~isempty(cmapSlice) && ~isempty(dataLines)
                    nC = size(cmapSlice, 1);
                    idxData = round(linspace(1, nC, numel(dataLines)));
                    for iLine = 1:numel(dataLines)
                        ln = dataLines(iLine);
                        if isgraphics(ln, 'line') && isprop(ln, 'Color')
                            ln.Color = cmapSlice(idxData(iLine), :);
                        end
                    end
                end

                i_applyLineStyleBundle(dataLines, opts.dataLineStyle, opts.dataLineWidth, opts.dataMarkerSize);
                i_applyLineStyleBundle(fitLines, opts.fitLineStyle, opts.fitLineWidth, opts.fitMarkerSize);

                refObjs = i_getReferenceObjects(ax, dataLines, fitLines);
                i_applyReferenceStyle(refObjs, opts);

                annTextObjs = i_getAnnotationTextObjects(ax);
                i_applyAnnotationTextStyle(annTextObjs, opts);
            end
        end
    end

    function i_applyBackgroundAppearance(target, opts)
        if isempty(target)
            return;
        end

        if isscalar(target) && isgraphics(target, 'figure')
            fig = target;
            if isfield(opts, 'bgWhiteFigure') && logical(opts.bgWhiteFigure) && isprop(fig, 'Color')
                fig.Color = [1 1 1];
            end

            if isfield(opts, 'bgTransparentAxes') && logical(opts.bgTransparentAxes)
                axList = findall(fig, 'Type', 'axes');
                for a = 1:numel(axList)
                    ax = axList(a);
                    if isgraphics(ax, 'axes') && isprop(ax, 'Color')
                        try
                            ax.Color = 'none';
                        catch
                        end
                    end
                end
            end
            return;
        end

        if isgraphics(target)
            figs = target(isgraphics(target, 'figure'));
            for i = 1:numel(figs)
                i_applyBackgroundAppearance(figs(i), opts);
            end
        end
    end

    function [dataLines, fitLines] = i_getDataAndFitLines(ax)
        dataLines = gobjects(0,1);
        fitLines = gobjects(0,1);

        % Use findobj ordering consistently for deterministic line traversal.
        allLines = findobj(ax, 'Type', 'line');
        keep = false(numel(allLines), 1);
        for i = 1:numel(allLines)
            ln = allLines(i);
            if ~isgraphics(ln, 'line')
                continue;
            end

            isVisible = true;
            if isprop(ln, 'Visible')
                try
                    isVisible = strcmpi(char(string(ln.Visible)), 'on');
                catch
                    isVisible = false;
                end
            end

            isHandleVisible = true;
            if isprop(ln, 'HandleVisibility')
                try
                    isHandleVisible = strcmpi(char(string(ln.HandleVisibility)), 'on');
                catch
                    isHandleVisible = false;
                end
            end

            keep(i) = isVisible && isHandleVisible;
        end
        allLines = allLines(keep);
        if isempty(allLines)
            return;
        end

        names = get(allLines, 'DisplayName');
        if ischar(names)
            names = {names};
        elseif isstring(names)
            names = cellstr(names(:));
        end

        % Legacy-compatible deterministic heuristic:
        % data lines => non-empty DisplayName, fit lines => empty DisplayName.
        isData = false(numel(allLines), 1);
        for i = 1:numel(allLines)
            isData(i) = strlength(strtrim(string(names{i}))) > 0;
        end

        dataLines = allLines(isData);
        fitLines = allLines(~isData);
    end

    function i_applyLineStyleBundle(lines, styleValue, lineWidth, markerSize)
        if isempty(lines)
            return;
        end

        applyStyle = ~(strcmp(string(styleValue), "(keep)") || strlength(strtrim(string(styleValue))) == 0);
        applyWidth = isfinite(lineWidth) && lineWidth >= 0;
        applyMarker = isfinite(markerSize) && markerSize >= 0;

        for i = 1:numel(lines)
            ln = lines(i);
            if ~isgraphics(ln, 'line')
                continue;
            end
            if applyStyle && isprop(ln, 'LineStyle')
                ln.LineStyle = char(styleValue);
            end
            if applyWidth && isprop(ln, 'LineWidth')
                ln.LineWidth = lineWidth;
            end
            if applyMarker && isprop(ln, 'MarkerSize')
                ln.MarkerSize = markerSize;
            end
        end
    end

    function refObjs = i_getReferenceObjects(ax, dataLines, fitLines)
        refObjs = gobjects(0,1);
        if isempty(ax) || ~isgraphics(ax, 'axes')
            return;
        end

        try
            ch = allchild(ax);
        catch
            ch = gobjects(0,1);
        end

        constantLines = gobjects(0,1);
        for i = 1:numel(ch)
            h = ch(i);
            try
                if isa(h, 'matlab.graphics.chart.decoration.ConstantLine')
                    constantLines(end+1,1) = h; %#ok<AGROW>
                end
            catch
            end
        end

        lineRefs = gobjects(0,1);
        try
            allLines = findall(ax, 'Type', 'line');
        catch
            allLines = gobjects(0,1);
        end

        excluded = [dataLines(:); fitLines(:)];
        for i = 1:numel(allLines)
            ln = allLines(i);
            if ~isgraphics(ln, 'line')
                continue;
            end
            if any(ln == excluded)
                continue;
            end
            lineRefs(end+1,1) = ln; %#ok<AGROW>
        end

        refObjs = [constantLines; lineRefs];
        if isempty(refObjs)
            return;
        end
        try
            refObjs = unique(refObjs, 'stable');
        catch
        end
    end

    function i_applyReferenceStyle(refObjs, opts)
        if isempty(refObjs)
            return;
        end

        refWidth = NaN;
        if isfield(opts, 'refLineWidth') && isfinite(opts.refLineWidth) && opts.refLineWidth >= 0
            refWidth = opts.refLineWidth;
        end

        refStyle = "";
        if isfield(opts, 'refLineStyle') && strlength(strtrim(string(opts.refLineStyle))) > 0
            refStyle = string(opts.refLineStyle);
        end

        [refColor, applyRefColor] = i_parseColorSpec(opts.refLineColor, true);

        for i = 1:numel(refObjs)
            obj = refObjs(i);
            if ~isgraphics(obj)
                continue;
            end
            try
                if isfinite(refWidth) && isprop(obj, 'LineWidth')
                    obj.LineWidth = refWidth;
                end
                if strlength(refStyle) > 0 && isprop(obj, 'LineStyle')
                    obj.LineStyle = char(refStyle);
                end
                if applyRefColor && isprop(obj, 'Color')
                    obj.Color = refColor;
                end
            catch
            end
        end
    end

    function annTextObjs = i_getAnnotationTextObjects(ax)
        annTextObjs = gobjects(0,1);
        if isempty(ax) || ~isgraphics(ax, 'axes')
            return;
        end

        try
            tx = findall(ax, 'Type', 'text');
        catch
            tx = gobjects(0,1);
        end
        if isempty(tx)
            return;
        end

        excluded = gobjects(0,1);
        try, excluded(end+1,1) = ax.Title; catch, end %#ok<AGROW>
        try, excluded(end+1,1) = ax.XLabel; catch, end %#ok<AGROW>
        try, excluded(end+1,1) = ax.YLabel; catch, end %#ok<AGROW>

        keep = false(numel(tx), 1);
        for i = 1:numel(tx)
            t = tx(i);
            if ~isgraphics(t, 'text')
                continue;
            end
            if any(t == excluded)
                continue;
            end
            lg = [];
            try
                lg = ancestor(t, 'legend');
            catch
            end
            if ~isempty(lg)
                continue;
            end
            keep(i) = true;
        end

        annTextObjs = tx(keep);
    end

    function i_applyAnnotationTextStyle(annTextObjs, opts)
        if isempty(annTextObjs)
            return;
        end

        fontName = "Helvetica";
        if isfield(opts, 'annFontName') && strlength(strtrim(string(opts.annFontName))) > 0
            fontName = string(opts.annFontName);
        end

        fontSize = NaN;
        if isfield(opts, 'annFontSize') && isfinite(opts.annFontSize) && opts.annFontSize > 0
            fontSize = opts.annFontSize;
        end

        fontWeight = "normal";
        if isfield(opts, 'annFontWeight') && strlength(strtrim(string(opts.annFontWeight))) > 0
            fontWeight = lower(strtrim(string(opts.annFontWeight)));
        end

        interpreter = "tex";
        if isfield(opts, 'annInterpreter') && strlength(strtrim(string(opts.annInterpreter))) > 0
            interpreter = lower(strtrim(string(opts.annInterpreter)));
        end

        [annColor, hasAnnColor] = i_parseColorSpec(opts.annColor, false);
        if ~hasAnnColor
            annColor = [0 0 0];
        end

        for i = 1:numel(annTextObjs)
            obj = annTextObjs(i);
            if ~isgraphics(obj, 'text')
                continue;
            end
            try
                if isprop(obj, 'FontName')
                    obj.FontName = char(fontName);
                end
                if isfinite(fontSize) && isprop(obj, 'FontSize')
                    obj.FontSize = fontSize;
                end
                if isprop(obj, 'FontWeight')
                    obj.FontWeight = char(fontWeight);
                end
                if isprop(obj, 'Interpreter')
                    obj.Interpreter = char(interpreter);
                end
                if isprop(obj, 'Color')
                    obj.Color = annColor;
                end
            catch
            end
        end
    end

    function [rgb, hasColor] = i_parseColorSpec(rawValue, allowKeep)
        rgb = [0 0 0];
        hasColor = false;

        s = strtrim(char(string(rawValue)));
        if allowKeep && (isempty(s) || strcmpi(s, '(keep)') || strcmpi(s, 'keep'))
            return;
        end

        s = strrep(s, '[', '');
        s = strrep(s, ']', '');
        vals = sscanf(s, '%f');
        if numel(vals) == 3 && all(isfinite(vals)) && all(vals >= 0) && all(vals <= 1)
            rgb = vals(:)';
            hasColor = true;
        end
    end

    function i_reverseDataLinesZOrder(ax, dataLines)
        if isempty(ax) || ~isgraphics(ax, 'axes') || isempty(dataLines)
            return;
        end

        dataLines = dataLines(isgraphics(dataLines, 'line'));
        if isempty(dataLines)
            return;
        end

        try
            ch = ax.Children;
        catch
            return;
        end

        if isempty(ch)
            return;
        end

        isDataChild = false(numel(ch), 1);
        for i = 1:numel(ch)
            h = ch(i);
            if isgraphics(h, 'line') && any(h == dataLines)
                isDataChild(i) = true;
            end
        end

        if nnz(isDataChild) < 2
            return;
        end

        dataChildren = ch(isDataChild);
        ch(isDataChild) = flipud(dataChildren);

        try
            ax.Children = ch;
        catch
        end
    end

    function cbList = i_getColorbarsForAxes(fig, ax)
        cbList = gobjects(0,1);
        allCb = findall(fig, 'Type', 'colorbar');
        if isempty(allCb)
            return;
        end

        keep = false(numel(allCb), 1);
        for i = 1:numel(allCb)
            cb = allCb(i);
            try
                keep(i) = isprop(cb, 'Axes') && ~isempty(cb.Axes) && cb.Axes == ax;
            catch
                keep(i) = false;
            end
        end
        cbList = allCb(keep);
    end

    function cmap = i_getColormapByName(mapName)
        persistent cmapCache
        if isempty(cmapCache)
            cmapCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        mapNameChar = char(string(mapName));
        key = lower(strtrim(mapNameChar));
        if isKey(cmapCache, key)
            cmap = cmapCache(key);
            return;
        end

        builtinNames = {'parula','turbo','jet','hsv','hot','cool','spring','summer','autumn','winter','gray','bone','copper','pink','lines','colorcube','prism','flag'};
        customNames = i_getCustomColormapNames();

        if any(strcmpi(key, builtinNames))
            cmap = feval(key, 256);
        elseif any(strcmpi(key, customNames))
            cmap = i_makeCustomColormap(key);
        elseif startsWith(key, 'cmocean:')
            cmapName = extractAfter(string(key), "cmocean:");
            try
                cmap = cmocean(char(cmapName), 256);
            catch
                cmap = cmocean(char(cmapName));
            end
        else
            scm8Maps = i_discoverScm8Colormaps();
            scm8Lower = lower(string(scm8Maps));
            hit = find(strcmp(key, scm8Lower), 1, 'first');
            if ~isempty(hit)
                cmap = feval(scm8Maps{hit}, 256);
            elseif exist(mapNameChar, 'file') == 2 || exist(mapNameChar, 'builtin') == 5
                cmap = feval(mapNameChar, 256);
            else
                error('Unknown colormap "%s".', key);
            end
        end

        i_validateColormapMatrix(cmap, key);
        cmapCache(key) = cmap;
    end

    function i_validateColormapMatrix(cmap, cmapName)
        if isempty(cmap) || ~isnumeric(cmap) || ~ismatrix(cmap) || size(cmap,2) ~= 3
            error('Colormap "%s" must be Nx3 numeric.', cmapName);
        end
        if any(~isfinite(cmap(:)))
            error('Colormap "%s" contains non-finite values.', cmapName);
        end
        if any(cmap(:) < 0) || any(cmap(:) > 1)
            error('Colormap "%s" must have values in [0,1].', cmapName);
        end
    end

    function idx = i_getSliceIndices(M, mode)
        if M < 2
            M = 2;
        end

        modeKey = lower(strtrim(char(string(mode))));
        mid = round(M/2);
        spanUltraNarrow = ceil(0.20 * M);
        spanNarrow = ceil(0.30 * M);
        spanMedium = ceil(0.35 * M);
        spanWide = ceil(0.40 * M);
        spanUltra = ceil(0.45 * M);

        switch modeKey
            case 'full'
                idx = 1:M;
            case 'full-rev'
                idx = M:-1:1;
            case {'ultra-narrow','ultra-narrow-rev'}
                [lo, hi] = i_centerSliceBounds(M, mid, spanUltraNarrow);
                idx = lo:hi;
            case {'narrow','narrow-rev'}
                [lo, hi] = i_centerSliceBounds(M, mid, spanNarrow);
                idx = lo:hi;
            case {'medium','medium-rev'}
                [lo, hi] = i_centerSliceBounds(M, mid, spanMedium);
                idx = lo:hi;
            case {'wide','wide-rev'}
                [lo, hi] = i_centerSliceBounds(M, mid, spanWide);
                idx = lo:hi;
            case {'ultra','ultra-rev'}
                [lo, hi] = i_centerSliceBounds(M, mid, spanUltra);
                idx = lo:hi;
            otherwise
                error('Unknown spread mode "%s".', modeKey);
        end

        if endsWith(modeKey, '-rev')
            idx = fliplr(idx);
        end
        idx = idx(idx >= 1 & idx <= M);
        if isempty(idx)
            idx = round(M/2);
        end
    end

    function [lo, hi] = i_centerSliceBounds(M, mid, span)
        lo = max(1, mid - round(span/2));
        hi = min(M, lo + span - 1);
        lo = min(lo, hi);
    end

    function names = i_getAvailableColormapNames()
        persistent cachedNames
        if ~isempty(cachedNames)
            names = cachedNames;
            return;
        end

        builtinNames = {'parula','turbo','jet','hsv','hot','cool','spring','summer','autumn','winter','gray','bone','copper','pink','lines','colorcube','prism','flag'};
        customNames = i_getCustomColormapNames();
        cmoceanNames = i_getCmoceanNames();
        scm8Names = i_discoverScm8Colormaps();

        names = unique([builtinNames, customNames, cmoceanNames, scm8Names], 'stable');
        cachedNames = names;
    end

    function names = i_getCustomColormapNames()
        names = { ...
            'softyellow', 'softgreen', 'softred', 'softblue', 'softpurple', ...
            'softorange', 'softcyan', 'softgray', 'softbrown', 'softteal', ...
            'softolive', 'softgold', 'softpink', 'softaqua', 'softsand', 'softsky', ...
            'bluebright', 'redbright', 'greenbright', 'purplebright', 'orangebright', ...
            'cyanbright', 'yellowbright', 'magnetabright', 'limebright', 'tealbright', ...
            'ultrabrightblue', 'ultrabrightred', ...
            'bluewhitered', 'redwhiteblue', 'purplewhitegreen', 'brownwhiteblue', ...
            'greenwhitepurple', 'bluewhiteorange', 'blackwhiteyellow', ...
            'fire', 'ice', 'ocean', 'topo', 'terrain', 'magma', 'inferno', 'plasma', 'cividis'};
    end

    function names = i_getCmoceanNames()
        names = {};
        if exist('cmocean', 'file') ~= 2
            return;
        end

        rawNames = {'thermal','haline','solar','matter','turbid','speed','amp','deep','dense','algae','balance','curl','delta','oxy','phase','rain','ice','gray'};
        names = cell(size(rawNames));
        for i = 1:numel(rawNames)
            names{i} = ['cmocean:' rawNames{i}];
        end
    end

    function names = i_discoverScm8Colormaps()
        persistent cachedScm8Names cachedDone
        if isempty(cachedDone)
            cachedDone = false;
        end

        if cachedDone
            names = cachedScm8Names;
            return;
        end

        candidates = strings(0,1);
        probeFns = {'SCM8_berlin', 'SCM8_acton', 'SCM8_vik'};
        for p = 1:numel(probeFns)
            w = which(probeFns{p});
            if ~isempty(w)
                files = dir(fullfile(fileparts(w), 'SCM8_*.m'));
                fileNames = sort({files.name});
                for f = 1:numel(fileNames)
                    candidates(end+1,1) = string(erase(fileNames{f}, '.m')); %#ok<AGROW>
                end
                break;
            end
        end

        if isempty(candidates)
            try
                thisDir = fileparts(mfilename('fullpath'));
                repoRoot = fileparts(thisDir);
                files = dir(fullfile(repoRoot, 'github_repo', '**', 'SCM8_*.m'));
                fileNames = sort({files.name});
                for f = 1:numel(fileNames)
                    candidates(end+1,1) = string(erase(fileNames{f}, '.m')); %#ok<AGROW>
                end
            catch
            end
        end

        candidates = unique(candidates, 'stable');
        [~, sortIdx] = sort(lower(candidates));
        candidates = candidates(sortIdx);
        valid = strings(0,1);
        for i = 1:numel(candidates)
            fn = char(candidates(i));
            try
                test = feval(fn, 8);
                if isnumeric(test) && ismatrix(test) && size(test,2) == 3 && all(isfinite(test(:))) && all(test(:) >= 0) && all(test(:) <= 1)
                    valid(end+1,1) = string(fn); %#ok<AGROW>
                end
            catch
            end
        end

        cachedScm8Names = cellstr(valid(:)');
        cachedDone = true;
        names = cachedScm8Names;
    end

    function C = i_makeCustomColormap(name)
        n = 256;
        switch lower(char(string(name)))
            case 'softyellow'
                C = [linspace(0.4,0.9,n)', linspace(0.4,0.9,n)', linspace(0.1,0.2,n)'];
            case 'softgreen'
                C = [linspace(0.1,0.4,n)', linspace(0.3,0.7,n)', linspace(0.1,0.3,n)'];
            case 'softred'
                C = [linspace(0.4,0.9,n)', linspace(0.1,0.3,n)', linspace(0.1,0.3,n)'];
            case 'softblue'
                C = [linspace(0.1,0.3,n)', linspace(0.1,0.3,n)', linspace(0.4,0.9,n)'];
            case 'softpurple'
                C = [linspace(0.4,0.7,n)', linspace(0.2,0.3,n)', linspace(0.5,0.8,n)'];
            case 'softorange'
                C = [linspace(0.7,0.95,n)', linspace(0.4,0.6,n)', linspace(0.1,0.2,n)'];
            case 'softcyan'
                C = [linspace(0.1,0.2,n)', linspace(0.5,0.9,n)', linspace(0.8,0.95,n)'];
            case 'softgray'
                C = repmat(linspace(0.3,0.9,n)',1,3);
            case 'softbrown'
                C = [linspace(0.3,0.6,n)', linspace(0.2,0.3,n)', linspace(0.1,0.1,n)'];
            case 'softteal'
                C = [linspace(0.1,0.2,n)', linspace(0.6,0.8,n)', linspace(0.7,0.9,n)'];
            case 'softolive'
                C = [linspace(0.3,0.5,n)', linspace(0.4,0.5,n)', linspace(0.1,0.2,n)'];
            case 'softgold'
                C = [linspace(0.8,1,n)', linspace(0.7,0.9,n)', linspace(0.2,0.3,n)'];
            case 'softpink'
                C = [linspace(0.9,1,n)', linspace(0.7,0.8,n)', linspace(0.7,0.9,n)'];
            case 'softaqua'
                C = [linspace(0.3,0.5,n)', linspace(0.8,1,n)', linspace(0.9,1,n)'];
            case 'softsand'
                C = [linspace(0.7,0.9,n)', linspace(0.6,0.7,n)', linspace(0.4,0.5,n)'];
            case 'softsky'
                C = [linspace(0.4,0.6,n)', linspace(0.6,0.8,n)', linspace(0.9,1,n)'];
            case 'bluebright'
                C = [zeros(n,1), zeros(n,1), linspace(0.2,1,n)'];
            case 'redbright'
                C = [linspace(0.2,1,n)', zeros(n,1), zeros(n,1)];
            case 'greenbright'
                C = [zeros(n,1), linspace(0.2,1,n)', zeros(n,1)];
            case 'purplebright'
                C = [linspace(0.3,1,n)', linspace(0,0.3,n)', linspace(0.3,1,n)'];
            case 'orangebright'
                C = [ones(n,1), linspace(0.5,0.1,n)', zeros(n,1)];
            case 'cyanbright'
                C = [zeros(n,1), linspace(0.5,1,n)', ones(n,1)];
            case 'yellowbright'
                C = [ones(n,1), ones(n,1), linspace(0.2,0,n)'];
            case 'magnetabright'
                C = [ones(n,1), linspace(0,0.2,n)', ones(n,1)];
            case 'limebright'
                C = [linspace(0.6,1,n)', ones(n,1), linspace(0.2,0.3,n)'];
            case 'tealbright'
                C = [zeros(n,1), linspace(0.7,1,n)', linspace(0.7,1,n)'];
            case 'ultrabrightblue'
                C = [zeros(n,1), zeros(n,1), linspace(0.5,1,n)'];
            case 'ultrabrightred'
                C = [linspace(0.5,1,n)', zeros(n,1), zeros(n,1)];
            case 'fire'
                C = [linspace(0,1,n)', linspace(0,0.8,n)', zeros(n,1)];
            case 'ice'
                C = [linspace(0.8,0,n)', linspace(1,0.4,n)', ones(n,1)];
            case 'ocean'
                C = [zeros(n,1), linspace(0.2,0.7,n)', linspace(0.5,1,n)'];
            case 'topo'
                C = [linspace(0.1,0.8,n)', linspace(0.4,0.8,n)', linspace(0.2,0.4,n)'];
            case 'terrain'
                C = [linspace(0.2,0.6,n)', linspace(0.4,1,n)', ones(n,1)*0.2];
            case 'magma'
                C = magma(n);
            case 'inferno'
                C = inferno(n);
            case 'plasma'
                C = plasma(n);
            case 'cividis'
                C = cividis(n);
            case 'bluewhitered'
                C = interp1([0 0.5 1],[0 0 1; 1 1 1; 1 0 0],linspace(0,1,n));
            case 'redwhiteblue'
                C = flipud(i_makeCustomColormap('bluewhitered'));
            case 'purplewhitegreen'
                C = interp1([0 0.5 1],[0.6 0 0.6; 1 1 1; 0 0.6 0], linspace(0,1,n));
            case 'brownwhiteblue'
                C = interp1([0 0.5 1],[0.5 0.2 0; 1 1 1; 0 0.4 1], linspace(0,1,n));
            case 'greenwhitepurple'
                C = interp1([0 0.5 1],[0 1 0; 1 1 1; 0.5 0 0.5], linspace(0,1,n));
            case 'bluewhiteorange'
                C = interp1([0 0.5 1],[0 0 1; 1 1 1; 1 0.5 0], linspace(0,1,n));
            case 'blackwhiteyellow'
                C = interp1([0 0.5 1],[0 0 0; 1 1 1; 1 1 0], linspace(0,1,n));
            otherwise
                error('Unknown custom colormap name: %s', name);
        end
    end

    function figs = i_getExplicitListTargetsNoAlert()
        figs = gobjects(0,1);
        if string(ddScope.Value) ~= "Explicit List"
            return;
        end

        selected = lbFigures.Value;
        if isempty(selected)
            return;
        end

        selected = double(selected(:));
        selected = selected(selected >= 1 & selected <= numel(explicitHandleCache));
        selected = unique(selected, 'stable');
        if isempty(selected)
            return;
        end

        figs = explicitHandleCache(selected);
        figs = figs(isgraphics(figs, 'figure'));
    end

    function onLegendArrow(locationString)
        figs = resolveExplicitListTargetsOrAlert("Legend");
        if isempty(figs), return; end

        [resolvedLocation, ok] = i_resolveLegendLocationFromArrow(locationString);
        if ~ok
            return;
        end
        legendLocationState = resolvedLocation;
        i_saveUIState();
        i_applyLegendLocationExistingOnly(figs, resolvedLocation);
    end

    function onApplyTypography(varargin)
        figs = resolveTargetsOrAlert();
        if isempty(figs), return; end

        fs = double(nfFontSize.Value);
        if ~isfinite(fs) || fs <= 0
            uialert(ui, 'Base Font Size must be a positive number.', 'Typography');
            return;
        end
        preset = char(ddAxisPreset.Value);

        [overrideFontSize, hasOverride, errMsg] = i_parseLegendOverrideFontSize();
        if strlength(errMsg) > 0
            uialert(ui, char(errMsg), 'Legend');
            return;
        end

        annOpts = struct();
        annOpts.annFontName = string(efAnnFontName.Value);
        annOpts.annFontSize = double(nfAnnFontSize.Value);
        annOpts.annFontWeight = string(ddAnnFontWeight.Value);
        annOpts.annInterpreter = string(ddAnnInterpreter.Value);
        annOpts.annColor = string(efAnnColor.Value);

        try
            if hasOverride
                FCS_applyFontSize(figs, fs, 'AffectLegend', false);
            else
                FCS_applyFontSize(figs, fs);
            end
            FCS_applyAxisPolicy(figs, preset);

            profileName = string(ddTypoProfile.Value);

            for k = 1:numel(figs)
                fig = figs(k);
                if ~isgraphics(fig, 'figure')
                    continue;
                end

                axList = findall(fig, 'Type', 'axes');
                for a = 1:numel(axList)
                    ax = axList(a);
                    if ~isgraphics(ax, 'axes')
                        continue;
                    end
                    annTextObjs = i_getAnnotationTextObjects(ax);
                    i_applyAnnotationTextStyle(annTextObjs, annOpts);
                end
            end

            if hasOverride
                i_applyLegendFontSize(figs, overrideFontSize);
            end

            report = FCS_applyTypography(figs, profileName);
            fprintf('[FCS Typography] profile=%s resolved=%s figures=%d changed=%d skipped=%d errors=%d\n', ...
                report.profileName, report.resolvedFontName, report.figuresProcessed, report.objectsChanged, report.objectsSkipped, report.objectsErrored);
            if report.objectsErrored > 0
                uialert(ui, sprintf('Typography applied with %d object-level errors. See Command Window for summary.', report.objectsErrored), 'Typography Apply Warning');
            end
        catch ME
            uialert(ui, ME.message, 'Typography Apply Failed');
        end
    end

    function onPublicationLabelAlignment(~, ~)
        figs = resolveExplicitListTargetsOrAlert("Publication Label Alignment");
        if isempty(figs)
            return;
        end

        try
            for k = 1:numel(figs)
                fig = figs(k);
                if ~isgraphics(fig, 'figure')
                    continue;
                end

                axList = findall(fig, 'Type', 'axes');
                for a = 1:numel(axList)
                    ax = axList(a);
                    if ~isgraphics(ax, 'axes')
                        continue;
                    end

                    isPrimaryAxes = i_isPrimaryPlotAxes(ax);
                    isManualLegendAxes = i_isManualLegendAxes(ax);
                    axHandleVisibility = "";
                    axVisible = "";
                    try
                        axHandleVisibility = string(ax.HandleVisibility);
                    catch
                    end
                    try
                        axVisible = string(ax.Visible);
                    catch
                    end

                    isAlignEligible = isPrimaryAxes && ~isManualLegendAxes && strcmpi(char(axVisible), 'on') && ~strcmpi(char(axHandleVisibility), 'off');
                    if ~isAlignEligible
                        continue;
                    end

                    try
                        xl = ax.XLabel;
                        if ~isempty(xl) && isgraphics(xl)
                            if isprop(xl, 'HorizontalAlignment')
                                xl.HorizontalAlignment = 'center';
                            end
                        end
                    catch
                    end

                    alignAxisLabelsPublication(ax);
                end
            end
        catch ME
            uialert(ui, ME.message, 'Publication Label Alignment Failed');
        end
    end

    function onApplyLegend(~, ~)
        figs = resolveExplicitListTargetsOrAlert("Legend");
        if isempty(figs), return; end

        baseFs = double(nfFontSize.Value);
        if ~isfinite(baseFs) || baseFs <= 0
            uialert(ui, 'Base Font Size must be a positive number.', 'Legend');
            return;
        end

        [effectiveLegendFontSize, ok] = i_resolveEffectiveLegendFontSize(baseFs);
        if ~ok
            return;
        end

        try
            i_applyLegendSettingsExistingOnly(figs, legendLocationState);
            i_applyLegendFontSize(figs, effectiveLegendFontSize);
            i_applyManualLegendDragModeToFigures(figs);
        catch ME
            uialert(ui, ME.message, 'Legend Apply Failed');
        end
    end

    function onApplyAppearance(varargin)
        overrides = struct();
        if nargin >= 3 && isstruct(varargin{3})
            overrides = varargin{3};
        end

        figs = resolveExplicitListTargetsOrAlert("Appearance");
        if isempty(figs), return; end

        spreadMode = string(ddSpreadMode.Value);
        if logical(cbSpreadReverse.Value)
            spreadMode = spreadMode + "-rev";
        end

        opts = struct();
        opts.mapName = string(ddCmap.Value);
        opts.spreadMode = spreadMode;
        opts.bgWhiteFigure = logical(cbBgWhiteFigure.Value);
        opts.bgTransparentAxes = logical(cbBgTransparentAxes.Value);
        opts.dataLineStyle = string(ddDataLineStyle.Value);
        opts.dataLineWidth = double(nfDataLineWidth.Value);
        opts.dataMarkerSize = double(nfDataMarkerSize.Value);
        opts.fitLineStyle = string(ddFitLineStyle.Value);
        opts.fitLineWidth = double(nfFitLineWidth.Value);
        opts.fitMarkerSize = double(nfFitMarkerSize.Value);
        opts.refLineWidth = double(nfRefLineWidth.Value);
        opts.refLineStyle = string(ddRefLineStyle.Value);
        opts.refLineColor = string(efRefLineColor.Value);
        opts.annFontName = string(efAnnFontName.Value);
        opts.annFontSize = double(nfAnnFontSize.Value);
        opts.annFontWeight = string(ddAnnFontWeight.Value);
        opts.annInterpreter = string(ddAnnInterpreter.Value);
        opts.annColor = string(efAnnColor.Value);
        opts.reversePlotOrder = logical(cbReversePlotOrder.Value);

        if ~isempty(fieldnames(overrides))
            fnames = sort(fieldnames(overrides));
            for i = 1:numel(fnames)
                opts.(fnames{i}) = overrides.(fnames{i});
            end
        end

        try
            stats = i_applyAppearanceSettings(figs, opts);
            taDiag.Value = {sprintf('Appearance applied: %d fig, %d axes, %d lines, %d colorbars', ...
                stats.figuresTouched, stats.axesTouched, stats.linesTouched, stats.colorbarsTouched)};
        catch ME
            uialert(ui, ME.message, 'Appearance Apply Failed');
        end
    end

    function onApplyPublicationStyle(~, ~)
        mode = str2double(string(ddPanelsPerRow.Value));
        if ~isfinite(mode) || ~any(mode == [1 2 3])
            mode = 2;
        end
        preset = i_getPublicationStylePreset(mode);

        nfDataLineWidth.Value = preset.lineWidth;
        nfDataMarkerSize.Value = preset.markerSize;
        nfFitLineWidth.Value = preset.lineWidth;
        nfFitMarkerSize.Value = preset.markerSize;

        overrides = struct();
        overrides.axesFont = preset.axesFont;
        overrides.labelFont = preset.labelFont;
        overrides.axesLineWidth = 1.1;
        overrides.tickDir = 'in';
        overrides.box = 'on';
        overrides.layer = 'top';
        overrides.tickLength = [0.02 0.02];
        overrides.xMinorTick = 'on';
        overrides.yMinorTick = 'on';
        overrides.figureColor = 'w';
        overrides.axesColor = 'none';

        onApplyAppearance([], [], overrides);
    end

    function onApplySmartPack(~, ~)
        onApplyAppearance([], []);
    end

    function onApplyWorkspaceSize(~, ~)
        % SIZE ONLY: sets figure dimensions; does not edit axes; does not call Equalize/Transform.
        figs = resolveTargetsOrAlert("Layout");
        if isempty(figs), return; end

        widthCm = double(nfWsWidth.Value);

        heightCm = i_computeWorkspaceHeightCm();
        if ~isfinite(widthCm) || widthCm <= 0 || ~isfinite(heightCm) || heightCm <= 0
            uialert(ui, 'Workspace size values must be positive numbers.', 'Workspace Size');
            return;
        end

        for k = 1:numel(figs)
            fig = figs(k);
            if ~isgraphics(fig, 'figure')
                continue;
            end

            try
                fig.Units = 'centimeters';
                % Preserve current window location; update only size.
                pos = fig.Position;
                fig.Position = [pos(1) pos(2) widthCm heightCm];
            catch
            end

        end
    end

    function onEqualizeCenterAxesGroup(~, ~)
        % Equalize defines base axes layout only. Transform is applied separately.
        figs = resolveTargetsOrAlert("Layout");
        if isempty(figs), return; end

        i_resetManualTransformToIdentityAndApply(figs);

        info = struct('fig', {}, 'axes', {}, 'positions', {}, 'xmin', {}, 'ymin', {}, 'xmax', {}, 'ymax', {}, 'width', {}, 'height', {});

        for k = 1:numel(figs)
            fig = figs(k);
            if ~isgraphics(fig, 'figure')
                continue;
            end

            axList = findall(fig, 'Type', 'axes');
            primaryAxes = gobjects(0,1);
            positions = zeros(0,4);

            for a = 1:numel(axList)
                ax = axList(a);
                if ~isgraphics(ax, 'axes') || ~i_isPrimaryPlotAxes(ax)
                    continue;
                end
                try
                    oldUnits = ax.Units;
                    ax.Units = 'normalized';
                    pos = double(ax.Position);
                    ax.Units = oldUnits;
                catch
                    continue;
                end
                if numel(pos) < 4 || any(~isfinite(pos(1:4))) || pos(3) <= 0 || pos(4) <= 0
                    continue;
                end
                primaryAxes(end+1,1) = ax; %#ok<AGROW>
                positions(end+1,:) = pos(1:4); %#ok<AGROW>
            end

            if isempty(primaryAxes)
                continue;
            end

            xmin = min(positions(:,1));
            ymin = min(positions(:,2));
            xmax = max(positions(:,1) + positions(:,3));
            ymax = max(positions(:,2) + positions(:,4));
            width = xmax - xmin;
            height = ymax - ymin;
            if ~isfinite(width) || ~isfinite(height) || width <= 0 || height <= 0
                continue;
            end

            info(end+1).fig = fig; %#ok<AGROW>
            info(end).axes = primaryAxes;
            info(end).positions = positions;
            info(end).xmin = xmin;
            info(end).ymin = ymin;
            info(end).xmax = xmax;
            info(end).ymax = ymax;
            info(end).width = width;
            info(end).height = height;
        end

        if isempty(info)
            uialert(ui, 'No primary plot axes found in selected figures.', 'Layout');
            return;
        end

        allWidths = [info.width];
        allHeights = [info.height];
        w = min(allWidths);
        h = min(allHeights);
        if ~isfinite(w) || ~isfinite(h) || w <= 0 || h <= 0
            uialert(ui, 'Unable to compute valid global group size.', 'Layout');
            return;
        end

        for iFig = 1:numel(info)
            figInfo = info(iFig);
            sx = w / figInfo.width;
            sy = h / figInfo.height;

            scaledCenterX = figInfo.xmin + w/2;
            scaledCenterY = figInfo.ymin + h/2;
            dx = 0.5 - scaledCenterX;
            dy = 0.5 - scaledCenterY;

            for a = 1:numel(figInfo.axes)
                ax = figInfo.axes(a);
                if ~isgraphics(ax, 'axes')
                    continue;
                end

                oldPos = figInfo.positions(a,:);
                newPos = [ ...
                    figInfo.xmin + (oldPos(1) - figInfo.xmin) * sx + dx, ...
                    figInfo.ymin + (oldPos(2) - figInfo.ymin) * sy + dy, ...
                    oldPos(3) * sx, ...
                    oldPos(4) * sy];

                try
                    oldUnits = ax.Units;
                    ax.Units = 'normalized';
                    ax.Position = newPos;
                    ax.Units = oldUnits;
                catch
                end
            end
        end

        i_captureAxesBasePositions(figs);
    end

    function i_captureAxesBasePositions(figs, allowNonIdentity)
        if nargin < 2
            allowNonIdentity = false;
        end

        if ~allowNonIdentity && ~i_isManualTransformIdentity()
            warning('FigureControlStudio:BaseCaptureSkipped', ...
                'Skipping full base snapshot capture while manual transform is non-identity.');
            return;
        end

        if isempty(axesBasePositions) || ~isa(axesBasePositions, 'containers.Map')
            axesBasePositions = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end
        if isempty(figs)
            return;
        end

        for k = 1:numel(figs)
            fig = figs(k);
            if isempty(fig) || ~isgraphics(fig, 'figure')
                continue;
            end

            axList = findall(fig, 'Type', 'axes');
            for a = 1:numel(axList)
                ax = axList(a);
                if ~isgraphics(ax, 'axes') || i_isTiledLayoutManagedAxes(ax) || ~i_isPrimaryPlotAxes(ax)
                    continue;
                end
                try
                    ax.Units = 'normalized';
                    key = i_axesSnapshotKey(ax);
                    axesBasePositions(key) = double(ax.Position);
                catch
                end
            end
        end
    end

    function i_captureAxesBasePositionsIfMissing(figs)
        if isempty(axesBasePositions) || ~isa(axesBasePositions, 'containers.Map')
            axesBasePositions = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end
        if isempty(figs)
            return;
        end

        for k = 1:numel(figs)
            fig = figs(k);
            if isempty(fig) || ~isgraphics(fig, 'figure')
                continue;
            end

            axList = findall(fig, 'Type', 'axes');
            for a = 1:numel(axList)
                ax = axList(a);
                if ~isgraphics(ax, 'axes') || i_isTiledLayoutManagedAxes(ax) || ~i_isPrimaryPlotAxes(ax)
                    continue;
                end
                try
                    ax.Units = 'normalized';
                    key = i_axesSnapshotKey(ax);

                    shouldCapture = true;
                    if isKey(axesBasePositions, key)
                        cand = axesBasePositions(key);
                        shouldCapture = ~(isnumeric(cand) && numel(cand) >= 4 && all(isfinite(cand(1:4))));
                    end

                    if shouldCapture
                        axesBasePositions(key) = double(ax.Position);
                    end
                catch
                end
            end
        end
    end

    function tf = i_isManualTransformIdentity()
        tf = abs(double(slAxScaleX.Value) - 1.0) <= 1e-12 && ...
             abs(double(slAxScaleY.Value) - 1.0) <= 1e-12 && ...
             abs(double(slAxOffsetX.Value)) <= 1e-12 && ...
             abs(double(slAxOffsetY.Value)) <= 1e-12;
    end

    function i_applyManualAxesTransform(fig)
        if isempty(fig) || ~isgraphics(fig, 'figure')
            return;
        end

        scaleX = i_quantizeSliderValue(double(slAxScaleX.Value), [0.5 1.5], 0.01);
        scaleY = i_quantizeSliderValue(double(slAxScaleY.Value), [0.5 1.5], 0.01);
        offsetX = i_quantizeSliderValue(double(slAxOffsetX.Value), [-0.2 0.2], 0.01);
        offsetY = i_quantizeSliderValue(double(slAxOffsetY.Value), [-0.2 0.2], 0.01);

        axList = findall(fig, 'Type', 'axes');

        validAxes = gobjects(0,1);
        basePositions = zeros(0,4);
        for a = 1:numel(axList)
            ax = axList(a);
            if ~isgraphics(ax, 'axes') || i_isTiledLayoutManagedAxes(ax) || ~i_isPrimaryPlotAxes(ax)
                continue;
            end
            try
                ax.Units = 'normalized';
                basePos = i_getAxesBasePositionFromSnapshot(ax);
                if isempty(basePos)
                    continue;
                end
                validAxes(end+1,1) = ax; %#ok<AGROW>
                basePositions(end+1,:) = basePos(1:4); %#ok<AGROW>
            catch
            end
        end

        nAxes = size(basePositions,1);
        if nAxes == 0
            return;
        end

        if nAxes == 1
            try
                newPos = i_computeManualAxesPosition(basePositions(1,:), scaleX, scaleY, offsetX, offsetY);
                validAxes(1).Position = newPos;
            catch
            end
            return;
        end

        xmin = min(basePositions(:,1));
        ymin = min(basePositions(:,2));
        xmax = max(basePositions(:,1) + basePositions(:,3));
        ymax = max(basePositions(:,2) + basePositions(:,4));
        unionW = xmax - xmin;
        unionH = ymax - ymin;

        if ~isfinite(unionW) || ~isfinite(unionH) || unionW <= 0 || unionH <= 0
            return;
        end

        unionBase = [xmin ymin unionW unionH];
        unionNew = i_computeManualAxesPosition(unionBase, scaleX, scaleY, offsetX, offsetY);

        for a = 1:nAxes
            basePos = basePositions(a,:);

            relX = (basePos(1) - xmin) / unionW;
            relY = (basePos(2) - ymin) / unionH;
            relW = basePos(3) / unionW;
            relH = basePos(4) / unionH;

            newPos = [ ...
                unionNew(1) + relX * unionNew(3), ...
                unionNew(2) + relY * unionNew(4), ...
                relW * unionNew(3), ...
                relH * unionNew(4)];

            newPos = i_clampAxesPositionIfNeeded(newPos);

            try
                validAxes(a).Position = newPos;
            catch
            end
        end
    end

    function basePos = i_getAxesBasePositionFromSnapshot(ax)
        basePos = [];
        if isempty(ax) || ~isgraphics(ax, 'axes')
            return;
        end

        key = i_axesSnapshotKey(ax);
        if isKey(axesBasePositions, key)
            cand = axesBasePositions(key);
            if isnumeric(cand) && numel(cand) >= 4 && all(isfinite(cand(1:4)))
                basePos = double(cand(1:4));
            end
        end
    end

    function key = i_axesSnapshotKey(ax)
        key = "";
        if isempty(ax) || ~isgraphics(ax)
            return;
        end
        try
            key = string(sprintf('%.17g', double(ax)));
        catch
            key = "";
        end
    end

    function posOut = i_computeManualAxesPosition(posIn, scaleX, scaleY, offsetX, offsetY)
        if ~isnumeric(posIn) || numel(posIn) < 4
            posOut = [0 0 1 1];
            return;
        end

        newWidth = posIn(3) * scaleX;
        newHeight = posIn(4) * scaleY;

        centerX = posIn(1) + posIn(3) / 2;
        centerY = posIn(2) + posIn(4) / 2;

        newLeft = centerX - newWidth / 2 + offsetX;
        newBottom = centerY - newHeight / 2 + offsetY;

        posOut = [newLeft newBottom newWidth newHeight];
        posOut = i_clampAxesPositionIfNeeded(posOut);
    end

    function pos = i_clampAxesPositionIfNeeded(pos)
        if pos(1) < 0
            pos(1) = 0;
        end
        if pos(2) < 0
            pos(2) = 0;
        end
        if pos(1) + pos(3) > 1
            pos(1) = max(0, 1 - pos(3));
        end
        if pos(2) + pos(4) > 1
            pos(2) = max(0, 1 - pos(4));
        end
    end

    function tf = i_isPrimaryPlotAxes(ax)
        tf = false;
        if isempty(ax) || ~isgraphics(ax, 'axes')
            return;
        end

        if i_isManualLegendAxes(ax)
            return;
        end

        try
            tagVal = lower(strtrim(string(ax.Tag)));
        catch
            tagVal = "";
        end

        if contains(tagVal, "legend") || contains(tagVal, "colorbar")
            return;
        end

        tf = true;
    end

    function tf = i_isManualLegendAxes(ax)
        tf = false;
        if isempty(ax) || ~isgraphics(ax, 'axes')
            return;
        end

        tagVal = "";
        try
            tagVal = lower(strtrim(string(ax.Tag)));
        catch
        end

        if tagVal == "plotsmtcombinedmanuallegendaxes"
            tf = true;
            return;
        end

        if tagVal == "mt_legend_axes"
            tf = true;
            return;
        end

        if contains(tagVal, "legend_axes")
            tf = true;
            return;
        end

        % No appdata handle dependency: manual legend axes are identified by tag.
    end

    function tf = i_isTiledLayoutManagedAxes(ax)
        tf = false;
        if isempty(ax) || ~isgraphics(ax, 'axes')
            return;
        end

        try
            p = ax.Parent;
            if ~isempty(p)
                pClass = lower(string(class(p)));
                if contains(pClass, "tiledchartlayout")
                    tf = true;
                    return;
                end
            end
        catch
        end

        try
            if isprop(ax, 'Layout')
                lay = ax.Layout;
                if ~isempty(lay) && isprop(lay, 'Tile')
                    tileVal = [];
                    try
                        tileVal = lay.Tile;
                    catch
                    end
                    if ~isempty(tileVal)
                        tf = true;
                        return;
                    end
                end
            end
        catch
        end
    end

    function onChooseFolder(~, ~)
        baseDir = char(string(efExportDir.Value));
        if isempty(baseDir) || exist(baseDir, 'dir') ~= 7
            baseDir = pwd;
        end
        p = uigetdir(baseDir, 'Select export folder');
        if isequal(p, 0)
            return;
        end
        efExportDir.Value = char(p);
        i_saveUIState();
    end

    function onApplyExport(~, ~)
        exportTempComposedFig = false;
        if logical(cbExportComposedOnly.Value)
            fig = [];
            if ~isempty(lastComposedFigure) && isgraphics(lastComposedFigure, 'figure')
                fig = lastComposedFigure;
            else
                [fig, ~, errMsg] = i_buildComposedFigureFromCurrentSelection();
                if isempty(fig) || ~isgraphics(fig, 'figure')
                    if isempty(errMsg)
                        errMsg = 'No composed figure is available to export.';
                    end
                    uialert(ui, char(errMsg), 'Export');
                    return;
                end
                exportTempComposedFig = true;
            end
            if strcmpi(char(ddExportFmt.Value), 'pdf')
                outDir = char(string(efExportDir.Value));
                if isempty(outDir)
                    outDir = pwd;
                end

                if exist(outDir, 'dir') ~= 7
                    mkdir(outDir);
                end

                modeStr = lower(strtrim(string(ddFilenameFrom.Value)));
                if modeStr == "name"
                    baseName = string(fig.Name);
                    if strlength(strtrim(baseName)) == 0
                        try
                            baseName = "Figure" + string(fig.Number);
                        catch
                            baseName = "Figure_1";
                        end
                    end
                else
                    try
                        baseName = "Figure" + string(fig.Number);
                    catch
                        baseName = "Figure_1";
                    end
                end

                try
                    if exist('sanitizeFilename', 'file') == 2
                        baseName = string(sanitizeFilename(char(baseName)));
                    end
                catch
                end
                if strlength(baseName) == 0
                    baseName = "Figure_1";
                end

                outFile = fullfile(outDir, char(baseName + ".pdf"));
                if ~logical(cbOverwrite.Value)
                    [p, n, e] = fileparts(outFile);
                    k = 1;
                    while exist(outFile, 'file')
                        outFile = fullfile(p, sprintf('%s_%d%s', n, k, e));
                        k = k + 1;
                    end
                end

                exportgraphics(fig, outFile, 'ContentType', 'vector');

                if exportTempComposedFig && ~isempty(fig) && isgraphics(fig, 'figure')
                    close(fig);
                end
                return;
            end
            figs = fig;
        else
            figs = resolveTargetsOrAlert('Export');
        end
        if isempty(figs), return; end

        exportOpts = struct();
        exportOpts.format = char(ddExportFmt.Value);
        exportOpts.outDir = char(string(efExportDir.Value));
        exportOpts.overwrite = logical(cbOverwrite.Value);
        exportOpts.vectorMode = logical(cbVector.Value);
        exportOpts.filenameFrom = char(ddFilenameFrom.Value);
        exportOpts.sanitize = true;

        try
            FCS_export(figs, exportOpts);
        catch ME
            uialert(ui, ME.message, 'Export Apply Failed');
        end
        if exportTempComposedFig && exist('fig', 'var') && ~isempty(fig) && isgraphics(fig, 'figure')
            close(fig);
        end
    end

    function journalSpecs = i_getJournalSpecs()
        journalSpecs = struct();
        journalSpecs.PRL = struct('Single', 8.6, 'Double', 17.8);
        journalSpecs.Nature = struct('Single', 8.9, 'Double', 18.3);
    end

    function onTargetReport(~, ~)
        try
            scopeSpec = buildScopeSpecFromUI();
            figs = FCS_resolveTargets(scopeSpec);
            figs = figs(isgraphics(figs, 'figure'));
            figs(figs == ui) = [];

            lines = strings(0,1);
            lines(end+1) = "Scope mode: " + string(scopeSpec.mode);
            lines(end+1) = "Exclude Known GUIs: " + string(logical(cbExcludeGUIs.Value));
            lines(end+1) = "Resolved targets: " + string(numel(figs));

            for k = 1:numel(figs)
                f = figs(k);
                numTxt = '?';
                nameTxt = '(unnamed)';
                tagTxt = '';
                try, numTxt = string(f.Number); catch, end
                try, if strlength(strtrim(string(f.Name))) > 0, nameTxt = string(f.Name); end, catch, end
                try, tagTxt = string(f.Tag); catch, end
                lines(end+1) = "  #" + numTxt + " | " + nameTxt + " | Tag=" + tagTxt;
            end

            if isempty(lines)
                lines = "No targets.";
            end

            taDiag.Value = cellstr(lines);
        catch ME
            taDiag.Value = {['Status error: ' ME.message]};
        end
    end

    function onSaveLayout(~, ~)
        rows = max(1, round(double(nfRows.Value)));
        cols = max(1, round(double(nfCols.Value)));

        widthCm = 8.6;
        switch string(ddWidthPreset.Value)
            case "Single column"
                widthCm = 8.6;
            case "Double column"
                widthCm = 17.6;
            case "Custom"
                widthCm = double(nfCustomWidth.Value);
                if ~isfinite(widthCm) || widthCm <= 0
                    uialert(ui, 'Custom width must be positive.', 'Save Layout Spec');
                    return;
                end
        end

        heightCm = max(3.0, widthCm * (rows / cols));
        spec = i_buildComposeSpecFromUI(rows, cols, widthCm, heightCm);

        [file, path] = uiputfile('*.composeSpec.mat', 'Save Layout Spec');
        if isequal(file, 0) || isequal(path, 0)
            return;
        end

        try
            save(fullfile(path, file), 'spec');
        catch ME
            uialert(ui, ME.message, 'Save Layout Spec Failed');
        end
    end

    function onLoadLayout(~, ~)
        [file, path] = uigetfile('*.composeSpec.mat', 'Load Layout Spec');
        if isequal(file, 0) || isequal(path, 0)
            return;
        end

        try
            S = load(fullfile(path, file), 'spec');
        catch ME
            uialert(ui, ME.message, 'Load Layout Spec Failed');
            return;
        end

        if ~isstruct(S) || ~isfield(S, 'spec')
            uialert(ui, 'Invalid ComposeSpec file: missing field "spec".', 'Invalid Layout Spec');
            return;
        end

        spec = S.spec;
        if ~isstruct(spec)
            uialert(ui, 'Invalid ComposeSpec file: "spec" must be a struct.', 'Invalid Layout Spec');
            return;
        end

        if ~isfield(spec, 'version') || ~isequal(double(spec.version), 1)
            uialert(ui, 'Invalid ComposeSpec file: unsupported or missing version (expected 1).', 'Invalid Layout Spec');
            return;
        end

        hasGrid = isfield(spec, 'grid') && isstruct(spec.grid) && ...
            isfield(spec.grid, 'rows') && isfield(spec.grid, 'cols');
        hasSize = isfield(spec, 'size') && isstruct(spec.size) && ...
            isfield(spec.size, 'widthCm') && isfield(spec.size, 'heightCm');
        hasLabels = isfield(spec, 'labels') && isstruct(spec.labels) && ...
            isfield(spec.labels, 'enabled') && isfield(spec.labels, 'position') && isfield(spec.labels, 'fontSize');

        if ~(hasGrid && hasSize && hasLabels)
            uialert(ui, 'Invalid ComposeSpec file: required fields grid/size/labels are missing.', 'Invalid Layout Spec');
            return;
        end

        i_applyComposeSpecToUI(spec);
    end

    function [newFig, composeWarnings] = i_buildComposedFigure(figs, rows, cols, widthCm, hGap, vGap, scaleFactor, autoLabel, labelPos, labelFs)
        % Pure visual compose: create tiledlayout and copy axes without geometry modification
        newFig = [];
        composeWarnings = strings(0,1);
        
        if isempty(figs) || rows < 1 || cols < 1
            return;
        end
        
        % Create new figure
        newFig = figure('Name', 'Composed Figure', 'Renderer', 'painters');
        
        % Create tiledlayout
        tl = tiledlayout(newFig, rows, cols, 'Padding', 'compact', 'TileSpacing', 'compact');
        
        % Copy each figure's primary axes into tiles
        for k = 1:numel(figs)
            srcFig = figs(k);
            
            % Find primary axes in source figure
            allAxes = findall(srcFig, 'Type', 'axes');
            primaryAxes = gobjects(0,1);
            
            for iAx = 1:numel(allAxes)
                ax = allAxes(iAx);
                if ~isgraphics(ax, 'axes')
                    continue;
                end
                % Skip legend axes
                if strcmp(get(ax, 'Tag'), 'legend')
                    continue;
                end
                % Skip axes with no children
                children = allchild(ax);
                if isempty(children)
                    continue;
                end
                % Check for plot objects
                hasPlot = any(arrayfun(@(h) ...
                    isa(h,'matlab.graphics.chart.primitive.Line') || ...
                    isa(h,'matlab.graphics.chart.primitive.Scatter') || ...
                    isa(h,'matlab.graphics.chart.primitive.Image') || ...
                    isa(h,'matlab.graphics.chart.primitive.Bar') || ...
                    isa(h,'matlab.graphics.chart.primitive.Area') || ...
                    isa(h,'matlab.graphics.chart.primitive.ErrorBar') || ...
                    isa(h,'matlab.graphics.chart.primitive.Surface') || ...
                    isa(h,'matlab.graphics.primitive.Patch'), children));
                
                if hasPlot
                    primaryAxes(end+1,1) = ax; %#ok<AGROW>
                end
            end
            
            % Create tile and copy axes
            nexttile(tl, k);
            if ~isempty(primaryAxes)
                try
                    copyobj(primaryAxes, tl);
                catch ME
                    % Fallback: copy one by one
                    for j = 1:numel(primaryAxes)
                        try
                            copyobj(primaryAxes(j), tl);
                        catch
                        end
                    end
                end
            end
        end
    end

    function [newFig, composeWarnings, errMsg] = i_buildComposedFigureFromCurrentSelection()
        newFig = [];
        composeWarnings = strings(0,1);
        errMsg = '';
        if string(ddScope.Value) ~= "Explicit List"
            errMsg = 'Compose is available only in Explicit List scope mode.';
            return;
        end
        selected = lbFigures.Value;
        if isempty(selected)
            errMsg = 'Select at least one figure from the explicit list.';
            return;
        end
        selected = double(selected(:));
        selected = selected(selected >= 1 & selected <= numel(explicitHandleCache));
        selected = unique(selected, 'stable');
        figs = explicitHandleCache(selected);
        figs = figs(isgraphics(figs, 'figure'));
        if isempty(figs)
            errMsg = 'Selected explicit-list figures are not valid.';
            return;
        end
        rows = max(1, round(double(nfRows.Value)));
        cols = max(1, round(double(nfCols.Value)));
        if rows * cols < numel(figs)
            errMsg = 'Rows * Columns must be at least the number of selected figures.';
            return;
        end
        widthCm = 8.6;
        switch string(ddWidthPreset.Value)
            case "Single column"
                widthCm = 8.6;
            case "Double column"
                widthCm = 17.6;
            case "Custom"
                widthCm = double(nfCustomWidth.Value);
                if ~isfinite(widthCm) || widthCm <= 0
                    errMsg = 'Custom width must be positive.';
                    return;
                end
        end
        hGap = i_quantizeSliderValue(double(slComposeHGap.Value), [0 0.1], 0.001);
        vGap = i_quantizeSliderValue(double(slComposeVGap.Value), [0 0.1], 0.001);
        scalePercent = double(nfOverallSizePct.Value);
        if ~isfinite(scalePercent)
            scalePercent = 100;
        end
        scalePercent = max(80, min(130, scalePercent));
        scaleFactor = scalePercent / 100;
        autoLabel = logical(cbAutoLabel.Value);
        labelPos = string(ddLabelPos.Value);
        labelFs = max(1, double(nfLabelFont.Value));
        [newFig, composeWarnings] = i_buildComposedFigure(figs, rows, cols, widthCm, hGap, vGap, scaleFactor, autoLabel, labelPos, labelFs);
    end

    function onCompose(~, ~)
        i_saveUIState();
        [newFig, composeWarnings, errMsg] = i_buildComposedFigureFromCurrentSelection();
        if ~isempty(errMsg)
            uialert(ui, errMsg, 'Compose');
            return;
        end
        if ~isempty(composeWarnings)
            msg = strjoin(unique(composeWarnings, 'stable'), newline);
            uialert(ui, char(msg), 'Compose warnings');
        end
        if isgraphics(newFig, 'figure')
            sel = lbFigures.Value;
            sel = double(sel(:));
            sel = sel(sel >= 1 & sel <= numel(explicitHandleCache));
            sel = unique(sel, 'stable');

            explicitHandleCache = [explicitHandleCache; newFig];
            i_captureAxesBasePositionsIfMissing(newFig);

            % Keep previous selection only (do not auto-select composed figure)
            refreshExplicitListbox(sel);

            lastComposedFigure = newFig;
            i_applyManualLegendDragModeToFigures(explicitHandleCache);
            i_saveUIState();
        end
    end

    function exportFig = i_createComposeFlattenedExportFigure(sourceFig)
        exportFig = [];
        if isempty(sourceFig) || ~isgraphics(sourceFig, 'figure')
            error('FigureControlStudio:ComposeExportInvalidFigure', 'Invalid compose figure for export flattening.');
        end

        srcSizePx = [1200 800];
        try
            oldUnitsSrc = sourceFig.Units;
            sourceFig.Units = 'pixels';
            srcPos = double(sourceFig.Position);
            sourceFig.Units = oldUnitsSrc;
            if isnumeric(srcPos) && numel(srcPos) >= 4 && all(isfinite(srcPos(3:4)))
                srcSizePx = max([200 200], round(srcPos(3:4)));
            end
        catch
        end

        exportFig = figure('Visible', 'off', ...
                           'Color', 'w', ...
                           'Renderer', 'painters', ...
                           'Units', 'pixels', ...
                           'Position', [100 100 srcSizePx(1) srcSizePx(2)]);

        srcAxes = findall(sourceFig, 'Type', 'axes');
        srcManualLegendAxes = srcAxes(false(size(srcAxes)));
        srcDataAxes = srcAxes(false(size(srcAxes)));
        for i = 1:numel(srcAxes)
            ax = srcAxes(i);
            if i_isManualLegendAxes(ax)
                srcManualLegendAxes(end+1,1) = ax; %#ok<AGROW>
            else
                srcDataAxes(end+1,1) = ax; %#ok<AGROW>
            end
        end

        for i = 1:numel(srcDataAxes)
            i_copyComposeObjectToFlattenedFigure(srcDataAxes(i), sourceFig, exportFig);
        end

        srcLegends = findall(sourceFig, 'Type', 'legend');
        for i = 1:numel(srcLegends)
            i_copyComposeObjectToFlattenedFigure(srcLegends(i), sourceFig, exportFig);
        end

        srcColorbars = findall(sourceFig, 'Type', 'colorbar');
        for i = 1:numel(srcColorbars)
            i_copyComposeObjectToFlattenedFigure(srcColorbars(i), sourceFig, exportFig);
        end

        for i = 1:numel(srcManualLegendAxes)
            copied = i_copyComposeObjectToFlattenedFigure(srcManualLegendAxes(i), sourceFig, exportFig);
            if ~isempty(copied) && isgraphics(copied)
                try
                    uistack(copied, 'top');
                catch
                end
            end
        end
    end

    function copied = i_copyComposeObjectToFlattenedFigure(srcObj, sourceFig, exportFig)
        copied = [];
        if isempty(srcObj) || ~isgraphics(srcObj) || isempty(sourceFig) || ~isgraphics(sourceFig, 'figure') || isempty(exportFig) || ~isgraphics(exportFig, 'figure')
            return;
        end

        objPosFig = i_getComposeObjectFigureNormalizedPosition(srcObj, sourceFig);

        try
            copied = copyobj(srcObj, exportFig);
        catch
            return;
        end

        if isempty(copied) || ~isgraphics(copied)
            return;
        end

        try
            if isprop(copied, 'Units')
                copied.Units = 'normalized';
            end
            if isprop(copied, 'Position') && isnumeric(objPosFig) && numel(objPosFig) >= 4
                copied.Position = i_clampRectNormalized(double(objPosFig(1:4)));
            end
        catch
        end
    end

    function posFig = i_getComposeObjectFigureNormalizedPosition(srcObj, sourceFig)
        posFig = [0 0 1 1];
        if isempty(srcObj) || ~isgraphics(srcObj) || isempty(sourceFig) || ~isgraphics(sourceFig, 'figure')
            return;
        end

        if ~isprop(srcObj, 'Position')
            return;
        end

        try
            oldUnitsObj = [];
            if isprop(srcObj, 'Units')
                oldUnitsObj = srcObj.Units;
                srcObj.Units = 'normalized';
            end
            posObj = double(srcObj.Position);
            if ~isempty(oldUnitsObj)
                srcObj.Units = oldUnitsObj;
            end
        catch
            return;
        end

        if ~isnumeric(posObj) || numel(posObj) < 4 || any(~isfinite(posObj(1:4)))
            return;
        end

        posFig = double(posObj(1:4));

        parentObj = [];
        try
            parentObj = srcObj.Parent;
        catch
        end

        while ~isempty(parentObj) && ~isequal(parentObj, sourceFig)
            if ~isgraphics(parentObj)
                break;
            end

            if ~isgraphics(parentObj, 'uipanel')
                break;
            end

            try
                oldUnitsParent = parentObj.Units;
                parentObj.Units = 'normalized';
                parentPos = double(parentObj.Position);
                parentObj.Units = oldUnitsParent;
            catch
                break;
            end

            if ~isnumeric(parentPos) || numel(parentPos) < 4 || any(~isfinite(parentPos(1:4)))
                break;
            end

            posFig = [ ...
                parentPos(1) + posFig(1) * parentPos(3), ...
                parentPos(2) + posFig(2) * parentPos(4), ...
                posFig(3) * parentPos(3), ...
                posFig(4) * parentPos(4)];

            try
                parentObj = parentObj.Parent;
            catch
                break;
            end
        end

        posFig = i_clampRectNormalized(posFig);
    end

    function i_safeDeleteGraphics(h)
        if isempty(h)
            return;
        end
        try
            if isgraphics(h)
                delete(h);
            end
        catch
        end
    end

    function i_applyComposeExportPhysicalSize(exportFig, widthCm, heightCm)
        if isempty(exportFig) || ~isgraphics(exportFig, 'figure')
            return;
        end
        if ~isfinite(widthCm) || widthCm <= 0 || ~isfinite(heightCm) || heightCm <= 0
            return;
        end

        exportFig.Units = 'centimeters';
        pos = exportFig.Position;
        pos(3) = double(widthCm);
        pos(4) = double(heightCm);
        exportFig.Position = pos;
        exportFig.Renderer = 'painters';
    end

    function i_logComposeExportFigureDiagnostics(exportFig)
        if isempty(exportFig) || ~isgraphics(exportFig, 'figure')
            return;
        end

        figUnits = get(exportFig, 'Units');
        figPosition = get(exportFig, 'Position');
        paperUnits = get(exportFig, 'PaperUnits');
        paperPositionMode = get(exportFig, 'PaperPositionMode');
        paperPosition = get(exportFig, 'PaperPosition');
        paperSize = get(exportFig, 'PaperSize');

        screenDpi = get(0, 'ScreenPixelsPerInch');

        oldUnits = exportFig.Units;
        exportFig.Units = 'pixels';
        posPx = double(exportFig.Position);
        exportFig.Units = oldUnits;

        widthIn = NaN;
        heightIn = NaN;
        widthCm = NaN;
        heightCm = NaN;
        if isnumeric(posPx) && numel(posPx) >= 4 && isfinite(screenDpi) && screenDpi > 0
            widthIn = posPx(3) / screenDpi;
            heightIn = posPx(4) / screenDpi;
            widthCm = widthIn * 2.54;
            heightCm = heightIn * 2.54;
        end

        fprintf('\n=== Compose Export Status (right before exportgraphics) ===\n');
        fprintf('get(exportFig,''Units'') = %s\n', string(figUnits));
        fprintf('get(exportFig,''Position'') = [%g %g %g %g]\n', figPosition(1), figPosition(2), figPosition(3), figPosition(4));
        fprintf('get(exportFig,''PaperUnits'') = %s\n', string(paperUnits));
        fprintf('get(exportFig,''PaperPositionMode'') = %s\n', string(paperPositionMode));
        fprintf('get(exportFig,''PaperPosition'') = [%g %g %g %g]\n', paperPosition(1), paperPosition(2), paperPosition(3), paperPosition(4));
        fprintf('get(exportFig,''PaperSize'') = [%g %g]\n', paperSize(1), paperSize(2));
        fprintf('get(0,''ScreenPixelsPerInch'') = %g\n', screenDpi);
        fprintf('exportFig pixel size = [%g x %g] px\n', posPx(3), posPx(4));
        fprintf('pixel->inch = [%g x %g] in\n', widthIn, heightIn);
        fprintf('pixel->cm = [%g x %g] cm\n', widthCm, heightCm);
        fprintf('===============================================================\n\n');
    end

    function tilePos = i_computeComposeContainerPosition(k, rows, cols, hGap, vGap)
        tilePos = [0 0 1 1];
        if ~isfinite(k) || ~isfinite(rows) || ~isfinite(cols) || rows < 1 || cols < 1
            return;
        end

        colIndex = mod(k - 1, cols);
        rowIndex = floor((k - 1) / cols);

        widthPerCell = (1 - (cols - 1) * hGap) / cols;
        heightPerCell = (1 - (rows - 1) * vGap) / rows;

        if ~isfinite(widthPerCell) || widthPerCell <= 0
            widthPerCell = 1 / cols;
            hGap = 0;
        end
        if ~isfinite(heightPerCell) || heightPerCell <= 0
            heightPerCell = 1 / rows;
            vGap = 0;
        end

        x = colIndex * (widthPerCell + hGap);
        yFromTop = rowIndex * (heightPerCell + vGap);
        y = 1 - yFromTop - heightPerCell;

        tilePos = [x y widthPerCell heightPerCell];

        tilePos(1) = min(max(tilePos(1), 0), 1);
        tilePos(2) = min(max(tilePos(2), 0), 1);
        tilePos(3) = min(max(tilePos(3), 0.001), 1);
        tilePos(4) = min(max(tilePos(4), 0.001), 1);
        if tilePos(1) + tilePos(3) > 1
            tilePos(1) = max(0, 1 - tilePos(3));
        end
        if tilePos(2) + tilePos(4) > 1
            tilePos(2) = max(0, 1 - tilePos(4));
        end
    end

    function [manualLegendCopied, manualLegendCopyFailed] = i_preserveCopiedAxesPositions(srcFig, panel, newFig, tilePos, srcManualLegendAxes)
        manualLegendCopied = 0;
        manualLegendCopyFailed = 0;

        if isempty(srcFig) || ~isgraphics(srcFig, 'figure') || isempty(panel) || ~isgraphics(panel)
            return;
        end

        srcAxes = findall(srcFig, 'Type', 'axes');
        dstAxes = findall(panel, 'Type', 'axes');
        if ~isempty(srcAxes) && ~isempty(dstAxes)
            srcIsManualLegend = false(size(srcAxes));
            for i = 1:numel(srcAxes)
                srcIsManualLegend(i) = i_isManualLegendAxes(srcAxes(i));
            end

            dstIsManualLegend = false(size(dstAxes));
            for i = 1:numel(dstAxes)
                dstIsManualLegend(i) = i_isManualLegendAxes(dstAxes(i));
            end

            srcAxes = srcAxes(~srcIsManualLegend);
            dstAxes = dstAxes(~dstIsManualLegend);

            try
                [~, idxSrc] = sort(double(srcAxes), 'ascend');
                srcAxes = srcAxes(idxSrc);
            catch
            end
            try
                [~, idxDst] = sort(double(dstAxes), 'ascend');
                dstAxes = dstAxes(idxDst);
            catch
            end

            n = min(numel(srcAxes), numel(dstAxes));
            for i = 1:n
                oldAx = srcAxes(i);
                newAx = dstAxes(i);
                if ~isgraphics(oldAx, 'axes') || ~isgraphics(newAx, 'axes')
                    continue;
                end

                try
                    oldUnits = oldAx.Units;
                    oldAx.Units = 'normalized';
                    srcOuterPos = oldAx.OuterPosition;
                    oldAx.Units = oldUnits;

                    newAx.Units = 'normalized';
                    newAx.OuterPosition = srcOuterPos;
                catch
                end
            end
        end

        if nargin < 5 || isempty(srcManualLegendAxes) || isempty(newFig) || ~isgraphics(newFig, 'figure')
            return;
        end

        for iLeg = 1:numel(srcManualLegendAxes)
            srcLegAx = srcManualLegendAxes(iLeg);
            if ~isgraphics(srcLegAx, 'axes')
                continue;
            end

            try
                oldUnitsLeg = srcLegAx.Units;
                srcLegAx.Units = 'normalized';
                srcOuterPos = double(srcLegAx.OuterPosition);
                srcLegAx.Units = oldUnitsLeg;

                mappedFigureOuterPos = [ ...
                    tilePos(1) + srcOuterPos(1) * tilePos(3), ...
                    tilePos(2) + srcOuterPos(2) * tilePos(4), ...
                    srcOuterPos(3) * tilePos(3), ...
                    srcOuterPos(4) * tilePos(4)];

                newLegAx = copyobj(srcLegAx, newFig);
                newLegAx.Units = 'normalized';
                newLegAx.OuterPosition = i_clampRectNormalized(mappedFigureOuterPos);

                if isprop(newLegAx, 'Clipping')
                    newLegAx.Clipping = 'off';
                end
                i_bringGraphicsToFront(newLegAx);
                manualLegendCopied = manualLegendCopied + 1;
            catch
                manualLegendCopyFailed = manualLegendCopyFailed + 1;
            end
        end
    end

    function tilePos = i_getTilePosition(tileAxesOrLayout)
        tilePos = [0 0 1 1];
        if isempty(tileAxesOrLayout) || ~isgraphics(tileAxesOrLayout)
            return;
        end

        try
            oldUnits = tileAxesOrLayout.Units;
            tileAxesOrLayout.Units = 'normalized';
            tilePos = tileAxesOrLayout.Position;
            tileAxesOrLayout.Units = oldUnits;
        catch
            try
                tilePos = tileAxesOrLayout.Position;
            catch
                tilePos = [0 0 1 1];
            end
        end
    end

    function [childrenToCopy, skipAnnotationCount, skipUnsupportedCount, manualLegendAxes] = i_filterComposeChildren(srcFig)
        childrenToCopy = gobjects(0,1);
        skipAnnotationCount = 0;
        skipUnsupportedCount = 0;
        manualLegendAxes = gobjects(0,1);

        if isempty(srcFig) || ~isgraphics(srcFig, 'figure')
            return;
        end

        manualLegendAxes = i_getManualLegendAxesForFigure(srcFig);

        srcChildren = allchild(srcFig);
        keep = false(numel(srcChildren), 1);
        for i = 1:numel(srcChildren)
            child = srcChildren(i);

            isValidGraphicsHandle = false;
            try
                isValidGraphicsHandle = isgraphics(child) && isvalid(child);
            catch
                try
                    isValidGraphicsHandle = ishghandle(child) && isgraphics(child);
                catch
                    isValidGraphicsHandle = false;
                end
            end

            if ~isValidGraphicsHandle
                skipUnsupportedCount = skipUnsupportedCount + 1;
                continue;
            end

            cls = "";
            try
                cls = string(class(child));
            catch
            end
            clsLower = lower(cls);

            isFigureAnnotation = startsWith(cls, "matlab.graphics.shape.") || contains(clsLower, "annotationpane");
            if isFigureAnnotation
                skipAnnotationCount = skipAnnotationCount + 1;
                continue;
            end

            isGraphicsRooted = startsWith(cls, "matlab.graphics.");
            if ~isGraphicsRooted
                skipUnsupportedCount = skipUnsupportedCount + 1;
                continue;
            end

            keep(i) = true;
        end

        childrenToCopy = srcChildren(keep);
    end

    function axesOut = i_getManualLegendAxesForFigure(fig)
        axesOut = gobjects(0,1);
        if isempty(fig) || ~isgraphics(fig, 'figure')
            return;
        end

        srcAxes = findall(fig, 'Type', 'axes');
        if isempty(srcAxes)
            return;
        end

        keep = false(numel(srcAxes),1);
        for i = 1:numel(srcAxes)
            keep(i) = i_isManualLegendAxes(srcAxes(i));
        end
        axesOut = srcAxes(keep);

        try
            [~, idx] = sort(double(axesOut), 'ascend');
            axesOut = axesOut(idx);
        catch
        end
    end

    function axesOut = i_getPrimaryAxesForCompose(container)
        axesOut = gobjects(0,1);
        if isempty(container) || ~isgraphics(container)
            return;
        end

        srcAxes = findall(container, 'Type', 'axes');
        if isempty(srcAxes)
            return;
        end

        keep = false(numel(srcAxes),1);
        for i = 1:numel(srcAxes)
            keep(i) = i_isPrimaryPlotAxes(srcAxes(i));
        end
        axesOut = srcAxes(keep);

        try
            [~, idx] = sort(double(axesOut), 'ascend');
            axesOut = axesOut(idx);
        catch
        end
    end

    function bbox = i_computeAxesBBoxNormalized(axList)
        bbox = [0 0 1 1];
        if isempty(axList)
            return;
        end

        mins = [inf inf];
        maxs = [-inf -inf];
        validCount = 0;
        for i = 1:numel(axList)
            ax = axList(i);
            if ~isgraphics(ax, 'axes')
                continue;
            end
            pos = i_getNormalizedPosition(ax);
            if ~all(isfinite(pos)) || numel(pos) < 4 || pos(3) <= 0 || pos(4) <= 0
                continue;
            end
            mins(1) = min(mins(1), pos(1));
            mins(2) = min(mins(2), pos(2));
            maxs(1) = max(maxs(1), pos(1) + pos(3));
            maxs(2) = max(maxs(2), pos(2) + pos(4));
            validCount = validCount + 1;
        end

        if validCount == 0
            return;
        end

        bbox = [mins(1) mins(2) max(1e-6, maxs(1)-mins(1)) max(1e-6, maxs(2)-mins(2))];
    end

    function posNorm = i_getNormalizedPosition(h)
        posNorm = [0 0 1 1];
        if isempty(h) || ~isgraphics(h)
            return;
        end
        try
            oldUnits = h.Units;
            h.Units = 'normalized';
            posNorm = double(h.Position);
            h.Units = oldUnits;
        catch
            try
                posNorm = double(h.Position);
            catch
                posNorm = [0 0 1 1];
            end
        end
        if ~isnumeric(posNorm) || numel(posNorm) < 4
            posNorm = [0 0 1 1];
        else
            posNorm = double(posNorm(1:4));
        end
    end

    function mappedPos = i_mapPositionBetweenBBoxes(pos, srcBBox, dstBBox)
        mappedPos = pos;

        if ~isnumeric(pos) || numel(pos) < 4
            mappedPos = [0 0 1 1];
            return;
        end
        if ~isnumeric(srcBBox) || numel(srcBBox) < 4
            srcBBox = [0 0 1 1];
        end
        if ~isnumeric(dstBBox) || numel(dstBBox) < 4
            dstBBox = [0 0 1 1];
        end

        srcW = max(1e-9, double(srcBBox(3)));
        srcH = max(1e-9, double(srcBBox(4)));
        dstW = max(1e-9, double(dstBBox(3)));
        dstH = max(1e-9, double(dstBBox(4)));

        x0 = (double(pos(1)) - double(srcBBox(1))) / srcW;
        y0 = (double(pos(2)) - double(srcBBox(2))) / srcH;
        w0 = double(pos(3)) / srcW;
        h0 = double(pos(4)) / srcH;

        mappedPos = [double(dstBBox(1)) + x0 * dstW, ...
                     double(dstBBox(2)) + y0 * dstH, ...
                     w0 * dstW, ...
                     h0 * dstH];
        mappedPos = i_clampRectNormalized(mappedPos);
    end

    function rectOut = i_clampRectNormalized(rectIn)
        rectOut = [0 0 1 1];
        if ~isnumeric(rectIn) || numel(rectIn) < 4
            return;
        end

        rectOut = double(rectIn(1:4));
        if ~all(isfinite(rectOut))
            rectOut = [0 0 1 1];
            return;
        end

        rectOut(3) = min(max(rectOut(3), 0.001), 1);
        rectOut(4) = min(max(rectOut(4), 0.001), 1);
        rectOut(1) = min(max(rectOut(1), 0), 1);
        rectOut(2) = min(max(rectOut(2), 0), 1);

        if rectOut(1) + rectOut(3) > 1
            rectOut(1) = max(0, 1 - rectOut(3));
        end
        if rectOut(2) + rectOut(4) > 1
            rectOut(2) = max(0, 1 - rectOut(4));
        end
    end

    function i_bringGraphicsToFront(hObj)
        if isempty(hObj) || ~isgraphics(hObj)
            return;
        end

        try
            uistack(hObj, 'top');
            return;
        catch
        end

        parentObj = [];
        try
            parentObj = hObj.Parent;
        catch
        end
        if isempty(parentObj) || ~isgraphics(parentObj)
            return;
        end

        try
            childrenNow = parentObj.Children;
            keepMask = true(size(childrenNow));
            for i = 1:numel(childrenNow)
                keepMask(i) = ~isequal(childrenNow(i), hObj);
            end
            parentObj.Children = [hObj; childrenNow(keepMask)];
        catch
        end
    end

    function report = i_verifyPanelLegendColorbarAssociations(panel)
        report = struct('brokenLegendCount', 0, 'brokenColorbarCount', 0);
        if isempty(panel) || ~isgraphics(panel)
            return;
        end

        lgds = findall(panel, 'Type', 'legend');
        for i = 1:numel(lgds)
            lg = lgds(i);
            if ~i_isLegendAssociatedWithPanelAxes(lg, panel)
                report.brokenLegendCount = report.brokenLegendCount + 1;
            end
        end

        cbs = findall(panel, 'Type', 'colorbar');
        for i = 1:numel(cbs)
            cb = cbs(i);
            if ~i_isColorbarAssociatedWithPanelAxes(cb, panel)
                report.brokenColorbarCount = report.brokenColorbarCount + 1;
            end
        end
    end

    function tf = i_isLegendAssociatedWithPanelAxes(lg, panel)
        tf = false;
        if isempty(lg) || ~isgraphics(lg, 'legend')
            return;
        end

        try
            if isprop(lg, 'Axes')
                ax = lg.Axes;
                if ~isempty(ax) && all(isgraphics(ax, 'axes'))
                    ok = true;
                    for j = 1:numel(ax)
                        if ~i_isDescendantOf(ax(j), panel)
                            ok = false;
                            break;
                        end
                    end
                    if ok
                        tf = true;
                        return;
                    end
                end
            end
        catch
        end

        try
            if isprop(lg, 'PlotChildren')
                pc = lg.PlotChildren;
                if ~isempty(pc)
                    ok = true;
                    for j = 1:numel(pc)
                        hostAx = [];
                        try
                            hostAx = ancestor(pc(j), 'axes');
                        catch
                        end
                        if isempty(hostAx) || ~i_isDescendantOf(hostAx, panel)
                            ok = false;
                            break;
                        end
                    end
                    if ok
                        tf = true;
                        return;
                    end
                end
            end
        catch
        end
    end

    function tf = i_isColorbarAssociatedWithPanelAxes(cb, panel)
        tf = false;
        if isempty(cb) || ~isgraphics(cb, 'colorbar')
            return;
        end

        try
            if isprop(cb, 'Axes')
                ax = cb.Axes;
                if ~isempty(ax) && isgraphics(ax, 'axes') && i_isDescendantOf(ax, panel)
                    tf = true;
                    return;
                end
            end
        catch
        end
    end

    function tf = i_isDescendantOf(obj, ancestorObj)
        tf = false;
        if isempty(obj) || isempty(ancestorObj)
            return;
        end

        current = obj;
        while ~isempty(current)
            if isequal(current, ancestorObj)
                tf = true;
                return;
            end
            next = [];
            try
                next = current.Parent;
            catch
                next = [];
            end
            if isempty(next)
                return;
            end
            current = next;
        end
    end

    function warningsOut = i_copyAndRemapAnnotations(srcFig, destFig, tilePos)
        warningsOut = strings(0,1);
        if isempty(srcFig) || ~isgraphics(srcFig, 'figure') || isempty(destFig) || ~isgraphics(destFig, 'figure')
            return;
        end

        figName = "(unnamed)";
        try
            nm = string(srcFig.Name);
            if strlength(strtrim(nm)) > 0
                figName = nm;
            end
        catch
        end

        allObjs = findall(srcFig);
        annObjs = gobjects(0,1);
        for ii = 1:numel(allObjs)
            obj = allObjs(ii);
            try
                cls = string(class(obj));
            catch
                cls = "";
            end

            isShapeClass = startsWith(cls, "matlab.graphics.shape.");
            if ~isShapeClass
                continue;
            end

            % Keep only figure-level annotations, not data-axes children
            parentAx = [];
            try
                parentAx = ancestor(obj, 'axes');
            catch
            end
            if ~isempty(parentAx)
                continue;
            end

            annObjs(end+1,1) = obj; %#ok<AGROW>
        end

        % Deterministic z-order rank from srcFig.Children:
        % rank by nearest ancestor that is directly under srcFig, then copy
        % annotations in ascending rank (bottom-to-top) so later copies stay on top.
        annRanks = inf(numel(annObjs),1);
        rootChildren = gobjects(0,1);
        childIds = [];
        try
            rootChildren = srcFig.Children;
            childIds = double(rootChildren);
        catch
            rootChildren = gobjects(0,1);
            childIds = [];
        end

        for ii = 1:numel(annObjs)
            anchor = annObjs(ii);

            if ~isempty(rootChildren)
                id = [];
                try, id = double(anchor); catch, end
                if ~isempty(id)
                    idx = find(childIds == id, 1, 'first');
                    if ~isempty(idx)
                        annRanks(ii) = idx;
                        continue;
                    end
                end
            end

            current = anchor;
            while ~isempty(current)
                parentObj = [];
                grandParentObj = [];
                try, parentObj = current.Parent; catch, parentObj = []; end
                if isempty(parentObj)
                    break;
                end
                try, grandParentObj = parentObj.Parent; catch, grandParentObj = []; end

                if isequal(parentObj, srcFig)
                    id = [];
                    try, id = double(current); catch, end
                    if ~isempty(id)
                        idx = find(childIds == id, 1, 'first');
                        if ~isempty(idx)
                            annRanks(ii) = idx;
                        end
                    end
                    break;
                elseif isequal(grandParentObj, srcFig)
                    id = [];
                    try, id = double(parentObj); catch, end
                    if ~isempty(id)
                        idx = find(childIds == id, 1, 'first');
                        if ~isempty(idx)
                            annRanks(ii) = idx;
                        end
                    end
                    break;
                else
                    current = parentObj;
                end
            end
        end

        [~, sortIdx] = sort(annRanks, 'ascend');
        annObjs = annObjs(sortIdx);

        for ii = 1:numel(annObjs)
            srcAnn = annObjs(ii);
            cls = "unknown";
            try
                cls = string(class(srcAnn));
            catch
            end

            unitsForWarn = "n/a";
            hasUnits = isprop(srcAnn, 'Units');
            oldUnits = "";
            restoreUnitsAfterRead = false;
            if hasUnits
                try
                    unitsForWarn = lower(string(srcAnn.Units));
                catch
                    unitsForWarn = "n/a";
                end
            end

            if hasUnits
                if ~strcmpi(char(unitsForWarn), 'normalized')
                    try
                        oldUnits = string(srcAnn.Units);
                        srcAnn.Units = 'normalized';
                        restoreUnitsAfterRead = true;
                        try
                            unitsForWarn = lower(string(srcAnn.Units));
                        catch
                            unitsForWarn = "normalized";
                        end
                    catch
                        warningsOut(end+1,1) = "Compose: fig=" + figName + " class=" + cls + " units=" + unitsForWarn + " action=skipped reason=units-not-normalizable"; %#ok<AGROW>
                        continue;
                    end
                end
            end

            copied = [];
            try
                copied = copyobj(srcAnn, destFig);
            catch ME
                warningsOut(end+1,1) = "Compose: fig=" + figName + " class=" + cls + " units=" + unitsForWarn + " action=skipped reason=copy-failed msg=" + string(ME.message); %#ok<AGROW>
                continue;
            end

            parentFig = [];
            try
                parentFig = ancestor(copied, 'figure');
            catch
            end
            if isempty(parentFig) || ~isequal(parentFig, destFig)
                try
                    delete(copied);
                catch
                end
                warningsOut(end+1,1) = "Compose: fig=" + figName + " class=" + cls + " units=" + unitsForWarn + " action=skipped reason=parent-mismatch-after-copy"; %#ok<AGROW>
                continue;
            end

            remapped = false;
            srcPos = [];
            X = [];
            Y = [];

            supportsPos = isprop(copied, 'Position');
            supportsXY = isprop(copied, 'X') && isprop(copied, 'Y');

            if supportsPos
                try
                    srcPos = srcAnn.Position;
                catch
                    srcPos = [];
                end
                if restoreUnitsAfterRead && hasUnits
                    try
                        srcAnn.Units = char(oldUnits);
                    catch
                    end
                    restoreUnitsAfterRead = false;
                end
            elseif supportsXY
                try
                    X = srcAnn.X;
                    Y = srcAnn.Y;
                catch
                    X = [];
                    Y = [];
                end
                if restoreUnitsAfterRead && hasUnits
                    try
                        srcAnn.Units = char(oldUnits);
                    catch
                    end
                    restoreUnitsAfterRead = false;
                end
            end

            if restoreUnitsAfterRead && hasUnits
                try
                    srcAnn.Units = char(oldUnits);
                catch
                end
                restoreUnitsAfterRead = false;
            end

            if isprop(copied, 'Position')
                try
                    if isnumeric(srcPos) && numel(srcPos) >= 4
                        newPos = [tilePos(1) + srcPos(1)*tilePos(3), ...
                                  tilePos(2) + srcPos(2)*tilePos(4), ...
                                  srcPos(3)*tilePos(3), ...
                                  srcPos(4)*tilePos(4)];
                        if isprop(copied, 'Units')
                            copied.Units = 'normalized';
                        end
                        copied.Position = newPos;
                        remapped = true;
                    end
                catch
                end
            end

            if ~remapped && isprop(copied, 'X') && isprop(copied, 'Y')
                try
                    if isnumeric(X) && isnumeric(Y)
                        copied.X = tilePos(1) + X .* tilePos(3);
                        copied.Y = tilePos(2) + Y .* tilePos(4);
                        remapped = true;
                    end
                catch
                end
            end

            if ~remapped
                try
                    delete(copied);
                catch
                end
                warningsOut(end+1,1) = "Compose: fig=" + figName + " class=" + cls + " units=" + unitsForWarn + " action=skipped reason=unsupported-coordinate-properties"; %#ok<AGROW>
            end
        end
    end

    % -------------------------------------------------------------------------
    % ComposeSpec v0 (Layout-Only Reproducibility Layer)
    %
    % Purpose:
    %   Extract reproducibility-relevant layout configuration from the UI
    %   without including figure identity or dynamic handles.
    %
    % Scope:
    %   - Grid dimensions
    %   - Final resolved physical size (cm)
    %   - Panel labeling configuration
    %
    % Explicitly Excluded:
    %   - Figure handles
    %   - explicitHandleCache
    %   - Scope/selection model
    %   - Export file paths
    %   - Styling adapters
    %
    % Determinism:
    %   This function performs no side effects and introduces no hidden state.
    %
    % Version:
    %   spec.version = 1
    % -------------------------------------------------------------------------
    function spec = i_buildComposeSpecFromUI(rows, cols, widthCm, heightCm)
        spec = struct( ...
            'version', 1, ...
            'grid', struct( ...
                'rows', rows, ...
                'cols', cols), ...
            'size', struct( ...
                'widthCm', widthCm, ...
                'heightCm', heightCm), ...
            'labels', struct( ...
                'enabled', logical(cbAutoLabel.Value), ...
                'position', string(ddLabelPos.Value), ...
                'fontSize', double(nfLabelFont.Value)));
    end

    function preset = i_getPublicationStylePreset(mode)
        switch mode
            case 1
                preset = struct( ...
                    'axesFont', 10, ...
                    'labelFont', 10, ...
                    'lineWidth', 1.2, ...
                    'markerSize', 7);
            case 2
                preset = struct( ...
                    'axesFont', 9, ...
                    'labelFont', 9, ...
                    'lineWidth', 1.0, ...
                    'markerSize', 6);
            case 3
                preset = struct( ...
                    'axesFont', 8, ...
                    'labelFont', 8, ...
                    'lineWidth', 0.8, ...
                    'markerSize', 5);
            otherwise
                preset = struct( ...
                    'axesFont', 9, ...
                    'labelFont', 9, ...
                    'lineWidth', 1.0, ...
                    'markerSize', 6);
        end
    end

    % -------------------------------------------------------------------------
    % ComposeSpec Preset System (UI-Level Only)
    %
    % Purpose:
    %   Allow saving and loading layout configuration without storing
    %   figure identity or dynamic handles.
    %
    % Scope:
    %   - Grid configuration
    %   - Physical size
    %   - Panel labeling options
    %
    % Behavior:
    %   Loading a spec updates UI controls only.
    %   It does NOT trigger Compose.
    %
    % Determinism:
    %   Compose execution remains unchanged.
    % -------------------------------------------------------------------------
    function i_applyComposeSpecToUI(spec)
        suppressUIStateSave = true;
        try
            if isfield(spec, 'grid') && isstruct(spec.grid)
                if isfield(spec.grid, 'rows') && isnumeric(spec.grid.rows) && isfinite(spec.grid.rows)
                    nfRows.Value = max(1, round(double(spec.grid.rows)));
                end
                if isfield(spec.grid, 'cols') && isnumeric(spec.grid.cols) && isfinite(spec.grid.cols)
                    nfCols.Value = max(1, round(double(spec.grid.cols)));
                end
            end

            ddWidthPreset.Value = 'Custom';
            onWidthPresetChanged();
            if isfield(spec, 'size') && isstruct(spec.size) && ...
                    isfield(spec.size, 'widthCm') && isnumeric(spec.size.widthCm) && isfinite(spec.size.widthCm)
                nfCustomWidth.Value = max(0.1, double(spec.size.widthCm));
            end

            if isfield(spec, 'labels') && isstruct(spec.labels)
                if isfield(spec.labels, 'enabled') && ~isempty(spec.labels.enabled)
                    cbAutoLabel.Value = logical(spec.labels.enabled);
                end
                if isfield(spec.labels, 'position') && ~isempty(spec.labels.position)
                    cand = string(spec.labels.position);
                    if any(string(ddLabelPos.Items) == cand)
                        ddLabelPos.Value = char(cand);
                    end
                end
                if isfield(spec.labels, 'fontSize') && isnumeric(spec.labels.fontSize) && isfinite(spec.labels.fontSize)
                    nfLabelFont.Value = max(1, double(spec.labels.fontSize));
                end
            end

            if isfield(spec, 'legend') && isstruct(spec.legend)
                if isfield(spec.legend, 'location') && ~isempty(spec.legend.location)
                    cand = lower(strtrim(string(spec.legend.location)));
                    insideSet = ["northwest","north","northeast","west","best","east","southwest","south","southeast"];
                    outsideSet = ["northoutside","southoutside","westoutside","eastoutside"];

                    if any(cand == outsideSet)
                        ddLegendPlacementMode.Value = 'Outside';
                        legendLocationState = char(cand);
                    elseif any(cand == insideSet)
                        ddLegendPlacementMode.Value = 'Inside';
                        legendLocationState = char(cand);
                    end
                end

                if isfield(spec.legend, 'fontSize')
                    if isnumeric(spec.legend.fontSize) && isfinite(spec.legend.fontSize) && spec.legend.fontSize > 0
                        efLegendFontSize.Value = char(string(double(spec.legend.fontSize)));
                    elseif isempty(spec.legend.fontSize)
                        efLegendFontSize.Value = '';
                    end
                end

                if isfield(spec.legend, 'placementMode') && ~isempty(spec.legend.placementMode)
                    cand = string(spec.legend.placementMode);
                    if any(string(ddLegendPlacementMode.Items) == cand)
                        ddLegendPlacementMode.Value = char(cand);
                    end
                end
            end

            onLegendPlacementModeChanged();

            applyFigs = i_getExplicitListTargetsNoAlert();
            if ~isempty(applyFigs)
                i_applyLegendLocationExistingOnly(applyFigs, legendLocationState);
            end
        catch ME
            suppressUIStateSave = false;
            uialert(ui, ME.message, 'Apply Layout Spec Failed');
            return;
        end

        suppressUIStateSave = false;
        i_saveUIState();
    end

    function s = i_panelLabel(idx)
        letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        if idx <= numel(letters)
            s = letters(idx);
            return;
        end

        first = floor((idx - 1) / numel(letters));
        second = mod((idx - 1), numel(letters)) + 1;
        if first <= numel(letters)
            s = [letters(first) letters(second)];
        else
            s = sprintf('P%d', idx);
        end
    end

    function i_loadUIState()
        oldSuppressUIStateSave = suppressUIStateSave;
        oldIsRestoringUIState = isRestoringUIState;
        suppressUIStateSave = true;
        isRestoringUIState = true;
        restoreGuard = onCleanup(@() i_restoreUIStateFlags(oldSuppressUIStateSave, oldIsRestoringUIState)); %#ok<NASGU>
        i_clearPendingRestore();

        up = userpath;
        if isempty(up)
            stateFile = fullfile(pwd, 'FCS_ui_state.mat');
        else
            parts = strsplit(up, pathsep);
            parts = parts(~cellfun(@isempty, parts));
            if isempty(parts)
                stateRoot = pwd;
            else
                stateRoot = parts{1};
            end
            stateFile = fullfile(stateRoot, 'FCS_ui_state.mat');
        end

        if exist(stateFile, 'file') ~= 2
            return;
        end

        try
            S = load(stateFile, 'uiState');
            if ~isstruct(S) || ~isfield(S, 'uiState') || ~isstruct(S.uiState)
                return;
            end
            uiState = S.uiState;

            if isfield(uiState, 'scopeMode') && ~isempty(uiState.scopeMode)
                cand = string(uiState.scopeMode);
                if any(string(ddScope.Items) == cand)
                    ddScope.Value = char(cand);
                end
            end
            if isfield(uiState, 'ddScope')
                i_tryAssignDropdownValue(ddScope, uiState.ddScope, 'ddScope');
            end
            if isfield(uiState, 'efTag')
                efTag.Value = uiState.efTag;
            end
            if isfield(uiState, 'efNameContains')
                efNameContains.Value = uiState.efNameContains;
            end
            if isfield(uiState, 'lbFigures')
                if i_tryAssignListboxValue(lbFigures, uiState.lbFigures, 'lbFigures')
                    i_clearPendingRestore();
                else
                    pendingRestore.lbFigures = uiState.lbFigures;
                    hasPendingRestore = true;
                end
            end
            if isfield(uiState, 'excludeKnownGUIs') && ~isempty(uiState.excludeKnownGUIs)
                cbExcludeGUIs.Value = logical(uiState.excludeKnownGUIs);
            end
            if isfield(uiState, 'cbExcludeGUIs')
                cbExcludeGUIs.Value = uiState.cbExcludeGUIs;
            end
            if isfield(uiState, 'nfGlobalFigWidth')
                nfGlobalFigWidth.Value = uiState.nfGlobalFigWidth;
            end
            if isfield(uiState, 'nfGlobalFigHeight')
                nfGlobalFigHeight.Value = uiState.nfGlobalFigHeight;
            end
            if isfield(uiState, 'gridRows') && isnumeric(uiState.gridRows) && isfinite(uiState.gridRows)
                nfRows.Value = max(1, round(double(uiState.gridRows)));
            end
            if isfield(uiState, 'nfRows')
                nfRows.Value = uiState.nfRows;
            end
            if isfield(uiState, 'gridCols') && isnumeric(uiState.gridCols) && isfinite(uiState.gridCols)
                nfCols.Value = max(1, round(double(uiState.gridCols)));
            end
            if isfield(uiState, 'nfCols')
                nfCols.Value = uiState.nfCols;
            end
            if isfield(uiState, 'nfFontSize')
                nfFontSize.Value = uiState.nfFontSize;
            end
            if isfield(uiState, 'ddAxisPreset')
                i_tryAssignDropdownValue(ddAxisPreset, uiState.ddAxisPreset, 'ddAxisPreset');
            end
            if isfield(uiState, 'ddTypoProfile')
                i_tryAssignDropdownValue(ddTypoProfile, uiState.ddTypoProfile, 'ddTypoProfile');
            end
            if isfield(uiState, 'widthPreset') && ~isempty(uiState.widthPreset)
                cand = string(uiState.widthPreset);
                if any(string(ddWidthPreset.Items) == cand)
                    ddWidthPreset.Value = char(cand);
                end
            end
            if isfield(uiState, 'ddWidthPreset')
                i_tryAssignDropdownValue(ddWidthPreset, uiState.ddWidthPreset, 'ddWidthPreset');
            end
            if isfield(uiState, 'customWidth') && isnumeric(uiState.customWidth) && isfinite(uiState.customWidth)
                nfCustomWidth.Value = max(0.1, double(uiState.customWidth));
            end
            if isfield(uiState, 'nfCustomWidth')
                nfCustomWidth.Value = uiState.nfCustomWidth;
            end
            if isfield(uiState, 'autoLabels') && ~isempty(uiState.autoLabels)
                cbAutoLabel.Value = logical(uiState.autoLabels);
            end
            if isfield(uiState, 'cbAutoLabel')
                cbAutoLabel.Value = uiState.cbAutoLabel;
            end
            if isfield(uiState, 'labelPosition') && ~isempty(uiState.labelPosition)
                cand = string(uiState.labelPosition);
                if any(string(ddLabelPos.Items) == cand)
                    ddLabelPos.Value = char(cand);
                end
            end
            if isfield(uiState, 'ddLabelPos')
                i_tryAssignDropdownValue(ddLabelPos, uiState.ddLabelPos, 'ddLabelPos');
            end
            if isfield(uiState, 'labelFontSize') && isnumeric(uiState.labelFontSize) && isfinite(uiState.labelFontSize)
                nfLabelFont.Value = max(1, double(uiState.labelFontSize));
            end
            if isfield(uiState, 'nfLabelFont')
                nfLabelFont.Value = uiState.nfLabelFont;
            end
            if isfield(uiState, 'composeHGap') && isnumeric(uiState.composeHGap) && isfinite(uiState.composeHGap)
                slComposeHGap.Value = i_quantizeSliderValue(double(uiState.composeHGap), [0 0.1], 0.001);
            end
            if isfield(uiState, 'slComposeHGap')
                slComposeHGap.Value = uiState.slComposeHGap;
            end
            if isfield(uiState, 'composeVGap') && isnumeric(uiState.composeVGap) && isfinite(uiState.composeVGap)
                slComposeVGap.Value = i_quantizeSliderValue(double(uiState.composeVGap), [0 0.1], 0.001);
            end
            if isfield(uiState, 'slComposeVGap')
                slComposeVGap.Value = uiState.slComposeVGap;
            end
            i_updateComposeGapLabels();
            if isfield(uiState, 'legendPlacementMode') && ~isempty(uiState.legendPlacementMode)
                cand = string(uiState.legendPlacementMode);
                if any(string(ddLegendPlacementMode.Items) == cand)
                    ddLegendPlacementMode.Value = char(cand);
                end
            end
            if isfield(uiState, 'efLegendFontSize')
                efLegendFontSize.Value = uiState.efLegendFontSize;
            end
            if isfield(uiState, 'ddLegendPlacementMode')
                i_tryAssignDropdownValue(ddLegendPlacementMode, uiState.ddLegendPlacementMode, 'ddLegendPlacementMode');
            end
            if isfield(uiState, 'legendLocation') && ~isempty(uiState.legendLocation)
                legendLocationState = char(string(uiState.legendLocation));
            end
            if isfield(uiState, 'manualLegendPositions')
                i_restoreManualLegendPositionState(uiState.manualLegendPositions);
            end
            if isfield(uiState, 'appearanceMapName') && ~isempty(uiState.appearanceMapName)
                cand = string(uiState.appearanceMapName);
                if any(string(ddCmap.Items) == cand)
                    ddCmap.Value = char(cand);
                end
            end
            if isfield(uiState, 'ddCmap')
                i_tryAssignDropdownValue(ddCmap, uiState.ddCmap, 'ddCmap');
            end
            if isfield(uiState, 'appearanceSpreadMode') && ~isempty(uiState.appearanceSpreadMode)
                cand = string(uiState.appearanceSpreadMode);
                if any(string(ddSpreadMode.Items) == cand)
                    ddSpreadMode.Value = char(cand);
                end
            end
            if isfield(uiState, 'ddSpreadMode')
                i_tryAssignDropdownValue(ddSpreadMode, uiState.ddSpreadMode, 'ddSpreadMode');
            end
            if isfield(uiState, 'appearanceSpreadReverse') && ~isempty(uiState.appearanceSpreadReverse)
                cbSpreadReverse.Value = logical(uiState.appearanceSpreadReverse);
            end
            if isfield(uiState, 'cbSpreadReverse')
                cbSpreadReverse.Value = uiState.cbSpreadReverse;
            end
            if isfield(uiState, 'bgWhiteFigure') && ~isempty(uiState.bgWhiteFigure)
                cbBgWhiteFigure.Value = logical(uiState.bgWhiteFigure);
            end
            if isfield(uiState, 'cbBgWhiteFigure')
                cbBgWhiteFigure.Value = uiState.cbBgWhiteFigure;
            end
            if isfield(uiState, 'bgTransparentAxes') && ~isempty(uiState.bgTransparentAxes)
                cbBgTransparentAxes.Value = logical(uiState.bgTransparentAxes);
            end
            if isfield(uiState, 'cbBgTransparentAxes')
                cbBgTransparentAxes.Value = uiState.cbBgTransparentAxes;
            end
            if isfield(uiState, 'dataLineStyle') && ~isempty(uiState.dataLineStyle)
                cand = string(uiState.dataLineStyle);
                if any(string(ddDataLineStyle.Items) == cand)
                    ddDataLineStyle.Value = char(cand);
                end
            end
            if isfield(uiState, 'ddDataLineStyle')
                i_tryAssignDropdownValue(ddDataLineStyle, uiState.ddDataLineStyle, 'ddDataLineStyle');
            end
            if isfield(uiState, 'dataLineWidth') && isnumeric(uiState.dataLineWidth) && isfinite(uiState.dataLineWidth)
                nfDataLineWidth.Value = max(0, double(uiState.dataLineWidth));
            end
            if isfield(uiState, 'nfDataLineWidth')
                nfDataLineWidth.Value = uiState.nfDataLineWidth;
            end
            if isfield(uiState, 'dataMarkerSize') && isnumeric(uiState.dataMarkerSize) && isfinite(uiState.dataMarkerSize)
                nfDataMarkerSize.Value = max(0, double(uiState.dataMarkerSize));
            end
            if isfield(uiState, 'nfDataMarkerSize')
                nfDataMarkerSize.Value = uiState.nfDataMarkerSize;
            end
            if isfield(uiState, 'fitLineStyle') && ~isempty(uiState.fitLineStyle)
                cand = string(uiState.fitLineStyle);
                if any(string(ddFitLineStyle.Items) == cand)
                    ddFitLineStyle.Value = char(cand);
                end
            end
            if isfield(uiState, 'ddFitLineStyle')
                i_tryAssignDropdownValue(ddFitLineStyle, uiState.ddFitLineStyle, 'ddFitLineStyle');
            end
            if isfield(uiState, 'fitLineWidth') && isnumeric(uiState.fitLineWidth) && isfinite(uiState.fitLineWidth)
                nfFitLineWidth.Value = max(0, double(uiState.fitLineWidth));
            end
            if isfield(uiState, 'nfFitLineWidth')
                nfFitLineWidth.Value = uiState.nfFitLineWidth;
            end
            if isfield(uiState, 'fitMarkerSize') && isnumeric(uiState.fitMarkerSize) && isfinite(uiState.fitMarkerSize)
                nfFitMarkerSize.Value = max(0, double(uiState.fitMarkerSize));
            end
            if isfield(uiState, 'nfFitMarkerSize')
                nfFitMarkerSize.Value = uiState.nfFitMarkerSize;
            end
            if isfield(uiState, 'refLineWidth') && isnumeric(uiState.refLineWidth) && isfinite(uiState.refLineWidth)
                nfRefLineWidth.Value = max(0, double(uiState.refLineWidth));
            end
            if isfield(uiState, 'nfRefLineWidth')
                nfRefLineWidth.Value = uiState.nfRefLineWidth;
            end
            if isfield(uiState, 'refLineStyle') && ~isempty(uiState.refLineStyle)
                cand = string(uiState.refLineStyle);
                if any(string(ddRefLineStyle.Items) == cand)
                    ddRefLineStyle.Value = char(cand);
                end
            end
            if isfield(uiState, 'ddRefLineStyle')
                i_tryAssignDropdownValue(ddRefLineStyle, uiState.ddRefLineStyle, 'ddRefLineStyle');
            end
            if isfield(uiState, 'refLineColor') && ~isempty(uiState.refLineColor)
                efRefLineColor.Value = char(string(uiState.refLineColor));
            end
            if isfield(uiState, 'efRefLineColor')
                efRefLineColor.Value = uiState.efRefLineColor;
            end
            if isfield(uiState, 'annFontName') && ~isempty(uiState.annFontName)
                efAnnFontName.Value = char(string(uiState.annFontName));
            end
            if isfield(uiState, 'efAnnFontName')
                efAnnFontName.Value = uiState.efAnnFontName;
            end
            if isfield(uiState, 'annFontSize') && isnumeric(uiState.annFontSize) && isfinite(uiState.annFontSize)
                nfAnnFontSize.Value = max(1, double(uiState.annFontSize));
            end
            if isfield(uiState, 'nfAnnFontSize')
                nfAnnFontSize.Value = uiState.nfAnnFontSize;
            end
            if isfield(uiState, 'annFontWeight') && ~isempty(uiState.annFontWeight)
                cand = lower(strtrim(string(uiState.annFontWeight)));
                if any(string(ddAnnFontWeight.Items) == cand)
                    ddAnnFontWeight.Value = char(cand);
                end
            end
            if isfield(uiState, 'ddAnnFontWeight')
                i_tryAssignDropdownValue(ddAnnFontWeight, uiState.ddAnnFontWeight, 'ddAnnFontWeight');
            end
            if isfield(uiState, 'annInterpreter') && ~isempty(uiState.annInterpreter)
                cand = lower(strtrim(string(uiState.annInterpreter)));
                if any(string(ddAnnInterpreter.Items) == cand)
                    ddAnnInterpreter.Value = char(cand);
                end
            end
            if isfield(uiState, 'ddAnnInterpreter')
                i_tryAssignDropdownValue(ddAnnInterpreter, uiState.ddAnnInterpreter, 'ddAnnInterpreter');
            end
            if isfield(uiState, 'annColor') && ~isempty(uiState.annColor)
                efAnnColor.Value = char(string(uiState.annColor));
            end
            if isfield(uiState, 'efAnnColor')
                efAnnColor.Value = uiState.efAnnColor;
            end
            if isfield(uiState, 'targetWidthCm') && isnumeric(uiState.targetWidthCm) && isfinite(uiState.targetWidthCm)
                nfWsWidth.Value = min(max(double(uiState.targetWidthCm), 5), 40);
            end
            if isfield(uiState, 'widthCm') && isnumeric(uiState.widthCm) && isfinite(uiState.widthCm)
                nfWsWidth.Value = min(max(double(uiState.widthCm), 5), 40);
            end
            if isfield(uiState, 'nfWsWidth')
                nfWsWidth.Value = uiState.nfWsWidth;
            end
            % Legacy uiState fields heightMode/ddWsHeightMode/heightCm/nfWsHeight are ignored.
            if isfield(uiState, 'baseRatio') && isnumeric(uiState.baseRatio) && isfinite(uiState.baseRatio)
                nfWsBaseRatio.Value = min(max(double(uiState.baseRatio), 0.3), 2);
            end
            if isfield(uiState, 'nfWsBaseRatio')
                nfWsBaseRatio.Value = uiState.nfWsBaseRatio;
            end
            i_updateWorkspaceHeightDisplay();

            if isfield(uiState, 'scaleX') && isnumeric(uiState.scaleX) && isfinite(uiState.scaleX)
                slAxScaleX.Value = i_quantizeSliderValue(double(uiState.scaleX), [0.5 1.5], 0.01);
            elseif isfield(uiState, 'axesTransformScaleX') && isnumeric(uiState.axesTransformScaleX) && isfinite(uiState.axesTransformScaleX)
                slAxScaleX.Value = i_quantizeSliderValue(double(uiState.axesTransformScaleX), [0.5 1.5], 0.01);
            elseif isfield(uiState, 'axesTransformScale') && isnumeric(uiState.axesTransformScale) && isfinite(uiState.axesTransformScale)
                slAxScaleX.Value = i_quantizeSliderValue(double(uiState.axesTransformScale), [0.5 1.5], 0.01);
            else
                slAxScaleX.Value = 1.0;
            end

            if isfield(uiState, 'scaleY') && isnumeric(uiState.scaleY) && isfinite(uiState.scaleY)
                slAxScaleY.Value = i_quantizeSliderValue(double(uiState.scaleY), [0.5 1.5], 0.01);
            elseif isfield(uiState, 'axesTransformScaleY') && isnumeric(uiState.axesTransformScaleY) && isfinite(uiState.axesTransformScaleY)
                slAxScaleY.Value = i_quantizeSliderValue(double(uiState.axesTransformScaleY), [0.5 1.5], 0.01);
            elseif isfield(uiState, 'axesTransformScale') && isnumeric(uiState.axesTransformScale) && isfinite(uiState.axesTransformScale)
                slAxScaleY.Value = i_quantizeSliderValue(double(uiState.axesTransformScale), [0.5 1.5], 0.01);
            else
                slAxScaleY.Value = 1.0;
            end

            if isfield(uiState, 'slAxScaleX')
                slAxScaleX.Value = uiState.slAxScaleX;
            end
            if isfield(uiState, 'slAxScaleY')
                slAxScaleY.Value = uiState.slAxScaleY;
            end

            if isfield(uiState, 'offsetX') && isnumeric(uiState.offsetX) && isfinite(uiState.offsetX)
                slAxOffsetX.Value = i_quantizeSliderValue(double(uiState.offsetX), [-0.2 0.2], 0.01);
            elseif isfield(uiState, 'axesTransformOffsetX') && isnumeric(uiState.axesTransformOffsetX) && isfinite(uiState.axesTransformOffsetX)
                slAxOffsetX.Value = i_quantizeSliderValue(double(uiState.axesTransformOffsetX), [-0.2 0.2], 0.01);
            end
            if isfield(uiState, 'slAxOffsetX')
                slAxOffsetX.Value = uiState.slAxOffsetX;
            end
            if isfield(uiState, 'offsetY') && isnumeric(uiState.offsetY) && isfinite(uiState.offsetY)
                slAxOffsetY.Value = i_quantizeSliderValue(double(uiState.offsetY), [-0.2 0.2], 0.01);
            elseif isfield(uiState, 'axesTransformOffsetY') && isnumeric(uiState.axesTransformOffsetY) && isfinite(uiState.axesTransformOffsetY)
                slAxOffsetY.Value = i_quantizeSliderValue(double(uiState.axesTransformOffsetY), [-0.2 0.2], 0.01);
            end
            if isfield(uiState, 'slAxOffsetY')
                slAxOffsetY.Value = uiState.slAxOffsetY;
            end
            i_updateAxesTransformLabels();
            if isfield(uiState, 'reversePlotOrder') && ~isempty(uiState.reversePlotOrder)
                cbReversePlotOrder.Value = logical(uiState.reversePlotOrder);
            end
            if isfield(uiState, 'ddPanelsPerRow')
                i_tryAssignDropdownValue(ddPanelsPerRow, uiState.ddPanelsPerRow, 'ddPanelsPerRow');
            end
            if isfield(uiState, 'cbReversePlotOrder')
                cbReversePlotOrder.Value = uiState.cbReversePlotOrder;
            end
            if isfield(uiState, 'panelsPerRow') && ~isempty(uiState.panelsPerRow)
                cand = string(uiState.panelsPerRow);
                if any(string(ddPanelsPerRow.Items) == cand)
                    ddPanelsPerRow.Value = char(cand);
                end
            end
            if isfield(uiState, 'exportComposedOnly') && ~isempty(uiState.exportComposedOnly)
                cbExportComposedOnly.Value = logical(uiState.exportComposedOnly);
            end
            if isfield(uiState, 'ddExportFmt')
                i_tryAssignDropdownValue(ddExportFmt, uiState.ddExportFmt, 'ddExportFmt');
            end
            if isfield(uiState, 'exportJournal')
                i_tryAssignDropdownValue(ddExportJournal, uiState.exportJournal, 'exportJournal');
            end
            if isfield(uiState, 'exportColumn')
                i_tryAssignDropdownValue(ddExportColumn, uiState.exportColumn, 'exportColumn');
            elseif isfield(uiState, 'prlMode')
                i_tryAssignDropdownValue(ddExportColumn, uiState.prlMode, 'exportColumn');
            end
            if isfield(uiState, 'cbVector')
                cbVector.Value = uiState.cbVector;
            end
            if isfield(uiState, 'cbOverwrite')
                cbOverwrite.Value = uiState.cbOverwrite;
            end
            if isfield(uiState, 'ddFilenameFrom')
                i_tryAssignDropdownValue(ddFilenameFrom, uiState.ddFilenameFrom, 'ddFilenameFrom');
            end
            if isfield(uiState, 'cbExportComposedOnly')
                cbExportComposedOnly.Value = logical(uiState.cbExportComposedOnly);
            end
            if isfield(uiState, 'exportOutDir')
                efExportDir.Value = char(string(uiState.exportOutDir));
            end
            i_updateAxesTransformLabels();
            i_updateComposeGapLabels();
            i_debugUIStateDiff('after i_loadUIState');
        catch
            % Graceful fallback to defaults/UI creation values
        end
    end

    function tf = i_tryAssignDropdownValue(ctrl, savedValue, fieldName)
        tf = false;
        try
            items = string(ctrl.Items);
            cand = string(savedValue);
            if isempty(cand)
                i_diagNote(sprintf('restore skipped for %s: empty saved value', fieldName));
                return;
            end
            cand = cand(1);
            if ~any(items == cand)
                i_diagNote(sprintf('restore skipped for %s: value not in Items (%s)', fieldName, char(cand)));
                return;
            end
            ctrl.Value = char(cand);
            tf = true;
        catch ME
            i_diagNote(sprintf('restore failed for %s: %s', fieldName, ME.message));
        end
    end

    function tf = i_tryAssignListboxValue(ctrl, savedValue, fieldName)
        tf = false;
        try
            if isnumeric(savedValue)
                selected = double(savedValue(:));
                if isempty(selected)
                    ctrl.Value = [];
                    tf = true;
                    return;
                end
                itemsData = ctrl.ItemsData;
                if ~isnumeric(itemsData)
                    i_diagNote(sprintf('restore skipped for %s: ItemsData not numeric', fieldName));
                    return;
                end
                ids = double(itemsData(:));
                valid = selected(ismember(selected, ids));
                if isempty(valid)
                    i_diagNote(sprintf('restore skipped for %s: no valid selection in ItemsData', fieldName));
                    return;
                end
                ctrl.Value = unique(valid, 'stable');
                tf = true;
                return;
            end

            if ischar(savedValue) || isstring(savedValue) || iscell(savedValue)
                ctrl.Value = savedValue;
                tf = true;
                return;
            end

            i_diagNote(sprintf('restore skipped for %s: unsupported value type (%s)', fieldName, class(savedValue)));
        catch ME
            i_diagNote(sprintf('restore failed for %s: %s', fieldName, ME.message));
        end
    end

    function i_diagNote(msg)
        if ~enableUIDiag
            return;
        end
        fprintf('%s\n', msg);
        i_appendDebugToDiag(msg);
    end

    function i_debugUIStateDiff(stageLabel)
        if ~enableUIDiag
            return;
        end

        up = userpath;
        if isempty(up)
            stateFile = fullfile(pwd, 'FCS_ui_state.mat');
        else
            parts = strsplit(up, pathsep);
            parts = parts(~cellfun(@isempty, parts));
            if isempty(parts)
                stateRoot = pwd;
            else
                stateRoot = parts{1};
            end
            stateFile = fullfile(stateRoot, 'FCS_ui_state.mat');
        end

        if exist(stateFile, 'file') ~= 2
            i_appendDebugToDiag(sprintf('[%s] uiState file not found.', char(string(stageLabel))));
            return;
        end

        try
            S = load(stateFile, 'uiState');
            if ~isstruct(S) || ~isfield(S, 'uiState') || ~isstruct(S.uiState)
                i_appendDebugToDiag(sprintf('[%s] uiState missing/invalid.', char(string(stageLabel))));
                return;
            end
            uiState = S.uiState;

            fieldNames = {
                'ddScope','efTag','efNameContains','lbFigures','cbExcludeGUIs', ...
                'nfGlobalFigWidth','nfGlobalFigHeight','nfRows','nfCols', ...
                'nfFontSize','ddAxisPreset','ddTypoProfile', ...
                'efLegendFontSize','ddLegendPlacementMode', ...
                'ddCmap','ddSpreadMode','cbSpreadReverse','cbBgWhiteFigure','cbBgTransparentAxes', ...
                'ddDataLineStyle','nfDataLineWidth','nfDataMarkerSize','ddFitLineStyle','nfFitLineWidth','nfFitMarkerSize', ...
                'nfRefLineWidth','ddRefLineStyle','efRefLineColor', ...
                'efAnnFontName','nfAnnFontSize','ddAnnFontWeight','ddAnnInterpreter','efAnnColor', ...
                'nfWsWidth','nfWsBaseRatio', ...
                'slAxScaleX','slAxScaleY','slAxOffsetX','slAxOffsetY', ...
                'ddPanelsPerRow','cbReversePlotOrder', ...
                'ddExportFmt','exportJournal','exportColumn','cbVector','cbOverwrite','ddFilenameFrom','cbExportComposedOnly','exportOutDir'};

            currentValues = {
                ddScope.Value, efTag.Value, efNameContains.Value, lbFigures.Value, cbExcludeGUIs.Value, ...
                nfGlobalFigWidth.Value, nfGlobalFigHeight.Value, nfRows.Value, nfCols.Value, ...
                nfFontSize.Value, ddAxisPreset.Value, ddTypoProfile.Value, ...
                efLegendFontSize.Value, ddLegendPlacementMode.Value, ...
                ddCmap.Value, ddSpreadMode.Value, cbSpreadReverse.Value, cbBgWhiteFigure.Value, cbBgTransparentAxes.Value, ...
                ddDataLineStyle.Value, nfDataLineWidth.Value, nfDataMarkerSize.Value, ddFitLineStyle.Value, nfFitLineWidth.Value, nfFitMarkerSize.Value, ...
                nfRefLineWidth.Value, ddRefLineStyle.Value, efRefLineColor.Value, ...
                efAnnFontName.Value, nfAnnFontSize.Value, ddAnnFontWeight.Value, ddAnnInterpreter.Value, efAnnColor.Value, ...
                nfWsWidth.Value, nfWsBaseRatio.Value, ...
                slAxScaleX.Value, slAxScaleY.Value, slAxOffsetX.Value, slAxOffsetY.Value, ...
                ddPanelsPerRow.Value, cbReversePlotOrder.Value, ...
                ddExportFmt.Value, ddExportJournal.Value, ddExportColumn.Value, cbVector.Value, cbOverwrite.Value, ddFilenameFrom.Value, cbExportComposedOnly.Value, efExportDir.Value};

            diffs = {};
            for iField = 1:numel(fieldNames)
                fName = fieldNames{iField};
                if ~isfield(uiState, fName)
                    continue;
                end
                savedValue = uiState.(fName);
                currentValue = currentValues{iField};
                if i_valuesEqual(savedValue, currentValue)
                    continue;
                end
                diffs{end+1,1} = sprintf('%s | saved=%s | current=%s', ...
                    fName, i_valueToText(savedValue), i_valueToText(currentValue));
            end

            header = sprintf('[%s] uiState diff count: %d', char(string(stageLabel)), numel(diffs));
            fprintf('%s\n', header);
            if isempty(diffs)
                i_appendDebugToDiag(header);
            else
                outLines = [{header}; diffs(:)];
                for iLine = 1:numel(outLines)
                    fprintf('  %s\n', outLines{iLine});
                end
                i_appendDebugToDiag(outLines);
            end
        catch ME
            i_appendDebugToDiag(sprintf('[%s] uiState diff failed: %s', char(string(stageLabel)), ME.message));
        end
    end

    function tf = i_valuesEqual(a, b)
        try
            tf = isequaln(a, b);
            if tf
                return;
            end
        catch
        end
        try
            tf = isequaln(string(a), string(b));
            if tf
                return;
            end
        catch
        end
        try
            if isnumeric(a) && isnumeric(b)
                tf = isequaln(double(a), double(b));
                return;
            end
        catch
        end
        tf = false;
    end

    function txt = i_valueToText(v)
        try
            if isstring(v)
                txt = char(strjoin(v(:), ','));
                return;
            end
            if ischar(v)
                txt = v;
                return;
            end
            if isnumeric(v) || islogical(v)
                txt = mat2str(v);
                return;
            end
            if iscell(v)
                if iscellstr(v)
                    txt = ['{' strjoin(v(:)', ', ') '}'];
                else
                    txt = ['<cell ' mat2str(size(v)) '>'];
                end
                return;
            end
            txt = ['<' class(v) '>'];
        catch
            txt = '<unprintable>';
        end
    end

    function i_appendDebugToDiag(linesIn)
        if nargin < 1 || isempty(linesIn)
            return;
        end

        if ischar(linesIn) || isstring(linesIn)
            newLines = cellstr(string(linesIn));
        else
            newLines = cellstr(string(linesIn(:)));
        end

        try
            if isgraphics(taDiag)
                current = taDiag.Value;
                if ischar(current) || isstring(current)
                    current = cellstr(string(current));
                end
                taDiag.Value = [current(:); newLines(:)];
            end
        catch
        end
    end

    function i_saveUIState()
        if suppressUIStateSave
            return;
        end

        uiState = struct();
        uiState.scopeMode = string(ddScope.Value);
        uiState.ddScope = ddScope.Value;
        uiState.efTag = efTag.Value;
        uiState.efNameContains = efNameContains.Value;
        uiState.lbFigures = lbFigures.Value;
        uiState.excludeKnownGUIs = logical(cbExcludeGUIs.Value);
        uiState.cbExcludeGUIs = cbExcludeGUIs.Value;
        uiState.nfGlobalFigWidth = nfGlobalFigWidth.Value;
        uiState.nfGlobalFigHeight = nfGlobalFigHeight.Value;
        uiState.gridRows = double(nfRows.Value);
        uiState.nfRows = nfRows.Value;
        uiState.gridCols = double(nfCols.Value);
        uiState.nfCols = nfCols.Value;
        uiState.nfFontSize = nfFontSize.Value;
        uiState.ddAxisPreset = ddAxisPreset.Value;
        uiState.ddTypoProfile = ddTypoProfile.Value;
        uiState.widthPreset = string(ddWidthPreset.Value);
        uiState.ddWidthPreset = ddWidthPreset.Value;
        uiState.customWidth = double(nfCustomWidth.Value);
        uiState.nfCustomWidth = nfCustomWidth.Value;
        uiState.autoLabels = logical(cbAutoLabel.Value);
        uiState.cbAutoLabel = cbAutoLabel.Value;
        uiState.labelPosition = string(ddLabelPos.Value);
        uiState.ddLabelPos = ddLabelPos.Value;
        uiState.labelFontSize = double(nfLabelFont.Value);
        uiState.nfLabelFont = nfLabelFont.Value;
        uiState.composeHGap = double(slComposeHGap.Value);
        uiState.slComposeHGap = slComposeHGap.Value;
        uiState.composeVGap = double(slComposeVGap.Value);
        uiState.slComposeVGap = slComposeVGap.Value;
        uiState.efLegendFontSize = efLegendFontSize.Value;
        uiState.legendPlacementMode = string(ddLegendPlacementMode.Value);
        uiState.ddLegendPlacementMode = ddLegendPlacementMode.Value;
        uiState.legendLocation = string(legendLocationState);
        uiState.manualLegendPositions = i_serializeManualLegendPositionState();
        uiState.appearanceMapName = string(ddCmap.Value);
        uiState.ddCmap = ddCmap.Value;
        uiState.appearanceSpreadMode = string(ddSpreadMode.Value);
        uiState.ddSpreadMode = ddSpreadMode.Value;
        uiState.appearanceSpreadReverse = logical(cbSpreadReverse.Value);
        uiState.cbSpreadReverse = cbSpreadReverse.Value;
        uiState.bgWhiteFigure = logical(cbBgWhiteFigure.Value);
        uiState.cbBgWhiteFigure = cbBgWhiteFigure.Value;
        uiState.bgTransparentAxes = logical(cbBgTransparentAxes.Value);
        uiState.cbBgTransparentAxes = cbBgTransparentAxes.Value;
        uiState.dataLineStyle = string(ddDataLineStyle.Value);
        uiState.ddDataLineStyle = ddDataLineStyle.Value;
        uiState.dataLineWidth = double(nfDataLineWidth.Value);
        uiState.nfDataLineWidth = nfDataLineWidth.Value;
        uiState.dataMarkerSize = double(nfDataMarkerSize.Value);
        uiState.nfDataMarkerSize = nfDataMarkerSize.Value;
        uiState.fitLineStyle = string(ddFitLineStyle.Value);
        uiState.ddFitLineStyle = ddFitLineStyle.Value;
        uiState.fitLineWidth = double(nfFitLineWidth.Value);
        uiState.nfFitLineWidth = nfFitLineWidth.Value;
        uiState.fitMarkerSize = double(nfFitMarkerSize.Value);
        uiState.nfFitMarkerSize = nfFitMarkerSize.Value;
        uiState.refLineWidth = double(nfRefLineWidth.Value);
        uiState.nfRefLineWidth = nfRefLineWidth.Value;
        uiState.refLineStyle = string(ddRefLineStyle.Value);
        uiState.ddRefLineStyle = ddRefLineStyle.Value;
        uiState.refLineColor = string(efRefLineColor.Value);
        uiState.efRefLineColor = efRefLineColor.Value;
        uiState.annFontName = string(efAnnFontName.Value);
        uiState.efAnnFontName = efAnnFontName.Value;
        uiState.annFontSize = double(nfAnnFontSize.Value);
        uiState.nfAnnFontSize = nfAnnFontSize.Value;
        uiState.annFontWeight = string(ddAnnFontWeight.Value);
        uiState.ddAnnFontWeight = ddAnnFontWeight.Value;
        uiState.annInterpreter = string(ddAnnInterpreter.Value);
        uiState.ddAnnInterpreter = ddAnnInterpreter.Value;
        uiState.annColor = string(efAnnColor.Value);
        uiState.efAnnColor = efAnnColor.Value;
        uiState.widthCm = double(nfWsWidth.Value);
        uiState.baseRatio = double(nfWsBaseRatio.Value);
        uiState.scaleX = double(slAxScaleX.Value);
        uiState.scaleY = double(slAxScaleY.Value);
        uiState.offsetX = double(slAxOffsetX.Value);
        uiState.offsetY = double(slAxOffsetY.Value);
        uiState.reversePlotOrder = logical(cbReversePlotOrder.Value);
        uiState.cbReversePlotOrder = cbReversePlotOrder.Value;
        uiState.panelsPerRow = string(ddPanelsPerRow.Value);
        uiState.ddPanelsPerRow = ddPanelsPerRow.Value;
        uiState.ddExportFmt = ddExportFmt.Value;
        uiState.exportJournal = ddExportJournal.Value;
        uiState.exportColumn = ddExportColumn.Value;
        uiState.cbVector = cbVector.Value;
        uiState.cbOverwrite = cbOverwrite.Value;
        uiState.ddFilenameFrom = ddFilenameFrom.Value;
        uiState.exportComposedOnly = logical(cbExportComposedOnly.Value);
        uiState.cbExportComposedOnly = cbExportComposedOnly.Value;
        uiState.exportOutDir = string(efExportDir.Value);

        up = userpath;
        if isempty(up)
            stateFile = fullfile(pwd, 'FCS_ui_state.mat');
        else
            parts = strsplit(up, pathsep);
            parts = parts(~cellfun(@isempty, parts));
            if isempty(parts)
                stateRoot = pwd;
            else
                stateRoot = parts{1};
            end
            stateFile = fullfile(stateRoot, 'FCS_ui_state.mat');
        end

        try
            save(stateFile, 'uiState');
        catch
            % Best-effort persistence only
        end
    end

    function restorePaperProps(fig, orig)
        fig.PaperUnits = orig.PaperUnits;
        fig.PaperPosition = orig.PaperPosition;
        fig.PaperSize = orig.PaperSize;
        fig.PaperPositionMode = orig.PaperPositionMode;
        fig.InvertHardcopy = orig.InvertHardcopy;
    end

    function i_scalePanel(container, scaleFactor)
        % Minimal scaling of FontSize and LineWidth for axes in container
        if nargin < 2 || ~isnumeric(scaleFactor) || scaleFactor <= 0
            return;
        end
        
        axList = findall(container, 'Type', 'axes');
        for i = 1:numel(axList)
            ax = axList(i);
            if ~isgraphics(ax)
                continue;
            end
            
            try
                if isprop(ax, 'FontSize')
                    ax.FontSize = ax.FontSize * scaleFactor;
                end
            catch
            end
            
            try
                if isprop(ax, 'LineWidth')
                    ax.LineWidth = ax.LineWidth * scaleFactor;
                end
            catch
            end
        end
    end
end
