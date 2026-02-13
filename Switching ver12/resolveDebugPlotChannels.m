function plotChannels_out = resolveDebugPlotChannels( ...
    plotChannels_in, switchCh, debugMode, onlyActive)

plotChannels_out = plotChannels_in;

% Only modify behavior in debug mode
if ~debugMode || ~onlyActive || ~isfinite(switchCh)
    return
end

% --- struct case (ch1, ch2, ...) ---
if isstruct(plotChannels_out)
    fn = fieldnames(plotChannels_out);

    % turn all OFF
    for k = 1:numel(fn)
        plotChannels_out.(fn{k}) = false;
    end

    % turn ON switching channel
    key = sprintf('ch%d', switchCh);
    if isfield(plotChannels_out, key)
        plotChannels_out.(key) = true;
    end

% --- vector / logical case ---
else
    plotChannels_out(:) = false;
    plotChannels_out(switchCh) = true;
end
