%% ACHC_main.m
clc; clear; close all;
disp('Running ACHC_main');

%% 1) User options
Cs_Cr_plotMode       = 'B';        % 'S'=sample, 'R'=reference, 'B'=both
C_or_CoverT_plotType = 'norm';     % 'raw','norm','both'
CsCr_plotLayout      = 'separate'; % 'overlay' or 'separate'
includeDiff          = true;       % include Cs-Cr difference
xVar                 = 'Angle';    % choose 'Temp','Angle','Field'
slowVar              = 'Field';    % the one we hide from legend if needed
fastVar              = 'Temp';     % the one that stays in legend
applyShift           = true;
Mirror               = false;
xVarRef              = 185;
shiftFactor          = 0.003e-9;
SortMode             = 'both';     % sort rule
addSuffix            = false;
temp_jump_threshold  = 3;
Fontsize             = 14;
analysis_and_fitt    = false;      % הפיט הישן מבוטל, יש חדש

%% --- Fit options (ישן, אם תרצה בעתיד) ---
fitMode = 'Cr_norm';
fold1   = 6;   % symmetry fold (n-fold) לפיט הישן אם תחזיר אותו

%% NEW OPTION — hide slow var in legend
showSlowVarInLegend = false;   % <–––––––––––––– החדש

%% NEW OPTION — fold detection mode for new analysis
% 'auto'   – זיהוי אוטומטי מהנתונים
% 'manual' – לכפות fold אחד לכל הדאטאסטים (למשל 6)
foldMode   = 'auto';   % 'auto' או 'manual'
manualFold = [];        % בשימוש רק אם foldMode = 'manual'
foldSignal = 'Cs';   % 'Cr' | 'Cs' | 'Diff'
Qmode = 'partialFourier';   % 'relativeNoise' / 'fractionalVariance' / 'stability' / 'partialFourier'
% Qmode options:
% 'relativeNoise'       – automatic fold detection (default)
% 'fractionalVariance'  – physical significance of symmetry
% 'stability'           – stable Q(n,T) maps
% 'partialFourier'     – PARTIAL angular coverage
verbose = true;   % true / false
plotPerDataset = false;   % true / false

%% NEW OPTION — extrema detection (local, guided by fold)
extremaOpts = struct();

% --- smoothing ---
extremaOpts.sgolayOrder = 3;
extremaOpts.sgolayFrame = 11;

% --- peak detection (fold-normalized) ---
extremaOpts.minPeakDistFrac = 0.4;   % fraction of period P
extremaOpts.minPromFrac     = 0.15;

% --- behavior ---
extremaOpts.useMeasuredOnly = true;
extremaOpts.debugPlot       = false;

%% 2) Paths & file listing
addpath(genpath('C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions'));

dataDir  = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\Differential AC Heat Capacity\Co0p29TaS2 MG119 but MG131 like, In plane\Angle Sweep at 15T diff Temp';

lineWidth = 1.5;
dAll    = dir(dataDir);
names   = {dAll.name};
pattern = '^.+_\d+$';
isData  = ~[dAll.isdir] ...
    & ~endsWith(names, '.ini','IgnoreCase',true) ...
    & ~cellfun(@isempty, regexp(names, pattern, 'once'));

fileList = names(isData);
if isempty(fileList)
    error('No data files matching *_# in folder.');
end

%% 3) Import all files
data = importFilesACHC(dataDir, fileList);

%% 4) Extract slow & fast vars
switch slowVar
    case 'Temp',  slowVals = arrayfun(@(d) mean(d.Ts,    'omitnan'), data);
    case 'Angle', slowVals = arrayfun(@(d) mean(d.Angle, 'omitnan'), data);
    case 'Field', slowVals = arrayfun(@(d) mean(d.Field, 'omitnan'), data);
end

switch fastVar
    case 'Temp',  fastVals = arrayfun(@(d) mean(d.Ts,    'omitnan'), data);
    case 'Angle', fastVals = arrayfun(@(d) mean(d.Angle, 'omitnan'), data);
    case 'Field', fastVals = arrayfun(@(d) mean(d.Field, 'omitnan'), data);
end

