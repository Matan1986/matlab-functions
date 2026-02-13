function fit_sine_from_legend
% FIT_SINE_FROM_LEGEND
%   1) Open your figure with the plotted curves.
%   2) Run >> fit_sine_from_legend
%   3) Pick the curve name in the pop-up list.
%   4) Curve Fitter will launch with numeric xForFit/yForFit.

    % 1) Grab the figure’s first axes
    fig   = gcf;
    axAll = findobj(fig,'Type','axes');
    if isempty(axAll)
        error('No axes found in the current figure.');
    end
    ax = axAll(1);

    % 2) Find all plotted lines
    lines = findobj(ax,'Type','line');
    if isempty(lines)
        error('No line plots found.');
    end

    % 3) Read legend entries
    lg = legend(ax);
    if isempty(lg) || isempty(lg.String)
        error('Please add a legend to your plot before running this.');
    end
    legendTexts = lg.String;

    % 4) Align order with plot order
    lines = flip(lines);

    % 5) Let user select one curve
    [idx, ok] = listdlg( ...
       'PromptString', 'Select a curve to fit:', ...
       'ListString',  legendTexts, ...
       'SelectionMode','single' ...
    );
    if ~ok
        disp('User cancelled.');
        return;
    end

    % 6) Extract raw data
    selLine = lines(idx);
    x_raw   = selLine.XData(:);
    y_raw   = selLine.YData(:);

    % 7) Convert to pure numeric
    xForFit = convertForFit(x_raw, 'XData');
    yForFit = convertForFit(y_raw, 'YData');

    % 8) Send to base workspace & launch Curve Fitter
    assignin('base','xForFit', xForFit);
    assignin('base','yForFit', yForFit);
    evalin('base','cftool xForFit yForFit sin2');
end

function v = convertForFit(arr, name)
% Converts different data types into a numeric vector v
    if isnumeric(arr)
        v = double(arr);

    elseif isdatetime(arr)
        v = datenum(arr);

    elseif isduration(arr)
        % convert durations to seconds
        v = seconds(arr);

    elseif iscategorical(arr)
        s = string(arr);
        v = str2double(s);

    elseif isstring(arr)
        v = str2double(arr);

    elseif iscell(arr)
        % assume cell array of numeric strings
        v = cellfun(@str2double, arr);

    else
        error('Cannot convert %s of class %s to numeric.', name, class(arr));
    end

    if any(isnan(v))
        warning('Some elements of %s converted to NaN—check your data.', name);
    end
end
