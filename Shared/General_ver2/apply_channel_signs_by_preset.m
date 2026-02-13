function LI_XV_out = apply_channel_signs_by_preset(preset_name, channel_sign_vec, LI_XV_in)
% APPLY_CHANNEL_SIGNS_BY_PRESET
% Apply +1 / -1 sign multipliers to LI channels according to a given vector.
% Works directly on LI1..LI4 before channel building.
%
% Inputs:
%   preset_name        : string (used only for logging, not for logic)
%   channel_sign_vec   : 1x4 numeric vector with +1 or -1 for each channel
%   LI_XV_in           : 1x4 cell array {LI1_XV, LI2_XV, LI3_XV, LI4_XV}
%
% Output:
%   LI_XV_out          : 1x4 cell array after applying the sign

    % --- Input checks ---
    if nargin < 3
        error('apply_channel_signs_by_preset:NotEnoughInputs', ...
              'Expected (preset_name, channel_sign_vec, LI_XV_in).');
    end
    if ~iscell(LI_XV_in) || numel(LI_XV_in) ~= 4
        error('apply_channel_signs_by_preset:BadLI_XV', ...
              'LI_XV_in must be a cell array of 4 elements.');
    end
    if numel(channel_sign_vec) ~= 4
        error('apply_channel_signs_by_preset:BadSignVec', ...
              'channel_sign_vec must have 4 elements.');
    end

    % --- Apply signs ---
    LI_XV_out = LI_XV_in;
    for k = 1:4
        if ~isempty(LI_XV_in{k}) && isnumeric(LI_XV_in{k})
            LI_XV_out{k} = channel_sign_vec(k) .* LI_XV_in{k};
        else
            LI_XV_out{k} = LI_XV_in{k};
        end
    end
%{
    % --- Optional log ---
    fprintf('[apply_channel_signs_by_preset] Applied sign vector [%s] for preset "%s"\n', ...
            num2str(channel_sign_vec), preset_name);
%}
end
