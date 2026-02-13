function formatAllFigures(varargin)
% FORMATALLFIGURES  Apply consistent formatting to all open figures.
% Automatically adapts to caller script (zfAMR, Resistivity_main, PS_dynamic, Switching, FieldSweep_main, etc.)
% If a figure contains subplots (multiple axes), grid is disabled for all subplots.

% -------- Defaults --------
defaultPos        = [0.1,0.1,0.5,0.5];
defaultFontSize   = 20;
defaultLegendFS   = 20;
defaultLineWidth  = 1.5;
defaultClear      = false;
defaultShowLeg    = true;
defaultShowGrid   = true;
defaultLegendMode = 'auto';
defaultTitleMode  = 'auto';
defaultXLabelMode = 'auto';
defaultYLabelMode = 'auto';

% -------------------------------------------------
% BACKWARD-COMPATIBILITY FIX:
% If called with name–value first argument,
% skip positional Optionals
% -------------------------------------------------
if nargin >= 1 && (ischar(varargin{1}) || isstring(varargin{1}))
    varargin = [{[],[],[],[],[],[],[],[],[],[],[]}, varargin];
end

% -------- Parse inputs --------
p = inputParser;
addOptional(p,'pos',defaultPos);
addOptional(p,'fontSize',defaultFontSize);
addOptional(p,'legendFS',defaultLegendFS);
addOptional(p,'lineW',defaultLineWidth);
addOptional(p,'clearTitles',defaultClear);
addOptional(p,'showLegend',defaultShowLeg);
addOptional(p,'showGrid',defaultShowGrid);

addOptional(p,'legendMode',defaultLegendMode, @(x) isempty(x) || ischar(x) || isstring(x));
addOptional(p,'titleMode', defaultTitleMode,  @(x) isempty(x) || ischar(x) || isstring(x));
addOptional(p,'xlabelMode',defaultXLabelMode, @(x) isempty(x) || ischar(x) || isstring(x));
addOptional(p,'ylabelMode',defaultYLabelMode, @(x) isempty(x) || ischar(x) || isstring(x));

addParameter(p,'colormap',[], @(c) isempty(c) || isa(c,'function_handle') || ...
    ischar(c) || isstring(c) || (isnumeric(c) && size(c,2)==3));
