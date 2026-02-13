function foldDetected = detect_fold_fft(x, y, maxFold)
% DETECT_FOLD_FFT  (harmonic projection)
% Detect dominant n-fold (n = 1..maxFold) in y(x), x in degrees.

    if nargin < 3
        maxFold = 12;
    end

    % Remove NaNs
    good = ~isnan(x) & ~isnan(y);
    x = x(good);
    y = y(good);

    % Sort by angle
    [x, idx] = sort(x);
    y = y(idx);

    % Merge duplicate angles by averaging y
    [xUnique, ~, ic] = unique(x);
    if numel(xUnique) < numel(x)
        yUnique = accumarray(ic, y, [], @mean);
        x = xUnique;
        y = yUnique;
    end

    % Work in radians
    theta = x * pi/180;

    % Remove DC
    y0  = y - mean(y);
    den = sum(y0.^2);
    if den == 0
        foldDetected = 1;
        fprintf('detect_fold_fft: zero-variance signal, returning fold=1\n');
        return;
    end

    amps = zeros(maxFold,1);
    R2   = zeros(maxFold,1);

    for n = 1:maxFold
        c = cos(n*theta);
        s = sin(n*theta);
        M = [c, s];

        coeff = M \ y0;
        a = coeff(1);
        b = coeff(2);

        yhat = M * coeff;

        amps(n) = sqrt(a^2 + b^2);
        R2(n)   = 1 - sum((y0 - yhat).^2) / den;
    end

    metric = amps .* max(R2,0);

    [~, foldDetected] = max(metric);

    fprintf('Harmonic amps (n=1..%d): ', maxFold);
    fprintf('%.3g ', amps);
    fprintf('| best n = %d\n', foldDetected);

end
