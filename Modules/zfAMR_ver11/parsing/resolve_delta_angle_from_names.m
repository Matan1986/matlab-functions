function delta_Angle = resolve_delta_angle_from_names(fileDir, filename)
% RESOLVE_DELTA_ANGLE_FROM_NAMES
% Decide angular step (Δθ) based on folder/file names.
%
% Logic:
%   - If either path contains standalone "5deg", "5 deg", "5°",
%     or contains "high res", "highres", "fine step", "fine angle"
%     → Δθ = 5
%   - Otherwise → default Δθ = 15

    delta_Angle = 15;

    % Merge folder and filename into one lowercase string
    combined = lower(string(fileDir) + " " + string(filename));

    % Explicit "5deg" pattern: must not be part of a larger number
    if ~isempty(regexp(combined, '(?<!\d)5\s*deg(?!\d)', 'once')) || ...
       ~isempty(regexp(combined, '(?<!\d)5\s*°(?!\d)', 'once'))
        delta_Angle = 5;
        return;
    end

    % Other textual indicators
    keywords_5deg = [ ...
        "highres", "high_res", "high-res", "high res", ...
        "hires", "fine step", "fine steps", "fine angle", "fine angles" ...
    ];

    for k = 1:numel(keywords_5deg)
        if contains(combined, keywords_5deg(k), 'IgnoreCase', true)
            delta_Angle = 5;
            return;
        end
    end
end
