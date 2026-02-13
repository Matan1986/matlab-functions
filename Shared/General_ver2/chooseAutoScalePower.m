function scalePower = chooseAutoScalePower(yData)
% chooseAutoScalePower
% -----------------------------------------
% Chooses power so that scaled values are O(1)
% SAFE: works on data only, no axis interaction

    yData = yData(isfinite(yData) & yData ~= 0);
    if isempty(yData)
        scalePower = 0;
        return;
    end

    maxVal = max(abs(yData));
    rawPower = floor(log10(maxVal));

    % We want: y * 10^scalePower ~ O(1)
    scalePower = -rawPower;

    % Safety: do not scale if already reasonable
    if abs(scalePower) <= 1
        scalePower = 0;
    end

    % Optional hard limits (recommended)
    scalePower = min(max(scalePower, -9), 9);
end
