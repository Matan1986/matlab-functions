function yhat = leaveOneOutPredict(X, y)
    y = y(:);
    n = numel(y);
    yhat = nan(n, 1);

    for i = 1:n
        mask = true(n, 1);
        mask(i) = false;
        Xtrain = X(mask, :);
        ytrain = y(mask);

        try
            coef = Xtrain \ ytrain;
        catch
            % Fallback for singular/ill-conditioned design matrices.
            coef = pinv(Xtrain) * ytrain;
        end

        yhat(i) = X(i, :) * coef;
    end
end

