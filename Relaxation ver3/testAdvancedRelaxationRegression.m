function testAdvancedRelaxationRegression()
% testAdvancedRelaxationRegression
% Lightweight regression test on 3 representative synthetic curves.

rng(7);
N = 260;

Time_table = cell(3,1);
Moment_table = cell(3,1);
Temp_table = cell(3,1);
Field_table = cell(3,1);

for i = 1:3
    t = linspace(0, 1800 + 600*i, N)';
    tau = [120, 450, 1200];
    beta = [0.45, 0.75, 0.95];
    Minf = [1e-4, 0.5e-4, 0.7e-4];
    dM = [8e-4, 6e-4, 4e-4];
    m = Minf(i) + dM(i).*exp(-(t./tau(i)).^beta(i));
    m = m + 2e-5*randn(size(m));

    h = [ones(round(N*0.2),1)*500; zeros(N-round(N*0.2),1)];

    Time_table{i} = t;
    Moment_table{i} = m;
    Temp_table{i} = ones(size(t))*(5 + 5*i);
    Field_table{i} = h;
end

fitParams = struct('timeWeight',true,'timeWeightFactor',0.7,'betaBoost',false,'tauBoost',false,'lowT_only',false);
allFits = fitAllRelaxations(Time_table, Moment_table, Temp_table, Field_table, false, 20, fitParams, 0, 0, 1e-7, 1e-10);

assert(~isempty(allFits), 'Baseline fitAllRelaxations returned empty output.');

cfg = struct('makePerCurvePlots',false,'makeSummaryPlot',false,'makeCollapsePlot',false, ...
             'debugResidualPlot',false,'figureVisible','off', ...
             'useMultiStart',true,'enableLogModel',true,'modelCriterion','AIC');
adv = analyzeRelaxationAdvanced(allFits, Time_table, Moment_table, Temp_table, cfg);

assert(isfield(adv,'results') && ~isempty(adv.results), 'Advanced results table is empty.');
assert(all(ismember({'fit_ok','fit_status','RMSE','Npts','tau_unresolved','model_choice'}, adv.results.Properties.VariableNames)), ...
    'Advanced output is missing required diagnostic columns.');

fprintf('testAdvancedRelaxationRegression: PASS (%d curves analyzed).\n', height(adv.results));
end
