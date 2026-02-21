function close_all_except_ui_figures()
% close_all_except_ui_figures
% ---------------------------------------------------------
% Closes all open figure windows EXCEPT specific UI tools:
%   - "Final Figure Formatter"
%   - "Appearance/ Colormap Control"
%   - "Reference Line Tool"
%
% Matching is done by substring containment in the Figure 'Name'.

% ---- names to KEEP (whitelist) ----
keepNames = {
    'Final Figure Formatter'
    'Appearance / Colormap Control'
    'Reference Line Tool'
    'FigureControlStudio'
};

% ---- find all figures ----
figs = findall(0,'Type','figure');

for f = figs'
    figName = get(f,'Name');

    % If Name is empty → safe to close
    if isempty(figName)
        close(f);
        continue
    end

    % Check if this figure should be kept
    keep = false;
    for k = 1:numel(keepNames)
        if contains(figName, keepNames{k})
            keep = true;
            break
        end
    end

    if ~keep
        close(f);
    end
end

end
