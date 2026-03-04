function plotRelaxationFits(allFits, Time_table, Moment_table, color_scheme, sample_name, fileList, typeLabel, Bohar_units, trimToFitWindow)
% plotRelaxationFits
% Backward-compatible wrapper that delegates to overlayRelaxationFits.
% Final fit-overlay implementation is centralized in overlayRelaxationFits.

if nargin < 9, trimToFitWindow = false; end
if nargin < 8, Bohar_units = false; end %#ok<NASGU>
if nargin < 7 || isempty(typeLabel), typeLabel = ''; end %#ok<NASGU>

containsTRM = any(contains(lower(string(fileList)), 'trm'));
containsIRM = any(contains(lower(string(fileList)), 'irm'));
compareMode = containsTRM && containsIRM;
debugMode = false;
offsetDisplayMode = false;
offsetValue = 0;
fields_nominal = [];

overlayRelaxationFits(allFits, Time_table, Moment_table, ...
    color_scheme, fileList, debugMode, trimToFitWindow, compareMode, ...
    sample_name, fields_nominal, containsTRM, containsIRM, ...
    offsetDisplayMode, offsetValue);

end
