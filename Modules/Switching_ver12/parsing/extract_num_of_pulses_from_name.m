function num_pulses = extract_num_of_pulses_from_name(pathOrFile)
% EXTRACT_NUM_OF_PULSES_FROM_NAME
% Extracts the number of pulses from a folder or filename string.
%
% Usage:
%   num_pulses = extract_num_of_pulses_from_name(pathOrFile)
%
% Example:
%   "Amp Dep 2K 10ms 0T 10sec 5pulses 2"  → 5
%   "Width Dep 4K 10ms 0T 1s 12pulses"    → 12
%   "Temp Dep 2K 5ms 0T 100ms 3 pulse"    → 3
%
% Returns NaN if not found.

    if nargin < 1 || isempty(pathOrFile)
        error('extract_num_of_pulses_from_name:MissingInput', ...
              'Input string is required.');
    end

    % Normalize the string
    str = lower(pathOrFile);
    str = regexprep(str, '\s+', ' ');  % collapse multiple spaces

    % Get only folder/file name
    [~, nameOnly, ext] = fileparts(str);
    if isempty(ext) && contains(str, filesep)
        [~, nameOnly] = fileparts(str);
    end

    % --- Regex: look for "[number][optional space]pulse/pulses" ---
    expr = '(\d+)\s*pulses?';
    tokens = regexp(nameOnly, expr, 'tokens', 'once');

    if isempty(tokens)
        warning('⚠️ No pulse count found in "%s". Returning NaN.', nameOnly);
        num_pulses = NaN;
        return;
    end

    num_pulses = str2double(tokens{1});

   %  fprintf('[extract_num_of_pulses_from_name] Detected number of pulses: %d\n', num_pulses);
end
