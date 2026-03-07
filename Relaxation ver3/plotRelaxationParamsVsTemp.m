function plotRelaxationParamsVsTemp(fitResults, sample_name, minR2, plotLevel)

%% Handle plotLevel parameter (gating for plotting)
if nargin < 4 || isempty(plotLevel)
    plotLevel = 'summary';
end
if strcmpi(plotLevel, 'none')
    return;
end
% plotRelaxationParamsVsTemp
% Draws core physics parameters: tau, n vs Temperature.
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
required = {'Temp_K','tau','n','R2'};
for r = 1:numel(required)
    if ~ismember(required{r}, T.Properties.VariableNames)
        error('plotRelaxationParamsVsTemp: Missing column: %s', required{r});
    end
end

%% --- Filter by R² ---
goodIdx = T.R2 >= minR2;
Tgood = T(goodIdx,:);

% If mixed-model table is provided, keep only KWW rows for tau/beta physics plots
if ismember('model_type', Tgood.Properties.VariableNames)
    modelType = lower(string(Tgood.model_type));
    isKww = modelType == "kww";
    Tgood = Tgood(isKww,:);
end

if isempty(Tgood)
    warning('No KWW curves with R² >= %.2f. Nothing to plot in tau/beta panel.', minR2);
    return;
end

%% --- Sort by temperature ---
Tgood = sortrows(Tgood, 'Temp_K');

%% --- Create figure ---
figure('Color','w','Name','Relaxation Parameters vs Temperature (Filtered)', ...
    'Units','normalized', 'Position',[0.30 0.18 0.42 0.62]);

tiledlayout(2,1,'TileSpacing','tight','Padding','compact');

% -----------------------------
% 1) tau vs T (log scale)
% -----------------------------
nexttile;
semilogy(Tgood.Temp_K, Tgood.tau, 's-','LineWidth',2,'MarkerSize',7);
xlabel('Temperature [K]');
ylabel('\tau [s]');
title(sprintf('%s — \tau vs Temperature (R^2 \geq %.2f)', sample_name, minR2));
grid on;

% -----------------------------
% 2) n vs T
% -----------------------------
nexttile;
plot(Tgood.Temp_K, Tgood.n, 'd-','LineWidth',2,'MarkerSize',7);
xlabel('Temperature [K]');
ylabel('\beta (n)');
title('\beta vs Temperature');
grid on;

end
