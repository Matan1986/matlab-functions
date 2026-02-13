function chans_out = filter_AMR_channels(chans_in, AngleDeg, varargin)
% FILTER_AMR_CHANNELS — Apply Median + SG filtering only to ascending (0→360) regions.
%
%   chans_out = filter_AMR_channels(chans_in, AngleDeg, 'Name',Value,...)
%
% INPUTS:
%   chans_in  : struct of numeric vectors per channel (.ch1, .ch2, ...)
%   AngleDeg  : angle vector (same length as channel data)
%
% NAME-VALUE PAIRS:
%   'ApplyMedian'  (logical) default: true
%   'MedianWindow' (scalar)  default: 11
%   'ApplySG'      (logical) default: true
%   'SGOrder'      (scalar)  default: 3
%   'SGFrame'      (scalar)  default: 51
%
% OUTPUT:
%   chans_out : struct with filtered (ascending only) data

p = inputParser;
addParameter(p, 'ApplyMedian',  true);
addParameter(p, 'MedianWindow', 11);
addParameter(p, 'ApplySG',      true);
addParameter(p, 'SGOrder',      3);
addParameter(p, 'SGFrame',      51);
parse(p, varargin{:});
o = p.Results;

% ---- sanitize Savitzky–Golay ----
o.SGFrame = make_odd_and_valid(o.SGFrame, o.SGOrder);

chans_out = chans_in;
fns = fieldnames(chans_in);

for i = 1:numel(fns)
    fn = fns{i};
    v  = chans_in.(fn);
    if ~isnumeric(v) || ~isvector(v), chans_out.(fn) = v; continue; end
    if numel(v) ~= numel(AngleDeg)
        warning('[filter_AMR_channels] AngleDeg size mismatch in %s, skipping.', fn);
        chans_out.(fn) = v;
        continue;
    end

    % ---- detect ascending segments ----
    segMask = AngleDeg >= 0 & AngleDeg <= 360;
    ascMask = segMask & [true; diff(AngleDeg(:)) >= 0];  % only where angle increases

    vFilt = v;  % initialize output same size

    % ---- apply filtering only on ascending regions ----
    if any(ascMask)
        vv = v(ascMask);

        % Median filter
        if o.ApplyMedian
            vv = medfilt1(vv, o.MedianWindow, 'omitnan', 'truncate');
        end

        % SG filter
        if o.ApplySG
            vv = sgolayfilt(vv, o.SGOrder, o.SGFrame);
        end

        vFilt(ascMask) = vv;
    end

    chans_out.(fn) = vFilt;
end
end


% ---------- helpers ----------
function n = make_odd_and_valid(n, order)
    if ~isfinite(n) || n < 3, n = 3; end
    n = floor(n);
    if mod(n,2) == 0, n = n+1; end
    minNeed = max(3, order+2 + mod(order+2,2));
    if n < minNeed
        n = minNeed;
    end
end
