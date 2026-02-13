function results = ACHC_runAuto(Angle, Cr, legendStrings, ...
    foldMode, manualFold, Qmode, ...
    verbose, plotPerDataset, signalLabel,extremaOpts)

% ACHC_runAuto
% Automatic n-fold symmetry detection
% Optional console output (verbose)
% Optional per-dataset plots (plotPerDataset)
%
% Angle          : cell array of angle vectors
% Cr             : cell array of signals (Cr / Cs / Cdiff etc.)
% legendStrings  : labels per dataset
% foldMode       : 'auto' | 'manual'
% manualFold     : scalar n (used if foldMode='manual')
% Qmode          : 'relativeNoise' | 'fractionalVariance' | 'stability' | 'partialFourier'
% verbose        : true / false (console diagnostics)
% plotPerDataset : true / false (draw figures per dataset)
% signalLabel    : string for y-axis label (e.g. 'C_r')

%% ---------------- defaults ----------------
if nargin < 4 || isempty(foldMode),        foldMode        = 'auto'; end
if nargin < 5 || isempty(manualFold),      manualFold      = 6;      end
if nargin < 6 || isempty(Qmode),           Qmode           = 'relativeNoise'; end
if nargin < 7 || isempty(verbose),         verbose         = false; end
if nargin < 8 || isempty(plotPerDataset),  plotPerDataset  = true;  end
if nargin < 9 || isempty(signalLabel),     signalLabel     = 'C';   end
if nargin < 10 || isempty(extremaOpts)
    extremaOpts = struct();
end

nDatasets = numel(Angle);
folds = 3:12;

%% ---------------- allocate ----------------
results.fold        = nan(1,nDatasets);
results.Q           = nan(1,nDatasets);
results.fold2       = nan(1,nDatasets);
results.Q2          = nan(1,nDatasets);
results.Qall        = cell(1,nDatasets);
results.A1          = nan(1,nDatasets);
results.A2          = nan(1,nDatasets);
results.signal      = false(1,nDatasets);
results.maxAngles   = cell(1,nDatasets);
results.minAngles   = cell(1,nDatasets);
results.foldsTested = folds;

if verbose
    fprintf('\n=== Folding analysis per dataset ===\n');
end

