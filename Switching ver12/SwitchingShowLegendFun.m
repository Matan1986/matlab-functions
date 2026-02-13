function showLegend = SwitchingShowLegendFun(dep_type)
% SWITCHINGSHOWLEGENDFUN  Return true if legend should be shown for given dep_type.
%
% Usage:
%   showLegend = SwitchingShowLegendFun(dep_type)
%
% Returns true for:
%   'Field cool'
%   'Configuration'
%   'Cooling rate'
%   'Pulse direction and order'
%
% Otherwise returns false.

    switch string(dep_type)
        case {'Field cool', 'Configuration', 'Cooling rate', 'Pulse direction and order'}
            showLegend = true;
        otherwise
            showLegend = false;
    end
end
