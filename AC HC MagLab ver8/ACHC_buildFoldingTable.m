function ACHC_buildFoldingTable(results, labels)

n = numel(labels);

% =========================
% Build table content
% =========================
T = cell(n+1,6);

% ---- COLUMN ORDER ----
T(1,:) = { ...
    'T', ...
    'fold', ...
    'Q', ...
    'signal', ...
    'max angles', ...
    'min angles'};

for i = 1:n
    % --- label ---
    T{i+1,1} = labels{i};

    % --- dominant fold & Q ---
    T{i+1,2} = sprintf('%d', results.fold(i));
    T{i+1,3} = sprintf('%.2f', results.Q(i));

    % --- signal ---
    isSig = results.signal(i);
    if isSig
        T{i+1,4} = '<html><b>✔</b></html>';
    else
        T{i+1,4} = '';
    end

    % --- extrema (highlighted only if signal=true) ---
    T{i+1,5} = highlightAngles( ...
        vec2str(results.maxAngles{i}), isSig, 'red');

    T{i+1,6} = highlightAngles( ...
        vec2str(results.minAngles{i}), isSig, 'blue');
end

% =========================
% Figure + table layout
% =========================
fig = figure( ...
    'Name','ACHC folding summary', ...
    'Color','w', ...
    'Units','normalized', ...
    'Position',[0.15 0.2 0.7 0.6]);   % מעט קומפקטי יותר

uitable(fig, ...
    'Data',T(2:end,:), ...
    'ColumnName',T(1,:), ...
    'Units','normalized', ...
    'Position',[0.02 0.02 0.96 0.96], ...
    'FontSize',13);

end


function s = Qvec2str(Q, folds)
if isempty(Q) || all(isnan(Q))
    s = '-';
    return
end

parts = cell(1, numel(Q));
for k = 1:numel(Q)
    if isnan(Q(k))
        parts{k} = sprintf('n=%2d: --', folds(k));
    else
        parts{k} = sprintf('n=%2d: %.2f', folds(k), Q(k));
    end
end
s = strjoin(parts, ' | ');
end
function s = vec2str(v)
if isempty(v)
    s = '-';
else
    parts = arrayfun(@(x) sprintf('%.1f°',x), v, 'Uni', false);
    s = strjoin(parts, ', ');
end
end
function s = highlightAngles(angleStr, isSignal, color)
% Highlight angles only if signal == true
if isempty(angleStr) || strcmp(angleStr,'-')
    s = angleStr;
    return
end

if isSignal
    s = sprintf('<html><font color="%s"><b>%s</b></font></html>', ...
        color, angleStr);
else
    s = angleStr;
end
end
