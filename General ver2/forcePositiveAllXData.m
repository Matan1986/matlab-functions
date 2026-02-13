function forcePositiveAllXData()

    figs = findall(0,'type','figure');

    for f = 1:numel(figs)
        ax = findall(figs(f),'type','axes');

        for a = 1:numel(ax)

            % ----- flip all plotted objects -----
            kids = ax(a).Children;
            for k = 1:numel(kids)
                if isprop(kids(k),'XData')
                    x = kids(k).XData;
                    if isnumeric(x)
                        kids(k).XData = abs(x);
                    end
                end
            end

            % ----- fix axis limits -----
            if isnumeric(ax(a).XLim)
                ax(a).XLim = sort(abs(ax(a).XLim));
            end
        end
    end
end
