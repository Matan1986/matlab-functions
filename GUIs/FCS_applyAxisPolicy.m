function FCS_applyAxisPolicy(figHandles, presetOrOpts)
% FCS_applyAxisPolicy Apply axis policy to axes under explicitly provided figures.
% Enforces explicit targeting by passing axes handles directly to applyAxisPolicy.
% Assumes applyAxisPolicy(ax, presetName) is available on path.

    if nargin < 2 || isempty(presetOrOpts)
        presetOrOpts = 'paper';
    end
    presetName = i_parsePreset(presetOrOpts);

    figs = i_validateFigHandles(figHandles);
    for fig = figs(:)'
        ax = findall(fig, 'Type', 'axes');
        keep = true(size(ax));
        for k = 1:numel(ax)
            tagVal = "";
            try
                tagVal = lower(string(ax(k).Tag));
            catch
            end
            if contains(tagVal, "legend") || contains(tagVal, "colorbar")
                keep(k) = false;
            end
        end
        ax = ax(keep);

        for a = ax(:)'
            applyAxisPolicy(a, presetName);
        end
    end
end

function presetName = i_parsePreset(presetOrOpts)
    if ischar(presetOrOpts) || (isstring(presetOrOpts) && isscalar(presetOrOpts))
        presetName = char(string(presetOrOpts));
        return;
    end

    if isstruct(presetOrOpts)
        if isfield(presetOrOpts, 'preset') && ~isempty(presetOrOpts.preset)
            presetName = char(string(presetOrOpts.preset));
            return;
        end
        error('FCS_applyAxisPolicy:MissingPreset', 'When presetOrOpts is a struct, field "preset" is required.');
    end

    error('FCS_applyAxisPolicy:InvalidPreset', 'presetOrOpts must be a preset string/char or a struct with field "preset".');
end

function figs = i_validateFigHandles(figHandles)
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
        error('FCS_applyAxisPolicy:InvalidFigureHandles', 'figHandles must contain only valid figure handles.');
    end

    [~, ia] = unique(ids, 'stable');
    figs = raw(ia);
end
