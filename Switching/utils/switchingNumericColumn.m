function x = switchingNumericColumn(tbl, varName)
if isempty(tbl)
    x = NaN(0, 1);
    return;
end

varName = char(string(varName));
varNames = string(tbl.Properties.VariableNames);
if ~any(varNames == string(varName))
    x = NaN(height(tbl), 1);
    return;
end

col = tbl.(varName);
if isnumeric(col)
    x = double(col(:));
else
    x = str2double(string(col(:)));
end
end