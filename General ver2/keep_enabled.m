function chans = keep_enabled(chans_all, enabledKeys)
%KEEP_ENABLED  Keep only the enabled channel fields from chans_all.
%
% Inputs:
%   chans_all   - struct with fields ch1..ch4 (and possibly others)
%   enabledKeys - cell array of enabled channel names, e.g. {'ch2','ch3'}
%
% Output:
%   chans       - struct containing only the enabled channels

    chans = struct();
    for i = 1:numel(enabledKeys)
        key = enabledKeys{i};
        if isfield(chans_all, key)
            chans.(key) = chans_all.(key);
        end
    end
end
