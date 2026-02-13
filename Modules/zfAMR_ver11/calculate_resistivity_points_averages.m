function resistivity_points_averages = calculate_resistivity_points_averages( ...
    resistivity_points_tables, angles_to_exclude_within_specific_field, fields, channelKeys)
% calculate_resistivity_points_averages
% Channel-agnostic (ch*), no hard-coded Rxy*/Rxx* names.
%
% PURPOSE
%   For each field (cell), compute the mean (over angles) of every channel matrix
%   at each temperature, optionally excluding specific angles for specific fields.
%
% INPUTS
%   resistivity_points_tables : cell array; each cell a table with columns:
%       - Angle     : [nAngles x 1]
%       - Indices   : (optional/pass-through; ignored here)
%       - ch*       : for each channel key (e.g., 'ch1','ch2',...), an [nAngles x nTemps] matrix
%   angles_to_exclude_within_specific_field : struct array, e.g.
%       [ struct('field', 11, 'angles', [90 180]), struct('field', NaN, 'angles', NaN) ]
%       If |fields(f) - ex.field| <= eps, rows with those angles are excluded for that field.
%   fields : [nFields x 1] vector of field values corresponding to each cell
%
% OPTIONAL
%   channelKeys : cellstr of channel variable names to process.
%                 If omitted/empty, auto-detect channel columns as all vars minus {'Angle','Indices'}.
%
% OUTPUT
%   resistivity_points_averages : cell array (length = numel(resistivity_points_tables))
%       Each cell is a table with one row, columns named exactly by channel keys.
%       Each entry is a [1 x nTemps] row vector (mean across angles, NaN-safe).

    nFields = numel(resistivity_points_tables);
    resistivity_points_averages = cell(nFields, 1);

    % Normalize exclusion config
    if nargin < 2 || isempty(angles_to_exclude_within_specific_field)
        angles_to_exclude_within_specific_field = struct('field', NaN, 'angles', NaN);
    end
    if nargin < 4
        channelKeys = [];
    end

    % Choose nan-mean function (compat with older MATLAB)
    useMeanOmit = ~isempty(which('mean')); %#ok<*EMCA>
    for f = 1:nFields
        T = resistivity_points_tables{f};
        if ~istable(T) || isempty(T)
            resistivity_points_averages{f} = table();
            continue;
        end

        % Determine channel columns (preserve requested order if provided)
        if isempty(channelKeys)
            varNames = T.Properties.VariableNames;
            channelKeys_f = setdiff(varNames, {'Angle','Indices'}, 'stable');
        else
            channelKeys_f = channelKeys(ismember(channelKeys, T.Properties.VariableNames));
        end

        % If no channel columns, return empty 1x0 table
        if isempty(channelKeys_f)
            resistivity_points_averages{f} = table();
            continue;
        end

        % Apply angle exclusions for this field (if any match)
        keepMask = true(height(T), 1);
        for ex = angles_to_exclude_within_specific_field(:).'
            if ~isstruct(ex) || ~isfield(ex,'field') || ~isfield(ex,'angles') || any(isnan([ex.field]))
                continue;
            end
            if abs(fields(f) - ex.field) <= eps && ismember('Angle', T.Properties.VariableNames)
                keepMask = keepMask & ~ismember(T.Angle, ex.angles);
            end
        end
        T = T(keepMask, :);

        % Compute NaN-safe mean across angles for each channel
        avgRow = cell(1, numel(channelKeys_f));
        for c = 1:numel(channelKeys_f)
            key = channelKeys_f{c};
            M = T.(key);  % [nAngles x nTemps]
            if isempty(M)
                avgRow{c} = nan(1, 0);
                continue;
            end
            % Ensure 2-D; mean over angle dimension (1)
            if useMeanOmit
                try
                    m = mean(M, 1, 'omitnan');
                catch
                    m = nanmean(M, 1); %#ok<NANMEAN>
                end
            else
                m = nanmean(M, 1); %#ok<NANMEAN>
            end
            % Force row vector shape [1 x nTemps]
            avgRow{c} = reshape(m, 1, []);
        end

        % Build a one-row output table with columns named by channel keys
        resistivity_points_averages{f} = cell2table(avgRow, 'VariableNames', channelKeys_f);
    end
end
