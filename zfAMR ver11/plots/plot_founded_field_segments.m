function plot_founded_field_segments(Timems, TemperatureK, FieldT, filtered_field, ...
    segments_field, rounded_field_max_values_vec, rounded_unique_field_max_values)
%% Plot Field Segments (robust to small length mismatches)

    % ========== 0) Align lengths ==========
    Timems   = Timems(:);
    TemperatureK = TemperatureK(:);
    FieldT   = FieldT(:);
    filtered_field = filtered_field(:);
    rounded_field_max_values_vec = rounded_field_max_values_vec(:);

    nCommon = min([numel(Timems), numel(TemperatureK), numel(FieldT), ...
                   numel(filtered_field), numel(rounded_field_max_values_vec)]);
    if any([numel(Timems), numel(TemperatureK), numel(FieldT), ...
            numel(filtered_field), numel(rounded_field_max_values_vec)] ~= nCommon)
        Timems   = Timems(1:nCommon);
        TemperatureK = TemperatureK(1:nCommon);
        FieldT   = FieldT(1:nCommon);
        filtered_field = filtered_field(1:nCommon);
        rounded_field_max_values_vec = rounded_field_max_values_vec(1:nCommon);
        segments_field = clean_and_clip_segments(segments_field, nCommon);
    end

    % ========== 1) Colormap by unique field values ==========
    if nargin < 7 || isempty(rounded_unique_field_max_values)
        rounded_unique_field_max_values = unique(rounded_field_max_values_vec(isfinite(rounded_field_max_values_vec)));
    else
        rounded_unique_field_max_values = unique(rounded_unique_field_max_values(:).');
    end
    if isempty(rounded_unique_field_max_values)
        rounded_unique_field_max_values = 0; % dummy to avoid size 0 colormap
    end

    cmap_field = parula(max(1, numel(rounded_unique_field_max_values)));
    % Ensure keys are double row vector, values are 1x3 double rows:
    vals = num2cell(cmap_field, 2);
    field_color_map = containers.Map(num2cell(rounded_unique_field_max_values), vals);

    % Helper: always return 1x3 RGB (handles missing keys & cells)
    function c = getColor(v)
        if isKey(field_color_map, v)
            c = field_color_map(v);
        else
            [~, idx] = min(abs(rounded_unique_field_max_values - v));
            c = field_color_map(rounded_unique_field_max_values(idx));
        end
        if iscell(c), c = c{1}; end
        c = c(:).'; % 1x3 row
    end

    % Helper: robust mode within [s:e]
    function fv = seg_mode(s,e)
        if ~(isfinite(s) && isfinite(e) && s>=1 && e>=s && e<=nCommon)
            fv = NaN; return;
        end
        vals = rounded_field_max_values_vec(s:e);
        vals = vals(isfinite(vals));
        if isempty(vals)
            fv = rounded_field_max_values_vec(s);
        else
            fv = mode(vals);
        end
    end

    % ========== 2) Plot ==========
    figure('Name', 'Field Segments', 'Position', [100, 100, 1000, 600]);

    % ---- Top: Temperature ----
    subplot(2, 1, 1); hold on;
    plot(Timems, TemperatureK, 'r', 'DisplayName', 'Temperature [K]');
    ylabel('Temperature [K]');
    title('Field Segments'); legend('show');

    nSeg = size(segments_field, 1);
    for i = 1:nSeg
        s = segments_field(i,1); e = segments_field(i,2);
        if ~(isfinite(s) && isfinite(e) && s>=1 && e>=s && e<=nCommon), continue; end
        fv = seg_mode(s,e);
        if isnan(fv), continue; end
        col = getColor(fv);

        xline(Timems(s), '--', 'Color', col, 'LineWidth', 1.5, 'HandleVisibility','off');
        xline(Timems(e), '--', 'Color', col, 'LineWidth', 1.5, 'HandleVisibility','off');
    end
    % Place labels after we know ylim
    yl = ylim; text_y = yl(2) - 0.02*(yl(2)-yl(1));
    for i = 1:nSeg
        s = segments_field(i,1); e = segments_field(i,2);
        if ~(isfinite(s) && isfinite(e) && s>=1 && e>=s && e<=nCommon), continue; end
        fv = seg_mode(s,e);
        if isnan(fv), continue; end
        col = getColor(fv);
        mid = floor((s+e)/2);
        text(Timems(mid), text_y, num2str(fv), ...
             'HorizontalAlignment','center','VerticalAlignment','bottom', ...
             'Color', col, 'FontSize', 10, 'Clipping','on');
    end
    hold off;

    % ---- Bottom: Field ----
    subplot(2, 1, 2); hold on;
    plot(Timems, FieldT, 'r', 'DisplayName', 'Field [T]');
    ylabel('Field [T]'); xlabel('Time [ms]'); legend('show');

    for i = 1:nSeg
        s = segments_field(i,1); e = segments_field(i,2);
        if ~(isfinite(s) && isfinite(e) && s>=1 && e>=s && e<=nCommon), continue; end
        fv = seg_mode(s,e);
        if isnan(fv), continue; end
        col = getColor(fv);

        plot(Timems(s:e), filtered_field(s:e), 'Color', col, 'LineWidth', 2, 'HandleVisibility','off');

        xline(Timems(s), '--', 'Color', col, 'LineWidth', 1.5, 'HandleVisibility','off');
        xline(Timems(e), '--', 'Color', col, 'LineWidth', 1.5, 'HandleVisibility','off');
    end
    % Safer text placement within axes limits
    yl = ylim; text_y = yl(2) - 0.02*(yl(2)-yl(1));
    for i = 1:nSeg
        s = segments_field(i,1); e = segments_field(i,2);
        if ~(isfinite(s) && isfinite(e) && s>=1 && e>=s && e<=nCommon), continue; end
        fv = seg_mode(s,e);
        if isnan(fv), continue; end
        col = getColor(fv);
        mid = floor((s+e)/2);
        text(Timems(mid), text_y, num2str(fv), ...
             'HorizontalAlignment','center','VerticalAlignment','bottom', ...
             'Color', col, 'FontSize', 10, 'Clipping','on');
    end
    hold off;
end

% ===== helper =====
function segs = clean_and_clip_segments(segs, nMax)
    if isempty(segs), return; end
    segs = segs(isfinite(segs(:,1)) & isfinite(segs(:,2)), :);
    segs(:,1) = max(1, min(nMax, segs(:,1)));
    segs(:,2) = max(1, min(nMax, segs(:,2)));
    swap = segs(:,1) > segs(:,2);
    if any(swap), segs(swap,:) = fliplr(segs(swap,:)); end
    segs = segs(segs(:,2) >= segs(:,1), :);
end
