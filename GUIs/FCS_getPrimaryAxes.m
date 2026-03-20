function axesOut = FCS_getPrimaryAxes(container, opts)
% FCS_getPrimaryAxes Shared axes selector with conservative defaults.
% mode='primary' matches FigureControlStudio primary-axes filtering by tag.
% mode='all' returns findall(...,'Type','axes') unchanged.

    if nargin < 2 || ~isstruct(opts)
        opts = struct();
    end

    mode = "primary";
    if isfield(opts, 'mode') && ~isempty(opts.mode)
        mode = lower(strtrim(string(opts.mode)));
    end

    axesOut = gobjects(0,1);
    if isempty(container) || ~isgraphics(container)
        return;
    end

    srcAxes = findall(container, 'Type', 'axes');
    if isempty(srcAxes)
        return;
    end

    switch mode
        case "all"
            axesOut = srcAxes;
            return;

        otherwise
            keep = false(numel(srcAxes),1);
            for i = 1:numel(srcAxes)
                keep(i) = i_isPrimaryPlotAxesByTag(srcAxes(i));
            end
            axesOut = srcAxes(keep);
            try
                [~, idx] = sort(double(axesOut), 'ascend');
                axesOut = axesOut(idx);
            catch
            end
    end
end

function tf = i_isPrimaryPlotAxesByTag(ax)
    tf = false;
    if isempty(ax) || ~isgraphics(ax, 'axes')
        return;
    end

    if i_isManualLegendAxesByTag(ax)
        return;
    end

    try
        tagVal = lower(strtrim(string(ax.Tag)));
    catch
        tagVal = "";
    end

    if contains(tagVal, "legend") || contains(tagVal, "colorbar")
        return;
    end

    tf = true;
end

function tf = i_isManualLegendAxesByTag(ax)
    tf = false;
    if isempty(ax) || ~isgraphics(ax, 'axes')
        return;
    end

    tagVal = "";
    try
        tagVal = lower(strtrim(string(ax.Tag)));
    catch
    end

    if tagVal == "plotsmtcombinedmanuallegendaxes"
        tf = true;
        return;
    end
    if tagVal == "mt_legend_axes"
        tf = true;
        return;
    end
    if contains(tagVal, "legend_axes")
        tf = true;
        return;
    end
end
