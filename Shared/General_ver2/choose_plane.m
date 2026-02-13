function plan_measured_str = choose_plane(plan_measured_strings, plan_measured)
% choose_plane  Safely select "In plane" or "Out of plane" from input list.
%
% INPUTS:
%   plan_measured_strings - cell array or string array, e.g. {"In plane","Out of plane"}
%   plan_measured         - numeric index (1 or 2), or NaN
%
% OUTPUT:
%   plan_measured_str     - string, selected label ("In plane"/"Out of plane")
%
% Behavior:
%   • If plan_measured is NaN or invalid, defaults to "Out of plane".
%   • Issues a warning if the input is out of range or not numeric.

    % Normalize the list
    if iscell(plan_measured_strings)
        plan_measured_strings = string(plan_measured_strings);
    end
    if numel(plan_measured_strings) < 2
        plan_measured_strings = ["In plane", "Out of plane"];
    end

    % Validate the index
    if isempty(plan_measured) || isnan(plan_measured) || ...
       plan_measured < 1 || plan_measured > numel(plan_measured_strings)
        warning('choose_plane:InvalidIndex', ...
            '⚠️  Invalid or missing plan_measured value. Defaulting to "Out of plane".');
        plan_measured_str = "Out of plane";
        return;
    end

    % Return the corresponding label
    plan_measured_str = plan_measured_strings(plan_measured);
end
