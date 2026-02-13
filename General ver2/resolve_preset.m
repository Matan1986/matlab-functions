function preset_name = resolve_preset(filename_ending, force_manual_preset, manual_preset_name)
% resolve_preset  Return preset_name based on manual/auto mode
% INPUTS:
%   filename_ending     - string, filename to parse
%   force_manual_preset - logical, if true always use manual_preset_name
%   manual_preset_name  - string, fallback or forced preset
% OUTPUT:
%   preset_name         - resolved preset string

    % Ensure char/string consistency
    if isstring(filename_ending),     filename_ending = char(strtrim(filename_ending)); end
    if isstring(manual_preset_name),  manual_preset_name = char(strtrim(manual_preset_name)); end

    if force_manual_preset
        preset_name = manual_preset_name;
    else
        preset_name = extract_preset_from_filename(filename_ending);
        if preset_name == ""
            warning('resolve_preset:fallingBack', ...
                'No preset found in filename "%s". Falling back to manual preset "%s".', ...
                filename_ending, manual_preset_name);
            preset_name = manual_preset_name;
        end
    end
end
