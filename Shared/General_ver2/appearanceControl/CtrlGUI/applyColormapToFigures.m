function applyColormapToFigures(mapName, folder, spreadMode, ...
    fitColor, dataWidth, dataStyle, fitWidth, fitStyle, ...
    reverseOrder, reverseLegend, noMapChange, markerSize)

% APPLYCOLORMAPTOFIGURES

if nargin < 2 || isempty(folder),     folder       = [];      end
if nargin < 3 || isempty(spreadMode), spreadMode   = 'start'; end
if nargin < 4
    fitColor = 'black';      % backward compatibility
end
% אם fitColor='' → לא נחליף צבעים
if nargin < 5, dataWidth    = [];  end
if nargin < 6, dataStyle    = '';  end
if nargin < 7, fitWidth     = [];  end
if nargin < 8, fitStyle     = '';  end
if nargin < 9, reverseOrder = 0;   end
if nargin < 10, reverseLegend = 0; end
if nargin < 11, noMapChange = 0;   end
if nargin < 12
    markerSize = [];
end
%% --- אם לא רוצים לשנות מפה: cmapFull ריק ---
if noMapChange
    cmapFull = [];   % applyToSingleFigure יבין מזה "לא לגעת ב-colormap"

else
    %% --- custom colormaps --- 
    custom = {
        'softyellow'
        'softgreen'
        'softred'
        'softblue'
        'softpurple'
        'softorange'
        'softcyan'
        'softgray'
        'softbrown'
        'softteal'
        'softolive'
        'softgold'
        'softpink'
        'softaqua'
        'softsand'
        'softsky'
        'bluebright'
        'redbright'
        'greenbright'
        'purplebright'
        'orangebright'
        'cyanbright'
        'yellowbright'
        'magnetabright'
        'limebright'
        'tealbright'
        'ultrabrightblue'
        'ultrabrightred'
        'bluewhitered'
        'redwhiteblue'
        'purplewhitegreen'
        'brownwhiteblue'
        'greenwhitepurple'
        'bluewhiteorange'
        'blackwhiteyellow'
        'fire'
        'ice'
        'ocean'
        'topo'
        'terrain'
        'magma'
        'inferno'
        'plasma'
        'cividis'
    };

    %% --- יצירת colormap --- 
    if any(strcmpi(mapName, custom))
        cmapFull = makeCustomColormap(mapName);
    else
        try
            if exist(mapName,'builtin') || exist(mapName,'file')
                cmapFull = feval(mapName,256);
            elseif contains(lower(mapName),'cmocean')
                cmapFull = eval(mapName);
            else
                error('Unknown colormap name "%s".', mapName);
            end
        catch ME
            error('Invalid colormap: %s', ME.message);
        end
    end
end

%% --- Apply to figs (גם כש-cmapFull ריק) ---
if isempty(folder)
    figList = findall(0,'Type','figure');
    for fig = figList'
        applyToSingleFigure(fig, cmapFull, spreadMode, ...
            fitColor, dataWidth, dataStyle, fitWidth, fitStyle, ...
            reverseOrder, reverseLegend, markerSize);
    end
else
    files = dir(fullfile(folder,'*.fig'));
    for k = 1:numel(files)
        f = openfig(fullfile(folder,files(k).name),'invisible');
        applyToSingleFigure(f, cmapFull, spreadMode, ...
            fitColor, dataWidth, dataStyle, fitWidth, fitStyle, ...
            reverseOrder, reverseLegend,markerSize);
        savefig(f, fullfile(folder,files(k).name));
        close(f);
    end
end

end
