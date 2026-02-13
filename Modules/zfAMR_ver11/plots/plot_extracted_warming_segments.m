function plot_extracted_warming_segments( ...
    Timems, TemperatureK, FieldT, warming_tables, filtered_temp, varargin)
% plot_extracted_warming_segments
% Draw colored warming segments (top) and colored boundaries on field (bottom).
% Robust to length mismatch, NaNs, and mixed 'Indices' formats.
%
% REQUIRED:
%   Timems, TemperatureK, FieldT, filtered_temp : column or row vectors (same sampling grid)
%   warming_tables : cell array {nFields x 1}; each cell is a table with:
%       - Angle   : vector of (rounded, linear) angles (e.g., 0, 5, 10, ...)
%       - Indices : cell array, each cell k has [n_k x 2] blocks [s e] for that angle
%
% Name-Value (debug/notice only):
%   'Warn'     : logical (default=false). If true, emits warning(...) messages.
%   'Debug'    : logical (default=false). If true, prints counters/summaries.
%   'DebugTag' : char    (default='warming'). Prefix tag in debug/warn prints.

%% ---------- Parse name-value flags (debug/notice only) ----------
p = inputParser;
p.addParameter('Warn',     false, @(x)islogical(x)&&isscalar(x));
p.addParameter('Debug',    false, @(x)islogical(x)&&isscalar(x));
p.addParameter('DebugTag', 'warming', @(x)ischar(x)||isstring(x));
p.parse(varargin{:});
WARN  = p.Results.Warn;
DEBUG = p.Results.Debug;
DTAG  = char(p.Results.DebugTag);

%% ---------- Hygiene: make column vectors & align lengths ----------
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

%% ---------- Collect blocks from warming_tables ----------
[angle_keys, blocks] = enumerate_blocks_from_tables(warming_tables);

% blocks is [m x 4]: [startIdx, endIdx, angleValue, fieldIndex]
if isempty(blocks)
    if WARN
        warning('%s:NoBlocks', '%s: No warming blocks found in warming_tables.', DTAG);
    end
end

% Clean/clip blocks to [1 .. nCommon]
blocks = clean_and_clip_blocks(blocks, nCommon);

% Sort by start index for consistent coloring
if ~isempty(blocks)
    blocks = sortrows(blocks, 1);  % by start
end

