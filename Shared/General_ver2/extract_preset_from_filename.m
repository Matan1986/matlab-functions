function preset_name = extract_preset_from_filename(fileName)
% extract_preset_from_filename  Infer preset_name from filename text.
% Supports tokens like: Vxy1, Vxx2, vXY3, vXX4 (order preserved).
% RETURNS "" if nothing found.

    if nargin < 1 || strlength(fileName)==0
        preset_name = "";
        return;
    end

    fname = char(fileName);

    % Pattern A: Vxy1 / Vxx2  (letters before number)
    patA = '(?i)v(xy|xx)\s*([1-4])';
    % Pattern B: v2xy / v3xx  (number before letters)
    patB = '(?i)v([1-4])\s*(xy|xx)';

    [startA, endA, tokA] = regexp(fname, patA, 'start','end','tokens');
    [startB, endB, tokB] = regexp(fname, patB, 'start','end','tokens');

    items = struct('s',{},'e',{},'text',{});

    % Collect matches for A (type, num)
    for k = 1:numel(startA)
        type = lower(string(tokA{k}{1}));   % "xy" or "xx"
        num  = string(tokA{k}{2});          % "1".."4"
        items(end+1) = struct('s',startA(k),'e',endA(k),'text',num+type); %#ok<AGROW>
    end

    % Collect matches for B (num, type)
    for k = 1:numel(startB)
        num  = string(tokB{k}{1});          % "1".."4"
        type = lower(string(tokB{k}{2}));   % "xy" or "xx"
        items(end+1) = struct('s',startB(k),'e',endB(k),'text',num+type); %#ok<AGROW>
    end

    if isempty(items)
        preset_name = "";
        return;
    end

    % Sort by appearance in the filename
    [~, order] = sort([items.s]);
    parts = strings(1, numel(order));
    for i = 1:numel(order)
        parts(i) = string(items(order(i)).text);
    end

    % Join with underscores
    preset_name = strjoin(parts, "_");
end
