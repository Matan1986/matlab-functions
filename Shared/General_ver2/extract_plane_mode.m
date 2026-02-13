function [plan_measured, plan_measured_str, matched_token] = extract_plane_mode(folderPathOrFile, fileNameOpt, defaultIfMissing)
% extract_plane_mode  Infer plane selection from folder/file name.
% OUTPUTS:
%   plan_measured     - 1 for "In plane", 2 for "Out of plane"
%   plan_measured_str - "In plane" or "Out of plane"
%   matched_token     - the exact matched substring (for debugging)
%
% If no match is found, it prints a warning and defaults to OUT-OF-PLANE.
%
% USAGE:
%   [pm, pm_str] = extract_plane_mode(fileDir);
%   [pm, pm_str] = extract_plane_mode(fileDir, filename_ending);
%   [pm, pm_str] = extract_plane_mode(fileDir, filename_ending, 1);  % default=In plane

    if nargin < 3, defaultIfMissing = NaN; end
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

    % Normalize: lowercase, replace path separators with spaces
    joined = lower(strjoin(split(searchStr, filesep), " "));

    % Candidate pattern sets
inPlanePats  = { ...
    'in[\s\-_]*plane', ...
    'in[\s\-_]*plan(?!e)', ...
    '\bin[\s\-_]*plane\b', ...
    '\bin[\s\-_]*plan(?!e)\b', ...
    '\bin\-plane\b', ...
    '\binplane\b', ...
    '(^|[\s\-_])ip($|[\s\-_])' ...   % <<< חדש
};

outPlanePats = { ...
    'out[\s\-_]*of[\s\-_]*plane', ...
    'out[\s\-_]*of[\s\-_]*plan(?!e)', ...
    'out[\s\-_]*plane', ...
    '\bout[\s\-_]*of[\s\-_]*plane\b', ...
    '\bout[\s\-_]*plane\b', ...
    '\bout\-of\-plane\b', ...
    '\boutofplane\b', ...
    '(^|[\s\-_])op($|[\s\-_])' ...   % <<< חדש
};


    % Find matches
    [idxIn, tokIn]   = local_last_match(joined, inPlanePats);
    [idxOut, tokOut] = local_last_match(joined, outPlanePats);

    % --- Decide result ---
    if ~isempty(idxIn) && isempty(idxOut)
        plan_measured     = 1;
        plan_measured_str = "In plane";
        matched_token     = tokIn;
    elseif isempty(idxIn) && ~isempty(idxOut)
        plan_measured     = 2;
        plan_measured_str = "Out of plane";
        matched_token     = tokOut;
    elseif ~isempty(idxIn) && ~isempty(idxOut)
        if idxOut > idxIn
            plan_measured     = 2;
            plan_measured_str = "Out of plane";
            matched_token     = tokOut;
        else
            plan_measured     = 1;
            plan_measured_str = "In plane";
            matched_token     = tokIn;
        end
    else
        % === No match found ===
        warning('extract_plane_mode:NoMatch', ...
            '⚠️  No "In-plane" or "Out-of-plane" token found in path "%s". Defaulting to OUT-OF-PLANE.', searchStr);
        plan_measured     = 2;
        plan_measured_str = "Out of plane";
        matched_token     = "";
    end
end

% ---- helpers ----
function [idxLast, lastTok] = local_last_match(s, patternCell)
% Return the start index of the last match across all patterns,
% and the corresponding matched substring.
    idxLast = [];
    lastTok = "";
    for i = 1:numel(patternCell)
        pat = patternCell{i};
        [starts, ends] = regexp(s, pat, 'start', 'end');
        if ~isempty(starts)
            [bestEnd, k] = max(ends); %#ok<ASGLU>
            if isempty(idxLast) || starts(k) > idxLast
                idxLast = starts(k);
                lastTok = extractBetween(s, starts(k), ends(k));
                if iscell(lastTok), lastTok = string(lastTok{1}); end
            end
        end
    end
end
