function [Tp_valid, mask_valid, reasons] = getValidSwitchTp(Tp, Dp, Fp, Dip_sigma, Dip_area, params)
% =========================================================
% getValidSwitchTp — Single source of truth for Tp filtering
%
% Computes valid Tp mask combining base validity, manual exclusion,
% and optional automatic degeneracy filtering. Used by both switching
% reconstruction and FM cross-check to ensure consistency.
%
% INPUTS:
%   Tp          - vector of pause temperatures
%   Dp          - AFM metric (dip area or direct)
%   Fp          - FM metric (plateau step)
%   Dip_sigma   - Gaussian dip sigma (from fit, may be empty)
%   Dip_area    - Gaussian dip area (from fit, may be empty)
%   params      - config struct with exclusion/auto-exclusion fields
%
% OUTPUTS:
%   Tp_valid    - filtered Tp vector (Tp(mask_valid))
%   mask_valid  - logical mask (same size as Tp)
%   reasons     - struct with .manualExcludedTp, .autoExcludedTp, etc.
%
% =========================================================

% Force all inputs to column vectors
Tp = Tp(:);
Dp = Dp(:);
Fp = Fp(:);
if ~isempty(Dip_sigma)
    Dip_sigma = Dip_sigma(:);
end
if ~isempty(Dip_area)
    Dip_area = Dip_area(:);
end

% Get common length and assert all arrays match
N = numel(Tp);
assert(numel(Dp) == N, 'getValidSwitchTp: Dp must have same length as Tp');
assert(numel(Fp) == N, 'getValidSwitchTp: Fp must have same length as Tp');
if ~isempty(Dip_sigma)
    assert(numel(Dip_sigma) == N, 'getValidSwitchTp: Dip_sigma must have same length as Tp');
end
if ~isempty(Dip_area)
    assert(numel(Dip_area) == N, 'getValidSwitchTp: Dip_area must have same length as Tp');
end

% Initialize mask_valid as logical N×1 (all true initially)
mask_valid = true(N, 1);

% Initialize reasons struct (always populated)
reasons = struct();
reasons.manualExcludedTp = [];
reasons.autoExcludedTp = [];
reasons.excludedAbove = [];

% Step 1: Base validity - apply to mask_valid
mask_valid = mask_valid & (Dp > 0) & isfinite(Fp) & (Fp > 0) ...
           & isfinite(Tp) & isfinite(Dp);

% Step 2: Manual exclusion (switchExcludeTp)
if isfield(params,'switchExcludeTp') && ~isempty(params.switchExcludeTp)
    manualEx = ismember(Tp, params.switchExcludeTp);
    reasons.manualExcludedTp = Tp(manualEx);
    mask_valid = mask_valid & ~manualEx;
end

% Step 3: Exclusion above threshold (switchExcludeTpAbove)
if isfield(params,'switchExcludeTpAbove') && ~isempty(params.switchExcludeTpAbove)
    aboveEx = Tp > params.switchExcludeTpAbove;
    reasons.excludedAbove = Tp(aboveEx);
    mask_valid = mask_valid & ~aboveEx;
end

% Step 4: Optional automatic degeneracy exclusion
if isfield(params,'autoExcludeDegenerateDip') && params.autoExcludeDegenerateDip
    
    % Condition 1: sigma stuck at lower bound
    if ~isempty(Dip_sigma) && numel(Dip_sigma) == N
        if isfield(params, 'dipSigmaLowerBound')
            sigmaLB = params.dipSigmaLowerBound;
        else
            sigmaLB = 0.4;  % default
        end
        sigmaTol = 1e-6;
        sigmaEx = abs(Dip_sigma - sigmaLB) < sigmaTol;
        reasons.autoExcludedTp = [reasons.autoExcludedTp; Tp(sigmaEx)];
        mask_valid = mask_valid & ~sigmaEx;
    end
    
    % Condition 2: extremely small dip area (below percentile)
    if ~isempty(Dip_area) && numel(Dip_area) == N
        if isfield(params, 'dipAreaLowPercentile')
            p = params.dipAreaLowPercentile;
        else
            p = 5;  % default
        end
        % Only consider finite positive areas for percentile
        area_valid = Dip_area(isfinite(Dip_area) & (Dip_area > 0));
        if ~isempty(area_valid)
            smallThresh = prctile(area_valid, p);
            areaEx = isfinite(Dip_area) & (Dip_area <= smallThresh);
            reasons.autoExcludedTp = [reasons.autoExcludedTp; Tp(areaEx)];
            mask_valid = mask_valid & ~areaEx;
        end
    end
end

% Deduplicate and sort reasons (always return as column vectors)
reasons.autoExcludedTp = unique(reasons.autoExcludedTp(:));
reasons.manualExcludedTp = unique(reasons.manualExcludedTp(:));
reasons.excludedAbove = unique(reasons.excludedAbove(:));

% Final masking - return filtered Tp (this is the ONLY place we index Tp)
Tp_valid = Tp(mask_valid);

end
