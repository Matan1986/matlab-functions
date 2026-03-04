function runPhaseC_leaveOneOut()

    %% -------- USER EDIT: path to baseline MAT --------
    % Put here the path to your baseline saved resultsLOO struct.
    baselineMatPath = fullfile(pwd, 'results', 'baseline_resultsLOO.mat'); % <-- EDIT ME
    assert(isfile(baselineMatPath), "Baseline MAT not found: %s", baselineMatPath);

    S = load(baselineMatPath);

    % Accept either S.resultsLOO or S.results (map if needed)
    if isfield(S,'resultsLOO')
        R = S.resultsLOO;
    elseif isfield(S,'results')
        R = S.results; % mapping section below can handle
    else
        error("MAT file must contain 'resultsLOO' or 'results' struct.");
    end

    %% -------- Mapping section (ONLY if needed) --------
    % If your struct uses other field names, map them here WITHOUT touching pipeline.
    % Expected: Tp, Rsw, C, A, F
    if ~isfield(R,'Tp') && isfield(R,'Tp_vec'); R.Tp = R.Tp_vec; end
    if ~isfield(R,'Rsw') && isfield(R,'Rsw_vec'); R.Rsw = R.Rsw_vec; end
    if ~isfield(R,'C') && isfield(R,'coexistence'); R.C = R.coexistence; end
    if ~isfield(R,'A') && isfield(R,'D_interp'); R.A = R.D_interp; end
    if ~isfield(R,'F') && isfield(R,'F_interp'); R.F = R.F_interp; end

    required = {'Tp','Rsw','C','A','F'};
    for k = 1:numel(required)
        assert(isfield(R,required{k}), "Missing field R.%s in loaded struct.", required{k});
    end

    Tp  = R.Tp(:);
    Rsw = R.Rsw(:);
    C   = R.C(:);
    A   = R.A(:);
    F   = R.F(:);

    N = numel(Tp);
    assert(numel(Rsw)==N && numel(C)==N && numel(A)==N && numel(F)==N, ...
        "All vectors must have same length.");

    %% Quick NaN diagnostics (do not fail unless all NaN)
    nanCounts = [sum(isnan(Tp)) sum(isnan(Rsw)) sum(isnan(C)) sum(isnan(A)) sum(isnan(F))];
    if any(nanCounts>0)
        warning("NaNs detected [Tp Rsw C A F] = [%d %d %d %d %d]. corr uses rows=complete.", nanCounts);
    end

    %% Baseline metrics (all points)
    baseCorrC = corr(C, Rsw, 'rows','complete');
    baseCorrA = corr(A, Rsw, 'rows','complete');
    baseCorrF = corr(F, Rsw, 'rows','complete');

    baseMdl = fitlm(C, Rsw);
    baseR2 = baseMdl.Rsquared.Ordinary;
    baseSlope = baseMdl.Coefficients.Estimate(2);

    fprintf("\n=== Phase C1: Leave-One-Out on Tp (statistical-only) ===\n");
    fprintf("Baseline (all points): corrC=%.4f | R2=%.4f | slope=%.4f\n", baseCorrC, baseR2, baseSlope);
    fprintf("Baseline: corrA=%.4f | corrF=%.4f\n\n", baseCorrA, baseCorrF);

    %% LOO loop
    corrC = nan(N,1);
    corrA = nan(N,1);
    corrF = nan(N,1);
    R2    = nan(N,1);
    slope = nan(N,1);
    Nused = nan(N,1);

    minPts = 3; % must have at least 3 non-NaN paired points to be meaningful

    for i = 1:N
        mask = true(N,1);
        mask(i) = false;

        % For correlations, rows='complete' will drop NaN rows automatically, but we need Nused for C/Rsw
        validCR = mask & ~isnan(C) & ~isnan(Rsw);
        Nused(i) = sum(validCR);

        if Nused(i) < minPts
            warning("Skipping i=%d (Tp=%.4g): too few valid points after removal (Nused=%d).", i, Tp(i), Nused(i));
            continue;
        end

        corrC(i) = corr(C(mask), Rsw(mask), 'rows','complete');
        corrA(i) = corr(A(mask), Rsw(mask), 'rows','complete');
        corrF(i) = corr(F(mask), Rsw(mask), 'rows','complete');

        mdl = fitlm(C(mask), Rsw(mask));
        R2(i) = mdl.Rsquared.Ordinary;
        slope(i) = mdl.Coefficients.Estimate(2);
    end

    %% Build table
    LOO = table(Tp, corrC, R2, slope, corrA, corrF, Nused, ...
        'VariableNames', {'Tp_removed','corrC','R2','slope','corrA','corrF','N_used'});

    % Add baseline values as metadata struct for saving
    baseline = struct('corrC',baseCorrC,'R2',baseR2,'slope',baseSlope,'corrA',baseCorrA,'corrF',baseCorrF);

    %% Save outputs
    stamp = datestr(now, 'yyyymmdd_HHMMSS');
    outDir = fullfile(pwd, 'results', 'phaseC', ['leaveOneOut_' stamp]);
    if ~exist(outDir,'dir'); mkdir(outDir); end

    save(fullfile(outDir,'leaveOneOut_results.mat'), 'LOO', 'baseline', 'baselineMatPath');
    writetable(LOO, fullfile(outDir,'leaveOneOut_results.csv'));

    %% Plot
    figure('Name','LOO corrC vs Tp_removed');
    plot(Tp, corrC, 'o-'); grid on;
    yline(baseCorrC);
    xlabel('Tp removed');
    ylabel('corr(Coexistence, Rsw)');
    title('Phase C1: Leave-One-Out Stability (statistical-only)');
    saveas(gcf, fullfile(outDir,'leaveOneOut_corrC.png'));

    fprintf("Saved outputs to: %s\n", outDir);
    disp(LOO);

end
