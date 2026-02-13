function [growth_num, FIB_num] = extract_growth_FIB(folderPathOrFile, fileNameOpt)
% extract_growth_FIB  Extract growth_num (MG###) and FIB_num (FIB##) from path and/or name.
% INPUTS:
%   folderPathOrFile - string, full path or folder
%   fileNameOpt      - optional string, filename
% OUTPUTS:
%   growth_num       - numeric growth number (e.g., 131)
%   FIB_num          - numeric FIB number (e.g., 10)

    % Defaults
    growth_num = NaN;
    FIB_num    = NaN;

    if nargin < 2, fileNameOpt = ""; end

    % Build search string
    if isempty(fileNameOpt)
        [folderPath, baseName, ~] = fileparts(folderPathOrFile);
        if folderPath == ""
            searchStr = string(folderPathOrFile);
        else
            searchStr = string(fullfile(folderPath, baseName));
        end
    else
        searchStr = string(fullfile(char(folderPathOrFile), char(fileNameOpt)));
    end

    % Split path into parts
    parts = split(searchStr, filesep);

    % --- Growth number (MG###) ---
    mgCandidates = parts(contains(parts, "MG", 'IgnoreCase', true));
    if ~isempty(mgCandidates)
        for k = numel(mgCandidates):-1:1
            tok = regexp(mgCandidates{k}, '(?i)MG[_ ]?(\d+)', 'tokens', 'once');
            if ~isempty(tok), growth_num = str2double(tok{1}); break; end
        end
    end
    if isnan(growth_num)
        allJoined = join(parts, " ");
        tok = regexp(allJoined, '(?i)MG[_ ]?(\d+)', 'tokens', 'once');
        if ~isempty(tok), growth_num = str2double(tok{1}); end
    end

    % --- FIB number (FIB##) ---
    fibCandidates = parts(contains(parts, "FIB", 'IgnoreCase', true));
    if ~isempty(fibCandidates)
        for k = numel(fibCandidates):-1:1
            tok = regexp(fibCandidates{k}, '(?i)FIB[_ ]?(\d+)', 'tokens', 'once');
            if ~isempty(tok), FIB_num = str2double(tok{1}); break; end
        end
    end
    if isnan(FIB_num)
        allJoined = join(parts, " ");
        tok = regexp(allJoined, '(?i)FIB[_ ]?(\d+)', 'tokens', 'once');
        if ~isempty(tok), FIB_num = str2double(tok{1}); end
    end
end