%% 5) Clean rounding
slowValsR = round(slowVals * 1e2) / 1e2;
fastValsR = round(fastVals * 1e2) / 1e2;

%% 6) Sorting
switch SortMode
    case 'fast'
        [~, idx] = sort(fastValsR);
    case 'slow'
        [~, idx] = sort(slowValsR);
    case 'both'
        [~, idx] = sortrows([slowValsR(:), fastValsR(:)], [1,2]);
end

%% reorder everything
fileList   = fileList(idx);
data       = data(idx);
slowVals   = slowVals(idx);
fastVals   = fastVals(idx);
slowValsR  = slowValsR(idx);
fastValsR  = fastValsR(idx);

%% 7) label maps — FIX
labelMap.Temp  = 'T';
labelMap.Angle = 'Angle';
labelMap.Field = 'B';

unitMap.Temp  = 'K';
unitMap.Angle = '°';
unitMap.Field = 'T';

%% display sorted
disp('Files in sorted order:');
for i = 1:numel(fileList)
    fprintf('%s: %s = %.2f %s, %s = %.2f %s\n', ...
        fileList{i}, ...
        slowVar, slowValsR(i), unitMap.(slowVar), ...
        fastVar, fastValsR(i), unitMap.(fastVar));
end

%% 8) Build legend strings
sv = slowValsR;
fv = fastValsR;

if showSlowVarInLegend
    legendStrings = arrayfun(@(s,f) ...
        sprintf('%s=%.1f%s, %s=%.1f%s', ...
        labelMap.(fastVar), f, unitMap.(fastVar), ...
        labelMap.(slowVar), s, unitMap.(slowVar)), ...
        sv, fv, 'Uni', false);
else
    legendStrings = arrayfun(@(f) ...
        sprintf('%s=%.1f%s', ...
        labelMap.(fastVar), f, unitMap.(fastVar)), ...
        fv, 'Uni', false);
end

%% 9) slowVarStr for title / figure name
slowVarStr = sprintf('%s = %.2f %s', ...
    labelMap.(slowVar), slowValsR(1), unitMap.(slowVar));

%% 10) unpack arrays
n          = numel(data);
Temp_S     = arrayfun(@(d) d.Ts,         data, 'Uni', false);
C_S        = arrayfun(@(d) d.Cs,         data, 'Uni', false);
Temp_R     = arrayfun(@(d) d.Tr,         data, 'Uni', false);
C_R        = arrayfun(@(d) d.Cr,         data, 'Uni', false);
Cdiff      = arrayfun(@(d) d.Cdiff,      data, 'Uni', false);

Cs_norm    = arrayfun(@(d) d.Cs_norm,    data, 'Uni', false);
Cr_norm    = arrayfun(@(d) d.Cr_norm,    data, 'Uni', false);
Cdiff_norm = arrayfun(@(d) d.Cdiff_norm, data, 'Uni', false);

Angle      = arrayfun(@(d) d.Angle,      data, 'Uni', false);
Field      = arrayfun(@(d) d.Field,      data, 'Uni', false);

%% 10b) DEBUG: angle monotonicity (with tolerance)
tol = 0.2;   % degrees — אפשר לשחק בין 0.05 ל-0.3

for i = 1:n
    ang = Angle{i};

    fprintf('\n--- Check %s ---\n', fileList{i});
    fprintf('Angle range: %.1f → %.1f deg\n', min(ang), max(ang));

    d = diff(ang);

    isUp   = all(d >= -tol);
    isDown = all(d <=  tol);

    if isUp
        disp('Angle is monotonic ↑ (within tolerance)');
    elseif isDown
        disp('Angle is monotonic ↓ (within tolerance)');
    else
        disp('Angle is NON-monotonic (true back & forth!)  <<< PROBLEM');
    end

    fprintf('min diff = %.4f deg, max diff = %.4f deg\n', min(d), max(d));

    neg = d(d < -tol);
    if ~isempty(neg)
        fprintf('large negative steps: count=%d, median=%.3f, min=%.3f\n', ...
            numel(neg), median(neg), min(neg));
    end
end


%% colormap
if numel(unique(slowVals)) * numel(unique(fastVals)) < 5
    colors = lines(n);
