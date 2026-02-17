function FigureControlStudio()
% FigureControlStudio
% Modern uifigure-based control studio for existing MATLAB figures.
% Orchestrates only explicit target resolution + adapter actions.
% NOTE:
%   ComposeSpec v0 extraction implemented via i_buildComposeSpecFromUI.
%   This supports future artifact-level reproducibility.
%   See documentation generator for ComposeSpec section.

    ui = uifigure('Name', 'FigureControlStudio', 'Position', [100 100 900 600]);

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
    tgtGrid = uigridlayout(targetPanel, [12 1]);
    tgtGrid.RowHeight = {22, 22, 22, 22, 28, 28, '1x', 22, 24, 22, 28, 1};
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

    cbExcludeGUIs = uicheckbox(tgtGrid, 'Text', 'Exclude Known GUIs', 'Value', true, 'ValueChangedFcn', @onExcludeChanged);

    lblDetected = uilabel(tgtGrid, 'Text', 'Detected: 0');
    lblHint = uilabel(tgtGrid, 'Text', 'Tip: Use Refresh for Explicit List mode');
    lblHint.FontColor = [0.35 0.35 0.35];
    btnResetDefaults = uibutton(tgtGrid, 'Text', 'Reset to Defaults', 'ButtonPushedFcn', @onResetDefaults);

    % explicit-list cache
    explicitHandleCache = gobjects(0,1);

    % ---------------- Tab 1: Typography ----------------
    tTypo = uitab(tabs, 'Title', 'Typography');
    tabRootTypo = uigridlayout(tTypo, [3 1]);
    tabRootTypo.RowHeight = {'fit', '1x', 'fit'};
    tabRootTypo.ColumnWidth = {'1x'};
    tabRootTypo.Padding = [12 12 12 12];

    secTypoMain = uigridlayout(tabRootTypo, [2 2]);
    secTypoMain.Layout.Row = 1;
    secTypoMain.Layout.Column = 1;
    secTypoMain.ColumnWidth = {170, '1x'};
    secTypoMain.RowHeight = {'fit', 'fit'};
    secTypoMain.Padding = [0 0 0 0];

    lblTypoFontSize = uilabel(secTypoMain, 'Text', 'Font Size', 'HorizontalAlignment', 'left');
    lblTypoFontSize.Layout.Row = 1;
    lblTypoFontSize.Layout.Column = 1;
    nfFontSize = uieditfield(secTypoMain, 'numeric', 'Value', 11, 'Limits', [1 Inf], 'RoundFractionalValues', true);
    nfFontSize.Layout.Row = 1;
    nfFontSize.Layout.Column = 2;

    lblTypoAxisPreset = uilabel(secTypoMain, 'Text', 'Axis Policy preset', 'HorizontalAlignment', 'left');
    lblTypoAxisPreset.Layout.Row = 2;
    lblTypoAxisPreset.Layout.Column = 1;
    ddAxisPreset = uidropdown(secTypoMain, 'Items', {'paper'}, 'Value', 'paper');
    ddAxisPreset.Layout.Row = 2;
    ddAxisPreset.Layout.Column = 2;

    typoActionBar = uigridlayout(tabRootTypo, [1 1]);
    typoActionBar.Layout.Row = 3;
    typoActionBar.Layout.Column = 1;
    typoActionBar.ColumnWidth = {'1x'};
    typoActionBar.RowHeight = {'fit'};
    typoActionBar.Padding = [0 0 0 0];

    btnApplyTypo = uibutton(typoActionBar, 'Text', 'Apply', 'ButtonPushedFcn', @onApplyTypography);
    btnApplyTypo.Layout.Row = 1;
    btnApplyTypo.Layout.Column = 1;

    % ---------------- Tab 2: Legend ----------------
    tLegend = uitab(tabs, 'Title', 'Legend');
    tabRootLegend = uigridlayout(tLegend, [4 1]);
    tabRootLegend.RowHeight = {'fit', 'fit', '1x', 'fit'};
    tabRootLegend.ColumnWidth = {'1x'};
    tabRootLegend.Padding = [12 12 12 12];

    secLegendA = uigridlayout(tabRootLegend, [4 2]);
    secLegendA.Layout.Row = 1;
    secLegendA.Layout.Column = 1;
    secLegendA.ColumnWidth = {170, '1x'};
    secLegendA.RowHeight = {'fit', 'fit', 'fit', 'fit'};
    secLegendA.Padding = [0 0 0 0];

    lblLegendFontOverride = uilabel(secLegendA, 'Text', 'Font Size (override)', 'HorizontalAlignment', 'left');
    lblLegendFontOverride.Layout.Row = 1;
    lblLegendFontOverride.Layout.Column = 1;
    efLegendFontSize = uieditfield(secLegendA, 'text', 'Placeholder', '(inherit base)');
    efLegendFontSize.Layout.Row = 1;
    efLegendFontSize.Layout.Column = 2;

    lblLegendPlacementMode = uilabel(secLegendA, 'Text', 'Placement mode', 'HorizontalAlignment', 'left');
    lblLegendPlacementMode.Layout.Row = 2;
    lblLegendPlacementMode.Layout.Column = 1;
    ddLegendPlacementMode = uidropdown(secLegendA, 'Items', {'Inside','Outside'}, 'Value', 'Inside', ...
        'ValueChangedFcn', @onLegendPlacementModeChanged);
    ddLegendPlacementMode.Layout.Row = 2;
    ddLegendPlacementMode.Layout.Column = 2;

    cbLegendReverse = uicheckbox(secLegendA, 'Text', 'Reverse legend entries', 'Value', false, ...
        'ValueChangedFcn', @onPersistedControlChanged);
    cbLegendReverse.Layout.Row = 3;
    cbLegendReverse.Layout.Column = [1 2];

    cbLegendAllowRebuild = uicheckbox(secLegendA, 'Text', 'Allow legend rebuild (advanced)', 'Value', false, ...
        'ValueChangedFcn', @onPersistedControlChanged);
    cbLegendAllowRebuild.Layout.Row = 4;
    cbLegendAllowRebuild.Layout.Column = [1 2];

    secLegendB = uigridlayout(tabRootLegend, [1 1]);
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

    legendActionBar = uigridlayout(tabRootLegend, [1 1]);
    legendActionBar.Layout.Row = 4;
    legendActionBar.Layout.Column = 1;
    legendActionBar.ColumnWidth = {'1x'};
    legendActionBar.RowHeight = {'fit'};
    legendActionBar.Padding = [0 0 0 0];

    btnApplyLegend = uibutton(legendActionBar, 'Text', 'Apply', 'ButtonPushedFcn', @onApplyLegend);
    btnApplyLegend.Layout.Row = 1;
    btnApplyLegend.Layout.Column = 1;

    % ---------------- Tab 3: Appearance ----------------
    tAppearance = uitab(tabs, 'Title', 'Appearance');
    tabRootAppearance = uigridlayout(tAppearance, [5 1]);
    tabRootAppearance.RowHeight = {'fit', 'fit', 'fit', '1x', 'fit'};
    tabRootAppearance.ColumnWidth = {'1x'};
    tabRootAppearance.Padding = [12 12 12 12];
    tabRootAppearance.RowSpacing = 12;
    tabRootAppearance.Scrollable = 'on';

    cmapItems = i_getAvailableColormapNames();
    if isempty(cmapItems)
        cmapItems = {'parula'};
    end
    cmapDefault = 'parula';
    if ~any(strcmp(cmapItems, cmapDefault))
        cmapDefault = cmapItems{1};
    end
    cmapItems = [{'keep'}, cmapItems];

    secColors = uigridlayout(tabRootAppearance, [2 1]);
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
        'ValueChangedFcn', @onPersistedControlChanged);
    ddCmap.Layout.Row = 1;
    ddCmap.Layout.Column = 2;

    lblAppSpread = uilabel(secAppA, 'Text', 'Colormap spread', 'HorizontalAlignment', 'left');
    lblAppSpread.Layout.Row = 2;
    lblAppSpread.Layout.Column = 1;
    ddSpreadMode = uidropdown(secAppA, ...
        'Items', {'keep','ultra-narrow','ultra-narrow-rev','narrow','narrow-rev','medium','medium-rev', ...
                  'wide','wide-rev','ultra','ultra-rev','full','full-rev'}, ...
        'Value', 'medium', ...
        'ValueChangedFcn', @onPersistedControlChanged);
    ddSpreadMode.Layout.Row = 2;
    ddSpreadMode.Layout.Column = 2;

    cbSpreadReverse = uicheckbox(secAppA, 'Text', 'Reverse spread order', 'Value', false, ...
        'ValueChangedFcn', @onPersistedControlChanged);
    cbSpreadReverse.Layout.Row = 3;
    cbSpreadReverse.Layout.Column = [1 2];

    secLinesAxes = uigridlayout(tabRootAppearance, [12 2]);
    secLinesAxes.Layout.Row = 2;
    secLinesAxes.Layout.Column = 1;
    secLinesAxes.ColumnWidth = {'1x','1x'};
    secLinesAxes.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 40};
    secLinesAxes.Padding = [12 12 12 12];
    secLinesAxes.RowSpacing = 6;

    lblSecLinesAxes = uilabel(secLinesAxes, 'Text', 'Lines & Axes', 'HorizontalAlignment', 'left');
    lblSecLinesAxes.FontWeight = 'bold';
    lblSecLinesAxes.Layout.Row = 1;
    lblSecLinesAxes.Layout.Column = [1 2];

    cbBgWhiteFigure = uicheckbox(secLinesAxes, 'Text', 'Background white (figure)', 'Value', false, ...
        'ValueChangedFcn', @onBackgroundToggleChanged);
    cbBgWhiteFigure.Layout.Row = 2;
    cbBgWhiteFigure.Layout.Column = [1 2];

    cbBgTransparentAxes = uicheckbox(secLinesAxes, 'Text', 'Transparent axes background', 'Value', false, ...
        'ValueChangedFcn', @onBackgroundToggleChanged);
    cbBgTransparentAxes.Layout.Row = 3;
    cbBgTransparentAxes.Layout.Column = [1 2];

    lblDataLineStyle = uilabel(secLinesAxes, 'Text', 'Data line style', 'HorizontalAlignment', 'left');
    lblDataLineStyle.Layout.Row = 4;
    lblDataLineStyle.Layout.Column = 1;
    ddDataLineStyle = uidropdown(secLinesAxes, 'Items', {'(keep)','-','--',':','-.'}, 'Value', '(keep)', ...
        'ValueChangedFcn', @onPersistedControlChanged);
    ddDataLineStyle.Layout.Row = 4;
    ddDataLineStyle.Layout.Column = 2;

    lblDataLineWidth = uilabel(secLinesAxes, 'Text', 'Data line width', 'HorizontalAlignment', 'left');
    lblDataLineWidth.Layout.Row = 5;
    lblDataLineWidth.Layout.Column = 1;
    nfDataLineWidth = uieditfield(secLinesAxes, 'numeric', 'Value', 1.5, 'Limits', [0 Inf], ...
        'ValueChangedFcn', @onPersistedControlChanged);
    nfDataLineWidth.Layout.Row = 5;
    nfDataLineWidth.Layout.Column = 2;

    lblDataMarkerSize = uilabel(secLinesAxes, 'Text', 'Data marker size', 'HorizontalAlignment', 'left');
    lblDataMarkerSize.Layout.Row = 6;
    lblDataMarkerSize.Layout.Column = 1;
    nfDataMarkerSize = uieditfield(secLinesAxes, 'numeric', 'Value', 6, 'Limits', [0 Inf], ...
        'ValueChangedFcn', @onPersistedControlChanged);
    nfDataMarkerSize.Layout.Row = 6;
    nfDataMarkerSize.Layout.Column = 2;

    lblFitLineStyle = uilabel(secLinesAxes, 'Text', 'Fit line style', 'HorizontalAlignment', 'left');
    lblFitLineStyle.Layout.Row = 7;
    lblFitLineStyle.Layout.Column = 1;
    ddFitLineStyle = uidropdown(secLinesAxes, 'Items', {'(keep)','-','--',':','-.'}, 'Value', '(keep)', ...
        'ValueChangedFcn', @onPersistedControlChanged);
    ddFitLineStyle.Layout.Row = 7;
    ddFitLineStyle.Layout.Column = 2;

    lblFitLineWidth = uilabel(secLinesAxes, 'Text', 'Fit line width', 'HorizontalAlignment', 'left');
    lblFitLineWidth.Layout.Row = 8;
    lblFitLineWidth.Layout.Column = 1;
    nfFitLineWidth = uieditfield(secLinesAxes, 'numeric', 'Value', 1.5, 'Limits', [0 Inf], ...
        'ValueChangedFcn', @onPersistedControlChanged);
    nfFitLineWidth.Layout.Row = 8;
    nfFitLineWidth.Layout.Column = 2;

    lblFitMarkerSize = uilabel(secLinesAxes, 'Text', 'Fit marker size', 'HorizontalAlignment', 'left');
    lblFitMarkerSize.Layout.Row = 9;
    lblFitMarkerSize.Layout.Column = 1;
    nfFitMarkerSize = uieditfield(secLinesAxes, 'numeric', 'Value', 6, 'Limits', [0 Inf], ...
        'ValueChangedFcn', @onPersistedControlChanged);
    nfFitMarkerSize.Layout.Row = 9;
    nfFitMarkerSize.Layout.Column = 2;

    lblPanelsPerRow = uilabel(secLinesAxes, 'Text', 'Panels per row:', 'HorizontalAlignment', 'left');
    lblPanelsPerRow.Layout.Row = 10;
    lblPanelsPerRow.Layout.Column = 1;
    ddPanelsPerRow = uidropdown(secLinesAxes, 'Items', {'1','2','3'}, 'Value', '2', ...
        'ValueChangedFcn', @onPersistedControlChanged);
    ddPanelsPerRow.Layout.Row = 10;
    ddPanelsPerRow.Layout.Column = 2;

    cbReversePlotOrder = uicheckbox(secLinesAxes, 'Text', 'Reverse plot order', 'Value', false, ...
        'ValueChangedFcn', @onPersistedControlChanged);
    cbReversePlotOrder.Layout.Row = 11;
    cbReversePlotOrder.Layout.Column = [1 2];

    btnApplyAppearance = uibutton(secLinesAxes, 'Text', 'Apply Appearance', 'ButtonPushedFcn', @onApplyAppearance);
    btnApplyAppearance.Layout.Row = 12;
    btnApplyAppearance.Layout.Column = [1 2];

    secQuickPresets = uigridlayout(tabRootAppearance, [2 1]);
    secQuickPresets.Layout.Row = 3;
    secQuickPresets.Layout.Column = 1;
    secQuickPresets.ColumnWidth = {'1x', '1x'};
    secQuickPresets.RowHeight = {'fit', 'fit'};
    secQuickPresets.Padding = [0 0 0 0];
    secQuickPresets.RowSpacing = 6;

    lblSecQuickPresets = uilabel(secQuickPresets, 'Text', 'Quick Presets', 'HorizontalAlignment', 'left');
    lblSecQuickPresets.FontWeight = 'bold';
    lblSecQuickPresets.Layout.Row = 1;
    lblSecQuickPresets.Layout.Column = 1;

    secAppC = uigridlayout(secQuickPresets, [3 1]);
    secAppC.Layout.Row = 2;
    secAppC.Layout.Column = 1;
    secAppC.ColumnWidth = {'1x'};
    secAppC.RowHeight = {'fit', 'fit', 'fit'};
    secAppC.Padding = [0 0 0 0];

    lblQuickPresetInfo = uilabel(secAppC, 'Text', 'Applies using current settings.', 'HorizontalAlignment', 'left');
    lblQuickPresetInfo.Layout.Row = 1;
    lblQuickPresetInfo.Layout.Column = [1 2];

    btnApplyPublicationStyle = uibutton(secAppC, 'Text', 'Apply Publication Style', 'ButtonPushedFcn', @onApplyPublicationStyle);
    btnApplyPublicationStyle.Layout.Row = 2;
    btnApplyPublicationStyle.Layout.Column = [1 2];

    btnApplySmartPack = uibutton(secAppC, 'Text', 'Apply Smart Colormap Pack', 'ButtonPushedFcn', @onApplySmartPack);
    btnApplySmartPack.Layout.Row = 3;
    btnApplySmartPack.Layout.Column = [1 2];

    secSpacerAppearance = uigridlayout(tabRootAppearance, [1 1]);
    secSpacerAppearance.Layout.Row = 4;
    secSpacerAppearance.Layout.Column = 1;
    secSpacerAppearance.ColumnWidth = {'1x'};
    secSpacerAppearance.RowHeight = {22};
    secSpacerAppearance.Padding = [0 0 0 0];

    secFigureSize = uigridlayout(tabRootAppearance, [2 1]);
    secFigureSize.Layout.Row = 5;
    secFigureSize.Layout.Column = 1;
    secFigureSize.ColumnWidth = {'1x'};
    secFigureSize.RowHeight = {'fit', 'fit'};
    secFigureSize.Padding = [0 0 0 0];
    secFigureSize.RowSpacing = 6;

    lblSecFigureSize = uilabel(secFigureSize, 'Text', 'Figure Size', 'HorizontalAlignment', 'left');
    lblSecFigureSize.FontWeight = 'bold';
    lblSecFigureSize.Layout.Row = 1;
    lblSecFigureSize.Layout.Column = 1;

    secAppD = uigridlayout(secFigureSize, [5 2]);
    secAppD.Layout.Row = 2;
    secAppD.Layout.Column = 1;
    secAppD.ColumnWidth = {170, '1x'};
    secAppD.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};
    secAppD.Padding = [0 0 0 0];

    lblWsWidth = uilabel(secAppD, 'Text', 'Target Width (cm)', 'HorizontalAlignment', 'left');
    lblWsWidth.Layout.Row = 1;
    lblWsWidth.Layout.Column = 1;
    nfWsWidth = uieditfield(secAppD, 'numeric', 'Value', 12, 'Limits', [5 40], ...
        'ValueChangedFcn', @onPersistedControlChanged);
    nfWsWidth.Layout.Row = 1;
    nfWsWidth.Layout.Column = 2;

    lblWsHeightMode = uilabel(secAppD, 'Text', 'Height Mode', 'HorizontalAlignment', 'left');
    lblWsHeightMode.Layout.Row = 2;
    lblWsHeightMode.Layout.Column = 1;
    ddWsHeightMode = uidropdown(secAppD, 'Items', {'Auto (ratio)','Auto (grid × ratio)','Custom'}, 'Value', 'Auto (ratio)', ...
        'ValueChangedFcn', @onWorkspaceHeightModeChanged);
    ddWsHeightMode.Layout.Row = 2;
    ddWsHeightMode.Layout.Column = 2;

    lblWsHeight = uilabel(secAppD, 'Text', 'Height (cm)', 'HorizontalAlignment', 'left');
    lblWsHeight.Layout.Row = 3;
    lblWsHeight.Layout.Column = 1;
    nfWsHeight = uieditfield(secAppD, 'numeric', 'Value', 9, 'Limits', [5 40], ...
        'ValueChangedFcn', @onPersistedControlChanged);
    nfWsHeight.Layout.Row = 3;
    nfWsHeight.Layout.Column = 2;

    lblWsBaseRatio = uilabel(secAppD, 'Text', 'Base ratio (H/W)', 'HorizontalAlignment', 'left');
    lblWsBaseRatio.Layout.Row = 4;
    lblWsBaseRatio.Layout.Column = 1;
    nfWsBaseRatio = uieditfield(secAppD, 'numeric', 'Value', 0.75, 'Limits', [0.3 2], ...
        'ValueChangedFcn', @onPersistedControlChanged);
    nfWsBaseRatio.Layout.Row = 4;
    nfWsBaseRatio.Layout.Column = 2;

    btnApplyWorkspaceSize = uibutton(secAppD, 'Text', 'Apply Size', 'ButtonPushedFcn', @onApplyWorkspaceSize);
    btnApplyWorkspaceSize.Layout.Row = 5;
    btnApplyWorkspaceSize.Layout.Column = [1 2];

    % ---------------- Tab 4: Export ----------------
    tExport = uitab(tabs, 'Title', 'Export');
    tabRootExport = uigridlayout(tExport, [5 1]);
    tabRootExport.ColumnWidth = {'1x'};
    tabRootExport.RowHeight = {'fit', 'fit', 'fit', '1x', 'fit'};
    tabRootExport.Padding = [12 12 12 12];

    secExportA = uigridlayout(tabRootExport, [6 2]);
    secExportA.Layout.Row = 1;
    secExportA.Layout.Column = 1;
    secExportA.ColumnWidth = {140, '1x'};
    secExportA.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
    secExportA.Padding = [0 0 0 0];

    lblExportFormat = uilabel(secExportA, 'Text', 'Format', 'HorizontalAlignment', 'left');
    lblExportFormat.Layout.Row = 1;
    lblExportFormat.Layout.Column = 1;
    ddExportFmt = uidropdown(secExportA, 'Items', {'pdf','png','fig'}, 'Value', 'pdf');
    ddExportFmt.Layout.Row = 1;
    ddExportFmt.Layout.Column = 2;

    cbVector = uicheckbox(secExportA, 'Text', 'Vector mode (PDF only)', 'Value', true);
    cbVector.Layout.Row = 2;
    cbVector.Layout.Column = [1 2];

    cbOverwrite = uicheckbox(secExportA, 'Text', 'Overwrite', 'Value', false);
    cbOverwrite.Layout.Row = 3;
    cbOverwrite.Layout.Column = [1 2];

    lblExportFilenameSource = uilabel(secExportA, 'Text', 'Filename source', 'HorizontalAlignment', 'left');
    lblExportFilenameSource.Layout.Row = 4;
    lblExportFilenameSource.Layout.Column = 1;
    ddFilenameFrom = uidropdown(secExportA, 'Items', {'Name','Number'}, 'Value', 'Name');
    ddFilenameFrom.Layout.Row = 4;
    ddFilenameFrom.Layout.Column = 2;

    secExportB = uigridlayout(tabRootExport, [2 1]);
    secExportB.Layout.Row = 2;
    secExportB.Layout.Column = 1;
    secExportB.ColumnWidth = {'1x'};
    secExportB.RowHeight = {'fit', 'fit'};
    secExportB.Padding = [0 0 0 0];

    btnChooseFolder = uibutton(secExportB, 'Text', 'Choose Folder', 'ButtonPushedFcn', @onChooseFolder);
    btnChooseFolder.Layout.Row = 1;
    btnChooseFolder.Layout.Column = 1;

    lblFolder = uilabel(secExportB, 'Text', pwd, 'WordWrap', 'on');
    lblFolder.Layout.Row = 2;
    lblFolder.Layout.Column = 1;

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

    exportOutDir = pwd;

    % ---------------- Tab 5: Compose ----------------
    tCompose = uitab(tabs, 'Title', 'Compose');
    tabRootCompose = uigridlayout(tCompose, [5 1]);
    tabRootCompose.ColumnWidth = {'1x'};
    tabRootCompose.RowHeight = {'fit', 'fit', 'fit', '1x', 'fit'};
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

    secComposeC = uigridlayout(tabRootCompose, [2 2]);
    secComposeC.Layout.Row = 3;
    secComposeC.Layout.Column = 1;
    secComposeC.ColumnWidth = {'1x', '1x'};
    secComposeC.RowHeight = {'fit', 'fit'};
    secComposeC.Padding = [0 0 0 0];

    cbExportCompose = uicheckbox(secComposeC, 'Text', 'Export immediately as PDF', 'Value', false, ...
        'ValueChangedFcn', @onPersistedControlChanged);
    cbExportCompose.Layout.Row = 1;
    cbExportCompose.Layout.Column = [1 2];

    btnSaveLayout = uibutton(secComposeC, 'Text', 'Save Layout...', 'ButtonPushedFcn', @onSaveLayout);
    btnSaveLayout.Layout.Row = 2;
    btnSaveLayout.Layout.Column = 1;

    btnLoadLayout = uibutton(secComposeC, 'Text', 'Load Layout...', 'ButtonPushedFcn', @onLoadLayout);
    btnLoadLayout.Layout.Row = 2;
    btnLoadLayout.Layout.Column = 2;

    composeActionBar = uigridlayout(tabRootCompose, [1 1]);
    composeActionBar.Layout.Row = 5;
    composeActionBar.Layout.Column = 1;
    composeActionBar.ColumnWidth = {'1x'};
    composeActionBar.RowHeight = {'fit'};
    composeActionBar.Padding = [0 0 0 0];

    btnCompose = uibutton(composeActionBar, 'Text', 'Compose', 'ButtonPushedFcn', @onCompose);
    btnCompose.Layout.Row = 1;
    btnCompose.Layout.Column = 1;

    % ---------------- Tab 6: Diagnostics (optional) ----------------
    tDiag = uitab(tabs, 'Title', 'Diagnostics');
    tabRootDiag = uigridlayout(tDiag, [3 1]);
    tabRootDiag.RowHeight = {'fit', '1x', 'fit'};
    tabRootDiag.ColumnWidth = {'1x'};
    tabRootDiag.Padding = [12 12 12 12];

    secDiagTop = uigridlayout(tabRootDiag, [1 1]);
    secDiagTop.Layout.Row = 1;
    secDiagTop.Layout.Column = 1;
    secDiagTop.RowHeight = {'fit'};
    secDiagTop.ColumnWidth = {'1x'};
    secDiagTop.Padding = [0 0 0 0];

    btnTargetReport = uibutton(secDiagTop, 'Text', 'Print Target Report', 'ButtonPushedFcn', @onTargetReport);
    btnTargetReport.Layout.Row = 1;
    btnTargetReport.Layout.Column = 1;

    secDiagBottom = uigridlayout(tabRootDiag, [1 1]);
    secDiagBottom.Layout.Row = 3;
    secDiagBottom.Layout.Column = 1;
    secDiagBottom.RowHeight = {'fit'};
    secDiagBottom.ColumnWidth = {'1x'};
    secDiagBottom.Padding = [0 0 0 0];

    taDiag = uitextarea(secDiagBottom, 'Editable', 'off');
    taDiag.Layout.Row = 1;
    taDiag.Layout.Column = 1;
    taDiag.Value = {'Diagnostics ready.'};

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
        'legendPlacementMode', "Inside", ...
        'legendLocation', "best", ...
        'legendReverse', false, ...
        'legendAllowRebuild', false, ...
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
        'reversePlotOrder', false, ...
        'panelsPerRow', "2", ...
        'exportCompose', false);
    suppressUIStateSave = false;
    legendLocationState = char(defaultUIState.legendLocation);

    % ---------------- Initialize ----------------
    i_loadUIState();
    onScopeModeChanged();
    onWidthPresetChanged();
    onWorkspaceHeightModeChanged();
    onLegendPlacementModeChanged();
    onRefreshExplicit();

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
    end

    function onExcludeChanged(~, ~)
        if string(ddScope.Value) == "Explicit List"
            onRefreshExplicit();
        end
        i_saveUIState();
    end

    function onRefreshExplicit(~, ~)
        try
            tmpSpec = struct('mode', 'allOpen', 'excludeKnownGUIs', cbExcludeGUIs.Value);
            figs = FCS_resolveTargets(tmpSpec);
            figs = figs(isgraphics(figs, 'figure'));
            figs(figs == ui) = [];

            explicitHandleCache = figs(:);
            refreshExplicitListbox([]);

        catch ME
            uialert(ui, ME.message, 'Refresh Failed');
        end
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
            numTxt = '?';
            nameTxt = '';
            try
                numTxt = string(f.Number);
            catch
            end
            try
                nameTxt = string(f.Name);
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
    end

    function onPersistedControlChanged(~, ~)
        i_saveUIState();
    end

    function onWorkspaceHeightModeChanged(~, ~)
        isCustom = string(ddWsHeightMode.Value) == "Custom";
        if isCustom
            nfWsHeight.Enable = matlab.lang.OnOffSwitchState.on;
        else
            nfWsHeight.Enable = matlab.lang.OnOffSwitchState.off;
        end
        i_saveUIState();
    end

    function onBackgroundToggleChanged(~, ~)
        % Deferred execution model:
        % Background toggles only update stored state.
        % Actual application occurs when user clicks the main Apply button.
        i_saveUIState();
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
        ddLegendPlacementMode.Value = char(defaultUIState.legendPlacementMode);
        legendLocationState = char(defaultUIState.legendLocation);
        cbLegendReverse.Value = logical(defaultUIState.legendReverse);
        cbLegendAllowRebuild.Value = logical(defaultUIState.legendAllowRebuild);
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
        cbReversePlotOrder.Value = logical(defaultUIState.reversePlotOrder);
        ddPanelsPerRow.Value = char(defaultUIState.panelsPerRow);
        cbExportCompose.Value = logical(defaultUIState.exportCompose);

        onScopeModeChanged();
        onWidthPresetChanged();
        onLegendPlacementModeChanged();
        onRefreshExplicit();
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

    function figs = resolveTargetsOrAlert()
        scopeSpec = buildScopeSpecFromUI();
        figs = FCS_resolveTargets(scopeSpec);
        figs = figs(isgraphics(figs, 'figure'));
        figs(figs == ui) = [];

        if isempty(figs)
            uialert(ui, 'No target figures found for the selected scope.', 'No Targets');
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
            uialert(ui, 'Resolved targets are not valid figure handles.', 'Invalid Targets');
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
                if ~isgraphics(ax, 'axes')
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
            i_applyBackgroundAppearance(fig, opts);

            axList = findall(fig, 'Type', 'axes');
            for a = 1:numel(axList)
                ax = axList(a);
                if ~isgraphics(ax, 'axes')
                    continue;
                end

                stats.axesTouched = stats.axesTouched + 1;
                
                % Publication style settings (optional):
                % When invoked from onApplyPublicationStyle, opts contains
                % additional fields for font sizes and axis appearance.
                if isfield(opts, 'axesFont') && isfinite(opts.axesFont) && opts.axesFont > 0
                    if isprop(ax, 'FontSize')
                        ax.FontSize = opts.axesFont;
                    end
                end
                
                if isfield(opts, 'tickDir') && ~isempty(opts.tickDir)
                    if isprop(ax, 'TickDir')
                        ax.TickDir = char(opts.tickDir);
                    end
                end
                
                if isfield(opts, 'box') && ~isempty(opts.box)
                    if isprop(ax, 'Box')
                        ax.Box = char(opts.box);
                    end
                end
                
                if isfield(opts, 'axesLineWidth') && isfinite(opts.axesLineWidth) && opts.axesLineWidth > 0
                    if isprop(ax, 'LineWidth')
                        ax.LineWidth = opts.axesLineWidth;
                    end
                end
                
                if isfield(opts, 'labelFont') && isfinite(opts.labelFont) && opts.labelFont > 0
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

    function onApplyTypography(~, ~)
        figs = resolveExplicitListTargetsOrAlert("Typography");
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

        try
            if hasOverride
                FCS_applyFontSize(figs, fs, 'AffectLegend', false);
            else
                FCS_applyFontSize(figs, fs);
            end
            FCS_applyAxisPolicy(figs, preset);
            if hasOverride
                i_applyLegendFontSize(figs, overrideFontSize);
            end
        catch ME
            uialert(ui, ME.message, 'Typography Apply Failed');
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
            if logical(cbLegendReverse.Value)
                allowRebuild = logical(cbLegendAllowRebuild.Value);
                i_applyLegendReverseExistingOnly(figs, allowRebuild, legendLocationState);
            end
        catch ME
            uialert(ui, ME.message, 'Legend Apply Failed');
        end
    end

    function onApplyAppearance(~, ~, overrides)
        if nargin < 3 || ~isstruct(overrides)
            overrides = struct();
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
        overrides.axesLineWidth = preset.lineWidth;
        overrides.tickDir = 'out';
        overrides.box = 'off';

        onApplyAppearance([], [], overrides);
    end

    function onApplySmartPack(~, ~)
        onApplyAppearance([], []);
    end

    function onApplyWorkspaceSize(~, ~)
        figs = resolveExplicitListTargetsOrAlert("Workspace Size");
        if isempty(figs), return; end

        widthCm = double(nfWsWidth.Value);
        baseRatioHW = double(nfWsBaseRatio.Value);
        rows = max(1, round(double(nfRows.Value)));
        cols = max(1, round(double(nfCols.Value)));

        if ~isfinite(widthCm) || widthCm <= 0 || ~isfinite(baseRatioHW) || baseRatioHW <= 0
            uialert(ui, 'Workspace size values must be positive numbers.', 'Workspace Size');
            return;
        end

        mode = string(ddWsHeightMode.Value);
        switch mode
            case "Auto (ratio)"
                heightCm = widthCm * baseRatioHW;
            case "Auto (grid × ratio)"
                % Robust fallback: if grid values are invalid, use ratio-only mode.
                if ~isfinite(rows) || ~isfinite(cols) || rows <= 0 || cols <= 0
                    heightCm = widthCm * baseRatioHW;
                else
                    heightCm = widthCm * (rows / cols) * baseRatioHW;
                end
            case "Custom"
                heightCm = double(nfWsHeight.Value);
            otherwise
                heightCm = widthCm * baseRatioHW;
        end

        if ~isfinite(heightCm) || heightCm <= 0
            uialert(ui, 'Computed workspace height is invalid.', 'Workspace Size');
            return;
        end

        defaultAxPos = [0.13 0.11 0.775 0.815];
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

            axList = findall(fig, 'Type', 'axes');
            for a = 1:numel(axList)
                ax = axList(a);
                if ~isgraphics(ax, 'axes') || i_isTiledLayoutManagedAxes(ax)
                    continue;
                end
                try
                    ax.Units = 'normalized';
                    ax.Position = defaultAxPos;
                catch
                end
            end
        end
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
        p = uigetdir(exportOutDir, 'Select export folder');
        if isequal(p, 0)
            return;
        end
        exportOutDir = p;
        lblFolder.Text = exportOutDir;
    end

    function onApplyExport(~, ~)
        figs = resolveTargetsOrAlert();
        if isempty(figs), return; end

        exportOpts = struct();
        exportOpts.format = char(ddExportFmt.Value);
        exportOpts.outDir = exportOutDir;
        exportOpts.overwrite = logical(cbOverwrite.Value);
        exportOpts.vectorMode = logical(cbVector.Value);
        exportOpts.filenameFrom = char(ddFilenameFrom.Value);
        exportOpts.sanitize = true;

        try
            FCS_export(figs, exportOpts);
        catch ME
            uialert(ui, ME.message, 'Export Apply Failed');
        end
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
            taDiag.Value = {['Diagnostics error: ' ME.message]};
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

    function onCompose(~, ~)
        i_saveUIState();

        if string(ddScope.Value) ~= "Explicit List"
            uialert(ui, 'Compose is available only in Explicit List scope mode.', 'Compose');
            return;
        end

        selected = lbFigures.Value;
        if isempty(selected)
            uialert(ui, 'Select at least one figure from the explicit list.', 'Compose');
            return;
        end

        selected = double(selected(:));
        selected = selected(selected >= 1 & selected <= numel(explicitHandleCache));
        selected = unique(selected, 'stable');
        figs = explicitHandleCache(selected);
        figs = figs(isgraphics(figs, 'figure'));

        if isempty(figs)
            uialert(ui, 'Selected explicit-list figures are not valid.', 'Compose');
            return;
        end

        rows = max(1, round(double(nfRows.Value)));
        cols = max(1, round(double(nfCols.Value)));
        if rows * cols < numel(figs)
            uialert(ui, 'Rows * Columns must be at least the number of selected figures.', 'Compose');
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
                    uialert(ui, 'Custom width must be positive.', 'Compose');
                    return;
                end
        end

        heightCm = max(3.0, widthCm * (rows / cols));

        densityMode = string(ddLayoutDensity.Value);
        switch densityMode
            case "Tight"
                densityPadding = 'compact';
                densitySpacing = 'compact';
            case "Spacious"
                densityPadding = 'loose';
                densitySpacing = 'loose';
            otherwise
                % Normal density maps to MATLAB tiledlayout normal spacing.
                densityPadding = 'normal';
                densitySpacing = 'normal';
        end

        scalePercent = double(nfOverallSizePct.Value);
        if ~isfinite(scalePercent)
            scalePercent = 100;
        end
        scalePercent = max(80, min(130, scalePercent));
        scaleFactor = scalePercent / 100;

        % Overall size scale is applied uniformly after base width/height are resolved.
        widthCm = widthCm * scaleFactor;
        heightCm = heightCm * scaleFactor;

        spec = i_buildComposeSpecFromUI(rows, cols, widthCm, heightCm); %#ok<NASGU>

        newFig = figure('Name', 'Composed Figure', ...
                        'Units', 'centimeters', ...
                        'Position', [2 2 widthCm heightCm], ...
                        'Renderer', 'painters', ...
                        'PaperPositionMode', 'auto');

                newFig.Units = 'centimeters';
                newFig.Position = [2 2 widthCm heightCm];

                tl = tiledlayout(newFig, rows, cols, 'Padding', densityPadding, 'TileSpacing', densitySpacing);

        autoLabel = logical(cbAutoLabel.Value);
        labelPos = string(ddLabelPos.Value);
        labelFs = max(1, double(nfLabelFont.Value));
        composeWarnings = strings(0,1);

        for k = 1:numel(figs)
            tileAx = nexttile(tl, k);
            tilePos = i_getTilePosition(tileAx);
            delete(tileAx);

            panel = uipanel('Parent', newFig, ...
                            'Units', 'normalized', ...
                            'Position', tilePos, ...
                            'BorderType', 'none');

            srcFig = figs(k);
            figName = "(unnamed)";
            try
                nm = string(srcFig.Name);
                if strlength(strtrim(nm)) > 0
                    figName = nm;
                end
            catch
            end

            [childrenToCopy, skipAnnotationCount, skipUnsupportedCount] = i_filterComposeChildren(srcFig);

            groupedCopyFailed = false;
            fallbackSkipCount = 0;
            groupedCopyErrorId = "";
            groupedCopyErrorMsgShort = "";

            if ~isempty(childrenToCopy)
                % Grouped copy is preferred because MATLAB can remap inter-object
                % references (e.g., legend/colorbar associations) in one transaction.
                try
                    copyobj(childrenToCopy, panel);
                catch ME
                    groupedCopyFailed = true;
                    groupedCopyErrorId = string(ME.identifier);
                    if strlength(strtrim(groupedCopyErrorId)) == 0
                        groupedCopyErrorId = "unknown";
                    end
                    groupedCopyErrorMsgShort = string(ME.message);
                    groupedCopyErrorMsgShort = strrep(groupedCopyErrorMsgShort, newline, " ");
                    if strlength(groupedCopyErrorMsgShort) > 80
                        groupedCopyErrorMsgShort = extractBefore(groupedCopyErrorMsgShort, 81) + "...";
                    end
                    % Deterministic fallback: per-object copy in stable child order.
                    for j = numel(childrenToCopy):-1:1
                        try
                            copyobj(childrenToCopy(j), panel);
                        catch
                            fallbackSkipCount = fallbackSkipCount + 1;
                        end
                    end
                end
            end

            assocReport = i_verifyPanelLegendColorbarAssociations(panel);

            warnParts = strings(0,1);
            if skipAnnotationCount > 0
                warnParts(end+1,1) = "skipped annotations=" + string(skipAnnotationCount); %#ok<AGROW>
            end
            if skipUnsupportedCount > 0
                warnParts(end+1,1) = "skipped unsupported=" + string(skipUnsupportedCount); %#ok<AGROW>
            end
            if groupedCopyFailed
                warnParts(end+1,1) = "grouped-copy fallback used"; %#ok<AGROW>
                warnParts(end+1,1) = "grouped-copy error=" + groupedCopyErrorId; %#ok<AGROW>
                if strlength(groupedCopyErrorMsgShort) > 0
                    warnParts(end+1,1) = "grouped-copy msg=" + groupedCopyErrorMsgShort; %#ok<AGROW>
                end
            end
            if fallbackSkipCount > 0
                warnParts(end+1,1) = "fallback skipped=" + string(fallbackSkipCount); %#ok<AGROW>
            end
            if assocReport.brokenLegendCount > 0
                warnParts(end+1,1) = "legend-association-risk=" + string(assocReport.brokenLegendCount); %#ok<AGROW>
            end
            if assocReport.brokenColorbarCount > 0
                warnParts(end+1,1) = "colorbar-association-risk=" + string(assocReport.brokenColorbarCount); %#ok<AGROW>
            end

            if ~isempty(warnParts)
                composeWarnings(end+1,1) = "Compose: fig=" + figName + " | " + strjoin(warnParts, ", "); %#ok<AGROW>
            end

            if autoLabel
                labelTxt = i_panelLabel(k);
                switch labelPos
                    case "Top-right"
                        x = tilePos(1) + tilePos(3) - 0.05;
                        y = tilePos(2) + tilePos(4) - 0.03;
                        hAlign = 'right';
                    otherwise
                        x = tilePos(1) + 0.01;
                        y = tilePos(2) + tilePos(4) - 0.03;
                        hAlign = 'left';
                end

                annotation(newFig, 'textbox', [x y 0.05 0.04], ...
                    'String', labelTxt, ...
                    'FitBoxToText', 'off', ...
                    'LineStyle', 'none', ...
                    'FontWeight', 'bold', ...
                    'FontSize', labelFs, ...
                    'HorizontalAlignment', hAlign, ...
                    'Units', 'normalized');
            end
        end

        if ~isempty(composeWarnings)
            msg = strjoin(unique(composeWarnings, 'stable'), newline);
            uialert(ui, char(msg), 'Compose warnings');
        end

        if logical(cbExportCompose.Value)
            [fileName, filePath] = uiputfile({'*.pdf','PDF file (*.pdf)'}, 'Export composed figure as PDF');
            if isequal(fileName, 0) || isequal(filePath, 0)
                return;
            end
            try
                exportgraphics(newFig, fullfile(filePath, fileName), 'ContentType', 'vector');
            catch ME
                uialert(ui, ME.message, 'Compose Export Failed');
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

    function [childrenToCopy, skipAnnotationCount, skipUnsupportedCount] = i_filterComposeChildren(srcFig)
        childrenToCopy = gobjects(0,1);
        skipAnnotationCount = 0;
        skipUnsupportedCount = 0;

        if isempty(srcFig) || ~isgraphics(srcFig, 'figure')
            return;
        end

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
            if isfield(uiState, 'excludeKnownGUIs') && ~isempty(uiState.excludeKnownGUIs)
                cbExcludeGUIs.Value = logical(uiState.excludeKnownGUIs);
            end
            if isfield(uiState, 'gridRows') && isnumeric(uiState.gridRows) && isfinite(uiState.gridRows)
                nfRows.Value = max(1, round(double(uiState.gridRows)));
            end
            if isfield(uiState, 'gridCols') && isnumeric(uiState.gridCols) && isfinite(uiState.gridCols)
                nfCols.Value = max(1, round(double(uiState.gridCols)));
            end
            if isfield(uiState, 'widthPreset') && ~isempty(uiState.widthPreset)
                cand = string(uiState.widthPreset);
                if any(string(ddWidthPreset.Items) == cand)
                    ddWidthPreset.Value = char(cand);
                end
            end
            if isfield(uiState, 'customWidth') && isnumeric(uiState.customWidth) && isfinite(uiState.customWidth)
                nfCustomWidth.Value = max(0.1, double(uiState.customWidth));
            end
            if isfield(uiState, 'autoLabels') && ~isempty(uiState.autoLabels)
                cbAutoLabel.Value = logical(uiState.autoLabels);
            end
            if isfield(uiState, 'labelPosition') && ~isempty(uiState.labelPosition)
                cand = string(uiState.labelPosition);
                if any(string(ddLabelPos.Items) == cand)
                    ddLabelPos.Value = char(cand);
                end
            end
            if isfield(uiState, 'labelFontSize') && isnumeric(uiState.labelFontSize) && isfinite(uiState.labelFontSize)
                nfLabelFont.Value = max(1, double(uiState.labelFontSize));
            end
            if isfield(uiState, 'legendPlacementMode') && ~isempty(uiState.legendPlacementMode)
                cand = string(uiState.legendPlacementMode);
                if any(string(ddLegendPlacementMode.Items) == cand)
                    ddLegendPlacementMode.Value = char(cand);
                end
            end
            if isfield(uiState, 'legendLocation') && ~isempty(uiState.legendLocation)
                legendLocationState = char(string(uiState.legendLocation));
            end
            if isfield(uiState, 'legendReverse') && ~isempty(uiState.legendReverse)
                cbLegendReverse.Value = logical(uiState.legendReverse);
            end
            if isfield(uiState, 'legendAllowRebuild') && ~isempty(uiState.legendAllowRebuild)
                cbLegendAllowRebuild.Value = logical(uiState.legendAllowRebuild);
            end
            if isfield(uiState, 'appearanceMapName') && ~isempty(uiState.appearanceMapName)
                cand = string(uiState.appearanceMapName);
                if any(string(ddCmap.Items) == cand)
                    ddCmap.Value = char(cand);
                end
            end
            if isfield(uiState, 'appearanceSpreadMode') && ~isempty(uiState.appearanceSpreadMode)
                cand = string(uiState.appearanceSpreadMode);
                if any(string(ddSpreadMode.Items) == cand)
                    ddSpreadMode.Value = char(cand);
                end
            end
            if isfield(uiState, 'appearanceSpreadReverse') && ~isempty(uiState.appearanceSpreadReverse)
                cbSpreadReverse.Value = logical(uiState.appearanceSpreadReverse);
            end
            if isfield(uiState, 'bgWhiteFigure') && ~isempty(uiState.bgWhiteFigure)
                cbBgWhiteFigure.Value = logical(uiState.bgWhiteFigure);
            end
            if isfield(uiState, 'bgTransparentAxes') && ~isempty(uiState.bgTransparentAxes)
                cbBgTransparentAxes.Value = logical(uiState.bgTransparentAxes);
            end
            if isfield(uiState, 'dataLineStyle') && ~isempty(uiState.dataLineStyle)
                cand = string(uiState.dataLineStyle);
                if any(string(ddDataLineStyle.Items) == cand)
                    ddDataLineStyle.Value = char(cand);
                end
            end
            if isfield(uiState, 'dataLineWidth') && isnumeric(uiState.dataLineWidth) && isfinite(uiState.dataLineWidth)
                nfDataLineWidth.Value = max(0, double(uiState.dataLineWidth));
            end
            if isfield(uiState, 'dataMarkerSize') && isnumeric(uiState.dataMarkerSize) && isfinite(uiState.dataMarkerSize)
                nfDataMarkerSize.Value = max(0, double(uiState.dataMarkerSize));
            end
            if isfield(uiState, 'fitLineStyle') && ~isempty(uiState.fitLineStyle)
                cand = string(uiState.fitLineStyle);
                if any(string(ddFitLineStyle.Items) == cand)
                    ddFitLineStyle.Value = char(cand);
                end
            end
            if isfield(uiState, 'fitLineWidth') && isnumeric(uiState.fitLineWidth) && isfinite(uiState.fitLineWidth)
                nfFitLineWidth.Value = max(0, double(uiState.fitLineWidth));
            end
            if isfield(uiState, 'fitMarkerSize') && isnumeric(uiState.fitMarkerSize) && isfinite(uiState.fitMarkerSize)
                nfFitMarkerSize.Value = max(0, double(uiState.fitMarkerSize));
            end
            if isfield(uiState, 'reversePlotOrder') && ~isempty(uiState.reversePlotOrder)
                cbReversePlotOrder.Value = logical(uiState.reversePlotOrder);
            end
            if isfield(uiState, 'panelsPerRow') && ~isempty(uiState.panelsPerRow)
                cand = string(uiState.panelsPerRow);
                if any(string(ddPanelsPerRow.Items) == cand)
                    ddPanelsPerRow.Value = char(cand);
                end
            end
            if isfield(uiState, 'exportCompose') && ~isempty(uiState.exportCompose)
                cbExportCompose.Value = logical(uiState.exportCompose);
            end
        catch
            % Graceful fallback to defaults/UI creation values
        end
    end

    function i_saveUIState()
        if suppressUIStateSave
            return;
        end

        uiState = struct();
        uiState.scopeMode = string(ddScope.Value);
        uiState.excludeKnownGUIs = logical(cbExcludeGUIs.Value);
        uiState.gridRows = double(nfRows.Value);
        uiState.gridCols = double(nfCols.Value);
        uiState.widthPreset = string(ddWidthPreset.Value);
        uiState.customWidth = double(nfCustomWidth.Value);
        uiState.autoLabels = logical(cbAutoLabel.Value);
        uiState.labelPosition = string(ddLabelPos.Value);
        uiState.labelFontSize = double(nfLabelFont.Value);
        uiState.legendPlacementMode = string(ddLegendPlacementMode.Value);
        uiState.legendLocation = string(legendLocationState);
        uiState.legendReverse = logical(cbLegendReverse.Value);
        uiState.legendAllowRebuild = logical(cbLegendAllowRebuild.Value);
        uiState.appearanceMapName = string(ddCmap.Value);
        uiState.appearanceSpreadMode = string(ddSpreadMode.Value);
        uiState.appearanceSpreadReverse = logical(cbSpreadReverse.Value);
        uiState.bgWhiteFigure = logical(cbBgWhiteFigure.Value);
        uiState.bgTransparentAxes = logical(cbBgTransparentAxes.Value);
        uiState.dataLineStyle = string(ddDataLineStyle.Value);
        uiState.dataLineWidth = double(nfDataLineWidth.Value);
        uiState.dataMarkerSize = double(nfDataMarkerSize.Value);
        uiState.fitLineStyle = string(ddFitLineStyle.Value);
        uiState.fitLineWidth = double(nfFitLineWidth.Value);
        uiState.fitMarkerSize = double(nfFitMarkerSize.Value);
        uiState.reversePlotOrder = logical(cbReversePlotOrder.Value);
        uiState.panelsPerRow = string(ddPanelsPerRow.Value);
        uiState.exportCompose = logical(cbExportCompose.Value);

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
end
