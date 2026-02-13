function [convUnits, xlabelStr] = convertDepUnits(dep_type, A, opts)
% convertDepUnits
% Single source of truth for:
%   - axis units
%   - axis label text
%   - abs-dependence semantics
%
% opts.abs (logical, default = false)
if nargin < 2 || isempty(A)
    A = NaN;   % placeholder, לא ישמש אם לא צריך
end
% ---------------- defaults ----------------
if nargin < 3 || isempty(opts)
    opts = struct;
end
if ~isfield(opts,'abs') || isempty(opts.abs)
    opts.abs = false;
end

% ---------------- dispatch ----------------
switch dep_type

    case 'Amplitude'
    assert(~isnan(A),'convertDepUnits:MissingArea', ...
        'Amplitude dependence requires sample area A.');
    xlabelStr = '$\mathrm{Current\ (10^{4}\ A\ cm^{-2})}$';
    convUnits = 1/A * 1e-4 * 1e-3 * 1e-4;


    case 'Width'
        xlabelStr = 'Pulse time (ms)';
        convUnits = 1e3;

    case 'Temperature'
        xlabelStr = 'Temperature (K)';
        convUnits = 1;

    case 'Field'
        if opts.abs
            xlabelStr = '|Field| (T)';
        else
            xlabelStr = 'Field (T)';
        end
        convUnits = 1;

    case 'Field cool'
        xlabelStr = 'FC conditions';
        convUnits = 1;

    case 'Configuration'
        xlabelStr = 'Configuration';
        convUnits = 1;

    case 'Cooling rate'
        xlabelStr = 'Cooling rate (K/min)';
        convUnits = 1;

    case 'Pulse direction and order'
        xlabelStr = 'Bars / pulse direction';
        convUnits = 1;

    otherwise
        xlabelStr = dep_type;
        convUnits = 1;
end

end
