function FCS_applyLegend(figHandles, legendOpts)
% FCS_applyLegend Apply legend updates to axes under explicitly provided figures.
% Enforces explicit targeting by always calling applyLegend(ax, ...).
% Assumes applyLegend is available on path.

    if nargin < 2
        legendOpts = struct();
    end

    [legendArgs, presetName] = i_parseLegendOpts(legendOpts);
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
            if strlength(presetName) == 0
                applyLegend(a, legendArgs{:});
            else
                applyLegend(a, legendArgs{:}, 'preset', char(presetName));
            end
        end
    end
end

function [legendArgs, presetName] = i_parseLegendOpts(legendOpts)
    legendArgs = {};
    presetName = "";

    if isempty(legendOpts)
        return;
    end

    if isstruct(legendOpts)
        if isfield(legendOpts, 'args') && ~isempty(legendOpts.args)
            if iscell(legendOpts.args)
                legendArgs = legendOpts.args;
            else
                legendArgs = {legendOpts.args};
            end
        end
        if isfield(legendOpts, 'preset') && ~isempty(legendOpts.preset)
            presetName = string(legendOpts.preset);
        end
        return;
    end

    if iscell(legendOpts)
        legendArgs = legendOpts;
        return;
    end

    legendArgs = {legendOpts};
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
        error('FCS_applyLegend:InvalidFigureHandles', 'figHandles must contain only valid figure handles.');
    end

    [~, ia] = unique(ids, 'stable');
    figs = raw(ia);
end
