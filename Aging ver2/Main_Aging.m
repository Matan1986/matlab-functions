%% MAIN_AGING_MEMORY — Spin-glass aging memory analysis (no fitting)
% Reads all aging-memory .dat files, identifies "pause" vs "no-pause" runs,
% computes ΔM(T) = M_noPause - M_pause, and plots M(T) and ΔM(T).

clc; clear; close_all_except_ui_figures;

%% --- User Settings ---
normalizeByMass = true;
color_scheme     = 'thermal';
fontsize         = 24;
linewidth        = 2.2;
debugMode        = false;
Bohar_units      = true;  % true → µB/Co ; false → emu/g
useAutoYScale = true;   % true / false
RobustnessCheck = false;
%% --- MAIN FIGURE summary mode (FIT-based only) ---
AFM_metric_main = 'height';   % 'height' | 'area'
% 'height' → Dip_A
% 'area'   → Dip_area
%%
doFit_MF_Gaussian = true;
%% --- AFM / FM normalization control ---
normalizeAFM_FM = true;     % true → normalize AFM and FM separately
                            % false → plot absolute values (current behavior)AFM_metric_main
dip_window_K     = 4;     % ±K window around pause T to find dip
smoothWindow_K = 6 * dip_window_K;   % FM scale (physics-first)
%% --- AFM / FM analysis display control ---
showAFM_FM_example = false;   % true / false
showAllPauses_AFmFM = true;   % true → plot AFM/FM for all pause temperatures
examplePause_K = [];   % vector of pause temperatures to show
%% --- FM background reliability control ---
excludeLowT_FM = true;      % true / false
excludeLowT_K  = 5;         % ignore T < excludeLowT_K when estimating FM
%% --- FM / AFM plateau geometry ---
FM_plateau_K    = 6;      % רוחב הפלטו
FM_buffer_K     = 4;      % מרחק מהדיפ
excludeLowT_mode = 'pre'; % איך מוציאים low-T
%% --- AFM / FM error bar display control ---
showAFM_errors = false;    % true → show error bars | false → hide error bars
%% --- Color control for pause markers (xlines) ---
colorRange  = [0 1];
% fraction of colormap used for vertical pause markers
% [0 1]   → full colormap (current behavior)
% [0.25 0.75] → compressed (recommended)
% [0.40 0.60] → very subtle
%% --- ΔM subtraction convention ---
subtractOrder = 'pauseMinusNo';
% options:
%   'noMinusPause'    → ΔM = M_noPause − M_pause   (ברירת מחדל, הקיים)
%   'pauseMinusNo'    → ΔM = M_pause − M_noPause
%% --- ΔM filtering (post-analysis, professional) ---
doFilterDeltaM   = true;
filterMethod     = 'sgolay';   % 'sgolay' | 'movmean' | 'movmedian'
sgolayOrder      = 2;
sgolayFrame      = 15;          % odd, small
%% --- ΔM alignment (visual only) ---
alignDeltaM      = false;          % false → no alignment
alignRef         = 'lowT';         % 'lowT' | 'highT'
alignWindow_K    = 2;            % average window around ref T

%% --- Offset controls for ΔM(T) plots ---
offsetMode       = 'none';   % 'vertical' | 'horizontal' | 'none'
offsetValue      = 120;          % offset magnitude as % of max ΔM amplitude (p-p)
%% --- Define data dir ---
dir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane Aging no field high res\Analyzed only";

%% --- Save options ---
saveTableMode = 'none';          % 'none' | 'figure' | 'excel' | 'both'
outputFolder  = fullfile(dir, 'Results');

%% --- Add MATLAB paths ---
baseFolder = 'C:\User\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions';
addpath(genpath(baseFolder));

%% --- Extract sample info from path ---
[growth_num, FIB_num] = extract_growth_FIB(dir, []);
sample_name = sprintf('MG %d', growth_num);

%% --- Step 1: Get file list ---
[file_noPause, pauseRuns] = getFileList_aging(dir);

