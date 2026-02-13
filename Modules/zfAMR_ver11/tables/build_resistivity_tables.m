function [resistivity_warming_tables, resistivity_cooling_tables] = ...
    build_resistivity_tables(warming_tables, cooling_tables, TemperatureK, varargin)
% build_resistivity_tables
% General, channel-agnostic (ch*) version.
%
% PURPOSE
%   Build per-field tables of resistivity data for warming and cooling,
%   using logical channel names (e.g., 'ch1','ch2','ch3','ch4'), without any
%   hard-coded 'Rxy*'/'Rxx*' anywhere.
%
% CALLING FORMS
%   1) New (recommended, channel-agnostic):
%        chans = struct('ch1', ch1, 'ch2', ch2, 'ch3', ch3, 'ch4', ch4); % any subset ok
%        [warmTbls, coolTbls] = build_resistivity_tables(warming_tables, cooling_tables, TemperatureK, chans);
%
%      You may pass any subset/superset of 'ch*' fields (e.g., 'ch1','ch2' only).
%      The function will create columns exactly for the fields present in 'chans'.
%
%   2) Backward-compat (legacy 4 inputs like your old function signature):
%        [warmTbls, coolTbls] = build_resistivity_tables(warming_tables, cooling_tables, TemperatureK, Rxy1, Rxx2, Rxy3, Rxx4);
%      This will be internally mapped to:
%        chans.ch1 = Rxy1;  chans.ch2 = Rxx2;  chans.ch3 = Rxy3;  chans.ch4 = Rxx4;
%
% INPUTS
%   warming_tables, cooling_tables : cell arrays; each cell is a table with fields:
%       - Angle   : vector of target angles for that field
%       - Indices : cell array; each cell contains [startIdx endIdx] rows to extract
%   TemperatureK : vector of temperatures per raw index (same length as channel vectors)
%   varargin     : either a single struct of channels OR 4 numeric vectors (legacy)
%
% OUTPUTS
%   resistivity_warming_tables : cell array of tables, one per field (warming)
%   resistivity_cooling_tables : cell array of tables, one per field (cooling)
%       Each table has columns:
%           Angle, Indices, Temperature, <one column per channel key in 'chans'>
%       Channel column names are exactly the fieldnames in your 'chans' struct (e.g., 'ch1','ch2',...).
%
% NOTES
%   - If a channel vector is empty or missing from 'chans', no column is created for it.
%   - Indices are assumed valid; the function concatenates data across all [start end] blocks per angle.

    % -------- Parse channels from varargin (new vs legacy) --------
    if numel(varargin) == 1 && isstruct(varargin{1})
        chans = varargin{1};                        % new API
    elseif numel(varargin) == 4                     % legacy API: Rxy1, Rxx2, Rxy3, Rxx4
        chans = struct('ch1', varargin{1}, ...
                       'ch2', varargin{2}, ...
                       'ch3', varargin{3}, ...
                       'ch4', varargin{4});
    else
        error(['build_resistivity_tables: invalid inputs. Use either:\n' ...
               '  build_resistivity_tables(warming_tables, cooling_tables, TemperatureK, chansStruct)\n' ...
               'or legacy 4-channel form:\n' ...
               '  build_resistivity_tables(..., Rxy1, Rxx2, Rxy3, Rxx4)']);
    end

    % Keep only valid channel fields that are numeric vectors matching TemperatureK length
    allKeys = fieldnames(chans);
    keepMask = false(size(allKeys));
    for i = 1:numel(allKeys)
        v = chans.(allKeys{i});
        keepMask(i) = isnumeric(v) && isvector(v) && (numel(v) == numel(TemperatureK));
    end
    chKeys = allKeys(keepMask);  % final list of channel names to include (e.g., {'ch1','ch2'})

    % Pre-allocate outputs
    resistivity_warming_tables = cell(numel(warming_tables), 1);
    resistivity_cooling_tables = cell(numel(cooling_tables), 1);

    % -------- Build WARMING tables --------
    for f = 1:numel(warming_tables)
        fieldTbl = warming_tables{f};
        Angles  = fieldTbl.Angle;
        Indices = fieldTbl.Indices;

        % Per-angle containers
        Temperatures = cell(size(Indices));
        chanCells    = initChannelCells(chKeys, size(Indices));

        for a = 1:numel(Indices)
            idxBlocks = Indices{a};
            % Containers to accumulate for this angle
            temp_vals = [];

            angleChanVals = initChannelAccumulators(chKeys);

            for k = 1:size(idxBlocks, 1)
                r1 = idxBlocks(k,1); r2 = idxBlocks(k,2);
                temp_vals = [temp_vals; TemperatureK(r1:r2)]; %#ok<AGROW>
                % Append each channel’s segment
                for c = 1:numel(chKeys)
                    key = chKeys{c};
                    angleChanVals.(key) = [angleChanVals.(key); chans.(key)(r1:r2)]; %#ok<AGROW>
                end
            end

            Temperatures{a} = temp_vals;
            % store per-channel cell arrays
            for c = 1:numel(chKeys)
                key = chKeys{c};
                chanCells.(key){a} = angleChanVals.(key);
            end
        end

        % Assemble table with dynamic channel columns
        resistivity_warming_tables{f} = assembleOutputTable(Angles, Indices, Temperatures, chanCells, chKeys);
    end

    % -------- Build COOLING tables --------
    for f = 1:numel(cooling_tables)
        fieldTbl = cooling_tables{f};
        Angles  = fieldTbl.Angle;
        Indices = fieldTbl.Indices;

        Temperatures = cell(size(Indices));
        chanCells    = initChannelCells(chKeys, size(Indices));

        for a = 1:numel(Indices)
            idxBlocks = Indices{a};
            temp_vals = [];

            angleChanVals = initChannelAccumulators(chKeys);

            for k = 1:size(idxBlocks, 1)
                r1 = idxBlocks(k,1); r2 = idxBlocks(k,2);
                temp_vals = [temp_vals; TemperatureK(r1:r2)]; %#ok<AGROW>
                for c = 1:numel(chKeys)
                    key = chKeys{c};
                    angleChanVals.(key) = [angleChanVals.(key); chans.(key)(r1:r2)]; %#ok<AGROW>
                end
            end

            Temperatures{a} = temp_vals;
            for c = 1:numel(chKeys)
                key = chKeys{c};
                chanCells.(key){a} = angleChanVals.(key);
            end
        end

        resistivity_cooling_tables{f} = assembleOutputTable(Angles, Indices, Temperatures, chanCells, chKeys);
    end
end

% =========================
% Local helpers
% =========================
function chanCells = initChannelCells(chKeys, sz)
    % Create a struct of cell arrays, one per channel key
    for c = 1:numel(chKeys)
        chanCells.(chKeys{c}) = cell(sz);
    end
end

function acc = initChannelAccumulators(chKeys)
    % Create a struct of numeric arrays (initially empty) used to accumulate samples
    for c = 1:numel(chKeys)
        acc.(chKeys{c}) = [];
    end
end

function Tout = assembleOutputTable(Angles, Indices, Temperatures, chanCells, chKeys)
    % Build the output table with dynamic channel columns named exactly by chKeys
    varNames = ['Angle','Indices','Temperature', chKeys(:)'];  % 1x(3+N)
    % Build a cell array of column data matching varNames order
    cols = {Angles, Indices, Temperatures};
    for c = 1:numel(chKeys)
        cols{end+1} = chanCells.(chKeys{c}); %#ok<AGROW>
    end
    Tout = table(cols{:}, 'VariableNames', varNames);
end
