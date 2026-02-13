function FinalFigureFormatterUI()

%% ================== CONSTANTS ==================
singleColWidth  = 3.375;   % inch (APS / PRL)
doubleColWidth  = 7.0;
panelAspect     = 0.75;

% preference group for storing UI state between runs
prefGroup = 'FinalFigureFormatterUI_Prefs';

skipList = ["CtrlGUI","Final Figure Formatter","FigureTools","refLineGUI"];
lastRealFigure = [];
applyCurrentOnly = false;

%% ================== MAIN WINDOW =================
fig = uifigure( ...
    'Name','Final Figure Formatter', ...
    'Position',[900 80 540 880], ...
    'Color','white');
% ensure we save UI state on close
fig.CloseRequestFcn = @closeAndSave;

gl = uigridlayout(fig,[8 1]);
gl.RowHeight   = {'fit','fit','fit','fit','fit','fit','fit','1x'};
gl.Padding     = [8 8 8 8];
gl.RowSpacing  = 6;

addlistener(0,'CurrentFigure','PostSet',@trackLastFigure);

%% ================== SAVE & EXPORT (compact) =================
pSave = uipanel(gl,'Title','Save & Export');
pSave.Layout.Row = 1;

gSave = uigridlayout(pSave,[3 3]);
gSave.RowHeight = {'fit','fit','fit'};
gSave.ColumnWidth = {'1x',150,150};
gSave.Padding = [4 4 4 4];
gSave.RowSpacing = 4;

% Path selector (top)
lblSave = uilabel(gSave,'Text','Save folder:','FontWeight','bold');
lblSave.Layout.Row = 1; lblSave.Layout.Column = 1;
hPathBox = uieditfield(gSave,'text','Value',pwd);
hPathBox.Layout.Row = 1; hPathBox.Layout.Column = 1;
btnBrowse = uibutton(gSave,'Text','Browse','ButtonPushedFcn',@browseFolder);
btnBrowse.Layout.Row = 1; btnBrowse.Layout.Column = 2;

% Primary action bar (horizontal)
actionBar = uigridlayout(gSave,[1 4]); actionBar.Layout.Row = 2; actionBar.Layout.Column = [1 3];
actionBar.ColumnWidth = {'1x','1x','1x','1x'}; actionBar.Padding = [6 6 6 6]; actionBar.RowHeight = {'fit'};
btnPDF = uibutton(actionBar,'Text','Save PDF','ButtonPushedFcn',@(~,~) saveDo('pdf'));
btnPNG = uibutton(actionBar,'Text','Save PNG','ButtonPushedFcn',@(~,~) saveDo('png'));
btnJPEG = uibutton(actionBar,'Text','Save JPEG','ButtonPushedFcn',@(~,~) saveDo('jpeg'));
btnFIG = uibutton(actionBar,'Text','Save FIG','ButtonPushedFcn',@(~,~) saveDo('fig'));

% Options row (create subfolder name before checkbox so callback can reference it)
hSubfolderName = uieditfield(gSave,'text','Value','figs','Enable','off'); hSubfolderName.Layout.Row = 3; hSubfolderName.Layout.Column = 3;
hUseSubfolder = uicheckbox(gSave,'Text','Save into subfolder:','Value',false);
hUseSubfolder.Layout.Row = 3; hUseSubfolder.Layout.Column = 1;
hOverwrite = uicheckbox(gSave,'Text','Overwrite existing files'); hOverwrite.Layout.Row = 3; hOverwrite.Layout.Column = 2;
% set callback after creation to avoid undefined-variable closure issues
hUseSubfolder.ValueChangedFcn = @setSubfolderEnable;

%% ================== FIGURE SIZE =================
pFig = uipanel(gl,'Title','Figure Size (pixels)');
pFig.Layout.Row = 2;

gFig = uigridlayout(pFig,[2 3]);
gFig.ColumnWidth = {'fit','1x','fit'};
gFig.Padding = [4 4 4 4];
gFig.RowSpacing = 4;

lblW = uilabel(gFig,'Text','Width'); lblW.Layout.Row = 1; lblW.Layout.Column = 1;
hFigWidth = uieditfield(gFig,'numeric','Value',700); hFigWidth.Layout.Row = 1; hFigWidth.Layout.Column = 2;

lblH = uilabel(gFig,'Text','Height'); lblH.Layout.Row = 2; lblH.Layout.Column = 1;
hFigHeight = uieditfield(gFig,'numeric','Value',500); hFigHeight.Layout.Row = 2; hFigHeight.Layout.Column = 2;

btnFigApply = uibutton(gFig,'Text','Apply Figure Size','ButtonPushedFcn',@applyFigureSize);
btnFigApply.Layout.Row = [1 2]; btnFigApply.Layout.Column = 3;

%% ================== AXES SIZE =================
pAx = uipanel(gl,'Title','Axes Size (normalized)');
pAx.Layout.Row = 3;

gAx = uigridlayout(pAx,[3 4]);
gAx.ColumnWidth = {'fit','1x','fit','1x'};
gAx.Padding = [4 4 4 4];
gAx.RowSpacing = 4;

uilabel(gAx,'Text','Axes Width'); hAxWidth = uieditfield(gAx,'numeric','Value',0.70); hAxWidth.Layout.Row = 1; hAxWidth.Layout.Column = 2;
uilabel(gAx,'Text','Axes Height'); hAxHeight = uieditfield(gAx,'numeric','Value',0.65); hAxHeight.Layout.Row = 1; hAxHeight.Layout.Column = 4;

uilabel(gAx,'Text','Top'); hTopMargin = uieditfield(gAx,'numeric','Value',0.06); hTopMargin.Layout.Row = 2; hTopMargin.Layout.Column = 2;
uilabel(gAx,'Text','Left'); hLeftMargin = uieditfield(gAx,'numeric','Value',0.08); hLeftMargin.Layout.Row = 2; hLeftMargin.Layout.Column = 4;

btnAxApply = uibutton(gAx,'Text','Apply Axes','ButtonPushedFcn',@applyAxesSize);
btnAxApply.Layout.Row = 3; btnAxApply.Layout.Column = [1 4];

%% ================== SMART PAPER LAYOUT =================
pSmart = uipanel(gl,'Title','SMART Paper Layout');
pSmart.Layout.Row = 4;

gSmart = uigridlayout(pSmart,[3 4]);
gSmart.RowHeight = {'fit','fit','fit'}; 
gSmart.ColumnWidth = {'fit','1x','fit','1x'};
gSmart.Padding = [4 4 4 4];
gSmart.RowSpacing = 4;

% Row 1: panels across/down
lblPA = uilabel(gSmart,'Text','Panels across'); lblPA.Layout.Row = 1; lblPA.Layout.Column = 1;
hPanelsX = uieditfield(gSmart,'numeric','Value',2); hPanelsX.Layout.Row = 1; hPanelsX.Layout.Column = 2;
lblPD = uilabel(gSmart,'Text','Panels down'); lblPD.Layout.Row = 1; lblPD.Layout.Column = 3;
hPanelsY = uieditfield(gSmart,'numeric','Value',2); hPanelsY.Layout.Row = 1; hPanelsY.Layout.Column = 4;

% Row 2: column mode and aspect ratio
lblMode = uilabel(gSmart,'Text','Column mode'); lblMode.Layout.Row = 2; lblMode.Layout.Column = 1;
colMode = uidropdown(gSmart,'Items',{'Single column','Double column'},'Value','Double column'); colMode.Layout.Row = 2; colMode.Layout.Column = 2;
lblAspect = uilabel(gSmart,'Text','Aspect ratio (H/W)'); lblAspect.Layout.Row = 2; lblAspect.Layout.Column = 3;
hAspect = uieditfield(gSmart,'numeric','Value',panelAspect); hAspect.Layout.Row = 2; hAspect.Layout.Column = 4;

% Row 3: apply button
btnSmart = uibutton(gSmart,'Text','Apply SMART','ButtonPushedFcn',@applySmartLayout); btnSmart.Layout.Row = 3; btnSmart.Layout.Column = [1 4];

%% ================== APPEARANCE / COLORMAP CONTROL =================
pApp = uipanel(gl,'Title','Appearance / Colormap Control');
pApp.Layout.Row = 5;

gApp = uigridlayout(pApp,[6 6]);
gApp.RowHeight = {'fit','fit','fit','fit','fit','fit'};
gApp.ColumnWidth = {'fit','1x','fit','1x','fit','1x'};
gApp.Padding = [4 4 4 4];
gApp.RowSpacing = 4;

% Build colormap list with ScientificColourMaps8 integration
builtinMaps = { 'parula','jet','cool','spring','summer','autumn','winter','copper','turbo',...
    'hot','gray','bone','pink','hsv','lines','colorcube','prism','flag','white' };

% Test for R2023b+ colormaps (magma, inferno, plasma, cividis)
% These were added in later MATLAB versions
testMaps = {'magma', 'inferno', 'plasma', 'cividis'};
for t = 1:numel(testMaps)
    try
        feval(testMaps{t}, 2);  % Quick test
        builtinMaps{end+1} = testMaps{t};
    catch
        % Colormap not available in this MATLAB version
    end
end

