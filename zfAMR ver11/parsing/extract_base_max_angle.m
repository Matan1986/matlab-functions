function base_max_angle = extract_base_max_angle(filename, forced_max_angle)
% extract_base_max_angle  Determine max angle (deg) from filename,
% or use forced_max_angle if provided.
%
% Usage:
%   base_max_angle = extract_base_max_angle(filename, forced_max_angle)
%
% Inputs:
%   filename         : string, full filename to inspect
%   forced_max_angle : numeric scalar (NaN means ignore / auto-detect)
%
% Output:
%   base_max_angle   : detected or forced maximum angle in degrees

    % --- If override provided, use it directly ---
    if nargin >= 2 && ~isnan(forced_max_angle)
        base_max_angle = forced_max_angle;
        return;
    end

    % --- Default if nothing found ---
    base_max_angle = 360;

    % --- Try to parse filename ---
    expr = '(?<=\D)(\d+)\s*deg';   % matches "...360deg"
    tokens = regexp(filename, expr, 'tokens');

    if ~isempty(tokens)
        % take the last numeric match (usually the max angle)
        lastToken = tokens{end};
        candidate = str2double(lastToken{1});

        if ~isnan(candidate) && candidate > 0
            base_max_angle = candidate;
        end
    end
end
