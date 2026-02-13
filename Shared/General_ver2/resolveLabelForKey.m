function lbl = resolveLabelForKey(key, channelLabels, plotChannels)
% Priority:
% 1) channelLabels.(key) if struct, or channelLabels(key) if containers.Map
% 2) plotChannels.labels.(key) if present
% 3) fallback to key itself
    lbl = key;
    try
        if ~isempty(channelLabels)
            if isstruct(channelLabels) && isfield(channelLabels, key)
                lbl = channelLabels.(key); return;
            elseif isa(channelLabels, 'containers.Map') && isKey(channelLabels, key)
                lbl = channelLabels(key); return;
            end
        end
        if isstruct(plotChannels) && isfield(plotChannels,'labels') && ...
           isstruct(plotChannels.labels) && isfield(plotChannels.labels, key)
            lbl = plotChannels.labels.(key); return;
        end
    catch
        % fall back silently
    end
    if isstring(lbl), lbl = char(lbl); end
end