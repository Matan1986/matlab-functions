function [figure_ch1_filtered, figure_ch2_filtered] = createFilteredPlots(dep_type, fontsize, ch1_label, ch2_label,Resistivity)
    % CREATEFILTEREDPLOTS  Create figures for filtered data with configurable channel labels
    if(Resistivity)
        unit_string='[10^{-6} \Omega\cdotcm]';
    else
        unit_string='[m \Omega]';
    end
    % Channel 1 (filtered)
    figure_ch1_filtered = figure('Name', sprintf('%s Dependence for %s (filtered)', dep_type, ch1_label), 'NumberTitle', 'off');
    hold on;
    ylabel([ch1_label unit_string], 'FontSize', 14);
    set(gca, 'FontSize', fontsize);

    % Channel 2 (filtered)
    figure_ch2_filtered = figure('Name', sprintf('%s Dependence for %s (filtered)', dep_type, ch2_label), 'NumberTitle', 'off');
    hold on;
    ylabel([ch2_label unit_string], 'FontSize', 14);
    set(gca, 'FontSize', fontsize);
end