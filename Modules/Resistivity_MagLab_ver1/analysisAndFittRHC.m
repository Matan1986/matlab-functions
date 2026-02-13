function smoothed_data = analysisAndFittRHC(Temp_table, RH_table, sortedFields, colors, peak_width, poly_order, temp_jump_threshold, moving_avg_window, Fontsize)
    zero_idx = find(sortedFields == 0, 1);
    if isempty(zero_idx), error('No zero-field data.'); end
    t = Temp_table{zero_idx}; r = RH_table{zero_idx};
    dt = diff(t); idx = abs(dt) > temp_jump_threshold; t(idx+1) = NaN; r(idx+1) = NaN;
    sg = sgolayfilt(r, poly_order, min(peak_width, numel(r)-1));
    mv = movmean(sg, moving_avg_window, 'Endpoints', 'shrink');
    ft = fittype('alpha*x', 'coefficients', {'alpha'}, 'independent', 'x');
    fr = fit(t, mv, ft, 'StartPoint', 1);
    figure('Name', 'RH vs T Fit', 'NumberTitle', 'off'); hold on;
    plot(t, r, 'b-', 'LineWidth', 1.3);
    plot(t, mv, 'k-', 'LineWidth', 1.5);
    plot(t, feval(fr, t), 'r--', 'LineWidth', 1.5);
    xlabel('T [K]', 'Interpreter', 'latex'); ylabel('RH', 'Interpreter', 'latex');
    legend('orig', 'smoothed', 'fit', 'Location', 'best'); grid on; hold off;
    disp(['alpha = ' num2str(fr.alpha)]);
    smoothed_data = mv;
end
