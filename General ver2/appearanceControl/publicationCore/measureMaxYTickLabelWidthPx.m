function maxWidthPx = measureMaxYTickLabelWidthPx(ax)
% MEASUREMAXYTICKLABELWIDTHPX Measure maximum Y tick-label width in pixels.
%
% Signature:
%   maxWidthPx = measureMaxYTickLabelWidthPx(ax)
%
% Behavior:
% - Reads ax.YTickLabel
% - Creates temporary invisible text objects with axis tick-label typography
% - Tracks max text extent width (Extent(3)) in pixels
% - Deletes temporary objects
% - Returns 0 when no measurable labels are present
%
% Constraints:
% - Stateless (no persistent/global state)
% - No geometry changes

    maxWidthPx = 0;

    if nargin < 1 || isempty(ax) || ~isgraphics(ax, 'axes')
        return;
    end

    rawLabels = [];
    try
        rawLabels = ax.YTickLabel;
    catch
    end

    labels = strings(0,1);
    if isstring(rawLabels)
        labels = rawLabels(:);
    elseif ischar(rawLabels)
        labels = string(cellstr(rawLabels));
    elseif iscell(rawLabels)
        try
            labels = string(rawLabels(:));
        catch
            labels = strings(0,1);
        end
    end

    if isempty(labels)
        try
            ticks = double(ax.YTick);
            if ~isempty(ticks)
                labels = compose('%g', ticks(:));
            end
        catch
        end
    end

    if isempty(labels)
        return;
    end

    tickInterpreter = 'tex';
    tickFontName = 'Helvetica';
    tickFontSize = 11;
    tickFontWeight = 'normal';
    tickFontAngle = 'normal';

    try
        if isprop(ax, 'TickLabelInterpreter')
            tickInterpreter = char(ax.TickLabelInterpreter);
        end
    catch
    end
    try
        if isprop(ax, 'FontName') && ~isempty(ax.FontName)
            tickFontName = char(ax.FontName);
        end
    catch
    end
    try
        if isprop(ax, 'FontSize') && isfinite(double(ax.FontSize)) && double(ax.FontSize) > 0
            tickFontSize = double(ax.FontSize);
        end
    catch
    end
    try
        if isprop(ax, 'FontWeight') && ~isempty(ax.FontWeight)
            tickFontWeight = char(ax.FontWeight);
        end
    catch
    end
    try
        if isprop(ax, 'FontAngle') && ~isempty(ax.FontAngle)
            tickFontAngle = char(ax.FontAngle);
        end
    catch
    end

    for iLbl = 1:numel(labels)
        lblText = string(labels(iLbl));
        if strlength(lblText) == 0
            continue;
        end

        t = [];
        try
            t = text(ax, 0, 0, char(lblText), ...
                'Units', 'pixels', ...
                'Visible', 'off', ...
                'Interpreter', tickInterpreter, ...
                'FontName', tickFontName, ...
                'FontSize', tickFontSize, ...
                'FontWeight', tickFontWeight, ...
                'FontAngle', tickFontAngle, ...
                'HandleVisibility', 'off', ...
                'HitTest', 'off');

            ext = double(t.Extent);
            if isnumeric(ext) && numel(ext) >= 3 && isfinite(ext(3))
                maxWidthPx = max(maxWidthPx, ext(3));
            end
        catch
        end

        if ~isempty(t) && isgraphics(t)
            try
                delete(t);
            catch
            end
        end
    end
end