cmoMaps = { 'cmocean(''thermal'')','cmocean(''haline'')','cmocean(''solar'')','cmocean(''matter'')',...
    'cmocean(''turbid'')','cmocean(''speed'')','cmocean(''amp'')','cmocean(''deep'')',...
    'cmocean(''dense'')','cmocean(''algae'')','cmocean(''balance'')','cmocean(''curl'')',...
    'cmocean(''delta'')','cmocean(''oxy'')','cmocean(''phase'')','cmocean(''rain'')',...
    'cmocean(''ice'')','cmocean(''gray'')' };

% Test if cmocean is available
try
    cmocean('thermal');  % Test call
catch
    % cmocean not available - clear the list
    cmoMaps = {};
end

% Remove potentially unavailable colormaps from custom list
customMaps = { 'softyellow','softgreen','softred','softblue','softpurple','softorange','softcyan',...
    'softgray','softbrown','softteal','softolive','softgold','softpink','softaqua',...
    'softsand','softsky','bluebright','redbright','greenbright','purplebright',...
    'orangebright','cyanbright','yellowbright','magnetabright','limebright',...
    'tealbright','ultrabrightblue','ultrabrightred','fire','ice','ocean','topo',...
    'terrain','bluewhitered','redwhiteblue',...
    'purplewhitegreen','brownwhiteblue','greenwhitepurple','bluewhiteorange',...
    'blackwhiteyellow' };
% Note: magma, inferno, plasma, cividis moved to builtinMaps with availability testing above

% Dynamically load ScientificColourMaps8 if available
scm8Maps = {};

try
    % MULTI-STAGE SCM8 DETECTION
    % This handles various SCM8 installation styles:
    % - As a folder of .m functions on the path
    % - As a toolbox with a main entry point
    % - With spaces in paths (Google Drive, OneDrive, etc.)
    
    scm8_dir = '';
    
    % Stage 1: Try to find scientificColourMaps8.m function (main entry point)
    % This works if SCM8 was installed as a toolbox with a main function
    scm8_func_path = which('scientificColourMaps8', '-all');
    if ~isempty(scm8_func_path)
        if ischar(scm8_func_path), scm8_func_path = {scm8_func_path}; end
        scm8_dir = fileparts(scm8_func_path{1});
    end
    
    % Stage 2: If Stage 1 failed, search path for common SCM8 colormap functions
    % This is more robust because SCM8 users often have individual colormap files
    % on the path (davos.m, batlow.m, etc.)
    if isempty(scm8_dir)
        % List of common SCM8 colormaps that are frequently used
        knownScm8Maps = {'davos', 'batlow', 'batlowS', 'batlowW', 'cmc', 'grayC', ...
            'nuuk', 'oleron', 'oslo', 'roma', 'romaO', 'tofino', 'turku', 'vanimo', ...
            'acton', 'bamako', 'berlin', 'bilbao', 'broc', 'cork', 'fes', 'gree', ...
            'hawai', 'imola', 'lajolla', 'lapaz', 'lisbon', 'managua', 'navia', ...
            'oliva', 'seattle', 'stromboli', 'tattooine', 'tybalt', 'ulvic'};
        
        for idx_map = 1:numel(knownScm8Maps)
            mapName = knownScm8Maps{idx_map};
            mapPath = which(mapName, '-all');
            
            if ~isempty(mapPath)
                if ischar(mapPath), mapPath = {mapPath}; end
                testDir = fileparts(mapPath{1});
                
                % Verify this directory likely contains colormaps
                % (need at least a few .m files)
                if isfolder(testDir)
                    dirContents = dir(fullfile(testDir, '*.m'));
                    if numel(dirContents) > 3
                        % Likely an SCM8 folder
                        scm8_dir = testDir;
                        break;
                    end
                end
            end
        end
    end
    
    % Stage 3: Extract all colormaps from the discovered directory
    if ~isempty(scm8_dir) && isfolder(scm8_dir)
        scm8_files = dir(fullfile(scm8_dir, '*.m'));
        
        for f = 1:numel(scm8_files)
            fname = scm8_files(f).name(1:end-2);  % Remove .m extension
            % Skip the main entry point function (if it exists)
            if ~strcmpi(fname, 'scientificColourMaps8')
                scm8Maps{end+1} = fname;
            end
        end
        
        % Verify at least one colormap actually works
        % This is a final sanity check that detection succeeded
        if ~isempty(scm8Maps)
            validMapFound = false;
            for verify_idx = 1:min(3, numel(scm8Maps))
                try
                    testCmap = feval(scm8Maps{verify_idx}, 8);
                    % Verify output format: Nx3 matrix of doubles in [0,1]
                    if ismatrix(testCmap) && size(testCmap,2) == 3 && ...
                       isdouble(testCmap) && ~any(isnan(testCmap(:))) && ...
                       all(testCmap(:) >= 0) && all(testCmap(:) <= 1)
                        validMapFound = true;
                        break;
                    end
                catch
                end
            end
            
            if ~validMapFound
                % Detection claimed success but colormaps don't work
                % This usually means path is set but installation is corrupted
                warning('ScientificColourMaps8 folder detected but colormaps cannot execute. Installation may be corrupted.');
                scm8Maps = {};
            end
        end
    end
    
catch
    % Silent failure - SCM8 is optional
    scm8Maps = {};
end

% Final cleanup: remove duplicates
if ~isempty(scm8Maps)
    scm8Maps = unique(scm8Maps);
    fprintf('[INFO] ScientificColourMaps8: Loaded %d colormaps\n', numel(scm8Maps));
else
    fprintf('[INFO] ScientificColourMaps8: Not found (optional)\n');
end

mapList = [ {'(no change)'};  ...
    {'--- Built-in ---'}; builtinMaps(:); {''}; ...
    {'--- Custom ---'}; customMaps(:); {''}; ...
    {'--- cmocean ---'}; cmoMaps(:); {''}; ...
    {'--- ScientificColourMaps8 ---'}; scm8Maps(:) ];

fprintf('[CONFIG] Total colormaps available: %d\n', numel(mapList)-4);  % Subtract separators and empty entries

% Row 1: Colormap dropdown + Spread mode
uilabel(gApp,'Text','Colormap:','FontSize',10); 
hPopupMap = uidropdown(gApp,'Items',mapList,'Value',mapList{1});
hPopupMap.Layout.Row = 1; hPopupMap.Layout.Column = 2;
uilabel(gApp,'Text','Spread:','FontSize',10);
hPopupSpread = uidropdown(gApp,'Items',{ 'ultra-narrow','ultra-narrow-rev','narrow','narrow-rev','medium','medium-rev',...
    'wide','wide-rev','ultra','ultra-rev','full','full-rev' },'Value','medium');
hPopupSpread.Layout.Row = 1; hPopupSpread.Layout.Column = [4 6];

% Row 2: Target selector + Folder path
uilabel(gApp,'Text','Target:','FontSize',10);
hRadioOpen = uicheckbox(gApp,'Text','Open figs'); 
hRadioOpen.Layout.Row = 2; hRadioOpen.Layout.Column = 2;
hRadioOpen.Value = true;
hRadioFolder = uicheckbox(gApp,'Text','Folder:'); 
hRadioFolder.Layout.Row = 2; hRadioFolder.Layout.Column = 4;
hEditFolder = uieditfield(gApp,'text','Value','','Enable','off');
hEditFolder.Layout.Row = 2; hEditFolder.Layout.Column = [5 6];
hRadioOpen.ValueChangedFcn = @(s,~) switchTarget(s.Value);
hRadioFolder.ValueChangedFcn = @(s,~) switchTarget(~s.Value);

% Row 3: Data line controls (width + style + marker size)
uilabel(gApp,'Text','Data W:','FontSize',9);
hEditDataLW = uieditfield(gApp,'text','Value','');
hEditDataLW.Layout.Row = 3; hEditDataLW.Layout.Column = 2;
uilabel(gApp,'Text','Style:','FontSize',9);
hPopupDataStyle = uidropdown(gApp,'Items',{'(no change)','-','--',':','-.','none'},'Value','(no change)');
hPopupDataStyle.Layout.Row = 3; hPopupDataStyle.Layout.Column = 4;
uilabel(gApp,'Text','Marker:','FontSize',9);
hEditMarkerSize = uieditfield(gApp,'text','Value','');
hEditMarkerSize.Layout.Row = 3; hEditMarkerSize.Layout.Column = 6;

% Row 4: Fit line controls (width + style + color)
uilabel(gApp,'Text','Fit W:','FontSize',9);
hEditFitLW = uieditfield(gApp,'text','Value','');
hEditFitLW.Layout.Row = 4; hEditFitLW.Layout.Column = 2;
uilabel(gApp,'Text','Style:','FontSize',9);
hPopupFitStyle = uidropdown(gApp,'Items',{'(no change)','-','--',':','-.','none'},'Value','(no change)');
hPopupFitStyle.Layout.Row = 4; hPopupFitStyle.Layout.Column = 4;
uilabel(gApp,'Text','Color:','FontSize',9);
hPopupFitColor = uidropdown(gApp,'Items',{'(no change)','black','red','blue','green','cyan','magenta','yellow','white'},'Value','(no change)');
hPopupFitColor.Layout.Row = 4; hPopupFitColor.Layout.Column = 6;

