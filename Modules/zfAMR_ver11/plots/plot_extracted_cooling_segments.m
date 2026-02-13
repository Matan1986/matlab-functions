function plot_extracted_cooling_segments( ...
    Timems, TemperatureK, FieldT, cooling_tables, filtered_temp, varargin)
% plot_extracted_cooling_segments
% Draw colored cooling segments (top) and colored boundaries on field (bottom).
% Robust to length mismatch, NaNs, and mixed 'Indices' formats.
%
% REQUIRED:
%   Timems, TemperatureK, FieldT, filtered_temp : vectors on the same grid
%   cooling_tables : cell {nFields x 1}; each table with:
%       - Angle   : vector of rounded (linear) angles
%       - Indices : cell array with [n_k x 2] blocks [s e] per angle
%
% Name-Value (debug/notice only):
%   'Warn'     : logical (default=false)
%   'Debug'    : logical (default=false)
%   'DebugTag' : char/string (default='cooling')

%% ---------- Parse name-value flags ----------
p = inputParser;
p.addParameter('Warn',     false, @(x)islogical(x)&&isscalar(x));
p.addParameter('Debug',    false, @(x)islogical(x)&&isscalar(x));
p.addParameter('DebugTag', 'cooling', @(x)ischar(x)||isstring(x));
p.parse(varargin{:});
WARN  = p.Results.Warn;
DEBUG = p.Results.Debug;
DTAG  = char(p.Results.DebugTag);

%% ---------- Hygiene: columns & align ----------
Timems        = Timems(:);
TemperatureK  = TemperatureK(:);
FieldT        = FieldT(:);
filtered_temp = filtered_temp(:);

nCommon = min([numel(Timems), numel(TemperatureK), numel(FieldT), numel(filtered_temp)]);
vecLens = [numel(Timems), numel(TemperatureK), numel(FieldT), numel(filtered_temp)];
if any(vecLens ~= nCommon)
    if WARN
        warning('%s:Lengths', '%s: aligning inputs to common length n=%d (was %s).', DTAG, nCommon, mat2str(vecLens));
    end
    Timems        = Timems(1:nCommon);
    TemperatureK  = TemperatureK(1:nCommon);
    FieldT        = FieldT(1:nCommon);
    filtered_temp = filtered_temp(1:nCommon);
end

if isempty(Timems) || isempty(TemperatureK) || isempty(FieldT)
    if WARN
        warning('%s:EmptyInputs', '%s: Nothing to plot after alignment.', DTAG);
    end
    return;
end

%% ---------- Collect blocks from cooling_tables ----------
[angle_keys, blocks] = enumerate_blocks_from_tables(cooling_tables); %#ok<ASGLU>

% blocks: [m x 4] = [start end angle fieldIndex]
blocks = clean_and_clip_blocks(blocks, nCommon);
if ~isempty(blocks)
    blocks = sortrows(blocks, 1);
end

