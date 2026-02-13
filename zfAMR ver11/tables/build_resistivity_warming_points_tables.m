function resistivity_warming_points_tables = ...
    build_resistivity_warming_points_tables(warming_points_table, varargin)
% build_resistivity_warming_points_tables
% Channel-agnostic (ch*) version — no hard-coded Rxy*/Rxx* names.
%
% PURPOSE
%   Build per-field tables of resistivity POINTS at each requested temperature
%   for the warming branch. Output tables have columns:
%       Angle, Indices, <one matrix column per channel key>
%   Each channel column is an [numAngles x numTemps] matrix (values at the
%   temperature-sampled indices).
%
% CALLING FORMS
%   1) New (recommended):
%        % chans is a struct with any subset/superset of ch* vectors:
%        chans = struct('ch1', ch1, 'ch2', ch2, 'ch3', ch3, 'ch4', ch4);
%        numTemps = length(temp_values);
%        out = build_resistivity_warming_points_tables(wpt_cell, chans, numTemps);
%
%   2) Legacy (backward compatible with your old signature):
%        out = build_resistivity_warming_points_tables(wpt_cell, Rxy1, Rxx2, Rxy3, Rxx4, numTemps);
%      Internally mapped to:
%        chans = struct('ch1', Rxy1, 'ch2', Rxx2, 'ch3', Rxy3, 'ch4', Rxx4);
%
% INPUTS
%   warming_points_table : cell array; each cell is a table for a field, with:
%       - Angle    : vector of angles
%       - Indices  : (optional/pass-through) as in your pipeline
%       - T1..Tn   : integer indices into the raw channel vectors, one column per temperature
%   varargin             : either (chansStruct, numTemps) OR (Rxy1, Rxx2, Rxy3, Rxx4, numTemps)
%
% OUTPUT
%   resistivity_warming_points_tables : cell array (one table per field)
%       Table variables: Angle, Indices, and one matrix column per channel key
%       Matrix size: [numAngles x numTemps]
%
% NOTES
%   - If a channel vector is missing or size-mismatched, it will be ignored.
%   - The function only uses the index columns (T1..Tn) in the input tables.

    % ---------- Parse inputs (new vs legacy) ----------
    if numel(varargin) == 2 && isstruct(varargin{1})
        chans    = varargin{1};
        numTemps = varargin{2};
    elseif numel(varargin) == 5 && ~isstruct(varargin{1})
        chans    = struct('ch1', varargin{1}, 'ch2', varargin{2}, ...
                          'ch3', varargin{3}, 'ch4', varargin{4});
        numTemps = varargin{5};
    else
        error(['build_resistivity_warming_points_tables: invalid inputs.\n' ...
               'Use either:\n' ...
               '  build_resistivity_warming_points_tables(wpt_cell, chansStruct, numTemps)\n' ...
               'or legacy:\n' ...
               '  build_resistivity_warming_points_tables(wpt_cell, Rxy1, Rxx2, Rxy3, Rxx4, numTemps)']);
    end

    % Keep only valid channels (numeric vectors, non-empty)
    allKeys = fieldnames(chans);
    keep = false(size(allKeys));
    for i = 1:numel(allKeys)
        v = chans.(allKeys{i});
        keep(i) = isnumeric(v) && isvector(v) && ~isempty(v);
    end
    chKeys = allKeys(keep);  % e.g., {'ch1','ch2'}

    % Precompute temperature column labels expected in the input tables
    tempLabels = arrayfun(@(k) sprintf('T%d',k), 1:numTemps, 'UniformOutput', false);

    % ---------- Build output per field ----------
    nFields = numel(warming_points_table);
    resistivity_warming_points_tables = cell(nFields,1);

    for f = 1:nFields
        fwpt = warming_points_table{f};
        if ~istable(fwpt)
            resistivity_warming_points_tables{f} = table();
            continue;
        end

        % Basic columns
        Angles = fwpt.Angle;
        Inds   = [];
        if ismember('Indices', fwpt.Properties.VariableNames)
            Inds = fwpt.Indices;
        else
            % keep shape-compatible placeholder if needed
            Inds = repmat({[]}, size(Angles));
        end

        nA = numel(Angles);

        % Prepare one matrix per channel key (angles x numTemps)
        chanMats = struct();
        for c = 1:numel(chKeys)
            chanMats.(chKeys{c}) = nan(nA, numTemps);
        end

        % Fill matrices using the table indices T1..TnumTemps
        for a = 1:nA
            for t = 1:numTemps
                colName = tempLabels{t};
                if ~ismember(colName, fwpt.Properties.VariableNames)
                    error('Missing column "%s" in warming_points_table{%d}.', colName, f);
                end
                idx = fwpt.(colName)(a);
                if ~isnan(idx) && idx >= 1
                    for c = 1:numel(chKeys)
                        key = chKeys{c};
                        v = chans.(key);
                        if idx <= numel(v)
                            chanMats.(key)(a,t) = v(idx);
                        end
                    end
                end
            end
        end

        % Assemble output table with dynamic channel columns named by chKeys
        varNames = [{'Angle','Indices'}, chKeys(:)'];
        cols = {Angles, Inds};
        for c = 1:numel(chKeys)
            cols{end+1} = chanMats.(chKeys{c}); %#ok<AGROW>
        end
        resistivity_warming_points_tables{f} = table(cols{:}, 'VariableNames', varNames);
    end
end
