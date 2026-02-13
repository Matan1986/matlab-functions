function latexColorbarHorizontal(cb, fs)
    % latexColorbarHorizontal(cb, fs)
    %
    % Converts a horizontal colorbar's ticks + label to LaTeX manually.

    if nargin < 1 || isempty(cb)
        cb = findall(gcf,'Type','Colorbar');
        if isempty(cb)
            error('No colorbar found.');
        end
        cb = cb(1);
    end

    if nargin < 2
        fs = 18;
    end

    fig = ancestor(cb, 'figure');

    % -----------------------
    % 1. Hide original ticks
    % -----------------------
    cb.TickLabels = repmat({''}, size(cb.Ticks));

    % -----------------------
    % 2. Fix Label
    % -----------------------
    if ~isempty(cb.Label.String)
        cb.Label.Interpreter = 'latex';
        cb.Label.String      = sanitizeLatexString(cb.Label.String);
        cb.Label.FontSize    = fs;
    end

    % Numeric ticks
    ticks = cb.Ticks;

    % Colorbar normalized position
    pos = cb.Position;

    % ------------------------------------------------------------
    % 3. Create an invisible axes covering the whole figure window
    % ------------------------------------------------------------
    axOverlay = axes('Position',[0 0 1 1], ...
                     'Color','none', ...
                     'XLim',[0 1], 'YLim',[0 1], ...
                     'XTick',[], 'YTick',[], ...
                     'HitTest','off', ...
                     'Visible','off');
    % Keep this axes in back
    uistack(axOverlay,'bottom');

    % Offset downward (as needed)
    yOffset = pos(2) - 0.05;   % tweakable

    % ------------------------------------------------------------
    % 4. Draw LaTeX tick labels using overlay axes
    % ------------------------------------------------------------
    for j = 1:numel(ticks)

        lbl = sanitizeLatexString(num2str(ticks(j)));

        % Compute normalized X location
        tNorm = (ticks(j) - ticks(1)) / (ticks(end) - ticks(1));
        xFig = pos(1) + tNorm * pos(3);
        yFig = yOffset;

        text(axOverlay, xFig, yFig, lbl, ...
            'Interpreter', 'latex', ...
            'FontSize', fs, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','top');
    end
end


function out = sanitizeLatexString(in)
    if isstring(in)
        in = char(in);
    elseif iscell(in)
        in = in{1};
    end

    in = strtrim(in);

    % Already wrapped in math mode?
    if numel(in)>=2 && in(1)=='$' && in(end)=='$'
        out = in;
        return;
    end

    % Escape underscores
    in = strrep(in,'_','\_');

    out = ['$' in '$'];
end
