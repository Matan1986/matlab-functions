function p = fit_folded(thetaDeg, y, fold, Nh)

thetaDeg = thetaDeg(:);
y        = y(:);

nPar = 1 + 2*Nh;
if numel(y) < max(8, nPar+1)     % מינימום שמרני
    p = nan(1,nPar);
    return;
end

th = thetaDeg * pi/180;

model = @(p,th) fourier_model(p, th, fold, Nh);

p0 = zeros(1,nPar);
p0(1) = mean(y);

opts = optimoptions('lsqcurvefit','Display','off');

try
    p = lsqcurvefit(model, p0, th, y, [], [], opts);
catch
    p = nan(1,nPar);
end

end
