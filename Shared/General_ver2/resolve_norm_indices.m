function normIdxVec = resolve_norm_indices(Normalize_to, keysF)
% Map Normalize_to to LOCAL indices of keysF.
% Supports:
%  - numeric vector shorter or equal to numel(keysF)
%    (shorter → last value is repeated)
%  - cellstr / string array of channel names (must match length)

    nCh = numel(keysF);

    % ---- Case A: reference given as names ----
    if iscellstr(Normalize_to) || (isstring(Normalize_to) && ~isscalar(Normalize_to))
        names = cellstr(Normalize_to);
        assert(numel(names)==nCh, ...
            'Normalize_to names length (%d) must match channels count (%d).', ...
            numel(names), nCh);

        normIdxVec = zeros(1,nCh);
        for k = 1:nCh
            idx = find(strcmp(keysF, names{k}),1,'first');
            if isempty(idx)
                error('Reference key "%s" not found among channels: %s', ...
                      names{k}, strjoin(keysF, ', '));
            end
            normIdxVec(k) = idx;
        end
        return;
    end

    % ---- Case B: numeric physical indices (LOCAL, may be shorter) ----
    if isscalar(Normalize_to)
        Normalize_to = repmat(Normalize_to,1,nCh);
    elseif numel(Normalize_to) < nCh
        % 🔑 extend by repeating last value
        Normalize_to = [Normalize_to, ...
                        repmat(Normalize_to(end), 1, nCh-numel(Normalize_to))];
    elseif numel(Normalize_to) > nCh
        error('Normalize_to length (%d) exceeds channels count (%d).', ...
              numel(Normalize_to), nCh);
    end

    normIdxVec = zeros(1,nCh);
    for k = 1:nCh
        refPhys = Normalize_to(k);  % physical channel number
        candidates = { ...
            sprintf('ch%d',refPhys), ...
            sprintf('ρ_{xx%d}',refPhys), ...
            sprintf('ρ_{xy%d}',refPhys) };

        idx = find(ismember(keysF,candidates),1,'first');
        if isempty(idx)
            error('Reference channel %d not present among keys: %s', ...
                   refPhys, strjoin(keysF, ', '));
        end
        normIdxVec(k) = idx;
    end
end
