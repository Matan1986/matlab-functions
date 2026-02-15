function FinalFigureFormatterUI()

baseFolder = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions'; % Work PC
addpath(genpath(baseFolder));

%% ================== CONSTANTS ==================
singleColWidth  = 3.375;   % inch (APS / PRL)
doubleColWidth  = 7.0;
panelAspect     = 0.75;

% preference group for storing UI state between runs
prefGroup = 'FinalFigureFormatterUI_Prefs';

skipList = ["CtrlGUI","Final Figure Formatter","FigureTools","refLineGUI","All Available Colormaps"];
lastRealFigure = [];
applyCurrentOnly = false;
currentFigureListener = [];
layoutPresetPath = '';

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

currentFigureListener = addlistener(0,'CurrentFigure','PostSet',@trackLastFigure);

%% ================== SAVE & EXPORT (compact) =================
pSave = uipanel(gl,'Title','Save & Export');
pSave.Layout.Row = 1;

gSave = uigridlayout(pSave,[4 3]);
gSave.RowHeight = {'fit','fit','fit','fit','fit'};
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

% PDF export mode
lblPdfMode = uilabel(gSave,'Text','PDF mode:','FontWeight','bold','HorizontalAlignment','right');
lblPdfMode.Layout.Row = 4; lblPdfMode.Layout.Column = 1;
hPdfMode = uidropdown(gSave, ...
    'Items', {'Vector (Recommended)','WYSIWYG (Match FIG)'}, ...
    'Value', 'Vector (Recommended)');
hPdfMode.Layout.Row = 4; hPdfMode.Layout.Column = [2 3];

% One-click preset workflow
lblPreset = uilabel(gSave,'Text','Preset:','FontWeight','bold','HorizontalAlignment','right');
lblPreset.Layout.Row = 5; lblPreset.Layout.Column = 1;
btnLoadLayoutPreset = uibutton(gSave,'Text','Load Preset...','ButtonPushedFcn',@loadLayoutPreset);
btnLoadLayoutPreset.Layout.Row = 5; btnLoadLayoutPreset.Layout.Column = [2 3];

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
pAx = uipanel(gl,'Title','Axes Geometry (Advanced)');
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
pSmart = uipanel(gl,'Title','SMART Layout (Primary)');
pSmart.Layout.Row = 4;

gSmart = uigridlayout(pSmart,[4 4]);
gSmart.RowHeight = {'fit','fit','fit','fit'}; 
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

% Row 3: style mode
lblStyleMode = uilabel(gSmart,'Text','Style mode'); lblStyleMode.Layout.Row = 3; lblStyleMode.Layout.Column = 1;
hStyleMode = uidropdown(gSmart,'Items',{'PRL','Nature','Compact','Presentation'},'Value','PRL');
hStyleMode.Layout.Row = 3; hStyleMode.Layout.Column = 2;

% Row 4: apply button
btnSmart = uibutton(gSmart,'Text','Apply SMART','ButtonPushedFcn',@applySmartLayout); btnSmart.Layout.Row = 4; btnSmart.Layout.Column = [1 4];

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
        testMapData = feval(testMaps{t}, 2);  % Quick test with output to avoid side effects
        if isnumeric(testMapData) && ismatrix(testMapData) && size(testMapData,2) == 3
            builtinMaps{end+1} = testMaps{t};
        end
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
    cmoTest = cmocean('thermal');  % Test with output to avoid gca/figure side effects
    if ~isnumeric(cmoTest) || size(cmoTest,2) ~= 3
        cmoMaps = {};
    end
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
hChkNoMapChange = uicheckbox(gApp,'Text','No map change','FontSize',9);
hChkNoMapChange.Layout.Row = 5; hChkNoMapChange.Layout.Column = 6;
hChkNoMapChange.Value = false;

% Row 6: Apply button + Show All Colormaps button
btnAppearance = uibutton(gApp,'Text','Apply Appearance','ButtonPushedFcn',@applyAppearanceSettings);
btnAppearance.Layout.Row = 6; btnAppearance.Layout.Column = [1 4];
btnShowAllMaps = uibutton(gApp,'Text','Show All Maps','ButtonPushedFcn',@showAllColormapsPreviews);
btnShowAllMaps.Layout.Row = 6; btnShowAllMaps.Layout.Column = [5 6];

%% ================== TYPOGRAPHY =================
pTypo = uipanel(gl,'Title','Typography');
pTypo.Layout.Row = 6;

gTypo = uigridlayout(pTypo,[3 8]);
gTypo.RowHeight = {'fit','fit','fit'};
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

% Row 2: Alignment buttons
posGrid = uigridlayout(gTypo,[1 4]); posGrid.Layout.Row = 2; posGrid.Layout.Column = [1 8];
posGrid.ColumnWidth = {'1x','1x','1x','1x'}; posGrid.Padding = [2 2 2 2];
uibutton(posGrid,'Text','↗','ButtonPushedFcn',@(~,~) moveLegend('northeast'));
uibutton(posGrid,'Text','↖','ButtonPushedFcn',@(~,~) moveLegend('northwest'));
uibutton(posGrid,'Text','↙','ButtonPushedFcn',@(~,~) moveLegend('southwest'));
uibutton(posGrid,'Text','↘','ButtonPushedFcn',@(~,~) moveLegend('southeast'));

% Row 3: Best/Out buttons
posGrid2 = uigridlayout(gTypo,[1 2]); posGrid2.Layout.Row = 3; posGrid2.Layout.Column = [1 8];
posGrid2.ColumnWidth = {'1x','1x'}; posGrid2.Padding = [2 2 2 2];
uibutton(posGrid2,'Text','Best','ButtonPushedFcn',@(~,~) moveLegend('best'));
uibutton(posGrid2,'Text','Out','ButtonPushedFcn',@(~,~) moveLegend('northeastoutside'));

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
btnRoundTripTest = uibutton(gAdvanced,'Text','Test Round-Trip','ButtonPushedFcn',@testUiRoundTrip);
btnRoundTripTest.Layout.Row = 2; btnRoundTripTest.Layout.Column = [4 6];

