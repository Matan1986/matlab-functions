function FCS_applyTypography(figHandles, opts)
% FCS_applyTypography Single explicit-target typography action.
% Validates explicit figure handles and applies font size + axis policy.
% Does not scan for targets; relies only on figHandles input.

    if nargin < 2 || ~isstruct(opts)
        error('FCS_applyTypography:InvalidOpts', 'opts must be a struct with fields fontSize and axisPreset.');
    end

    if ~isfield(opts, 'fontSize') || isempty(opts.fontSize)
        error('FCS_applyTypography:MissingFontSize', 'opts.fontSize is required.');
    end
    if ~isnumeric(opts.fontSize) || ~isscalar(opts.fontSize) || ~isfinite(opts.fontSize) || opts.fontSize <= 0
        error('FCS_applyTypography:InvalidFontSize', 'opts.fontSize must be a positive numeric scalar.');
    end

    if ~isfield(opts, 'axisPreset') || isempty(opts.axisPreset)
        error('FCS_applyTypography:MissingAxisPreset', 'opts.axisPreset is required.');
    end
    if ~(ischar(opts.axisPreset) || (isstring(opts.axisPreset) && isscalar(opts.axisPreset)))
        error('FCS_applyTypography:InvalidAxisPreset', 'opts.axisPreset must be a char or scalar string.');
    end

    figs = i_validateExplicitFigureHandles(figHandles);

    FCS_applyFontSize(figs, double(opts.fontSize));
    FCS_applyAxisPolicy(figs, char(string(opts.axisPreset)));
end

function figs = i_validateExplicitFigureHandles(figHandles)
    if nargin < 1 || isempty(figHandles)
        figs = gobjects(0,1);
        return;
    end

    raw = figHandles;
    if iscell(raw)
        raw = [raw{:}];
    end
    raw = raw(:);

    keep = false(size(raw));
    ids = nan(size(raw));
    for k = 1:numel(raw)
        try
            keep(k) = isgraphics(raw(k), 'figure') && isvalid(raw(k));
            if keep(k)
                ids(k) = double(raw(k));
            end
        catch
            keep(k) = false;
        end
    end

    if ~all(keep)
        error('FCS_applyTypography:InvalidFigureHandles', 'figHandles must contain only valid figure handles.');
    end

    [~, ia] = unique(ids, 'stable');
    figs = raw(ia);
end
