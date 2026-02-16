function FCS_applyFontSize(figHandles, fs)
% FCS_applyFontSize Apply font size roles to explicitly provided figures only.
% Enforces explicit targeting by normalizing figHandles via explicitList mode.
% Assumes applyFontSizeByRole_v2 is on MATLAB path.

    if nargin < 2 || ~isnumeric(fs) || ~isscalar(fs) || ~isfinite(fs) || fs <= 0
        error('FCS_applyFontSize:InvalidFontSize', 'fs must be a positive numeric scalar.');
    end

    figs = FCS_resolveTargets(struct('mode', 'explicitList', 'explicitList', figHandles, 'excludeKnownGUIs', false));
    for fig = figs(:)'
        applyFontSizeByRole_v2(fig, fs);
    end
end
