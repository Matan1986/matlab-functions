function varCol = getVarByCandidates(tbl, candidates)
    names = string(tbl.Properties.VariableNames);
    lowerNames = lower(names);
    for i = 1:numel(candidates)
        cand = lower(string(candidates{i}));
        idx = find(lowerNames == cand, 1, 'first');
        if ~isempty(idx)
            varCol = tbl{:, idx};
            return;
        end
    end
    error('Missing required variable. Candidates: %s', strjoin(candidates, ', '));
end

