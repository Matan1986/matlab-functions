function rgb = name2rgb(c)
% NAME2RGB  המרת שם צבע (black, red, ...) לוקטור [R G B]

if isnumeric(c) && numel(c) == 3
    rgb = c(:)'; 
    return;
end

c = lower(strtrim(string(c)));

switch c
    case {'k','black'}
        rgb = [0 0 0];
    case {'r','red'}
        rgb = [1 0 0];
    case {'g','green'}
        rgb = [0 0.5 0];
    case {'b','blue'}
        rgb = [0 0 1];
    case {'c','cyan'}
        rgb = [0 1 1];
    case {'m','magenta'}
        rgb = [1 0 1];
    case {'y','yellow'}
        rgb = [1 1 0];
    case {'w','white'}
        rgb = [1 1 1];
    otherwise
        % ניסיון לפרש כוקטור "[0 0 1]" וכדומה
        try
            v = str2num(c); %#ok<ST2NM>
            if isnumeric(v) && numel(v) == 3
                rgb = v(:)';
            else
                rgb = [0 0 0];
            end
        catch
            rgb = [0 0 0];
        end
end
end
