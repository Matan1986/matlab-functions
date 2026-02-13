function convertCartesianFigureToPolar(fig)
% convertCartesianFigureToPolar
% Re-draw Cartesian line plots into a polarplot.
% All visual parameters controlled at the top.

    if nargin < 1
        fig = gcf;
    end

    %% ============================
    %   USER PARAMETERS (EDIT ME)
    %% ============================

    % Figure size + placement
    figWidth   = 600;
    figHeight  = 500;
    centerFigure = true;      % center on screen

    % Fonts
    globalFontSize = 20;      % applies to title, ticks, legend, ylabel, etc.

    % Legend control
    legendLocation = 'northeastoutside';
    legendShiftX   = 0;    % no need for shift when outside

    % Polar axis settings
    thetaZeroLocation = 'right';            % 'top' / 'bottom' / 'left' / 'right'
    thetaDir          = 'counterclockwise'; % 'clockwise' / 'counterclockwise'

    % Y-label manual placement
    ylabelX = -0.25;   % normalized units
    ylabelY = 0.5;

    %% ============================
    %       END USER PARAMETERS
    %% ============================


    %% -------- Extract original figure name --------
    origName = get(fig, 'Name');
    if isempty(origName)
        origName = 'Figure';
    end
    newName = [origName, ' – polar'];   % suffix as requested


    %% -------- Create new figure --------
    screenSize = get(0,'ScreenSize'); % [left bottom width height]

    if centerFigure
        left   = (screenSize(3) - figWidth)/2;
        bottom = (screenSize(4) - figHeight)/2;
    else
        left = 100;
        bottom = 100;
    end

    figPolar = figure('Name', newName, ...
                      'Color','w', ...
                      'Position',[left bottom figWidth figHeight]);

    pax = polaraxes(figPolar);
    hold(pax,'on');

    % Apply polar axis settings
    pax.ThetaZeroLocation = thetaZeroLocation;
    pax.ThetaDir          = thetaDir;

    % Apply font settings to polar axes
    pax.FontSize = globalFontSize;
    pax.ThetaAxis.FontSize = globalFontSize;
    pax.RAxis.FontSize = globalFontSize;


    %% -------- Extraction from original figure --------
    legendEntries = {};
    titleText = "";
    ylabelText = "";

    axList = findall(fig, 'Type', 'axes');

    for ax = axList'

        % Copy title
        t = get(get(ax,'Title'),'String');
        if ~isempty(t)
            titleText = t;
        end

        % Copy ylabel
        yl = get(get(ax,'YLabel'),'String');
        if ~isempty(yl)
            ylabelText = yl;
        end

        % Copy line objects
        lines = findall(ax, 'Type', 'line');

        % ===== DRAW IN REVERSE ORDER =====
        for L = flip(lines')     % <---- reversed drawing order
            theta = L.XData;
            r     = L.YData;

            % Convert degrees→radians if needed
            if max(theta) > 2*pi
                theta = deg2rad(theta);
            end

            polarplot(pax, theta, r, ...
                'LineWidth',  L.LineWidth, ...
                'Color',      L.Color, ...
                'Marker',     L.Marker, ...
                'MarkerSize', L.MarkerSize);

            if ~isempty(L.DisplayName)
                legendEntries{end+1} = L.DisplayName; %#ok<AGROW>
            end
        end
    end

    hold(pax,'off');


  %% -------- Legend (polar-compatible reverse order) --------
if ~isempty(legendEntries)

    % Get line handles exactly as polaraxes stores them
    lineHandles = findall(pax, 'Type', 'line');

    % IMPORTANT: polaraxes stores children in reverse -> fix order
    lineHandles = flip(lineHandles);  

    % Now reverse again to get the order user expects
    lineHandles = flip(lineHandles);  % ← this achieves true reverse

    % Build legend from reversed handles but original labels
    hLeg = legend(lineHandles, flip(legendEntries), ...
                  'Location', legendLocation);

    hLeg.FontSize = globalFontSize;

    % Optional shift
    pos = hLeg.Position;
    pos(1) = pos(1) + legendShiftX;
    hLeg.Position = pos;
end


    %% -------- Title --------
    if titleText ~= ""
        title(pax, titleText, 'FontSize', globalFontSize);
    end


    %% -------- Manual Y-label (left side) --------
    if ylabelText ~= ""
        text(pax, ylabelX, ylabelY, ylabelText, ...
            'Units','normalized', ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontSize', globalFontSize, ...
            'Rotation', 90);
    end

end
