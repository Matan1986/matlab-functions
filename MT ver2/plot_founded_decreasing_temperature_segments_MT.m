function plot_founded_decreasing_temperature_segments_MT(Timems, TemperatureK, FieldT,segments_decreasing_temp,filtered_temp)
%% Plot Decreasing Temperature Segments
figure('Name', 'Decreasing Temperature Segments', 'Position', [100, 100, 1000, 600]);
subplot(2, 1, 1);
hold on;
plot(Timems, TemperatureK, 'r', 'DisplayName', 'Temperature [K]');
ylabel('Temperature [K]');
title('Decreasing Temperature Segments');
legend('show');
hold off;
subplot(2, 1, 2);
hold on;
    FieldT_vec= FieldT*ones(size(Timems));
plot(Timems, FieldT_vec, 'r', 'DisplayName', 'Field [T]');
ylabel('Field [T]');
xlabel('Time [ms]');
legend('show');
hold off;
colors = parula(size(segments_decreasing_temp, 1));
subplot(2, 1, 1);
hold on;
for i = 1:size(segments_decreasing_temp, 1)
    segment_start_temp = segments_decreasing_temp(i, 1);
    segment_end_temp = segments_decreasing_temp(i, 2);
    if segment_start_temp <= length(filtered_temp) && segment_end_temp <= length(filtered_temp)
        color_temp = colors(i, :);
        plot(Timems(segment_start_temp:segment_end_temp), filtered_temp(segment_start_temp:segment_end_temp), 'Color', color_temp, 'LineWidth', 2, 'HandleVisibility', 'off');
        xline(Timems(segment_start_temp), '--', 'Color', color_temp, 'HandleVisibility', 'off');
        xline(Timems(segment_end_temp), '--', 'Color', color_temp, 'HandleVisibility', 'off');
    end
end
hold off;
subplot(2, 1, 2);
hold on;
for i = 1:size(segments_decreasing_temp, 1)
    segment_start_temp = segments_decreasing_temp(i, 1);
    segment_end_temp = segments_decreasing_temp(i, 2);
    if segment_start_temp <= length(filtered_temp) && segment_end_temp <= length(filtered_temp)
        color_temp = colors(i, :);
        xline(Timems(segment_start_temp), '--', 'Color', color_temp, 'HandleVisibility', 'off');
        xline(Timems(segment_end_temp), '--', 'Color', color_temp, 'HandleVisibility', 'off');
    end
end
hold off;
end