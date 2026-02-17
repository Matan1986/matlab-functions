function [figure_ch1_filtered_offset, figure_ch2_filtered_offset] = createFilteredOffsetPlots(ch1_label, ch2_label)
    % CREATEFILTEREDOFFSETPLOTS  Create figures for filtered data with y-axis offset
    %   Uses configurable channel labels for titles and axes.

    % Channel 1 figure (filtered + offset)
    figure_ch1_filtered_offset = figure('Name', sprintf('Amplitude Dependence for %s (Filtered with Offset)', ch1_label), 'NumberTitle', 'off');
    hold on;
    title(sprintf('Amplitude Dependence for %s (Filtered with Offset)', ch1_label), 'FontSize', 14);
    xlabel('Time [sec]', 'FontSize', 14);
    ylabel(physLabel('symbol','\rho','units','10^{-6}\Omega \cdot cm'), 'FontSize', 14);
    set(gca, 'FontSize', 10);
    grid on;

    % Channel 2 figure (filtered + offset)
    figure_ch2_filtered_offset = figure('Name', sprintf('Amplitude Dependence for %s (Filtered with Offset)', ch2_label), 'NumberTitle', 'off');
    hold on;
    title(sprintf('Amplitude Dependence for %s (Filtered with Offset)', ch2_label), 'FontSize', 14);
    xlabel('Time [sec]', 'FontSize', 14);
    ylabel(physLabel('symbol','\rho','units','10^{-6}\Omega \cdot cm'), 'FontSize', 14);
    set(gca, 'FontSize', 10);
    grid on;
end