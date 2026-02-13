function plotFilteredOffsetData(fig_ch1_offset, fig_ch2_offset, filtered_data, tableData_ch1, tableData_ch2, sortedVals, colors, max_peak_to_peak, ch1_label, ch2_label)
    % PLOTFILTEREDOFFSETDATA  Plot filtered data with vertical offsets for two channels
    global legend_entries_ch1_offset legend_entries_ch2_offset;
    legend_entries_ch1_offset = cell(size(filtered_data,1),1);
    legend_entries_ch2_offset = cell(size(filtered_data,1),1);

    for i = 1:size(filtered_data,1)
        t = filtered_data{i,1};
        y1c = filtered_data{i,2};
        y2c = filtered_data{i,3};
        n = min(length(t), length(y1c));
        t = t(1:n);
        y1c = y1c(1:n);
        y2c = y2c(1:n);

        if i == 1
            base = t(1);
        else
            t = t - t(1) + base;
        end

        offset = max_peak_to_peak * (i-1);
        y1 = y1c + offset;
        y2 = y2c + offset;

        % Channel 1 plot
        figure(fig_ch1_offset);
        plot(t, y1, 'LineWidth',1.5,'Color',colors(i,:)); hold on;
        legend_entries_ch1_offset{i} = sprintf('%s= %g mA', ch1_label, sortedVals(i));
        txt = sprintf('%.2f%%', tableData_ch1(i,4));
        text(max(t)*1.05, max(y1), txt, 'Color',colors(i,:),'FontSize',14,'HorizontalAlignment','left');

        % Channel 2 plot
        figure(fig_ch2_offset);
        plot(t, y2, 'LineWidth',1.5,'Color',colors(i,:)); hold on;
        legend_entries_ch2_offset{i} = sprintf('%s= %g mA', ch2_label, sortedVals(i));
        txt2 = sprintf('%.2f%%', tableData_ch2(i,4));
        text(max(t)*1.05, max(y2), txt2, 'Color',colors(i,:),'FontSize',14,'HorizontalAlignment','left');
    end
end
