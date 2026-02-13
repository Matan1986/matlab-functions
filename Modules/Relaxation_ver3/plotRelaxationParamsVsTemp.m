function plotRelaxationParamsVsTemp(fitResults, sample_name, minR2)
% plotRelaxationParamsVsTemp
% Draws 3 subplots: M0, tau, n vs Temperature
% Filters by minimum R² before plotting.

if nargin < 3
    minR2 = 0;   % no filtering by default
end

%% --- Normalize input to table ---
if isstruct(fitResults)
    T = struct2table(fitResults);
else
    T = fitResults;
end

%% --- Check required columns ---
required = {'Temp_K','M0','tau','n','R2'};
for r = 1:numel(required)
    if ~ismember(required{r}, T.Properties.VariableNames)
        error('plotRelaxationParamsVsTemp: Missing column: %s', required{r});
    end
end

%% --- Filter by R² ---
goodIdx = T.R2 >= minR2;
Tgood = T(goodIdx,:);

if isempty(Tgood)
    warning('No curves with R² >= %.2f. Nothing to plot.', minR2);
    return;
end

%% --- Sort by temperature ---
Tgood = sortrows(Tgood, 'Temp_K');

%% --- Create figure ---
fig = figure('Color','w','Name','Relaxation Parameters vs Temperature (Filtered)', ...
    'Units','normalized', 'Position',[0.25 0.10 0.50 0.75]);

tiledlayout(3,1,'TileSpacing','tight','Padding','compact');

% -----------------------------
% 1) M0 vs T
% -----------------------------
nexttile;
plot(Tgood.Temp_K, Tgood.M0, 'o-','LineWidth',2,'MarkerSize',7);
xlabel('Temperature [K]');
ylabel('M_0 [\mu_B / Co]');
title(sprintf('%s — M_0 vs Temperature (R^2 ≥ %.2f)', sample_name, minR2));
grid on;

% -----------------------------
% 2) tau vs T (log scale)
% -----------------------------
nexttile;
semilogy(Tgood.Temp_K, Tgood.tau, 's-','LineWidth',2,'MarkerSize',7);
xlabel('Temperature [K]');
ylabel('\tau [s]');
title('\tau vs Temperature');
grid on;

% -----------------------------
% 3) n vs T
% -----------------------------
nexttile;
plot(Tgood.Temp_K, Tgood.n, 'd-','LineWidth',2,'MarkerSize',7);
xlabel('Temperature [K]');
ylabel('n (dimensionless)');
title('n vs Temperature');
grid on;

end
