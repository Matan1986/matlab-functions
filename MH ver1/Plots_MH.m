function Plots_MH(Temp_table, H_table, M_table, ...
                  sortedTemps, colors, unitsRatio, ...
                  growth_num, fontsize, linewidth, all_same_fig)

N = numel(sortedTemps);

%% ============================================================
%  Metadata extraction (AUTO) from workspace dir + fileList
%% ============================================================
% read dir + fileList from base workspace
directory = evalin('base','dir');
fileList  = evalin('base','fileList');

% use the FIRST file to determine metadata
meta = parse_MH_metadata(directory, fileList{1});

% build common title string
titleStr = sprintf('%s, %s', meta.measureType, meta.growth);

if ~strcmp(meta.orientation, "Orientation Unknown")
    titleStr = sprintf('%s, %s', titleStr, meta.orientation);
end

%% ============================================================
%  PLOTS
%% ============================================================

if ~all_same_fig

    for i = 1:N

        H = H_table{i}(:);
        M = M_table{i}(:) * unitsRatio;

        % Figure name includes MG, orientation and temperature
        figName = sprintf('%s, %gK', meta.figName, sortedTemps(i));

        figure('Name', figName, ...
               'Color','w','NumberTitle','off');
        hold on;

        % *** plot exactly as measured ***
        plot(H/1e4, M, 'Color', colors(i,:), ...
             'LineWidth', linewidth, ...
             'DisplayName', sprintf('%g K', sortedTemps(i)));

        applyXLabel('Field (T)');
        applyYLabel('$M_z$ ($\mu_B / \mathrm{Co}^{2+}$)');
        applyTitle(sprintf('%s, %g K', titleStr, sortedTemps(i)));
        grid on; set(gca,'FontSize',fontsize);
        applyLegend('show','Location','northeast');

        hold off;
    end

else
    % ========================
    % One figure for all temps
    % ========================

    figure('Name', meta.figName, ...
           'Color','w','NumberTitle','off');
    hold on;

    for i = 1:N

        H = H_table{i}(:);
        M = M_table{i}(:) * unitsRatio;

        plot(H/1e4, M, 'Color', colors(i,:), ...
             'LineWidth', linewidth, ...
             'DisplayName', sprintf('%g K', sortedTemps(i)));
    end

    applyXLabel('Field (T)');
    applyYLabel('$M_z$ ($\mu_B / \mathrm{Co}^{2+}$)');
    applyTitle(titleStr);
    grid on; set(gca,'FontSize',fontsize);
    applyLegend('show','Location','eastoutside');

    hold off;
end

end