%% --- Step 2: Import data ---
[noPause_T, noPause_M] = importFiles_aging(file_noPause, normalizeByMass, debugMode);
for i = 1:numel(pauseRuns)
    [pauseRuns(i).T, pauseRuns(i).M] = importFiles_aging(pauseRuns(i).file, normalizeByMass, debugMode);
end

%% --- Step 3: Convert units to µB/Co if requested ---
if Bohar_units
    [noPause_M, pauseRuns] = convertToMuBperCo(noPause_M, pauseRuns);
end

%% --- Step 4a: Analysis (ΔM computation) ---
[pauseRuns, pauseRuns_raw] = computeDeltaM( ...
    noPause_T, noPause_M, pauseRuns, ...
    dip_window_K, subtractOrder, ...
    alignDeltaM, alignRef, alignWindow_K, ...
    doFilterDeltaM, filterMethod, sgolayOrder, sgolayFrame);

%% --- Step 4b: AFM FM Analysis ---
pauseRuns = analyzeAFM_FM_components( ...
    pauseRuns, dip_window_K, smoothWindow_K, ...
    excludeLowT_FM, excludeLowT_K, ...
    FM_plateau_K, excludeLowT_mode, FM_buffer_K, ...
    AFM_metric_main);

% -------- Robustness check (optional, local sanity) --------

if RobustnessCheck

    % =========================================================
    % Robustness parameter sweep (broader coverage)
    % =========================================================
    % Goals:
    %  - probe wider smoothing scales (smoothWindow_K)
    %  - probe wider plateau geometry (FM_plateau_K, FM_buffer_K)
    %  - keep everything deterministic and comparable

    k = 0;

    % --- choose smoothing multipliers (relative to dip_window_K) ---
    smoothMult = [2 3 4 6 8 10];     % <<< expanded to larger domains

    % --- choose plateau widths (K) ---
    plateauList = [4 6 8 12 16];     % <<< expanded

    % --- choose buffers away from dip (K) ---
    bufferList  = [2 4 6 8 10];      % <<< expanded

    for sm = smoothMult
        for pl = plateauList
            for bf = bufferList

                % Skip unphysical combos: plateau should not be too small vs buffer
                if pl < 2
                    continue;
                end

                % Skip too-aggressive near-dip: ensure buffer at least ~dip_window_K/2
                if bf < 0.5*dip_window_K
                    continue;
                end

                k = k + 1;

                paramSet(k) = struct( ...
                    'label', sprintf('sm=%gx | pl=%gK | bf=%gK', sm, pl, bf), ...
                    'smoothWindow_K', sm*dip_window_K, ...
                    'FM_plateau_K',   pl, ...
                    'FM_buffer_K',    bf);

            end
        end
    end

    % Run the check
    plotAFM_FM_robustnessCheck( ...
        pauseRuns, dip_window_K, ...
        excludeLowT_FM, excludeLowT_K, excludeLowT_mode, ...
        paramSet, fontsize);

end


if showAFM_FM_example

    allPauseK = [pauseRuns.waitK];

    if showAllPauses_AFmFM
        pauseList = allPauseK;
    else
        pauseList = examplePause_K;
    end

    for k = 1:numel(pauseList)

        Tp_req = pauseList(k);
        idx = find(allPauseK == Tp_req, 1);

        if isempty(idx)
            warning('Requested pause %.1f K not found. Skipping.', Tp_req);
            continue;
        end

        plotAFM_FM_decomposition(pauseRuns(idx));

    end
end

%% --- Step 4c: MF(FM) + Gaussian(dip) fitting (NEW) ---

fitOpts = struct();
fitOpts.windowFactor = 4;
fitOpts.minWindow_K  = 25;
fitOpts.debugPlots   = false; %%%%%%%%%%%%%%%%%%%% Debub plots

pauseRuns_fit = fitFMstep_plus_GaussianDip( ...
    pauseRuns_raw, dip_window_K, fitOpts);

