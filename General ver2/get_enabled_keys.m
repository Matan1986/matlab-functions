function enabledKeys = get_enabled_keys(plotChannels)
%GET_ENABLED_KEYS Return list of enabled channel keys ('ch1'..'ch4')
%
% Input:  plotChannels - struct with fields ch1..ch4 set to true/false
% Output: enabledKeys  - cellstr of enabled keys, e.g. {'ch2','ch3'}

    allKeys = {'ch1','ch2','ch3','ch4'};
    mask = cellfun(@(k) isfield(plotChannels,k) && plotChannels.(k), allKeys);
    enabledKeys = allKeys(mask);
end