if DEBUG
    nPerField = accumarray(max(1,blocks(:,4)), 1, [], @sum, 0);
    fprintf('[%s] total blocks: %d (per field: %s)\n', DTAG, size(blocks,1), mat2str(nPerField'));
end

%% ---------- Base figure ----------
figure('Name', 'Extracted Cooling Segments', 'Position', [120, 120, 1000, 600]);

% Top: Temperature vs time
subplot(2,1,1); hold on;
plot(Timems, TemperatureK, 'r', 'DisplayName', 'Temperature [K]');
ylabel('Temperature [K]');
title('Extracted Cooling Segments');
legend('show');
hold off;

% Bottom: Field vs time
subplot(2,1,2); hold on;
plot(Timems, FieldT, 'r', 'DisplayName', 'Field [T]');
ylabel('Field [T]');
xlabel('Time [ms]');
legend('show');
hold off;

%% ---------- Colored overlays ----------
if isempty(blocks)
    return;
end

colors = parula(size(blocks, 1));  % one color per block

% Overlay on temperature: colored filtered curve + dashed boundaries
subplot(2,1,1); hold on;
for i = 1:size(blocks,1)
    s = blocks(i,1); e = blocks(i,2);
    if s < 1 || e > nCommon || s > e, continue; end
    col = colors(i, :);
    plot(Timems(s:e), filtered_temp(s:e), 'Color', col, 'LineWidth', 2, 'HandleVisibility', 'off');
    xline(Timems(s), '--', 'Color', col, 'HandleVisibility', 'off');
    xline(Timems(e), '--', 'Color', col, 'HandleVisibility', 'off');
end
hold off;

% Overlay on field: only dashed boundaries (same colors/order)
subplot(2,1,2); hold on;
for i = 1:size(blocks,1)
    s = blocks(i,1); e = blocks(i,2);
    if s < 1 || e > nCommon || s > e, continue; end
    col = colors(i, :);
    xline(Timems(s), '--', 'Color', col, 'HandleVisibility', 'off');
    xline(Timems(e), '--', 'Color', col, 'HandleVisibility', 'off');
end
hold off;

end % === main ===

%% ======================= Helpers =======================

function [angle_keys, blocks] = enumerate_blocks_from_tables(tables_cell)
% INPUT: tables_cell {nFields x 1}, each a table with 'Angle' and 'Indices'
% OUTPUT:
%   angle_keys : unique angles across all tables (for diagnostics)
%   blocks     : [m x 4] = [start end angle fieldIndex]
    angle_keys = [];
    blocks = zeros(0,4);
    if isempty(tables_cell) || ~iscell(tables_cell)
        return;
    end

    angle_keys = collect_angle_keys_from_tables(tables_cell);

    for f = 1:numel(tables_cell)
        T = tables_cell{f};
        if ~istable(T) || ~all(ismember({'Angle','Indices'}, T.Properties.VariableNames))
            continue;
        end
        A = T.Angle;
        C = T.Indices;

        if numel(A) ~= numel(C)
            n = min(numel(A), numel(C));
            A = A(1:n); C = C(1:n);
        end

        for k = 1:numel(A)
            ang  = A(k);
            cellk = C{k};
            if isempty(cellk), continue; end

            if isvector(cellk) && ~isempty(cellk)
                if mod(numel(cellk),2)==0
                    cellk = reshape(cellk, 2, []).';
                else
                    continue;
                end
            end

            if size(cellk,2) ~= 2
                if size(cellk,2) > 2, cellk = cellk(:,1:2); else, continue; end
            end

            segs = clean_and_clip_segments(cellk, inf);
            if isempty(segs), continue; end

            blocks = [blocks; [segs, repmat(ang, size(segs,1), 1), repmat(f, size(segs,1), 1)]]; %#ok<AGROW>
        end
    end
end

function keys = collect_angle_keys_from_tables(tables_cell)
    keys = [];
    for f = 1:numel(tables_cell)
        T = tables_cell{f};
        if istable(T) && any(strcmp('Angle', T.Properties.VariableNames))
            a = T.Angle(:); a = a(isfinite(a));
            keys = [keys; a]; %#ok<AGROW>
        end
    end
    keys = unique(keys);
end

function segs = clean_and_clip_segments(segs, nMax)
    if isempty(segs), return; end
    segs = round(segs);
    good = all(isfinite(segs),2);
    segs = segs(good,:);

    flipMask = segs(:,1) > segs(:,2);
    if any(flipMask), segs(flipMask,:) = segs(flipMask,[2 1]); end

    if isfinite(nMax)
        segs(:,1) = max(1, min(nMax, segs(:,1)));
        segs(:,2) = max(1, min(nMax, segs(:,2)));
    end

    segs = segs(segs(:,2) >= segs(:,1), :);
end

function blocks = clean_and_clip_blocks(blocks, nMax)
    if isempty(blocks), return; end
    if size(blocks,2) ~= 4
        if size(blocks,2) > 4
            blocks = blocks(:,1:4);
        else
            blocks = zeros(0,4);
            return;
        end
    end

    blocks(:,1:2) = round(blocks(:,1:2));
    good = all(isfinite(blocks(:,1:2)),2);
    blocks = blocks(good,:);

    flipMask = blocks(:,1) > blocks(:,2);
    if any(flipMask), blocks(flipMask,1:2) = blocks(flipMask,[2 1]); end

    blocks(:,1) = max(1, min(nMax, blocks(:,1)));
    blocks(:,2) = max(1, min(nMax, blocks(:,2)));

    blocks = blocks(blocks(:,2) >= blocks(:,1), :);
end
