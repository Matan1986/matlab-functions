function PlotsHC(Temp_table, HC_table, sortedFields, colors, ...
                 temp_jump_threshold, Fontsize, LineWidth)
    % Plot Cp vs T and Cp/T vs T for different fields
    % temp_jump_threshold עדיין לא בשימוש, נשמר לתאימות

    nF   = numel(sortedFields);
    cmap = copper(nF);

    %% =========================
    % Cp vs T
    %% =========================
    fig = figure('Name','Cp vs T for Different Fields','NumberTitle','off','Color','w');
    ax  = axes(fig); hold(ax,'on'); colormap(ax,cmap);

    for i = 1:nF
        [T_sorted, idx] = sort(Temp_table{i});
        HC_sorted       = HC_table{i}(idx);

        plot(ax, T_sorted, HC_sorted, '-o', ...
            'Color',      colors(i,:), ...
            'LineWidth',  LineWidth, ...
            'DisplayName',[num2str(sortedFields(i)) ' T']);
    end

    % X label: upright text in latex, ticks in tex
    xlabel(ax,'Temperature (K)','Interpreter','latex','FontSize',Fontsize);

    % Y label: math mode but FULL \mathrm{}
    ylab_full = '$\mathrm{C_{p}\ (J\ K^{-1}\ mol^{-1})}$';
    ylabel(ax, ylab_full, 'Interpreter','latex','FontSize',Fontsize);

    ax.TickLabelInterpreter = 'tex';
    ax.FontSize = Fontsize - 2;
    ax.TickDir  = 'out';
    ax.Layer    = 'top';

    legend(ax,'show','Location','southeast');
    grid(ax,'on');
    hold(ax,'off');

    % Optional: enforce LaTeX look for labels/legend only (must not touch ticks)
    if exist('forceLatexFigure','file') == 2
        forceLatexFigure(fig);
    end


    %% =========================
    % Cp/T vs T
    %% =========================
    fig = figure('Name','Cp/T vs T for Different Fields','NumberTitle','off','Color','w');
    ax  = axes(fig); hold(ax,'on'); colormap(ax,cmap);

    for i = 1:nF
        [T_sorted, idx] = sort(Temp_table{i});
        HC_sorted       = HC_table{i}(idx);
        Cp_over_T       = HC_sorted ./ T_sorted;

        plot(ax, T_sorted, Cp_over_T, '-o', ...
            'Color',      colors(i,:), ...
            'LineWidth',  LineWidth, ...
            'DisplayName',[num2str(sortedFields(i)) ' T']);
    end

    xlabel(ax,'Temperature (K)','Interpreter','latex','FontSize',Fontsize);

    ylab_full = '$\mathrm{C_{p}/T\ (J\ K^{-2}\ mol^{-1})}$';
    ylabel(ax, ylab_full, 'Interpreter','latex','FontSize',Fontsize);

    ax.TickLabelInterpreter = 'tex';
    ax.FontSize = Fontsize - 2;
    ax.TickDir  = 'out';
    ax.Layer    = 'top';

    legend(ax,'show','Location','southeast');
    grid(ax,'on');
    hold(ax,'off');

    if exist('forceLatexFigure','file') == 2
        forceLatexFigure(fig);
    end
end