%% ============================================================
for i = 1:nDatasets

    %% -------- raw data --------
    theta = Angle{i}(:);
    yraw  = Cr{i}(:);
    label = legendStrings{i};

    %% -------- monotonicity check --------
    tol = 0.2;  % deg
    d = diff(theta);
    isMono = all(d >= -tol) || all(d <= tol);

    if ~isMono
        if verbose
            fprintf('WARNING: %s non-monotonic angle sweep – skipping\n', label);
        end
        results.Qall{i} = nan(size(folds));
        continue
    end

    %% -------- sort & detrend --------
    [theta, idx] = sort(theta);
    y = detrend(yraw(idx));

    %% -------- compute Q(n) --------
    Qall = nan(size(folds));
    for k = 1:numel(folds)
        switch Qmode
            case 'relativeNoise'
                Qall(k) = foldingQuality_relativeNoise(theta, y, folds(k), 1);
            case 'fractionalVariance'
                Qall(k) = foldingQuality_fractionalVariance(theta, y, folds(k), 1);
            case 'stability'
                Qall(k) = foldingQuality_stability(theta, y, folds(k), 1);
            case 'partialFourier'
                Qall(k) = foldingQuality_partialFourier(theta, y, folds(k));
            otherwise
                error('Unknown Qmode: %s', Qmode);
        end
    end
    results.Qall{i} = Qall;

    if verbose
        fprintf('%s | Qall:', label);
        for ii = 1:numel(folds)
            if isnan(Qall(ii))
                fprintf(' %d:NaN', folds(ii));
            else
                fprintf(' %d:%.2f', folds(ii), Qall(ii));
            end
        end
        fprintf('\n');
    end

    %% -------- choose two best folds --------
    fold1 = NaN; Q1 = NaN;
    fold2 = NaN; Q2 = NaN;

    if strcmpi(foldMode,'manual')
        fold1 = manualFold;
        idx1  = folds == fold1;
        if any(idx1), Q1 = Qall(idx1); end

        Qtmp = Qall; Qtmp(idx1) = NaN;
        [Q2, idx2] = max(Qtmp);
        if ~isnan(Q2), fold2 = folds(idx2); end

    else
        valid = ~isnan(Qall);
        if any(valid)
            foldsV = folds(valid);
            Qv     = Qall(valid);
            [Qs, is] = sort(Qv,'descend');
            fold1 = foldsV(is(1)); Q1 = Qs(1);
            if numel(Qs) >= 2
                fold2 = foldsV(is(2)); Q2 = Qs(2);
            end
        end
    end

    %% -------- signal decision --------
    if isnan(Q1)
        hasSignal = false;
    else
        switch Qmode
            case 'relativeNoise'
                hasSignal = Q1 > 2;
            case 'fractionalVariance'
                hasSignal = Q1 > 0.15;
            case 'stability'
                hasSignal = Q1 > 0.5;
            case 'partialFourier'
                % סף יותר “קשוח” כדי לא לסמן signal בכל טמפ'
                hasSignal = Q1 > 0.8;
        end
    end

    %% -------- folded data (defined BEFORE fit) --------
    if ~isnan(fold1)
        P = 360 / fold1;
        thetaFold = mod(theta, P);
        [thetaFold, idxF] = sort(thetaFold);
        yFold = y(idxF);
    else
        P = NaN; thetaFold = []; yFold = [];
    end

    %% -------- folded Fourier fit (creates p!) --------
    p = [];
    if hasSignal && ~isempty(thetaFold)
        p = fit_folded(thetaFold, yFold, fold1, 2);
    end

    if hasSignal && ~isempty(p) && ~any(isnan(p))
        A1 = hypot(p(2), p(3));
        A2 = hypot(p(4), p(5));
    else
        A1 = 0; A2 = 0;
    end

    %% -------- extrema (always if fold exists) --------
    canExtractExtrema = ~isnan(fold1) && ~isnan(Q1);

    if canExtractExtrema
        [angMax, angMin] = extrema_from_fold_local(theta, y, fold1, extremaOpts);
    else
        angMax = [];
        angMin = [];
    end

    %% -------- store --------
    results.fold(i)      = fold1;
    results.Q(i)         = Q1;
    results.fold2(i)     = fold2;
    results.Q2(i)        = Q2;
    results.A1(i)        = A1;
    results.A2(i)        = A2;
    results.signal(i)    = hasSignal;
    results.maxAngles{i} = angMax;
    results.minAngles{i} = angMin;

    if verbose
        fprintf('%s | fold1=%g (Q=%.2f) | fold2=%g (Q=%.2f) | Qmode=%s\n', ...
            label, fold1, Q1, fold2, Q2, Qmode);
    end

    %% ================= PLOTS =================
    if plotPerDataset
        figure('Name',label,'Color','w');

        % --- raw ---
        subplot(3,1,1)
        plot(theta, y, '.-'); hold on
        yl = ylim;
        for a = angMax, plot([a a], yl, 'r--'); end
        for a = angMin, plot([a a], yl, 'b--'); end
        xlabel('Angle [deg]')
        ylabel([signalLabel ' (detrended)'])
        title([label ' | raw'])
        grid on

        % --- folded ---
        subplot(3,1,2)
        if ~isempty(thetaFold)
            plot(thetaFold, yFold, 'k.'); hold on
            if hasSignal && ~isempty(p) && ~any(isnan(p))
                th = linspace(0,P,400);
                plot(th, fourier_model(p, th*pi/180, fold1, 2), ...
                    'r','LineWidth',1.5);
            end
            xlabel(sprintf('Angle mod %.1f°',P))
            title(sprintf('fold=%g | Q=%.2f', fold1, Q1))
        else
            text(0.5,0.5,'No valid fold','Units','normalized', ...
                'HorizontalAlignment','center');
        end
        ylabel([signalLabel ' (folded)'])
        grid on

        % --- Q vs fold ---
        subplot(3,1,3)
        plot(folds, Qall, 'o-','LineWidth',1.5); hold on
        if ~isnan(Q1), plot(fold1, Q1, 'ro','MarkerFaceColor','r'); end
        if ~isnan(Q2), plot(fold2, Q2, 'ks','MarkerFaceColor','k'); end
        xlabel('fold n')
        ylabel('Folding quality Q')
        title('Q vs fold')
        grid on
    end

end
%% ============================================================

ACHC_buildFoldingTable(results, legendStrings);
end
