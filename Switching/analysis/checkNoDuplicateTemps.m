function checkNoDuplicateTemps(T, label)
    T = T(:);
    Tuniq = unique(T);
    if numel(Tuniq) ~= numel(T)
        error('Duplicate T_K detected in %s table. Expected one row per T_K.', label);
    end
end

