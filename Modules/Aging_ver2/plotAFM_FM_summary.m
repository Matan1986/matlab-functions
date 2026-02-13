function plotAFM_FM_summary(pauseRuns, fontsize, showErrors)
% plotAFM_FM_summary
% ------------------------------------------------------------
% Summary of AFM / FM decomposition:
%   (a) AFM dip amplitude vs pause temperature
%   (b) AFM dip area vs pause temperature
%   (c) FM step magnitude vs pause temperature
%
% showErrors:
%   true  → plot error bars (AFM + FM)
%   false → plot values only (clean trend view)
% ------------------------------------------------------------

if nargin < 2 || isempty(fontsize)
    fontsize = 16;
end
if nargin < 3 || isempty(showErrors)
    showErrors = true;
end

% ---------------- Extract data ----------------
Tp        = [pauseRuns.waitK];
AFM_amp   = [pauseRuns.AFM_amp];
AFM_area  = [pauseRuns.AFM_area];
FM_step   = [pauseRuns.FM_step_mag];

AFM_amp_err  = [pauseRuns.AFM_amp_err];
AFM_area_err = [pauseRuns.AFM_area_err];

if isfield(pauseRuns,'FM_step_err')
    FM_err = [pauseRuns.FM_step_err];
else
    FM_err = NaN(size(FM_step));
end

validFM = isfinite(FM_step);
xlim_common = [min(Tp) max(Tp)];

% ---------------- Figure ----------------
figure('Color','w','Name','AFM / FM Summary');
tiledlayout(3,1,'TileSpacing','compact','Padding','compact');

% ============================================================
% (a) AFM dip amplitude
% ============================================================
nexttile;
if showErrors
    errorbar(Tp, AFM_amp, AFM_amp_err, ...
        'o-', 'LineWidth',1.8, 'MarkerSize',6, 'CapSize',8);
else
    plot(Tp, AFM_amp, 'o-', 'LineWidth',1.8, 'MarkerSize',6);
end
xlim(xlim_common);
ylabel('AFM dip amplitude');

% ============================================================
% (b) AFM dip area
% ============================================================
nexttile;
if showErrors
    errorbar(Tp, AFM_area, AFM_area_err, ...
        'o-', 'LineWidth',1.8, 'MarkerSize',6, 'CapSize',8);
else
    plot(Tp, AFM_area, 'o-', 'LineWidth',1.8, 'MarkerSize',6);
end
xlim(xlim_common);
ylabel('AFM dip area');

% ============================================================
% (c) FM step magnitude
% ============================================================
nexttile;
hold on;
if any(validFM)
    if showErrors
        errorbar(Tp(validFM), FM_step(validFM), FM_err(validFM), ...
            'o-', 'LineWidth',1.8, 'MarkerSize',6, 'CapSize',8);
    else
        plot(Tp(validFM), FM_step(validFM), ...
            'o-', 'LineWidth',1.8, 'MarkerSize',6);
    end
else
    text(mean(xlim_common), 0, 'No valid FM step', ...
        'HorizontalAlignment','center');
end
xlim(xlim_common);
xlabel('Pause Temperature (K)');
ylabel('FM step magnitude');

% ---------------- Formatting ----------------
set(findall(gcf,'-property','FontSize'),'FontSize',fontsize);

end
