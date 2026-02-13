function I = extract_current_I(folderPathOrFile, fileNameOpt, defaultIfMissing)
% extract_current_I  Extract current I [Amps] from file/folder name.
% INPUTS:
%   folderPathOrFile - string, full path or folder
%   fileNameOpt      - optional string, filename
%   defaultIfMissing - optional numeric default (NaN if omitted)
% OUTPUT:
%   I - numeric current value in Amps

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

    parts  = split(searchStr, filesep);
    joined = lower(strjoin(parts, " "));

    % Patterns allowing separator (_ or non-alnum) OR end-of-string after the unit
    unitTail = '(?=_|[^a-z0-9]|$)';

    pats = { ...
        ['(?<![a-z0-9])i[a-zx_]*\s*[_= ]\s*' ...
         '([0-9]+(?:p[0-9]+)?|[0-9]*\.[0-9]+|[0-9]+e[+-]?[0-9]+)\s*' ...
         '(a|amp|amps|ma|mamp|ua|µa|microa|na|nanoa)' unitTail], ...
        ['(?<![a-z0-9])i[a-zx_]*\s*' ...
         '([0-9]+(?:p[0-9]+)?|[0-9]*\.[0-9]+|[0-9]+e[+-]?[0-9]+)\s*' ...
         '(a|amp|amps|ma|mamp|ua|µa|microa|na|nanoa)' unitTail], ...
        ['(?<![a-z0-9])i[a-zx_]*\s*' ...
         '(a|amp|amps|ma|mamp|ua|µa|microa|na|nanoa)\s*' ...
         '([0-9]+(?:p[0-9]+)?|[0-9]*\.[0-9]+|[0-9]+e[+-]?[0-9]+)' unitTail] ...
    };

    value = NaN; unit = "";

    for pi = 1:numel(pats)
        tok = regexp(joined, pats{pi}, 'tokens');
        if ~isempty(tok)
            t = tok{end};
            if numel(t) == 2
                valStr = t{1}; unitStr = t{2};
            else
                unitStr = t{1}; valStr = t{2};
            end
            value = local_parse_number_with_p(valStr);
            unit  = string(unitStr);
            break;
        end
    end

    % Fallback: value without unit -> assume mA
    if isnan(value)
        tok = regexp(joined, '(?<![a-z0-9])i[a-zx_]*\s*[_= ]?\s*([0-9]+(?:p[0-9]+)?|[0-9]*\.[0-9]+|[0-9]+e[+-]?[0-9]+)(?=_|[^a-z0-9]|$)', 'tokens');
        if ~isempty(tok)
            valStr = tok{end}{1};
            value  = local_parse_number_with_p(valStr);
            unit   = "ma";
        end
    end

    if isnan(value)
        I = defaultIfMissing;
        return;
    end

    unit = replace(unit, "µ", "u");
    switch lower(unit)
        case {"a","amp","amps"}, scale = 1;
        case {"ma","mamp"},      scale = 1e-3;
        case {"ua","microa"},    scale = 1e-6;
        case {"na","nanoa"},     scale = 1e-9;
        otherwise,               scale = 1;
    end

    I = value * scale;
end

function x = local_parse_number_with_p(s)
% Convert strings with 'p' as decimal separator into numeric values
    s = strtrim(string(s));
    if contains(s, "e") || contains(s, "E")
        x = str2double(s);
    else
        s = regexprep(s, 'p', '.', 'ignorecase');
        x = str2double(s);
    end
end
