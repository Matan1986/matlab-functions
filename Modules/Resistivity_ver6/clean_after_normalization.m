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
    y(bad) = NaN;
end