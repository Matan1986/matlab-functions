function CtrlGUI()

%% ---------- Main window ----------
h.fig = figure('Name','Appearance / Colormap Control', ...
    'NumberTitle','off','MenuBar','none','ToolBar','none', ...
    'Color','w','Units','normalized','Position',[0.33 0.18 0.34 0.70]);

%% ---------- MAP LISTS ----------
builtinMaps = { 'parula','jet','cool','spring','summer','autumn','winter','copper','turbo',...
    'hot','gray','bone','pink','hsv','lines','colorcube','prism','flag','white' };

cmoMaps = { 'cmocean(''thermal'')','cmocean(''haline'')','cmocean(''solar'')','cmocean(''matter'')',...
    'cmocean(''turbid'')','cmocean(''speed'')','cmocean(''amp'')','cmocean(''deep'')',...
    'cmocean(''dense'')','cmocean(''algae'')','cmocean(''balance'')','cmocean(''curl'')',...
    'cmocean(''delta'')','cmocean(''oxy'')','cmocean(''phase'')','cmocean(''rain'')',...
    'cmocean(''ice'')','cmocean(''gray'')' };

customMaps = { 'softyellow','softgreen','softred','softblue','softpurple','softorange','softcyan',...
    'softgray','softbrown','softteal','softolive','softgold','softpink','softaqua',...
    'softsand','softsky','bluebright','redbright','greenbright','purplebright',...
    'orangebright','cyanbright','yellowbright','magnetabright','limebright',...
    'tealbright','ultrabrightblue','ultrabrightred','fire','ice','ocean','topo',...
    'terrain','magma','inferno','plasma','cividis','bluewhitered','redwhiteblue',...
    'purplewhitegreen','brownwhiteblue','greenwhitepurple','bluewhiteorange',...
    'blackwhiteyellow' };

mapList = [ {'(no change)'};  ...
    {'--- Built-in ---'}; builtinMaps(:); {''}; ...
    {'--- Custom ---'}; customMaps(:); {''}; ...
    {'--- cmocean ---'}; cmoMaps(:) ];

%% ============================================================
%  ALL LABELS (1)–(8) — CREATED BEFORE THE LEGEND PANEL
%% ============================================================

%% (1) Select colormap
uicontrol('Parent',h.fig,'Style','text','String','(1) Select colormap:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.93 0.40 0.035], ...
    'HorizontalAlignment','left');

h.popupMap = uicontrol('Parent',h.fig,'Style','popupmenu','BackgroundColor','w', ...
    'String',mapList,'Units','normalized','Position',[0.05 0.88 0.35 0.05]);

%% (2) Spread mode
uicontrol('Parent',h.fig,'Style','text','String','(2) Spread mode:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.83 0.40 0.035], ...
    'HorizontalAlignment','left');

h.popupSpread = uicontrol('Parent',h.fig,'Style','popupmenu','BackgroundColor','w', ...
    'String',{ 'ultra-narrow','ultra-narrow-rev','narrow','narrow-rev','medium','medium-rev',...
    'wide','wide-rev','ultra','ultra-rev','full','full-rev' }, ...
    'Units','normalized','Position',[0.05 0.78 0.40 0.05]);

%% (3) Target
uicontrol('Parent',h.fig,'Style','text','String','(3) Target:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.73 0.40 0.035], ...
    'HorizontalAlignment','left');

h.radioOpen = uicontrol('Parent',h.fig,'Style','radiobutton','String','Open figures', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.69 0.40 0.035], ...
    'Value',1,'Callback',@switchTarget);

h.radioFolder = uicontrol('Parent',h.fig,'Style','radiobutton','String','FIG files in folder:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.65 0.40 0.035], ...
    'Callback',@switchTarget);

h.editFolder = uicontrol('Parent',h.fig,'Style','edit','Enable','off','BackgroundColor',[0.97 0.97 0.97], ...
    'Units','normalized','Position',[0.05 0.605 0.50 0.045]);

h.btnBrowse = uicontrol('Parent',h.fig,'Style','pushbutton','String','Browse...','Enable','off', ...
    'Units','normalized','Position',[0.60 0.605 0.12 0.045],'Callback',@onBrowse);

%% (4) Fit color
uicontrol('Parent',h.fig,'Style','text','String','(4) Fit color:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.55 0.40 0.035], ...
    'HorizontalAlignment','left');