for i = 1:numel(pauseRuns)
    pauseRuns(i).FM_step_A     = pauseRuns_fit(i).FM_step_A;
    pauseRuns(i).Dip_A         = pauseRuns_fit(i).Dip_A;
    pauseRuns(i).Dip_sigma    = pauseRuns_fit(i).Dip_sigma;
    pauseRuns(i).Dip_T0       = pauseRuns_fit(i).Dip_T0;
    pauseRuns(i).fit_R2        = pauseRuns_fit(i).fit_R2;
    pauseRuns(i).fit_RMSE      = pauseRuns_fit(i).fit_RMSE;
    pauseRuns(i).fit_NRMSE     = pauseRuns_fit(i).fit_NRMSE;
    pauseRuns(i).fit_chi2_red  = pauseRuns_fit(i).fit_chi2_red;
    pauseRuns(i).fit_curve     = pauseRuns_fit(i).fit_curve;
    pauseRuns(i).FM_E = pauseRuns_fit(i).FM_E;
    pauseRuns(i).FM_area_abs = pauseRuns_fit(i).FM_area_abs;
end
% --- derived memory strength (integrated dip weight) ---
for i = 1:numel(pauseRuns)
    pauseRuns(i).Dip_area = ...
        pauseRuns(i).Dip_A * sqrt(2*pi) * pauseRuns(i).Dip_sigma;
end

% plotAFM_FM_summary(pauseRuns, fontsize, showAFM_errors);
% plotAgingMemory_AFM_vs_FM(pauseRuns, fontsize, showAFM_errors,normalizeAFM_FM);

DipA     = [pauseRuns.Dip_A];
DipSigma = [pauseRuns.Dip_sigma];
FMstepA  = [pauseRuns.FM_step_A];
Tp       = [pauseRuns.waitK];

fprintf('\n=== Dip sigma statistics ===\n');
fprintf('min sigma = %.2f K\n', min(DipSigma));
fprintf('max sigma = %.2f K\n', max(DipSigma));
fprintf('mean sigma = %.2f K\n', mean(DipSigma));
fprintf('std/mean = %.2f\n', std(DipSigma)/mean(DipSigma));
% --- extra diagnostics: does sigma add independent info? ---
R_As = corr(DipA(:), DipSigma(:), 'rows','complete');
fprintf('corr(Dip_A, Dip_sigma) = %.2f\n', R_As);

% --- build per-component "strength" metrics (not ratios) ---
Dip_area = DipA .* sqrt(2*pi) .* DipSigma;   % integrated Gaussian weight

% normalize for comparison across metrics (z-score)
Z = @(x) (x - mean(x,'omitnan')) ./ (std(x,'omitnan') + eps);

Z_FM      = Z(FMstepA);
Z_DipA    = Z(DipA);
Z_DipArea = Z(Dip_area);

% --- quick table (all pauses) ---
diagTbl = table(Tp(:), FMstepA(:), DipA(:), DipSigma(:), Dip_area(:), ...
    Z_FM(:), Z_DipA(:), Z_DipArea(:), ...
    'VariableNames', {'Tp_K','FM_step_A','Dip_A','Dip_sigma_K','Dip_area','Z_FM','Z_DipA','Z_DipArea'});

disp(diagTbl);

% --- show only 5 representative pauses (spread across Tp) ---
n = numel(Tp);
idx5 = unique(round(linspace(1,n, min(5,n))));
disp(diagTbl(idx5,:));

% --- simple diagnostic plot: which metric separates pauses better? ---
figure('Color','w', ...
       'Name','Diagnostic: AFM vs FM metric variability', ...
       'NumberTitle','off');

ax = axes; 
hold(ax,'on');

plot(Tp, Z_FM, '-o',['LineWi' ...
    'dth'],1.5);
plot(Tp, Z_DipA, '-o','LineWidth',1.5);
plot(Tp, Z_DipArea, '-o','LineWidth',1.5);
xlabel('T_p (K)');
ylabel('Z-score (relative variation)');
legend('FM\_step\_A','Dip\_A','Dip\_area','Location','best');
title('Diagnostic: which component metric varies most across pauses?');
Tp        = [pauseRuns.waitK];
Dip_area = [pauseRuns.Dip_area];
FM_step  = [pauseRuns.FM_step_A];

% --- auto scaling (based on what is actually plotted) ---
FMvec = [pauseRuns.FM_E];   % row vector

