function y_clean = remove_outliers(y, percent_jump, percent_median)

    if nargin < 3
        percent_median = 300;   % לא קריטי אבל משאיר תאימות אחורה
    end
    if nargin < 2
        percent_jump = 150;
    end

    y = y(:);
    y_clean = y;

    %% ===== 1) סף Outlier מבוסס על dy (שינוי בין נקודות) =====
    dy = abs(diff(y));
    med_dy = nanmedian(dy);

    % מקרים של אות שטוח מדי — למנוע threshold = 0
    if med_dy == 0 || isnan(med_dy)
        med_dy = nanmean(dy);
        if med_dy == 0 || isnan(med_dy)
            % אין מה לנקות — תחזיר החלקה עדינה
            y_clean = sg_safe(y_clean);
            return;
        end
    end

    % סף לזיהוי קפיצות
    thr_jump = med_dy * (percent_jump / 100);

    % Outlier על בסיס שינוי גבוה מדי
    bad_jump = [false; dy > thr_jump];

    %% ===== 2) סטיות אמפליטודה רק אם המשרעת באמת משמעותית =====
    medY = nanmedian(y);
    thr_med = abs(medY) * (percent_median / 100);

    bad_med = abs(y - medY) > thr_med;

    %% ===== 3) מסכה של נקודות בעייתיות =====
    bad = bad_jump | bad_med;

    % בנוסף: נקודות NaN קיימות מהשלבים הקודמים → ממלאים גם אותן
    badFill = bad | isnan(y);

    %% ===== 4) מילוי חכם (PCHIP + SGOLAY) =====
    y_clean = smart_fill_minimal(y_clean, badFill);

end
function y = smart_fill_minimal(y, bad)

    x = (1:numel(y))';

    good = ~bad;

    % מקרה קצה: מעט מדי נקודות תקינות
    if sum(good) < 2
        y = sg_safe(y);
        return;
    end

    % אינטרפולציה PCHIP חלקה ותואמת
    y(bad) = interp1(x(good), y(good), x(bad), 'pchip');

    % החלקת SGOLAY עדינה
    y = sg_safe(y);
end
function y = sg_safe(y)
    N = numel(y);
    w = min(11, N);
    if mod(w,2)==0, w = w - 1; end
    if w >= 3
        y = sgolayfilt(y, 3, w);
    end
end

