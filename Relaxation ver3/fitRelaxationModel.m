function [fitParamsOut, R2Out, yFitOut, modelTypeOut] = fitRelaxationModel(t, M, T, debug, fitParams, relaxationModel)
% fitRelaxationModel  Dispatcher for relaxation fit models.
%
% Modes:
%   'log'     -> logarithmic model only
%   'kww'     -> stretched exponential only
%   'compare' -> fit both and choose by lower AIC

if nargin < 4 || isempty(debug), debug = false; end
if nargin < 5 || isempty(fitParams), fitParams = struct(); end
if nargin < 6 || isempty(relaxationModel), relaxationModel = 'log'; end

mode = lower(string(relaxationModel));

switch mode
    case "log"
        [fitParamsOut, R2Out, yFitOut] = fitLogRelaxation(t, M, T, debug, fitParams);
        modelTypeOut = "log";

    case "kww"
        [fitParamsOut, R2Out] = fitStretchedExp(t, M, T, debug, fitParams);
        yFitOut = computeKwwFit(t, fitParamsOut);
        modelTypeOut = "kww";

    case "compare"
        [fitLog, R2Log, yLog] = fitLogRelaxation(t, M, T, debug, fitParams);
        [fitKww, R2Kww] = fitStretchedExp(t, M, T, debug, fitParams);
        yKww = computeKwwFit(t, fitKww);

        aicLog = computeAIC(M, yLog, 2);
        aicKww = computeAIC(M, yKww, 4);

        if aicLog <= aicKww
            fitParamsOut = fitLog;
            R2Out = R2Log;
            yFitOut = yLog;
            modelTypeOut = "log";
        else
            fitParamsOut = fitKww;
            R2Out = R2Kww;
            yFitOut = yKww;
            modelTypeOut = "kww";
        end

    otherwise
        warning('Unknown relaxationModel="%s"; using log.', mode);
        [fitParamsOut, R2Out, yFitOut] = fitLogRelaxation(t, M, T, debug, fitParams);
        modelTypeOut = "log";
end

end

function yFit = computeKwwFit(t, p)
if isempty(p) || ~all(isfield(p, {'Minf','dM','tau','n'}))
    yFit = nan(size(t));
    return;
end

if ~isfinite(p.tau) || p.tau <= 0 || ~isfinite(p.n) || p.n <= 0
    yFit = nan(size(t));
    return;
end

tSafe = max(t(:), 0);
yFitCol = p.Minf + p.dM .* exp(-(tSafe ./ p.tau) .^ p.n);
yFit = reshape(yFitCol, size(t));
end

function aic = computeAIC(y, yFit, k)
yv = y(:);
fh = yFit(:);
mask = isfinite(yv) & isfinite(fh);
yv = yv(mask);
fh = fh(mask);

n = numel(yv);
if n <= 0
    aic = Inf;
    return;
end

sse = nansum((yv - fh).^2);
if sse <= 0
    sse = eps;
end

aic = n * log(sse / n) + 2 * k;
end
