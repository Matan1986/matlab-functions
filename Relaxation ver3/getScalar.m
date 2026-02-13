function val = getScalar(x)
% Ensures x is numeric scalar, otherwise NaN
if iscell(x)
    x = x{:};
end
if isempty(x) || ~isnumeric(x)
    val = NaN;
elseif numel(x) > 1
    val = x(1);
else
    val = x;
end
end
