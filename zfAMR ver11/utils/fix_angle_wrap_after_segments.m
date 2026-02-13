function [rounded_fixed, unique_fixed] = ...
    fix_angle_wrap_after_segments(angle_raw, rounded_angle, unique_angle, base_max_angle)
% fix_angle_wrap_after_segments
% ---------------------------------------------------------
% Fix scan-end WRAP AFTER find_angle_segments without touching filtered_angle.
%
% INPUTS:
%   angle_raw      : filtered_angle (continuous, untouched)
%   rounded_angle  : rounded_smoothed_angle_deg
%   unique_angle   : unique_rounded_smoothed_angle_deg
%   base_max_angle : expected scan max angle for this file (can be NaN)
%
% OUTPUTS:
%   rounded_fixed  : corrected rounded angles
%   unique_fixed   : corrected unique angle list

    % ---- params ----
    tol = 0.5;                 % [deg] how close to scan end counts as wrap
    epsShift = 1e-3;
    unifyEndToZero = false;    % <<< set true if you want 360° to be treated as 0°

    rounded_fixed = rounded_angle;

    % ---- robust base_max_angle inference ----
    if nargin < 4 || isempty(base_max_angle) || ~isfinite(base_max_angle) || base_max_angle <= 0
        if ~isempty(unique_angle) && all(isfinite(unique_angle))
            base_max_angle = max(unique_angle);
        else
            base_max_angle = max(angle_raw);
        end
    end

    % guard
    if ~isfinite(base_max_angle) || base_max_angle <= 0
        unique_fixed = unique(rounded_fixed, 'stable');
        return;
    end

    % ---- detect "fake 0" that actually came from near scan end ----
    isFakeZero = (rounded_angle == 0) & (angle_raw > (base_max_angle - tol));

    % push those points back to scan end bin
    rounded_fixed(isFakeZero) = round(base_max_angle - epsShift);

    % ---- optional: treat end as 0 (canonicalize) ----
    if unifyEndToZero
        isEnd = rounded_fixed >= (base_max_angle - tol);
        rounded_fixed(isEnd) = 0;
    end

    % rebuild unique list
    unique_fixed = unique(rounded_fixed, 'stable');
end
