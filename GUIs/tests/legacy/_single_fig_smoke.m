function _single_fig_smoke(figPath, outPath)
try
    fig = openfig(figPath,'invisible');
    c = onCleanup(@() closeSafe(fig)); %#ok<NASGU>
    ax = findall(fig,'Type','axes');
    lg = findall(fig,'Type','legend');
    ln = findall(fig,'Type','line');
    fid = fopen(outPath,'w');
    fprintf(fid,'OK|axes=%d|legend=%d|line=%d\n',numel(ax),numel(lg),numel(ln));
    fclose(fid);
catch ME
    fid = fopen(outPath,'w');
    fprintf(fid,'FAIL|%s\n', ME.message);
    fclose(fid);
end
end

function closeSafe(fig)
try
    if ~isempty(fig) && isvalid(fig)
        close(fig);
    end
catch
end
end
