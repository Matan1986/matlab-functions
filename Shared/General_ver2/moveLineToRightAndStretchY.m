function axR = moveLineToRightAndStretchY(fig, lineSelector, stretchFactor, rightAxisFontScale)
% moveLineToRightAndStretchY
%
% ✔ Deletes existing legend
% ✔ Controls LEFT and RIGHT Y-axis colors explicitly
% ✔ X-axis completely untouched
% ✔ Data unchanged
% ✔ Stretch = YLim tightening only
%
% INPUTS
% ------
% fig                : figure handle (gcf)
% lineSelector       : line index (1,2,...) OR DisplayName
% stretchFactor      : >1 (e.g. 1.5, 2, 3)
% rightAxisFontScale : font multiplier for right Y-axis (default 1.1)
%
% OUTPUT
% ------
% axR : handle to right Y-axis

    arguments
        fig (1,1) matlab.ui.Figure
        lineSelector
        stretchFactor (1,1) double {mustBeGreaterThan(stretchFactor,1)}
        rightAxisFontScale (1,1) double {mustBeGreaterThan(rightAxisFontScale,1)} = 1.1
    end

    % =================================================
    % 0) Delete existing legend (explicitly)
    % =================================================
    delete(findall(fig,'Type','legend'));

    % =================================================
    % 1) Find axes with lines
    % =================================================
    allAxes = findall(fig,'Type','axes');
    axL = [];

    for k = 1:numel(allAxes)
        if ~isempty(findall(allAxes(k),'Type','line'))
            axL = allAxes(k);
            break
        end
    end
    assert(~isempty(axL),'No axes with line objects found.');

    % =================================================
    % 2) Get all lines on left axis
    % =================================================
    lines = findall(axL,'Type','line');
    assert(numel(lines) >= 2, 'Need at least two lines.');

    % ---- select line to move ----
    if isnumeric(lineSelector)
        hMove = lines(lineSelector);
    else
        idx = find(strcmp({lines.DisplayName}, string(lineSelector)));
        assert(~isempty(idx),'No matching DisplayName.');
        hMove = lines(idx(1));
    end

    % ---- remaining line stays on left ----
    hLeft = setdiff(lines, hMove);
    hLeft = hLeft(1);   % assume one dominant left line

    % =================================================
    % 3) Colors
    % =================================================
    colorLeft  = hLeft.Color;
    colorRight = hMove.Color;

    % =================================================
    % 4) Create RIGHT Y-axis (X fully locked)
    % =================================================
    axR = axes('Parent',fig,...
        'Position',axL.Position,...
        'Color','none',...
        'YAxisLocation','right');

    axR.XLim     = axL.XLim;
    axR.XLimMode = 'manual';
    axR.XColor   = 'none';
    axR.XTick    = [];
    axR.XLabel   = [];

    % =================================================
    % 5) Move line to right axis
    % =================================================
    hMove.Parent = axR;

    % =================================================
    % 6) Stretch in Y (visual only)
    % =================================================
    yData = hMove.YData;
    yData = yData(isfinite(yData));

    yCenter   = mean(yData);
    halfRange = max(abs(yData - yCenter));

    axR.YLim = [yCenter - halfRange/stretchFactor, ...
                yCenter + halfRange/stretchFactor];

    % =================================================
    % 7) Copy Y-label text
    % =================================================
    axR.YLabel.String      = axL.YLabel.String;
    axR.YLabel.Interpreter = axL.YLabel.Interpreter;

    % =================================================
    % 8) Apply colors & fonts EXPLICITLY
    % =================================================
    % Left axis
    axL.YLabel.Color = colorLeft;

    % Right axis
    axR.YLabel.Color = colorRight;
    axR.FontSize     = axL.FontSize * rightAxisFontScale;

    % =================================================
    % 9) Cleanup
    % =================================================
    axL.Box = 'off';
    axR.Box = 'off';
    axR.Tag = 'RightAxis';
end
