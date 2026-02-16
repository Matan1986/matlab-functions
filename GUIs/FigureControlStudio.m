function FigureControlStudio()
% FigureControlStudio
% Modern uifigure-based control studio for existing MATLAB figures.
% Orchestrates only explicit target resolution + adapter actions.

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
    tgtGrid = uigridlayout(targetPanel, [11 1]);
    tgtGrid.RowHeight = {22, 22, 22, 22, 28, 28, '1x', 22, 24, 22, 1};
    tgtGrid.ColumnWidth = {'1x'};
    tgtGrid.Padding = [8 8 8 8];

    uilabel(tgtGrid, 'Text', 'Scope Mode');
    ddScope = uidropdown(tgtGrid, ...
        'Items', {'Current Figure', 'All Open Figures', 'By Tag', 'By Name Contains', 'Explicit List'}, ...
        'Value', 'Current Figure', ...
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
    lbFigures.Items = {'(none)'};
    lbFigures.ItemsData = NaN;

    cbExcludeGUIs = uicheckbox(tgtGrid, 'Text', 'Exclude Known GUIs', 'Value', true, 'ValueChangedFcn', @onExcludeChanged);

    lblDetected = uilabel(tgtGrid, 'Text', 'Detected: 0');
    lblHint = uilabel(tgtGrid, 'Text', 'Tip: Use Refresh for Explicit List mode');
    lblHint.FontColor = [0.35 0.35 0.35];

    % explicit-list cache
    explicitHandleCache = gobjects(0,1);

    % ---------------- Tab 1: Typography ----------------
    tTypo = uitab(tabs, 'Title', 'Typography');
    gTypo = uigridlayout(tTypo, [7 2]);
    gTypo.ColumnWidth = {170, '1x'};
    gTypo.RowHeight = {22, 28, 22, 28, 36, '1x', 1};
    gTypo.Padding = [12 12 12 12];

    uilabel(gTypo, 'Text', 'Font Size', 'HorizontalAlignment', 'left');
    nfFontSize = uieditfield(gTypo, 'numeric', 'Value', 11, 'Limits', [1 Inf], 'RoundFractionalValues', true);

    uilabel(gTypo, 'Text', 'Axis Policy preset', 'HorizontalAlignment', 'left');
    ddAxisPreset = uidropdown(gTypo, 'Items', {'paper'}, 'Value', 'paper');

    btnApplyTypo = uibutton(gTypo, 'Text', 'Apply', 'ButtonPushedFcn', @onApplyTypography);
    btnApplyTypo.Layout.Row = 5;
    btnApplyTypo.Layout.Column = [1 2];

    % ---------------- Tab 2: Legend ----------------
    tLegend = uitab(tabs, 'Title', 'Legend');
    gLegend = uigridlayout(tLegend, [7 2]);
    gLegend.ColumnWidth = {170, '1x'};
    gLegend.RowHeight = {22, 28, 22, 22, 36, '1x', 1};
    gLegend.Padding = [12 12 12 12];

    uilabel(gLegend, 'Text', 'Location', 'HorizontalAlignment', 'left');
    ddLegendLocation = uidropdown(gLegend, 'Items', ...
        {'best','north','south','east','west','northeast','northwest','southeast','southwest','eastoutside','westoutside','northoutside','southoutside','none'}, ...
        'Value', 'northeast');

    cbLegendPreset = uicheckbox(gLegend, 'Text', 'Use preset style', 'Value', true);
    cbLegendPreset.Layout.Row = 3;
    cbLegendPreset.Layout.Column = [1 2];

    btnApplyLegend = uibutton(gLegend, 'Text', 'Apply', 'ButtonPushedFcn', @onApplyLegend);
    btnApplyLegend.Layout.Row = 5;
    btnApplyLegend.Layout.Column = [1 2];

    % ---------------- Tab 3: Appearance ----------------
    tAppearance = uitab(tabs, 'Title', 'Appearance');
    gApp = uigridlayout(tAppearance, [11 2]);
    gApp.ColumnWidth = {170, '1x'};
    gApp.RowHeight = {22, 28, 22, 22, 22, 28, 22, 28, 36, 28, '1x'};
    gApp.Padding = [12 12 12 12];

    uilabel(gApp, 'Text', 'Colormap', 'HorizontalAlignment', 'left');
    ddCmap = uidropdown(gApp, 'Items', {'parula','turbo','jet','hsv','hot','cool','spring','summer','autumn','winter','gray','lines','viridis','plasma','magma'}, 'Value', 'parula');

    cbReverse = uicheckbox(gApp, 'Text', 'Reverse order', 'Value', false);
    cbReverse.Layout.Row = 3;
    cbReverse.Layout.Column = [1 2];

    uilabel(gApp, 'Text', 'LineWidth (optional)', 'HorizontalAlignment', 'left');
    nfLineWidth = uieditfield(gApp, 'numeric', 'Value', 1.5, 'Limits', [0 Inf]);

    uilabel(gApp, 'Text', 'MarkerSize (optional)', 'HorizontalAlignment', 'left');
    nfMarkerSize = uieditfield(gApp, 'numeric', 'Value', 6, 'Limits', [0 Inf]);

    btnApplyAppearance = uibutton(gApp, 'Text', 'Apply', 'ButtonPushedFcn', @onApplyAppearance);
    btnApplyAppearance.Layout.Row = 9;
    btnApplyAppearance.Layout.Column = [1 2];

    btnApplySmartPack = uibutton(gApp, 'Text', 'Apply Smart Colormap Pack', 'ButtonPushedFcn', @onApplySmartPack);
    btnApplySmartPack.Layout.Row = 10;
    btnApplySmartPack.Layout.Column = [1 2];

    % ---------------- Tab 4: Export ----------------
    tExport = uitab(tabs, 'Title', 'Export');
    gExport = uigridlayout(tExport, [12 2]);
    gExport.ColumnWidth = {170, '1x'};
    gExport.RowHeight = {22, 28, 22, 22, 22, 22, 22, 28, 28, 36, '1x', 1};
    gExport.Padding = [12 12 12 12];

    uilabel(gExport, 'Text', 'Format', 'HorizontalAlignment', 'left');
    ddExportFmt = uidropdown(gExport, 'Items', {'pdf','png','fig'}, 'Value', 'pdf');

    cbVector = uicheckbox(gExport, 'Text', 'Vector mode (PDF only)', 'Value', true);
    cbVector.Layout.Row = 3;
    cbVector.Layout.Column = [1 2];

    cbOverwrite = uicheckbox(gExport, 'Text', 'Overwrite', 'Value', false);
    cbOverwrite.Layout.Row = 4;
    cbOverwrite.Layout.Column = [1 2];

    uilabel(gExport, 'Text', 'Filename source', 'HorizontalAlignment', 'left');
    ddFilenameFrom = uidropdown(gExport, 'Items', {'Name','Number'}, 'Value', 'Name');

    btnChooseFolder = uibutton(gExport, 'Text', 'Choose Folder', 'ButtonPushedFcn', @onChooseFolder);
    btnChooseFolder.Layout.Row = 8;
    btnChooseFolder.Layout.Column = [1 2];

    lblFolder = uilabel(gExport, 'Text', pwd, 'WordWrap', 'on');
    lblFolder.Layout.Row = 9;
    lblFolder.Layout.Column = [1 2];

    btnApplyExport = uibutton(gExport, 'Text', 'Apply', 'ButtonPushedFcn', @onApplyExport);
    btnApplyExport.Layout.Row = 10;
    btnApplyExport.Layout.Column = [1 2];

    exportOutDir = pwd;

    % ---------------- Tab 5: Compose ----------------
    tCompose = uitab(tabs, 'Title', 'Compose');
    gCompose = uigridlayout(tCompose, [14 2]);
    gCompose.ColumnWidth = {190, '1x'};
    gCompose.RowHeight = {22, 28, 22, 28, 22, 22, 22, 28, 22, 28, 22, 22, 36, '1x'};
    gCompose.Padding = [12 12 12 12];

    uilabel(gCompose, 'Text', 'Rows', 'HorizontalAlignment', 'left');
    nfRows = uieditfield(gCompose, 'numeric', 'Value', 2, 'Limits', [1 Inf], 'RoundFractionalValues', true);

    uilabel(gCompose, 'Text', 'Columns', 'HorizontalAlignment', 'left');
    nfCols = uieditfield(gCompose, 'numeric', 'Value', 2, 'Limits', [1 Inf], 'RoundFractionalValues', true);

    cbAutoLabel = uicheckbox(gCompose, 'Text', 'Auto label panels', 'Value', true);
    cbAutoLabel.Layout.Row = 5;
    cbAutoLabel.Layout.Column = [1 2];

    uilabel(gCompose, 'Text', 'Label position', 'HorizontalAlignment', 'left');
    ddLabelPos = uidropdown(gCompose, 'Items', {'Top-left','Top-right'}, 'Value', 'Top-left');

    uilabel(gCompose, 'Text', 'Label font size', 'HorizontalAlignment', 'left');
    nfLabelFont = uieditfield(gCompose, 'numeric', 'Value', 11, 'Limits', [1 Inf], 'RoundFractionalValues', true);

    uilabel(gCompose, 'Text', 'Manuscript width preset', 'HorizontalAlignment', 'left');
    ddWidthPreset = uidropdown(gCompose, 'Items', {'Single column','Double column','Custom'}, 'Value', 'Single column', ...
        'ValueChangedFcn', @onWidthPresetChanged);

    uilabel(gCompose, 'Text', 'Custom width (cm)', 'HorizontalAlignment', 'left');
    nfCustomWidth = uieditfield(gCompose, 'numeric', 'Value', 12.0, 'Limits', [0.1 Inf]);

    cbExportCompose = uicheckbox(gCompose, 'Text', 'Export immediately as PDF', 'Value', false);
    cbExportCompose.Layout.Row = 12;
    cbExportCompose.Layout.Column = [1 2];

    btnCompose = uibutton(gCompose, 'Text', 'Compose', 'ButtonPushedFcn', @onCompose);
    btnCompose.Layout.Row = 13;
    btnCompose.Layout.Column = [1 2];

    % ---------------- Tab 6: Diagnostics (optional) ----------------
    tDiag = uitab(tabs, 'Title', 'Diagnostics');
    gDiag = uigridlayout(tDiag, [3 1]);
    gDiag.RowHeight = {34, '1x', 1};
    gDiag.Padding = [12 12 12 12];

    btnTargetReport = uibutton(gDiag, 'Text', 'Print Target Report', 'ButtonPushedFcn', @onTargetReport);
    taDiag = uitextarea(gDiag, 'Editable', 'off');
    taDiag.Value = {'Diagnostics ready.'};

    % ---------------- Initialize ----------------
    onScopeModeChanged();
    onRefreshExplicit();
    onWidthPresetChanged();

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
    end

    function onExcludeChanged(~, ~)
        if string(ddScope.Value) == "Explicit List"
            onRefreshExplicit();
        end
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
            lbFigures.Items = {'(none)'};
            lbFigures.ItemsData = NaN;
            lbFigures.Value = NaN;
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
        if isempty(sel) || (isnumeric(sel) && any(isnan(sel)))
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
        if isempty(sel) || (isnumeric(sel) && any(isnan(sel)))
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
                if isempty(selected) || (isnumeric(selected) && any(isnan(selected)))
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

    function onApplyTypography(~, ~)
        figs = resolveTargetsOrAlert();
        if isempty(figs), return; end

        fs = double(nfFontSize.Value);
        preset = char(ddAxisPreset.Value);

        try
            FCS_applyFontSize(figs, fs);
            FCS_applyAxisPolicy(figs, preset);
        catch ME
            uialert(ui, ME.message, 'Typography Apply Failed');
        end
    end

    function onApplyLegend(~, ~)
        figs = resolveTargetsOrAlert();
        if isempty(figs), return; end

        loc = char(ddLegendLocation.Value);
        legendOpts = struct();
        legendOpts.args = {'show', 'Location', loc};
        if cbLegendPreset.Value
            legendOpts.preset = 'paper';
        end

        try
            FCS_applyLegend(figs, legendOpts);
        catch ME
            uialert(ui, ME.message, 'Legend Apply Failed');
        end
    end

    function onApplyAppearance(~, ~)
        figs = resolveTargetsOrAlert();
        if isempty(figs), return; end

        cmapOpts = struct();
        cmapOpts.mapName = string(ddCmap.Value);
        cmapOpts.reverseOrder = logical(cbReverse.Value);
        cmapOpts.applyToAxes = true;
        cmapOpts.applyToColorbar = true;
        cmapOpts.applyToLines = true;
        cmapOpts.applyToScatter = true;
        cmapOpts.includeHiddenHandles = false;

        if nfLineWidth.Value > 0
            cmapOpts.lineWidth = double(nfLineWidth.Value);
        end
        if nfMarkerSize.Value > 0
            cmapOpts.markerSize = double(nfMarkerSize.Value);
        end

        try
            FCS_setColormapOnly(figs, cmapOpts);
        catch ME
            uialert(ui, ME.message, 'Appearance Apply Failed');
        end
    end

    function onApplySmartPack(~, ~)
        figs = resolveTargetsOrAlert();
        if isempty(figs), return; end

        smartOpts = struct();
        smartOpts.mapName = string(ddCmap.Value);
        smartOpts.spreadMode = 'medium';
        if nfLineWidth.Value > 0
            smartOpts.lineWidth = double(nfLineWidth.Value);
        end
        if nfMarkerSize.Value > 0
            smartOpts.markerSize = double(nfMarkerSize.Value);
        end
        smartOpts.reverseOrder = logical(cbReverse.Value);
        smartOpts.reverseLegendOrder = false;
        smartOpts.noMapChange = false;

        try
            FCS_applyColormap(figs, smartOpts);
        catch ME
            uialert(ui, ME.message, 'Smart Colormap Pack Failed');
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

    function onCompose(~, ~)
        if string(ddScope.Value) ~= "Explicit List"
            uialert(ui, 'Compose is available only in Explicit List scope mode.', 'Compose');
            return;
        end

        selected = lbFigures.Value;
        if isempty(selected) || (isnumeric(selected) && any(isnan(selected)))
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

        newFig = figure('Name', 'Composed Figure', ...
                        'Units', 'centimeters', ...
                        'Position', [2 2 widthCm heightCm], ...
                        'Renderer', 'painters', ...
                        'PaperPositionMode', 'auto');

        tl = tiledlayout(newFig, rows, cols, 'Padding', 'compact', 'TileSpacing', 'compact');

        autoLabel = logical(cbAutoLabel.Value);
        labelPos = string(ddLabelPos.Value);
        labelFs = max(1, double(nfLabelFont.Value));
        composeWarnings = strings(0,1);

        for k = 1:numel(figs)
            tileAx = nexttile(tl, k);
            tilePos = i_getTilePosition(tileAx);

            srcAxes = findall(figs(k), 'Type', 'axes');
            keep = true(size(srcAxes));
            for j = 1:numel(srcAxes)
                tg = "";
                try, tg = lower(string(srcAxes(j).Tag)); catch, end
                if contains(tg, "legend") || contains(tg, "colorbar")
                    keep(j) = false;
                end
            end
            srcAxes = srcAxes(keep);

            if ~isempty(srcAxes)
                % Preserve original axes properties by copying full axes object(s)
                for j = numel(srcAxes):-1:1
                    newAx = copyobj(srcAxes(j), newFig);
                    try
                        newAx.Layout.Tile = k;
                    catch
                        try
                            newAx.Units = 'normalized';
                            newAx.Position = tilePos;
                        catch
                        end
                    end
                end
            end

            annWarn = i_copyAndRemapAnnotations(figs(k), newFig, tilePos);
            if ~isempty(annWarn)
                composeWarnings = [composeWarnings; string(annWarn(:))]; %#ok<AGROW>
            end

            delete(tileAx);

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
end
