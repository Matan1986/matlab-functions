function chans_out = apply_median_and_smooth_per_sweep(chans_in, AngleDeg, varargin)
% APPLY_MEDIAN_AND_SMOOTH_PER_SWEEP
% Applies median and/or smoothing per angular sweep (0→360 or partial sweeps).
% Optionally processes also backward sweeps if 'IgnoreDirection' is true.
%
% Usage:
%   chans_out = apply_median_and_smooth_per_sweep(chans_in, AngleDeg, ...
%       'DoMedian',true,'MedianWindow',11,'DoSmooth',true,'SmoothMethod','movmean', ...
%       'SmoothWindow',51,'IgnoreDirection',true,'JumpThreshold',100);
%
% Notes:
% - Sweeps are split when AngleDeg decreases by more than JumpThreshold (default 100°).
% - Each sweep is processed independently with optional median & smoothing filters.

    % ---------- Parameters ----------
    p = inputParser;
    addParameter(p, 'DoMedian', true);
    addParameter(p, 'MedianWindow', 51);
    addParameter(p, 'DoSmooth', true);
    addParameter(p, 'SmoothMethod', 'movmean');
    addParameter(p, 'SmoothWindow', 101);
    addParameter(p, 'IgnoreDirection', false);   % ✅ new
    addParameter(p, 'JumpThreshold', 100);       % ✅ configurable
    parse(p, varargin{:});
    o = p.Results;

    chans_out = chans_in;
    fns = fieldnames(chans_in);
    n = numel(AngleDeg);

    % ---------- Detect sweep boundaries ----------
    jumps = [0; find(diff(AngleDeg) < -o.JumpThreshold); n];
    nSweeps = numel(jumps) - 1;

    % ---------- Decide which sweeps to keep ----------
    keepSweep = true(1, nSweeps);
    if ~o.IgnoreDirection
        for s = 1:nSweeps
            i1 = jumps(s) + 1;
            i2 = jumps(s+1);
            if mean(diff(AngleDeg(i1:i2)), 'omitnan') < 0
                keepSweep(s) = false;  % backward sweep
            end
        end
    end

    % fprintf('[AngleDebug] nSamples=%d | nSweeps=%d | keep=%d\n', n, nSweeps, sum(keepSweep));

    % ---------- Process each channel ----------
    for i = 1:numel(fns)
        fn = fns{i};
        v = chans_in.(fn);
        if ~isnumeric(v) || ~isvector(v), continue; end
        v = v(:);
        v_proc = nan(size(v));

        for s = 1:nSweeps
            if ~keepSweep(s), continue; end
            i1 = jumps(s) + 1;
            i2 = jumps(s+1);
            seg = v(i1:i2);

            % ---- Median ----
            if o.DoMedian
                seg = medfilt1(seg, o.MedianWindow, 'omitnan', 'truncate');
            end

            % ---- Smoothing ----
            if o.DoSmooth
                switch lower(o.SmoothMethod)
                    case 'movmean'
                        seg = movmean(seg, o.SmoothWindow, 'omitnan', 'Endpoints', 'shrink');
                    case 'sgolay'
                        seg = sgolayfilt(seg, 3, max(5, o.SmoothWindow));
                    otherwise
                        error('Unknown smoothing method "%s".', o.SmoothMethod);
                end
            end

            v_proc(i1:i2) = seg;
        end

        chans_out.(fn) = v_proc;
    end
end
