function resistivity_deviation_percent_tables = calculate_resistivity_deviation_percent( ...
    resistivity_points_tables, resistivity_points_averages, Normalize_to, ...
    angles_to_exclude_within_specific_field, fields, channelKeys)
% calculate_resistivity_deviation_percent  (vectorized normalization per table)
%
% Normalize_to can be:
%   • scalar numeric   -> same physical reference for all channels (e.g., 2 means ch2)
%   • numeric vector   -> per-channel physical reference (length == #channels in table)
%   • cellstr/strings  -> per-channel names matching keysF (length == #channels)
%
% Examples:
%   Normalize_to = 2                 % all channels normalized to physical ch2
%   Normalize_to = [2 2 1 2]         % per-channel physical refs
%   Normalize_to = {'ch2','ch2'}     % per-channel by local names (keysF)
%
% Notes:
% - keysF is determined from each table's variable names (excluding 'Angle','Indices'),
%   unless channelKeys is supplied (then it is intersected with table vars).
% - Physical indices are translated to local indices (of keysF) per table.

    nFields = numel(resistivity_points_tables);
    resistivity_deviation_percent_tables = cell(nFields, 1);

    if nargin < 6
        channelKeys = []; % auto-detect later
    end

    for f = 1:nFields
        pts = resistivity_points_tables{f};
        avs = resistivity_points_averages{f};

        if ~istable(pts) || isempty(pts) || ~istable(avs) || isempty(avs)
            resistivity_deviation_percent_tables{f} = table();
            continue;
        end

        % ---- Determine keysF (the local channel list for this table) ----
        if isempty(channelKeys)
            keysF = setdiff(pts.Properties.VariableNames, {'Angle','Indices'}, 'stable');
        else
            keysF = channelKeys(ismember(channelKeys, pts.Properties.VariableNames));
        end

        % If no channel columns, return empty table
        if isempty(keysF)
            resistivity_deviation_percent_tables{f} = pts(:, intersect({'Angle','Indices'}, pts.Properties.VariableNames, 'stable'));
            continue;
        end

        % ---- Resolve Normalize_to to local indices (1..numel(keysF)) ----
        normIdxVec = resolve_norm_indices(Normalize_to, keysF);

        % ---- Exclude unwanted angles (only for this field) ----
        keepMask = true(height(pts), 1);
        if ~isempty(angles_to_exclude_within_specific_field)
            for ex = angles_to_exclude_within_specific_field(:).'
                if isstruct(ex) && isfield(ex,'field') && isfield(ex,'angles') && ...
                        ~any(isnan([ex.field])) && ismember('Angle', pts.Properties.VariableNames)
                    if abs(fields(f) - ex.field) <= eps
                        keepMask = keepMask & ~ismember(pts.Angle, ex.angles);
                    end
                end
            end
        end
        pts = pts(keepMask, :);

        % ---- Build output table skeleton ----
        outVars = {'Angle','Indices'};
        outCols = cell(1, numel(outVars));
        if ismember('Angle', pts.Properties.VariableNames), outCols{1} = pts.Angle; else, outCols{1} = []; end
        if ismember('Indices', pts.Properties.VariableNames), outCols{2} = pts.Indices; else, outCols{2} = []; end

        % ---- Compute deviations per channel ----
        for k = 1:numel(keysF)
            key = keysF{k};
            refIdx = normIdxVec(k);                      % local reference index (1..numel(keysF))
            if refIdx < 1 || refIdx > numel(keysF)
                error('Invalid Normalize_to index %d for channel %s (keysF length = %d).', refIdx, key, numel(keysF));
            end
            refKey = keysF{refIdx};

            if ~ismember(key, avs.Properties.VariableNames)
                error('Channel key "%s" not found in averages.', key);
            end
            if ~ismember(refKey, avs.Properties.VariableNames)
                error('Reference key "%s" not found in averages.', refKey);
            end

            % channel values: Y [nAngles x nTemps], its mean mu [1 x nTemps], and ref mean refVec [1 x nTemps]
            Y      = pts.(key);
            mu     = avs.(key);
            refVec = avs.(refKey);

            % Deviation = (Y - mu) / refVec * 100  (vectorized across temps)
            dev = bsxfun(@minus, Y, mu);
            dev = bsxfun(@rdivide, dev, refVec);
            dev = dev * 100;

            outVars{end+1} = key; %#ok<AGROW>
            outCols{end+1} = dev; %#ok<AGROW>
        end

        % ---- Assemble output table ----
        resistivity_deviation_percent_tables{f} = table(outCols{:}, 'VariableNames', outVars);
    end
end