switch AFM_metric_main
    case 'height'
        AFMvec = [pauseRuns.Dip_A];      % row vector
        unitStr = '\mu_B / Co';

    case 'area'
        AFMvec = [pauseRuns.Dip_area];   % row vector
        unitStr = '\mu_B·K / Co';

    otherwise
        error('Unknown AFM_metric_main: %s', AFM_metric_main);
end

% build probe vector (column), remove NaNs/Infs
yProbe = [AFMvec(:); FMvec(:)];
yProbe = yProbe(isfinite(yProbe));

if isempty(yProbe)
    warning('Auto-scale probe is empty. Falling back to scalePower=0.');
    scalePower  = 0;
    scaleFactor = 1;
else
    scalePower  = chooseAutoScalePower(yProbe);
    scaleFactor = 10^(scalePower);
end

% ===============================
% Build AFM / FM vectors for MAIN FIGURE
% ===============================

switch AFM_metric_main
    case 'height'
        Y_AFM = [pauseRuns.Dip_A];
        unitStr = '\mu_B / Co';

    case 'area'
        Y_AFM = [pauseRuns.Dip_area];
        unitStr = '\mu_B\cdot K / Co';

    otherwise
        error('Unknown AFM_metric_main: %s', AFM_metric_main);
end

Y_FM = [pauseRuns.FM_E];   % local FM strength (RMS from fit)

% ===============================
% Colormap for pause temperatures (Tp)
% ===============================
Tp = [pauseRuns.waitK];
Tp = Tp(:)';

cmap = cmocean('thermal',256);

Tp_norm = (Tp - min(Tp)) ./ ...
          (max(Tp) - min(Tp) + eps);

idx = round(1 + Tp_norm*(size(cmap,1)-1));
Tp_colors = cmap(idx,:);






% --- marker style (locked for both panels) ---
markerEdgeColor = 'k';
markerEdgeWidth = 0.6;

figure('Color','w', ...
       'Name','Aging memory summary', ...
       'NumberTitle','off');


% ---------- (a) AFM memory (FIT-based) ----------
ax1 = subplot(2,1,1); hold(ax1,'on');

ax1.TickDir = 'in';
ax1.Box = 'on';
ax1.Layer = 'top';
ax1.FontName = 'Times New Roman';
ax1.TickLabelInterpreter = 'latex';
ax1.XMinorTick = 'off';
ax1.YMinorTick = 'off';
grid(ax1,'off');

% guide line
plot(Tp, Y_AFM * scaleFactor, '-', ...
    'Color',[0.6 0.6 0.6], 'LineWidth',1.2);

% markers
for i = 1:numel(Tp)
    plot(Tp(i), Y_AFM(i)*scaleFactor, 'o', ...
    'MarkerSize',9, ...
        'MarkerFaceColor',Tp_colors(i,:), ...
        'MarkerEdgeColor',markerEdgeColor, ...
        'LineWidth',markerEdgeWidth);
end

ylab_AFM = sprintf([ ...
    '$\\mathrm{AFM-like}$\n' ...
    '$\\mathrm{(10^{-%d}\\ %s)}$' ], ...
    scalePower, unitStr);

hY1 = ylabel(ylab_AFM,'Interpreter','latex');
set(hY1,'FontSize',fontsize-2);

set(ax1,'FontSize',fontsize-2)
set(ax1,'XTick',Tp)
xlim(ax1,[min(Tp)-1 max(Tp)+1])
ylim(ax1,[0 3])


% ---------- (b) FM background (FIT-based) ----------
ax2 = subplot(2,1,2); hold(ax2,'on');

ax2.TickDir = 'in';
ax2.Box = 'on';
ax2.Layer = 'top';
ax2.FontName = 'Times New Roman';
ax2.TickLabelInterpreter = 'latex';
ax2.XMinorTick = 'off';
ax2.YMinorTick = 'off';
grid(ax2,'off');

% guide line
plot(Tp, Y_FM * scaleFactor, '-', ...
    'Color',[0.6 0.6 0.6], 'LineWidth',1.2);

