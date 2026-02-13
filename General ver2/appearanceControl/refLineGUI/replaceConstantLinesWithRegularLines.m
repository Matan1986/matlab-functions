function replaceConstantLinesWithRegularLines(fig)

if nargin < 1 || isempty(fig)
    fig = gcf;
end

% --- אפשר גישה ל-handles חבויים ---
H0 = get(groot,'ShowHiddenHandles');
set(groot,'ShowHiddenHandles','on');

cl = findall(fig,'Type','ConstantLine');

for h = cl(:).'
    
    ax = ancestor(h,'axes');
    if isempty(ax) || ~isvalid(ax)
        continue
    end
    
    % --- שמירת מאפיינים ---
    val = h.Value;
    col = h.Color;
    ls  = h.LineStyle;
    lw  = h.LineWidth;
    
    xl = xlim(ax);
    yl = ylim(ax);
    
    % --- טולרנס מספרי ---
    tol = max(range(xl),range(yl)) * 1e-12;
    
    % --- זיהוי כיוון ---
    % אם הערך קרוב לטווח X → כנראה xline
    isVertical = (val >= xl(1)-tol) && (val <= xl(2)+tol);
    
    % אם הערך קרוב לטווח Y → כנראה yline
    isHorizontal = (val >= yl(1)-tol) && (val <= yl(2)+tol);
    
    % אם שניהם true (נדיר אבל אפשרי) נבדוק יחס מיקום
    if isVertical && isHorizontal
        % נבדוק איזה ציר "דומיננטי" ביחס לגבולות
        dx = min(abs(val - xl));
        dy = min(abs(val - yl));
        isVertical = dx < dy;
    end
    
    % --- יצירת קו רגיל ---
    if isVertical
        newLine = line(ax,[val val],yl,...
            'Color',col,...
            'LineStyle',ls,...
            'LineWidth',lw,...
            'HandleVisibility','off');
    else
        newLine = line(ax,xl,[val val],...
            'Color',col,...
            'LineStyle',ls,...
            'LineWidth',lw,...
            'HandleVisibility','off');
    end
    
    % שלח אחורה
    uistack(newLine,'bottom');
    
    % מחק ConstantLine
    delete(h);
    
end

% --- החזרת מצב קודם ---
set(groot,'ShowHiddenHandles',H0);

end
