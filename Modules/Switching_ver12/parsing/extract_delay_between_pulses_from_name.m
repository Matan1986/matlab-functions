function delay_between_pulses_s = extract_delay_between_pulses_from_name(pathOrFile)
% EXTRACT_DELAY_BETWEEN_PULSES_FROM_NAME
% Detects the SECOND time value (e.g. "10ms ... 10sec") in a folder/filename string
% and returns it in SECONDS.
%
% Usage:
%   delay_between_pulses_s = extract_delay_between_pulses_from_name(pathOrFile)
%
% Example:
%   "Amp Dep 2K 10ms 0T 10sec 5pulses"  → 10
%   "Width Dep 4K 5ms 0T 1s 10pulses"   → 1
%   "Temp Dep 2K 1ms 0T 250ms 5pulses"  → 0.25
%
% Returns NaN if no time value is found.

    if nargin < 1 || isempty(pathOrFile)
        error('extract_delay_between_pulses_from_name:MissingInput', ...
              'Input string is required.');
    end

    % Normalize string
    str = lower(pathOrFile);

    % Regex to match time values (ms/s/sec)
   tokens = regexp(str, '(\d+(?:\.\d+)?)\s*(ms|msec|milliseconds?|s|sec|seconds?)(?![a-zA-Z])', 'tokens');


    if isempty(tokens)
        warning('⚠️ No time value found in "%s". Returning NaN.', pathOrFile);
        delay_between_pulses_s = NaN;
        return;
    end

    % Convert all to seconds
    times_s = zeros(1, numel(tokens));
    for i = 1:numel(tokens)
        val = str2double(tokens{i}{1});
        unit = tokens{i}{2};
        if startsWith(unit, 'ms')
            times_s(i) = val * 1e-3;
        else
            times_s(i) = val;
        end
    end

    if numel(times_s) >= 2
        % Return the SECOND time value
        delay_between_pulses_s = times_s(2);
    elseif numel(times_s) == 1
        % Return the single value found
        delay_between_pulses_s = times_s(1);
        %warning('⚠️ Only one time value found in "%s". Returning that value (%.4g s).', ...
        %        pathOrFile, delay_between_pulses_s);
    else
        delay_between_pulses_s = NaN;
    end
end
