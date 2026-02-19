function FinalFigureFormatterGUI()
% ========================================================================
% DEPRECATION NOTICE (LEGACY GEOMETRY ENGINE)
% This file is deprecated for new development.
% It remains for backward compatibility only.
% Do not extend or reuse this file for new layout logic.
% New layout logic must use explicit target lists and stateless margin
% normalization.
% ========================================================================
% FINALFIGUREFORMATTER – Compact GUI for formatting figures safely
% Skips all your GUI tools automatically:
%   CtrlGUI, Final Figure Formatter, FigureTools, refLineGUI

%% ============================================================
%  ⚠️⚠️⚠️  PRODUCTION LOCK — DO NOT MODIFY  ⚠️⚠️⚠️
%
%  CASE: PRL — DOUBLE COLUMN — 3 PANELS IN ONE ROW
%
%  Journal:          PRL
%  Column mode:      Double column
%  Article width:    7.0 inch
%  Panels across:    nx = 3
%  Aspect ratio:     H/W = 0.85
%
%  ------------------------------------------------------------
%  RESULTING PHYSICAL PANEL SIZE (EXPORTED PDF SIZE):
%
%      panelWidth  = 7.0 / 3  = 2.333 inch
%      panelHeight = 2.333 * 0.85 ≈ 1.98 inch
%
%  ------------------------------------------------------------
%  FONT SYSTEM (PRINT SIZE — TRUE PHYSICAL SIZE):
%
%      Tick font   = 9 pt
%      Label font  = 11 pt
%      Title font  = 11 pt
%      Legend font = 8 pt
%      Annotation  = 10 pt
%
%  ------------------------------------------------------------
%  AXES GEOMETRY (NORMALIZED INSIDE PANEL):
%
%      axWidth     = 0.76
%      axHeight    = 0.72
%      topMargin   = 0.08
%      leftMargin  = 0.12
%
%  ------------------------------------------------------------
%  These numbers were tuned and validated for:
%      ✔ Correct PRL double-column width (7.0 inch)
%      ✔ Proper 3-panel side-by-side layout
%      ✔ Readable fonts at final print size
%      ✔ Balanced margins without clipping
%
%  Any modification to:
%      • articleWidth
%      • nx
%      • aspect ratio
%      • font sizes
%      • margins
%
%  WILL CHANGE FINAL PRINT SIZE AND TYPOGRAPHY.
%
%  🔴 DO NOT MODIFY CASUALLY.
%  🔴 This controls FINAL EXPORTED PHYSICAL DIMENSIONS.
%  🔴 Change only if journal requirements change.
%
%  ============================================================

%% ============================================================
%  ⚠️⚠️⚠️  PRODUCTION LOCK — DO NOT MODIFY  ⚠️⚠️⚠️
%
%  CASE: PRL — DOUBLE COLUMN — 2 PANELS IN ONE ROW
%
%  Journal:          PRL
%  Column mode:      Double column
%  Article width:    7.0 inch
%  Panels across:    nx = 2
%  Aspect ratio:     H/W = 0.85
%
%  ------------------------------------------------------------
%  RESULTING PHYSICAL PANEL SIZE:
%
%      panelWidth  = 7.0 / 2  = 3.50 inch
%      panelHeight = 3.50 * 0.85 ≈ 2.98 inch
%
%  ------------------------------------------------------------
%  FONT SYSTEM (UNCHANGED FROM 3-PANEL MODE):
%
%      Tick font   = 9 pt
%      Label font  = 11 pt
%      Title font  = 11 pt
%      Legend font = 8 pt
%      Annotation  = 10 pt
%
%  ------------------------------------------------------------
%  AXES GEOMETRY (ADJUSTED FOR LARGER PANEL):
%
%      axWidth     = 0.80
%      axHeight    = 0.75
%      topMargin   = 0.06
%      leftMargin  = 0.10
%
%  ------------------------------------------------------------
%  Fonts remain identical across entire manuscript.
%  Panel size increases for improved readability.
%
%  🔴 DO NOT MODIFY CASUALLY.
%
%  ============================================================


% ===== JOURNAL PRESETS =====
journal = "PRL";   % "PRL" | "Nature"

switch journal
    case "PRL"
        singleColWidth  = 3.375;
        doubleColWidth  = 7.0;

        singleColHeight = 5.0;
        doubleColHeight = 6.0;
        doubleColHeightTall = 7.5;

    case "Nature"
        singleColWidth  = 3.5;
        doubleColWidth  = 7.2;

        singleColHeight = 5.5;
        doubleColHeight = 7.5;
end


f = figure('Name','Final Figure Formatter',...
    'NumberTitle','off','MenuBar','none','ToolBar','none',...
    'Units','pixels','Position',[1000 80 550 820],...
    'Resize','off','Color','w');

lastRealFigure = [];
figListener = addlistener(0,'CurrentFigure','PostSet',@trackLastFigure);
f.UserData.listener = figListener;
set(f,'CloseRequestFcn',@closeGUI);

skipList = ["CtrlGUI","Final Figure Formatter","FigureTools","refLineGUI"];

%% --- Save Folder ---
uicontrol(f,'Style','text','String','Save Folder:',...
    'Units','pixels','Position',[10 790 200 20],...
    'HorizontalAlignment','left','BackgroundColor','w',...
    'FontSize',8,'FontWeight','bold');

hPathBox = uicontrol(f,'Style','edit','String',pwd,...
    'Units','pixels','Position',[20 770 240 22],...
    'FontSize',10);

uicontrol(f,'Style','pushbutton','String','Browse…',...
    'Units','pixels','Position',[265 770 75 22],...
    'FontSize',10,'Callback',@browseFolder);

