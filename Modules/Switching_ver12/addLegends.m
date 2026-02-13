function addLegends(fig_unf1, fig_unf2, fig_f1, fig_f2, fig_fc1, fig_fc2, ch1_label, ch2_label)
    % ADDLEGENDS  Attach legends (already assembled in globals) to all figures
    global legend_entries_ch1_unfiltered legend_entries_ch2_unfiltered
    global legend_entries_ch1_filtered   legend_entries_ch2_filtered
    global legend_entries_ch1_fc   legend_entries_ch2_fc

    % Unfiltered (if you ever enable)
    figure(fig_unf1);
    legend(legend_entries_ch1_unfiltered, 'Location','best','Interpreter','tex');
    figure(fig_unf2);
    legend(legend_entries_ch2_unfiltered, 'Location','best','Interpreter','tex');

    % Filtered
    figure(fig_f1);
    legend(legend_entries_ch1_filtered, 'Location','best','Interpreter','tex');
    figure(fig_f2);
    legend(legend_entries_ch2_filtered, 'Location','best','Interpreter','tex');

    % Filtered & centered
    figure(fig_fc1);
    legend(legend_entries_ch1_fc, 'Location','best','Interpreter','tex');
    figure(fig_fc2);
    legend(legend_entries_ch2_fc, 'Location','best','Interpreter','tex');
end