if DEBUG
    nPerField = accumarray(max(1,blocks(:,4)), 1, [], @sum, 0);
    fprintf('[%s] angle_keys: %s\n', DTAG, mat2str(angle_keys(:)'));
    fprintf('[%s] total blocks: %d (per field: %s)\n', DTAG, size(blocks,1), mat2str(nPerField'));
end

%% ---------- Base figure ----------
figure('Name', 'Extracted Warming Segments', 'Position', [100, 100, 1000, 600]);

% Top: Temperature vs time
subplot(2,1,1); hold on;
plot(Timems, TemperatureK, 'r', 'DisplayName', 'Temperature [K]');
ylabel('Temperature [K]');
title('Extracted Warming Segments');
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
    s = blocks(i,1);
    e = blocks(i,2);
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
    s = blocks(i,1);
    e = blocks(i,2);
    if s < 1 || e > nCommon || s > e, continue; end
    col = colors(i, :);
    xline(Timems(s), '--', 'Color', col, 'HandleVisibility', 'off');
    xline(Timems(e), '--', 'Color', col, 'HandleVisibility', 'off');
end
hold off;

end % === main ===

%% ======================= Helpers =======================

function [angle_keys, blocks] = enumerate_blocks_from_tables(warming_tables)
% enumerate_blocks_from_tables
% INPUT: warming_tables {nFields x 1}, each a table with 'Angle' and 'Indices'
% OUTPUT:
%   angle_keys : sorted unique list of all angles encountered (may be empty)
%   blocks     : [m x 4] array [start end angle fieldIndex], concatenated for all fields/angles

    angle_keys = [];
    blocks = zeros(0,4);

    if isempty(warming_tables) || ~iscell(warming_tables)
        return;
    end

    % collect unique angle keys across all tables
    angle_keys = collect_angle_keys_from_tables(warming_tables);

    % iterate fields
    for f = 1:numel(warming_tables)
        T = warming_tables{f};
        if ~istable(T) || ~all(ismember({'Angle','Indices'}, T.Properties.VariableNames))
            % skip invalid
            continue;
        end
        A = T.Angle;               % vector
        C = T.Indices;             % cell array of [n_k x 2] or empty

        % defensive shapes
        if numel(A) ~= numel(C)
            % try to salvage min common
            n = min(numel(A), numel(C));
            A = A(1:n);
            C = C(1:n);
        end

        for k = 1:numel(A)
            ang  = A(k);
            cellk = C{k};
            if isempty(cellk)
                continue;
            end

            % normalize: allow row, col, or malformed to pass if 2 columns exist
            if isvector(cellk) && ~isempty(cellk)
                % if vector length even, reshape to Nx2
                if mod(numel(cellk),2)==0
                    cellk = reshape(cellk, 2, []).';
                else
                    % invalid vector length; skip
                    continue;
                end
            end

            if size(cellk,2) ~= 2
                % attempt to coerce by taking first 2 cols
                if size(cellk,2) > 2
                    cellk = cellk(:,1:2);
                else
                    continue;
                end
            end

            % remove NaNs/Inf and inverted ranges
            segs = clean_and_clip_segments(cellk, inf); % clip to +inf (no actual clip), also flips if needed
            if isempty(segs), continue; end

            % append with angle & field index
            blocks = [blocks; [segs, repmat(ang, size(segs,1), 1), repmat(f, size(segs,1), 1)]]; %#ok<AGROW>
        end
    end
end

function keys = collect_angle_keys_from_tables(warming_tables)
% collect all angle keys from all field tables; return sorted unique
    keys = [];
    for f = 1:numel(warming_tables)
        T = warming_tables{f};
        if istable(T) && any(strcmp('Angle', T.Properties.VariableNames))
            a = T.Angle(:);
            a = a(isfinite(a));
            keys = [keys; a]; %#ok<AGROW>
        end
    end
    keys = unique(keys);
end

function segs = clean_and_clip_segments(segs, nMax)
% Clean [N x 2] segments matrix: round, drop NaNs/Inf, enforce start<=end,
% and clip into [1 .. nMax] if nMax is finite.
    if isempty(segs), return; end
    segs = round(segs);
    good = all(isfinite(segs),2);
    segs = segs(good,:);

    % enforce start<=end (flip where needed)
    flipMask = segs(:,1) > segs(:,2);
    if any(flipMask), segs(flipMask,:) = segs(flipMask,[2 1]); end

    if isfinite(nMax)
        segs(:,1) = max(1, min(nMax, segs(:,1)));
        segs(:,2) = max(1, min(nMax, segs(:,2)));
    end

    % drop empty/inverted after clipping
    segs = segs(segs(:,2) >= segs(:,1), :);
end

function blocks = clean_and_clip_blocks(blocks, nMax)
% blocks: [N x 4] = [s e angle field]
    if isempty(blocks), return; end
    if size(blocks,2) ~= 4
        % try to salvage by truncating/expanding—otherwise bail
        if size(blocks,2) > 4
            blocks = blocks(:,1:4);
        else
            blocks = zeros(0,4);
            return;
        end
    end

    % round s,e only; angle/field left as-is (angle may be fractional 0.1°)
    blocks(:,1:2) = round(blocks(:,1:2));
    good = all(isfinite(blocks(:,1:2)),2);
    blocks = blocks(good,:);

    % flip inverted
    flipMask = blocks(:,1) > blocks(:,2);
    if any(flipMask), blocks(flipMask,1:2) = blocks(flipMask, [2 1]); end

    % clip s,e to [1..nMax]
    blocks(:,1) = max(1, min(nMax, blocks(:,1)));
    blocks(:,2) = max(1, min(nMax, blocks(:,2)));

    % drop empties
    blocks = blocks(blocks(:,2) >= blocks(:,1), :);
end