%{
%% --- Size Presets ---
uicontrol(f,'Style','text','String','Size Presets:',...
    'Units','pixels','Position',[-50 590 200 22],...
    'BackgroundColor','w','FontSize',8,'FontWeight','bold');

makeBtn([0.10 0.83 0.80 0.04],'Small (600×450)',  @() fmtAll([600 450],12,'white'));
makeBtn([0.10 0.78 0.80 0.04],'Medium (700×500)', @() fmtAll([700 500],13,'white'));
makeBtn([0.10 0.73 0.80 0.04],'Large (950×600)',  @() fmtAll([950 600],14,'white'));
makeBtn([0.10 0.68 0.80 0.04],'Format for Paper (APS)', @formatAllForPaper);
%}

%% --- Figure Size (pixels) ---
uicontrol(f,'Style','text','String','Figure Size (pixels):',...
    'Units','pixels','Position',[10 745 100 18],...
    'BackgroundColor','w','FontSize',8,'FontWeight','bold');

% Width
uicontrol(f,'Style','text','String','Width:',...
    'Units','pixels','Position',[115 745 50 18],...
    'BackgroundColor','w','FontSize',8);

hFigWidth = uicontrol(f,'Style','edit','String','700',...
    'Units','pixels','Position',[120+40 745 50 18],...
    'FontSize',10);

% Height
uicontrol(f,'Style','text','String','Height:',...
    'Units','pixels','Position',[120+45+45 745 50 18],...
    'BackgroundColor','w','FontSize',8);

hFigHeight = uicontrol(f,'Style','edit','String','500',...
    'Units','pixels','Position',[120+45+45+45 745 50 18],...
    'FontSize',10);

uicontrol(f,'Style','pushbutton','String','Apply Figure Size',...
    'Units','pixels','Position',[120+45+45+45+45+10 745 150 18],...
    'FontSize',10,'Callback',@applyFigureSize);


%% --- Axes Size Control (REPLACES Size Presets) ---
uicontrol(f,'Style','text','String','Axes Size (norm.):',...
    'Units','pixels','Position',[8 710 100 18],...
    'BackgroundColor','w','FontSize',8,'FontWeight','bold');

% Width
uicontrol(f,'Style','text','String','Width:',...
    'Units','pixels','Position',[115 720 50 18],...
    'BackgroundColor','w','FontSize',8);

hAxWidth = uicontrol(f,'Style','edit','String','0.70',...
    'Units','pixels','Position',[120+40 720 50 18],...
    'FontSize',10);

% Height
uicontrol(f,'Style','text','String','Height:',...
    'Units','pixels','Position',[120+45+45 720 50 18],...
    'BackgroundColor','w','FontSize',8);

hAxHeight = uicontrol(f,'Style','edit','String','0.65',...
    'Units','pixels','Position',[120+45+45+45 720 50 18],...
    'FontSize',10);

uicontrol(f,'Style','text','String','Top:',...
    'Units','pixels','Position',[110 700 70 18],...
    'BackgroundColor','w','FontSize',8);

hTopMargin = uicontrol(f,'Style','edit','String','0.06',...
    'Units','pixels','Position',[120+40 700 50 18],...
    'FontSize',10);

uicontrol(f,'Style','text','String','Left:',...
    'Units','pixels','Position',[120+45+45 700 50 18],...
    'BackgroundColor','w','FontSize',8);

hLeftMargin = uicontrol(f,'Style','edit','String','0.08',...
    'Units','pixels','Position',[120+45+45+45 700 50 18],...
    'FontSize',10);

% Apply button
uicontrol(f,'Style','pushbutton','String', sprintf('Apply Axes Size'),...
    'Units','pixels','Position',[120+45+45+45+45+10 710 150 18],...
    'FontSize',10,'Callback',@applyAxesSize);

%% --- Font Size Control ---
uicontrol(f,'Style','text','String','Font Size:',...
    'Units','pixels','Position',[10 670 70 18],...
    'BackgroundColor','w','FontSize',8,'FontWeight','bold');

hFontSize = uicontrol(f,'Style','popupmenu',...
    'String',{'8','10','12','14','16','18','20','22','24','28','30','32','36','38','40','48','60'},...
    'Units','pixels','Position',[75 670 40 18],...
    'FontSize',10,'Value',3);   % Default = 12pt

uicontrol(f,'Style','pushbutton','String','Apply Font Size',...
    'Units','pixels','Position',[120 665 100 20],...
    'FontSize',10,'Callback',@applyFontSize);
% --- Legend Font Size ---
uicontrol(f,'Style','text','String','Legend:',...
    'Units','pixels','Position',[230 670 60 18],...
    'BackgroundColor','w','FontSize',8,'FontWeight','bold');

hLegendFontSize = uicontrol(f,'Style','popupmenu',...
    'String',{'4','5','6','7','8','10','12','14','16','18','20','22','24','28','30','32','36','38','40','48','60'},...
    'Units','pixels','Position',[285 670 40 18],...
    'FontSize',10,'Value',3);

uicontrol(f,'Style','pushbutton','String','Apply Legend Font',...
    'Units','pixels','Position',[330 665 120 20],...
    'FontSize',10,'Callback',@applyLegendFontSize);

%% --- Legend Position ---
uicontrol(f,'Style','text','String','Legend Position:',...
    'Units','pixels','Position',[-40 523 200 50],...
    'BackgroundColor','w','FontSize',8,'FontWeight','bold');

makeBtn([0.10 0.63 0.38 0.04],'Top-Right',    @() moveLegend('northeast'));
makeBtn([0.52 0.63 0.38 0.04],'Top-Left',     @() moveLegend('northwest'));
makeBtn([0.10 0.58 0.38 0.04],'Bottom-Right', @() moveLegend('southeast'));
makeBtn([0.52 0.58 0.38 0.04],'Bottom-Left',  @() moveLegend('southwest'));
makeBtn([0.10 0.53 0.38 0.04],'Best Fit',     @() moveLegend('best'));
makeBtn([0.52 0.53 0.38 0.04],'Outside',      @() moveLegend('northeastoutside'));

