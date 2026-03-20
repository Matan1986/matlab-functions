function Resistivity_plot_results( ...
    TemperatureK, resistivity, smoothed_data, fit_data, ...
    TC_index, TC2_index, max_temp_index, ...
    TH, TL, delta_T, resistivity_at_TH, ...
    fit_TemperatureK, fit_params, RRR, ...
    TC_to_TL_drop, TC_to_TL_drop_normalized, ...
    ylabelStr, figNameStr, ...
    plot_filtered, filename, best_fit_model)

% =================================================
% Resistivity_plot_results
% Visualization ONLY – paper-ready
% =================================================

% ---------------- STYLE ----------------
lw_main = 1.8;
lw_fit  = 1.6;
lw_ext  = 1.4;
fontSize = 20;

% ---------------- FIGURE ----------------
fig = figure('Name', figNameStr);
ax  = axes('Parent',fig);
hold(ax,'on');

% ---------------- RAW DATA ----------------
hRaw = plot(ax, TemperatureK, resistivity, '.-', ...
    'LineWidth', lw_main, ...
    'DisplayName','Raw');

% ---------------- FILTERED ----------------
if plot_filtered && ~isempty(smoothed_data)
    plot(ax, TemperatureK, smoothed_data, '-', ...
        'LineWidth', lw_main, ...
        'DisplayName','Filtered');
end

% ---------------- FIT ----------------
if ~isempty(fit_data)
    plot(ax, fit_TemperatureK, fit_data, '--', ...
        'LineWidth', lw_fit, ...
        'DisplayName','Fit');
end

% ---------------- EXTENDED FIT ----------------
if max(TemperatureK) < (TH - delta_T) && ~isempty(fit_data)

    extT = linspace(fit_TemperatureK(end), TH, 100);

    if strcmp(best_fit_model,'logarithmic')
        fit_model = @(b,x) b(1)*log(x) + b(2);
    else
        fit_model = @(b,x) b(1)*sqrt(x) + b(2);
    end

    extFit = fit_model(fit_params, extT);

    hExt = plot(ax, extT, extFit, '--', ...
        'LineWidth', lw_ext, ...
        'DisplayName','Extended fit');

    idxTH = find(abs(extT - TH) <= delta_T,1);
    if ~isempty(idxTH)
        datatip(hExt,'DataIndex',idxTH,'Location','southwest');
    end
end

% ---------------- DATA TIPS ----------------
if ~isnan(TC_index)
    datatip(hRaw,'DataIndex',TC_index,'Location','southeast');
end
if ~isnan(TC2_index)
    datatip(hRaw,'DataIndex',TC2_index,'Location','southeast');
end

if ~isnan(TC_index)
    xline(ax, TemperatureK(TC_index), '--');
end

% ---------------- AXES LABELS ----------------

% X axis — TEXT, NOT LaTeX (no italics)
xlabel(ax,'Temperature (K)','Interpreter','latex','FontSize',fontSize);

% Y axis — LaTeX (physics symbol)
ylabelLatex = ylabelStr;


ylabel(ax, ['$' ylabelLatex '$'], ...
    'FontSize',fontSize, ...
    'Interpreter','latex');

% ---------------- TICKS ----------------
ax.TickLabelInterpreter = 'latex';
ax.FontSize = fontSize - 2;

xlim(ax,[0 max(TemperatureK)]);
grid(ax,'on');

end
