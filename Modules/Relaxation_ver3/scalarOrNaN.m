function val = scalarOrNaN(x)
% scalarOrNaN — safely reduce arrays to single numeric values
if isempty(x)
    val = NaN;
elseif numel(x) > 1
    val = mean(x(:), 'omitnan');
else
    val = x;
end
end
