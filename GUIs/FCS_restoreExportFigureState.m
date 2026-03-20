function FCS_restoreExportFigureState(state)
% FCS_restoreExportFigureState Restore temporary export-time mutations.

    if nargin < 1 || ~isstruct(state)
        return;
    end

    if isfield(state, 'obj') && isfield(state, 'prop') && isfield(state, 'value')
        n = min([numel(state.obj), numel(state.prop), numel(state.value)]);
        for i = n:-1:1
            obj = state.obj(i);
            if isempty(obj) || ~isgraphics(obj)
                continue;
            end
            try
                propName = char(state.prop(i));
                if isprop(obj, propName)
                    obj.(propName) = state.value{i};
                end
            catch
            end
        end
    end

    if isfield(state, 'paper') && isstruct(state.paper) && isfield(state.paper, 'applied') && logical(state.paper.applied)
        fig = [];
        if isfield(state.paper, 'fig')
            fig = state.paper.fig;
        end
        if isempty(fig) || ~isgraphics(fig, 'figure')
            return;
        end
        try
            if isfield(state.paper, 'PaperUnits') && isprop(fig, 'PaperUnits') && ~isempty(state.paper.PaperUnits)
                fig.PaperUnits = state.paper.PaperUnits;
            end
            if isfield(state.paper, 'PaperPosition') && isprop(fig, 'PaperPosition') && ~isempty(state.paper.PaperPosition)
                fig.PaperPosition = state.paper.PaperPosition;
            end
            if isfield(state.paper, 'PaperSize') && isprop(fig, 'PaperSize') && ~isempty(state.paper.PaperSize)
                fig.PaperSize = state.paper.PaperSize;
            end
            if isfield(state.paper, 'PaperPositionMode') && isprop(fig, 'PaperPositionMode') && ~isempty(state.paper.PaperPositionMode)
                fig.PaperPositionMode = state.paper.PaperPositionMode;
            end
            if isfield(state.paper, 'InvertHardcopy') && isprop(fig, 'InvertHardcopy') && ~isempty(state.paper.InvertHardcopy)
                fig.InvertHardcopy = state.paper.InvertHardcopy;
            end
        catch ME
            warning('FCS_restoreExportFigureState:PaperRestoreFailed', 'Failed to restore paper properties: %s', ME.message);
        end
    end
end