%% --- Save Figures ---
uicontrol(f,'Style','text','String','Save Figures:',...
    'Units','pixels','Position',[-50 405 200 22],...
    'BackgroundColor','w','FontSize',8,'FontWeight','bold');

makeBtn([0.10 0.41 0.40 0.04],'Save PDF',  @() saveDo("pdf"));
makeBtn([0.10 0.36 0.4 0.04],'Save PNG',  @() saveDo("png"));
makeBtn([0.10 0.31 0.40 0.04],'Save JPEG', @() saveDo("jpeg"));
makeBtn([0.10 0.26 0.40 0.04],'Save FIG',  @() saveDo("fig"));

% --- Overwrite Checkbox ---
hOverwrite = uicontrol(f,'Style','checkbox','String','Overwrite existing files',...
    'Units','pixels','Position',[100 410 200 22],...
    'FontSize',8,'BackgroundColor','w','Value',0);
% --- Save into Subfolder ---
hUseSubfolder = uicontrol(f,'Style','checkbox',...
    'String','Save into subfolder:',...
    'Units','pixels','Position',[100 390 150 22],...
    'FontSize',8,'BackgroundColor','w','Value',0);

hSubfolderName = uicontrol(f,'Style','edit',...
    'String','figs',...
    'Units','pixels','Position',[240 390 170 22],...
    'FontSize',9,...
    'Enable','off');
hUseSubfolder.Callback = @(s,e) ...
    set(hSubfolderName,'Enable', ternary(s.Value,'on','off'));
%% --- Extra Tools ---
uicontrol(f,'Style','text','String','Extra Tools:',...
    'Units','pixels','Position',[-50 187 200 22],...
    'BackgroundColor','w','FontSize',8,'FontWeight','bold');

hApplyCurrentOnly = uicontrol(f,'Style','checkbox',...
    'String','Apply to CURRENT figure only',...
    'Units','pixels','Position',[20 165 320 22],...
    'FontSize',9,...
    'BackgroundColor','w',...
    'Value',0);   % default = OFF


uicontrol(f,'Style','pushbutton','String','Reset Formatting',...
    'Units','pixels','Position',[20 130 150 26],...
    'FontSize',10,'Callback',@resetAll);

uicontrol(f,'Style','pushbutton','String','Close',...
    'Units','pixels','Position',[130 10 100 28],...
    'FontSize',11,'Callback',@closeGUI);

uicontrol(f,'Style','pushbutton','String','Set Figure Background: WHITE',...
    'Units','pixels','Position',[175 130 200 26],...
    'FontSize',10,'Callback',@setFigureBackgroundWhite);

%% --- Paper Layout (SMART) ---
uicontrol(f,'Style','text','String','Paper Layout (SMART):',...
    'Units','pixels','Position',[10 635 150 22],...
    'BackgroundColor','w','FontSize',9,'FontWeight','bold');

uicontrol(f,'Style','text','String','Panels across:',...
    'Units','pixels','Position',[10 615 60 25],'BackgroundColor','w');

hPanelsX = uicontrol(f,'Style','edit','String','3',...
    'Units','pixels','Position',[70 615 20 22]);

uicontrol(f,'Style','text','String','Panels down:',...
    'Units','pixels','Position',[100 615 50 25],'BackgroundColor','w');

hPanelsY = uicontrol(f,'Style','edit','String','1',...
    'Units','pixels','Position',[150 615 20 22]);

uicontrol(f,'Style','popupmenu',...
    'String',{'Single column','Double column'},...
    'Units','pixels','Position',[180 615 100 22],...
    'Value',2,'Tag','ColumnMode');

uicontrol(f,'Style','pushbutton','String','Apply SMART Layout',...
    'Units','pixels','Position',[300 615 150 22],...
    'FontSize',10,'Callback',@applySmartLayout);

uicontrol(f,'Style','text','String','Aspect ratio (H/W):',...
    'Units','pixels','Position',[10 590 120 20],...
    'BackgroundColor','w');

hAspectRatio = uicontrol(f,'Style','edit','String','0.85',...
    'Units','pixels','Position',[130 590 50 22],...
    'FontSize',10);

