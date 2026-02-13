function [figure_ch1_unfiltered, figure_ch2_unfiltered] = createUnfilteredPlots(dep_type, fontsize, ch1_label, ch2_label,Resistivity)
    % Create figures for unfiltered data with configurable channel labels
    if(Resistivity)
        unit_string='[10^{-6} \Omega\cdotcm]';
    else
        unit_string='[m \Omega]';
    end
    % Channel 1 figure
    figure_ch1_unfiltered = figure('Name', sprintf('%s Dependence for %s (unfiltered)', dep_type, ch1_label), 'NumberTitle', 'off');
    hold on;
    ylabel([ch1_label unit_string], 'FontSize', 14);
    set(gca, 'FontSize', fontsize);

    % Channel 2 figure
    figure_ch2_unfiltered = figure('Name', sprintf('%s Dependence for %s (unfiltered)', dep_type, ch2_label), 'NumberTitle', 'off');
    hold on;
    ylabel([ch2_label unit_string], 'FontSize', 14);
    set(gca, 'FontSize', fontsize);
end
