function pulse_length_s = extract_pulse_length_from_name(pathOrFile)
% EXTRACT_PULSE_LENGTH_FROM_NAME
% Detects the FIRST occurrence of a pulse duration (e.g. "10ms", "0.5s", "15sec")
% in a folder or filename string and returns it in SECONDS.
%
% Logic:
%   - If only ONE time value appears → returns NaN (uncertain if it's pulse or delay)
%   - If TWO or more → returns the FIRST (assumed pulse length)
%
% Examples:
%   "Amp Dep 2K 10ms 0T 10sec 5pulses"  → 0.01
%   "Width Dep 2K 15sec ..."            → NaN   (only one)
%
% Returns NaN if not found or ambiguous.

    if nargin < 1 || isempty(pathOrFile)
        error('extract_pulse_length_from_name:MissingInput', ...
              'Input string is required.');
    end

    % Normalize input
    str = lower(pathOrFile);
    str = regexprep(str, '\s+', ' ');  % collapse multiple spaces

    % Get only folder/file name
    [~, nameOnly, ext] = fileparts(str);
    if isempty(ext) && contains(str, filesep)
        [~, nameOnly] = fileparts(str);
    end

    % --- Regex: match "10ms", "10 ms", "10msec", "0.5s", "15 sec", etc. ---
    expr = '(\d+(?:\.\d+)?)\s*(ms|msec|milliseconds?|s|sec|seconds?)';
    tokens = regexp(nameOnly, expr, 'tokens');

    if isempty(tokens)
        warning('⚠️ No time value found in "%s". Returning NaN.', nameOnly);
        pulse_length_s = NaN;
        return;
    end

    % If only one time value → ambiguous, return NaN
    if numel(tokens) < 2
        % warning('⚠️ Only one time value found in "%s" → cannot determine pulse length. Returning NaN.', nameOnly);
        pulse_length_s = NaN;
        return;
    end

    % Otherwise: first time value = pulse length
    numeric_value = str2double(tokens{1}{1});
    unit_detected = tokens{1}{2};

    if contains(unit_detected, 'ms')
        pulse_length_s = numeric_value / 1000;  % convert ms → s
    elseif contains(unit_detected, 's')
        pulse_length_s = numeric_value;          % already seconds
    else
        pulse_length_s = NaN;
    end
end
