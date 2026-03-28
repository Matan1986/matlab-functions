function v = toDoubleColumn(col)
    if isnumeric(col)
        v = double(col);
        return;
    end
    if islogical(col)
        v = double(col);
        return;
    end
    if isstring(col) || iscellstr(col)
        v = str2double(erase(string(col), '"'));
        return;
    end
    if iscell(col)
        v = str2double(erase(string(col), '"'));
        return;
    end
    error('Unsupported column data type for numeric conversion.');
end