else
    colors = parula(n);
end

%% 11) Plot
PlotsACHC( Temp_S, C_S, Temp_R, C_R, Cdiff, ...
    Cs_norm, Cr_norm, Cdiff_norm, ...
    Angle, Field, slowValsR, fastValsR, colors, ...
    temp_jump_threshold, Fontsize, legendStrings, ...
    Cs_Cr_plotMode, C_or_CoverT_plotType, ...
    CsCr_plotLayout, includeDiff, xVar, ...
    lineWidth, applyShift, shiftFactor, addSuffix, ...
    SortMode, false, xVarRef, showSlowVarInLegend, slowVarStr);

%% 12) Mirror mode
if Mirror
    switch xVar
        case 'Temp'
            [Temp_S, Cs_norm]    = mirrorAcross(Temp_S, Cs_norm, xVarRef, n);
            [Temp_R, Cr_norm]    = mirrorAcross(Temp_R, Cr_norm, xVarRef, n);
            [Temp_S, Cdiff_norm] = mirrorAcross(Temp_S, Cdiff_norm, xVarRef, n);

        case 'Angle'
            [Angle, Cs_norm]    = mirrorAcross(Angle, Cs_norm, xVarRef, n);
            [Angle, Cr_norm]    = mirrorAcross(Angle, Cr_norm, xVarRef, n);
            [Angle, Cdiff_norm] = mirrorAcross(Angle, Cdiff_norm, xVarRef, n);

        case 'Field'
            [Field, Cs_norm]    = mirrorAcross(Field, Cs_norm, xVarRef, n);
            [Field, Cr_norm]    = mirrorAcross(Field, Cr_norm, xVarRef, n);
            [Field, Cdiff_norm] = mirrorAcross(Field, Cdiff_norm, xVarRef, n);
    end

    PlotsACHC( Temp_S, C_S, Temp_R, C_R, Cdiff, ...
        Cs_norm, Cr_norm, Cdiff_norm, ...
        Angle, Field, slowValsR, fastValsR, colors, ...
        temp_jump_threshold, Fontsize, legendStrings, ...
        Cs_Cr_plotMode, C_or_CoverT_plotType, ...
        CsCr_plotLayout, includeDiff, xVar, ...
        lineWidth, applyShift, shiftFactor, addSuffix, ...
        SortMode, true, xVarRef, showSlowVarInLegend, slowVarStr );
end

%% ================================================================
%   EXTRA ANALYSIS — AUTO FOLD DETECTION + PER-DATASET FITS
% ================================================================
switch foldSignal
    case 'Cr'
        Y_for_fold = Cr_norm;
        foldLabel  = 'Cr';

    case 'Cs'
        Y_for_fold = Cs_norm;
        foldLabel  = 'Cs';

    case 'Diff'
        Y_for_fold = Cdiff_norm;
        foldLabel  = 'Cs - Cr';

    otherwise
        error('Unknown foldSignal option');
end

disp('Running automatic folding + fits');
results = ACHC_runAuto(Angle, Y_for_fold, legendStrings, foldMode, manualFold, Qmode, verbose,plotPerDataset,foldSignal,extremaOpts);
disp('--- Auto-analysis completed ---');

% ===============================
% Build Q(n,T) matrix
% ===============================
Tvals = fastValsR;
folds = results.foldsTested;
nF    = numel(folds);
nT    = numel(Tvals);

Qmat = nan(nF, nT);

for i = 1:nT
    if ~isempty(results.Qall{i}) && ~all(isnan(results.Qall{i}))
        Qmat(:,i) = results.Qall{i}(:);
    end
end

figure('Name','Folding quality Q(n,T)','Color','w');

imagesc(Tvals, folds, Qmat);
axis xy;
yticks(folds);              % force all n values on axis
ylim([min(folds) max(folds)])

xlabel('Temperature [K]');
ylabel('Fold n');
title(sprintf('Folding quality map Q(n,T) — %s', foldLabel));

cb = colorbar;
cb.Label.String = 'Folding quality Q';

set(gca,'FontSize',14);
colormap(parula);
grid on;


formatAllFigures([0.1, 0.1, 0.4, 0.4], 18, 18, 2.5);
