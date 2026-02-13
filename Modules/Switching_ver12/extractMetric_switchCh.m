function [T, V] = extractMetric_switchCh(tableData, switchCh, metricType)

chName = sprintf('ch%d', switchCh);

if ~isfield(tableData, chName) || isempty(tableData.(chName))
    T = [];
    V = [];
    return;
end

tbl = tableData.(chName);

T = tbl(:,1);   % dep value = Temperature

switch metricType
    case "meanP2P"
        V = tbl(:,2);        % avg_p2p

    case "medianAbs"
        V = abs(tbl(:,4));   % |ΔR/R| %

    otherwise
        error('Unknown metricType');
end

end