% Row 5: Legend/Plot reversal checkboxes
hChkReverseLegend = uicheckbox(gApp,'Text','Reverse Legend','FontSize',9);
hChkReverseLegend.Layout.Row = 5; hChkReverseLegend.Layout.Column = [1 2];
hChkReverseLegend.Value = false;
hChkReverseOrder = uicheckbox(gApp,'Text','Reverse Plot','FontSize',9);
hChkReverseOrder.Layout.Row = 5; hChkReverseOrder.Layout.Column = [4 5];
hChkReverseOrder.Value = false;

% Row 6: Apply button + Show All Colormaps button
btnAppearance = uibutton(gApp,'Text','Apply Appearance','ButtonPushedFcn',@applyAppearanceSettings);
btnAppearance.Layout.Row = 6; btnAppearance.Layout.Column = [1 4];
btnShowAllMaps = uibutton(gApp,'Text','Show All Maps','ButtonPushedFcn',@showAllColormapsPreviews);
btnShowAllMaps.Layout.Row = 6; btnShowAllMaps.Layout.Column = [5 6];

%% ================== TYPOGRAPHY =================
pTypo = uipanel(gl,'Title','Typography');
pTypo.Layout.Row = 6;

gTypo = uigridlayout(pTypo,[2 8]);
gTypo.RowHeight = {'fit','fit'};
gTypo.ColumnWidth = {'fit','1x','fit','fit','fit','fit','fit','fit'};
gTypo.Padding = [4 4 4 4];
gTypo.RowSpacing = 4;

% Row 1: Font controls + Legend controls
uilabel(gTypo,'Text','Font size:','FontSize',9); 
hFontSize = uidropdown(gTypo,'Items',string(8:2:30),'Value','12');
hFontSize.Layout.Row = 1; hFontSize.Layout.Column = 2;
btnApplyFont = uibutton(gTypo,'Text','Apply','ButtonPushedFcn',@applyFontSize);
btnApplyFont.Layout.Row = 1; btnApplyFont.Layout.Column = 3;

uilabel(gTypo,'Text','Legend:','FontSize',9);
hLegendFontSize = uidropdown(gTypo,'Items',string(8:2:30),'Value','12');
hLegendFontSize.Layout.Row = 1; hLegendFontSize.Layout.Column = [5 6];
btnApplyLegend = uibutton(gTypo,'Text','Apply','ButtonPushedFcn',@applyLegendFontSize);
btnApplyLegend.Layout.Row = 1; btnApplyLegend.Layout.Column = 7;

% Row 2: Legend position buttons (compact)
posGrid = uigridlayout(gTypo,[1 6]); posGrid.Layout.Row = 2; posGrid.Layout.Column = [1 8];
posGrid.ColumnWidth = {'1x','1x','1x','1x','1x','1x'}; posGrid.Padding = [2 2 2 2];
uibutton(posGrid,'Text','↗','ButtonPushedFcn',@(~,~) moveLegend('northeast'));
uibutton(posGrid,'Text','↖','ButtonPushedFcn',@(~,~) moveLegend('northwest'));
uibutton(posGrid,'Text','↙','ButtonPushedFcn',@(~,~) moveLegend('southwest'));
uibutton(posGrid,'Text','↘','ButtonPushedFcn',@(~,~) moveLegend('southeast'));
uibutton(posGrid,'Text','Best','ButtonPushedFcn',@(~,~) moveLegend('best'));
uibutton(posGrid,'Text','Out','ButtonPushedFcn',@(~,~) moveLegend('northeastoutside'));

% ================== ADVANCED / UTILITIES (collapsible) =================
% advanced panel (visible)
pAdvanced = uipanel(gl,'Title','Advanced / Utilities');
pAdvanced.Layout.Row = 7; pAdvanced.Visible = 'on';
gAdvanced = uigridlayout(pAdvanced,[2 6]); 
gAdvanced.RowHeight = {'fit','fit'}; 
gAdvanced.ColumnWidth = {'fit','1x','fit','fit','fit','fit'};
gAdvanced.Padding = [4 4 4 4];
gAdvanced.RowSpacing = 4;

chkCurrent = uicheckbox(gAdvanced,'Text','Apply CURRENT only', 'ValueChangedFcn',@(s,~) setApplyCurrent(s.Value),'FontSize',9);
chkCurrent.Layout.Row = 1; chkCurrent.Layout.Column = [1 2];
btnAdvWhite = uibutton(gAdvanced,'Text','Bg White','ButtonPushedFcn',@setFigureBackgroundWhite); 
btnAdvWhite.Layout.Row = 1; btnAdvWhite.Layout.Column = 3;
btnAdvFormat = uibutton(gAdvanced,'Text','Format','ButtonPushedFcn',@formatAllForPaper); 
btnAdvFormat.Layout.Row = 1; btnAdvFormat.Layout.Column = 4;
btnAdvReset = uibutton(gAdvanced,'Text','Reset All','ButtonPushedFcn',@resetAll); 
btnAdvReset.Layout.Row = 1; btnAdvReset.Layout.Column = 5;
btnAdvClose = uibutton(gAdvanced,'Text','Close','ButtonPushedFcn',@closeAndSave); 
btnAdvClose.Layout.Row = 1; btnAdvClose.Layout.Column = 6;
btnRestoreDefaults = uibutton(gAdvanced,'Text','Restore Defaults','ButtonPushedFcn',@restoreUIdefaults);
btnRestoreDefaults.Layout.Row = 2; btnRestoreDefaults.Layout.Column = [1 3];

% Standardize button appearance
styleAllButtons();

% load previously saved prefs (if any)
loadPrefs();

