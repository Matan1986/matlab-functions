function [Scaling_factor, A] = getScalingFactor(growth_num, FIB_num)
% getScalingFactor  Return Scaling_factor for a given growth_num and FIB_num
%
% Usage:
%   Scaling_factor = getScalingFactor(growth_num, FIB_num)
%   [Scaling_factor, A] = getScalingFactor(growth_num, FIB_num)
%
% INPUT:
%   growth_num – integer or string (e.g., 131)
%   FIB_num    – integer (e.g., 10)
%
% OUTPUT:
%   Scaling_factor – computed scaling factor (A/l * convenient_units)
%   A              – optional output, cross-sectional area (w * d)

% Constants
convenient_units = 1e8;  % Ohm-cm

% Default values
d = NaN; l = NaN; w = NaN;

% Geometry selection
switch growth_num
    case 131
        switch FIB_num
            case 1
                d = 0.707e-6; l = 20e-6; w = 20e-6;
            case 3
                d = 0.580e-6; l = 35e-6; w = 20e-6;
            case 10
                d = 0.580e-6; l = 35e-6; w = 20e-6;
            case 12
                d = 1.5e-6;  l = 35e-6; w = 20e-6;  % Approx.
            case 13
                d = 2e-6;  l = 35e-6; w = 20e-6;  % Approx.
            case 14
                d = 1.8e-6;  l = 35e-6; w = 20e-6;  % Approx.
            otherwise
                warning('Unknown FIB_num %d for growth %d.', FIB_num, growth_num);
                d = 1e-6; l = 35e-6; w = 20e-6;
        end

    case 119
        switch FIB_num
            case 1
                d = 1.1e-6; l = 20e-6; w = 20e-6;
            case 2
                d = 1.050e-6; l = 35e-6; w = 20e-6;
            case 3
                d = 2.45e-6; l = 20e-6; w = 20e-6;
            case 4
                d = 0.5e-6;  l = 35e-6; w = 20e-6;  % Approx.
            case 5
                d = 0.5e-6;  l = 20e-6; w = 20e-6;  % Approx.
            otherwise
                warning('Unknown FIB_num %d for growth %d.', FIB_num, growth_num);
                d = 1e-6; l = 35e-6; w = 20e-6;
        end

    case 337
        switch FIB_num
            case 1
                d = 1.4e-6; l = 35e-6; w = 20e-6;  % Approx.
            case 2
                d = 1.05e-6; l = 20e-6; w = 20e-6; % Approx.
 
            otherwise
                warning('Unknown FIB_num %d for growth %d.', FIB_num, growth_num);
                d = 1e-6; l = 35e-6; w = 20e-6;
        end

    otherwise
        warning('Unknown growth_num %d.', growth_num);
        d = 1e-6; l = 20e-6; w = 20e-6;
end

% Cross-sectional area
A = w * d;

% Scaling factor
Scaling_factor = A / l * convenient_units; % see Ohm-cm

% If only one output is requested, don't display A
if nargout < 2
    clear A;
end
end