%{
uicontrol(f,'Style','pushbutton',...
    'String','Combine open figures → panels',...
    'Units','pixels',...
    'Position',[300 585 200 22],...
    'FontSize',10,...
    'Callback',@combineFiguresGUI);
%}
%% ============================================================
% CALLBACKS
%% ============================================================
    function combineFiguresGUI(~,~)

        nx = str2double(hPanelsX.String);
        ny = str2double(hPanelsY.String);

        if isnan(nx) || isnan(ny) || nx<1 || ny<1
            errordlg('Panels must be positive integers','Combine Figures');
            return;
        end

        % column mode
        colPopup = findobj(f,'Tag','ColumnMode');
        isDouble = (colPopup.Value == 2);

        if isDouble
            journalMode = journal + "-double";
        else
            journalMode = journal + "-single";
        end

        % output path
        [file, path] = uiputfile('*.pdf','Save combined figure as');
        if isequal(file,0)
            return;
        end
        outPdf = fullfile(path,file);

        % 🚀 call your function
        combineOpenFiguresToPanels(nx, ny, journalMode, outPdf);

    end

    function applySmartLayout(~,~)

        figs = findRealFigs();
        if isempty(figs)
            errordlg('No data figures found','SMART Layout');
            return;
        end

        nx = str2double(hPanelsX.String);
        ny = str2double(hPanelsY.String);

        if any(isnan([nx ny])) || nx<1 || ny<1
            errordlg('Panels must be positive integers','SMART Layout');
            return;
        end

        colPopup = findobj(f,'Tag','ColumnMode');
        isDouble = (colPopup.Value == 2);

        %% ================= ARTICLE PRESET =================
        switch journal
            case "PRL"
                if isDouble
                    articleWidth = 7.0;

                else
                    articleWidth = 3.375;

                end

            case "Nature"
                if isDouble
                    articleWidth = 7.2;

                else
                    articleWidth = 3.5;

                end
        end

        %% ================= PANEL SIZE =================
        panelWidth = articleWidth / nx;
        ratio = str2double(hAspectRatio.String);

        if isnan(ratio) || ratio <= 0 || ratio > 2
            errordlg('Aspect ratio must be positive and reasonable (e.g. 0.6)','SMART Layout');
            return;
        end

        panelHeight = panelWidth * ratio;

        %% ================= STYLE FROM PANEL SIZE =================
        style = getStyleFromPanelSize(panelWidth, panelHeight);
        % --- Force fixed margins ---

        % גם לעדכן UI
        hTopMargin.String  = sprintf('%.2f',style.topMargin);
        hLeftMargin.String = sprintf('%.2f',style.leftMargin);

        screenFontScale = 10;  % רק למסך
        styleScreen = style;
        styleScreen.tickFont   = round(style.tickFont   * screenFontScale);
        styleScreen.labelFont  = round(style.labelFont  * screenFontScale);
        styleScreen.titleFont  = round(style.titleFont  * screenFontScale);
        styleScreen.legendFont = round(style.legendFont * screenFontScale);
        styleScreen.annFont    = round(style.annFont    * screenFontScale);

        %% ================= UPDATE UI =================
        DPI = 96;
        hFigWidth.String  = num2str(round(panelWidth * DPI));
        hFigHeight.String = num2str(round(panelHeight * DPI));

        hAxWidth.String    = sprintf('%.2f',style.axWidth);
        hAxHeight.String   = sprintf('%.2f',style.axHeight);
        hTopMargin.String  = sprintf('%.2f',style.topMargin);
        hLeftMargin.String = sprintf('%.2f',style.leftMargin);

        setPopupValueByString(hFontSize,       num2str(style.tickFont));
        setPopupValueByString(hLegendFontSize, num2str(style.legendFont));

        %% ================= APPLY TO ALL MATLAB FIGURES =================
        for k = 1:numel(figs)

            fig = figs{k};

            % ---- resize MATLAB figure to panel size
            % ---------- PHYSICAL SIZE (for export) ----------
            fig.PaperUnits = 'inches';
            fig.PaperSize  = [panelWidth panelHeight];
            fig.PaperPosition = [0 0 panelWidth panelHeight];
            fig.PaperPositionMode = 'manual';

            % ---------- SCREEN PREVIEW SIZE ----------
            DPI = 96;              % screen DPI
            previewScale = 3.0;    % 👈 אתה יכול לשחק עם זה (2.5–4 טוב)

            fig.Units = 'pixels';
            fig.Position(3) = panelWidth  * DPI * previewScale;
            fig.Position(4) = panelHeight * DPI * previewScale;


            % ---- axes geometry
            if isMultiPanelFigure(fig)
                applyAxesSizeMulti(fig, ...
                    style.axWidth, style.axHeight, ...
                    style.topMargin, style.leftMargin);
            else
                applyAxesSizeSingle(fig, ...
                    style.axWidth, style.axHeight, ...
                    style.topMargin, style.leftMargin);
            end

            % ---- fonts
            applyFontSystem(fig, style);

            lg = findall(fig,'Type','legend');
            for L = lg'
                L.FontSize = style.legendFont;
            end
        end
        fprintf("DEBUG: axW=%.2f axH=%.2f top=%.2f left=%.2f\n", ...
            style.axWidth, style.axHeight, style.topMargin, style.leftMargin);
        fprintf("✔ SMART: %s | %s | nx=%d | Panel = %.2f x %.2f inch\n", ...
            journal, ternary(isDouble,"double","single"), ...
            nx, panelWidth, panelHeight);

    end


% =====================================================================
% PRESETS: ONLY FIGURE SIZE
% =====================================================================
    function [figW_in, rowH_in, rowGap_in] = getJournalFigurePreset(journal, isDouble)

        switch string(journal)

            case "PRL"
                if isDouble
                    figW_in   = 7.0;
                    rowH_in   = 3.8;   % fixed one-row height
                    rowGap_in = 0.35;  % fixed physical gap between rows
                else
                    figW_in   = 3.375;
                    rowH_in   = 4.5;
                    rowGap_in = 0.40;
                end

            case "Nature"
                if isDouble
                    figW_in   = 7.2;
                    rowH_in   = 4.8;
                    rowGap_in = 0.40;
                else
                    figW_in   = 3.5;
                    rowH_in   = 5.0;
                    rowGap_in = 0.45;
                end

            otherwise
                % fallback
                figW_in   = ternary(isDouble, 7.0, 3.5);
                rowH_in   = 4.0;
                rowGap_in = 0.40;
        end
    end

% =====================================================================
% STYLE: ONLY FROM FIGURE SIZE
% =====================================================================
    function style = getSmartStyleFromFigureSize(figW_in, figH_in)

        % A single scalar that captures "how big is the printed figure"
        % (You can tune this formula later; it’s stable.)
        scale = figW_in;

        % ---- fonts ----
        % tuned for typical PRL/Nature-like figures
        if scale >= 5.0
            tickFont   = 9;
            legendFont = 8;
            axWidth    = 0.78;
            axHeight   = 0.72;
            topMargin  = 0.05;
            leftMargin = 0.07;

        elseif scale >= 4.0
            tickFont   = 8;
            legendFont = 7;
            axWidth    = 0.75;
            axHeight   = 0.70;
            topMargin  = 0.06;
            leftMargin = 0.08;

        else
            tickFont   = 7;
            legendFont = 6;
            axWidth    = 0.72;
            axHeight   = 0.68;
            topMargin  = 0.07;
            leftMargin = 0.09;
        end

        style.tickFont   = tickFont;
        style.legendFont = legendFont;

        style.axWidth    = axWidth;
        style.axHeight   = axHeight;
        style.topMargin  = topMargin;
        style.leftMargin = leftMargin;

    end