% markers
for i = 1:numel(Tp)
    plot(Tp(i), Y_FM(i)*scaleFactor, 'o', ...
    'MarkerSize',9, ...
        'MarkerFaceColor',Tp_colors(i,:), ...
        'MarkerEdgeColor',markerEdgeColor, ...
        'LineWidth',markerEdgeWidth);
end

xlabel('Pause temperature (K)','Interpreter','latex');

ylab_FM = sprintf([ ...
    '$\\mathrm{FM-like}$\n' ...
    '$\\mathrm{(10^{-%d}\\ \\mu_{\\mathrm{B}}/\\mathrm{Co})}$' ], ...
    scalePower);

hY2 = ylabel(ylab_FM,'Interpreter','latex');
set(hY2,'FontSize',fontsize-2);

set(ax2,'FontSize',fontsize-2)
set(ax2,'XTick',Tp)
xlim(ax2,[min(Tp)-1 max(Tp)+1])
ylim(ax2,[0 3])

set(ax1,'XTickLabel',[])

pos1 = ax1.Position;
pos2 = ax2.Position;

newHeight = 0.38;

ax1.Position = [pos1(1), 0.58, pos1(3), newHeight];
ax2.Position = [pos2(1), 0.08, pos2(3), newHeight];


linkaxes(findall(gcf,'Type','axes'),'x');

%%
mode = 'experimental';   % 'experimental' 'fit'
Tsw = [ ...
4 6 8 10 12.01 14 16 18 20 22 24 26 28 30 32 34 ];
Rsw = abs([ ...
-0.118798584194838
-0.122264267325776
-0.118851761632771
-0.101822896954594
-0.0788304623579251
-0.0593463579408640
-0.0498599138258924
-0.0428929207553538
-0.0415806933904911
-0.0430961878264001
-0.0500748615139096
-0.0693882621296171
-0.0809671274875996
-0.0367692256085554
-0.00532765237477462
-0.000552867428264816 ]);

params = struct();
params.dipWindowK  = 4;     % חלון הדיפ לאינטגרל
params.wideWindowK = 25;    % חלון רחב להערכת הרקע
params.lambdaMin   = 0.03;  % טווח סריקת λ
params.lambdaMax   = 1.2;
params.nLambda     = 100;   % כמה נקודות לסריקה
params.fitTmin     = 4;     % טווח פיט
params.fitTmax     = 34;

result = reconstructSwitchingAmplitude( ...
    mode, ...
    pauseRuns, ...
    params, ...
    Tp, ...
    Tsw, ...
    Rsw);

%% =========================================================
%  Competition model test (mid/high-T only: 10–30 K)
% ==========================================================
fprintf('\nλ = %.3f\n', result.lambda);
fprintf('a = %.3f\n', result.a);
fprintf('b = %.3f\n', result.b);
fprintf('R² = %.3f\n', result.R2);

figure;
plot(Tsw, Rsw, 'ko','LineWidth',2); hold on;
plot(Tsw, result.Rhat, 'r-','LineWidth',2);
legend('Measured','Reconstructed');
xlabel('T (K)');
ylabel('\DeltaR');

A = result.D_basis(:);
B = result.F_basis(:);

mask = (Tsw >= 10) & (Tsw <= 30);

Rplot = Rsw(mask) / max(Rsw(mask));

figure; hold on;

plot(Tsw(mask), Rplot, 'k','LineWidth',3);

plot(Tsw(mask), A(mask), 'b','LineWidth',2);
plot(Tsw(mask), B(mask), 'g','LineWidth',2);

plot(Tsw(mask), A(mask).*(1-A(mask)), 'm','LineWidth',2);

imb = abs(A - B);
imb_norm = imb / max(imb(mask));

plot(Tsw(mask), 1 - imb_norm(mask), 'c','LineWidth',2);

legend('Rsw','A','B','A(1-A)','1-norm(|A-B|)');
grid on;

imb = abs(A - B);
G = 1 - imb;

mask = (Tsw >= 10) & (Tsw <= 30);

X = [G(mask), ones(sum(mask),1)];
y = Rsw(mask);

beta = X \ y;

Rhat = X * beta;

SS_tot = sum((y - mean(y)).^2);
SS_res = sum((Rhat - y).^2);
R2 = 1 - SS_res/SS_tot;

