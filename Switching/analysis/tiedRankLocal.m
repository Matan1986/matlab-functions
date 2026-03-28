function ranks = tiedRankLocal(x)
    % Returns ranks in [1..n] using average rank for ties.
    x = x(:);
    n = numel(x);

    [xs, idx] = sort(x, 'ascend');
    ranksSorted = nan(n, 1);

    i = 1;
    while i <= n
        j = i;
        while j < n && xs(j + 1) == xs(i)
            j = j + 1;
        end
        avgRank = (i + j) / 2;
        ranksSorted(i:j) = avgRank;
        i = j + 1;
    end

    ranks = nan(n, 1);
    ranks(idx) = ranksSorted;
end

