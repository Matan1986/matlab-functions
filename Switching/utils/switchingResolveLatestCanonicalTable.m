function p = switchingResolveLatestCanonicalTable(repoRoot, fileName)
%SWITCHINGRESOLVELATESTCANONICALTABLE Latest path to a canonical run table artifact.

p = '';
runsRoot = switchingCanonicalRunRoot(repoRoot);
if exist(runsRoot, 'dir') ~= 7, return; end
d = dir(fullfile(runsRoot, 'run_*_switching_canonical'));
paths = {};
for i = 1:numel(d)
    f = fullfile(runsRoot, d(i).name, 'tables', fileName);
    if exist(f, 'file') == 2, paths{end+1,1} = f; end %#ok<AGROW>
end
if isempty(paths), return; end
[~, idx] = max(cellfun(@(x) dir(x).datenum, paths));
p = paths{idx};
end