% Assign deterministic tags to value-bearing controls for JSON round-trip restore
assignControlTags();

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
        figs = findRealFigs();
        if isempty(figs), return; end
        style = buildStyleFromCurrentUI();
        style.applyPreviewResize = false;
        applyStyleToFigures(figs, style);
    end

    function applyFigureSize(~,~)
        figs = findRealFigs();
        if isempty(figs), return; end
        style = buildStyleFromCurrentUI();
        style.applyPreviewResize = true;
        style.previewScale = 1.0;
        applyStyleToFigures(figs, style);
    end

    function applyFontSize(~,~)
        figs = findRealFigs();
        if isempty(figs), return; end
        style = buildStyleFromCurrentUI();
        style.applyPreviewResize = false;
        applyStyleToFigures(figs, style);
    end

    function applyLegendFontSize(~,~)
        figs = findRealFigs();
        if isempty(figs), return; end
        legendFs = str2double(hLegendFontSize.Value);
        if ~isfinite(legendFs) || legendFs <= 0
            errordlg('Legend font size must be a positive number','Legend Font Size');
            return;
        end
        for k = 1:numel(figs)
            try
                SmartFigureEngine.applyLegendAnnotationFontOnly(figs(k), legendFs);
            catch ME
                warning('Legend/annotation font apply failed on figure %d: %s', k, ME.message);
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

        style = SmartFigureEngine.computeSmartStyle(panelWidth, panelHeight, nx, ny, hStyleMode.Value);
        style.applyPreviewResize = true;
        style.previewScale = 3.0;
        style.dpi = 96;

        hTopMargin.Value  = style.topMargin;
        hLeftMargin.Value = style.leftMargin;
        hFigWidth.Value   = round(panelWidth * style.dpi);
        hFigHeight.Value  = round(panelHeight * style.dpi);
        hAxWidth.Value    = style.axWidth;
        hAxHeight.Value   = style.axHeight;

        setPopupValueByString(hFontSize,       num2str(style.tickFont));
        setPopupValueByString(hLegendFontSize, num2str(style.legendFont));

        applyStyleToFigures(figs, style);

        fprintf('✔ SMART: nx=%d | Panel = %.2f x %.2f inch\n', nx, panelWidth, panelHeight);
    end

    function style = buildStyleFromCurrentUI()
        panelWidth = max(1.0, hFigWidth.Value/96);
        panelHeight = max(1.0, hFigHeight.Value/96);
        nx = max(1, round(hPanelsX.Value));
        ny = max(1, round(hPanelsY.Value));
        style = SmartFigureEngine.computeSmartStyle(panelWidth, panelHeight, nx, ny, hStyleMode.Value);

        style.axWidth = hAxWidth.Value;
        style.axHeight = hAxHeight.Value;
        style.topMargin = hTopMargin.Value;
        style.leftMargin = hLeftMargin.Value;

        fs = str2double(hFontSize.Value);
        lfs = str2double(hLegendFontSize.Value);
        style = SmartFigureEngine.applyUiOverrides(style, fs, lfs);
        style.applyPreviewResize = false;
    end

    function applyStyleToFigures(figs, style)
        if applyCurrentOnly
            figs = findRealFigs();
        end
        figs = figs(:);
        for k = 1:numel(figs)
            fig0 = figs(k);
            try
                SmartFigureEngine.applyFullSmart(fig0, style);
            catch ME
                warning('Smart apply failed on figure %d: %s', k, ME.message);
            end
        end
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
        mapName = hPopupMap.Value;
        spreadMode = hPopupSpread.Value;
        useFolder = logical(hRadioFolder.Value);
        folderName = strtrim(hEditFolder.Value);
        targetFigs = [];

        if useFolder
            if isempty(folderName) || ~isfolder(folderName)
                errordlg('Invalid folder path','Appearance Error');
                return;
            end
        else
            if applyCurrentOnly && ~isempty(lastRealFigure) && isvalid(lastRealFigure)
                targetFigs = lastRealFigure;
            else
                targetFigs = findRealFigs();
            end
        end

        try
            appearanceStyle = SmartFigureEngine.buildAppearanceStyleFromUI( ...
                mapName, spreadMode, useFolder, folderName, ...
                hPopupFitColor.Value, hEditDataLW.Value, hPopupDataStyle.Value, ...
                hEditMarkerSize.Value, hEditFitLW.Value, hPopupFitStyle.Value, ...
                logical(hChkReverseOrder.Value), logical(hChkReverseLegend.Value), ...
                logical(hChkNoMapChange.Value), targetFigs, scm8Maps);
            SmartFigureEngine.applyAppearanceToTargets(appearanceStyle);
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
                    if isvalid(k)
                        delete(k);
                    end
                catch ME
                    fprintf('[INFO] Preview cleanup skipped: %s\n', ME.message);
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
        if nMaps < 1
            fprintf('[PREVIEW] No colormaps available to preview.\n');
            return;
        end
        
        % Calculate tile dimensions for optimal layout
        % Aim for narrow strips stacked vertically
        nCols = 1;  % Single column of colormaps
        nRows = nMaps;
        
        % Create new figure with tiledlayout
        % CRITICAL: Hide figure during construction to prevent blank canvas flashing
        fig = figure('Name','All Available Colormaps','Visible','off','NumberTitle','off',...
            'Position',[100 100 1400 min(max(25*nRows, 600), 1200)]);  % Hide until fully populated
        
        % CRITICAL: Pass figure handle explicitly to tiledlayout to prevent
        % tiledlayout() from creating a separate blank figure when main UI is uifigure
        tl = tiledlayout(fig, nRows, 1, 'Padding','compact','TileSpacing','tight');
        
        loadedCount = 0;
        failedMaps = {};
        
        for k = 1:nMaps
            mapName = mapNames{k};
            
            try
                % Get colormap with error handling
                cmap = SmartFigureEngine.getColormapForPreview(mapName, scm8Maps);
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
                msg = ME.message;
                msg = msg(1:min(30, numel(msg)));
                failedMaps{end+1} = [mapName ' (error: ' msg ')'];
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
        if isvalid(fig)
            fig.Visible = 'on';
        end
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

        figsToSave = findRealFigs();
        figsToSave = figsToSave(:);
        if isempty(figsToSave)
            warning('FinalFigureFormatterUI:NoFiguresToSave','No valid target figures found for export.');
            return;
        end

        % WYSIWYG rule: export must be passive (no export-time reformat/reflow)

        pdfMode = getPdfExportMode();
        validFigsForMetadata = gobjects(0);
        anyPdfSaved = false;

        for k = 1:numel(figsToSave)
            fig0 = figsToSave(k);
            if ~isvalid(fig0) || ~isscalar(fig0) || ~isgraphics(fig0,'figure')
                warning('FinalFigureFormatterUI:InvalidFigureHandle','Skipping invalid figure target at index %d.', k);
                continue;
            end
            validFigsForMetadata(end+1,1) = fig0; %#ok<AGROW>
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
                    pdfSaved = false;
                    if strcmp(pdfMode,'wysiwyg')
                        try
                            exportgraphics(fig0, outPath, 'ContentType','image', 'Resolution', 600, 'BackgroundColor', 'current');
                            pdfSaved = true;
                        catch ME
                            warning('FinalFigureFormatterUI:PdfExportFailed', ...
                                'Failed to save PDF with passive exportgraphics (%s): %s', outPath, ME.message);
                        end
                    else
                        try
                            exportgraphics(fig0, outPath, 'ContentType','vector', 'BackgroundColor', 'current');
                            pdfSaved = true;
                        catch ME
                            warning('FinalFigureFormatterUI:PdfExportFailed', ...
                                'Failed to save PDF with passive exportgraphics (%s): %s', outPath, ME.message);
                        end
                    end
                    anyPdfSaved = anyPdfSaved || pdfSaved;

                otherwise
                    error('Unknown save mode: %s',mode);
            end
        end

        if strcmpi(mode,'pdf') && anyPdfSaved
            jsonName = ['save_layout_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '.json'];
            jsonPath = ensureFreeFilename(fullfile(saveFolder, jsonName), overwrite);
            [metaOk, metaMsg] = saveLayoutMetadataJson(jsonPath, validFigsForMetadata, mode, pdfMode);
            if ~metaOk
                fprintf('[INFO] Layout metadata save note (%s): %s\n', jsonPath, metaMsg);
            end
        end

          % persist UI state after a save operation
          savePrefs();
    end

    function prepareFigureForWysiwygExport(fig)
        %#ok<INUSD>
        % Passive export policy: do not mutate figure properties at save time.
    end

    function prepareFigureForVectorExport(fig)
        %#ok<INUSD>
        % Passive export policy: do not mutate figure properties at save time.
    end

    function mode = getPdfExportMode()
        mode = 'vector';
        try
            if strcmpi(hPdfMode.Value, 'WYSIWYG (Match FIG)')
                mode = 'wysiwyg';
            end
        catch
        end
    end

    function [ok, msg] = saveLayoutMetadataJson(jsonPath, figHandles, exportMode, pdfMode)
        ok = true;
        msg = '';
        buildError = "";
        try
            meta = buildLayoutMetadata(figHandles, exportMode, pdfMode);
        catch ME
            meta = struct();
            meta.schemaVersion = 'ui-snapshot-v1';
            meta.savedAt = string(datetime('now','TimeZone','local','Format','yyyy-MM-dd''T''HH:mm:ss.SSSZZZZZ'));
            meta.generator = 'FinalFigureFormatterUI';
            meta.export = struct('mode', string(exportMode), 'pdfMode', string(pdfMode));
            meta.uiState = struct();
            buildError = string(ME.message);
            ok = false;
            msg = char(buildError);
        end

        if strlength(buildError) > 0
            meta.error = buildError;
            meta.errorStage = 'buildLayoutMetadata';
        end

        try
            raw = jsonencode(meta, 'PrettyPrint', true);
        catch MEpp
            try
                raw = jsonencode(meta);
            catch MEraw
                raw = jsonencode(struct( ...
                    'schemaVersion','ui-snapshot-v1', ...
                    'savedAt',string(datetime('now','TimeZone','local','Format','yyyy-MM-dd''T''HH:mm:ss.SSSZZZZZ')), ...
                    'generator','FinalFigureFormatterUI', ...
                    'export',struct('mode', string(exportMode), 'pdfMode', string(pdfMode)), ...
                    'uiState',struct(), ...
                    'error',string(MEraw.message), ...
                    'errorStage','jsonencode', ...
                    'jsonencodePrettyError',string(MEpp.message)));
                ok = false;
                if isempty(msg), msg = MEraw.message; end
            end
        end

        fid = fopen(jsonPath, 'w');
        if fid < 0
            ok = false;
            msg = sprintf('Could not open metadata file for writing: %s', jsonPath);
            return;
        end
        c = onCleanup(@() fclose(fid)); %#ok<NASGU>
        try
            fwrite(fid, raw, 'char');
        catch ME
            ok = false;
            if isempty(msg), msg = ME.message; end
        end
    end

    function meta = buildLayoutMetadata(figHandles, exportMode, pdfMode)
        %#ok<INUSD>
        try
            styleNow = buildStyleFromCurrentUI();
        catch
            styleNow = struct();
        end
        try
            defaults = SmartFigureEngine.computeSmartStyle( ...
                max(1.0, hFigWidth.Value/96), max(1.0, hFigHeight.Value/96), ...
                max(1, round(hPanelsX.Value)), max(1, round(hPanelsY.Value)), hStyleMode.Value);
        catch
            defaults = struct();
        end

        meta = struct();
        meta.schemaVersion = 'ui-snapshot-v1';
        meta.savedAt = string(datetime('now','TimeZone','local','Format','yyyy-MM-dd''T''HH:mm:ss.SSSZZZZZ'));
        meta.generator = 'FinalFigureFormatterUI';
        meta.export = struct('mode', string(exportMode), 'pdfMode', string(pdfMode));

        try
            meta.uiKnown = collectKnownUiState();
        catch
            meta.uiKnown = struct();
        end
        try
            meta.uiControls = captureUiControlsRaw();
        catch
            meta.uiControls = struct('type',{},'tag',{},'label',{},'value',{},'items',{},'enabled',{});
        end
        meta.uiState = meta.uiKnown;
        meta.uiControlsSnapshot = meta.uiControls;

        % Keep only UI snapshot fields required for reproducibility
        try, meta.uiState.nx = double(hPanelsX.Value); catch, meta.uiState.nx = NaN; end
        try, meta.uiState.ny = double(hPanelsY.Value); catch, meta.uiState.ny = NaN; end
        try, meta.uiState.styleMode = string(hStyleMode.Value); catch, end
        try, meta.uiState.fontSize = string(hFontSize.Value); catch, end
        try, meta.uiState.legendFontSize = string(hLegendFontSize.Value); catch, end
        try, meta.uiState.applyCurrentOnly = logical(applyCurrentOnly); catch, end
        try, meta.uiState.exportMode = string(exportMode); catch, end
        try, meta.uiState.pdfMode = string(pdfMode); catch, end
        try, meta.uiState.SAFE_MODE = logical(getNumericField(styleNow, 'safeMode', getNumericField(defaults, 'safeMode', 1)) ~= 0); catch, end

        % Intentionally UI-snapshot only: no figure/axes/legend/object serialization
    end

    function [layoutBlock, typographyBlock, optionsBlock] = buildLayoutRecipeBlocks(figInfoList, styleNow, defaults)
        axesPerFigure = zeros(1, numel(figInfoList));
        totalAxes = 0;
        for i = 1:numel(figInfoList)
            try
                axesPerFigure(i) = numel(figInfoList(i).axes);
            catch
                axesPerFigure(i) = 0;
            end
            totalAxes = totalAxes + axesPerFigure(i);
        end

        nx = getNumericField(styleNow, 'nx', getNumericField(defaults, 'nx', 1));
        ny = getNumericField(styleNow, 'ny', getNumericField(defaults, 'ny', 1));

        margins = struct( ...
            'left', getNumericField(styleNow, 'leftMargin', getNumericField(defaults, 'leftMargin', NaN)), ...
            'right', getNumericField(styleNow, 'rightMargin', getNumericField(defaults, 'rightMargin', NaN)), ...
            'top', getNumericField(styleNow, 'topMargin', getNumericField(defaults, 'topMargin', NaN)), ...
            'bottom', getNumericField(styleNow, 'bottomMargin', getNumericField(defaults, 'bottomMargin', NaN)));

        panelSizes = struct( ...
            'panelWidth', getNumericField(styleNow, 'panelWidth', getNumericField(defaults, 'panelWidth', NaN)), ...
            'panelHeight', getNumericField(styleNow, 'panelHeight', getNumericField(defaults, 'panelHeight', NaN)), ...
            'axWidth', getNumericField(styleNow, 'axWidth', getNumericField(defaults, 'axWidth', NaN)), ...
            'axHeight', getNumericField(styleNow, 'axHeight', getNumericField(defaults, 'axHeight', NaN)));

        layoutBlock = struct();
        layoutBlock.figureCount = numel(figInfoList);
        layoutBlock.axesPerFigure = axesPerFigure;
        layoutBlock.totalAxesCount = totalAxes;
        layoutBlock.margins = margins;
        layoutBlock.panelSizes = panelSizes;
        layoutBlock.nx = nx;
        layoutBlock.ny = ny;

        typographyBlock = struct();
        typographyBlock.baseFont = getNumericField(styleNow, 'tickFont', getNumericField(defaults, 'tickFont', NaN));
        typographyBlock.legendFontSize = getNumericField(styleNow, 'legendFont', getNumericField(defaults, 'legendFont', NaN));
        typographyBlock.labelFontSize = getNumericField(styleNow, 'labelFont', getNumericField(defaults, 'labelFont', NaN));
        typographyBlock.titleFontSize = getNumericField(styleNow, 'titleFont', getNumericField(defaults, 'titleFont', NaN));
        typographyBlock.annotationFontSize = getNumericField(styleNow, 'annotationFont', getNumericField(defaults, 'annotationFont', NaN));

        optionsBlock = struct();
        optionsBlock.smartCentering = logical(getNumericField(styleNow, 'safeMode', getNumericField(defaults, 'safeMode', 1)) ~= 0);
        optionsBlock.SAFE_MODE = logical(getNumericField(styleNow, 'safeMode', getNumericField(defaults, 'safeMode', 1)) ~= 0);
        optionsBlock.applyCurrentOnly = logical(applyCurrentOnly);
        optionsBlock.mode = string(getStringField(styleNow, 'mode', getStringField(defaults, 'mode', char(hStyleMode.Value))));
        optionsBlock.geometryMode = string(getStringField(styleNow, 'geometryMode', getStringField(defaults, 'geometryMode', 'deterministic-grid')));
    end

    function legendState = collectLegendStateAllFigures(figHandles, styleNow)
        legendState = struct('figureLegendState',{},'builtInLegendCount',{},'manualLegendCount',{},'legendFont',{});
        totalBuiltIn = 0;
        totalManual = 0;

        if isempty(figHandles)
            legendState = struct('figureLegendState',struct([]), ...
                'builtInLegendCount',0,'manualLegendCount',0, ...
                'legendFont',getNumericField(styleNow,'legendFont',NaN));
            return;
        end

        oneTemplate = getFigureLegendStateTemplate();
        perFig = repmat(oneTemplate, 0, 1);
        idx = 0;
        for i = 1:numel(figHandles)
            f = figHandles(i);
            try
                if isempty(f) || ~isvalid(f) || ~isgraphics(f,'figure')
                    continue;
                end
            catch
                continue;
            end

            idx = idx + 1;
            one = collectLegendStateForFigure(f);
            perFig(idx) = one;
            totalBuiltIn = totalBuiltIn + one.builtInLegendCount;
            totalManual = totalManual + one.manualLegendCount;
        end

        legendState = struct();
        legendState.figureLegendState = perFig;
        legendState.builtInLegendCount = totalBuiltIn;
        legendState.manualLegendCount = totalManual;
        legendState.legendFont = getNumericField(styleNow,'legendFont',NaN);
    end

    function one = collectLegendStateForFigure(f)
        one = getFigureLegendStateTemplate();

        try, one.figureName = string(f.Name); catch, end
        try, one.figureNumber = double(f.Number); catch, end

        builtInItemTemplate = getBuiltInLegendTemplate();
        builtIn = repmat(builtInItemTemplate, 0, 1);
        try
            lg = findall(f,'Type','legend');
        catch
            lg = gobjects(0);
        end
        for i = 1:numel(lg)
            L = lg(i);
            item = builtInItemTemplate;
            item.exists = true;
            try, item.location = string(L.Location); catch, end
            try, if isprop(L,'Position'), item.position = double(L.Position); end, catch, end
            try, if isprop(L,'FontSize'), item.fontSize = double(L.FontSize); end, catch, end
            try, if isprop(L,'NumColumns'), item.numColumns = double(L.NumColumns); end, catch, end
            builtIn(end+1) = item; %#ok<AGROW>
        end

        manualItemTemplate = getManualLegendEntryTemplate();
        manual = repmat(manualItemTemplate, 0, 1);

        try
            txb = findall(f,'Type','textboxshape');
        catch
            txb = gobjects(0);
        end
        for i = 1:numel(txb)
            t = txb(i);
            m = manualItemTemplate;
            m.type = "textboxshape";
            try, if isprop(t,'Tag'), m.tag = string(t.Tag); end, catch, end
            try, if isprop(t,'Position'), m.position = double(t.Position); end, catch, end
            try, if isprop(t,'FontSize'), m.fontSize = double(t.FontSize); end, catch, end
            manual(end+1) = m; %#ok<AGROW>
        end

        try
            tx = findall(f,'Type','text');
        catch
            tx = gobjects(0);
        end
        for i = 1:numel(tx)
            t = tx(i);
            include = false;
            tagVal = "";
            parentIsAxes = false;
            try, tagVal = lower(string(t.Tag)); catch, end
            try, parentIsAxes = isa(t.Parent, 'matlab.graphics.axis.Axes'); catch, end
            if contains(tagVal,'legend') || ~parentIsAxes
                include = true;
            end
            if ~include
                continue;
            end

            m = manualItemTemplate;
            m.type = "text";
            try, if isprop(t,'Tag'), m.tag = string(t.Tag); end, catch, end
            try, if isprop(t,'Position'), m.position = double(t.Position); end, catch, end
            try, if isprop(t,'FontSize'), m.fontSize = double(t.FontSize); end, catch, end
            manual(end+1) = m; %#ok<AGROW>
        end

        one.builtInLegends = builtIn;
        one.manualLegends = manual;
        one.manualLegendAxes = collectManualLegendAxesForFigure(f);
        one.builtInLegendCount = numel(builtIn);
        one.manualLegendCount = numel(manual) + numel(one.manualLegendAxes);
    end

    function manualAxes = collectManualLegendAxesForFigure(f)
        manualAxesTemplate = getManualLegendAxesTemplate();
        manualAxes = repmat(manualAxesTemplate, 0, 1);
        try
            allAxes = findall(f,'Type','axes');
        catch
            allAxes = gobjects(0);
        end
        idx = 0;
        for i = 1:numel(allAxes)
            a = allAxes(i);
            try
                if ~isManualLegendAxes(a)
                    continue;
                end
            catch
                continue;
            end
            idx = idx + 1;
            manualAxes(idx) = manualAxesTemplate;
            try, if isprop(a,'Tag'), manualAxes(idx).tag = string(a.Tag); end, catch, end
            try, if isprop(a,'Position'), manualAxes(idx).position = double(a.Position); end, catch, end
            try, if isprop(a,'OuterPosition'), manualAxes(idx).outerPosition = double(a.OuterPosition); end, catch, end
            try, if isprop(a,'Visible'), manualAxes(idx).visible = string(a.Visible); end, catch, end
        end
    end

    function val = getNumericField(s, fieldName, defaultVal)
        val = defaultVal;
        try
            if isstruct(s) && isfield(s,fieldName)
                candidate = s.(fieldName);
                if isnumeric(candidate) || islogical(candidate)
                    if ~isempty(candidate)
                        val = double(candidate(1));
                    end
                end
            end
        catch
        end
    end

    function val = getStringField(s, fieldName, defaultVal)
        val = defaultVal;
        try
            if isstruct(s) && isfield(s,fieldName)
                candidate = s.(fieldName);
                val = char(string(candidate));
            end
        catch
        end
    end

    function figInfoList = collectFigureAxesMetadata(figHandles)
        figTemplate = getFigureMetadataTemplate();
        figInfoList = repmat(figTemplate, 0, 1);
        if isempty(figHandles)
            return;
        end

        idx = 0;
        for i = 1:numel(figHandles)
            f = figHandles(i);
            try
                if isempty(f) || ~isvalid(f) || ~isgraphics(f,'figure')
                    continue;
                end
            catch
                continue;
            end

            idx = idx + 1;
            figInfoList(idx) = figTemplate;

            try, figInfoList(idx).name = string(f.Name); catch, end
            try, figInfoList(idx).number = double(f.Number); catch, end
            try, figInfoList(idx).position = double(f.Position); catch, end

            try
                ax = SmartFigureEngine.getDataAxes(f);
            catch
                ax = gobjects(0);
            end

            axIdx = 0;
            for j = 1:numel(ax)
                a = ax(j);
                try
                    if isempty(a) || ~isvalid(a)
                        continue;
                    end
                    if ~(isgraphics(a,'axes') || isgraphics(a,'uiaxes'))
                        continue;
                    end
                    if isManualLegendAxes(a)
                        continue;
                    end
                catch
                    continue;
                end

                axIdx = axIdx + 1;
                axInfo = getAxisMetadataTemplate();

                try, if isprop(a,'Tag'), axInfo.tag = string(a.Tag); end, catch, end
                try, if isprop(a,'Position'), axInfo.position = double(a.Position); end, catch, end
                try, if isprop(a,'OuterPosition'), axInfo.outerPosition = double(a.OuterPosition); end, catch, end

                try
                    if isprop(a,'XLim')
                        xlimNow = double(a.XLim);
                        if isnumeric(xlimNow) && numel(xlimNow) >= 2
                            axInfo.xlim = xlimNow(1:2);
                        end
                    end
                catch
                end
                try
                    if isprop(a,'YLim')
                        ylimNow = double(a.YLim);
                        if isnumeric(ylimNow) && numel(ylimNow) >= 2
                            axInfo.ylim = ylimNow(1:2);
                        end
                    end
                catch
                end

                try, if isprop(a,'XScale'), axInfo.xscale = string(a.XScale); end, catch, end
                try, if isprop(a,'YScale'), axInfo.yscale = string(a.YScale); end, catch, end

                try, if isprop(a,'Title') && isprop(a.Title,'String'), axInfo.title = string(a.Title.String); end, catch, end
                try, if isprop(a,'XLabel') && isprop(a.XLabel,'String'), axInfo.xlabel = string(a.XLabel.String); end, catch, end
                try, if isprop(a,'YLabel') && isprop(a.YLabel,'String'), axInfo.ylabel = string(a.YLabel.String); end, catch, end
                try, if isprop(a,'FontSize'), axInfo.tickFontSize = double(a.FontSize); end, catch, end
                try, if isprop(a,'Title') && isprop(a.Title,'FontSize'), axInfo.titleFontSize = double(a.Title.FontSize); end, catch, end
                try, if isprop(a,'XLabel') && isprop(a.XLabel,'FontSize'), axInfo.xlabelFontSize = double(a.XLabel.FontSize); end, catch, end
                try, if isprop(a,'YLabel') && isprop(a.YLabel,'FontSize'), axInfo.ylabelFontSize = double(a.YLabel.FontSize); end, catch, end

                figInfoList(idx).axes(axIdx) = axInfo;
            end
        end
    end

    function out = getFigureMetadataTemplate()
        out = struct('name',"",'number',NaN,'position',[],'axes',repmat(getAxisMetadataTemplate(),0,1));
    end

    function out = getAxisMetadataTemplate()
        out = struct('tag',"",'position',[],'outerPosition',[],'xlim',[],'ylim',[], ...
            'xscale',"",'yscale',"",'title',"",'xlabel',"",'ylabel',"", ...
            'tickFontSize',NaN,'titleFontSize',NaN,'xlabelFontSize',NaN,'ylabelFontSize',NaN);
    end

    function out = getFigureLegendStateTemplate()
        out = struct('figureName',"",'figureNumber',NaN, ...
            'builtInLegends',repmat(getBuiltInLegendTemplate(),0,1), ...
            'manualLegends',repmat(getManualLegendEntryTemplate(),0,1), ...
            'manualLegendAxes',repmat(getManualLegendAxesTemplate(),0,1), ...
            'builtInLegendCount',0,'manualLegendCount',0);
    end

    function out = getBuiltInLegendTemplate()
        out = struct('exists',false,'location',"",'position',[],'fontSize',NaN,'numColumns',NaN);
    end

    function out = getManualLegendEntryTemplate()
        out = struct('type',"",'tag',"",'position',[],'fontSize',NaN);
    end

    function out = getManualLegendAxesTemplate()
        out = struct('tag',"",'position',[],'outerPosition',[],'visible',"");
    end

    function tf = isManualLegendAxes(a)
        tf = false;
        try
            if isempty(a) || ~isvalid(a)
                return;
            end
            tagVal = "";
            try, if isprop(a,'Tag'), tagVal = string(a.Tag); end, catch, end
            if strlength(tagVal) > 0
                if strcmpi(tagVal, "MT_Legend_Axes")
                    tf = true;
                    return;
                end
                if any(contains(tagVal, ["legend_axes","legend axis","legend"], 'IgnoreCase', true))
                    tf = true;
                    return;
                end
            end
            if isprop(a,'UserData')
                try
                    ud = a.UserData;
                    if ischar(ud) || isstring(ud)
                        if contains(string(ud), "legend", 'IgnoreCase', true)
                            tf = true;
                            return;
                        end
                    elseif isstruct(ud)
                        fn = fieldnames(ud);
                        for ii = 1:numel(fn)
                            v = ud.(fn{ii});
                            if (ischar(v) || isstring(v)) && contains(string(v), "legend", 'IgnoreCase', true)
                                tf = true;
                                return;
                            end
                        end
                    end
                catch
                end
            end
        catch
            tf = false;
        end
    end

    function state = collectKnownUiState()
        state = struct();
        state.path = string(hPathBox.Value);
        state.useSubfolder = logical(hUseSubfolder.Value);
        state.subfolderName = string(hSubfolderName.Value);
        state.overwrite = logical(hOverwrite.Value);
        state.pdfMode = string(hPdfMode.Value);
        state.layoutPresetPath = string(layoutPresetPath);

        state.figWidth = double(hFigWidth.Value);
        state.figHeight = double(hFigHeight.Value);
        state.axWidth = double(hAxWidth.Value);
        state.axHeight = double(hAxHeight.Value);
        state.topMargin = double(hTopMargin.Value);
        state.leftMargin = double(hLeftMargin.Value);

        state.panelsX = double(hPanelsX.Value);
        state.panelsY = double(hPanelsY.Value);
        state.columnMode = string(colMode.Value);
        state.styleMode = string(hStyleMode.Value);
        state.aspect = double(hAspect.Value);

        state.fontSize = string(hFontSize.Value);
        state.legendFontSize = string(hLegendFontSize.Value);
        state.applyCurrentOnly = logical(applyCurrentOnly);

        state.appearanceMapName = string(hPopupMap.Value);
        state.appearanceSpreadMode = string(hPopupSpread.Value);
        state.appearanceUseFolder = logical(hRadioFolder.Value);
        state.appearanceFolderPath = string(hEditFolder.Value);
        state.appearanceFitColor = string(hPopupFitColor.Value);
        state.appearanceDataLineWidth = string(hEditDataLW.Value);
        state.appearanceDataLineStyle = string(hPopupDataStyle.Value);
        state.appearanceMarkerSize = string(hEditMarkerSize.Value);
        state.appearanceFitLineWidth = string(hEditFitLW.Value);
        state.appearanceFitLineStyle = string(hPopupFitStyle.Value);
        state.appearanceReverseLegend = logical(hChkReverseLegend.Value);
        state.appearanceReverseOrder = logical(hChkReverseOrder.Value);
        state.appearanceNoMapChange = logical(hChkNoMapChange.Value);
    end

    function controlsRaw = captureUiControlsRaw()
        controlsRaw = struct('type',{},'tag',{},'label',{},'value',{},'items',{},'enabled',{},'checked',{},'selectedIndex',{});
        all = findall(fig);
        idx = 0;
        for i = 1:numel(all)
            h = all(i);
            try
                if ~isprop(h,'Value')
                    continue;
                end
                idx = idx + 1;
                controlsRaw(idx).type = string(class(h));
                if isprop(h,'Tag'), controlsRaw(idx).tag = string(h.Tag); else, controlsRaw(idx).tag = ""; end
                if isprop(h,'Text'), controlsRaw(idx).label = string(h.Text); else, controlsRaw(idx).label = ""; end
                controlsRaw(idx).value = toJsonSafeValue(h.Value);
                if isprop(h,'Items')
                    controlsRaw(idx).items = toJsonSafeValue(h.Items);
                else
                    controlsRaw(idx).items = [];
                end
                if isprop(h,'Enable')
                    controlsRaw(idx).enabled = string(h.Enable);
                else
                    controlsRaw(idx).enabled = "";
                end
                if islogical(h.Value) || isnumeric(h.Value)
                    try
                        controlsRaw(idx).checked = logical(h.Value(1));
                    catch
                        controlsRaw(idx).checked = [];
                    end
                else
                    controlsRaw(idx).checked = [];
                end
                if isprop(h,'Items')
                    try
                        itemsNow = h.Items;
                        valNow = h.Value;
                        selIdx = [];
                        if iscell(itemsNow)
                            selIdx = find(strcmp(itemsNow, char(string(valNow))), 1);
                        elseif isstring(itemsNow)
                            selIdx = find(strcmp(cellstr(itemsNow), char(string(valNow))), 1);
                        end
                        controlsRaw(idx).selectedIndex = selIdx;
                    catch
                        controlsRaw(idx).selectedIndex = [];
                    end
                else
                    controlsRaw(idx).selectedIndex = [];
                end
            catch
                idx = idx - 1;
            end
        end
    end

    function out = toJsonSafeValue(in)
        try
            if ischar(in) || isnumeric(in) || islogical(in) || isempty(in) || iscell(in) || isstruct(in)
                out = in;
                return;
            end
            if isstring(in)
                out = cellstr(in);
                return;
            end
            if isdatetime(in)
                out = char(string(in));
                return;
            end
            out = char(string(in));
        catch
            out = [];
        end
    end

    function out = normalizeForJson(in)
        [out, ~] = normalizeForJsonWithErrors(in, 'root');
    end

    function [out, errors] = normalizeForJsonWithErrors(in, path)
        errors = struct('path',{},'message',{});

        if isstruct(in)
            if isempty(in)
                out = struct();
                return;
            end

            if isscalar(in)
                out = struct();
                f = fieldnames(in);
                for ii = 1:numel(f)
                    key = f{ii};
                    childPath = sprintf('%s.%s', path, key);
                    try
                        [val, childErr] = normalizeForJsonWithErrors(in.(key), childPath);
                        out.(key) = val;
                        errors = [errors, childErr]; %#ok<AGROW>
                    catch ME
                        out.(key) = [];
                        errors(end+1) = struct('path', string(childPath), 'message', string(ME.message)); %#ok<AGROW>
                    end
                end
                return;
            end

            out = cell(1,numel(in));
            for ii = 1:numel(in)
                childPath = sprintf('%s(%d)', path, ii);
                try
                    [out{ii}, childErr] = normalizeForJsonWithErrors(in(ii), childPath);
                    errors = [errors, childErr]; %#ok<AGROW>
                catch ME
                    out{ii} = struct();
                    errors(end+1) = struct('path', string(childPath), 'message', string(ME.message)); %#ok<AGROW>
                end
            end
            return;
        end

        if iscell(in)
            out = cell(size(in));
            for ii = 1:numel(in)
                childPath = sprintf('%s{%d}', path, ii);
                try
                    [out{ii}, childErr] = normalizeForJsonWithErrors(in{ii}, childPath);
                    errors = [errors, childErr]; %#ok<AGROW>
                catch ME
                    out{ii} = [];
                    errors(end+1) = struct('path', string(childPath), 'message', string(ME.message)); %#ok<AGROW>
                end
            end
            return;
        end

        if isstring(in)
            try
                out = cellstr(in);
            catch ME
                out = cellstr(string(in));
                errors(end+1) = struct('path', string(path), 'message', string(ME.message)); %#ok<AGROW>
            end
            return;
        end

        if isdatetime(in)
            out = char(string(in));
            return;
        end

        if ischar(in) || isnumeric(in) || islogical(in) || isempty(in)
            out = in;
            return;
        end

        try
            out = char(string(in));
        catch ME
            out = [];
            errors(end+1) = struct('path', string(path), 'message', string(ME.message)); %#ok<AGROW>
        end
    end

    function prepareFiguresForExportThroughEngine(figs)
        %#ok<INUSD>
        % Passive export policy: export does not re-apply SMART formatting.
    end


    function setFigureBackgroundWhite(~,~)
        for f = findRealFigs()
            f.Color = 'white';
        end
    end

    function loadLayoutPreset(~,~)
        startPath = hPathBox.Value;
        try
            if ~isempty(layoutPresetPath) && isfile(layoutPresetPath)
                startPath = fileparts(layoutPresetPath);
            end
        catch
        end

        [f,p] = uigetfile({'*.json;*.mat','Layout Metadata Files (*.json,*.mat)'}, ...
            'Load Layout Preset / Metadata', startPath);
        if isequal(f,0), return; end
        presetPath = fullfile(p,f);
        layoutPresetPath = presetPath;

        try
            [~,~,ext] = fileparts(presetPath);
            switch lower(ext)
                case '.json'
                    raw = fileread(presetPath);
                    meta = jsondecode(raw);
                case '.mat'
                    s = load(presetPath);
                    if isfield(s,'meta')
                        meta = s.meta;
                    else
                        fn = fieldnames(s);
                        meta = s.(fn{1});
                    end
                otherwise
                    error('Unsupported preset extension: %s', ext);
            end

            applyLayoutMetadataStruct(meta);

            savePrefs();
        catch ME
            errordlg(sprintf('Failed to load layout preset:\n%s', ME.message), 'Layout Preset Error');
        end
    end

    function applyLayoutMetadataStruct(meta)
        if isempty(meta) || ~isstruct(meta)
            return;
        end

        % Primary source: uiState (new schema)
        if isfield(meta,'uiState') && isstruct(meta.uiState)
            applyKnownUiState(meta.uiState);
        % Legacy fallback
        elseif isfield(meta,'uiKnown') && isstruct(meta.uiKnown)
            applyKnownUiState(meta.uiKnown);
        else
            applyKnownUiState(meta);
        end

        % Generic replay by Tag (primary for full round-trip)
        if isfield(meta,'uiControlsSnapshot')
            replayUiControlsSnapshot(meta.uiControlsSnapshot);
        elseif isfield(meta,'uiControls')
            replayUiControlsSnapshot(meta.uiControls);
        end
    end

    function replayUiControlsSnapshot(snapshot)
        if isempty(snapshot)
            return;
        end
        if isstruct(snapshot)
            items = snapshot;
        elseif iscell(snapshot)
            try
                items = [snapshot{:}];
            catch
                return;
            end
        else
            return;
        end
        if isempty(items)
            return;
        end

        tagMap = buildUiControlTagMap();
        for i = 1:numel(items)
            it = items(i);
            try
                if ~isfield(it,'tag') || isempty(it.tag)
                    continue;
                end
                tag = char(string(it.tag));
                if isempty(tag)
                    continue;
                end
                if ~isKey(tagMap, tag)
                    warning('FinalFigureFormatterUI:UnmatchedControlTag', ...
                        'Saved UI control tag not found in current UI: %s', tag);
                    continue;
                end
                h = tagMap(tag);
                if ~isvalid(h)
                    continue;
                end

                if isfield(it,'selectedIndex') && ~isempty(it.selectedIndex) && isprop(h,'Items')
                    try
                        idxSel = double(it.selectedIndex);
                        items = h.Items;
                        if isfinite(idxSel) && idxSel >= 1 && idxSel <= numel(items)
                            if iscell(items)
                                h.Value = items{idxSel};
                            else
                                h.Value = items(idxSel);
                            end
                            continue;
                        end
                    catch
                    end
                end

                if isfield(it,'checked') && ~isempty(it.checked)
                    applyControlValue(h, it.checked);
                elseif isfield(it,'value')
                    applyControlValue(h, it.value);
                end
            catch ME
                warning('FinalFigureFormatterUI:ReplayControlFailed', ...
                    'Failed to replay control at index %d: %s', i, ME.message);
            end
        end
    end

    function applyControlValue(h, rawValue)
        if isempty(h) || ~isvalid(h)
            return;
        end
        if ~isprop(h,'Value')
            return;
        end

        try
            currVal = h.Value;
        catch
            return;
        end

        try
            % Dropdowns: ensure value is among Items when possible
            if isprop(h,'Items')
                itemsNow = h.Items;
                candidate = parseTextScalar(rawValue);
                if ~isempty(candidate) && iscell(itemsNow)
                    idx = find(strcmp(itemsNow, candidate), 1);
                    if ~isempty(idx)
                        h.Value = itemsNow{idx};
                        return;
                    end
                elseif ~isempty(candidate) && isstring(itemsNow)
                    idx = find(strcmp(cellstr(itemsNow), candidate), 1);
                    if ~isempty(idx)
                        h.Value = itemsNow(idx);
                        return;
                    end
                end
            end

            % Numeric fields / checkboxes / generic value controls
            if isnumeric(currVal)
                numVal = parseNumericScalar(rawValue);
                if ~isempty(numVal)
                    h.Value = numVal;
                end
                return;
            end

            if islogical(currVal)
                logVal = parseLogicalScalar(rawValue);
                if ~isempty(logVal)
                    h.Value = logVal;
                end
                return;
            end

            % Textual controls
            txtVal = parseTextScalar(rawValue);
            if ~isempty(txtVal)
                h.Value = txtVal;
            end
        catch
            % Last resort: try direct assignment
            try
                h.Value = rawValue;
            catch
            end
        end
    end

    function scalarNum = parseNumericScalar(rawValue)
        scalarNum = [];
        try
            if isnumeric(rawValue) || islogical(rawValue)
                if ~isempty(rawValue)
                    scalarNum = double(rawValue(1));
                end
                return;
            end
            if ischar(rawValue) || isstring(rawValue)
                scalarNum = str2double(char(string(rawValue)));
                if ~isfinite(scalarNum)
                    scalarNum = [];
                end
            end
        catch
            scalarNum = [];
        end
    end

    function scalarLog = parseLogicalScalar(rawValue)
        scalarLog = [];
        try
            if islogical(rawValue)
                if ~isempty(rawValue)
                    scalarLog = logical(rawValue(1));
                end
                return;
            end
            if isnumeric(rawValue)
                if ~isempty(rawValue)
                    scalarLog = logical(rawValue(1));
                end
                return;
            end
            if ischar(rawValue) || isstring(rawValue)
                txt = lower(strtrim(char(string(rawValue))));
                if any(strcmp(txt, {'1','true','on','yes'}))
                    scalarLog = true;
                elseif any(strcmp(txt, {'0','false','off','no'}))
                    scalarLog = false;
                else
                    scalarLog = [];
                end
            end
        catch
            scalarLog = [];
        end
    end

    function scalarTxt = parseTextScalar(rawValue)
        scalarTxt = [];
        try
            if ischar(rawValue)
                scalarTxt = rawValue;
                return;
            end
            if isstring(rawValue)
                if isempty(rawValue)
                    scalarTxt = '';
                else
                    scalarTxt = char(rawValue(1));
                end
                return;
            end
            if isnumeric(rawValue) || islogical(rawValue)
                if isempty(rawValue)
                    scalarTxt = '';
                else
                    scalarTxt = char(string(rawValue(1)));
                end
            end
        catch
            scalarTxt = [];
        end
    end

    function map = buildUiControlTagMap()
        map = containers.Map('KeyType','char','ValueType','any');
        allControls = findall(fig);
        for ii = 1:numel(allControls)
            h = allControls(ii);
            try
                if ~isprop(h,'Value') || ~isprop(h,'Tag')
                    continue;
                end
                tag = char(string(h.Tag));
                if isempty(tag)
                    continue;
                end
                map(tag) = h;
            catch
            end
        end
    end

    function assignControlTags()
        % Save / export
        try, hPathBox.Tag = 'pathBox'; catch, end
        try, hUseSubfolder.Tag = 'useSubfolder'; catch, end
        try, hSubfolderName.Tag = 'subfolderName'; catch, end
        try, hOverwrite.Tag = 'overwrite'; catch, end
        try, hPdfMode.Tag = 'pdfMode'; catch, end

        % Figure / axes geometry
        try, hFigWidth.Tag = 'figWidth'; catch, end
        try, hFigHeight.Tag = 'figHeight'; catch, end
        try, hAxWidth.Tag = 'axWidth'; catch, end
        try, hAxHeight.Tag = 'axHeight'; catch, end
        try, hTopMargin.Tag = 'topMargin'; catch, end
        try, hLeftMargin.Tag = 'leftMargin'; catch, end

        % Smart layout
        try, hPanelsX.Tag = 'panelsX'; catch, end
        try, hPanelsY.Tag = 'panelsY'; catch, end
        try, colMode.Tag = 'columnMode'; catch, end
        try, hAspect.Tag = 'aspect'; catch, end
        try, hStyleMode.Tag = 'styleMode'; catch, end

        % Appearance
        try, hPopupMap.Tag = 'appearanceMapName'; catch, end
        try, hPopupSpread.Tag = 'appearanceSpreadMode'; catch, end
        try, hRadioOpen.Tag = 'appearanceOpenFigs'; catch, end
        try, hRadioFolder.Tag = 'appearanceUseFolder'; catch, end
        try, hEditFolder.Tag = 'appearanceFolderPath'; catch, end
        try, hEditDataLW.Tag = 'appearanceDataLineWidth'; catch, end
        try, hPopupDataStyle.Tag = 'appearanceDataLineStyle'; catch, end
        try, hEditMarkerSize.Tag = 'appearanceMarkerSize'; catch, end
        try, hEditFitLW.Tag = 'appearanceFitLineWidth'; catch, end
        try, hPopupFitStyle.Tag = 'appearanceFitLineStyle'; catch, end
        try, hPopupFitColor.Tag = 'appearanceFitColor'; catch, end
        try, hChkReverseLegend.Tag = 'appearanceReverseLegend'; catch, end
        try, hChkReverseOrder.Tag = 'appearanceReverseOrder'; catch, end
        try, hChkNoMapChange.Tag = 'appearanceNoMapChange'; catch, end

        % Typography / advanced
        try, hFontSize.Tag = 'fontSize'; catch, end
        try, hLegendFontSize.Tag = 'legendFontSize'; catch, end
        try, chkCurrent.Tag = 'applyCurrentOnly'; catch, end
    end

    function testUiRoundTrip(~,~)
        try
            before = captureUiControlsRaw();
            tmpPath = fullfile(tempdir, ['ffui_roundtrip_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '.json']);
            [okSave, msgSave] = saveLayoutMetadataJson(tmpPath, gobjects(0), 'pdf', getPdfExportMode());
            if ~okSave
                fprintf('[INFO] Round-trip test: save metadata degraded: %s\n', msgSave);
            end

            restoreUIdefaults([],[]);

            raw = fileread(tmpPath);
            meta = jsondecode(raw);
            applyLayoutMetadataStruct(meta);

            after = captureUiControlsRaw();
            mismatch = compareControlSnapshots(before, after);
            assert(isempty(mismatch), 'Round-trip mismatch in %d control(s): %s', numel(mismatch), strjoin(mismatch, ', '));
            msgbox('Round-trip test passed: UI state restored successfully.','Round-Trip Test');
        catch ME
            errordlg(sprintf('Round-trip test failed:\n%s', ME.message), 'Round-Trip Test');
        end
    end

    function mismatch = compareControlSnapshots(a, b)
        mismatch = {};
        mapA = snapshotToMap(a);
        mapB = snapshotToMap(b);
        keysA = mapA.keys;
        for i = 1:numel(keysA)
            tag = keysA{i};
            if ~isKey(mapB, tag)
                mismatch{end+1} = tag; %#ok<AGROW>
                continue;
            end
            va = mapA(tag);
            vb = mapB(tag);
            if ~isequaln(string(va), string(vb))
                mismatch{end+1} = tag; %#ok<AGROW>
            end
        end
    end

    function map = snapshotToMap(snap)
        map = containers.Map('KeyType','char','ValueType','any');
        if isempty(snap)
            return;
        end
        for i = 1:numel(snap)
            try
                if ~isfield(snap(i),'tag') || ~isfield(snap(i),'value')
                    continue;
                end
                tag = char(string(snap(i).tag));
                if isempty(tag)
                    continue;
                end
                map(tag) = snap(i).value;
            catch
            end
        end
    end

    function applyKnownUiState(s)
        if isempty(s) || ~isstruct(s), return; end

        setFieldText(hPathBox, s, 'path');
        setFieldLogical(hUseSubfolder, s, 'useSubfolder');
        setFieldText(hSubfolderName, s, 'subfolderName');
        setFieldLogical(hOverwrite, s, 'overwrite');
        setFieldDropdown(hPdfMode, s, 'pdfMode');
        if isfield(s,'layoutPresetPath')
            try, layoutPresetPath = char(string(s.layoutPresetPath)); catch, end
        end

        setFieldNumeric(hFigWidth, s, 'figWidth');
        setFieldNumeric(hFigHeight, s, 'figHeight');
        setFieldNumeric(hAxWidth, s, 'axWidth');
        setFieldNumeric(hAxHeight, s, 'axHeight');
        setFieldNumeric(hTopMargin, s, 'topMargin');
        setFieldNumeric(hLeftMargin, s, 'leftMargin');

        setFieldNumeric(hPanelsX, s, 'panelsX');
        setFieldNumeric(hPanelsY, s, 'panelsY');
        setFieldDropdown(colMode, s, 'columnMode');
        setFieldDropdown(hStyleMode, s, 'styleMode');
        setFieldNumeric(hAspect, s, 'aspect');

        setFieldDropdownOrText(hFontSize, s, 'fontSize');
        setFieldDropdownOrText(hLegendFontSize, s, 'legendFontSize');

        if isfield(s,'applyCurrentOnly')
            applyCurrentOnly = logical(s.applyCurrentOnly);
            if exist('chkCurrent','var') && isvalid(chkCurrent)
                chkCurrent.Value = applyCurrentOnly;
            end
        end

        setFieldDropdown(hPopupMap, s, 'appearanceMapName');
        setFieldDropdown(hPopupSpread, s, 'appearanceSpreadMode');
        if isfield(s,'appearanceUseFolder')
            useFolder = logical(s.appearanceUseFolder);
            hRadioFolder.Value = useFolder;
            hRadioOpen.Value = ~useFolder;
            hEditFolder.Enable = iif(useFolder, 'on', 'off');
        end
        setFieldText(hEditFolder, s, 'appearanceFolderPath');
        setFieldDropdown(hPopupFitColor, s, 'appearanceFitColor');
        setFieldDropdownOrText(hEditDataLW, s, 'appearanceDataLineWidth');
        setFieldDropdown(hPopupDataStyle, s, 'appearanceDataLineStyle');
        setFieldDropdownOrText(hEditMarkerSize, s, 'appearanceMarkerSize');
        setFieldDropdownOrText(hEditFitLW, s, 'appearanceFitLineWidth');
        setFieldDropdown(hPopupFitStyle, s, 'appearanceFitLineStyle');
        setFieldLogical(hChkReverseLegend, s, 'appearanceReverseLegend');
        setFieldLogical(hChkReverseOrder, s, 'appearanceReverseOrder');
        setFieldLogical(hChkNoMapChange, s, 'appearanceNoMapChange');

        setSubfolderEnable(hUseSubfolder, []);
    end

    function setFieldText(ctrl, s, key)
        if ~isfield(s,key), return; end
        try
            if isvalid(ctrl)
                ctrl.Value = char(string(s.(key)));
            end
        catch
        end
    end

    function setFieldNumeric(ctrl, s, key)
        if ~isfield(s,key), return; end
        try
            v = double(s.(key));
            if isfinite(v) && isvalid(ctrl)
                ctrl.Value = v;
            end
        catch
        end
    end

    function setFieldLogical(ctrl, s, key)
        if ~isfield(s,key), return; end
        try
            if isvalid(ctrl)
                ctrl.Value = logical(s.(key));
            end
        catch
        end
    end

    function setFieldDropdown(ctrl, s, key)
        if ~isfield(s,key), return; end
        try
            v = char(string(s.(key)));
            if isvalid(ctrl) && any(strcmp(ctrl.Items, v))
                ctrl.Value = v;
            end
        catch
        end
    end

    function setFieldDropdownOrText(ctrl, s, key)
        if ~isfield(s,key), return; end
        try
            v = string(s.(key));
            if isprop(ctrl,'Items')
                items = ctrl.Items;
                itemsStr = string(items);
                if any(itemsStr == v)
                    try
                        ctrl.Value = v;
                    catch
                        ctrl.Value = char(v);
                    end
                end
            else
                try
                    ctrl.Value = v;
                catch
                    ctrl.Value = char(v);
                end
            end
        catch
        end
    end

    function moveLegend(loc)
        figs = findRealFigs();
        for k = 1:numel(figs)
            SmartFigureEngine.setLegendLocation(figs(k), loc);
        end
    end

    function resetAll(~,~)
        figs = findRealFigs();
        style = SmartFigureEngine.computeSmartStyle(3.5, 2.6, 1, 1, hStyleMode.Value);
        style.applyPreviewResize = false;
        for k = 1:numel(figs)
            fig = figs(k);
            try
                fig.Color = [0.94 0.94 0.94];
                fig.Position(3:4) = [560 420];
                SmartFigureEngine.applyFullSmart(fig, style);
            catch
            end
        end
    end

    function formatAllForPaper(~,~)
        figs = findRealFigs();
        for k = 1:numel(figs)
            fig = figs(k);
            SmartFigureEngine.formatForPaper(fig, hStyleMode.Value);
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
            setpref(prefGroup,'StyleMode',hStyleMode.Value);
            setpref(prefGroup,'Aspect',double(hAspect.Value));
            setpref(prefGroup,'FontSize',hFontSize.Value);
            setpref(prefGroup,'LegendFontSize',hLegendFontSize.Value);
            setpref(prefGroup,'PdfMode',hPdfMode.Value);
            setpref(prefGroup,'LayoutPresetPath',layoutPresetPath);
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
            setpref(prefGroup,'AppearanceReverseLegend',logical(hChkReverseLegend.Value));
            setpref(prefGroup,'AppearanceReverseOrder',logical(hChkReverseOrder.Value));
            setpref(prefGroup,'AppearanceNoMapChange',logical(hChkNoMapChange.Value));
        catch
        end
    end

    function loadPrefs()
        % LOADPREFS - Load preferences with per-key isolation
        % Each preference is guarded so one corrupt key does not block others
        failedPrefKeys = {};

        try
            if ispref(prefGroup,'LastPath')
                p = getpref(prefGroup,'LastPath');
                if ischar(p) || isstring(p), hPathBox.Value = char(p); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('LastPath (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'UseSubfolder')
                useSub = getpref(prefGroup,'UseSubfolder');
                if islogical(useSub) || isnumeric(useSub)
                    hUseSubfolder.Value = logical(useSub(1));
                    hSubfolderName.Enable = iif(hUseSubfolder.Value, 'on', 'off');
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('UseSubfolder (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'SubfolderName')
                sf = getpref(prefGroup,'SubfolderName');
                if ischar(sf) || isstring(sf), hSubfolderName.Value = char(sf); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('SubfolderName (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'Overwrite')
                ov = getpref(prefGroup,'Overwrite');
                if islogical(ov) || isnumeric(ov), hOverwrite.Value = logical(ov(1)); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('Overwrite (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'FigWidth')
                fw = getpref(prefGroup,'FigWidth');
                if isnumeric(fw) && fw > 0, hFigWidth.Value = fw(1); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('FigWidth (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'FigHeight')
                fh = getpref(prefGroup,'FigHeight');
                if isnumeric(fh) && fh > 0, hFigHeight.Value = fh(1); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('FigHeight (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AxWidth')
                aw = getpref(prefGroup,'AxWidth');
                if isnumeric(aw) && aw >=0 && aw <= 1, hAxWidth.Value = aw(1); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AxWidth (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AxHeight')
                ah = getpref(prefGroup,'AxHeight');
                if isnumeric(ah) && ah >= 0 && ah <= 1, hAxHeight.Value = ah(1); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AxHeight (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'TopMargin')
                tm = getpref(prefGroup,'TopMargin');
                if isnumeric(tm) && tm >= 0 && tm <= 1, hTopMargin.Value = tm(1); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('TopMargin (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'LeftMargin')
                lm = getpref(prefGroup,'LeftMargin');
                if isnumeric(lm) && lm >= 0 && lm <= 1, hLeftMargin.Value = lm(1); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('LeftMargin (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'PanelsX')
                px = getpref(prefGroup,'PanelsX');
                if isnumeric(px) && px > 0, hPanelsX.Value = px(1); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('PanelsX (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'PanelsY')
                py = getpref(prefGroup,'PanelsY');
                if isnumeric(py) && py > 0, hPanelsY.Value = py(1); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('PanelsY (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'ColMode')
                cm = getpref(prefGroup,'ColMode');
                if ischar(cm) || isstring(cm)
                    cm = char(cm);
                    if any(strcmp(colMode.Items, cm)), colMode.Value = cm; end
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('ColMode (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'StyleMode')
                smd = getpref(prefGroup,'StyleMode');
                if ischar(smd) || isstring(smd)
                    smd = char(smd);
                    if any(strcmp(hStyleMode.Items, smd)), hStyleMode.Value = smd; end
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('StyleMode (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'Aspect')
                asp = getpref(prefGroup,'Aspect');
                if isnumeric(asp) && asp > 0, hAspect.Value = asp(1); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('Aspect (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'FontSize')
                fs = getpref(prefGroup,'FontSize');
                if isnumeric(fs) && fs > 0
                    hFontSize.Value = num2str(fs(1));
                elseif ischar(fs) || isstring(fs)
                    fs = char(fs);
                    if any(strcmp(hFontSize.Items, fs)), hFontSize.Value = fs; end
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('FontSize (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'LegendFontSize')
                lfs = getpref(prefGroup,'LegendFontSize');
                if isnumeric(lfs) && lfs > 0
                    hLegendFontSize.Value = num2str(lfs(1));
                elseif ischar(lfs) || isstring(lfs)
                    lfs = char(lfs);
                    if any(strcmp(hLegendFontSize.Items, lfs)), hLegendFontSize.Value = lfs; end
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('LegendFontSize (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'PdfMode')
                pm = getpref(prefGroup,'PdfMode');
                if ischar(pm) || isstring(pm)
                    pm = char(pm);
                    if any(strcmp(hPdfMode.Items, pm)), hPdfMode.Value = pm; end
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('PdfMode (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'LayoutPresetPath')
                lpp = getpref(prefGroup,'LayoutPresetPath');
                if ischar(lpp) || isstring(lpp)
                    layoutPresetPath = char(lpp);
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('LayoutPresetPath (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'ApplyCurrentOnly')
                aco = getpref(prefGroup,'ApplyCurrentOnly');
                if islogical(aco) || isnumeric(aco)
                    applyCurrentOnly = logical(aco(1));
                    chkCurrent.Value = applyCurrentOnly;
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('ApplyCurrentOnly (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceMapName')
                mn = getpref(prefGroup,'AppearanceMapName');
                if ischar(mn) || isstring(mn)
                    mn = char(mn);
                    if any(strcmp(mapList, mn)), hPopupMap.Value = mn; end
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceMapName (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceSpreadMode')
                sm = getpref(prefGroup,'AppearanceSpreadMode');
                if ischar(sm) || isstring(sm)
                    sm = char(sm);
                    if any(strcmp(hPopupSpread.Items, sm)), hPopupSpread.Value = sm; end
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceSpreadMode (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceUseFolder')
                auf = getpref(prefGroup,'AppearanceUseFolder');
                if islogical(auf) || isnumeric(auf)
                    auf = logical(auf(1));
                    hRadioFolder.Value = auf;
                    hRadioOpen.Value = ~auf;
                    hEditFolder.Enable = iif(auf, 'on', 'off');
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceUseFolder (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceFolderPath')
                fp = getpref(prefGroup,'AppearanceFolderPath');
                if ischar(fp) || isstring(fp), hEditFolder.Value = char(fp); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceFolderPath (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceFitColor')
                fc = getpref(prefGroup,'AppearanceFitColor');
                if ischar(fc) || isstring(fc)
                    fc = char(fc);
                    if any(strcmp(hPopupFitColor.Items, fc)), hPopupFitColor.Value = fc; end
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceFitColor (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceDataLineWidth')
                dlw = getpref(prefGroup,'AppearanceDataLineWidth');
                if isnumeric(dlw)
                    hEditDataLW.Value = num2str(dlw(1));
                elseif ischar(dlw) || isstring(dlw)
                    hEditDataLW.Value = char(dlw);
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceDataLineWidth (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceDataLineStyle')
                dls = getpref(prefGroup,'AppearanceDataLineStyle');
                if ischar(dls) || isstring(dls)
                    dls = char(dls);
                    if any(strcmp(hPopupDataStyle.Items, dls)), hPopupDataStyle.Value = dls; end
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceDataLineStyle (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceMarkerSize')
                ms = getpref(prefGroup,'AppearanceMarkerSize');
                if isnumeric(ms)
                    hEditMarkerSize.Value = num2str(ms(1));
                elseif ischar(ms) || isstring(ms)
                    hEditMarkerSize.Value = char(ms);
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceMarkerSize (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceFitLineWidth')
                flw = getpref(prefGroup,'AppearanceFitLineWidth');
                if isnumeric(flw)
                    hEditFitLW.Value = num2str(flw(1));
                elseif ischar(flw) || isstring(flw)
                    hEditFitLW.Value = char(flw);
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceFitLineWidth (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceFitLineStyle')
                fls = getpref(prefGroup,'AppearanceFitLineStyle');
                if ischar(fls) || isstring(fls)
                    fls = char(fls);
                    if any(strcmp(hPopupFitStyle.Items, fls)), hPopupFitStyle.Value = fls; end
                end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceFitLineStyle (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceReverseLegend')
                arl = getpref(prefGroup,'AppearanceReverseLegend');
                if islogical(arl) || isnumeric(arl), hChkReverseLegend.Value = logical(arl(1)); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceReverseLegend (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceReverseOrder')
                aro = getpref(prefGroup,'AppearanceReverseOrder');
                if islogical(aro) || isnumeric(aro), hChkReverseOrder.Value = logical(aro(1)); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceReverseOrder (%s)', ME.message);
        end

        try
            if ispref(prefGroup,'AppearanceNoMapChange')
                anm = getpref(prefGroup,'AppearanceNoMapChange');
                if islogical(anm) || isnumeric(anm), hChkNoMapChange.Value = logical(anm(1)); end
            end
        catch ME
            failedPrefKeys{end+1} = sprintf('AppearanceNoMapChange (%s)', ME.message);
        end

        if ~isempty(failedPrefKeys)
            prefSummary = strjoin(unique(failedPrefKeys), ', ');
            fprintf('[INFO] Preferences skipped (%d): %s\n', numel(failedPrefKeys), prefSummary);
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
        hStyleMode.Value = 'PRL';
        hAspect.Value = panelAspect;
        hFontSize.Value = '12'; hLegendFontSize.Value = '12';
        hPdfMode.Value = 'Vector (Recommended)';
        applyCurrentOnly = false; chkCurrent.Value = false;
        % reset Appearance controls
        hPopupMap.Value = mapList{1};
        hPopupSpread.Value = 'medium';
        hRadioOpen.Value = true; hRadioFolder.Value = false; hEditFolder.Value = ''; hEditFolder.Enable = 'off';
        hPopupFitColor.Value = '(no change)';
        hEditDataLW.Value = ''; hPopupDataStyle.Value = '(no change)';
        hEditMarkerSize.Value = ''; hEditFitLW.Value = ''; hPopupFitStyle.Value = '(no change)';
        hChkReverseLegend.Value = false; hChkReverseOrder.Value = false; hChkNoMapChange.Value = false;
        % persist cleared state
        savePrefs();
    end

    function closeAndSave(~,~)
        % save current UI state, then close
        try
            savePrefs();
        catch ME
            fprintf('[INFO] savePrefs on close skipped: %s\n', ME.message);
        end
        try
            if ~isempty(currentFigureListener) && isvalid(currentFigureListener)
                delete(currentFigureListener);
            end
        catch ME
            fprintf('[INFO] Listener cleanup skipped: %s\n', ME.message);
        end
        if isvalid(fig)
            delete(fig);
        end
    end

    % advanced toggle removed; advanced panel is always visible

    function trackLastFigure(~,~)
        % TRACKLASTFIGURE - Store reference to currently active figure
        % Safe string comparison and validation
        fig0 = get(0,'CurrentFigure');
        if isempty(fig0), return; end
        if ~isvalid(fig0), return; end
        
        if ~isRealDataFigure(fig0)
            return;
        end
        
        lastRealFigure = fig0;
    end

    function figs = findRealFigs()
        % FINDREALFIGS - Return array of valid user data figures
        % Filters out UI windows using safe string comparison
        if applyCurrentOnly
            if ~isempty(lastRealFigure) && isvalid(lastRealFigure) && isRealDataFigure(lastRealFigure)
                figs = lastRealFigure;
                return;
            end

            figCurrent = [];
            try
                figCurrent = get(0,'CurrentFigure');
            catch
                figCurrent = [];
            end
            if ~isempty(figCurrent) && isvalid(figCurrent) && isRealDataFigure(figCurrent)
                lastRealFigure = figCurrent;
                figs = figCurrent;
                return;
            end

            lastRealFigure = [];
            figs = [];
            return;
        end
        
        % Find all figures and filter out UI windows
        allFigs = findall(0,'Type','figure');
        figs = [];
        
        for f = allFigs'
            if ~isvalid(f), continue; end
            
            if isRealDataFigure(f)
                figs = [figs; f];
            end
        end
    end

    function tf = isRealDataFigure(f)
        tf = false;
        try
            if isempty(f) || ~isvalid(f) || ~isgraphics(f,'figure')
                return;
            end

            fname = '';
            try
                fname = char(f.Name);
            catch
                fname = '';
            end

            for i = 1:numel(skipList)
                if strcmp(fname, skipList{i})
                    return;
                end
            end

            hasAxes = ~isempty(findall(f,'Type','axes'));
            tf = hasAxes;
        catch
            tf = false;
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

    function setPopupValueByString(hPopup, targetStr)
        try
            opts = hPopup.Items;
            idx = find(strcmp(opts, targetStr), 1);
            if ~isempty(idx), hPopup.Value = opts(idx); end
        catch
        end
    end

    function out = sanitizeLatexString(in)
        % Normalize labels for robust publication typography.
        % Fixes split-letter labels, normalizes common scientific notation,
        % and keeps latex usage consistent.
        if iscell(in)
            out = cell(size(in));
            for k = 1:numel(in)
                out{k} = sanitizeLatexString(in{k});
            end
            return;
        end
        if isstring(in), in = char(in); end
        if ~ischar(in)
            out = in;
            return;
        end

        in = collapseSpacedLabel(in);
        in = strrep(in, char(916), '\\Delta'); % Δ
        in = strrep(in, char(181), '\\mu');    % µ

        in = strtrim(in);
        if isempty(in), out = in; return; end
        if isWrappedInMath(in)
            out = repairWrappedMathString(in);
            return;
        end

        in = regexprep(in, '^\s*Temperature\s*\(\s*K\s*\)\s*$', 'Temperature (K)', 'ignorecase');
        in = regexprep(in, '10\s*\^\s*\(?\s*([-+]?\d+)\s*\)?', '10^{$1}');
        in = regexprep(in, '([A-Za-z])\s*\^\s*\(?\s*([-+]?\d+)\s*\)?', '$1^{$2}');
        if ~isempty(regexpi(in,'M\s*/\s*H\s*\(.*emu.*g\^\{-?1\}.*Oe\^\{-?1\}.*\)','once'))
            in = 'M/H\,(10^{-5}\,\\mathrm{emu}\,\\mathrm{g}^{-1}\,\\mathrm{Oe}^{-1})';
        end
        in = regexprep(in,'\s+',' ');
        in = normalizeMathCore(in);

        in = strrep(in,'[','');
        in = strrep(in,']','');
        in = escapePlainUnderscores(in);

        if contains(in,{'_','^','\','{','Delta','\mu'})
            out = ['$' in '$'];
        else
            out = in;
        end
    end

    function out = repairWrappedMathString(in)
        out = in;
        if ~ischar(out) || numel(out) < 2, return; end
        if ~(out(1) == '$' && out(end) == '$'), return; end

        core = strtrim(out(2:end-1));
        if isempty(core)
            out = in;
            return;
        end

        % Normalize accidental doubled slashes from repeated sanitization
        core = strrep(core, '\\\\', '\\');

        % If expression is fully wrapped by \mathrm{...}, strip it.
        % MATLAB's LaTeX subset often rejects mixed command content there.
        stripped = stripOuterMathMacro(core, '\\mathrm');
        if ~strcmp(stripped, core)
            core = stripped;
        end

        core = normalizeMathCore(core);
        core = escapePlainUnderscores(core);

        % Final cleanup of common spacing artifacts
        core = regexprep(core,'\s+',' ');
        out = ['$' core '$'];
    end

    function out = stripOuterMathMacro(in, macro)
        out = in;
        s = strtrim(in);
        prefix = [macro '{'];
        nPrefix = numel(prefix);
        if numel(s) < nPrefix + 1 || ~strncmp(s, prefix, nPrefix)
            return;
        end

        depth = 0;
        closeIdx = -1;
        for i = (nPrefix+1):numel(s)
            ch = s(i);
            if ch == '{'
                depth = depth + 1;
            elseif ch == '}'
                if depth == 0
                    closeIdx = i;
                    break;
                else
                    depth = depth - 1;
                end
            end
        end

        if closeIdx == numel(s)
            out = s((nPrefix+1):(end-1));
        end
    end

    function out = normalizeMathCore(in)
        out = in;
        if ~ischar(out), return; end

        out = regexprep(out,'\\Delta(?=[A-Za-z])','\\Delta ');
        out = regexprep(out,'\\rho(?=[A-Za-z])','\\rho ');
        out = regexprep(out,'\\mu(?=[A-Za-z])','\\mu ');
        out = regexprep(out,'\\Omega(?=[A-Za-z])','\\Omega ');
    end

    function out = escapePlainUnderscores(in)
        out = in;
        if ~ischar(out) || isempty(out), return; end

        chars = out;
        k = 1;
        while k <= numel(chars)
            if chars(k) ~= '_'
                k = k + 1;
                continue;
            end

            prefix = chars(1:max(1,k-1));
            if ~isempty(regexp(prefix,'\\[A-Za-z]+$','once'))
                k = k + 1;
                continue;
            end
            if k > 1 && chars(k-1) == '\\'
                k = k + 1;
                continue;
            end

            chars = [chars(1:k-1) '\\' chars(k:end)]; %#ok<AGROW>
            k = k + 2;
        end
        out = chars;
    end

    function out = collapseSpacedLabel(in)
        out = in;
        if ~ischar(out), return; end
        s = strtrim(out);
        if numel(s) < 3, out = s; return; end

        % Collapse only true split-letter patterns while preserving normal
        % spaces in legend entries and axis titles.
        tokenPattern = '^\s*(?:[A-Za-z]\s+){5,}[A-Za-z](?:\s*[\(\[].*[\)\]])?\s*$';
        if ~isempty(regexp(s, tokenPattern, 'once'))
            out = regexprep(s,'([A-Za-z])\s+(?=[A-Za-z])','$1');
            return;
        end
        out = s;
    end

    function tf = isWrappedInMath(str)
        if isstring(str), str = char(str); end
        if ~ischar(str), tf = false; return; end
        tf = numel(str) >= 2 && str(1) == '$' && str(end) == '$';
    end

end
