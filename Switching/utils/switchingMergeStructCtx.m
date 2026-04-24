function out = switchingMergeStructCtx(a, b)
%SWITCHINGMERGESTRUCTCTX Shallow merge struct b into copy of struct a.

out = a;
fn = fieldnames(b);
for i = 1:numel(fn)
    out.(fn{i}) = b.(fn{i});
end
end
