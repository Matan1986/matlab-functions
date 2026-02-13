function chans_out = apply_fieldwise_smoothing(chans_in, FieldT, AngleDeg, field_values, FIELD_TOL, varargin)
% APPLY_FIELDWISE_SMOOTHING — Adaptive LOESS smoothing per field & channel,
% applied only to ascending 0→360° sweeps.

p = inputParser;
addParameter(p, 'SpanLow',  0.18);
addParameter(p, 'SpanMid',  0.10);
addParameter(p, 'SpanHigh', 0.12);
addParameter(p, 'UseFiltering', true);
addParameter(p, 'UseDynamic',   true);
addParameter(p, 'PostSmoothWindow', 7);
parse(p, varargin{:});
o = p.Results;

chans_out = chans_in;

for k = 1:4
    key = sprintf('ch%d', k);
    if ~isfield(chans_in, key), continue; end
    y_all = chans_in.(key);
    y_smooth = nan(size(y_all));

    for iF = 1:numel(field_values)
        B0 = field_values(iF);
        idx = abs(FieldT - B0) <= FIELD_TOL;
        if ~any(idx), continue; end

        ang = AngleDeg(idx);
        y   = y_all(idx);

        % --- Skip descending sweeps ---
        if ang(end) < ang(1)
            continue;
        end

        keep = ang >= 0 & ang <= 360;
        ang = ang(keep);
        y   = y(keep);
        if numel(ang) < 10, continue; end

        [angS, si] = sort(ang);
        [angU, ia] = unique(angS, 'stable');
        yU = y(si); yU = yU(ia);

        yU_smooth = smooth_angle_loess( ...
            angU, yU, B0, ...
            'SpanLow',  o.SpanLow, ...
            'SpanMid',  o.SpanMid, ...
            'SpanHigh', o.SpanHigh, ...
            'UseFiltering', o.UseFiltering, ...
            'UseDynamic',   o.UseDynamic);

        yU_smooth = movmean(yU_smooth, o.PostSmoothWindow, 'omitnan');

        % ✅ FIX: assign only within the same local region
        local_idx = find(idx);
        local_idx = local_idx(keep);
        y_smooth(local_idx) = interp1(angU, yU_smooth, ang, 'linear', 'extrap');
    end

    chans_out.(key) = y_smooth;
end
end
