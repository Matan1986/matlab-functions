function plotRelaxationFits(allFits, Time_table, Moment_table, color_scheme, sample_name, fileList, typeLabel, Bohar_units, trimToFitWindow)
% plotRelaxationFits — draw fitted relaxation curves using same model as fitStretchedExp
%
% M(t) = Minf + dM * exp( -((t - t0)/tau)^n )

if nargin < 9, trimToFitWindow = false; end
if nargin < 8, Bohar_units = false; end
if isempty(allFits)
    warning('No fits to plot.');
    return;
end

% --- Ensure fileList is cell array ---
if ischar(fileList) || isstring(fileList)
    fileList = {char(fileList)};
end

% --- Extract nominal field (T) ---
fname = fileList{1};
Hnom_T = NaN;

if ~isempty(fname)
    Fmatch = regexp(fname, '(?<=afterFC|afterZFC|FC|ZFC|and_)[0-9]+[pP\.]?[0-9]*?(?=T)', 'match', 'once');
    if ~isempty(Fmatch)
        Fmatch = strrep(lower(Fmatch),'p','.');
        Hnom_T = str2double(Fmatch);
    end
end

if isnan(Hnom_T)
    Hnom_T = mean(allFits.Field_Oe,'omitnan') / 1e4;
end

% === Generate consistent colors ===
numCurves = height(allFits);

switch lower(color_scheme)
    case 'parula', cmap = parula(numCurves);
    case 'jet',    cmap = jet(numCurves);
    otherwise,     cmap = lines(numCurves);
end
colors = cmap;

% === Figure setup ===
figTitle = sprintf('%s – Magnetic relaxation (%s fits, %.3f T)', ...
    sample_name, typeLabel, Hnom_T);

figure('Name', figTitle, 'Color', 'w');
hold on; box on; grid on;

% === Loop and plot fits ===
for i = 1:height(allFits)

    k = allFits.data_idx(i);
    if k < 1 || k > numel(Time_table), continue; end
    
    % Extract parameters
    Minf = allFits.Minf(i);
    dM   = allFits.dM(i);
    tau  = allFits.tau(i);
    beta = allFits.n(i);

    if ismember('t0', allFits.Properties.VariableNames)
        t0 = allFits.t0(i);
    else
        t0 = allFits.t_start(i);
    end
    t1 = allFits.t_end(i);

    % Experimental data
    t_exp = Time_table{k};
    M_exp = Moment_table{k};

    % Trim to fit window
    if trimToFitWindow
        valid = (t_exp >= t0) & (t_exp <= t1);
        t_exp = t_exp(valid);
        M_exp = M_exp(valid);
    end

    % Model curve
    tmodel = linspace(t0, t1, 400);
    z = max(0, (tmodel - t0) ./ max(tau,1e-6));
    beta = max(0.05, min(1.5, beta));
    Mmodel = Minf + dM .* exp(-z.^beta);
    tplot = (tmodel - t0) / 60; % minutes

    % Experimental curve (thin)
    plot((t_exp - t0)/60, M_exp, '-', 'Color', colors(i,:), 'LineWidth', 1.0);

    % ---- Build DisplayName (TRM/IRM aware) ----
    thisFile = lower(fileList{k});
    if contains(thisFile,"trm")
        prefix = "TRM";
    elseif contains(thisFile,"irm")
        prefix = "IRM";
    else
        prefix = "";
    end

    if prefix ~= ""
        dispName = sprintf('%s – %.1f K, %.3f T', prefix, allFits.Temp_K(i), Hnom_T);
    else
        dispName = sprintf('%.1f K, %.3f T', allFits.Temp_K(i), Hnom_T);
    end
    disp(dispName)
    % Fitted curve (thick)
    plot(tplot, Mmodel, '-', 'Color', colors(i,:), ...
        'LineWidth', 2.4, 'DisplayName', dispName);

end

% === Axes and legend ===
xlabel('Time (minutes)');
if Bohar_units
    ylabel('M (\mu_B / Co)', 'Interpreter','tex');
else
    ylabel('M (emu/g)', 'Interpreter','tex');
end

title(figTitle, 'FontWeight','bold');
legend('show','Location','eastoutside','Box','on');
set(gca,'FontSize',14);

end
