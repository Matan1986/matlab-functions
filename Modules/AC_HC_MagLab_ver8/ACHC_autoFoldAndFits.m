function results = ACHC_autoFoldAndFits(Angle, Cr_norm, legendStrings)

n = numel(Angle);

%% Stage 1 — Detect folds
detFold = zeros(1,n);
for i = 1:n
    detFold(i) = detect_fold_fft(Angle{i}, Cr_norm{i}, 12);
end

%% Stage 2 — Fits
A_all   = zeros(n,1);
phi_all = zeros(n,1);
d_all   = zeros(n,1);
R2_all  = zeros(n,1);

for i = 1:n
    x = Angle{i};
    y = Cr_norm{i};
    fold_i = detFold(i);

    [A, phi_deg, d0, stats] = fit_with_fold(x, y, fold_i, legendStrings{i});

    A_all(i)   = A;
    phi_all(i) = phi_deg;
    d_all(i)   = d0;
    R2_all(i)  = stats(2);
end

results.detFold = detFold;
results.A       = A_all;
results.phi     = phi_all;
results.d       = d_all;
results.R2      = R2_all;

end
