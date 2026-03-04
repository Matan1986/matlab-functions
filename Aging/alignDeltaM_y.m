function pauseRuns = alignDeltaM_y(pauseRuns, alignRef, alignWindow_K)

% Choose reference T for alignment
switch lower(alignRef)
    case 'lowt'
        Tref = inf;
        for i = 1:numel(pauseRuns)
            if ~isempty(pauseRuns(i).T_common)
                Tref = min(Tref, min(pauseRuns(i).T_common));
            end
        end

    case 'hight'
        Tref = -inf;
        for i = 1:numel(pauseRuns)
            if ~isempty(pauseRuns(i).T_common)
                Tref = max(Tref, max(pauseRuns(i).T_common));
            end
        end

    otherwise
        error('alignRef must be ''lowT'' or ''highT''');
end

% Compute offset per run
for i = 1:numel(pauseRuns)
    T = pauseRuns(i).T_common;
    dM = pauseRuns(i).DeltaM;

    if isempty(T)
        continue;
    end

    if alignWindow_K > 0
        mask = abs(T - Tref) < alignWindow_K;
        if any(mask)
            C = mean(dM(mask),'omitnan');
        else
            [~, idx] = min(abs(T - Tref));
            C = dM(idx);
        end
    else
        [~, idx] = min(abs(T - Tref));
        C = dM(idx);
    end

    pauseRuns(i).DeltaM_aligned = dM - C;
    pauseRuns(i).DeltaM_offset  = C;
end
end