h.popupFitColor = uicontrol('Parent',h.fig,'Style','popupmenu','BackgroundColor','w', ...
    'String',{'(no change)','black','red','blue','green','cyan','magenta','yellow','white'}, ...
    'Units','normalized','Position',[0.05 0.51 0.40 0.05]);


%% (5) Data lines
uicontrol('Parent',h.fig,'Style','text','String','(5) Data lines:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.48 0.40 0.035], ...
    'HorizontalAlignment','left');

uicontrol('Parent',h.fig,'Style','text','String','Width:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.45 0.15 0.03], ...
    'HorizontalAlignment','left');

h.editDataLW = uicontrol('Parent',h.fig,'Style','edit','BackgroundColor','w', ...
    'Units','normalized','Position',[0.20 0.44 0.12 0.04]);

uicontrol('Parent',h.fig,'Style','text','String','Style:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.35 0.45 0.15 0.03], ...
    'HorizontalAlignment','left');

h.popupDataStyle = uicontrol('Parent',h.fig,'Style','popupmenu','BackgroundColor','w', ...
    'String',{'(no change)','-','--',':','-.','none'}, ...
    'Units','normalized','Position',[0.50 0.44 0.20 0.04]);
%% (5b) Marker size
uicontrol('Parent',h.fig,'Style','text','String','Marker size:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.39 0.40 0.03], ...
    'HorizontalAlignment','left');

h.editMarkerSize = uicontrol('Parent',h.fig,'Style','edit','BackgroundColor','w', ...
    'Units','normalized','Position',[0.20 0.38 0.12 0.04]);

%% (6) Fit lines
uicontrol('Parent',h.fig,'Style','text','String','(6) Fit lines:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.34 0.40 0.035], ...
    'HorizontalAlignment','left');

uicontrol('Parent',h.fig,'Style','text','String','Width:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.30 0.15 0.03], ...
    'HorizontalAlignment','left');

h.editFitLW = uicontrol('Parent',h.fig,'Style','edit','BackgroundColor','w', ...
    'Units','normalized','Position',[0.20 0.30 0.12 0.04]);

uicontrol('Parent',h.fig,'Style','text','String','Style:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.35 0.30 0.15 0.03], ...
    'HorizontalAlignment','left');

h.popupFitStyle = uicontrol('Parent',h.fig,'Style','popupmenu','BackgroundColor','w', ...
    'String',{'(no change)','-','--',':','-.','none'}, ...
    'Units','normalized','Position',[0.50 0.30 0.20 0.04]);

%% (7) Legend
uicontrol('Parent',h.fig,'Style','text','String','(7) Legend:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.225 0.40 0.035], ...
    'HorizontalAlignment','left');

h.chkReverseLegend = uicontrol('Parent',h.fig,'Style','checkbox','String','Reverse legend order', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.19 0.40 0.04]);

%% (8) Plot order
uicontrol('Parent',h.fig,'Style','text','String','(8) Plot order:', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.125 0.40 0.035], ...
    'HorizontalAlignment','left');

h.chkReverseOrder = uicontrol('Parent',h.fig,'Style','checkbox','String','Reverse plot order', ...
    'Units','normalized','BackgroundColor','w','Position',[0.05 0.095 0.40 0.04]);

%% ---------- Buttons ----------
h.btnApply = uicontrol('Parent',h.fig,'Style','pushbutton','String','Apply', ...
    'Units','normalized','Position',[0.25 0.03 0.20 0.065], ...
    'BackgroundColor',[0.90 0.95 1],'FontWeight','bold','Callback',@onApply);

h.btnClose = uicontrol('Parent',h.fig,'Style','pushbutton','String','Close', ...
    'Units','normalized','Position',[0.47 0.03 0.20 0.065], ...
    'BackgroundColor',[0.95 0.95 0.95],'Callback',@(src,evt) close(h.fig));

%% ============================================================
%  ONLY NOW — PLACE THE LEGEND PANEL ON THE RIGHT
%% ============================================================

legendPanel = uipanel('Parent',h.fig,'Title','Colormaps','FontSize',8, ...
    'Units','normalized','Position',[0.76 0.05 0.22 0.90],'BackgroundColor','w');

%% ---------- Colormap LEGEND (Auto-packed, no scroll) ----------
legendPanel = uipanel('Parent',h.fig, ...
    'Title','Colormaps', ...
    'FontSize',8, ...
    'Units','normalized', ...
    'Position',[0.76 0.05 0.22 0.90], ...
    'BackgroundColor','w');

