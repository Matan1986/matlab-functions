function [T, X] = get_canonical_X(varargin)
%GET_CANONICAL_X Load canonical switching X(T) from the fixed run export.
%   [T, X] = GET_CANONICAL_X() returns temperature T and observable X from
%   results/switching/runs/run_2026_03_22_013049_x_observable_export_corrected/observables.csv.

opts = parseInputs(varargin{:});
obsPath = fullfile(opts.repoRoot, 'results', 'switching', 'runs', opts.runName, 'observables.csv');
if ~isfile(obsPath)
    error('Canonical X observables file not found: %s', obsPath);
end

tbl = readtable(obsPath, 'VariableNamingRule', 'preserve', 'TextType', 'string');
required = {'temperature', 'observable', 'value'};
if ~all(ismember(required, tbl.Properties.VariableNames))
    error('Canonical X file is missing required columns: %s', strjoin(required, ', '));
end

maskX = string(tbl.observable) == "X";
if ~any(maskX)
    error('No rows with observable == "X" were found in: %s', obsPath);
end

Traw = double(tbl.temperature(maskX));
Xraw = double(tbl.value(maskX));

[T, X] = collapseByTemperature(Traw, Xraw);
end

function [Tuniq, Xuniq] = collapseByTemperature(T, X)
T = T(:);
X = X(:);
validT = isfinite(T);
T = T(validT);
X = X(validT);

[Tuniq, ~, g] = unique(T, 'sorted');
Xuniq = NaN(size(Tuniq));
for i = 1:numel(Tuniq)
    xi = X(g == i);
    finiteMask = isfinite(xi);
    if any(finiteMask)
        Xuniq(i) = xi(find(finiteMask, 1, 'first'));
    else
        Xuniq(i) = NaN;
    end
end
end

function opts = parseInputs(varargin)
thisPath = mfilename('fullpath');
opts = struct();
opts.repoRoot = fileparts(fileparts(thisPath));
opts.runName = 'run_2026_03_22_013049_x_observable_export_corrected';

if isempty(varargin)
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('Arguments must be provided as name/value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(string(varargin{k}));
    value = varargin{k + 1};
    switch name
        case "reporoot"
            opts.repoRoot = char(string(value));
        case "runname"
            opts.runName = char(string(value));
        otherwise
            error('Unknown option: %s', string(varargin{k}));
    end
end
end