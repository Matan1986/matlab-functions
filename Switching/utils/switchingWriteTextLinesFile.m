function switchingWriteTextLinesFile(pathOut, lines, errorId)
%SWITCHINGWRITETEXTLINESFILE Write cell array of lines to UTF-8 text file.

if nargin < 3 || isempty(errorId)
    errorId = 'switchingWriteTextLinesFile:WriteFail';
end
fid = fopen(pathOut, 'w');
if fid < 0
    error(errorId, 'Cannot write %s', pathOut);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);
end
