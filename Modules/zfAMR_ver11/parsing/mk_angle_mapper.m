function mapper = mk_angle_mapper(unique_rounded_smoothed_angle_deg, round_digits)
% Build a stable angle->color mapping keyed by rounded angles (no wrap).
if nargin < 2, round_digits = 1; end
keyround   = @(x) round(x, round_digits);              % linear rounding
angle_keys = unique(keyround(unique_rounded_smoothed_angle_deg(:)));
cmap       = parula(numel(angle_keys));

mapper.keys  = angle_keys;
mapper.cmap  = cmap;
mapper.round = keyround;
mapper.idx   = @(a) local_idx_for_angle(a, angle_keys, keyround);
mapper.col   = @(a) cmap(mapper.idx(a), :);

    function ii = local_idx_for_angle(a, keys, kr)
        ak = kr(a);
        [tf, ii] = ismember(ak, keys);
        if ~tf
            [~, ii] = min(abs(keys - ak)); % nearest
        end
        ii = max(1, min(numel(keys), ii));
    end
end
