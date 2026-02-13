function tbl = firstNonEmptyTable(tblCell)
    tbl = [];
    if ~iscell(tblCell), return; end
    for i = 1:numel(tblCell)
        ti = tblCell{i};
        if istable(ti) && ~isempty(ti)
            tbl = ti; return;
        end
    end
end