function q = switchingSafeFraction(num, den)
%SWITCHINGSAFEFRACTION Elementwise ratio with NaN where undefined.

q = num ./ den;
q(~isfinite(q)) = NaN;
end
