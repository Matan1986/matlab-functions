function Yre = reindex_rows(Y, perm)
% Apply permutation to rows of Y (numeric or table).
    if istable(Y)
        Yre = Y(perm, :);
    else
        Yre = Y(perm, :);
    end
end