addParameter(p,'reducedTemps',[], @(x) isnumeric(x) && isvector(x));
addParameter(p,'legendThreshold',10,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
addParameter(p,'callerName',"",@(x)ischar(x)||isstring(x));
addParameter(p,'fig',[],@(x) isempty(x) || isgraphics(x));
addParameter(p,'forceGrid',false,@islogical);
parse(p,varargin{:});

targetFig = p.Results.fig;
forceGrid = p.Results.forceGrid;

% -------- Extract --------
newPos        = p.Results.pos;
newFontSize   = p.Results.fontSize;
newLegendFS   = p.Results.legendFS;
lineWidth     = p.Results.lineW;
clearTitles   = p.Results.clearTitles;
showLegend    = p.Results.showLegend;
showGrid      = p.Results.showGrid;

legendMode    = string(p.Results.legendMode);
xlabelMode    = string(p.Results.xlabelMode);
ylabelMode    = string(p.Results.ylabelMode);
legendThreshold = p.Results.legendThreshold;
userColormap  = p.Results.colormap;

% -------- Detect caller --------
if strlength(string(p.Results.callerName)) > 0
    callerName = string(p.Results.callerName);
else
    st = dbstack;
    callerName = "";
    if numel(st) >= 2
        callerName = string(st(2).name);
    end
end
cLow = lower(callerName);

% -------- Behavior flags --------
forceLatex      = false;
convertXXXY     = false;
texReplacements = false;
amrPlainLabels  = false;
yOnlyReplace    = false;
isSwitching     = false;

% -------- Caller-based behavior --------
if contains(cLow, {'main_switching','switching_main','switching'})
    convertXXXY     = true;
    texReplacements = true;
    amrPlainLabels  = true;
    isSwitching     = true;

elseif contains(cLow, {'resistivity_main'})
    convertXXXY     = true;
    texReplacements = true;

elseif contains(cLow, {'amr','zfamr','fcamr','field_vs_temp'})
    convertXXXY     = true;
    texReplacements = true;
    amrPlainLabels  = true;

elseif contains(cLow, {'fieldsweep_main'})
    yOnlyReplace    = true;
end

% -------- Legend policy --------
if ~isempty(p.Results.reducedTemps) && showLegend
    showLegend = numel(p.Results.reducedTemps) < legendThreshold;
    legendMode = string( iff(showLegend,'auto','none') );
end

% -------- Process figures --------
if ~isempty(targetFig)
    figs = targetFig;
else
    figs = findall(0,'Type','figure');
end

for fi = 1:numel(figs)
    fig = figs(fi);
    set(fig,'Color','w','Units','normalized','Position',newPos);

    if ~isempty(userColormap)
        colormap(fig,userColormap);
    end

    axesHandles = findall(fig,'Type','axes');
    axesHandles = axesHandles(isgraphics(axesHandles,'axes'));
    hasSubplots = numel(axesHandles) > 1;

    for ai = 1:numel(axesHandles)
        ax = axesHandles(ai);
        if ~isvalid(ax), continue; end

        set(ax,'FontSize',newFontSize,'Color','w');

        if showGrid && (forceGrid || isSwitching || ai == 1)
            ax.XGrid = 'on'; ax.YGrid = 'on';
        else
            ax.XGrid = 'off'; ax.YGrid = 'off';
        end

        box(ax,'on');

        % ---- Legend (FIXED scalar logic) ----
        if (isscalar(legendMode) && strcmpi(legendMode,'none')) || ~showLegend
            delete(findall(ax,'Type','Legend'));
        else
            L = findobj(ax,'Type','line','-depth',1);
            L = L(arrayfun(@(h) ~isempty(get(h,'DisplayName')), L));
            if ~isempty(L)
                lg = legend(ax,L,'Location','eastoutside');
                lg.FontSize = newLegendFS;
                lg.Interpreter = 'tex';
                lg.AutoUpdate = 'off';
            end
        end

        if clearTitles
            title(ax,'','Interpreter','none');
        end

        % ---- Labels ----
        for lblType = ["XLabel","YLabel"]
            lab = get(ax,lblType);
            str = flatstr(lab.String);
            if isempty(str), continue; end

            if hasSubplots && strcmp(lblType,'YLabel') && ~isSwitching
                if isscalar(ylabelMode) && strcmpi(ylabelMode,'none')
                    ylabel(ax,'');
                end
                continue;
            end

            if yOnlyReplace && strcmp(lblType,'YLabel')
                str = regexprep(str,'xx','‖');
                str = regexprep(str,'xy','⊥');
                set(lab,'Interpreter','tex','String',str);
                continue;
            end

            if amrPlainLabels
                set(lab,'Interpreter','tex','String',apply_tex_replacements(str,convertXXXY));
            else
                set(lab,'Interpreter','tex','String',str);
            end

            if strcmp(lblType,'XLabel') && isscalar(xlabelMode) && strcmpi(xlabelMode,'none')
                xlabel(ax,'');
            end
            if strcmp(lblType,'YLabel') && isscalar(ylabelMode) && strcmpi(ylabelMode,'none')
                ylabel(ax,'');
            end
        end
    end
end

% ===================== Helpers ======================
    function y = iff(c,a,b), if c, y=a; else, y=b; end, end

    function s = flatstr(s)
        if iscell(s), s = strjoin(s,' '); end
        s = string(s);
        if numel(s)>1, s = strjoin(s,' '); end
        s = char(s);
    end

    function out = apply_tex_replacements(s,convertXXXY)
        txt = flatstr(s);
        if convertXXXY
            txt = regexprep(txt,'xx\d*','xx');
            txt = regexprep(txt,'xy\d*','xy');
            txt = regexprep(txt,'xx','‖');
            txt = regexprep(txt,'xy','⊥');
        end
        out = txt;
    end
end