% =====================================================================
% UI helper: set popup by matching string
% =====================================================================
    function setPopupValueByString(hPopup, targetStr)
        opts = get(hPopup,'String');
        idx = find(strcmp(opts, targetStr), 1);
        if ~isempty(idx)
            hPopup.Value = idx;
        end
    end





    function setFigureBackgroundWhite(~,~)

        figs = findRealFigs();
        if isempty(figs)
            warning('No target figures found.');
            return;
        end

        for k = 1:numel(figs)
            fig = figs{k};

            % רקע האיור
            fig.Color = 'w';

            % לוודא שצירים לא "מלבינים"
            ax = findall(fig,'Type','axes');
            for a = ax'
                if isprop(a,'Color')
                    a.Color = 'none';   % שקוף, כמו שאתה עובד
                end
            end
        end

        fprintf("✔ Figure background set to WHITE\n");
    end

    function applyLegendFontSize(~,~)
        fs = str2double(hLegendFontSize.String{hLegendFontSize.Value});

        figs = findRealFigs();
        if isempty(figs)
            warning('applyLegendFontSize:NoFigures','No target figures found.');
            return;
        end

        for k = 1:numel(figs)
            fig = figs{k};

            lg = findall(fig,'Type','legend');
            for L = lg'
                L.FontSize    = fs;
                L.FontName    = 'latex';
                L.Interpreter = 'latex';
                if isprop(L,'ItemTokenSize')
                    L.ItemTokenSize = [10 8];
                end
                % sanitize legend strings
                if iscell(L.String)
                    for j = 1:numel(L.String)
                        L.String{j} = sanitizeLatexString(L.String{j});
                    end
                elseif ischar(L.String)
                    L.String = sanitizeLatexString(L.String);
                end
            end
        end

        fprintf("✔ Legend font size set to %d pt\n", fs);
    end

    function applyFigureSize(~,~)
        w = str2double(hFigWidth.String);
        h = str2double(hFigHeight.String);

        if isnan(w) || isnan(h) || w<=100 || h<=100
            errordlg('Figure width and height must be numbers > 100 px',...
                'Figure Size Error');
            return;
        end

        figs = findRealFigs();
        for k = 1:numel(figs)
            fig = figs{k};
            fig.Units = 'pixels';
            pos = fig.Position;
            fig.Position = [pos(1) pos(2) w h];
        end

        fprintf("✔ Figure size set to %d × %d pixels\n", w, h);
    end

    function browseFolder(~,~)
        p = uigetdir(pwd,'Select Folder');
        if p ~= 0, hPathBox.String = p; end
    end

    function fmtAll(sz,fs,bg)
        figs = findRealFigs();
        for k = 1:numel(figs)
            safeFormat(figs{k}, sz, fs, bg);
        end
    end

    function applyCurrent(~,~)
        fig = gcf;
        safeFormat(fig, [700 500], 13, 'white');
    end

    function moveLegend(loc)
        figs = findRealFigs();
        for k = 1:numel(figs)
            fig = figs{k};
            lg = findall(fig,'Type','legend');
            if ~isempty(lg)
                set(lg,'Location',loc,'Box','off','Color','none');
            end
        end
    end

    function saveDo(mode)

        baseFolder = hPathBox.String;
        overwrite  = logical(hOverwrite.Value);

        % --- subfolder logic ---
        if hUseSubfolder.Value
            subName = strtrim(hSubfolderName.String);

            if isempty(subName)
                errordlg('Subfolder name is empty','Save Error');
                return;
            end

            saveFolder = fullfile(baseFolder, subName);

            if ~exist(saveFolder,'dir')
                mkdir(saveFolder);
                fprintf("📁 Created subfolder: %s\n", saveFolder);
            end
        else
            saveFolder = baseFolder;
        end

        % --- actual saving ---
        switch mode
            case "png"
                save_PNG(saveFolder, overwrite);
            case "jpeg"
                save_JPEG(saveFolder, overwrite);
            case "fig"
                save_figs(saveFolder, overwrite);
            case "pdf"
                save_PDF(saveFolder, overwrite);
        end

        fprintf("✔ Saved (%s) → %s (overwrite=%d)\n", ...
            mode, saveFolder, overwrite);
    end



    function resetAll(~,~)
        figs = findRealFigs();
        for fig = figs
            fig.Color = [0.94 0.94 0.94];
            fig.Position(3:4) = [560 420];
            ax = findall(fig,'Type','axes');
            for a = ax'
                a.FontName = 'Helvetica';
                a.FontSize = 11;
                a.LineWidth = 0.5;
                a.Box = 'on';
            end
        end
    end

    function formatAllForPaper(~,~)
        figs = findRealFigs();
        for k = 1:numel(figs)
            fig = figs{k};
            formatForPaper(fig);
        end
        fprintf("✔ Applied APS/PRL formatting to all figures.\n");
    end
    function applyCustomSize(~,~)
        w = str2double(hWidth.String);
        h = str2double(hHeight.String);

        if isnan(w) || isnan(h) || w<=0 || h<=0
            errordlg('Width and Height must be positive numbers','Invalid Input');
            return;
        end

        figs = findRealFigs();
        for k = 1:numel(figs)
            safeFormat(figs{k}, [w h], 13, 'white');
        end

        fprintf("✔ Applied custom size: %d × %d px\n", w, h);
    end
    function applyFontSize(~,~)
        fs = str2double(hFontSize.String{hFontSize.Value});

        figs = findRealFigs();
        if isempty(figs)
            warning('applyFontSize:NoFigures','No target figures found (maybe CURRENT is GUI / none open).');
            return;
        end

        for k = 1:numel(figs)
            fig = figs{k};

            %% ========== 1. AXES ==========
            ax = findall(fig,'Type','axes');
            for a = ax'
                % Ticks
                a.FontSize   = fs;
                a.FontName   = 'latex';
                a.TickLabelInterpreter = 'latex';

                % XLabel / YLabel / ZLabel / Title
                fixLabelForLatex(a.XLabel, fs);
                fixLabelForLatex(a.YLabel, fs);
                fixLabelForLatex(a.ZLabel, fs);
                fixLabelForLatex(a.Title,  fs);
            end

            %% ========== 2. TEXT OBJECTS ==========
            tx = findall(fig,'Type','text');
            for t = tx'
                if ~isempty(t.String)
                    t.String      = sanitizeLatexString(t.String);
                    t.FontSize    = fs;
                    t.FontName    = 'latex';
                    t.Interpreter = 'latex';
                end
            end

            %% ========== 3. LEGENDS ==========
            lg = findall(fig,'Type','legend');
            for L = lg'
                L.FontSize    = fs;
                L.FontName    = 'latex';
                L.Interpreter = 'latex';

                % sanitize each entry
                if iscell(L.String)
                    for j = 1:numel(L.String)
                        L.String{j} = sanitizeLatexString(L.String{j});
                    end
                elseif ischar(L.String)
                    L.String = sanitizeLatexString(L.String);
                end
            end

            %% ========== 4. ANNOTATIONS ==========
            %% ========== 4. ALL TEXTBOX / ANNOTATION OBJECTS ==========

            % Annotation textboxes
            annBox = findall(fig,'Type','textboxshape');
            for a = annBox'
                if isprop(a,'String') && ~isempty(a.String)
                    a.String      = sanitizeLatexString(a.String);
                end
                a.FontSize    = fs;
                a.FontName    = 'latex';
                if isprop(a,'Interpreter')
                    a.Interpreter = 'latex';
                end
            end

            % Arrow / doublearrow / line annotations (just font)
            annAll = findall(fig,'Type','annotation');
            for a = annAll'
                if isprop(a,'FontSize')
                    a.FontSize = fs;
                end
            end


            %% ========== 5. COLORBARS (REAL OR AXES) ==========
            % 1) Find real colorbar objects
            cb1 = findall(fig,'Type','colorbar');  % NOTE: 'colorbar' (lowercase)

            % 2) Find axes that behave like colorbars (fallback heuristic)
            axAll = findall(fig,'Type','axes');
            cb2 = [];
            for a = axAll'
                pos = a.Position;
                if pos(3) < 0.06 || pos(4) < 0.06   % VERY narrow width or height
                    cb2 = [cb2; a]; %#ok<AGROW>
                end
            end

            cbs = unique([cb1 ; cb2]);   % combine both types

            for c = cbs'
                cType = get(c,'Type');
                isAxes = strcmpi(cType,'axes');

                % ---------------- TICKS ----------------
                if isAxes
                    ticks = get(c,'YTick');       % axes-style colorbar
                    tickStr = cell(size(ticks));
                    for j = 1:numel(ticks)
                        tickStr{j} = sanitizeLatexString(num2str(ticks(j)));
                    end

                    set(c,'YTickLabel',tickStr);
                    set(c,'FontSize',fs);
                    set(c,'FontName','latex');

                    % label on axes-colorbar (often Title)
                    ttl = get(c,'Title');
                    if ~isempty(ttl) && isprop(ttl,'String') && ~isempty(ttl.String)
                        ttl.String      = sanitizeLatexString(ttl.String);
                        ttl.Interpreter = 'latex';
                        ttl.FontSize    = fs;
                        ttl.FontName    = 'latex';
                    end

                else
                    % ---------- REAL COLORBAR ----------
                    ticks = c.Ticks;
                    tickStr = cell(size(ticks));
                    for j = 1:numel(ticks)
                        tickStr{j} = sanitizeLatexString(num2str(ticks(j)));
                    end

                    c.TickLabels = tickStr;

                    % 🔴 זה החסר הקריטי
                    c.TickLabelInterpreter = 'latex';

                    c.FontSize = fs;
                    c.FontName = 'latex';

                    if ~isempty(c.Label.String)
                        c.Label.String      = sanitizeLatexString(c.Label.String);
                        c.Label.Interpreter = 'latex';
                        c.Label.FontSize    = fs;
                        c.Label.FontName    = 'latex';
                    end
                end

            end
        end

        fprintf("✔ Applied LaTeX + font size to ALL elements (%d pt)\n", fs);
    end

    function out = sanitizeLatexString(in)

        % ---- cell array (multi-line label) ----
        if iscell(in)
            out = cell(size(in));
            for k = 1:numel(in)
                out{k} = sanitizeLatexString(in{k});
            end
            return;
        end

        % ---- string / char ----
        if isstring(in)
            in = char(in);
        end

        in = strtrim(in);
        if isempty(in)
            out = in;
            return;
        end

        % already math → keep AS IS
        if isWrappedInMath(in)
            out = in;
            return;
        end

        % clean MATLAB brackets
        in = strrep(in,'[','');
        in = strrep(in,']','');

        % escape underscore
        in = strrep(in,'_','\_');

        % math detection
        if contains(in,{'_','^','\','{'})
            out = ['$' in '$'];
        else
            out = in;
        end
    end



%% ===========================
% HELPERS
%% ===========================
    function tf = isWrappedInMath(str)
        tf = numel(str) >= 2 && str(1) == '$' && str(end) == '$';
    end

    function fixLabelForLatex(lbl, fs)
        if isempty(lbl) || isempty(lbl.String)
            return;
        end
        lbl.String      = sanitizeLatexString(lbl.String);
        lbl.FontSize    = fs;
        lbl.FontName    = 'latex';
        lbl.Interpreter = 'latex';
    end



    function applyAxesSize(~,~)
        w = str2double(hAxWidth.String);
        h = str2double(hAxHeight.String);
        topMargin = str2double(hTopMargin.String);
        leftMargin = str2double(hLeftMargin.String);

        if any(isnan([w h topMargin leftMargin])) ...
                || w<=0 || h<=0 || w>1 || h>1 ...
                || topMargin<0 || topMargin>0.5 ...
                || leftMargin<0 || leftMargin>0.5
            errordlg('Invalid size or margin values','Axes Size Error');
            return;
        end

        % Compute bottom margin to maintain desired top gap
        bottom = 1 - h - topMargin;
        if bottom < 0
            bottom = 0;
            warning('Top margin too large relative to height — adjusted.');
        end

        figs = findRealFigs();
        for k = 1:numel(figs)
            ax = findall(figs{k},'Type','axes');
            if isMultiPanelFigure(figs{k})
                applyAxesSizeMulti(figs{k}, w, h, topMargin, leftMargin);
            else
                applyAxesSizeSingle(figs{k}, w, h, topMargin, leftMargin);
            end

        end

        fprintf("✔ Axes size applied: width=%.2f, height=%.2f, topMargin=%.2f, leftMargin=%.2f\n", ...
            w, h, topMargin, leftMargin);
    end


%% ============================================================
% SAFE HELPERS — filters GUIs + wraps formatter
%% ============================================================
    function trackLastFigure(~,~)
        try
            fig = get(0,'CurrentFigure');
            if isempty(fig) || ~isvalid(fig)
                return;
            end
            if any(string(fig.Name) == skipList)
                return;
            end
            lastRealFigure = fig;
        catch
            % silent
        end
    end

    function figs = findRealFigs()

        if exist('hApplyCurrentOnly','var') && hApplyCurrentOnly.Value

            if isempty(lastRealFigure) || ~isvalid(lastRealFigure)
                warning('No active data figure selected.');
                figs = {};
                return;
            end

            figs = {lastRealFigure};
            return;
        end


        % --- ALL FIGURES MODE ---
        allF = findall(0,'Type','figure');
        figs = {};

        for fig = allF'
            if any(string(get(fig,'Name')) == skipList)
                continue;
            end

            % enforce legend style
            lg = findall(fig,'Type','legend');
            for L = lg'
                L.Color = 'none';
                L.Box   = 'off';
            end

            figs{end+1} = fig; %#ok<AGROW>
        end
    end


    function safeFormat(fig, sz, fs, bg)
        figName = string(get(fig,'Name'));
        if any(figName == skipList), return; end

        old = get(0,'CurrentFigure');
        set(0,'CurrentFigure',fig);

        % שימוש במעצב הכללי שלך
        if isempty(sz)
            sz = fig.Position(3:4);   % שומר את הגודל הנוכחי
        end
        postFormatAllFigures(sz,'Arial',fs,"CtrlGUI",bg,true);


        % legends – שקוף, בלי מסגרת
        lg = findall(fig,'Type','legend');
        for L = lg'
            L.Color = 'none';
            L.Box   = 'off';
        end

        % axes formatting בסיסי
        ax = findall(fig,'Type','axes');
        for a = ax'
            a.TickDir = 'out';
            a.Layer   = 'top';
        end
        for a = ax'
            % קו מסגרת דק מאוד
            a.LineWidth = 0.6;
        end

        fixAxisLabelsBrackets(fig);
        fixLegendBrackets(fig);

        set(0,'CurrentFigure',old);
    end

    function makeBtn(pos,label,callback)
        uicontrol(f,'Style','pushbutton','String',label,...
            'Units','normalized','Position',pos,...
            'FontSize',9,'BackgroundColor',[0.94 0.94 0.94],...
            'Callback',@(src,event) callback());
    end

%% ============================================================
% NEW HELPERS: label / legend cleanup
%% ============================================================

    function fixAxisLabelsBrackets(fig)
        ax = findall(fig,'Type','axes');
        for a = ax'
            hX = get(a,'XLabel');
            hY = get(a,'YLabel');
            hZ = get(a,'ZLabel');
            hT = get(a,'Title');

            set(hX,'String', convertBracketsToParens(get(hX,'String')));
            set(hY,'String', convertBracketsToParens(get(hY,'String')));
            set(hZ,'String', convertBracketsToParens(get(hZ,'String')));
            set(hT,'String', convertBracketsToParens(get(hT,'String')));
        end
    end

    function out = convertBracketsToParens(in)
        if isstring(in)
            in = cellstr(in);
        end
        if ischar(in)
            out = regexprep(in,'\[(.*?)\]','($1)');
        elseif iscellstr(in)
            out = in;
            for k = 1:numel(out)
                out{k} = regexprep(out{k},'\[(.*?)\]','($1)');
            end
        else
            out = in;
        end
    end

    function fixLegendBrackets(fig)
        lg = findall(fig,'Type','legend');
        for L = lg'
            str = L.String;
            if isstring(str)
                str = cellstr(str);
            end
            if ischar(str)
                s = str;
                s = strrep(s,'[',' ');
                s = strrep(s,']',' ');
                s = regexprep(s,'\s+',' ');
                s = strtrim(s);
                L.String = s;
            elseif iscellstr(str)
                for k = 1:numel(str)
                    s = str{k};
                    s = strrep(s,'[',' ');
                    s = strrep(s,']',' ');
                    s = regexprep(s,'\s+',' ');
                    str{k} = strtrim(s);
                end
                L.String = str;
            end
        end
    end

%% ============================================================
% FORMAT FOR PAPER + CLIPPING FIX
%% ============================================================

    function formatForPaper(fig)
        if nargin<1
            fig = gcf;
        end

        tickFont   = 16;
        labelFont  = 20;
        legendFont = 18;
        lineWidth  = 2.5;

        ax = findall(fig,'Type','axes');
        for a = ax'
            a.FontSize  = tickFont;
            a.LineWidth = 0.6;
            a.TickDir   = 'out';
            a.Box       = 'on';
            a.Layer     = 'top';

            if ~isempty(a.XLabel.String)
                a.XLabel.FontSize = labelFont;
            end
            if ~isempty(a.YLabel.String)
                a.YLabel.FontSize = labelFont;
            end
            if ~isempty(a.Title.String)
                a.Title.FontSize = labelFont;
            end

            L = findall(a,'Type','Line');
            set(L,'LineWidth',lineWidth);
        end

        lg = findall(fig,'Type','legend');
        for L = lg'
            L.FontSize = legendFont;
            L.Color    = 'none';
            L.Box      = 'off';
        end

        tx = findall(fig,'Type','text');
        for t = tx'
            if isempty(t.String), continue; end
            t.FontSize = labelFont;
        end

        drawnow;
        fixClipping(fig);
        drawnow;
    end

    function fixClipping(fig)
        ax = findall(fig,'Type','axes');
        if isempty(ax), return; end

        for a = ax'
            a.Units = 'normalized';
            drawnow;

            ti = a.TightInset;   % [left bottom right top]

            extraMargin = 0.06;

            left   = ti(1) + extraMargin;
            bottom = ti(2) + extraMargin*0.8;
            right  = ti(3) + extraMargin;
            top    = ti(4) + extraMargin*1.2;

            newW = 1 - left - right;
            newH = 1 - bottom - top;

            a.Position = [left bottom newW newH];
        end
    end
    function out = ternary(cond,a,b)
        if cond, out = a; else, out = b; end
    end
    function tf = isMultiPanelFigure(fig)
        ax = findall(fig,'Type','axes');
        ax = ax(~strcmp(get(ax,'Tag'),'legend'));  % להוציא legends
        tf = numel(ax) > 1;
    end
    function applyAxesSizeSingle(fig, w, h, topMargin, leftMargin)

        ax = findall(fig,'Type','axes');
        ax = ax(~strcmp(get(ax,'Tag'),'legend'));

        bottom = 1 - h - topMargin;
        if bottom < 0
            bottom = 0;
        end

        for a = ax'
            a.Units = 'normalized';
            a.Position = [leftMargin, bottom, w, h];
        end
    end
    function applyAxesSizeMulti(fig, w, h, topMargin, leftMargin)

        ax = findall(fig,'Type','axes');
        ax = ax(~strcmp(get(ax,'Tag'),'legend'));

        % --- exclude colorbars ---
        ax = ax(~arrayfun(@isColorbarAxes, ax));

        if isempty(ax), return; end

        % --- reference bounding box of all subplots ---
        pos = vertcat(ax.Position);
        left0   = min(pos(:,1));
        bottom0 = min(pos(:,2));
        right0  = max(pos(:,1) + pos(:,3));
        top0    = max(pos(:,2) + pos(:,4));

        width0  = right0 - left0;
        height0 = top0   - bottom0;

        % --- desired new box ---
        newLeft   = leftMargin;
        newTop    = 1 - topMargin;
        newWidth  = min(w, 1 - newLeft - 0.02);
        newHeight = min(h, newTop - 0.02);

        scaleX = newWidth  / width0;
        scaleY = newHeight / height0;

        for a = ax'
            p = a.Position;

            % scale around bottom-left of the block
            p(1) = newLeft + (p(1) - left0) * scaleX;
            p(2) = newTop  - (top0 - p(2) - p(4)) * scaleY - p(4)*scaleY;

            p(3) = p(3) * scaleX;
            p(4) = p(4) * scaleY;

            a.Units = 'normalized';
            a.Position = p;
        end
    end

    function closeGUI(~,~)
        if isfield(f.UserData,'listener') && isvalid(f.UserData.listener)
            delete(f.UserData.listener);
        end
        delete(f);
    end
    function tf = isColorbarAxes(a)
        tf = false;
        try
            if isprop(a,'Tag') && contains(string(a.Tag),'Colorbar','IgnoreCase',true)
                tf = true; return;
            end
            pos = a.Position;
            if pos(3) < 0.07 || pos(4) < 0.07
                tf = true; return;
            end
        catch
        end
    end
    function applyFontSystem(fig, style)

        % ===== AXES =====
        ax = findall(fig,'Type','axes');
        for a = ax'
            a.FontSize = style.tickFont;

            if ~isempty(a.XLabel.String)
                a.XLabel.FontSize = style.labelFont;
            end
            if ~isempty(a.YLabel.String)
                a.YLabel.FontSize = style.labelFont;
            end
            if ~isempty(a.Title.String)
                a.Title.FontSize  = style.titleFont;
            end
        end

        % ===== LEGEND =====
        lg = findall(fig,'Type','legend');
        for L = lg'
            L.FontSize = style.legendFont;

            % קצר את הדוגמה של הקו
            if isprop(L,'ItemTokenSize')
                L.ItemTokenSize = [10 8];  % רוחב וגובה הדוגמה
            end
        end

        % ===== TEXT OBJECTS =====
        tx = findall(fig,'Type','text');
        for t = tx'
            t.FontSize = style.annFont;
        end

        % ===== ANNOTATION TEXTBOX =====
        ann = findall(fig,'Type','textboxshape');
        for a = ann'
            a.FontSize = style.annFont;
        end

        % ===== COLORBARS =====
        cb = findall(fig,'Type','colorbar');
        for c = cb'
            c.FontSize = style.tickFont;
            if ~isempty(c.Label.String)
                c.Label.FontSize = style.labelFont;
            end
        end
    end

    function style = getStyleFromPanelSize(panelW, ~)

        % ===== DEFAULT (fallback = 3-panel PRL) =====
        style.tickFont   = 9;
        style.labelFont  = 11;
        style.titleFont  = 11;
        style.legendFont = 8;
        style.annFont    = 10;

        style.axWidth    = 0.76;
        style.axHeight   = 0.72;
        style.topMargin  = 0.08;
        style.leftMargin = 0.12;

        % ===== 3 PANELS =====
        if abs(panelW - 2.33) < 0.1

            style.axWidth    = 0.76;
            style.axHeight   = 0.72;
            style.topMargin  = 0.08;
            style.leftMargin = 0.12;

            % ===== 2 PANELS =====
        elseif abs(panelW - 3.5) < 0.2

            style.axWidth    = 0.80;
            style.axHeight   = 0.75;
            style.topMargin  = 0.06;
            style.leftMargin = 0.10;

        end

    end




end

