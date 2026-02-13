function y = clean_after_normalization(y, jumpPercent, medianFactor)

    medAbs = nanmedian(abs(y));
    if medAbs == 0 || isnan(medAbs)
        medAbs = max(abs(y));
    end

    thrJump = medAbs * (jumpPercent/100);
    thrMed  = medAbs * medianFactor;

    dy = abs(diff(y));
    badJump = [false; dy > thrJump];
    badMed  = abs(y - nanmedian(y)) > thrMed;

    bad = badJump | badMed;

    % ---- הגנה על הקצוות ----
    nProtect = 10;   % כמה נקודות בכל צד לא לגעת
    bad(1:nProtect) = false;
    bad(end-nProtect+1:end) = false;

    % מילוי חכם
    y = fill_outliers_smart(y, bad);


end

function y = fill_outliers_smart(y, bad)

    x = (1:numel(y))';

    % מקרה קצה: הכל Outlier → החלקה בלבד
    if sum(~bad) < 2
        y = sg_safe(y);
        return;
    end

good = ~bad & ~isnan(y);
y(bad) = interp1(x(good), y(good), x(bad), 'pchip');

    % SGOLAY עדין, לא מעוות AMR
    y = sg_safe(y);
end
function y = sg_safe(y)
    N = numel(y);
    w = min(11, N);
    if mod(w,2)==0, w = w-1; end
    if w >= 3
        y = sgolayfilt(y, 3, w);
    end
end
