function [angu, Yu] = dedup_by_round(ang, Y, round_to_deg)
% Deduplicate near-duplicate angles by rounding and averaging rows of Y.
% Y can be a numeric vector/matrix or a table (rows must match length(ang)).
    if nargin < 3, round_to_deg = 0.1; end
    key = round(ang(:) / round_to_deg) * round_to_deg;
    [keys, ~, ic] = unique(key,'stable');
    if istable(Y)
        % average numeric vars; keep nonnumeric by first occurrence
        Ynum = varfun(@isnumeric, Y, 'OutputFormat','uniform');
        Yavg = table();
        for j = 1:width(Y)
            col = Y.(j);
            if Ynum(j)
                Yavg.(Y.Properties.VariableNames{j}) = accumarray(ic, col, [numel(keys),1], @mean, NaN);
            else
                firstIdx = accumarray(ic, (1:height(Y))', [numel(keys),1], @(ix) ix(1), NaN);
                Yavg.(Y.Properties.VariableNames{j}) = col(firstIdx);
            end
        end
        Yu = Yavg;
    else
        % numeric matrix/vector
        if isvector(Y), Y = Y(:); end
        Yu = accumarray(ic, Y, [numel(keys), size(Y,2)], @mean, NaN, true);
    end
    angu = keys;
end
