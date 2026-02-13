function idx = normalize_index_for_channel(Normalize_to, k, fallback_idx, nChannels)
% NORMALIZE_INDEX_FOR_CHANNEL  Select per-channel normalization index with fallback.
% Usage:
%   idx = normalize_index_for_channel(Normalize_to, k, fallback_idx)
%   idx = normalize_index_for_channel(Normalize_to, k, fallback_idx, nChannels)
%
% Inputs
%   Normalize_to : [] | scalar | vector
%                  - scalar N  -> use N for all channels
%                  - vector v  -> use v(k) for channel k (if available)
%   k            : current channel index (integer)
%   fallback_idx : index to use if Normalize_to is missing/invalid
%   nChannels    : optional upper bound for valid indices (e.g., 4)
%
% Output
%   idx          : chosen normalization channel index (positive integer)

    if nargin < 4 || isempty(nChannels), nChannels = Inf; end

    idx = fallback_idx;

    if isempty(Normalize_to)
        % keep fallback
    elseif isscalar(Normalize_to) && isfinite(Normalize_to)
        idx = round(Normalize_to);
    elseif isvector(Normalize_to) && numel(Normalize_to) >= k ...
            && isfinite(Normalize_to(k))
        idx = round(Normalize_to(k));
    end

    % Validate bounds
    if ~isfinite(idx) || idx < 1
        idx = fallback_idx;
    elseif isfinite(nChannels) && idx > nChannels
        idx = fallback_idx;
    end
end
