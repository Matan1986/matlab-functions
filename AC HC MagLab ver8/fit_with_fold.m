function [A, phi_deg, d, stats] = fit_with_fold(x, y, fold_i, label)
% FIT_WITH_FOLD
%   fit: y(x) = A * sin(fold_i * x*pi/180 + phi) + d

    if nargin < 4 || isempty(label)
        label = '(unnamed)';
    end

    % Remove NaNs
    good = ~isnan(x) & ~isnan(y);
    x = x(good);
    y = y(good);

    % Column vectors
    x = x(:);
    y = y(:);

    % Sort by angle
    [x, idx] = sort(x);
    y = y(idx);

    if numel(x) < 5
        warning('fit_with_fold:TooFewPoints', ...
            'Too few points for "%s" (n=%d).', label, numel(x));
        A = NaN; phi_deg = NaN; d = NaN;
        stats = [NaN NaN NaN NaN];
        return;
    end

    % Initial guesses
    A0   = (max(y) - min(y)) / 2;
    phi0 = 0;
    d0   = mean(y);

    % Amplitude sanity check
    ampRange = max(y) - min(y);
    yScale   = max(abs(y));
    if yScale == 0
        yScale = 1;
    end
    relAmp = ampRange / yScale;

    if ampRange < 1e-12 || relAmp < 1e-3
        fprintf('Warning: tiny modulation in "%s": Δy=%.3g, rel=%.3g → phase may be unreliable.\n', ...
            label, ampRange, relAmp);
    end

    ft = fittype( ...
        'A * sin(f * x * pi/180 + phi) + d', ...
        'independent','x', ...
        'coefficients',{'A','phi','d'}, ...
        'problem','f' ...
    );

    opts = fitoptions('Method','NonlinearLeastSquares', ...
                      'StartPoint',[A0, phi0, d0], ...
                      'MaxIter',2000, 'TolFun',1e-12);

    try
        [fitobj, g] = fit(x, y, ft, opts, 'problem', fold_i);

        A       = fitobj.A;
        phi_deg = fitobj.phi * 180/pi;
        d       = fitobj.d;
        stats   = [g.sse, g.rsquare, g.adjrsquare, g.rmse];

    catch ME
        warning('Fit failed for "%s": %s', label, ME.message);
        A = NaN; phi_deg = NaN; d = NaN;
        stats = [NaN NaN NaN NaN];
    end
end
