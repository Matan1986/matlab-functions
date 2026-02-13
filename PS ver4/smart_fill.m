function y = smart_fill(y, bad)

    x = (1:numel(y))';

    % ----- מסכה אמיתית לכל הנקודות שצריך למלא -----
    badFill = bad | isnan(y);   % <<< זה כל ההבדל

    % ----- מקרה קצה: אין בכלל Outliers או NaN -----
    if ~any(badFill)
        y = sgolay_safe(y);
        return;
    end

    % ----- מקרה קצה: מעט מדי נקודות טובות -----
    good = ~badFill;
    if sum(good) < 2
        y = sgolay_safe(y);
        return;
    end

    % ----- אינטרפולציה על כל החורים -----
    y(badFill) = interp1(x(good), y(good), x(badFill), 'pchip');

    % ----- החלקת SGOLAY עדינה -----
    y = sgolay_safe(y);
end

function y = sgolay_safe(y)
    N = numel(y);
    w = min(11, N);
    if mod(w,2)==0, w = w-1; end
    if w >= 3
        y = sgolayfilt(y, 3, w);
    end
end