% רשימת מפות תקפות (בלי --- ובלי ריקים)
validMaps = mapList(~startsWith(mapList,'---') & ~strcmp(mapList,''));
numMaps   = numel(validMaps);

topMargin    = 0.97;
bottomMargin = 0.03;
availableH   = topMargin - bottomMargin;
dy    = availableH / numMaps;
barFrac = 0.95;
txtFrac = 0.95;
barH = barFrac * dy;
txtH = txtFrac * dy;

for k = 1:numMaps
    mapName = validMaps{k};

    % ---- load colormap ----
    try
        if contains(mapName,'cmocean')
            cmap = eval(mapName);
        elseif exist(mapName,'builtin') || exist(mapName,'file')
            cmap = feval(mapName,64);
        else
            cmap = makeCustomColormap(mapName);
        end
    catch
        cmap = repmat([0.5 0.5 0.5],64,1);
    end

    y0 = topMargin - k*dy;

    % ---- bar ----
    ax = axes('Parent',legendPanel, ...
        'Units','normalized', ...
        'Position',[0.05, y0 + (dy-barH)/2, 0.33, barH]);
    img = reshape(cmap, [1 size(cmap,1) 3]);
    image(ax, img);
    axis(ax,'off');

    % ---- label ----
    uicontrol('Parent',legendPanel,'Style','text', ...
        'String',mapName, ...
        'Units','normalized', ...
        'Position',[0.40, y0 + (dy-txtH)/2, 0.55, txtH], ...
        'BackgroundColor','w', ...
        'FontSize',4.5, ...
        'HorizontalAlignment','left');
end


%% ---------- Save GUI handles ----------
guidata(h.fig,h);

%% ---------- CALLBACKS ----------
    function switchTarget(~,~)
        h = guidata(h.fig);
        if h.radioOpen.Value
            h.radioFolder.Value = 0;
            set(h.editFolder,'Enable','off');
            set(h.btnBrowse,'Enable','off');
        else
            h.radioOpen.Value = 0;
            h.radioFolder.Value = 1;
            set(h.editFolder,'Enable','on');
            set(h.btnBrowse,'Enable','on');
        end
        guidata(h.fig,h);
    end

    function onBrowse(~,~)
        h = guidata(h.fig);
        folderName = uigetdir(pwd,'Select folder');
        if ischar(folderName) && folderName ~= 0
            set(h.editFolder,'String',folderName);
        end
    end

    function onApply(~,~)
        h = guidata(h.fig);

        maps = h.popupMap.String;
        mapName = maps{h.popupMap.Value};

        noColormapChange = strcmp(mapName,'(no change)');

        modes = h.popupSpread.String;
        spreadMode = modes{h.popupSpread.Value};

        fitColors = h.popupFitColor.String;
        fitColor  = fitColors{h.popupFitColor.Value};
        if strcmp(fitColor,'(no change)')
            fitColor = '';   % מסמן שלא משנים
        end
        ms = str2double(h.editMarkerSize.String);
        if isnan(ms) || ms <= 0
            ms = [];   % no change
        end
        % Data lines
        dw = str2double(h.editDataLW.String);
        if isnan(dw) || dw <= 0, dw = []; end

        fs = str2double(h.editFitLW.String);
        if isnan(fs) || fs <= 0, fs = []; end

        dataStyles = h.popupDataStyle.String;
        dataStyle = dataStyles{h.popupDataStyle.Value};
        if strcmp(dataStyle,'(no change)'), dataStyle=''; end

        fitStyles = h.popupFitStyle.String;
        fitStyle = fitStyles{h.popupFitStyle.Value};
        if strcmp(fitStyle,'(no change)'), fitStyle=''; end

        reverseOrder  = h.chkReverseOrder.Value;
        reverseLegend = h.chkReverseLegend.Value;

        try
            if h.radioOpen.Value
                applyColormapToFigures(mapName,[],spreadMode,...
                    fitColor,dw,dataStyle,fs,fitStyle,reverseOrder,reverseLegend,noColormapChange,ms);
            else
                folderName = strtrim(h.editFolder.String);
                if isempty(folderName) || ~isfolder(folderName)
                    errordlg('Invalid folder','Error'); return;
                end
                applyColormapToFigures(mapName,folderName,spreadMode,...
                    fitColor,dw,dataStyle,fs,fitStyle,reverseOrder,reverseLegend,noColormapChange,ms);
            end
        catch ME
            errordlg(ME.message,'Error');
        end
    end

end
