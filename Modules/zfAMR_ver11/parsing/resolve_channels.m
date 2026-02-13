function [keys, labels] = resolve_channels(plotChannels)
% Returns:
%   keys   - cellstr of variable names inside the tables
%   labels - cellstr of pretty labels for title/legend

    % --- struct of flags (possibly with extra fields like .labels) ---
    if isstruct(plotChannels)
        keys   = {};
        labels = {};

        % optional nested label map
        label_map = [];
        if isfield(plotChannels,'labels') && isstruct(plotChannels.labels)
            label_map = plotChannels.labels;
        end

        fns = fieldnames(plotChannels);
        for i = 1:numel(fns)
            fn = fns{i};
            if strcmp(fn,'labels'), continue; end  % skip nested labels container

            val = plotChannels.(fn);
            is_flag = (islogical(val) || isnumeric(val)) && isscalar(val);
            if is_flag && logical(val)
                keys{end+1} = fn; %#ok<AGROW>
                if ~isempty(label_map) && isfield(label_map, fn)
                    lbl = label_map.(fn);
                    if isstring(lbl), lbl = char(lbl); end
                    labels{end+1} = lbl; %#ok<AGROW>
                else
                    labels{end+1} = pretty_label(fn); %#ok<AGROW>
                end
            end
        end
        return
    end

    % --- list of keys (string array / cellstr) ---
    if isstring(plotChannels) || iscellstr(plotChannels)
        keys = cellstr(plotChannels);
        labels = cellfun(@pretty_label, keys, 'UniformOutput', false);
        return
    end

    % --- Nx2 {key,label} table ---
    if iscell(plotChannels) && size(plotChannels,2) == 2
        keys   = plotChannels(:,1);
        labels = plotChannels(:,2);
        if isstring(keys),   keys   = cellstr(keys);   end
        if isstring(labels), labels = cellstr(labels); end
        return
    end

    % Fallback
    keys = {};
    labels = {};
end
