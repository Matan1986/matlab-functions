function smoothed_data = analysisAndFitt_MT(Temp_table, HC_table, sortedFields, colors, peak_width, poly_order, temp_jump_threshold, moving_avg_window)
% Analyze and fit heat capacity data, with double smoothing: Savitzky-Golay and moving average
plot_smooth=false;
% Extract the data corresponding to the zero field
zero_field_index = find(sortedFields == 0, 1);
if isempty(zero_field_index)
    error('No zero-field data found.');
end

% Extract temperature and heat capacity data for zero field
temp_zero_field = Temp_table{zero_field_index};
hc_zero_field = HC_table{zero_field_index};

% Detect and remove large jumps in temperature
temp_diff = diff(temp_zero_field);
remove_indices = find(abs(temp_diff) > temp_jump_threshold); % Identify the jump
temp_zero_field(remove_indices + 1) = NaN;
hc_zero_field(remove_indices + 1) = NaN;

% Apply smoothing using Savitzky-Golay filter across the entire data set
if length(hc_zero_field) >= peak_width
    smoothed_hc = sgolayfilt(hc_zero_field, poly_order, peak_width);
else
    warning('Data is too short for the specified peak width. Adjusting peak width to match data length.');
    peak_width = length(hc_zero_field) - 1;
    poly_order = min(poly_order, peak_width - 1);
    smoothed_hc = sgolayfilt(hc_zero_field, poly_order, peak_width);
end

% Apply a moving average to the already smoothed data
if length(smoothed_hc) >= moving_avg_window
    moving_avg_smoothed_hc = movmean(smoothed_hc, moving_avg_window, 'Endpoints', 'shrink');
else
    warning('Data is too short for the specified moving average window. No additional smoothing applied.');
    moving_avg_smoothed_hc = smoothed_hc; % Fallback to the original smoothed data
end

% Fit the data using the custom equation: beta*T^3 + gamma*T
customEquation = fittype('beta * x^3 + gamma * x', 'coefficients', {'beta', 'gamma'}, 'independent', 'x');
fit_result = fit(temp_zero_field, moving_avg_smoothed_hc, customEquation, 'StartPoint', [1, 1]);

% Plot the original, smoothed, moving average smoothed data, and fitted curve
figure('Name', 'Cp vs T with Custom Fit and Double Smoothing', 'NumberTitle', 'off');
hold on;
colormap(parula(1));

% Plot original data
plot(temp_zero_field, hc_zero_field, 'b-', 'LineWidth', 1.3, 'DisplayName', '0T');

if(plot_smooth)
    % Plot Savitzky-Golay smoothed data
    plot(temp_zero_field, smoothed_hc, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Savitzky-Golay Smoothed Data');

    % Plot moving average smoothed data
    plot(temp_zero_field, moving_avg_smoothed_hc, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Moving Average Smoothed Data');
end

% Plot the fitted curve
plot(temp_zero_field, feval(fit_result, temp_zero_field), 'r--', 'LineWidth', 1.5, 'DisplayName', 'Fitted curve');

% Add labels, legend, and grid
xlabel('Temperature', 'Interpreter', 'latex');
ylabel('$C_p \, [J \, K^{-1} \, mol^{-1}]$', 'Interpreter', 'latex');
legend('show', 'Location', 'southeast');
grid on;
title('Cp vs T with Double Smoothing and Custom Fit', 'Interpreter', 'latex');

% Display the symbolic equation with gamma and beta
equation_str = '$C_p = \beta T^3 + \gamma T$';
values_str = sprintf('$\\beta = %.3g$, $\\gamma = %.3g$', fit_result.beta, fit_result.gamma);
text(mean(temp_zero_field), mean(moving_avg_smoothed_hc), equation_str, 'Interpreter', 'latex', 'FontSize', 12, 'BackgroundColor', 'white', 'EdgeColor', 'black');
text(mean(temp_zero_field), mean(moving_avg_smoothed_hc) - 0.2*mean(moving_avg_smoothed_hc), values_str, 'Interpreter', 'latex', 'FontSize', 12, 'BackgroundColor', 'white', 'EdgeColor', 'black');
hold off;

% Return the doubly smoothed data
smoothed_data = moving_avg_smoothed_hc;
end