%% ==========================================================
% ================= CALLBACKS ===============================
%% ==========================================================

    function setApplyCurrent(val)
        applyCurrentOnly = val;
    end

    function browseFolder(~,~)
        p = uigetdir(pwd);
        if p~=0, hPathBox.Value = p; end
        % save chosen path to prefs immediately
        savePrefs();
    end

    function applyAxesSize(~,~)
        for f = findRealFigs()
            ax = findall(f{1},'Type','axes');
            for a = ax'
                a.Units = 'normalized';
                a.Position = [ ...
                    hLeftMargin.Value, ...
                    1-hAxHeight.Value-hTopMargin.Value, ...
                    hAxWidth.Value, ...
                    hAxHeight.Value];
            end
        end
    end

    function applyFigureSize(~,~)
        w = hFigWidth.Value;
        h = hFigHeight.Value;
        figs = findRealFigs();
        for k = 1:numel(figs)
            f0 = figs{k};
            try
                % Position is [left bottom width height] in pixels for figures
                pos = f0.Position;
                pos(3:4) = [w h];
                f0.Position = pos;
            catch
            end
        end
    end

    function applyFontSize(~,~)
        fs = str2double(hFontSize.Value);
        for f = findRealFigs()
            set(findall(f{1},'Type','axes'),'FontSize',fs);
        end
    end

    function applyLegendFontSize(~,~)
        fs = str2double(hLegendFontSize.Value);
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
                if isprop(L,'FontName'), L.FontName = 'latex'; end
                if isprop(L,'Interpreter'), L.Interpreter = 'latex'; end
                if isprop(L,'ItemTokenSize'), L.ItemTokenSize = [10 8]; end
                % sanitize legend strings
                if iscell(L.String)
                    for j = 1:numel(L.String)
                        L.String{j} = sanitizeLatexString(L.String{j});
                    end
                elseif ischar(L.String) || isstring(L.String)
                    L.String = sanitizeLatexString(L.String);
                end
            end
        end
    end

    function applySmartLayout(~,~)
        figs = findRealFigs();
        if isempty(figs)
            errordlg('No data figures found','SMART Layout');
            return;
        end

        nx = hPanelsX.Value;
        ny = hPanelsY.Value;

        if any([nx ny] < 1)
            errordlg('Panels must be positive integers','SMART Layout');
            return;
        end

        isDouble = strcmp(colMode.Value,'Double column');

        % article width depending on column mode
        if isDouble
            articleWidth = doubleColWidth;
        else
            articleWidth = singleColWidth;
        end

        panelWidth = articleWidth / nx;
        ratio = hAspect.Value;
        if isnan(ratio) || ratio <= 0 || ratio > 2
            errordlg('Aspect ratio must be positive and reasonable (e.g. 0.6)','SMART Layout');
            return;
        end
        panelHeight = panelWidth * ratio;

        % get style from panel size
        style = getStyleFromPanelSize(panelWidth, panelHeight);

        % derive physical axes size (in inches) and compute fonts/markers/lines
        axPhysicalW = panelWidth * style.axWidth;   % inches
        axPhysicalH = panelHeight * style.axHeight; % inches

        % use a single scale factor from axes physical size (height is primary)
        scl = max(0.5, axPhysicalH); % avoid zero

        % fonts: continuous mapping tuned for printed figures
        tickFont   = max(6, min(22, round(6 + scl * 3.0)));
        labelFont  = max(8, round(tickFont + 2));
        titleFont  = max(9, round(tickFont + 3));
        legendFont = max(6, round(labelFont - 1));
        annFont    = max(8, round(tickFont + 1));

        % line and marker sizing (in points for markers, linewidth in points)
        lineWidth  = max(0.5, min(3.0, 0.6 * scl));
        markerSize = max(4, min(24, round(6 + scl * 6)));
        itemTokenW = max(8, round(markerSize * 1.2));
        itemTokenH = max(6, round(markerSize * 1.0));

        % store derived style
        style.tickFont   = tickFont;
        style.labelFont  = labelFont;
        style.titleFont  = titleFont;
        style.legendFont = legendFont;
        style.annFont    = annFont;
        style.lineWidth  = lineWidth;
        style.markerSize = markerSize;
        style.itemTokenSize = [itemTokenW itemTokenH];

        % update UI controls with computed values
        hTopMargin.Value  = style.topMargin;
        hLeftMargin.Value = style.leftMargin;

        % screen preview DPI
        DPI = 96;
        hFigWidth.Value  = round(panelWidth * DPI);
        hFigHeight.Value = round(panelHeight * DPI);

        hAxWidth.Value  = style.axWidth;
        hAxHeight.Value = style.axHeight;
        hTopMargin.Value = style.topMargin;
        hLeftMargin.Value = style.leftMargin;

        % reflect computed font sizes in the UI dropdowns
        setPopupValueByString(hFontSize,       num2str(style.tickFont));
        setPopupValueByString(hLegendFontSize, num2str(style.legendFont));

        % apply to MATLAB figures
        previewScale = 3.0;
        for k = 1:numel(figs)
            fig0 = figs{k};

            % set physical paper size for export
            try
                fig0.Units = 'inches';
                fig0.PaperUnits = 'inches';
                fig0.PaperSize = [panelWidth panelHeight];
                fig0.PaperPosition = [0 0 panelWidth panelHeight];
                fig0.PaperPositionMode = 'manual';
            catch
            end

            % set screen preview size
            try
                fig0.Units = 'pixels';
                fig0.Position(3) = panelWidth * DPI * previewScale;
                fig0.Position(4) = panelHeight * DPI * previewScale;
            catch
            end

            % apply axes geometry
            if isMultiPanelFigure(fig0)
                applyAxesSizeMulti(fig0, style.axWidth, style.axHeight, style.topMargin, style.leftMargin);
            else
                applyAxesSizeSingle(fig0, style.axWidth, style.axHeight, style.topMargin, style.leftMargin);
            end

            % apply fonts, line widths, marker sizes and legend sizing
            applyFontSystem(fig0, style);
        end

        fprintf('✔ SMART: nx=%d | Panel = %.2f x %.2f inch\n', nx, panelWidth, panelHeight);
    end

    function switchTarget(useOpen)
        if useOpen
            hRadioOpen.Value = true;
            hRadioFolder.Value = false;
            hEditFolder.Enable = 'off';
        else
            hRadioOpen.Value = false;
            hRadioFolder.Value = true;
            hEditFolder.Enable = 'on';
        end
    end

    function applyAppearanceSettings(~,~)
        % Extract values from UI controls
        maps = hPopupMap.Items;
        mapName = hPopupMap.Value;
        
        noColormapChange = strcmp(mapName,'(no change)');
        
        spreadMode = hPopupSpread.Value;
        
        % Target: open figures or folder
        useFolder = logical(hRadioFolder.Value);
        
        % Fit color
        fitColor_str = hPopupFitColor.Value;
        if strcmp(fitColor_str,'(no change)')
            fitColor = '';
        else
            fitColor = fitColor_str;
        end
        
        % Data lines
        dw = str2double(hEditDataLW.Value);
        if isnan(dw) || dw <= 0, dw = []; end
        
        dataStyle = hPopupDataStyle.Value;
        if strcmp(dataStyle,'(no change)'), dataStyle = ''; end
        
        % Marker size
        ms = str2double(hEditMarkerSize.Value);
        if isnan(ms) || ms <= 0, ms = []; end
        
        % Fit lines
        fw = str2double(hEditFitLW.Value);
        if isnan(fw) || fw <= 0, fw = []; end
        
        fitStyle = hPopupFitStyle.Value;
        if strcmp(fitStyle,'(no change)'), fitStyle = ''; end
        
        % Legend/plot order flags (now actual checkboxes with .Value)
        reverseLegend = logical(hChkReverseLegend.Value);
        reverseOrder = logical(hChkReverseOrder.Value);
        
        try
            if ~useFolder
                % Apply to currently open figures
                applyColormapToFigures(mapName, [], spreadMode, ...
                    fitColor, dw, dataStyle, fw, fitStyle, reverseOrder, reverseLegend, noColormapChange, ms);
            else
                % Apply to .fig files in the selected folder
                folderName = strtrim(hEditFolder.Value);
                if isempty(folderName) || ~isfolder(folderName)
                    errordlg('Invalid folder path','Appearance Error');
                    return;
                end
                applyColormapToFigures(mapName, folderName, spreadMode, ...
                    fitColor, dw, dataStyle, fw, fitStyle, reverseOrder, reverseLegend, noColormapChange, ms);
            end
            fprintf('✔ Appearance settings applied.\n');
        catch ME
            errordlg(ME.message,'Appearance Error');
        end
    end

    function showAllColormapsPreviews(~,~)
        % SHOWALLCOLORMAPSPREVIEWS - Display all available colormaps with tiledlayout
        % Each colormap shown as horizontal bar with proper error handling
        
        % DEFENSIVE: Close any existing preview window to prevent accumulation
        % This ensures only one preview window is open at a time
        existingPreview = findall(0, 'Type', 'figure', 'Name', 'All Available Colormaps');
        if ~isempty(existingPreview)
            for k = existingPreview'
                try
                    close(k);
                catch
                    % Silent failure if close fails
                end
            end
        end
        
        % Extract colormap names from mapList (skip separators, empty entries, and placeholders)
        mapNames = {};
        for i = 1:numel(mapList)
            name = mapList{i};
            % Skip empty strings, section separators, and placeholder entries
            if ~strcmp(name,'') && ~startsWith(name,'---') && ~strcmp(name,'(no change)')
                mapNames{end+1} = name;
            end
        end
        
        nMaps = numel(mapNames);
        fprintf('[PREVIEW] Opening colormap preview for %d maps\n', nMaps);
        
        % Calculate tile dimensions for optimal layout
        % Aim for narrow strips stacked vertically
        nCols = 1;  % Single column of colormaps
        nRows = nMaps;
        
        % Create new figure with tiledlayout
        % CRITICAL: Hide figure during construction to prevent blank canvas flashing
        fig = figure('Name','All Available Colormaps','NumberTitle','off',...
            'Position',[100 100 1400 min(max(25*nRows, 600), 1200)],...
            'Visible','off');  % Hide until fully populated
        
        % CRITICAL: Pass figure handle explicitly to tiledlayout to prevent
        % tiledlayout() from creating a separate blank figure when main UI is uifigure
        tl = tiledlayout(fig, nRows, 1, 'Padding','compact','TileSpacing','tight');
        
        loadedCount = 0;
        failedMaps = {};
        
        for k = 1:nMaps
            mapName = mapNames{k};
            
            try
                % Get colormap with error handling
                cmap = getColormapToUse(mapName);
                if isempty(cmap)
                    failedMaps{end+1} = mapName;
                    continue;
                end
                
                % Verify colormap format (should be Nx3)
                if size(cmap,2) ~= 3
                    failedMaps{end+1} = [mapName ' (bad size)'];
                    continue;
                end
                
                % Create tile for this colormap
                ax = nexttile(tl);
                
                % Display colormap as horizontal bar
                colorData = reshape(cmap, [1, size(cmap,1), 3]);
                image(ax, colorData);
                
                % Configure axis
                ax.YTick = [];
                ax.XTick = [];
                ax.YLabel.String = mapName;
                ax.YLabel.FontSize = 9;
                ax.YLabel.Rotation = 0;
                ax.YLabel.HorizontalAlignment = 'right';
                
                loadedCount = loadedCount + 1;
                
            catch ME
                % Log failed colormap
                failedMaps{end+1} = [mapName ' (error: ' ME.message(1:30) ')'];
                fprintf('[WARNING] Colormap %s failed: %s\n', mapName, ME.message);
            end
        end
        
        % Set title
        title(tl, sprintf('Available Colormaps: %d / %d loaded', loadedCount, nMaps), ...
            'FontSize', 14, 'FontWeight', 'bold');
        
        % Log summary
        fprintf('[PREVIEW] Successfully loaded %d / %d colormaps\n', loadedCount, nMaps);
        
        if ~isempty(failedMaps)
            fprintf('[PREVIEW] Failed maps:\n');
            for i = 1:numel(failedMaps)
                fprintf('  - %s\n', failedMaps{i});
            end
        end
        
        % Make figure visible now that content is fully loaded
        fig.Visible = 'on';
    end

    function saveDo(mode)
        baseFolder = hPathBox.Value;
        overwrite = logical(hOverwrite.Value);

        if exist('hUseSubfolder','var') && hUseSubfolder.Value
            subName = strtrim(hSubfolderName.Value);
            if isempty(subName)
                errordlg('Subfolder name is empty','Save Error');
                return;
            end
            saveFolder = fullfile(baseFolder, subName);
            if ~exist(saveFolder,'dir')
                mkdir(saveFolder);
            end
        else
            saveFolder = baseFolder;
        end

        % ensure export-friendly font/interpreter settings match UI
        ensureExportFonts();

        for f = findRealFigs()
            fig0 = f{1};
            baseName = fig0.Name;
            if isempty(baseName), baseName = 'Figure'; end
            baseName = regexprep(baseName, '[\\/:*?"<>|]', '_');
            baseName = strrep(baseName,'—','-'); baseName = strrep(baseName,'–','-');

            outBase = fullfile(saveFolder, baseName);

            switch lower(mode)
                case 'fig'
                    outPath = ensureFreeFilename([outBase '.fig'], overwrite);
                    try
                        savefig(fig0, outPath);
                    catch ME
                        warning('Failed to save FIG (%s): %s', outPath, ME.message);
                    end

                case 'png'
                    outPath = ensureFreeFilename([outBase '.png'], overwrite);
                    try
                        exportgraphics(fig0, outPath, 'Resolution',300);
                    catch
                        % fallback to print
                        try
                            print(fig0, outPath, '-dpng', '-r300');
                        catch ME
                            warning('Failed to save PNG (%s): %s', outPath, ME.message);
                        end
                    end

                case 'jpeg'
                    outPath = ensureFreeFilename([outBase '.jpg'], overwrite);
                    try
                        exportgraphics(fig0, outPath, 'Resolution',300);
                    catch
                        try
                            print(fig0, outPath, '-djpeg', '-r300');
                        catch ME
                            warning('Failed to save JPEG (%s): %s', outPath, ME.message);
                        end
                    end

                case 'pdf'
                    outPath = ensureFreeFilename([outBase '.pdf'], overwrite);
                    % try exportgraphics first, then fall back to saveas/print
                    try
                        exportgraphics(fig0, outPath, 'ContentType','vector');
                    catch
                        try
                            saveas(fig0, outPath);
                        catch
                            try
                                print(fig0, '-dpdf', outPath);
                            catch ME
                                warning('Failed to save PDF (%s): %s', outPath, ME.message);
                            end
                        end
                    end

                otherwise
                    error('Unknown save mode: %s',mode);
            end
        end
          % persist UI state after a save operation
          savePrefs();
    end

    function ensureExportFonts()
        % Apply font settings and LaTeX interpreters before exporting
        fs = str2double(hFontSize.Value);
        lfs = str2double(hLegendFontSize.Value);
        figs = findRealFigs();
        for k = 1:numel(figs)
            fig = figs{k};
            % set renderer for vector export
            try, fig.Renderer = 'painters'; catch, end

            ax = findall(fig,'Type','axes');
            for a = ax'
                try
                    if isprop(a,'FontUnits'), a.FontUnits = 'points'; end
                    a.FontSize = fs;
                    if isprop(a,'TickLabelInterpreter'), a.TickLabelInterpreter = 'latex'; end
                    % X/Y labels and title
                    if ~isempty(a.XLabel.String)
                        a.XLabel.String = sanitizeLatexString(a.XLabel.String);
                        if isprop(a.XLabel,'FontUnits'), a.XLabel.FontUnits = 'points'; end
                        a.XLabel.FontSize = fs;
                        if isprop(a.XLabel,'Interpreter'), a.XLabel.Interpreter = 'latex'; end
                        if isprop(a.XLabel,'FontName'), a.XLabel.FontName = 'latex'; end
                    end
                    if ~isempty(a.YLabel.String)
                        a.YLabel.String = sanitizeLatexString(a.YLabel.String);
                        if isprop(a.YLabel,'FontUnits'), a.YLabel.FontUnits = 'points'; end
                        a.YLabel.FontSize = fs;
                        if isprop(a.YLabel,'Interpreter'), a.YLabel.Interpreter = 'latex'; end
                        if isprop(a.YLabel,'FontName'), a.YLabel.FontName = 'latex'; end
                    end
                    if ~isempty(a.Title.String)
                        a.Title.String = sanitizeLatexString(a.Title.String);
                        if isprop(a.Title,'FontUnits'), a.Title.FontUnits = 'points'; end
                        a.Title.FontSize = fs;
                        if isprop(a.Title,'Interpreter'), a.Title.Interpreter = 'latex'; end
                        if isprop(a.Title,'FontName'), a.Title.FontName = 'latex'; end
                    end
                catch
                end
            end

            lg = findall(fig,'Type','legend');
            for L = lg'
                try
                    if isprop(L,'FontUnits'), L.FontUnits = 'points'; end
                    L.FontSize = lfs;
                    if isprop(L,'Interpreter'), L.Interpreter = 'latex'; end
                    if isprop(L,'FontName'), L.FontName = 'latex'; end
                    if isprop(L,'ItemTokenSize'), L.ItemTokenSize = [10 8]; end
                catch
                end
            end
        end
    end


    function setFigureBackgroundWhite(~,~)
        for f = findRealFigs()
            f{1}.Color = 'white';
        end
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

    function resetAll(~,~)
        figs = findRealFigs();
        for k = 1:numel(figs)
            fig = figs{k};
            try
                fig.Color = [0.94 0.94 0.94];
                fig.Position(3:4) = [560 420];
                ax = findall(fig,'Type','axes');
                for a = ax'
                    a.FontName = 'Helvetica';
                    a.FontSize = 11;
                    a.LineWidth = 0.5;
                    a.Box = 'on';
                end
            catch
            end
        end
    end

    function formatAllForPaper(~,~)
        figs = findRealFigs();
        for k = 1:numel(figs)
            fig = figs{k};
            formatForPaper(fig);
        end
    end

    function out = ensureFreeFilename(pathname, overwrite)
        % ENSUREFREEFILE NAME - Generate unique filename if needed
        % INPUT: pathname - full file path
        %        overwrite - if true, return original pathname
        % OUTPUT: out - a filename that doesn't exist (or original if overwrite=true)
        % SAFETY: Limits iteration to 10000 to prevent infinite loops
        
        if overwrite || ~exist(pathname,'file')
            out = pathname; return;
        end
        
        [p,n,e] = fileparts(pathname);
        i = 1;
        maxIter = 10000;  % SAFETY: prevent infinite loop
        while i <= maxIter
            cand = fullfile(p, sprintf('%s_%d%s', n, i, e));
            if ~exist(cand,'file')
                out = cand; return;
            end
            i = i + 1;
        end
        
        % FALLBACK: If we hit maxIter, use timestamp to guarantee uniqueness
        timestamp = sprintf('_%s', datetime('now','Format','yyyyMMdd_HHmmss'));
        out = fullfile(p, sprintf('%s%s%s', n, timestamp, e));
    end

    function styleAllButtons()
        btns = findall(fig,'Type','uibutton');
        for b = btns'
            try
                txt = string(b.Text);
                b.FontSize = 11;
                b.FontWeight = 'normal';
                b.BackgroundColor = [0.95 0.95 0.95];
                b.Tooltip = b.Text;
                % Make primary Save buttons visually dominant
                if startsWith(lower(txt),'save')
                    b.FontWeight = 'bold';
                    b.BackgroundColor = [0.82 0.90 1.00];
                    b.FontSize = 12;
                end
            catch
            end
        end
    end

    function setSubfolderEnable(s,~)
        if exist('hSubfolderName','var') && isvalid(hSubfolderName)
            if s.Value
                hSubfolderName.Enable = 'on';
            else
                hSubfolderName.Enable = 'off';
            end
        end
    end

    % ------------------- Preferences (save/load UI state) -----------------
    function savePrefs()
        try
            if ~ispref(prefGroup)
                setpref(prefGroup,'initialized',true);
            end
            setpref(prefGroup,'LastPath',hPathBox.Value);
            setpref(prefGroup,'UseSubfolder',logical(hUseSubfolder.Value));
            setpref(prefGroup,'SubfolderName',hSubfolderName.Value);
            setpref(prefGroup,'Overwrite',logical(hOverwrite.Value));
            setpref(prefGroup,'FigWidth',double(hFigWidth.Value));
            setpref(prefGroup,'FigHeight',double(hFigHeight.Value));
            setpref(prefGroup,'AxWidth',double(hAxWidth.Value));
            setpref(prefGroup,'AxHeight',double(hAxHeight.Value));
            setpref(prefGroup,'TopMargin',double(hTopMargin.Value));
            setpref(prefGroup,'LeftMargin',double(hLeftMargin.Value));
            setpref(prefGroup,'PanelsX',double(hPanelsX.Value));
            setpref(prefGroup,'PanelsY',double(hPanelsY.Value));
            setpref(prefGroup,'ColMode',colMode.Value);
            setpref(prefGroup,'Aspect',double(hAspect.Value));
            setpref(prefGroup,'FontSize',hFontSize.Value);
            setpref(prefGroup,'LegendFontSize',hLegendFontSize.Value);
            setpref(prefGroup,'ApplyCurrentOnly',logical(applyCurrentOnly));
            % Appearance preferences
            setpref(prefGroup,'AppearanceMapName',hPopupMap.Value);
            setpref(prefGroup,'AppearanceSpreadMode',hPopupSpread.Value);
            setpref(prefGroup,'AppearanceUseFolder',logical(hRadioFolder.Value));
            setpref(prefGroup,'AppearanceFolderPath',hEditFolder.Value);
            setpref(prefGroup,'AppearanceFitColor',hPopupFitColor.Value);
            setpref(prefGroup,'AppearanceDataLineWidth',hEditDataLW.Value);
            setpref(prefGroup,'AppearanceDataLineStyle',hPopupDataStyle.Value);
            setpref(prefGroup,'AppearanceMarkerSize',hEditMarkerSize.Value);
            setpref(prefGroup,'AppearanceFitLineWidth',hEditFitLW.Value);
            setpref(prefGroup,'AppearanceFitLineStyle',hPopupFitStyle.Value);
        catch
        end
    end

    function loadPrefs()
        % LOADPREFS - Safely load preferences with type validation
        % Defaults to UI initial values if preferences missing or malformed
        try
            % Path preference
            if ispref(prefGroup,'LastPath')
                p = getpref(prefGroup,'LastPath');
                if ischar(p) || isstring(p)
                    hPathBox.Value = char(p);
                end
            end
            
            % Subfolder preferences
            if ispref(prefGroup,'UseSubfolder')
                useSub = getpref(prefGroup,'UseSubfolder');
                if islogical(useSub) || isnumeric(useSub)
                    hUseSubfolder.Value = logical(useSub(1));
                    hSubfolderName.Enable = iif(hUseSubfolder.Value, 'on', 'off');
                end
            end
            if ispref(prefGroup,'SubfolderName')
                sf = getpref(prefGroup,'SubfolderName');
                if ischar(sf) || isstring(sf)
                    hSubfolderName.Value = char(sf);
                end
            end
            
            % Save options
            if ispref(prefGroup,'Overwrite')
                ov = getpref(prefGroup,'Overwrite');
                if islogical(ov) || isnumeric(ov)
                    hOverwrite.Value = logical(ov(1));
                end
            end
            
            % Figure size preferences
            if ispref(prefGroup,'FigWidth')
                fw = getpref(prefGroup,'FigWidth');
                if isnumeric(fw) && fw > 0
                    hFigWidth.Value = fw(1);
                end
            end
            if ispref(prefGroup,'FigHeight')
                fh = getpref(prefGroup,'FigHeight');
                if isnumeric(fh) && fh > 0
                    hFigHeight.Value = fh(1);
                end
            end
            
            % Axes size preferences
            if ispref(prefGroup,'AxWidth')
                aw = getpref(prefGroup,'AxWidth');
                if isnumeric(aw) && aw >=0 && aw <= 1
                    hAxWidth.Value = aw(1);
                end
            end
            if ispref(prefGroup,'AxHeight')
                ah = getpref(prefGroup,'AxHeight');
                if isnumeric(ah) && ah >= 0 && ah <= 1
                    hAxHeight.Value = ah(1);
                end
            end
            
            % Margin preferences
            if ispref(prefGroup,'TopMargin')
                tm = getpref(prefGroup,'TopMargin');
                if isnumeric(tm) && tm >= 0 && tm <= 1
                    hTopMargin.Value = tm(1);
                end
            end
            if ispref(prefGroup,'LeftMargin')
                lm = getpref(prefGroup,'LeftMargin');
                if isnumeric(lm) && lm >= 0 && lm <= 1
                    hLeftMargin.Value = lm(1);
                end
            end
            
            % Panel preferences
            if ispref(prefGroup,'PanelsX')
                px = getpref(prefGroup,'PanelsX');
                if isnumeric(px) && px > 0
                    hPanelsX.Value = px(1);
                end
            end
            if ispref(prefGroup,'PanelsY')
                py = getpref(prefGroup,'PanelsY');
                if isnumeric(py) && py > 0
                    hPanelsY.Value = py(1);
                end
            end
            
            % Layout preferences
            if ispref(prefGroup,'ColMode')
                cm = getpref(prefGroup,'ColMode');
                if ischar(cm) || isstring(cm)
                    cm = char(cm);
                    if any(strcmp(colMode.Items, cm))
                        colMode.Value = cm;
                    end
                end
            end
            if ispref(prefGroup,'Aspect')
                asp = getpref(prefGroup,'Aspect');
                if isnumeric(asp) && asp > 0
                    hAspect.Value = asp(1);
                end
            end
            
            % Typography preferences
            if ispref(prefGroup,'FontSize')
                fs = getpref(prefGroup,'FontSize');
                if isnumeric(fs) && fs > 0
                    hFontSize.Value = num2str(fs(1));
                elseif ischar(fs) || isstring(fs)
                    hFontSize.Value = char(fs);
                end
            end
            if ispref(prefGroup,'LegendFontSize')
                lfs = getpref(prefGroup,'LegendFontSize');
                if isnumeric(lfs) && lfs > 0
                    hLegendFontSize.Value = num2str(lfs(1));
                elseif ischar(lfs) || isstring(lfs)
                    hLegendFontSize.Value = char(lfs);
                end
            end
            
            % Current-only preference
            if ispref(prefGroup,'ApplyCurrentOnly')
                aco = getpref(prefGroup,'ApplyCurrentOnly');
                if islogical(aco) || isnumeric(aco)
                    applyCurrentOnly = logical(aco(1));
                    chkCurrent.Value = applyCurrentOnly;
                end
            end
            
            % Appearance preferences
            if ispref(prefGroup,'AppearanceMapName')
                mn = getpref(prefGroup,'AppearanceMapName');
                if ischar(mn) || isstring(mn)
                    mn = char(mn);
                    if any(strcmp(mapList, mn))
                        hPopupMap.Value = mn;
                    end
                end
            end
            if ispref(prefGroup,'AppearanceSpreadMode')
                sm = getpref(prefGroup,'AppearanceSpreadMode');
                if ischar(sm) || isstring(sm)
                    sm = char(sm);
                    if any(strcmp(hPopupSpread.Items, sm))
                        hPopupSpread.Value = sm;
                    end
                end
            end
            if ispref(prefGroup,'AppearanceUseFolder')
                auf = getpref(prefGroup,'AppearanceUseFolder');
                if islogical(auf) || isnumeric(auf)
                    auf = logical(auf(1));
                    hRadioFolder.Value = auf;
                    hRadioOpen.Value = ~auf;
                    hEditFolder.Enable = iif(auf, 'on', 'off');
                end
            end
            if ispref(prefGroup,'AppearanceFolderPath')
                fp = getpref(prefGroup,'AppearanceFolderPath');
                if ischar(fp) || isstring(fp)
                    hEditFolder.Value = char(fp);
                end
            end
            if ispref(prefGroup,'AppearanceFitColor')
                fc = getpref(prefGroup,'AppearanceFitColor');
                if ischar(fc) || isstring(fc)
                    fc = char(fc);
                    if any(strcmp(hPopupFitColor.Items, fc))
                        hPopupFitColor.Value = fc;
                    end
                end
            end
            if ispref(prefGroup,'AppearanceDataLineWidth')
                dlw = getpref(prefGroup,'AppearanceDataLineWidth');
                if isnumeric(dlw)
                    hEditDataLW.Value = num2str(dlw(1));
                elseif ischar(dlw) || isstring(dlw)
                    hEditDataLW.Value = char(dlw);
                end
            end
            if ispref(prefGroup,'AppearanceDataLineStyle')
                dls = getpref(prefGroup,'AppearanceDataLineStyle');
                if ischar(dls) || isstring(dls)
                    dls = char(dls);
                    if any(strcmp(hPopupDataStyle.Items, dls))
                        hPopupDataStyle.Value = dls;
                    end
                end
            end
            if ispref(prefGroup,'AppearanceMarkerSize')
                ms = getpref(prefGroup,'AppearanceMarkerSize');
                if isnumeric(ms)
                    hEditMarkerSize.Value = num2str(ms(1));
                elseif ischar(ms) || isstring(ms)
                    hEditMarkerSize.Value = char(ms);
                end
            end
            if ispref(prefGroup,'AppearanceFitLineWidth')
                flw = getpref(prefGroup,'AppearanceFitLineWidth');
                if isnumeric(flw)
                    hEditFitLW.Value = num2str(flw(1));
                elseif ischar(flw) || isstring(flw)
                    hEditFitLW.Value = char(flw);
                end
            end
            if ispref(prefGroup,'AppearanceFitLineStyle')
                fls = getpref(prefGroup,'AppearanceFitLineStyle');
                if ischar(fls) || isstring(fls)
                    fls = char(fls);
                    if any(strcmp(hPopupFitStyle.Items, fls))
                        hPopupFitStyle.Value = fls;
                    end
                end
            end
        catch ME
            % Silent failure - just use defaults
            warning('Some preferences could not be loaded: %s', ME.message);
        end
    end
    
    function result = iif(condition, trueVal, falseVal)
        % IIF - Simple ternary operator for compact code
        if condition
            result = trueVal;
        else
            result = falseVal;
        end
    end

    function restoreUIdefaults(~,~)
        % remove stored prefs and reset controls to initial defaults
        try
            if ispref(prefGroup), rmpref(prefGroup); end
        catch
        end
        % reset controls to the defaults defined earlier in this file
        hPathBox.Value = pwd;
        hSubfolderName.Value = 'figs'; hSubfolderName.Enable = 'off'; hUseSubfolder.Value = false;
        hOverwrite.Value = false;
        hFigWidth.Value = 700; hFigHeight.Value = 500;
        hAxWidth.Value = 0.70; hAxHeight.Value = 0.65;
        hTopMargin.Value = 0.06; hLeftMargin.Value = 0.08;
        hPanelsX.Value = 2; hPanelsY.Value = 2;
        colMode.Value = 'Double column';
        hAspect.Value = panelAspect;
        hFontSize.Value = '12'; hLegendFontSize.Value = '12';
        applyCurrentOnly = false; chkCurrent.Value = false;
        % reset Appearance controls
        hPopupMap.Value = mapList{1};
        hPopupSpread.Value = 'medium';
        hRadioOpen.Value = true; hRadioFolder.Value = false; hEditFolder.Value = ''; hEditFolder.Enable = 'off';
        hPopupFitColor.Value = '(no change)';
        hEditDataLW.Value = ''; hPopupDataStyle.Value = '(no change)';
        hEditMarkerSize.Value = ''; hEditFitLW.Value = ''; hPopupFitStyle.Value = '(no change)';
        % persist cleared state
        savePrefs();
    end

    function closeAndSave(~,~)
        % save current UI state, then close
        try
            savePrefs();
        catch
        end
        delete(fig);
    end

    % advanced toggle removed; advanced panel is always visible

    function trackLastFigure(~,~)
        % TRACKLASTFIGURE - Store reference to currently active figure
        % Safe string comparison and validation
        fig0 = get(0,'CurrentFigure');
        if isempty(fig0), return; end
        if ~isvalid(fig0), return; end
        
        % Safely check if figure name is in skip list
        fname = '';
        try
            fname = char(fig0.Name);  % Convert to char to support both string and char
        catch
            fname = '';
        end
        
        % Safe string matching
        for i = 1:numel(skipList)
            if strcmp(fname, skipList{i})
                return;  % Skip UI windows
            end
        end
        
        lastRealFigure = fig0;
    end

    function figs = findRealFigs()
        % FINDREALFIGS - Return array of valid user data figures
        % Filters out UI windows using safe string comparison
        if applyCurrentOnly
            if isempty(lastRealFigure)
                figs = [];
                return;
            end
            if ~isvalid(lastRealFigure)
                lastRealFigure = [];  % Clean up deleted handle
                figs = [];
                return;
            end
            figs = lastRealFigure;
            return;
        end
        
        % Find all figures and filter out UI windows
        allFigs = findall(0,'Type','figure');
        figs = [];
        
        for f = allFigs'
            if ~isvalid(f), continue; end
            
            % Get figure name safely
            fname = '';
            try
                fname = char(f.Name);
            catch
                fname = '';
            end
            
            % Check if figure should be skipped
            isSkipped = false;
            for i = 1:numel(skipList)
                if strcmp(fname, skipList{i})
                    isSkipped = true;
                    break;
                end
            end
            
            if ~isSkipped
                figs = [figs; f];
            end
        end
    end

    % ------------------ SMART helpers ported from legacy GUI --------------
    function tf = isMultiPanelFigure(fig)
        ax = findall(fig,'Type','axes');
        if isempty(ax), tf = false; return; end
        tags = get(ax,'Tag');
        if ischar(tags), tags = {tags}; end
        ax = ax(~strcmp(tags,'legend'));
        tf = numel(ax) > 1;
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

    function applyAxesSizeSingle(fig, w, h, topMargin, leftMargin)
        ax = findall(fig,'Type','axes');
        ax = ax(~strcmp(get(ax,'Tag'),'legend'));
        bottom = 1 - h - topMargin;
        if bottom < 0, bottom = 0; end
        for a = ax'
            a.Units = 'normalized';
            a.Position = [leftMargin, bottom, w, h];
        end
    end

    function applyAxesSizeMulti(fig, w, h, topMargin, leftMargin)
        ax = findall(fig,'Type','axes');
        ax = ax(~strcmp(get(ax,'Tag'),'legend'));
        % exclude colorbars
        ax = ax(~arrayfun(@isColorbarAxes, ax));
        if isempty(ax), return; end
        pos = vertcat(ax.Position);
        left0   = min(pos(:,1));
        bottom0 = min(pos(:,2));
        right0  = max(pos(:,1) + pos(:,3));
        top0    = max(pos(:,2) + pos(:,4));
        width0  = right0 - left0;
        height0 = top0   - bottom0;
        newLeft   = leftMargin;
        newTop    = 1 - topMargin;
        newWidth  = min(w, 1 - newLeft - 0.02);
        newHeight = min(h, newTop - 0.02);
        scaleX = newWidth  / width0;
        scaleY = newHeight / height0;
        for a = ax'
            p = a.Position;
            p(1) = newLeft + (p(1) - left0) * scaleX;
            p(2) = newTop  - (top0 - p(2) - p(4)) * scaleY - p(4)*scaleY;
            p(3) = p(3) * scaleX;
            p(4) = p(4) * scaleY;
            a.Units = 'normalized';
            a.Position = p;
        end
    end

    function applyFontSystem(fig, style)
        % AXES
        ax = findall(fig,'Type','axes');
        for a = ax'
            a.FontSize = style.tickFont;
            try
                if isprop(a,'TickLabelInterpreter'), a.TickLabelInterpreter = 'latex'; end
            catch
            end
            % labels and title: sanitize and set latex interpreter/font
            try
                if ~isempty(a.XLabel.String)
                    a.XLabel.String = sanitizeLatexString(a.XLabel.String);
                    a.XLabel.FontSize = style.labelFont;
                    if isprop(a.XLabel,'Interpreter'), a.XLabel.Interpreter = 'latex'; end
                    if isprop(a.XLabel,'FontName'), a.XLabel.FontName = 'latex'; end
                end
                if ~isempty(a.YLabel.String)
                    a.YLabel.String = sanitizeLatexString(a.YLabel.String);
                    a.YLabel.FontSize = style.labelFont;
                    if isprop(a.YLabel,'Interpreter'), a.YLabel.Interpreter = 'latex'; end
                    if isprop(a.YLabel,'FontName'), a.YLabel.FontName = 'latex'; end
                end
                if ~isempty(a.Title.String)
                    a.Title.String = sanitizeLatexString(a.Title.String);
                    a.Title.FontSize = style.titleFont;
                    if isprop(a.Title,'Interpreter'), a.Title.Interpreter = 'latex'; end
                    if isprop(a.Title,'FontName'), a.Title.FontName = 'latex'; end
                end
            catch
            end
        end
        % LEGENDS
        lg = findall(fig,'Type','legend');
        for L = lg'
            try
                if isprop(L,'FontUnits'), L.FontUnits = 'points'; end
                L.FontSize = style.legendFont;
                if isprop(L,'FontName'), L.FontName = 'latex'; end
                if isprop(L,'Interpreter'), L.Interpreter = 'latex'; end
                if isprop(L,'ItemTokenSize') && isfield(style,'itemTokenSize')
                    L.ItemTokenSize = style.itemTokenSize;
                end
                % sanitize legend strings
                if iscell(L.String)
                    for j = 1:numel(L.String)
                        L.String{j} = sanitizeLatexString(L.String{j});
                    end
                elseif ischar(L.String) || isstring(L.String)
                    L.String = sanitizeLatexString(L.String);
                end
            catch
            end
        end
        % TEXT
        tx = findall(fig,'Type','text');
        for t = tx'
            try
                t.FontSize = style.annFont;
                if isprop(t,'Interpreter'), t.Interpreter = 'latex'; end
                t.String = sanitizeLatexString(t.String);
            catch
            end
        end
        % TEXTBOX
        ann = findall(fig,'Type','textboxshape');
        for a = ann'
            try
                a.FontSize = style.annFont;
                if isprop(a,'Interpreter'), a.Interpreter = 'latex'; end
                a.String = sanitizeLatexString(a.String);
            catch
            end
        end
        % COLORBARS
        cb = findall(fig,'Type','colorbar');
        for c = cb'
            c.FontSize = style.tickFont;
            if ~isempty(c.Label.String)
                c.Label.String = sanitizeLatexString(c.Label.String);
                c.Label.FontSize = style.labelFont;
                if isprop(c.Label,'Interpreter'), c.Label.Interpreter = 'latex'; end
                if isprop(c.Label,'FontName'), c.Label.FontName = 'latex'; end
            end
        end
        % --- apply line widths and marker sizes to plotted objects ---
        try
            if isfield(style,'lineWidth') || isfield(style,'markerSize')
                % lines
                ln = findall(fig,'Type','line');
                for L = ln'
                    try
                        if isfield(style,'lineWidth') && isprop(L,'LineWidth'), L.LineWidth = style.lineWidth; end
                        if isfield(style,'markerSize') && isprop(L,'MarkerSize'), L.MarkerSize = style.markerSize; end
                    catch
                    end
                end
                % scatter objects
                sc = findall(fig,'Type','scatter');
                for S = sc'
                    try, if isprop(S,'SizeData'), S.SizeData = style.markerSize^2; end; catch, end
                end
                % errorbar objects
                eb = findall(fig,'Type','errorbar');
                for E = eb'
                    try
                        if isprop(E,'LineWidth'), E.LineWidth = style.lineWidth; end
                        if isprop(E,'MarkerSize'), E.MarkerSize = style.markerSize; end
                    catch
                    end
                end
                % patches and other drawable objects
                pch = findall(fig,'Type','patch');
                for P = pch'
                    try, if isprop(P,'LineWidth'), P.LineWidth = style.lineWidth; end; catch, end
                end
            end
        catch
        end
    end

    function style = getStyleFromPanelSize(panelW, ~)
        % defaults (fallback)
        style.tickFont   = 9; style.labelFont  = 11; style.titleFont  = 11;
        style.legendFont = 8; style.annFont    = 10;
        style.axWidth    = 0.76; style.axHeight   = 0.72;
        style.topMargin  = 0.08; style.leftMargin = 0.12;
        if abs(panelW - 2.33) < 0.1
            style.axWidth    = 0.76; style.axHeight   = 0.72;
            style.topMargin  = 0.08; style.leftMargin = 0.12;
        elseif abs(panelW - 3.5) < 0.2
            style.axWidth    = 0.80; style.axHeight   = 0.75;
            style.topMargin  = 0.06; style.leftMargin = 0.10;
        end
    end

    function setPopupValueByString(hPopup, targetStr)
        try
            opts = hPopup.Items;
            idx = find(strcmp(opts, targetStr), 1);
            if ~isempty(idx), hPopup.Value = opts(idx); end
        catch
        end
    end

    function out = sanitizeLatexString(in)
        % ported from legacy GUI: escape underscores, wrap math when needed
        if iscell(in)
            out = cell(size(in));
            for k = 1:numel(in)
                out{k} = sanitizeLatexString(in{k});
            end
            return;
        end
        if isstring(in), in = char(in); end
        in = strtrim(in);
        if isempty(in), out = in; return; end
        if isWrappedInMath(in), out = in; return; end
        in = strrep(in,'[',''); in = strrep(in,']','');
        in = strrep(in,'_','\\_');
        if contains(in,{'_','^','\','{'})
            out = ['$' in '$'];
        else
            out = in;
        end
    end

    %% ===== APPEARANCE / COLORMAP HELPER FUNCTIONS =====
    
    function applyColormapToFigures(mapName, folder, spreadMode, ...
        fitColor, dataWidth, dataStyle, fitWidth, fitStyle, ...
        reverseOrder, reverseLegend, noMapChange, markerSize)
        
        % APPLYCOLORMAPTOFIGURES - Apply colormap and styling to figures
        % Respects applyCurrentOnly flag
        
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
        
        % Generate colormap
        if noMapChange
            cmapFull = [];  % signal: don't change colormap
        else
            cmapFull = getColormapToUse(mapName);
        end
        
        % Apply to figures (respecting applyCurrentOnly)
        if isempty(folder)
            if applyCurrentOnly && ~isempty(lastRealFigure)
                figList = lastRealFigure;
            else
                figList = findRealFigs();
                if iscell(figList), figList = [figList{:}]; else, figList = figList(:); end
            end
            
            for fig = figList'
                applyToSingleFigure(fig, cmapFull, spreadMode, ...
                    fitColor, dataWidth, dataStyle, fitWidth, fitStyle, ...
                    reverseOrder, reverseLegend, markerSize);
            end
        else
            % Apply to .fig files in folder
            files = dir(fullfile(folder,'*.fig'));
            for k = 1:numel(files)
                f = openfig(fullfile(folder,files(k).name),'invisible');
                applyToSingleFigure(f, cmapFull, spreadMode, ...
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
        
        axList = findall(fig,'Type','axes');
        fitRGB = name2rgb(fitColor);
        
        %% 1) COLORING + COLORMAP
        if ~isempty(cmapFull)
            M = size(cmapFull,1);
        end
        
        for ax = axList'
            % ----- colormap -----
            if ~isempty(cmapFull)
                idx = getSliceIndices(M, spreadMode);
                cmapSlice = cmapFull(idx,:);
                colormap(ax, cmapSlice);
            end
            
            % ----- lines -----
            allLines = findall(ax,'Type','line');
            if isempty(allLines), continue; end
            
            names = get(allLines,'DisplayName');
            if ischar(names), names = {names}; end
            
            isData = ~cellfun(@isempty,names);
            dataLines = allLines(isData);
            fitLines = allLines(~isData);
            
            % DATA lines
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
                % change width/style only
                for k = 1:numel(dataLines)
                    if ~isempty(dataWidth), dataLines(k).LineWidth = dataWidth; end
                    if ~isempty(dataStyle), dataLines(k).LineStyle = dataStyle; end
                end
            end
            
            % FIT lines
            for k = 1:numel(fitLines)
                if ~isempty(markerSize), fitLines(k).MarkerSize = markerSize; end
                if ~isempty(fitColor)
                    fitLines(k).Color = fitRGB;
                end
                if ~isempty(fitWidth), fitLines(k).LineWidth = fitWidth; end
                if ~isempty(fitStyle), fitLines(k).LineStyle = fitStyle; end
            end
            
            % COLORBARS
            cbList = findall(fig,'Type','colorbar','Axes',ax);
            for cb = cbList'
                if ~isempty(cmapFull)
                    colormap(cb, flipud(cmapSlice));
                end
                set(cb,'Direction','normal');
            end
        end
        
        %% 2) Reverse PLOT order
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
        
        %% 3) Reverse LEGEND order
        if reverseLegend
            for ax = axList'
                hLeg = findobj(ax.Parent,'Type','legend','-and','Parent',ax.Parent);
                if isempty(hLeg), continue; end
                
                % Store all legend properties before deletion
                oldPos = hLeg.Position;
                oldFontSize = hLeg.FontSize;
                oldFontWeight = hLeg.FontWeight;
                oldFontName = hLeg.FontName;
                oldInterpreter = hLeg.Interpreter;
                oldLocation = hLeg.Location;
                oldOrientation = hLeg.Orientation;
                oldBox = hLeg.Box;
                oldEdgeColor = hLeg.EdgeColor;
                oldFaceColor = hLeg.FaceColor;
                oldFaceAlpha = hLeg.FaceAlpha;
                
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
                
                % Create new legend with reversed data
                newLeg = legend(ax, dataLines, dataNames);
                newLeg.AutoUpdate = 'off';
                
                % Restore all preserved properties
                try
                    newLeg.Position = oldPos;
                    newLeg.FontSize = oldFontSize;
                    newLeg.FontWeight = oldFontWeight;
                    newLeg.FontName = oldFontName;
                    newLeg.Interpreter = oldInterpreter;
                    newLeg.Location = oldLocation;
                    newLeg.Orientation = oldOrientation;
                    newLeg.Box = oldBox;
                    newLeg.EdgeColor = oldEdgeColor;
                    newLeg.FaceColor = oldFaceColor;
                    newLeg.FaceAlpha = oldFaceAlpha;
                catch ME
                    % Legacy figure - some properties may not be available
                    warning('Could not restore all legend properties: %s', ME.message);
                end
            end
        end
    end
    
    function cmap = getColormapToUse(mapName)
        % GETCOLORMAPTOUSE - Safely retrieve colormap by name
        % NO eval() - uses safe dispatch only
        % Validates all outputs for correctness
        
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
        
        try
            % Check custom colormaps first
            if any(strcmpi(mapName, custom))
                cmap = makeCustomColormap(mapName);
            % Check cmocean specially (SAFE DISPATCH - no eval)
            elseif contains(lower(mapName),'cmocean')
                cmap = getCmoceanColormap(mapName);
            % Check ScientificColourMaps8
            elseif ~isempty(scm8Maps) && any(strcmp(mapName, scm8Maps))
                cmap = feval(mapName, 256);
            % Check built-in MATLAB colormaps
            elseif exist(mapName,'builtin')
                cmap = feval(mapName, 256);
            % Check if function exists in path
            elseif exist(mapName,'file')
                cmap = feval(mapName, 256);
            else
                error('Unknown colormap name "%s".', mapName);
            end
        catch ME
            error('Invalid colormap: %s', ME.message);
        end
        
        % VALIDATE OUTPUT FORMAT
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
    end
    
    function cmap = getCmoceanColormap(mapName)
        % GETCMOCEANCOLORMAP - Safe dispatch for cmocean colormaps
        % Avoids eval() - validates input format first
        
        % Extract colormap name from string like "cmocean('thermal')"
        match = regexp(mapName, "cmocean\('([^']*)'\)", 'tokens');
        if isempty(match)
            error('Invalid cmocean format: %s', mapName);
        end
        
        cmName = match{1}{1};
        
        % Whitelist of known cmocean maps
        validMaps = {'thermal','haline','solar','matter','turbid','speed',...
            'amp','deep','dense','algae','balance','curl','delta','oxy',...
            'phase','rain','ice','gray'};
        
        if ~any(strcmp(cmName, validMaps))
            error('Unknown cmocean colormap: %s', cmName);
        end
        
        % Safe dispatch using feval
        try
            cmap = cmocean(cmName);
        catch ME
            error('cmocean function failed: %s', ME.message);
        end
    end
    
    function idx = getSliceIndices(M, mode)
        % GETSLICEINDICES - Flexible colormap slicing with spread modes
        % BOUNDS-SAFE: All returned indices guaranteed in [1, M]
        
        if M < 2, M = 2; end  % Minimum viable colormap size
        
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
                lo = min(lo, hi);  % Ensure lo <= hi
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
        
        % FINAL SAFETY CHECK: Verify all indices are within bounds
        idx = idx(idx >= 1 & idx <= M);
        if isempty(idx)
            idx = round(M/2);  % Fallback to middle
        end
    end
    
    function rgb = name2rgb(c)
        % NAME2RGB - Convert color name to RGB vector
        
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
        % MAKECUSTOMCOLORMAP - Generate custom color maps
        
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
                C = flipud(makeCustomColormap('bluewhitered'));
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
