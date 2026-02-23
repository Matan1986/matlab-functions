function debugPlotSwitchingReconstruction(state, cfg, result)

if nargin < 3 || isempty(result)
    return;
end

Tsw = getFirstAvailable(result, cfg, {'Tsw'});
Rsw = getFirstAvailable(result, cfg, {'Rsw'});
A = getFirstAvailable(result, cfg, {'A_basis','AFM_basis','D_basis'});
B = getFirstAvailable(result, cfg, {'B_basis','FM_basis','F_basis'});
C = getFirstAvailable(result, cfg, {'C_basis'});
Rhat = getFirstAvailable(result, cfg, {'Rhat'});

if isempty(Tsw) || isempty(Rsw) || isempty(A) || isempty(B) || isempty(C) || isempty(Rhat)
    return;
end

Tsw = Tsw(:);
Rsw = Rsw(:);
A = A(:);
B = B(:);
C = C(:);
Rhat = Rhat(:);

n = min([numel(Tsw), numel(Rsw), numel(A), numel(B), numel(C), numel(Rhat)]);
if n < 2
    return;
end

Tsw = Tsw(1:n);
Rsw = Rsw(1:n);
A = A(1:n);
B = B(1:n);
C = C(1:n);
Rhat = Rhat(1:n);

fig = figure('Color','w', 'Name', 'Debug Switching Reconstruction', 'NumberTitle','off');
ax = axes(fig);
hold(ax, 'on');

plot(ax, Tsw, A, '-', 'LineWidth', 1.8, 'Color', [0 0.4470 0.7410]);
plot(ax, Tsw, B, '-', 'LineWidth', 1.8, 'Color', [0.4660 0.6740 0.1880]);
plot(ax, Tsw, C, '-', 'LineWidth', 1.8, 'Color', [0.4940 0.1840 0.5560]);
plot(ax, Tsw, Rsw, 'ko', 'LineWidth', 1.2, 'MarkerFaceColor', 'w');
plot(ax, Tsw, Rhat, '-', 'LineWidth', 2.0, 'Color', [0.8500 0.3250 0.0980]);

lambdaVal = getScalarOrNaN(result, 'lambda');
R2Val = getScalarOrNaN(result, 'R2');
corrVal = getCoexistenceCorrelation(result);

title(ax, sprintf('corr=%.3f | R^2=%.3f | lambda=%.3f', corrVal, R2Val, lambdaVal));
xlabel(ax, 'T (K)');
ylabel(ax, 'Amplitude / Basis');
legend(ax, {'A(T)', 'B(T)', 'C(T)', 'Rsw', 'Fit'}, 'Location', 'best');
grid(ax, 'on');

end

function v = getFirstAvailable(result, cfg, names)
v = [];
for i = 1:numel(names)
    f = names{i};
    if isfield(result, f)
        x = result.(f);
        if ~isempty(x)
            v = x;
            return;
        end
    end
    if isfield(cfg, f)
        x = cfg.(f);
        if ~isempty(x)
            v = x;
            return;
        end
    end
end
end

function val = getScalarOrNaN(s, fieldName)
val = NaN;
if isfield(s, fieldName)
    x = s.(fieldName);
    if ~isempty(x) && isscalar(x) && isfinite(x)
        val = x;
    end
end
end

function c = getCoexistenceCorrelation(result)
c = NaN;
if isfield(result, 'DecisionTable') && istable(result.DecisionTable)
    dt = result.DecisionTable;
    if all(ismember({'Model','Correlation'}, dt.Properties.VariableNames))
        modelNames = lower(string(dt.Model));
        idx = find(contains(modelNames, 'coexistence'), 1, 'first');
        if ~isempty(idx)
            x = dt.Correlation(idx);
            if isfinite(x)
                c = x;
                return;
            end
        end
    end
end
if isfield(result, 'correlation') && isfinite(result.correlation)
    c = result.correlation;
end
end
