% ========================================================================
% DEPRECATION NOTICE (LEGACY GEOMETRY ENGINE)
% This file is deprecated for new development.
% It remains for backward compatibility only.
% Do not extend or reuse this file for new layout logic.
% New layout logic must use explicit target lists and stateless margin
% normalization.
% ========================================================================
classdef SmartFigureEngine
    methods(Static)
        function style = computeSmartStyle(panelWidth, panelHeight, nx, ny, mode)
            if nargin < 5 || isempty(mode), mode = 'PRL'; end
            if nargin < 4 || isempty(ny), ny = 1; end
            if nargin < 3 || isempty(nx), nx = 1; end
            if nargin < 2 || isempty(panelHeight), panelHeight = 3.0; end
            if nargin < 1 || isempty(panelWidth), panelWidth = 3.5; end

            mode = char(string(mode));
            modeKey = lower(strtrim(mode));

            switch modeKey
                case 'nature'
                    base = 12.0; lineMul = 1.00; marginMul = 1.05;
                case 'compact'
                    base = 10.8; lineMul = 0.92; marginMul = 0.95;
                case 'presentation'
                    base = 13.5; lineMul = 1.18; marginMul = 1.12;
                otherwise
                    mode = 'PRL';
                    base = 11.6; lineMul = 1.00; marginMul = 1.00;
            end

            density = 1.0 + 0.08*max(0,nx-1) + 0.05*max(0,ny-1);
            scalePhysical = max(0.75, min(1.35, (panelHeight/3.2)*0.65 + (panelWidth/3.5)*0.35));
            tickBase = base * density * scalePhysical;
            nxTightness = min(1, max(0, (nx - 1) / 2));
            nyTightness = min(1, max(0, (ny - 1) / 2));
            layoutTightness = min(1, 0.65*nxTightness + 0.35*nyTightness);

            tickFont = max(10, min(28, round(tickBase)));
            labelFont = round(tickFont * 1.18);
            legendFont = max(8, round(tickFont * 0.92));
            titleFont = round(tickFont * 1.22);
            annotationFont = max(8, round(tickFont * 0.88));

            targetLabelFont = round(32 - 2*nxTightness - 1*nyTightness);
            labelFont = targetLabelFont;
            titleFont = targetLabelFont;
            legendFont = max(12, round(targetLabelFont * 0.50));
            tickFont = max(10, round(targetLabelFont * 0.84));
            annotationFont = max(8, round(targetLabelFont * 0.84));

            lineWidth = max(1.1, min(3.5, (1.2 + 0.18*scalePhysical) * lineMul));
            markerSize = max(5, min(12, round(5.2 + 1.8*scalePhysical)));

            leftMargin = (0.185 + 0.022*layoutTightness) * marginMul;
            topMargin = (0.022 + 0.012*layoutTightness) * marginMul;
            rightMargin = (0.022 + 0.010*layoutTightness) * marginMul;
            bottomMargin = (0.19 + 0.012*layoutTightness) * marginMul;

            axWidth = max(0.05, 1 - leftMargin - rightMargin);
            axHeight = max(0.05, 1 - topMargin - bottomMargin);

            style = struct( ...
                'tickFont', tickFont, ...
                'labelFont', labelFont, ...
                'legendFont', legendFont, ...
                'titleFont', titleFont, ...
                'annotationFont', annotationFont, ...
                'lineWidth', lineWidth, ...
                'markerSize', markerSize, ...
                'axWidth', axWidth, ...
                'axHeight', axHeight, ...
                'topMargin', topMargin, ...
                'leftMargin', leftMargin, ...
                'rightMargin', rightMargin, ...
                'bottomMargin', bottomMargin, ...
                'mode', mode, ...
                'nx', nx, ...
                'ny', ny, ...
                'panelWidth', panelWidth, ...
                'panelHeight', panelHeight, ...
                'xLabelOffset', 0.12, ...
                'xLabelOffsetSubplot', 0.18, ...
                'yLabelOffset', 0.14, ...
                'xLabelPadNormalized', 0.12 + 0.02*nyTightness, ...
                'yLabelPadNormalized', 0.10 + 0.010*layoutTightness, ...
                'xLabelPadSubplotExtra', 0.16 + 0.05*nyTightness + 0.01*layoutTightness, ...
                'yLabelPadSubplotExtra', -(0.03 + 0.010*nyTightness + 0.005*layoutTightness), ...
                'rowGap', 0.060 - 0.010*nxTightness, ...
                'colGap', 0.055 - 0.010*nxTightness, ...
                'dpi', 96, ...
                'previewScale', 3.0, ...
                'applyPreviewResize', true, ...
                'enableAutoReflow', true, ...
                'sharedXLabel', false, ...
                'sharedYLabel', false, ...
                'safeMode', true, ...
                'geometryMode', 'deterministic-grid', ...
                'autoCompactLegend', false, ...
                'allowLegendLayoutChanges', false, ...
                'detectTextOverlaps', true, ...
                'lockSmartStyle', false, ...
                'xLabelBaselineOffset', 0.08);
        end

        function applyFullSmart(fig, style)
            if nargin < 2 || isempty(style)
                style = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 1, 1, 'PRL');
            end
            if isempty(fig) || ~isvalid(fig) || ~isgraphics(fig,'figure'), return; end

            dbg = SmartFigureEngine.isDebugEnabled();

            if isappdata(fig,'SmartFigureEngine_IsApplying') && getappdata(fig,'SmartFigureEngine_IsApplying')
                return;
            end
            setappdata(fig,'SmartFigureEngine_IsApplying',true);
            c = onCleanup(@() SmartFigureEngine.clearApplyingFlag(fig)); %#ok<NASGU>

            if ~isfield(style,'lockSmartStyle'), style.lockSmartStyle = false; end
            if isappdata(fig,'SmartFigureEngine_StyleLock')
                try
                    style.lockSmartStyle = logical(getappdata(fig,'SmartFigureEngine_StyleLock'));
                catch
                end
            end
            if style.lockSmartStyle
                style = SmartFigureEngine.rebuildLockedStyle(style);
            end

            SmartFigureEngine.captureLegendSnapshot(fig);

            if dbg
                fprintf('[SmartEngine] applyFullSmart mode=%s nx=%d ny=%d tick=%g label=%g legend=%g top=%g left=%g\n', ...
                    char(string(style.mode)), style.nx, style.ny, style.tickFont, style.labelFont, style.legendFont, style.topMargin, style.leftMargin);
            end

            setappdata(fig,'SmartFigureEngine_LastStyle',style);

            SmartFigureEngine.applyFigureGeometry(fig, style);
            SmartFigureEngine.applyAxesGeometry(fig, style);
            SmartFigureEngine.recenterYLabelsForFigure(fig);
            style = SmartFigureEngine.syncSafeModeMarginsFromAxes(fig, style);
            setappdata(fig,'SmartFigureEngine_LastStyle',style);
            SmartFigureEngine.applyTypography(fig, style);
            SmartFigureEngine.applyLineSystem(fig, style);
            SmartFigureEngine.applyLegendSystem(fig, style);
            SmartFigureEngine.applyAnnotationStyle(fig, style);
            SmartFigureEngine.finalize(fig, style);
            SmartFigureEngine.enforceReferenceLinesBehindData(fig);
            SmartFigureEngine.recenterYLabelsForFigure(fig);

            try
                report = SmartFigureEngine.validateFigureConsistency(fig);
                if ~report.passed
                    fprintf('[SmartEngine] Consistency check failed with %d issue(s)\n', numel(report.issues));
                elseif dbg
                    fprintf('[SmartEngine] Consistency check passed\n');
                end
            catch ME
                warning('SmartFigureEngine:ConsistencyValidation', 'validateFigureConsistency failed: %s', ME.message);
            end

            axNow = SmartFigureEngine.getDataAxes(fig);
            SmartFigureEngine.attachYLimRecenteringListeners(axNow);
            geomMode = SmartFigureEngine.getGeometryMode(style);
            isDeterministicMode = strcmpi(geomMode,'deterministic-grid');
            if ~isDeterministicMode && (~isfield(style,'enableAutoReflow') || style.enableAutoReflow)
                SmartFigureEngine.attachAutoReflow(fig);
            end
        end

        function style = applyUiOverrides(style, tickOverride, legendOverride)
            if nargin < 2, tickOverride = NaN; end
            if nargin < 3, legendOverride = NaN; end
            if isfield(style,'lockSmartStyle') && style.lockSmartStyle
                return;
            end

            if ~isnan(tickOverride) && tickOverride > 0
                style.tickFont = tickOverride;
                style.labelFont = round(style.tickFont * 1.18);
                style.legendFont = round(style.tickFont * 0.92);
                style.titleFont = round(style.tickFont * 1.22);
                style.annotationFont = max(8, round(style.tickFont * 0.88));
            end

            if ~isnan(legendOverride) && legendOverride > 0
                style.legendFont = legendOverride;
            end
        end

        function applyFigureGeometry(fig, style)
            if isempty(fig) || ~isvalid(fig), return; end
            try
                fig.Units = 'inches';
                fig.PaperUnits = 'inches';
                fig.PaperSize = [style.panelWidth style.panelHeight];
                fig.PaperPosition = [0 0 style.panelWidth style.panelHeight];
                fig.PaperPositionMode = 'manual';
            catch
            end
            try
                if isfield(style,'applyPreviewResize') && style.applyPreviewResize
                    dpi = style.dpi;
                    ps = style.previewScale;
                    fig.Units = 'pixels';
                    p = fig.Position;
                    p(3) = style.panelWidth * dpi * ps;
                    p(4) = style.panelHeight * dpi * ps;
                    fig.Position = p;
                end
            catch
            end
        end

        function applyAxesGeometry(fig, style)
            ax = SmartFigureEngine.getDataAxes(fig);
            fprintf('Geometry update: %d axes found\n', numel(ax));
            if isempty(ax), return; end

            isSafeMode = ~(isfield(style,'safeMode') && ~style.safeMode);
            geomMode = SmartFigureEngine.getGeometryMode(style);
            if isSafeMode && numel(ax) == 1
                left = style.leftMargin;
                width = style.axWidth;
                height = style.axHeight;
                bottom = max(0.01, min(1-height-0.01, 1 - height - style.topMargin));
                ax(1).Units = 'normalized';
                ax(1).Position = [left, bottom, width, height];
                SmartFigureEngine.applyGlobalLeftShift(ax(1), style);
                SmartFigureEngine.placeAxisLabels(ax(1), style, false);
                SmartFigureEngine.enforceReferenceLinesBehindData(fig);
                return;
            end

            if numel(ax) > 1
                if strcmpi(geomMode,'deterministic-grid')
                    SmartFigureEngine.applyDeterministicGridGeometry(fig, ax, style);
                else
                    SmartFigureEngine.applyMultiPanelGeometry(fig, ax, style);
                end
                SmartFigureEngine.applyGlobalLeftShift(ax, style);
                SmartFigureEngine.enforceReferenceLinesBehindData(fig);
                return;
            end

            if numel(ax) == 1
                bottom = max(0, 1 - style.axHeight - style.topMargin);
                left = max(0.01, min(1-style.axWidth-0.01, style.leftMargin));
                ax(1).Units = 'normalized';
                ax(1).Position = [left, bottom, style.axWidth, style.axHeight];
                SmartFigureEngine.applyGlobalLeftShift(ax(1), style);
                SmartFigureEngine.placeAxisLabels(ax(1), style, false);
                SmartFigureEngine.enforceReferenceLinesBehindData(fig);
                return;
            end
        end

        function applyTypography(fig, style)
            ax = SmartFigureEngine.getDataAxes(fig);
            if isempty(ax), return; end
            try
                if numel(ax) > 1
                    pos = vertcat(ax.Position);
                    yCenters = pos(:,2) + pos(:,4)/2;
                    yVals = SmartFigureEngine.clusterVals(yCenters, max(0.03, 0.25*median(pos(:,4))));
                    inferredNy = max(1, numel(yVals));
                    if ~isfield(style,'ny') || ~isnumeric(style.ny) || ~isfinite(style.ny)
                        style.ny = inferredNy;
                    else
                        style.ny = max(style.ny, inferredNy);
                    end
                end
            catch
            end
            legendFs = SmartFigureEngine.getSharedLegendTextFont(style);
            isMultiPanel = numel(ax) > 1;
            for a = ax(:)'
                try
                    if isprop(a,'FontUnits'), a.FontUnits = 'points'; end
                    a.FontSize = style.tickFont;
                    if isprop(a,'TickLabelInterpreter'), a.TickLabelInterpreter = 'latex'; end
                    if isprop(a,'TickDir'), a.TickDir = 'out'; end
                    if isprop(a,'Box'), a.Box = 'on'; end
                    if isprop(a,'XColor'), a.XColor = [0 0 0]; end
                    if isprop(a,'YColor'), a.YColor = [0 0 0]; end
                    if isprop(a,'ZColor'), a.ZColor = [0 0 0]; end
                catch
                end

                SmartFigureEngine.applyTextObj(a.XLabel, style.labelFont);
                if isMultiPanel
                    yFont = SmartFigureEngine.getCompactYLabelFont(style, a.YLabel.String);
                else
                    yFont = style.labelFont;
                end
                SmartFigureEngine.applyTextObj(a.YLabel, yFont);
                SmartFigureEngine.applyTextObj(a.Title, style.titleFont);
                try
                    if isprop(a.XLabel,'Color'), a.XLabel.Color = [0 0 0]; end
                    if isprop(a.YLabel,'Color'), a.YLabel.Color = [0 0 0]; end
                    if isprop(a.Title,'Color'), a.Title.Color = [0 0 0]; end
                catch
                end

                SmartFigureEngine.reduceTicksNice(a, style.tickFont);
            end

            SmartFigureEngine.normalizeMultiPanelLabels(fig, ax, style);
            SmartFigureEngine.enforceBottomOnlyXTickLabels(ax);
            SmartFigureEngine.applySharedLabels(fig, ax, style);
            SmartFigureEngine.scaleSharedBottomText(fig, ax, style);

            lg = findall(fig,'Type','legend');
            for L = lg(:)'
                SmartFigureEngine.applyTextObj(L, legendFs);
                try
                    if isprop(L,'Interpreter'), L.Interpreter = 'latex'; end
                    if isprop(L,'Box'), L.Box = 'off'; end
                    if isprop(L,'Color'), L.Color = 'none'; end
                catch
                end
            end

            excludedText = gobjects(0);
            for a = ax(:)'
                try, excludedText(end+1,1) = a.XLabel; catch, end %#ok<AGROW>
                try, excludedText(end+1,1) = a.YLabel; catch, end %#ok<AGROW>
                try, excludedText(end+1,1) = a.Title;  catch, end %#ok<AGROW>
            end

            tx = findall(fig,'Type','text');
            for t = tx(:)'
                textFs = legendFs;
                try
                    if ~isempty(excludedText) && any(t == excludedText)
                        continue;
                    end
                catch
                end
                SmartFigureEngine.applyTextObj(t, textFs);
                try
                    if isprop(t,'Color'), t.Color = [0 0 0]; end
                catch
                end
            end

            ann = findall(fig,'Type','textboxshape');
            for t = ann(:)'
                SmartFigureEngine.applyTextObj(t, legendFs);
                try
                    if isprop(t,'Interpreter'), t.Interpreter = 'latex'; end
                    if isprop(t,'LineWidth'), t.LineWidth = max(0.5, style.lineWidth*0.5); end
                    if isprop(t,'Color'), t.Color = [0 0 0]; end
                catch
                end
            end

            SmartFigureEngine.normalizeInAxesTextboxes(fig, ax, legendFs);

            SmartFigureEngine.enforceSubplotLabelPlacement(ax, style);
        end

        function applyLineSystem(fig, style)
            ln = findall(fig,'Type','line');
            for L = ln(:)'
                try
                    if isprop(L,'LineWidth'), L.LineWidth = max(style.lineWidth,1.1); end
                    if isprop(L,'MarkerSize'), L.MarkerSize = style.markerSize; end
                    if isprop(L,'Marker') && ~strcmp(L.Marker,'none')
                        if isprop(L,'LineStyle') && strcmp(L.LineStyle,'-')
                            L.LineStyle = '--';
                        end
                        if isprop(L,'MarkerEdgeColor')
                            L.MarkerEdgeColor = 'none';
                        end
                        if isprop(L,'MarkerFaceColor') && (ischar(L.MarkerFaceColor) || isstring(L.MarkerFaceColor))
                            if strcmp(string(L.MarkerFaceColor),'none') && isprop(L,'Color')
                                L.MarkerFaceColor = L.Color;
                            end
                        end
                    end
                catch
                end
            end

            sc = findall(fig,'Type','scatter');
            for S = sc(:)'
                try
                    if isprop(S,'SizeData'), S.SizeData = style.markerSize^2; end
                    if isprop(S,'LineWidth'), S.LineWidth = max(0.5, min(0.9, style.lineWidth*0.35)); end
                catch
                end
            end
        end

        function applyLegendSystem(fig, style)
            lg = findall(fig,'Type','legend');
            legendFs = SmartFigureEngine.getSharedLegendTextFont(style);
            for L = lg(:)'
                try
                    if isprop(L,'AutoUpdate'), L.AutoUpdate = 'off'; end
                    if isprop(L,'Units'), L.Units = 'normalized'; end
                    if isprop(L,'LocationMode'), L.LocationMode = 'auto'; end

                    isManualLegend = false;
                    try
                        if isprop(L,'Location')
                            isManualLegend = strcmpi(char(L.Location),'none');
                        end
                    catch
                    end

                    L.FontSize = legendFs;
                    if isprop(L,'Interpreter'), L.Interpreter = 'latex'; end
                    if isprop(L,'Location')
                        if ~isManualLegend
                            L.Location = 'northeast';
                        else
                            L.Location = 'none';
                        end
                    end
                    if isprop(L,'Orientation'), L.Orientation = 'vertical'; end
                    if isprop(L,'Box'), L.Box = 'off'; end

                    if isManualLegend && isprop(L,'Position')
                        try
                            SmartFigureEngine.positionManualLegendNearTopRight(L, style);
                        catch
                        end
                    end
                catch
                end
            end
        end

        function positionManualLegendNearTopRight(L, style)
            try
                if isempty(L) || ~isgraphics(L,'legend') || ~isprop(L,'Position')
                    return;
                end

                parentAx = [];
                try
                    if isprop(L,'Parent') && ~isempty(L.Parent) && isgraphics(L.Parent,'axes')
                        parentAx = L.Parent;
                    end
                catch
                end
                if isempty(parentAx)
                    try
                        parentAx = ancestor(L,'axes');
                    catch
                        parentAx = [];
                    end
                end
                if isempty(parentAx) || ~isgraphics(parentAx,'axes')
                    return;
                end

                oldAxUnits = '';
                try
                    if isprop(parentAx,'Units')
                        oldAxUnits = parentAx.Units;
                        parentAx.Units = 'normalized';
                    end
                catch
                end

                axPos = [];
                try
                    axPos = parentAx.Position;
                catch
                end

                try
                    if ~isempty(oldAxUnits) && isprop(parentAx,'Units')
                        parentAx.Units = oldAxUnits;
                    end
                catch
                end

                if isempty(axPos) || numel(axPos) < 4
                    return;
                end

                p = L.Position;
                if numel(p) < 4 || p(3) <= 0 || p(4) <= 0
                    return;
                end

                colGap = 0.05;
                rowGap = 0.05;
                try
                    if isfield(style,'colGap') && isnumeric(style.colGap) && isfinite(style.colGap)
                        colGap = max(0, style.colGap);
                    end
                catch
                end
                try
                    if isfield(style,'rowGap') && isnumeric(style.rowGap) && isfinite(style.rowGap)
                        rowGap = max(0, style.rowGap);
                    end
                catch
                end

                insetX = max(0.008, min(0.028, 0.18*colGap + 0.02));
                insetY = max(0.008, min(0.028, 0.18*rowGap + 0.02));

                targetX = axPos(1) + axPos(3) - p(3) - insetX;
                targetY = axPos(2) + axPos(4) - p(4) - insetY;

                xMin = axPos(1) + 0.001;
                xMax = axPos(1) + axPos(3) - p(3) - 0.001;
                yMin = axPos(2) + 0.001;
                yMax = axPos(2) + axPos(4) - p(4) - 0.001;

                if xMax < xMin || yMax < yMin
                    return;
                end

                p(1) = min(max(targetX, xMin), xMax);
                p(2) = min(max(targetY, yMin), yMax);
                L.Position = p;
            catch
            end
        end

        function finalize(fig, style)
            SmartFigureEngine.bringMarkersToFront(fig);
            SmartFigureEngine.enforceAnnotationHierarchy(fig, SmartFigureEngine.getSharedLegendTextFont(style));
            if ~isfield(style,'detectTextOverlaps') || style.detectTextOverlaps
                SmartFigureEngine.resolveTextOverlaps(fig, style);
            end
            SmartFigureEngine.solveLabelOverflow(fig, style);
            SmartFigureEngine.warnLabelOverflow(fig);
            drawnow limitrate;
        end

        function validateEngine(fig)
            disp('Validating style consistency...');
            ax = findall(fig,'Type','axes');
            for k = 1:numel(ax)
                if isprop(ax(k),'TickLabelInterpreter')
                    assert(any(strcmpi(ax(k).TickLabelInterpreter, {'tex','latex'})));
                end
            end
        end

        function attachAutoReflow(fig)
            if isempty(fig) || ~isvalid(fig), return; end
            if isappdata(fig,'SmartFigureEngine_SizeListener')
                l = getappdata(fig,'SmartFigureEngine_SizeListener');
                try
                    if isvalid(l), return; end
                catch
                end
            end
            try
                l = addlistener(fig, 'SizeChanged', @(~,~) SmartFigureEngine.autoReflow(fig));
                setappdata(fig,'SmartFigureEngine_SizeListener',l);
            catch
            end
        end

        function autoReflow(fig, style)
            if isempty(fig) || ~isvalid(fig) || ~isgraphics(fig,'figure'), return; end
            if isappdata(fig,'SmartFigureEngine_IsApplying') && getappdata(fig,'SmartFigureEngine_IsApplying')
                return;
            end

            if nargin >= 2 && isstruct(style)
                ax = SmartFigureEngine.getDataAxes(fig);
                if numel(ax) > 1
                    if strcmpi(SmartFigureEngine.getGeometryMode(style),'deterministic-grid')
                        SmartFigureEngine.applyDeterministicGridGeometry(fig, ax, style);
                    else
                        SmartFigureEngine.applyMultiPanelGeometry(fig, ax, style);
                    end
                    SmartFigureEngine.recenterYLabelsForAxes(ax);
                    SmartFigureEngine.enforceReferenceLinesBehindData(fig);
                    SmartFigureEngine.attachYLimRecenteringListeners(ax);
                    return;
                end
            end

            try
                p = fig.Position;
                panelWidth = max(1.0, p(3)/96);
                panelHeight = max(1.0, p(4)/96);
            catch
                return;
            end

            style0 = [];
            if isappdata(fig,'SmartFigureEngine_LastStyle')
                style0 = getappdata(fig,'SmartFigureEngine_LastStyle');
            end
            mode = 'PRL'; nx = 1; ny = 1;
            if isstruct(style0)
                if isfield(style0,'mode'), mode = style0.mode; end
                if isfield(style0,'nx'), nx = style0.nx; end
                if isfield(style0,'ny'), ny = style0.ny; end
            end

            style = SmartFigureEngine.computeSmartStyle(panelWidth, panelHeight, nx, ny, mode);
            style.applyPreviewResize = false;
            style.enableAutoReflow = false;
            SmartFigureEngine.applyFullSmart(fig, style);
        end

        function setLegendLocation(fig, loc)
            if isempty(fig) || ~isvalid(fig) || ~isgraphics(fig,'figure'), return; end
            lg = findall(fig,'Type','legend');
            for L = lg(:)'
                try
                    if isprop(L,'Location'), L.Location = loc; end
                catch
                end
            end
        end

        function applyLegendAnnotationFontOnly(fig, fontSize)
            if isempty(fig) || ~isvalid(fig) || ~isgraphics(fig,'figure')
                return;
            end
            if nargin < 2 || ~isnumeric(fontSize) || ~isfinite(fontSize) || fontSize <= 0
                return;
            end

            fs = max(1, round(fontSize));
            try
                setappdata(0,'SmartFigureEngine_GlobalLegendFont',fs);
            catch
            end

            lg = findall(fig,'Type','legend');
            for L = lg(:)'
                try
                    if isprop(L,'FontUnits'), L.FontUnits = 'points'; end
                    L.FontSize = fs;
                    if isprop(L,'Interpreter'), L.Interpreter = 'latex'; end
                catch
                end
            end

            ax = SmartFigureEngine.getDataAxes(fig);
            excludedText = gobjects(0);
            for a = ax(:)'
                try, excludedText(end+1,1) = a.XLabel; catch, end %#ok<AGROW>
                try, excludedText(end+1,1) = a.YLabel; catch, end %#ok<AGROW>
                try, excludedText(end+1,1) = a.Title;  catch, end %#ok<AGROW>
            end

            tx = findall(fig,'Type','text');
            for t = tx(:)'
                try
                    if ~isempty(excludedText) && any(t == excludedText)
                        continue;
                    end

                    includeManualLegendText = false;

                    % Figure-level text (not inside axes) is treated as manual legend/annotation text
                    pAx = [];
                    try, pAx = ancestor(t,'axes'); catch, end
                    if isempty(pAx)
                        includeManualLegendText = true;
                    end

                    % Explicit legend-like tagging on text or parent/group
                    if ~includeManualLegendText
                        tagVal = "";
                        nameVal = "";
                        pTag = "";
                        gpTag = "";
                        try, if isprop(t,'Tag'), tagVal = lower(string(t.Tag)); end, catch, end
                        try, if isprop(t,'DisplayName'), nameVal = lower(string(t.DisplayName)); end, catch, end
                        try
                            p = t.Parent;
                            if ~isempty(p) && isgraphics(p) && isprop(p,'Tag')
                                pTag = lower(string(p.Tag));
                            end
                        catch
                        end
                        try
                            gp = ancestor(t,'hggroup');
                            if ~isempty(gp) && isprop(gp,'Tag')
                                gpTag = lower(string(gp.Tag));
                            end
                        catch
                        end

                        if contains(tagVal,'legend') || contains(nameVal,'legend') || contains(pTag,'legend') || contains(gpTag,'legend')
                            includeManualLegendText = true;
                        end
                    end

                    if includeManualLegendText
                        SmartFigureEngine.applyTextObj(t, fs);
                    end
                catch
                end
            end

            txb = findall(fig,'Type','textboxshape');
            for t = txb(:)'
                try
                    SmartFigureEngine.applyTextObj(t, fs);
                    if isprop(t,'Interpreter'), t.Interpreter = 'latex'; end
                catch
                end
            end

            annTypes = {'textarrowshape','arrowshape','doubleendarrowshape'};
            for i = 1:numel(annTypes)
                a = findall(fig,'Type',annTypes{i});
                for h = a(:)'
                    try
                        if isprop(h,'FontUnits'), h.FontUnits = 'points'; end
                        if isprop(h,'FontSize'), h.FontSize = fs; end
                        if isprop(h,'Interpreter'), h.Interpreter = 'latex'; end
                    catch
                    end
                end
            end
        end

        function applyAnnotationStyle(fig, style)
            % Apply annotation textbox styling using EXACT same logic as legend FontSize
            % Uses getSharedLegendTextFont to ensure identical behavior
            
            if nargin < 2 || isempty(fig) || ~isvalid(fig) || ~isgraphics(fig,'figure')
                return;
            end
            
            % Find all annotation textboxes
            ann = findall(fig, 'Type', 'textboxshape');
            if isempty(ann)
                return;
            end
            
            % Use the EXACT same FontSize resolution as legend
            fs = SmartFigureEngine.getSharedLegendTextFont(style);
            
            % Apply FontSize to each textbox
            for k = 1:numel(ann)
                try
                    ann(k).FontSize = fs;
                catch
                    % Skip annotation if property setting fails
                end
            end
        end

        function setStyleLock(fig, tf)
            if nargin < 2, tf = true; end
            if isempty(fig) || ~isvalid(fig) || ~isgraphics(fig,'figure'), return; end
            setappdata(fig,'SmartFigureEngine_StyleLock',logical(tf));
        end

        function setDebug(tf)
            if nargin < 1, tf = true; end
            setappdata(0,'SmartFigureEngine_Debug', logical(tf));
            fprintf('[SmartEngine] Debug mode: %s\n', string(logical(tf)));
        end

        function report = validateFigureConsistency(fig)
            report = struct('axesCount',0,'passed',true,'issues',{{}},'diagnostics',[]);
            if nargin < 1 || isempty(fig) || ~isvalid(fig) || ~isgraphics(fig,'figure')
                report.passed = false;
                report.issues{end+1} = 'Invalid figure handle';
                disp('[CONSISTENCY] Invalid figure handle');
                return;
            end

            diagRows = struct('check',{},'handle',{},'property',{},'value',{},'suggestion',{});
            function addIssue(checkName, h, propName, val, fixHint)
                row = struct('check',checkName,'handle',h,'property',propName,'value',val,'suggestion',fixHint);
                diagRows(end+1) = row; %#ok<AGROW>
                report.issues{end+1} = sprintf('%s | %s=%s', checkName, propName, string(val));
                report.passed = false;
            end

            ax = SmartFigureEngine.getDataAxes(fig);
            report.axesCount = numel(ax);
            if isempty(ax)
                addIssue('AxisDiscovery', fig, 'axesCount', 0, 'Ensure getDataAxes returns all real plotting axes');
            end

            refTick = NaN;
            refLabel = NaN;
            refLineWidth = NaN;
            if ~isempty(ax)
                try, refTick = ax(1).FontSize; catch, end
                try, refLabel = ax(1).XLabel.FontSize; catch, end
                try
                    l0 = findall(ax(1),'Type','line');
                    if ~isempty(l0), refLineWidth = l0(1).LineWidth; end
                catch
                end
            end

            for k = 1:numel(ax)
                a = ax(k);
                try
                    if isprop(a,'FontSize') && a.FontSize <= 10
                        addIssue('FontHierarchy', a, 'FontSize', a.FontSize, 'Apply SMART typography to all axes');
                    end
                    if isfinite(refTick) && abs(a.FontSize - refTick) > 2
                        addIssue('FontHierarchy', a, 'FontSize', a.FontSize, 'Normalize tick font hierarchy across panels');
                    end
                catch
                end

                try
                    if isgraphics(a.XLabel) && a.XLabel.FontSize <= 10
                        addIssue('LabelScaling', a.XLabel, 'FontSize', a.XLabel.FontSize, 'Scale subplot/shared X labels with style');
                    end
                    if isfinite(refLabel) && isgraphics(a.XLabel) && abs(a.XLabel.FontSize - refLabel) > 2
                        addIssue('LabelScaling', a.XLabel, 'FontSize', a.XLabel.FontSize, 'Normalize label hierarchy');
                    end
                catch
                end
                try
                    p = a.Position;
                    if any(p < 0) || (p(1)+p(3) > 1.001) || (p(2)+p(4) > 1.001)
                        addIssue('GeometryBounds', a, 'Position', mat2str(p,4), 'Clamp or reflow axes into normalized bounds');
                    end
                    if numel(ax) > 1 && (p(1) < 0.005 || p(2) < 0.005)
                        addIssue('MarginCorrectness', a, 'Position', mat2str(p,4), 'Increase left/top propagation for multi-panel layout');
                    end
                catch
                end

                try
                    ov = SmartFigureEngine.getAxisLabelOverflow(a);
                    if ov.xOverflow > 0
                        addIssue('XLabelClipping', a.XLabel, 'Overflow', ov.xOverflow, 'Increase bottomMargin using extent delta');
                    end
                    if ov.yOverflow > 0
                        addIssue('YLabelClipping', a.YLabel, 'Overflow', ov.yOverflow, 'Increase leftMargin using extent delta');
                    end
                    if ov.titleOverflow > 0
                        addIssue('TitleClipping', a.Title, 'Overflow', ov.titleOverflow, 'Increase topMargin using extent delta');
                    end
                catch
                end
                try
                    if isa(a,'matlab.graphics.illustration.ColorBar')
                        addIssue('AxisDiscovery', a, 'Class', class(a), 'Exclude colorbars from getDataAxes');
                    end
                catch
                end

                try
                    xl = a.XLim;
                    if isnumeric(xl) && numel(xl)==2 && abs(xl(1)+xl(2)) < 1e-8
                        xt = a.XTick;
                        if isnumeric(xt) && numel(xt) > 1
                            if max(abs(sort(xt) + sort(-xt))) > 1e-8
                                addIssue('TickSymmetry', a, 'XTick', mat2str(xt,5), 'Apply symmetric ticks after reduction');
                            end
                        end
                    end
                catch
                end

                try
                    lns = findall(a,'Type','line');
                    if ~isempty(lns)
                        lw = [lns.LineWidth];
                        if any(lw <= 0)
                            addIssue('LineWidthConsistency', a, 'LineWidth', mat2str(lw,3), 'Ensure positive deterministic line widths');
                        elseif isfinite(refLineWidth) && any(abs(lw - refLineWidth) > max(0.01,0.7*abs(refLineWidth)))
                            addIssue('LineWidthConsistency', a, 'LineWidth', mat2str(lw,3), 'Normalize line width hierarchy');
                        end
                    end
                catch
                end
            end

            if numel(ax) > 1
                try
                    pos = vertcat(ax.Position);
                    h = pos(:,4);
                    if max(h)-min(h) > 0.06
                        addIssue('SubplotUniformity', fig, 'RowHeights', mat2str(h,3), 'Reflow rows to consistent panel heights');
                    end
                catch
                end

                try
                    yFonts = zeros(numel(ax),1);
                    xFonts = zeros(numel(ax),1);
                    for i = 1:numel(ax)
                        yFonts(i) = ax(i).YLabel.FontSize;
                        xFonts(i) = ax(i).XLabel.FontSize;
                    end
                    if any(yFonts > max(refLabel, 1) * 1.01)
                        addIssue('YLabelMultiPanelScale', fig, 'YLabel.FontSize', mat2str(yFonts,3), 'Reduce Y label size slightly for multi-panel layout');
                    end
                    if all(xFonts <= styleFromAxes(ax(1), 'tick'))
                        addIssue('SharedXLabelScale', fig, 'XLabel.FontSize', mat2str(xFonts,3), 'Ensure shared/bottom X label scales above tick font');
                    end
                catch
                end

                try
                    pos = vertcat(ax.Position);
                    minBottom = min(pos(:,2));
                    bottomIdx = find(abs(pos(:,2)-minBottom) <= 0.03);
                    baseline = [];
                    for j = 1:numel(bottomIdx)
                        a = ax(bottomIdx(j));
                        p = a.Position;
                        lp = a.XLabel.Position;
                        baseline(end+1) = p(2) + lp(2)*p(4); %#ok<AGROW>
                    end
                    if numel(baseline) > 1 && (max(baseline)-min(baseline) > 0.01)
                        addIssue('XLabelBaselineAligned', fig, 'XLabelBaselineSpread', max(baseline)-min(baseline), 'Align bottom X-label baseline deterministically');
                    end
                catch
                end
            end

            lg = findall(fig,'Type','legend');
            snap = [];
            if isappdata(fig,'SmartFigureEngine_LegendSnapshot')
                try
                    snap = getappdata(fig,'SmartFigureEngine_LegendSnapshot');
                catch
                end
            end

            if ~isempty(snap)
                for i = 1:numel(snap)
                    try
                        parentAx = snap(i).Parent;
                        if isempty(parentAx) || ~isgraphics(parentAx), continue; end
                        curr = findall(fig,'Type','legend','Parent',parentAx);
                        if isempty(curr)
                            addIssue('LegendOrderPreserved', parentAx, 'Legend', 'missing', 'Legend disappeared after SMART apply');
                            continue;
                        end
                        currStr = curr(1).String;
                        if ischar(currStr), currStr = {currStr}; end
                        oldStr = snap(i).Strings;
                        if numel(currStr) ~= numel(oldStr)
                            addIssue('LegendEntryCount', curr(1), 'StringCount', sprintf('%d->%d', numel(oldStr), numel(currStr)), 'Preserve legend entry count under SMART formatting');
                        elseif ~isequal(currStr(:), oldStr(:))
                            addIssue('LegendOrderPreserved', curr(1), 'StringOrder', 'changed', 'Do not reorder legend entries unless Reverse Legend is explicitly requested');
                        end

                        try
                            if isfield(snap(i),'NumColumns') && ~isempty(snap(i).NumColumns) && isprop(curr(1),'NumColumns') && curr(1).NumColumns ~= snap(i).NumColumns
                                addIssue('LegendNumColumnsUnchanged', curr(1), 'NumColumns', sprintf('%g->%g', snap(i).NumColumns, curr(1).NumColumns), 'Preserve legend NumColumns unless explicit layout flag is enabled');
                            end
                        catch
                        end
                        try
                            if isfield(snap(i),'Orientation') && ~isempty(snap(i).Orientation) && isprop(curr(1),'Orientation')
                                currOrient = char(string(curr(1).Orientation));
                                if ~strcmpi(currOrient, snap(i).Orientation)
                                    addIssue('LegendOrientationUnchanged', curr(1), 'Orientation', sprintf('%s->%s', snap(i).Orientation, currOrient), 'Preserve legend orientation unless explicit layout flag is enabled');
                                end
                            end
                        catch
                        end
                    catch
                    end
                end
            end

            if numel(lg) > 1
                parents = gobjects(0);
                for i = 1:numel(lg)
                    try
                        parents(end+1) = lg(i).Parent; %#ok<AGROW>
                    catch
                    end
                end
                if ~isempty(parents)
                    if numel(unique(parents)) < numel(parents)
                        addIssue('LegendIsolation', fig, 'LegendCount', numel(lg), 'Avoid duplicated legends for same parent axes');
                    end
                end
            end

            txb = findall(fig,'Type','textboxshape');
            for i = 1:numel(txb)
                try
                    if txb(i).FontSize <= 10
                        addIssue('TextboxInclusion', txb(i), 'FontSize', txb(i).FontSize, 'Scale annotation textboxes with SMART style');
                    end
                catch
                end
            end

            tx = findall(fig,'Type','text');
            for i = 1:numel(tx)
                try
                    if strcmpi(tx(i).Visible,'off'), continue; end
                    if tx(i).FontSize <= 9
                        addIssue('VisibleTextScaled', tx(i), 'FontSize', tx(i).FontSize, 'Scale all visible text objects (manual legends, headers, labels) with style');
                    end
                catch
                end
            end

            function v = styleFromAxes(a, key)
                v = 10;
                try
                    switch key
                        case 'tick'
                            v = a.FontSize;
                    end
                catch
                end
            end

            report.diagnostics = diagRows;

            fprintf('[CONSISTENCY] axes=%d | issues=%d\n', report.axesCount, numel(report.issues));
            for i = 1:numel(diagRows)
                hLabel = 'n/a';
                try
                    hLabel = sprintf('%.0f', double(diagRows(i).handle));
                catch
                end
                fprintf('  - [%s] handle=%s prop=%s value=%s | fix=%s\n', ...
                    diagRows(i).check, hLabel, diagRows(i).property, string(diagRows(i).value), diagRows(i).suggestion);
            end
        end

        function formatForPaper(fig, styleMode)
            if nargin < 1 || isempty(fig)
                fig = gcf;
            end
            if nargin < 2 || isempty(styleMode)
                styleMode = 'PRL';
            end

            try
                p = fig.Position;
                panelWidth = max(1.0, p(3)/96);
                panelHeight = max(1.0, p(4)/96);
            catch
                panelWidth = 3.5;
                panelHeight = 2.6;
            end

            style = SmartFigureEngine.computeSmartStyle(panelWidth, panelHeight, 1, 1, styleMode);
            style.applyPreviewResize = false;
            SmartFigureEngine.applyFullSmart(fig, style);
        end

        function appearanceStyle = buildAppearanceStyleFromUI(mapName, spreadMode, useFolder, folderPath, ...
                fitColorRaw, dataWidthRaw, dataStyleRaw, markerSizeRaw, fitWidthRaw, fitStyleRaw, ...
                reverseOrder, reverseLegend, noMapChange, targetFigs, scm8Maps)

            if nargin < 1 || isempty(mapName), mapName = '(no change)'; end
            if nargin < 2 || isempty(spreadMode), spreadMode = 'medium'; end
            if nargin < 3 || isempty(useFolder), useFolder = false; end
            if nargin < 4, folderPath = ''; end
            if nargin < 5, fitColorRaw = ''; end
            if nargin < 6, dataWidthRaw = []; end
            if nargin < 7, dataStyleRaw = ''; end
            if nargin < 8, markerSizeRaw = []; end
            if nargin < 9, fitWidthRaw = []; end
            if nargin < 10, fitStyleRaw = ''; end
            if nargin < 11, reverseOrder = false; end
            if nargin < 12, reverseLegend = false; end
            if nargin < 13, noMapChange = false; end
            if nargin < 14, targetFigs = []; end
            if nargin < 15, scm8Maps = {}; end

            fitColor = char(string(fitColorRaw));
            if strcmpi(strtrim(fitColor), '(no change)')
                fitColor = '';
            end

            dataWidth = SmartFigureEngine.parsePositiveNumeric(dataWidthRaw);
            markerSize = SmartFigureEngine.parsePositiveNumeric(markerSizeRaw);
            fitWidth = SmartFigureEngine.parsePositiveNumeric(fitWidthRaw);

            dataStyle = char(string(dataStyleRaw));
            if strcmpi(strtrim(dataStyle), '(no change)')
                dataStyle = '';
            end

            fitStyle = char(string(fitStyleRaw));
            if strcmpi(strtrim(fitStyle), '(no change)')
                fitStyle = '';
            end

            folderPath = strtrim(char(string(folderPath)));
            noColormapChange = logical(noMapChange) || strcmpi(strtrim(char(string(mapName))), '(no change)');

            appearanceStyle = struct( ...
                'mapName', char(string(mapName)), ...
                'spreadMode', char(string(spreadMode)), ...
                'useFolder', logical(useFolder), ...
                'folderPath', folderPath, ...
                'fitColor', fitColor, ...
                'dataWidth', dataWidth, ...
                'dataStyle', dataStyle, ...
                'markerSize', markerSize, ...
                'fitWidth', fitWidth, ...
                'fitStyle', fitStyle, ...
                'reverseOrder', logical(reverseOrder), ...
                'reverseLegend', logical(reverseLegend), ...
                'noMapChange', noColormapChange, ...
                'targetFigs', targetFigs, ...
                'scm8Maps', {scm8Maps});
        end

        function applyAppearanceToTargets(appearanceStyle)
            if nargin < 1 || ~isstruct(appearanceStyle)
                error('SmartFigureEngine:InvalidAppearanceStyle', 'appearanceStyle must be a struct');
            end

            SmartFigureEngine.applyColormapToFigures(appearanceStyle.mapName, appearanceStyle.folderPath, appearanceStyle.spreadMode, ...
                appearanceStyle.fitColor, appearanceStyle.dataWidth, appearanceStyle.dataStyle, appearanceStyle.fitWidth, ...
                appearanceStyle.fitStyle, appearanceStyle.reverseOrder, appearanceStyle.reverseLegend, ...
                appearanceStyle.noMapChange, appearanceStyle.markerSize, appearanceStyle.targetFigs, appearanceStyle.scm8Maps, ...
                appearanceStyle.useFolder);
        end

        function applyAppearance(fig, appearanceStyle)
            if nargin < 2 || ~isstruct(appearanceStyle)
                error('SmartFigureEngine:InvalidAppearanceStyle', 'appearanceStyle must be a struct');
            end

            if appearanceStyle.noMapChange
                cmapFull = [];
            else
                cmapFull = SmartFigureEngine.getColormapToUse(appearanceStyle.mapName, appearanceStyle.scm8Maps);
            end

            SmartFigureEngine.applyToSingleFigure(fig, cmapFull, appearanceStyle.spreadMode, ...
                appearanceStyle.fitColor, appearanceStyle.dataWidth, appearanceStyle.dataStyle, ...
                appearanceStyle.fitWidth, appearanceStyle.fitStyle, appearanceStyle.reverseOrder, ...
                appearanceStyle.reverseLegend, appearanceStyle.markerSize);
        end

        function cmap = getColormapForPreview(mapName, scm8Maps)
            if nargin < 2, scm8Maps = {}; end
            cmap = SmartFigureEngine.getColormapToUse(mapName, scm8Maps);
        end
    end

    methods(Static, Access=private)
        function captureLegendSnapshot(fig)
            snap = struct('Parent',{},'ParentId',{},'Strings',{});
            lg = findall(fig,'Type','legend');
            for i = 1:numel(lg)
                try
                    s = lg(i).String;
                    if ischar(s), s = {s}; end
                    p = lg(i).Parent;
                    pid = NaN;
                    try, pid = double(p); catch, end
                    ncols = [];
                    orient = '';
                    try, if isprop(lg(i),'NumColumns'), ncols = lg(i).NumColumns; end, catch, end
                    try, if isprop(lg(i),'Orientation'), orient = char(string(lg(i).Orientation)); end, catch, end
                    snap(end+1) = struct('Parent',p,'ParentId',pid,'Strings',{s},'NumColumns',ncols,'Orientation',orient); %#ok<AGROW>
                catch
                end
            end
            setappdata(fig,'SmartFigureEngine_LegendSnapshot',snap);
        end

        function snapItem = getLegendSnapshotForLegend(fig, legendObj)
            snapItem = [];
            if ~isappdata(fig,'SmartFigureEngine_LegendSnapshot'), return; end
            try
                snap = getappdata(fig,'SmartFigureEngine_LegendSnapshot');
            catch
                return;
            end
            if isempty(snap), return; end

            parentId = NaN;
            try, parentId = double(legendObj.Parent); catch, end
            for i = 1:numel(snap)
                try
                    if isequal(snap(i).Parent, legendObj.Parent) || (~isnan(parentId) && isfield(snap(i),'ParentId') && snap(i).ParentId == parentId)
                        snapItem = snap(i);
                        return;
                    end
                catch
                end
            end
        end

        function applyTextObj(obj, fs)
            try
                if isempty(obj) || ~isgraphics(obj), return; end
                if isprop(obj,'FontUnits'), obj.FontUnits = 'points'; end
                if isprop(obj,'FontSize'), obj.FontSize = fs; end
                if isprop(obj,'Interpreter'), obj.Interpreter = 'latex'; end
            catch
            end
        end

        function placeAxisLabels(a, style, isSubplot)
            xPad = 0.0;
            yPad = 0.0;
            subplotExtraXPad = 0.0;
            subplotExtraYPad = 0.0;
            try
                isSafeMode = ~(isfield(style,'safeMode') && ~style.safeMode);
                isDeterministic = strcmpi(SmartFigureEngine.getGeometryMode(style), 'deterministic-grid');
                if isSafeMode && isDeterministic
                    if isfield(style,'xLabelPadNormalized') && isnumeric(style.xLabelPadNormalized) && isfinite(style.xLabelPadNormalized)
                        xPad = max(0, style.xLabelPadNormalized);
                    else
                        xPad = 0.08;
                    end
                    if isfield(style,'yLabelPadNormalized') && isnumeric(style.yLabelPadNormalized) && isfinite(style.yLabelPadNormalized)
                        yPad = max(0, style.yLabelPadNormalized);
                    else
                        yPad = 0.08;
                    end
                    if isSubplot && isfield(style,'ny') && isnumeric(style.ny) && isfinite(style.ny) && style.ny > 1
                        if isfield(style,'xLabelPadSubplotExtra') && isnumeric(style.xLabelPadSubplotExtra) && isfinite(style.xLabelPadSubplotExtra)
                            subplotExtraXPad = max(0, style.xLabelPadSubplotExtra);
                        else
                            subplotExtraXPad = 0.04;
                        end
                        if isfield(style,'yLabelPadSubplotExtra') && isnumeric(style.yLabelPadSubplotExtra) && isfinite(style.yLabelPadSubplotExtra)
                            subplotExtraYPad = style.yLabelPadSubplotExtra;
                        else
                            subplotExtraYPad = 0.04;
                        end
                    end
                end
            catch
                xPad = 0.08;
                yPad = 0.08;
                subplotExtraXPad = 0.06;
                subplotExtraYPad = 0.04;
            end

            try
                a.XLabel.Units = 'normalized';
                xPos = a.XLabel.Position;
                xPadEff = max(0.10, xPad + subplotExtraXPad);
                xPos(2) = -xPadEff;
                a.XLabel.Position = xPos;
                a.XLabel.HorizontalAlignment = 'center';
                a.XLabel.VerticalAlignment = 'top';
            catch
            end
            try
                a.YLabel.Units = 'normalized';
                yPos = a.YLabel.Position;
                yPadEff = max(0.045, yPad + subplotExtraYPad);
                yPos(1) = -yPadEff;
                a.YLabel.Position = yPos;
                a.YLabel.Rotation = 90;
                a.YLabel.HorizontalAlignment = 'center';
                a.YLabel.VerticalAlignment = 'bottom';
            catch
            end

            SmartFigureEngine.recenterYLabelOnAxes(a);
        end

        function recenterYLabelsForFigure(fig)
            ax = SmartFigureEngine.getDataAxes(fig);
            SmartFigureEngine.recenterYLabelsForAxes(ax);
        end

        function recenterYLabelsForAxes(ax)
            if isempty(ax)
                return;
            end
            for a = ax(:)'
                SmartFigureEngine.recenterYLabelOnAxes(a);
            end
        end

        function recenterYLabelOnAxes(ax)
            try
                if isempty(ax) || ~(isgraphics(ax,'axes') || isgraphics(ax,'uiaxes'))
                    return;
                end
                yl = [];
                try
                    yl = ax.YLabel;
                catch
                end
                if isempty(yl) || ~isgraphics(yl)
                    return;
                end

                yLimits = ax.YLim;
                if isempty(yLimits) || numel(yLimits) < 2 || any(~isfinite(yLimits))
                    return;
                end
                yCenter = mean(yLimits);

                yl.Units = 'data';
                pos = yl.Position;
                if numel(pos) < 2
                    return;
                end
                pos(2) = yCenter;
                yl.Position = pos;
            catch
            end
        end

        function attachYLimRecenteringListeners(ax)
            if isempty(ax)
                return;
            end

            for a = ax(:)'
                try
                    if isempty(a) || ~(isgraphics(a,'axes') || isgraphics(a,'uiaxes'))
                        continue;
                    end

                    if isappdata(a,'SmartFigureEngine_YLimListener')
                        l = getappdata(a,'SmartFigureEngine_YLimListener');
                        try
                            if isvalid(l)
                                continue;
                            end
                        catch
                        end
                    end

                    l = addlistener(a, 'YLim', 'PostSet', @(~,evt) SmartFigureEngine.onAxisYLimChanged(evt));
                    setappdata(a,'SmartFigureEngine_YLimListener',l);
                catch
                end
            end
        end

        function onAxisYLimChanged(evt)
            try
                ax = [];
                try
                    if isprop(evt,'AffectedObject')
                        ax = evt.AffectedObject;
                    end
                catch
                end
                if isempty(ax)
                    return;
                end
                SmartFigureEngine.recenterYLabelOnAxes(ax);
            catch
            end
        end

        function style = syncSafeModeMarginsFromAxes(fig, style)
            isSafeMode = ~(isfield(style,'safeMode') && ~style.safeMode);
            if ~isSafeMode
                return;
            end
            if strcmpi(SmartFigureEngine.getGeometryMode(style),'deterministic-grid')
                return;
            end
            ax = SmartFigureEngine.getDataAxes(fig);
            if isempty(ax)
                return;
            end
            if numel(ax) == 1
                return;
            end
            try
                pos = vertcat(ax.Position);
                style.bottomMargin = min(pos(:,2));
                style.leftMargin = min(pos(:,1));
            catch
            end
        end

        function ax = getDataAxes(fig)
            if nargin < 1 || isempty(fig) || ~isvalid(fig) || ~isgraphics(fig)
                ax = [];
                return;
            end

            ax = gobjects(0);
            try
                axClassic = findall(fig, 'Type', 'axes');
                if ~isempty(axClassic)
                    ax = [ax; axClassic(:)]; %#ok<AGROW>
                end
            catch
            end
            try
                axUi = findall(fig, 'Type', 'uiaxes');
                if ~isempty(axUi)
                    ax = [ax; axUi(:)]; %#ok<AGROW>
                end
            catch
            end
            if isempty(ax), return; end

            try
                ax = unique(ax, 'stable');
            catch
            end

            keep = true(size(ax));
            for k = 1:numel(ax)
                a = ax(k);

                if isa(a, 'matlab.graphics.illustration.Legend') || isa(a, 'matlab.graphics.illustration.ColorBar')
                    keep(k) = false;
                    continue;
                end

                tagVal = "";
                try
                    tagVal = string(a.Tag);
                catch
                end
                if strlength(tagVal) > 0
                    if strcmpi(tagVal, "MT_Legend_Axes")
                        keep(k) = false;
                        continue;
                    end
                    if contains(tagVal, ["legend","colorbar","helper","temp"], 'IgnoreCase', true)
                        keep(k) = false;
                        continue;
                    end
                end

                try
                    if isprop(a,'Visible') && ~strcmpi(char(a.Visible),'on')
                        keep(k) = false;
                        continue;
                    end
                catch
                end
            end

            ax = ax(keep);
        end

        function tf = isColorbarAxes(a)
            tf = false;
            try
                if isprop(a,'Tag') && contains(string(a.Tag),'Colorbar','IgnoreCase',true)
                    tf = true; return;
                end
                p = a.Position;
                if p(3) < 0.07 || p(4) < 0.07
                    tf = true; return;
                end
            catch
            end
        end

        function distributeRowsWithGap(ax, rowGap)
            if numel(ax) < 2, return; end
            try
                pos = vertcat(ax.Position);
                yCenters = pos(:,2) + pos(:,4)/2;
                yVals = SmartFigureEngine.clusterVals(yCenters, 0.04);
                if numel(yVals) < 2, return; end
                yVals = sort(yVals,'descend');

                bottomByRow = zeros(1,numel(yVals));
                heightByRow = zeros(1,numel(yVals));
                for r = 1:numel(yVals)
                    idx = abs(yCenters-yVals(r)) <= 0.04;
                    bottomByRow(r) = median(pos(idx,2));
                    heightByRow(r) = median(pos(idx,4));
                end

                nRows = numel(yVals);
                topEdge = max(bottomByRow+heightByRow);
                totalGap = rowGap*(nRows-1);
                hScale = min(1.0, max(0.92, (sum(heightByRow)-totalGap)/max(sum(heightByRow),eps)));
                hNew = heightByRow*hScale;

                bNew = zeros(size(bottomByRow));
                curTop = topEdge;
                for r = 1:nRows
                    bNew(r) = curTop - hNew(r);
                    curTop = bNew(r) - rowGap;
                end

                minBottom = min(bNew);
                if minBottom < 0.02
                    bNew = bNew + (0.02-minBottom);
                end

                for k = 1:numel(ax)
                    p = ax(k).Position;
                    [~, r] = min(abs(yVals - (p(2)+p(4)/2)));
                    p(2) = bNew(r);
                    p(4) = hNew(r);
                    ax(k).Position = p;
                end
            catch
            end
        end

        function lockPanelAlignment(ax)
            if numel(ax) < 2, return; end
            pos = vertcat(ax.Position);
            xCenters = pos(:,1)+pos(:,3)/2;
            yCenters = pos(:,2)+pos(:,4)/2;

            xVals = SmartFigureEngine.clusterVals(xCenters,0.035);
            yVals = SmartFigureEngine.clusterVals(yCenters,0.04);
            if isempty(xVals) || isempty(yVals), return; end
            yVals = sort(yVals,'descend');

            leftByCol = zeros(1,numel(xVals));
            widthByCol = zeros(1,numel(xVals));
            for c = 1:numel(xVals)
                idx = abs(xCenters-xVals(c)) <= 0.04;
                leftByCol(c) = median(pos(idx,1));
                widthByCol(c) = median(pos(idx,3));
            end

            bottomByRow = zeros(1,numel(yVals));
            heightByRow = zeros(1,numel(yVals));
            for r = 1:numel(yVals)
                idx = abs(yCenters-yVals(r)) <= 0.04;
                bottomByRow(r) = median(pos(idx,2));
                heightByRow(r) = median(pos(idx,4));
            end

            for k = 1:numel(ax)
                [~,c] = min(abs(xVals - xCenters(k)));
                [~,r] = min(abs(yVals - yCenters(k)));
                ax(k).Units = 'normalized';
                ax(k).Position = [leftByCol(c), bottomByRow(r), widthByCol(c), heightByRow(r)];
            end
        end

        function vals = clusterVals(v, tol)
            vals = [];
            if isempty(v), return; end
            vs = sort(v(:));
            groups = {vs(1)};
            for i = 2:numel(vs)
                if abs(vs(i)-median(groups{end})) <= tol
                    groups{end}(end+1,1) = vs(i); %#ok<AGROW>
                else
                    groups{end+1} = vs(i); %#ok<AGROW>
                end
            end
            vals = cellfun(@median, groups);
        end

        function reduceTicksNice(ax, tickFont)
            %#ok<INUSD>
            % Tick curation disabled: SMART styles ticks but does not modify
            % or prune tick values.
        end

        function applyMultiPanelGeometry(fig, ax, style)
            if numel(ax) < 2, return; end

            layouts = gobjects(0);
            isTiledAxis = false(size(ax));
            for k = 1:numel(ax)
                try
                    tl = ancestor(ax(k), 'tiledlayout');
                    if ~isempty(tl)
                        layouts(end+1) = tl; %#ok<AGROW>
                        isTiledAxis(k) = true;
                    end
                catch
                end
            end

            if ~isempty(layouts)
                layouts = unique(layouts);
                for tl = layouts(:)'
                    SmartFigureEngine.applyTiledLayoutSpacing(tl, style);
                end
            end

            freeAx = ax(~isTiledAxis);
            if isempty(freeAx)
                for a = ax(:)'
                    SmartFigureEngine.placeAxisLabels(a, style, true);
                end
                return;
            end

            for k = 1:numel(freeAx)
                try
                    freeAx(k).Units = 'normalized';
                catch
                end
            end

            pos = SmartFigureEngine.getBaselinePositions(fig, freeAx);
            if isempty(pos), return; end

            for k = 1:numel(freeAx)
                try
                    freeAx(k).Position = pos(k,:);
                catch
                end
            end

            left0 = min(pos(:,1));
            top0 = max(pos(:,2)+pos(:,4));

            targetLeft = max(0.01, min(0.45, style.leftMargin));
            targetTop = max(0.55, min(0.99, 1 - style.topMargin));

            dx = targetLeft - left0;
            dy = targetTop - top0;

            for k = 1:numel(freeAx)
                p = freeAx(k).Position;
                p(1) = p(1) + dx;
                p(2) = p(2) + dy;
                freeAx(k).Position = p;
            end

            pos2 = vertcat(freeAx.Position);
            minLeft = min(pos2(:,1));
            minBottom = min(pos2(:,2));
            maxRight = max(pos2(:,1)+pos2(:,3));
            maxTop = max(pos2(:,2)+pos2(:,4));

            clampDx = 0;
            clampDy = 0;
            if minLeft < 0.01, clampDx = 0.01 - minLeft; end
            if (maxRight + clampDx) > 0.99, clampDx = 0.99 - maxRight; end
            if minBottom < 0.01, clampDy = 0.01 - minBottom; end
            if (maxTop + clampDy) > 0.99, clampDy = 0.99 - maxTop; end

            if clampDx ~= 0 || clampDy ~= 0
                for k = 1:numel(freeAx)
                    p = freeAx(k).Position;
                    p(1) = p(1) + clampDx;
                    p(2) = p(2) + clampDy;
                    freeAx(k).Position = p;
                end
            end

            if numel(freeAx) > 1
                SmartFigureEngine.lockPanelAlignment(freeAx);
                SmartFigureEngine.distributeRowsWithGap(freeAx, style.rowGap);
            end
            for a = ax(:)'
                SmartFigureEngine.placeAxisLabels(a, style, true);
            end
        end

        function applyDeterministicGridGeometry(fig, ax, style)
            if numel(ax) < 2, return; end

            leftMargin = style.leftMargin;
            rightMargin = NaN;
            topMargin = style.topMargin;
            bottomMargin = NaN;

            if isfield(style,'axWidth') && isnumeric(style.axWidth) && isfinite(style.axWidth) && style.axWidth > 0
                rightMargin = 1 - leftMargin - style.axWidth;
            end
            if ~(isnumeric(rightMargin) && isfinite(rightMargin) && rightMargin > 0)
                if isfield(style,'rightMargin') && isnumeric(style.rightMargin) && isfinite(style.rightMargin)
                    rightMargin = style.rightMargin;
                else
                    rightMargin = 0.06;
                end
            end

            if isfield(style,'axHeight') && isnumeric(style.axHeight) && isfinite(style.axHeight) && style.axHeight > 0
                bottomMargin = 1 - topMargin - style.axHeight;
            end
            if ~(isnumeric(bottomMargin) && isfinite(bottomMargin) && bottomMargin > 0)
                if isfield(style,'bottomMargin') && isnumeric(style.bottomMargin) && isfinite(style.bottomMargin)
                    bottomMargin = style.bottomMargin;
                else
                    bottomMargin = max(0.01, 1 - style.axHeight - style.topMargin);
                end
            end

            usableWidth = max(0.05, 1 - leftMargin - rightMargin);
            usableHeight = max(0.05, 1 - topMargin - bottomMargin);
            rowGap = 0.0;
            colGap = 0.0;
            if isfield(style,'rowGap') && isnumeric(style.rowGap) && isfinite(style.rowGap)
                rowGap = max(0, style.rowGap);
            end
            if isfield(style,'colGap') && isnumeric(style.colGap) && isfinite(style.colGap)
                colGap = max(0, style.colGap);
            end

            isTiledAxis = false(size(ax));
            for k = 1:numel(ax)
                try
                    isTiledAxis(k) = ~isempty(ancestor(ax(k), 'tiledlayout'));
                catch
                    isTiledAxis(k) = false;
                end
            end

            if ~any(isTiledAxis)
                for k = 1:numel(ax)
                    try
                        ax(k).Units = 'normalized';
                    catch
                    end
                end

                try
                    pos = vertcat(ax.Position);
                catch
                    return;
                end
                if isempty(pos), return; end

                xCenters = pos(:,1) + pos(:,3)/2;
                yCenters = pos(:,2) + pos(:,4)/2;
                tolX = max(0.02, 0.25 * median(pos(:,3)));
                tolY = max(0.02, 0.25 * median(pos(:,4)));

                xVals = SmartFigureEngine.clusterVals(xCenters, tolX);
                yVals = SmartFigureEngine.clusterVals(yCenters, tolY);
                xVals = sort(xVals, 'ascend');
                yVals = sort(yVals, 'descend');

                nCols = numel(xVals);
                nRows = numel(yVals);
                if nCols < 1 || nRows < 1
                    return;
                end

                totalGapX = colGap * max(0, nCols-1);
                totalGapY = rowGap * max(0, nRows-1);
                cellWidth = max(0.04, (usableWidth - totalGapX) / nCols);
                cellHeight = max(0.04, (usableHeight - totalGapY) / nRows);

                for i = 1:numel(ax)
                    [~, col] = min(abs(xVals - xCenters(i)));
                    [~, row] = min(abs(yVals - yCenters(i)));
                    left = leftMargin + (col-1) * (cellWidth + colGap);
                    bottom = bottomMargin + (nRows-row) * (cellHeight + rowGap);
                    try
                        ax(i).Units = 'normalized';
                        ax(i).Position = [left, bottom, cellWidth, cellHeight];
                    catch
                    end
                end
            else
                nAxes = numel(ax);
                nCols = 0;
                nRows = 0;
                if isfield(style,'nx') && isnumeric(style.nx) && isfinite(style.nx) && style.nx >= 1
                    nCols = round(style.nx);
                end
                if isfield(style,'ny') && isnumeric(style.ny) && isfinite(style.ny) && style.ny >= 1
                    nRows = round(style.ny);
                end
                if nCols < 1 || nRows < 1 || (nCols*nRows) < nAxes
                    nCols = ceil(sqrt(nAxes));
                    nRows = ceil(nAxes / nCols);
                end

                totalGapX = colGap * max(0, nCols-1);
                totalGapY = rowGap * max(0, nRows-1);
                cellWidth = max(0.04, (usableWidth - totalGapX) / nCols);
                cellHeight = max(0.04, (usableHeight - totalGapY) / nRows);

                axOrdered = SmartFigureEngine.orderAxesDeterministically(ax);
                for i = 1:nAxes
                    row = ceil(i / nCols);
                    col = mod(i-1, nCols) + 1;
                    left = leftMargin + (col-1) * (cellWidth + colGap);
                    bottom = bottomMargin + (nRows-row) * (cellHeight + rowGap);
                    try
                        axOrdered(i).Units = 'normalized';
                        axOrdered(i).Position = [left, bottom, cellWidth, cellHeight];
                    catch
                    end
                end
            end

            for a = ax(:)'
                SmartFigureEngine.placeAxisLabels(a, style, true);
            end
        end

        function axOut = orderAxesDeterministically(axIn)
            axOut = axIn;
            if isempty(axIn), return; end
            key = nan(numel(axIn),1);
            hasTile = false;
            for i = 1:numel(axIn)
                try
                    if isprop(axIn(i),'Layout') && isprop(axIn(i).Layout,'Tile')
                        t = double(axIn(i).Layout.Tile);
                        if isfinite(t) && t > 0
                            key(i) = t;
                            hasTile = true;
                        end
                    end
                catch
                end
            end
            if hasTile && all(isfinite(key(~isnan(key))))
                try
                    key(isnan(key)) = inf;
                    [~, order] = sort(key, 'ascend');
                    axOut = axIn(order);
                    return;
                catch
                end
            end
            try
                creationOrderKey = inf(numel(axIn),1);
                for i = 1:numel(axIn)
                    p = ancestor(axIn(i),'figure');
                    if isempty(p) || ~isgraphics(p,'figure')
                        continue;
                    end
                    ch = p.Children;
                    idx = find(ch == axIn(i), 1, 'first');
                    if ~isempty(idx)
                        creationOrderKey(i) = numel(ch) - idx + 1;
                    end
                end
                [~, order] = sort(creationOrderKey, 'ascend');
                axOut = axIn(order);
            catch
            end
        end

        function pos = getBaselinePositions(fig, freeAx)
            pos = [];
            if isempty(freeAx), return; end
            if numel(freeAx) <= 1
                try
                    pos = vertcat(freeAx.Position);
                catch
                    pos = [];
                end
                return;
            end

            idsNow = SmartFigureEngine.handleIds(freeAx);
            if isappdata(fig,'SmartFigureEngine_BaselineAxes') && isappdata(fig,'SmartFigureEngine_BaselinePos')
                try
                    idsOld = getappdata(fig,'SmartFigureEngine_BaselineAxes');
                    posOld = getappdata(fig,'SmartFigureEngine_BaselinePos');
                    if isnumeric(idsOld) && isnumeric(posOld) && isequal(idsOld(:), idsNow(:)) && size(posOld,1) == numel(idsNow)
                        pos = posOld;
                        return;
                    end
                catch
                end
            end

            try
                pos = vertcat(freeAx.Position);
                setappdata(fig,'SmartFigureEngine_BaselineAxes', idsNow);
                setappdata(fig,'SmartFigureEngine_BaselinePos', pos);
            catch
                pos = [];
            end
        end

        function ids = handleIds(h)
            ids = zeros(numel(h),1);
            for i = 1:numel(h)
                try
                    ids(i) = double(h(i));
                catch
                    ids(i) = i;
                end
            end
        end

        function applyTiledLayoutSpacing(tl, style)
            if isempty(tl) || ~isvalid(tl), return; end
            m = max(style.topMargin, style.leftMargin);
            try
                if m <= 0.05
                    tl.Padding = 'tight';
                    tl.TileSpacing = 'tight';
                elseif m <= 0.09
                    tl.Padding = 'compact';
                    tl.TileSpacing = 'compact';
                else
                    tl.Padding = 'loose';
                    tl.TileSpacing = 'compact';
                end
            catch
            end
        end

        function epsX = getGlobalLeftShift(style)
            epsX = 0.008;
            try
                if isfield(style,'panelWidth') && isnumeric(style.panelWidth) && isfinite(style.panelWidth)
                    if style.panelWidth <= 3.0
                        epsX = 0.010;
                    elseif style.panelWidth >= 6.0
                        epsX = 0.006;
                    else
                        t = (style.panelWidth - 3.0) / 3.0;
                        epsX = 0.010 - 0.004 * max(0, min(1, t));
                    end
                end
            catch
            end
            epsX = max(0.005, min(0.015, epsX));
        end

        function applyGlobalLeftShift(ax, style)
            if isempty(ax), return; end
            epsX = SmartFigureEngine.getGlobalLeftShift(style);
            for k = 1:numel(ax)
                try
                    p = ax(k).Position;
                    if numel(p) >= 4
                        p(1) = p(1) - epsX;
                        ax(k).Position = p;
                    end
                catch
                end
            end
        end

        function enforceSymmetricXTicks(ax)
            try
                xl = get(ax,'XLim');
                if ~isnumeric(xl) || numel(xl) ~= 2
                    return;
                end
                if abs(xl(1) + xl(2)) < 1e-8
                    maxVal = max(abs(xl));
                    nTicks = 5;
                    newTicks = linspace(-maxVal, maxVal, nTicks);
                    set(ax,'XTick',newTicks);
                end
            catch
            end
        end

        function ticks = niceXTicks(xl, maxX)
            ticks = [];
            try
                xMin = xl(1); xMax = xl(2); xRange = xMax-xMin;
                if xRange <= 0, return; end
                targetN = max(3, min(maxX, 4));
                rawStep = xRange/max(1,targetN-1);
                step = SmartFigureEngine.niceStep(rawStep);
                starts = [ceil(xMin/step)*step, floor(xMin/step)*step, floor(xMin/step)*step + 0.5*step];
                best = []; bestScore = inf;
                for s = starts
                    tk = s:step:xMax+1e-9;
                    tk = tk(tk>=xMin-1e-9 & tk<=xMax+1e-9);
                    if numel(tk) < 3, continue; end
                    sc = 3*abs(numel(tk)-targetN) + abs(tk(1)-xMin)/step;
                    if sc < bestScore, bestScore=sc; best=tk; end
                end
                if isempty(best), return; end
                if numel(best) > maxX
                    idx = unique(round(linspace(1,numel(best),maxX)));
                    best = best(idx);
                end
                ticks = unique(round(best,10));
            catch
                ticks = [];
            end
        end

        function step = niceStep(x)
            p = 10.^floor(log10(x));
            m = x/p;
            if m <= 1
                b = 1;
            elseif m <= 2
                b = 2;
            elseif m <= 2.5
                b = 2.5;
            elseif m <= 5
                b = 5;
            else
                b = 10;
            end
            step = b*p;
        end

        function v = reduceSym(vin, maxN)
            v = vin;
            try
                vin = vin(:).';
                n = numel(vin);
                if n <= maxN || maxN < 3, return; end
                idx = unique(round(linspace(1,n,maxN)));
                idx = unique([1 idx n]);
                if numel(idx) > maxN
                    keep = unique(round(linspace(1,numel(idx),maxN)));
                    idx = idx(keep);
                end
                v = vin(idx);
            catch
                v = vin;
            end
        end

        function n = legendRows(L)
            n = 1;
            try
                s = L.String;
                if isstring(s), s = cellstr(s); end
                if ischar(s)
                    n = 1;
                elseif iscell(s)
                    n = numel(s);
                end
                if isprop(L,'NumColumns') && isnumeric(L.NumColumns) && L.NumColumns > 1
                    n = ceil(n/L.NumColumns);
                end
            catch
            end
        end

        function bringMarkersToFront(fig)
            ax = SmartFigureEngine.getDataAxes(fig);
            for a = ax(:)'
                try
                    ch = a.Children;
                    isLine = arrayfun(@(h) isgraphics(h,'line'), ch);
                    isScatter = arrayfun(@(h) isgraphics(h,'scatter'), ch);
                    lineCh = ch(isLine); sc = ch(isScatter); other = ch(~(isLine|isScatter));

                    isRefLine = false(size(lineCh));
                    for k = 1:numel(lineCh)
                        try
                            isRefLine(k) = SmartFigureEngine.isReferenceGraphic(lineCh(k));
                            if isRefLine(k) && isprop(lineCh(k),'HandleVisibility')
                                lineCh(k).HandleVisibility = 'off';
                            end
                        catch
                        end
                    end

                    dataLine = lineCh(~isRefLine);
                    refLine = lineCh(isRefLine);

                    hasMarker = false(size(dataLine));
                    for k = 1:numel(dataLine)
                        try
                            hasMarker(k) = ~strcmp(dataLine(k).Marker,'none');
                        catch
                        end
                    end

                    refOther = gobjects(0);
                    keepOther = true(size(other));
                    for k = 1:numel(other)
                        try
                            if SmartFigureEngine.isReferenceGraphic(other(k))
                                refOther(end+1,1) = other(k); %#ok<AGROW>
                                keepOther(k) = false;
                                if isprop(other(k),'HandleVisibility')
                                    other(k).HandleVisibility = 'off';
                                end
                            end
                        catch
                        end
                    end
                    otherData = other(keepOther);

                    a.Children = [dataLine(hasMarker); sc; dataLine(~hasMarker); otherData; refLine; refOther];

                    for k = 1:numel(refLine)
                        try, uistack(refLine(k), 'bottom'); catch, end
                    end
                    for k = 1:numel(refOther)
                        try, uistack(refOther(k), 'bottom'); catch, end
                    end
                catch
                end
            end
        end

        function enforceReferenceLinesBehindData(fig)
            if isempty(fig) || ~isvalid(fig) || ~isgraphics(fig,'figure')
                return;
            end

            % Global pass: try to push every reference-like object to bottom
            try
                allObj = findall(fig);
            catch
                allObj = gobjects(0);
            end
            for h = allObj(:)'
                try
                    if SmartFigureEngine.isReferenceGraphic(h)
                        try, uistack(h,'bottom'); catch, end
                    end
                catch
                end
            end

            ax = SmartFigureEngine.getDataAxes(fig);
            for a = ax(:)'
                try
                    try
                        if isprop(a,'SortMethod')
                            a.SortMethod = 'childorder';
                        end
                    catch
                    end

                    ch = a.Children;
                    isRef = false(size(ch));
                    for k = 1:numel(ch)
                        try
                            isRef(k) = SmartFigureEngine.isReferenceGraphic(ch(k));
                        catch
                        end
                    end

                    if any(isRef)
                        dataChildren = ch(~isRef);
                        refChildren = ch(isRef);

                        % Primary ordering pass
                        a.Children = [dataChildren; refChildren];

                        % Fallback stacking pass (robust against child order ambiguities)
                        for k = 1:numel(refChildren)
                            try
                                uistack(refChildren(k),'bottom');
                            catch
                            end
                        end
                        for k = 1:numel(dataChildren)
                            try
                                uistack(dataChildren(k),'top');
                            catch
                            end
                        end
                    end
                catch
                end
            end
        end

        function tf = isReferenceGraphic(h)
            tf = false;
            try
                if isempty(h) || ~isgraphics(h)
                    return;
                end

                cls = lower(class(h));
                if contains(cls, 'constantline')
                    tf = true;
                    return;
                end

                try
                    if isgraphics(h,'line')
                        ls = '';
                        try, ls = char(h.LineStyle); catch, end
                        if strcmp(ls,'--')
                            x = h.XData;
                            if isnumeric(x) && numel(x) >= 2 && all(abs(x - x(1)) < 1e-12)
                                tf = true;
                                return;
                            end
                        end
                    end
                catch
                end

                tagVal = "";
                try, tagVal = lower(string(h.Tag)); catch, end
                nameVal = "";
                try, nameVal = lower(string(h.DisplayName)); catch, end

                tagHit = any(contains(tagVal, ["ref","reference","guide","threshold","tn","marker"], 'IgnoreCase', true));
                nameHit = any(contains(nameVal, ["ref","reference","guide","threshold","tn","marker"], 'IgnoreCase', true));
                if tagHit || nameHit
                    tf = true;
                    return;
                end

                try
                    if isprop(h,'HandleVisibility') && strcmpi(char(h.HandleVisibility), 'off')
                        tf = true;
                        return;
                    end
                catch
                end
            catch
                tf = false;
            end
        end

        function enforceAnnotationHierarchy(fig, annFont)
            tx = findall(fig,'Type','text');
            for t = tx(:)'
                try
                    pAx = ancestor(t,'axes');
                    if ~isempty(pAx)
                        continue;
                    end
                    s = lower(char(string(t.String)));
                    if contains(s,{'pause','zfc','fc'})
                        t.FontSize = annFont;
                    end
                catch
                end
            end
        end

        function fs = getSharedLegendTextFont(style)
            fs = SmartFigureEngine.getLegendTargetFont(style);
            try
                if isfield(style,'legendFont') && isnumeric(style.legendFont) && isfinite(style.legendFont) && style.legendFont > 0
                    fs = round(style.legendFont);
                end
            catch
            end
            fs = max(1, fs);
        end

        function enforceBottomOnlyXTickLabels(ax)
            if numel(ax) < 2, return; end
            try
                pos = vertcat(ax.Position);
            catch
                return;
            end
            yCenters = pos(:,2) + pos(:,4)/2;
            yVals = SmartFigureEngine.clusterVals(yCenters, 0.03);
            if numel(yVals) < 2
                return;
            end

            yBottom = min(pos(:,2));
            tolY = max(0.03, 0.25 * median(pos(:,4)));
            bottomMask = pos(:,2) <= (yBottom + tolY);

            for k = 1:numel(ax)
                try
                    if bottomMask(k)
                        if isprop(ax(k),'XTickLabelMode')
                            ax(k).XTickLabelMode = 'auto';
                        end
                    else
                        if isprop(ax(k),'XTickLabel')
                            ax(k).XTickLabel = {};
                        end
                    end
                catch
                end
            end
        end

        function enforceSubplotLabelPlacement(ax, style)
            if numel(ax) < 2, return; end
            try
                nyNow = 1;
                try
                    pos = vertcat(ax.Position);
                    yCenters = pos(:,2) + pos(:,4)/2;
                    yVals = SmartFigureEngine.clusterVals(yCenters, max(0.03, 0.25*median(pos(:,4))));
                    nyNow = max(1, numel(yVals));
                catch
                end

                style2 = style;
                style2.ny = nyNow;
                for k = 1:numel(ax)
                    try
                        SmartFigureEngine.placeAxisLabels(ax(k), style2, true);
                    catch
                    end
                end

                if SmartFigureEngine.isDebugEnabled()
                    for k = 1:min(numel(ax), 6)
                        try
                            xp = ax(k).XLabel.Position;
                            yp = ax(k).YLabel.Position;
                            fprintf('[SmartEngine] subplotLabel axis=%d ny=%d XLabelPosY=%.4f YLabelPosX=%.4f YLabelFS=%.2f\n', ...
                                k, nyNow, xp(2), yp(1), ax(k).YLabel.FontSize);
                        catch
                        end
                    end
                end
            catch
            end
        end

        function fs = getLegendTargetFont(style)
            fs = 16;
            try
                if isfield(style,'legendFont') && isnumeric(style.legendFont) && isfinite(style.legendFont) && style.legendFont > 0
                    fs = round(style.legendFont);
                end
            catch
            end
            fs = max(1, fs);

            try
                key = 'SmartFigureEngine_GlobalLegendFont';
                if isappdata(0, key)
                    g = getappdata(0, key);
                    if isnumeric(g) && isfinite(g) && isscalar(g) && g > 0
                        fs = round(g);
                    else
                        setappdata(0, key, fs);
                    end
                else
                    setappdata(0, key, fs);
                end
            catch
            end

            fs = max(1, fs);
        end

        function styleOut = rebuildLockedStyle(styleIn)
            panelWidth = 3.5;
            panelHeight = 2.6;
            nx = 1;
            ny = 1;
            mode = 'PRL';
            if isfield(styleIn,'panelWidth'), panelWidth = styleIn.panelWidth; end
            if isfield(styleIn,'panelHeight'), panelHeight = styleIn.panelHeight; end
            if isfield(styleIn,'nx'), nx = styleIn.nx; end
            if isfield(styleIn,'ny'), ny = styleIn.ny; end
            if isfield(styleIn,'mode'), mode = styleIn.mode; end

            styleOut = SmartFigureEngine.computeSmartStyle(panelWidth, panelHeight, nx, ny, mode);
            passthrough = {'applyPreviewResize','previewScale','dpi','enableAutoReflow', ...
                'sharedXLabel','sharedYLabel','autoCompactLegend','allowLegendLayoutChanges', ...
                'detectTextOverlaps','lockSmartStyle','xLabelBaselineOffset','safeMode','geometryMode', ...
                'rightMargin','bottomMargin','colGap'};
            for i = 1:numel(passthrough)
                key = passthrough{i};
                if isfield(styleIn,key)
                    styleOut.(key) = styleIn.(key);
                end
            end
        end

        function normalizeMultiPanelLabels(fig, ax, style)
            if numel(ax) < 2, return; end

            pos = vertcat(ax.Position);
            yBottom = min(pos(:,2));
            xLeft = min(pos(:,1));
            tolY = max(0.03, 0.25 * median(pos(:,4)));
            tolX = max(0.03, 0.25 * median(pos(:,3)));

            bottomMask = pos(:,2) <= (yBottom + tolY);
            leftMask = pos(:,1) <= (xLeft + tolX);

            for k = 1:numel(ax)
                try
                    if bottomMask(k)
                        SmartFigureEngine.applyTextObj(ax(k).XLabel, style.labelFont);
                    end
                    if leftMask(k)
                        yFs = SmartFigureEngine.getCompactYLabelFont(style, ax(k).YLabel.String);
                        SmartFigureEngine.applyTextObj(ax(k).YLabel, yFs);
                    end
                catch
                end
            end

            layouts = gobjects(0);
            for k = 1:numel(ax)
                try
                    tl = ancestor(ax(k), 'tiledlayout');
                    if ~isempty(tl), layouts(end+1) = tl; end %#ok<AGROW>
                catch
                end
            end
            if ~isempty(layouts)
                layouts = unique(layouts);
                for tl = layouts(:)'
                    try, SmartFigureEngine.applyTextObj(tl.XLabel, style.labelFont); catch, end
                    try
                        SmartFigureEngine.applyTextObj(tl.YLabel, SmartFigureEngine.getCompactYLabelFont(style, tl.YLabel.String));
                    catch
                    end
                    try, SmartFigureEngine.applyTextObj(tl.Title, style.titleFont); catch, end
                end
            end
        end

        function applySharedLabels(fig, ax, style)
            if numel(ax) < 2, return; end
            shareX = isfield(style,'sharedXLabel') && style.sharedXLabel;
            shareY = isfield(style,'sharedYLabel') && style.sharedYLabel;
            if ~(shareX || shareY), return; end

            layouts = gobjects(0);
            for k = 1:numel(ax)
                try
                    tl = ancestor(ax(k), 'tiledlayout');
                    if ~isempty(tl), layouts(end+1) = tl; end %#ok<AGROW>
                catch
                end
            end

            sharedX = '';
            sharedY = '';
            for k = 1:numel(ax)
                try
                    s = char(string(ax(k).XLabel.String));
                    if isempty(sharedX) && ~isempty(strtrim(s)), sharedX = s; end
                catch
                end
                try
                    s = char(string(ax(k).YLabel.String));
                    if isempty(sharedY) && ~isempty(strtrim(s)), sharedY = s; end
                catch
                end
            end

            if ~isempty(layouts)
                layouts = unique(layouts);
                for tl = layouts(:)'
                    if shareX && ~isempty(sharedX)
                        try, tl.XLabel.String = sharedX; SmartFigureEngine.applyTextObj(tl.XLabel, style.labelFont); catch, end
                    end
                    if shareY && ~isempty(sharedY)
                        try
                            tl.YLabel.String = sharedY;
                            SmartFigureEngine.applyTextObj(tl.YLabel, SmartFigureEngine.getCompactYLabelFont(style, tl.YLabel.String));
                        catch
                        end
                    end
                end
            end

            pos = vertcat(ax.Position);
            yBottom = min(pos(:,2));
            xLeft = min(pos(:,1));
            tolY = 0.03;
            tolX = 0.03;
            bottomIdx = find(abs(pos(:,2)-yBottom) <= tolY);
            leftIdx = find(abs(pos(:,1)-xLeft) <= tolX);

            if shareX && ~isempty(bottomIdx)
                [~, iMid] = min(abs((pos(bottomIdx,1)+pos(bottomIdx,3)/2) - 0.5));
                anchor = bottomIdx(iMid);
                for k = 1:numel(ax)
                    try
                        if k == anchor
                            ax(k).XLabel.String = sharedX;
                            SmartFigureEngine.applyTextObj(ax(k).XLabel, style.labelFont);
                        else
                            ax(k).XLabel.String = '';
                        end
                    catch
                    end
                end
            end

            if shareY && ~isempty(leftIdx)
                [~, iMid] = min(abs((pos(leftIdx,2)+pos(leftIdx,4)/2) - 0.5));
                anchor = leftIdx(iMid);
                for k = 1:numel(ax)
                    try
                        if k == anchor
                            ax(k).YLabel.String = sharedY;
                            SmartFigureEngine.applyTextObj(ax(k).YLabel, SmartFigureEngine.getCompactYLabelFont(style, ax(k).YLabel.String));
                        else
                            ax(k).YLabel.String = '';
                        end
                    catch
                    end
                end
            end

            if ~strcmpi(SmartFigureEngine.getGeometryMode(style),'deterministic-grid')
                SmartFigureEngine.alignXLabelBaseline(fig, ax, style);
            end
        end

        function scaleSharedBottomText(fig, ax, style)
            if numel(ax) < 2, return; end
            try
                pos = vertcat(ax.Position);
                minBottom = min(pos(:,2));
                tx = findall(fig,'Type','text','Visible','on');
                for t = tx(:)'
                    try
                        pAx = ancestor(t,'axes');
                        if ~isempty(pAx) && any(pAx == ax)
                            continue;
                        end
                        if isprop(t,'Units')
                            oldUnits = t.Units;
                            t.Units = 'normalized';
                            tp = t.Position;
                            t.Units = oldUnits;
                            if numel(tp) >= 2 && tp(2) < minBottom + 0.02
                                SmartFigureEngine.applyTextObj(t, style.labelFont);
                            end
                        end
                    catch
                    end
                end
            catch
            end
        end

        function yFont = getCompactYLabelFont(style, labelString)
            %#ok<INUSD>
            yFont = style.labelFont;
            try
                if isfield(style,'ny') && isnumeric(style.ny) && isfinite(style.ny) && style.ny > 1
                    nyTightness = min(1, max(0, (style.ny - 1) / 2));
                    panelTightness = 0;
                    if isfield(style,'panelHeight') && isnumeric(style.panelHeight) && isfinite(style.panelHeight)
                        panelTightness = min(1, max(0, (2.8 - style.panelHeight) / 1.2));
                    end
                    yScale = 0.98 - 0.05*nyTightness - 0.03*panelTightness;
                    yFont = max(12, round(style.labelFont * yScale));
                end
            catch
            end
        end

        function normalizeInAxesTextboxes(fig, ax, targetFs)
            try
                if isempty(ax), return; end
                tx = findall(fig,'Type','text');
                for t = tx(:)'
                    try
                        pAx = ancestor(t,'axes');
                        if isempty(pAx) || ~any(pAx == ax)
                            continue;
                        end

                        isTextboxLike = false;
                        try
                            if isprop(t,'BackgroundColor')
                                bg = t.BackgroundColor;
                                if isnumeric(bg)
                                    isTextboxLike = true;
                                elseif ischar(bg) || isstring(bg)
                                    isTextboxLike = ~strcmpi(char(string(bg)),'none');
                                end
                            end
                        catch
                        end
                        try
                            if ~isTextboxLike && isprop(t,'EdgeColor')
                                ec = t.EdgeColor;
                                if isnumeric(ec)
                                    isTextboxLike = true;
                                elseif ischar(ec) || isstring(ec)
                                    isTextboxLike = ~strcmpi(char(string(ec)),'none');
                                end
                            end
                        catch
                        end

                        if isTextboxLike
                            SmartFigureEngine.applyTextObj(t, targetFs);
                            if isprop(t,'Color'), t.Color = [0 0 0]; end
                        end
                    catch
                    end
                end
            catch
            end
        end

        function tf = hasLabelNewline(labelString)
            tf = false;
            try
                if iscell(labelString)
                    tf = numel(labelString) > 1;
                    if tf, return; end
                    if ~isempty(labelString)
                        s = string(labelString{1});
                    else
                        s = "";
                    end
                else
                    s = string(labelString);
                end
                tf = contains(s, newline);
            catch
                tf = false;
            end
        end

        function alignXLabelBaseline(fig, ax, style)
            if isempty(ax), return; end
            try
                pos = vertcat(ax.Position);
            catch
                return;
            end

            minBottom = min(pos(:,2));
            tolY = 0.03;
            bottomIdx = find(abs(pos(:,2)-minBottom) <= tolY);
            if isempty(bottomIdx), return; end

            baselineOffset = 0.08;
            if isfield(style,'xLabelBaselineOffset')
                baselineOffset = style.xLabelBaselineOffset;
            end
            targetYFig = max(0.001, minBottom - baselineOffset);

            for ii = 1:numel(bottomIdx)
                k = bottomIdx(ii);
                a = ax(k);
                try
                    p = a.Position;
                    if p(4) <= eps, continue; end
                    localY = (targetYFig - p(2)) / p(4);
                    a.XLabel.Units = 'normalized';
                    xp = a.XLabel.Position;
                    xp(2) = localY;
                    a.XLabel.Position = xp;
                    a.XLabel.VerticalAlignment = 'top';
                catch
                end
            end
        end

        function n = legendEntryCount(L)
            n = 0;
            try
                s = L.String;
                if isstring(s), s = cellstr(s); end
                if ischar(s)
                    n = 1;
                elseif iscell(s)
                    n = numel(s);
                end
            catch
            end
        end

        function resolveTextOverlaps(fig, style)
            try
                ax = SmartFigureEngine.getDataAxes(fig);
                if isempty(ax), return; end
                axRects = vertcat(ax.Position);
                isSafeMode = ~(isfield(style,'safeMode') && ~style.safeMode);

                lg = findall(fig,'Type','legend');
                for L = lg(:)'
                    try
                        lr = L.Position;
                        ov = false;
                        for i = 1:size(axRects,1)
                            if SmartFigureEngine.rectOverlap(lr, axRects(i,:))
                                ov = true;
                                break;
                            end
                        end
                        if ov
                            if ~isSafeMode
                                if isprop(L,'Location'), L.Location = 'northeastoutside'; end
                            end
                        end
                    catch
                    end
                end

                txb = findall(fig,'Type','textboxshape');
                for t = txb(:)'
                    try
                        tr = t.Position;
                        ov = false;
                        for i = 1:size(axRects,1)
                            if SmartFigureEngine.rectOverlap(tr, axRects(i,:))
                                ov = true;
                                break;
                            end
                        end
                        if ov
                        end
                    catch
                    end
                end

                for a = ax(:)'
                    try
                        te = get(a.Title,'Extent');
                        if te(2) < 1.0 && isprop(a.Title,'FontSize')
                            a.Title.FontSize = max(style.tickFont, round(a.Title.FontSize*0.95));
                        end
                    catch
                    end
                end
            catch
            end
        end

        function warnLabelOverflow(fig)
            ax = SmartFigureEngine.getDataAxes(fig);
            for k = 1:numel(ax)
                a = ax(k);
                try
                    ov = SmartFigureEngine.getAxisLabelOverflow(a);
                    if ov.xOverflow > 0
                        warning('SmartFigureEngine:XLabelClipping', ...
                            'XLabel clipped on axis %d (overflow = %.4f).', k, ov.xOverflow);
                    end
                    if ov.yOverflow > 0
                        warning('SmartFigureEngine:YLabelClipping', ...
                            'YLabel clipped on axis %d (overflow = %.4f).', k, ov.yOverflow);
                    end
                    if ov.titleOverflow > 0
                        warning('SmartFigureEngine:TitleClipping', ...
                            'Title clipped on axis %d (overflow = %.4f).', k, ov.titleOverflow);
                    end
                catch
                end
            end
        end

        function solveLabelOverflow(fig, style)
            if nargin < 2 || isempty(style) || ~isstruct(style)
                style = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 1, 1, 'PRL');
            end
            if isempty(fig) || ~isvalid(fig) || ~isgraphics(fig,'figure')
                return;
            end

            if ~isfield(style,'rightMargin') || ~isnumeric(style.rightMargin) || ~isfinite(style.rightMargin)
                style.rightMargin = max(0.01, 1 - style.leftMargin - style.axWidth);
            end
            if ~isfield(style,'bottomMargin') || ~isnumeric(style.bottomMargin) || ~isfinite(style.bottomMargin)
                style.bottomMargin = max(0.01, 1 - style.topMargin - style.axHeight);
            end

            maxIter = 5;
            pad = 0.012;
            for iter = 1:maxIter
                ax = SmartFigureEngine.getDataAxes(fig);
                if isempty(ax)
                    break;
                end

                deltaBottom = 0;
                deltaLeft = 0;
                deltaTop = 0;

                for k = 1:numel(ax)
                    try
                        ov = SmartFigureEngine.getAxisLabelOverflow(ax(k));
                        deltaBottom = max(deltaBottom, ov.xOverflow + pad);
                        deltaLeft = max(deltaLeft, ov.yOverflow + pad);
                        deltaTop = max(deltaTop, ov.titleOverflow + pad);
                    catch
                    end
                end

                if deltaBottom <= pad && deltaLeft <= pad && deltaTop <= pad
                    break;
                end

                style.bottomMargin = min(0.92, max(0.01, style.bottomMargin + deltaBottom));
                style.leftMargin = min(0.92, max(0.01, style.leftMargin + deltaLeft));
                style.topMargin = min(0.92, max(0.01, style.topMargin + deltaTop));

                maxAxesSpan = 0.95;
                totalX = style.leftMargin + style.rightMargin;
                if totalX > maxAxesSpan
                    overflowX = totalX - maxAxesSpan;
                    style.leftMargin = max(0.01, style.leftMargin - overflowX);
                end

                style.axWidth = max(0.05, 1 - style.leftMargin - style.rightMargin);
                style.axHeight = max(0.05, 1 - style.topMargin - style.bottomMargin);

                SmartFigureEngine.applyAxesGeometry(fig, style);
                SmartFigureEngine.recenterYLabelsForFigure(fig);
                drawnow limitrate;
            end

            maxResidual = 0;
            try
                ax = SmartFigureEngine.getDataAxes(fig);
                for k = 1:numel(ax)
                    ov = SmartFigureEngine.getAxisLabelOverflow(ax(k));
                    maxResidual = max([maxResidual, ov.xOverflow, ov.yOverflow, ov.titleOverflow]);
                end
            catch
            end
            if maxResidual > 0.01
                warning('SmartFigureEngine:OverflowSolverNotConverged', ...
                    'Label overflow solver did not converge after %d iterations (max residual %.4f).', maxIter, maxResidual);
            end

            if isgraphics(fig,'figure')
                setappdata(fig,'SmartFigureEngine_LastStyle',style);
            end
        end

        function ov = getAxisLabelOverflow(a)
            ov = struct('xOverflow',0,'yOverflow',0,'titleOverflow',0);
            try
                ex = get(a.XLabel, 'Extent');
                if isnumeric(ex) && numel(ex) >= 2
                    ov.xOverflow = max(0, -double(ex(2)) - 0.002);
                end
            catch
            end
            try
                ey = get(a.YLabel, 'Extent');
                if isnumeric(ey) && numel(ey) >= 1
                    ov.yOverflow = max(0, -double(ey(1)) - 0.002);
                end
            catch
            end
            try
                et = get(a.Title, 'Extent');
                if isnumeric(et) && numel(et) >= 4
                    ov.titleOverflow = max(0, double(et(2) + et(4) - 1.0) + 0.002);
                end
            catch
            end
        end

        function clearApplyingFlag(fig)
            try
                if ~isempty(fig) && isvalid(fig) && isgraphics(fig,'figure')
                    setappdata(fig,'SmartFigureEngine_IsApplying',false);
                end
            catch
            end
        end

        function tf = rectOverlap(r1, r2)
            tf = false;
            try
                x1 = r1(1); y1 = r1(2); w1 = r1(3); h1 = r1(4);
                x2 = r2(1); y2 = r2(2); w2 = r2(3); h2 = r2(4);
                tf = (x1 < x2+w2) && (x2 < x1+w1) && (y1 < y2+h2) && (y2 < y1+h1);
            catch
            end
        end

        function tf = isDebugEnabled()
            tf = false;
            try
                if isappdata(0,'SmartFigureEngine_Debug')
                    tf = logical(getappdata(0,'SmartFigureEngine_Debug'));
                end
            catch
                tf = false;
            end
        end

        function mode = getGeometryMode(style)
            mode = 'adaptive-smart';
            try
                isSafeMode = ~(isfield(style,'safeMode') && ~style.safeMode);
                if isSafeMode
                    mode = 'deterministic-grid';
                end
                if isfield(style,'geometryMode')
                    raw = lower(strtrim(char(string(style.geometryMode))));
                    if any(strcmp(raw, {'deterministic-grid','adaptive-smart'}))
                        mode = raw;
                    end
                end
            catch
                mode = 'adaptive-smart';
            end
        end

        function v = parsePositiveNumeric(raw)
            v = [];
            if isempty(raw), return; end
            if isnumeric(raw)
                x = raw;
            else
                x = str2double(raw);
            end
            if isnumeric(x) && isfinite(x) && x > 0
                v = double(x(1));
            end
        end

        function applyColormapToFigures(mapName, folder, spreadMode, ...
                fitColor, dataWidth, dataStyle, fitWidth, fitStyle, ...
                reverseOrder, reverseLegend, noMapChange, markerSize, targetFigs, scm8Maps, useFolder)

            if nargin < 2 || isempty(folder), folder = []; end
            if nargin < 3 || isempty(spreadMode), spreadMode = 'medium'; end
            if nargin < 4, fitColor = ''; end
            if nargin < 5, dataWidth = []; end
            if nargin < 6, dataStyle = ''; end
            if nargin < 7, fitWidth = []; end
            if nargin < 8, fitStyle = ''; end
            if nargin < 9, reverseOrder = 0; end
            if nargin < 10, reverseLegend = 0; end
            if nargin < 11, noMapChange = 0; end
            if nargin < 12, markerSize = []; end
            if nargin < 13, targetFigs = []; end
            if nargin < 14, scm8Maps = {}; end
            if nargin < 15, useFolder = false; end

            if noMapChange
                cmapFull = [];
            else
                cmapFull = SmartFigureEngine.getColormapToUse(mapName, scm8Maps);
            end

            if ~useFolder
                figList = targetFigs;
                if iscell(figList), figList = [figList{:}]; else, figList = figList(:); end
                for fig = figList'
                    SmartFigureEngine.applyToSingleFigure(fig, cmapFull, spreadMode, ...
                        fitColor, dataWidth, dataStyle, fitWidth, fitStyle, ...
                        reverseOrder, reverseLegend, markerSize);
                end
            else
                files = dir(fullfile(folder,'*.fig'));
                for k = 1:numel(files)
                    f = openfig(fullfile(folder,files(k).name),'invisible');
                    SmartFigureEngine.applyToSingleFigure(f, cmapFull, spreadMode, ...
                        fitColor, dataWidth, dataStyle, fitWidth, fitStyle, ...
                        reverseOrder, reverseLegend, markerSize);
                    savefig(f, fullfile(folder,files(k).name));
                    close(f);
                end
            end
        end

        function applyToSingleFigure(fig, cmapFull, spreadMode, ...
                fitColor, dataWidth, dataStyle, fitWidth, fitStyle, ...
                reverseOrder, reverseLegend, markerSize)

            if nargin < 5, dataWidth = []; end
            if nargin < 6, dataStyle = ''; end
            if nargin < 7, fitWidth = []; end
            if nargin < 8, fitStyle = ''; end
            if nargin < 9, reverseOrder = 0; end
            if nargin < 10, reverseLegend = 0; end
            if nargin < 11, markerSize = []; end
            if isempty(fig) || ~isvalid(fig) || ~isgraphics(fig,'figure'), return; end

            axList = findall(fig,'Type','axes');
            fitRGB = SmartFigureEngine.name2rgb(fitColor);

            if ~isempty(cmapFull)
                M = size(cmapFull,1);
            end

            for ax = axList'
                if ~isempty(cmapFull)
                    idx = SmartFigureEngine.getSliceIndices(M, spreadMode);
                    cmapSlice = cmapFull(idx,:);
                    colormap(ax, cmapSlice);
                end

                allLines = findall(ax,'Type','line');
                if isempty(allLines), continue; end

                names = get(allLines,'DisplayName');
                if ischar(names), names = {names}; end

                isData = ~cellfun(@isempty,names);
                dataLines = allLines(isData);
                fitLines = allLines(~isData);

                if ~isempty(cmapFull) && ~isempty(dataLines)
                    nC = size(cmapSlice,1);
                    idx = round(linspace(1,nC,numel(dataLines)));
                    for k = 1:numel(dataLines)
                        if ~isempty(markerSize), dataLines(k).MarkerSize = markerSize; end
                        dataLines(k).Color = cmapSlice(idx(k),:);
                        if ~isempty(dataWidth), dataLines(k).LineWidth = dataWidth; end
                        if ~isempty(dataStyle), dataLines(k).LineStyle = dataStyle; end
                    end
                else
                    for k = 1:numel(dataLines)
                        if ~isempty(dataWidth), dataLines(k).LineWidth = dataWidth; end
                        if ~isempty(dataStyle), dataLines(k).LineStyle = dataStyle; end
                    end
                end

                for k = 1:numel(fitLines)
                    if ~isempty(markerSize), fitLines(k).MarkerSize = markerSize; end
                    if ~isempty(fitColor)
                        fitLines(k).Color = fitRGB;
                    end
                    if ~isempty(fitWidth), fitLines(k).LineWidth = fitWidth; end
                    if ~isempty(fitStyle), fitLines(k).LineStyle = fitStyle; end
                end

                cbList = findall(fig,'Type','colorbar','Axes',ax);
                for cb = cbList'
                    if ~isempty(cmapFull)
                        colormap(cb, flipud(cmapSlice));
                    end
                    set(cb,'Direction','normal');
                end
            end

            if reverseOrder
                for ax = axList'
                    ch = ax.Children;
                    isLine = strcmp(get(ch,'Type'),'line');
                    lineChildren = ch(isLine);
                    otherChildren = ch(~isLine);
                    if numel(lineChildren) > 1
                        lineChildren = flipud(lineChildren);
                    end
                    ax.Children = [lineChildren; otherChildren];
                end
            end

            if reverseLegend
                for ax = axList'
                    hLeg = findobj(ax.Parent,'Type','legend','-and','Parent',ax.Parent);
                    if isempty(hLeg), continue; end

                    oldProps = struct();
                    try, oldProps.Position = hLeg.Position; catch, end
                    try, oldProps.Location = hLeg.Location; catch, end
                    try, oldProps.Orientation = hLeg.Orientation; catch, end
                    try, oldProps.Box = hLeg.Box; catch, end
                    try, oldProps.EdgeColor = hLeg.EdgeColor; catch, end
                    try, oldProps.FaceColor = hLeg.FaceColor; catch, end
                    try, oldProps.FaceAlpha = hLeg.FaceAlpha; catch, end

                    allLines = findall(ax,'Type','line');
                    if isempty(allLines), continue; end
                    names = get(allLines,'DisplayName');
                    if ischar(names), names = {names}; end

                    isData = ~cellfun(@isempty,names);
                    dataLines = allLines(isData);
                    dataNames = names(isData);

                    dataLines = flipud(dataLines);
                    dataNames = flipud(dataNames);

                    delete(hLeg);

                    newLeg = legend(ax, dataLines, dataNames);
                    newLeg.AutoUpdate = 'off';

                    try
                        if isfield(oldProps,'Position') && isprop(newLeg,'Position'), newLeg.Position = oldProps.Position; end
                        if isfield(oldProps,'Location') && isprop(newLeg,'Location'), newLeg.Location = oldProps.Location; end
                        if isfield(oldProps,'Orientation') && isprop(newLeg,'Orientation'), newLeg.Orientation = oldProps.Orientation; end
                        if isfield(oldProps,'Box') && isprop(newLeg,'Box'), newLeg.Box = oldProps.Box; end
                        if isfield(oldProps,'EdgeColor') && isprop(newLeg,'EdgeColor'), newLeg.EdgeColor = oldProps.EdgeColor; end
                        if isfield(oldProps,'FaceColor') && isprop(newLeg,'FaceColor'), newLeg.FaceColor = oldProps.FaceColor; end
                        if isfield(oldProps,'FaceAlpha') && isprop(newLeg,'FaceAlpha'), newLeg.FaceAlpha = oldProps.FaceAlpha; end
                    catch
                    end
                end
            end

            tickFloor = 0;
            for ax = axList'
                try
                    if isprop(ax,'FontSize') && isnumeric(ax.FontSize) && isfinite(ax.FontSize) && ax.FontSize > 0
                        tickFloor = max(tickFloor, round(ax.FontSize));
                    end
                catch
                end
            end
            tickFloor = max(1, tickFloor);

            lgAll = findall(fig,'Type','legend');
            for L = lgAll(:)'
                try
                    if isprop(L,'FontSize')
                        L.FontSize = max(round(L.FontSize), tickFloor);
                    end
                catch
                end
            end

            txb = findall(fig,'Type','textboxshape');
            for t = txb(:)'
                try
                    if isprop(t,'FontSize')
                        t.FontSize = max(round(t.FontSize), tickFloor);
                    end
                catch
                end
            end

            tx = findall(fig,'Type','text');
            for t = tx(:)'
                try
                    pAx = ancestor(t,'axes');
                    if isempty(pAx) || ~any(pAx == axList)
                        continue;
                    end

                    isTextboxLike = false;
                    try
                        if isprop(t,'BackgroundColor')
                            bg = t.BackgroundColor;
                            if isnumeric(bg)
                                isTextboxLike = true;
                            elseif ischar(bg) || isstring(bg)
                                isTextboxLike = ~strcmpi(char(string(bg)),'none');
                            end
                        end
                    catch
                    end
                    try
                        if ~isTextboxLike && isprop(t,'EdgeColor')
                            ec = t.EdgeColor;
                            if isnumeric(ec)
                                isTextboxLike = true;
                            elseif ischar(ec) || isstring(ec)
                                isTextboxLike = ~strcmpi(char(string(ec)),'none');
                            end
                        end
                    catch
                    end

                    if isTextboxLike && isprop(t,'FontSize')
                        t.FontSize = max(round(t.FontSize), tickFloor);
                    end
                catch
                end
            end
        end

        function cmap = getColormapToUse(mapName, scm8Maps)
            persistent cmapCache
            if isempty(cmapCache)
                cmapCache = containers.Map('KeyType','char','ValueType','any');
            end
            if nargin < 2, scm8Maps = {}; end

            custom = {
                'softyellow', 'softgreen', 'softred', 'softblue', 'softpurple', ...
                'softorange', 'softcyan', 'softgray', 'softbrown', 'softteal', ...
                'softolive', 'softgold', 'softpink', 'softaqua', 'softsand', 'softsky', ...
                'bluebright', 'redbright', 'greenbright', 'purplebright', 'orangebright', ...
                'cyanbright', 'yellowbright', 'magnetabright', 'limebright', 'tealbright', ...
                'ultrabrightblue', 'ultrabrightred', ...
                'bluewhitered', 'redwhiteblue', 'purplewhitegreen', 'brownwhiteblue', ...
                'greenwhitepurple', 'bluewhiteorange', 'blackwhiteyellow', ...
                'fire', 'ice', 'ocean', 'topo', 'terrain', 'magma', 'inferno', ...
                'plasma', 'cividis'
            };

            cmap = [];
            cacheKey = lower(strtrim(char(string(mapName))));
            if isKey(cmapCache, cacheKey)
                cmap = cmapCache(cacheKey);
                return;
            end

            try
                if any(strcmpi(mapName, custom))
                    cmap = SmartFigureEngine.makeCustomColormap(mapName);
                elseif contains(lower(mapName),'cmocean')
                    cmap = SmartFigureEngine.getCmoceanColormap(mapName);
                elseif ~isempty(scm8Maps) && any(strcmp(mapName, scm8Maps))
                    cmap = feval(mapName, 256);
                elseif exist(mapName,'builtin')
                    cmap = feval(mapName, 256);
                elseif exist(mapName,'file')
                    cmap = feval(mapName, 256);
                else
                    error('Unknown colormap name "%s".', mapName);
                end
            catch ME
                error('Invalid colormap: %s', ME.message);
            end

            if isempty(cmap)
                error('Colormap %s returned empty result', mapName);
            end
            if ~ismatrix(cmap) || size(cmap,2) ~= 3
                error('Colormap %s has invalid dimensions (expected Nx3)', mapName);
            end
            if any(isnan(cmap(:))) || any(isinf(cmap(:)))
                error('Colormap %s contains NaN or Inf', mapName);
            end
            if any(cmap(:) < 0) || any(cmap(:) > 1)
                error('Colormap %s has values outside [0,1]', mapName);
            end

            cmapCache(cacheKey) = cmap;
        end

        function cmap = getCmoceanColormap(mapName)
            match = regexp(mapName, "cmocean\('([^']*)'\)", 'tokens');
            if isempty(match)
                error('Invalid cmocean format: %s', mapName);
            end

            cmName = match{1}{1};
            validMaps = {'thermal','haline','solar','matter','turbid','speed',...
                'amp','deep','dense','algae','balance','curl','delta','oxy',...
                'phase','rain','ice','gray'};

            if ~any(strcmp(cmName, validMaps))
                error('Unknown cmocean colormap: %s', cmName);
            end

            try
                cmap = cmocean(cmName);
            catch ME
                error('cmocean function failed: %s', ME.message);
            end
        end

        function idx = getSliceIndices(M, mode)
            if M < 2, M = 2; end

            SPAN_ULTRA_NARROW = ceil(0.20 * M);
            SPAN_NARROW = ceil(0.30 * M);
            SPAN_MEDIUM = ceil(0.35 * M);
            SPAN_WIDE = ceil(0.40 * M);
            SPAN_ULTRA = ceil(0.45 * M);

            mode = lower(mode);
            mid = round(M/2);

            switch mode
                case 'full'
                    idx = 1:M;
                case 'full-rev'
                    idx = M:-1:1;
                case 'ultra-narrow'
                    lo = max(1, mid - round(SPAN_ULTRA_NARROW/2));
                    hi = min(M, lo + SPAN_ULTRA_NARROW - 1);
                    lo = min(lo, hi);
                    idx = lo:hi;
                case 'ultra-narrow-rev'
                    lo = max(1, mid - round(SPAN_ULTRA_NARROW/2));
                    hi = min(M, lo + SPAN_ULTRA_NARROW - 1);
                    lo = min(lo, hi);
                    idx = hi:-1:lo;
                case 'narrow'
                    lo = max(1, mid - round(SPAN_NARROW/2));
                    hi = min(M, lo + SPAN_NARROW - 1);
                    lo = min(lo, hi);
                    idx = lo:hi;
                case 'narrow-rev'
                    lo = max(1, mid - round(SPAN_NARROW/2));
                    hi = min(M, lo + SPAN_NARROW - 1);
                    lo = min(lo, hi);
                    idx = hi:-1:lo;
                case 'medium'
                    lo = max(1, mid - round(SPAN_MEDIUM/2));
                    hi = min(M, lo + SPAN_MEDIUM - 1);
                    lo = min(lo, hi);
                    idx = lo:hi;
                case 'medium-rev'
                    lo = max(1, mid - round(SPAN_MEDIUM/2));
                    hi = min(M, lo + SPAN_MEDIUM - 1);
                    lo = min(lo, hi);
                    idx = hi:-1:lo;
                case 'wide'
                    lo = max(1, mid - round(SPAN_WIDE/2));
                    hi = min(M, lo + SPAN_WIDE - 1);
                    lo = min(lo, hi);
                    idx = lo:hi;
                case 'wide-rev'
                    lo = max(1, mid - round(SPAN_WIDE/2));
                    hi = min(M, lo + SPAN_WIDE - 1);
                    lo = min(lo, hi);
                    idx = hi:-1:lo;
                case 'ultra'
                    lo = max(1, mid - round(SPAN_ULTRA/2));
                    hi = min(M, lo + SPAN_ULTRA - 1);
                    lo = min(lo, hi);
                    idx = lo:hi;
                case 'ultra-rev'
                    lo = max(1, mid - round(SPAN_ULTRA/2));
                    hi = min(M, lo + SPAN_ULTRA - 1);
                    lo = min(lo, hi);
                    idx = hi:-1:lo;
                otherwise
                    error('Unknown spreadMode "%s".', mode);
            end

            idx = idx(idx >= 1 & idx <= M);
            if isempty(idx)
                idx = round(M/2);
            end
        end

        function rgb = name2rgb(c)
            if isnumeric(c) && numel(c) == 3
                rgb = c(:)';
                return;
            end
            if isempty(c), rgb = []; return; end

            c = lower(strtrim(string(c)));
            switch c
                case {'k','black'}
                    rgb = [0 0 0];
                case {'r','red'}
                    rgb = [1 0 0];
                case {'g','green'}
                    rgb = [0 0.5 0];
                case {'b','blue'}
                    rgb = [0 0 1];
                case {'c','cyan'}
                    rgb = [0 1 1];
                case {'m','magenta'}
                    rgb = [1 0 1];
                case {'y','yellow'}
                    rgb = [1 1 0];
                case {'w','white'}
                    rgb = [1 1 1];
                otherwise
                    try
                        v = str2num(c); %#ok<ST2NM>
                        if isnumeric(v) && numel(v) == 3
                            rgb = v(:)';
                        else
                            rgb = [0 0 0];
                        end
                    catch
                        rgb = [0 0 0];
                    end
            end
        end

        function C = makeCustomColormap(name)
            n = 256;

            switch lower(name)
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
                    C1 = [0 0 1];
                    C2 = [1 1 1];
                    C3 = [1 0 0];
                    C = interp1([0 0.5 1],[C1;C2;C3],linspace(0,1,n));
                case 'redwhiteblue'
                    C = flipud(SmartFigureEngine.makeCustomColormap('bluewhitered'));
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
    end
end
