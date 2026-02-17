function FCS_applyFontSize(figHandles, fs, varargin)
% FCS_applyFontSize Apply font size roles to explicitly provided figures only.
% Enforces explicit targeting by normalizing figHandles via explicitList mode.
% Assumes applyFontSizeByRole_v2 is on MATLAB path.

    if nargin < 2 || ~isnumeric(fs) || ~isscalar(fs) || ~isfinite(fs) || fs <= 0
        error('FCS_applyFontSize:InvalidFontSize', 'fs must be a positive numeric scalar.');
    end

    opts = i_parseOptions(varargin{:});

    figs = FCS_resolveTargets(struct('mode', 'explicitList', 'explicitList', figHandles, 'excludeKnownGUIs', false));
    for fig = figs(:)'
        applyFontSizeByRole_v2(fig, fs, 'AffectLegend', opts.AffectLegend);
    end
end

function opts = i_parseOptions(varargin)
    opts = struct('AffectLegend', true);
    if isempty(varargin)
        return;
    end

    if mod(numel(varargin), 2) ~= 0
        error('FCS_applyFontSize:InvalidOptions', 'Options must be provided as name-value pairs.');
    end

    for k = 1:2:numel(varargin)
        name = string(varargin{k});
        value = varargin{k+1};
        switch lower(name)
            case "affectlegend"
                if ~(islogical(value) && isscalar(value))
                    error('FCS_applyFontSize:InvalidAffectLegend', 'AffectLegend must be a logical scalar.');
                end
                opts.AffectLegend = logical(value);
            otherwise
                error('FCS_applyFontSize:UnknownOption', 'Unknown option: %s', char(name));
        end
    end
end
