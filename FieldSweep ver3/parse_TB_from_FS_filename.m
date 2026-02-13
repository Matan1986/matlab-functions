function [temp_values, field_values] = parse_TB_from_FS_filename(filename)
% Robust parse of Temp & Field ranges for Field-Sweep files.
% Handles cases where field is missing from filename.

% Default outputs
temp_values  = [];
field_values = [NaN NaN];

%% =====================================================
% 1) FIELD RANGE DETECTION
%% =====================================================

% --- Case 1: Explicit range "FS_-5T_to_5T" / "FS_9Tto-9T" ---
tokB = regexp(filename, ...
    '([+-]?\d+(?:\.\d+)?)T[^0-9+-]*to[^0-9+-]*([+-]?\d+(?:\.\d+)?)T', ...
    'tokens');

if ~isempty(tokB)
    vals = str2double(tokB{1});
    field_values = sort(vals);
else
    % --- Case 2: Single field like "Field_5T", "FS_5T", "-7T" ---
    tokSingle = regexp(filename, ...
        '(?:FS[_-]*)?([+-]?\d+(?:\.\d+)?)T', ...
        'tokens');
    if ~isempty(tokSingle)
        B = str2double(tokSingle{1});
        field_values = sort([-abs(B), abs(B)]);
    end
end

%% =====================================================
% 2) TEMPERATURE RANGE DETECTION
%% =====================================================

tokT = regexp(filename, ...
    '(?:Temp|temp|Different[_-]*temp)[_-]*([0-9]+(?:\.[0-9]+)?)K[^0-9]*to[^0-9]*([0-9]+(?:\.[0-9]+)?)K[^0-9]*at[^0-9]*([0-9]+(?:\.[0-9]+)?)K', ...
    'tokens');

if ~isempty(tokT)
    vals  = str2double(tokT{1});
    T1    = vals(1);
    T2    = vals(2);
    dT    = vals(3);
    temp_values = T1:dT:T2;

else
    % fallback – detect single Temp_4K or _4K_
    tokSingleT = regexp(filename, '([0-9]+(?:\.[0-9]+)?)K', 'tokens');
    if ~isempty(tokSingleT)
        temp_values = str2double(tokSingleT{1});
    end
end

%% =====================================================
% 3) Warnings and defaults
%% =====================================================

if any(isnan(field_values))
    warning('⚠️ Field range not detected in filename: "%s"', filename);
    % DEFAULT: avoid crash, assume symmetric fallback
    field_values = [-7 7];   % ← safety default, change if needed
end

if isempty(temp_values)
    warning('⚠️ Temperature range not detected in filename: "%s"', filename);
end

end
