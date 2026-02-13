function appended_files = extract_appended_flag(folderPathOrFile, fileNameOpt)
% extract_appended_flag  Detect if filename/path contains "appended"
% INPUTS:
%   folderPathOrFile - string, path or folder
%   fileNameOpt      - optional filename string
% OUTPUT:
%   appended_files   - logical true if "appended" found (case-insensitive)

    if nargin < 2, fileNameOpt = ""; end

    if isempty(fileNameOpt)
        [~, baseName, ~] = fileparts(folderPathOrFile);
        searchStr = lower(baseName);
    else
        searchStr = lower(fileNameOpt);
    end

    appended_files = contains(searchStr, "appended", 'IgnoreCase', true);
end