fprintf('R2 (with offset) = %.4f\n', R2);
%% --- Step 5: Plot results (with optional offset) ---
plotAgingMemory(noPause_T, noPause_M, pauseRuns, color_scheme, ...
    fontsize, linewidth, sample_name, Bohar_units, ...
    offsetMode, offsetValue, dip_window_K, colorRange, useAutoYScale);

%% --- Step 6: Save summary table (optional) ---
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Build summary table from pauseRuns
pauseK        = [pauseRuns.waitK]';
DeltaM_pause  = [pauseRuns.DeltaM_atPause]';
DeltaM_min    = [pauseRuns.DeltaM_localMin]';

T_min = nan(numel(pauseRuns),1);
for i = 1:numel(pauseRuns)
    if isfield(pauseRuns(i),'T_localMin') && ~isempty(pauseRuns(i).T_localMin)
        T_min(i) = pauseRuns(i).T_localMin;
    end
end

% Create clean ASCII table
summaryTbl = table(pauseK, DeltaM_pause, DeltaM_min, T_min, ...
    'VariableNames', {'Pause_K', 'DeltaM_atPause', 'DeltaM_localMin', 'T_localMin_K'});

% Round numbers
summaryTbl.Pause_K        = round(summaryTbl.Pause_K, 3);
summaryTbl.T_localMin_K   = round(summaryTbl.T_localMin_K, 3);

% Pretty column names for uitable (ASCII only)
prettyNames = {'Pause T (K)', ...
    'DeltaM at pause', ...
    'DeltaM local min', ...
    'T local min (K)'};

%% --- Always show summary table figure ---
tblData = table2cell(summaryTbl);

% Convert numeric columns to scientific notation
tblData(:,2) = convertToScientificStr(summaryTbl.DeltaM_atPause, 3);
tblData(:,3) = convertToScientificStr(summaryTbl.DeltaM_localMin, 3);
tblData(:,4) = convertToScientificStr(summaryTbl.T_localMin_K, 3);

% Create table figure (ALWAYS)
f_tbl = figure('Color','w','Name','DeltaM Summary Table');
t = uitable('Parent', f_tbl, ...
    'Data', tblData, ...
    'ColumnName', prettyNames, ...
    'Units','normalized', ...
    'Position',[0 0 1 1]);

set(t, 'FontSize', 14, ...
    'RowStriping', 'on', ...
    'ColumnWidth', {130,130,130,150});


switch lower(saveTableMode)
    case 'none'
        % do nothing (table already shown)

    case 'excel'
        outFile = fullfile(outputFolder, sprintf('%s_AgingSummary.xlsx', sample_name));
        writetable(summaryTbl, outFile);
        fprintf('Saved summary table to %s\n', outFile);

    case 'figure'
        outFig = fullfile(outputFolder, sprintf('%s_AgingSummary.fig', sample_name));
        savefig(f_tbl, outFig);
        fprintf('Saved table figure to %s\n', outFig);

    case 'both'
        outFile = fullfile(outputFolder, sprintf('%s_AgingSummary.xlsx', sample_name));
        writetable(summaryTbl, outFile);

        outFig = fullfile(outputFolder, sprintf('%s_AgingSummary.fig', sample_name));
        savefig(f_tbl, outFig);

        fprintf('Saved Excel + FIG in %s\n', outputFolder);

    otherwise
        warning('Unknown saveTableMode "%s". Use none|figure|excel|both.', saveTableMode);
end


%% --- Step 7: Format figures (optional) ---

%{
formatAllFigures( ...
    fontsize, fontsize, ...     % ← Axes FS, Legend FS
    'pos',[0.1,0.1,0.75,0.7], ...
    'clearTitles',false, ...
    'showLegend',true, ...
    'showGrid',true);
%}
function S = convertToScientificStr(x, digits)
if nargin < 2
    digits = 3;
end
S = cell(size(x));
for i = 1:numel(x)
    if isnan(x(i))
        S{i} = '';
    else
        S{i} = sprintf(['%0.', num2str(digits), 'e'], x(i));
    end
end
end


