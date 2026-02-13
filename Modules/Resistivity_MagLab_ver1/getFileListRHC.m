function [fileList, legendStrings, colors] = getFileListRHC(directory)
    d = dir(directory);
    names = {d.name};
    mask = ~[d.isdir] & ~endsWith(names, '.ini', 'IgnoreCase', true) & ~cellfun(@isempty, regexp(names, '^.+_\d+$', 'once'));
    fileList = names(mask);
    legendStrings = fileList;
    colors = parula(numel(fileList));
end
