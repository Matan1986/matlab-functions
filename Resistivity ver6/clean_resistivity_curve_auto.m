function y_clean = clean_resistivity_curve_auto(temp, y, showPlots)
% CLEAN_RESISTIVITY_CURVE_AUTO
% Adaptive, physics-consistent filtering for ρ(T)

if nargin < 3
    showPlots = false;
end

temp = temp(:);
y    = y(:);
N    = numel(y);

%% 1) Rolling MAD (adaptive noise estimate)
W_mad = max(21, round(N/100));
W_mad = min(W_mad, 501);

rolling_MAD = movmad(y, W_mad, 1);
global_noise = median(rolling_MAD,'omitnan');

%% 2) Median filter (adaptive)
MedianWindow = max(3, round(W_mad/8));
MedianWindow = min(MedianWindow, 41);

y_med = medfilt1(y, MedianWindow, 'omitnan', 'truncate');

%% 3) Residuals
resid = abs(y - y_med);

%% 4) Outlier detection using rolling MAD of residuals
rolling_resid_MAD = movmad(resid, W_mad, 1);
MAD_thr = 3 * rolling_resid_MAD + 2 * global_noise;

mask_good = (resid <= MAD_thr) | isnan(resid);

%% 5) Replace outliers with median
y_fixed = y;
y_fixed(~mask_good) = y_med(~mask_good);

%% 6) Savitzky-Golay smoothing (adaptive)
SG_window = round(N / 70);
SG_window = max(21, SG_window);
SG_window = min(SG_window, 401);
if mod(SG_window,2)==0, SG_window = SG_window + 1; end

SG_order = 3;

y_clean = sgolayfilt(y_fixed, SG_order, SG_window);

%% 7) Diagnostic plot
if showPlots
    figure('Name','Adaptive Resistivity Cleaning');
    plot(temp, y, 'k.', 'DisplayName','Raw'); hold on;
    plot(temp, y_med, 'b-', 'DisplayName','Median');
    plot(temp, y_fixed, 'm-', 'DisplayName','Outlier Removed');
    plot(temp, y_clean, 'r-', 'LineWidth',2, 'DisplayName','Final SG');
    xlabel('Temperature [K]'); ylabel('ρ / R (arb)');
    title('Adaptive Resistivity Cleaning');
    legend('Location','best'); grid on;
end

end
