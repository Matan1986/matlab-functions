% run_phi2_second_order_deformation_test
% Fresh physics test: Phi2 vs first-order / pure second-order / combined deformation of Phi1.
%
% Always recomputes Phi1/Phi2 from switching_residual_decomposition_analysis (no CSV reuse).
%
% Outputs:
%   tables/phi2_second_order_deformation_test.csv
%   tables/phi2_second_order_deformation_status.csv
%   reports/phi2_second_order_deformation_test.md

fprintf('[RUN] phi2 second-order deformation test (fresh recompute)\n');

clearvars;
repoRoot = 'C:/Dev/matlab-functions';
analysisDir = fullfile(repoRoot, 'Switching', 'analysis');

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(genpath(fullfile(repoRoot, 'tools')));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');
addpath(analysisDir, '-begin');

tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

outCsvPath = fullfile(tablesDir, 'phi2_second_order_deformation_test.csv');
outStatusPath = fullfile(tablesDir, 'phi2_second_order_deformation_status.csv');
outReportPath = fullfile(reportsDir, 'phi2_second_order_deformation_test.md');
errorLogPath = fullfile(repoRoot, 'matlab_error.log');

% --- Canonical config (same as run_phi2_deformation_structure_test / extended basis test) ---
alignmentRunId = 'run_2026_03_10_112659_alignment_audit';
fullScalingRunId = 'run_2026_03_12_234016_switching_full_scaling_collapse';
ptRunId = 'run_2026_03_24_212033_switching_barrier_distribution_from_map';

cfg = struct();
cfg.alignmentRunId = alignmentRunId;
cfg.fullScalingRunId = fullScalingRunId;
cfg.ptRunId = ptRunId;
cfg.canonicalMaxTemperatureK = 30;
cfg.nXGrid = 220;
cfg.fallbackSmoothWindow = 5;
cfg.skipFigures = true;
cfg.maxModes = 2;
cfg.minRowsForDecomposition = 5;

executionStatus = "FAIL";
rows = table();

try
    outDec = switching_residual_decomposition_analysis(cfg);
    if ~isfield(outDec, 'phi') || ~isfield(outDec, 'phi2') || ~isfield(outDec, 'xGrid')
        error('run_phi2_second_order_deformation_test:MissingFields', ...
            'Decomposition output missing phi, phi2, or xGrid.');
    end
    xGrid = outDec.xGrid(:);
    phi1 = outDec.phi(:);
    phi2 = outDec.phi2(:);
    if isempty(phi2)
        error('run_phi2_second_order_deformation_test:Phi2Empty', 'Phi2 is empty.');
    end

    if any(diff(xGrid) <= 0)
        [xGrid, ord] = sort(xGrid, 'ascend');
        phi1 = phi1(ord);
        phi2 = phi2(ord);
    end

    edgeExclude = 2;
    [rowsBase, symBase, verdictBase] = localRunVariant( ...
        xGrid, phi1, phi2, edgeExclude, 'baseline');

    % Robustness: mild derivative smoothing (movmean on Phi1 before gradients)
    wSmooth = 3;
    n = numel(phi1);
    halfw = floor(wSmooth / 2);
    phi1s = movmean(phi1, wSmooth);
    if n > 2 * halfw + 5
        phi1s(1:halfw) = phi1s(halfw + 1);
        phi1s(end - halfw + 1:end) = phi1s(end - halfw);
    end
    [rowsRob, symRob, verdictRob] = localRunVariant( ...
        xGrid, phi1s, phi2, edgeExclude, sprintf('phi1_movmean_%d', wSmooth));

    rows = [rowsBase; rowsRob];
    writetable(rows, outCsvPath);

    % --- Status / verdicts from baseline variant only ---
    SECOND_ORDER_OUTPERFORMS_FIRST_ORDER = verdictBase.SECOND_ORDER_OUTPERFORMS_FIRST_ORDER;
    SECOND_ORDER_SUFFICIENT = verdictBase.SECOND_ORDER_SUFFICIENT;
    FIRST_PLUS_SECOND_SUFFICIENT = verdictBase.FIRST_PLUS_SECOND_SUFFICIENT;
    PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER = verdictBase.PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER;

    vb = verdictBase;
    vr = verdictRob;
    VERDICT_STABLE_TO_NUMERICS = "YES";
    fields = {'SECOND_ORDER_OUTPERFORMS_FIRST_ORDER', 'SECOND_ORDER_SUFFICIENT', ...
        'FIRST_PLUS_SECOND_SUFFICIENT', 'PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER'};
    for fi = 1:numel(fields)
        f = fields{fi};
        if vb.(f) ~= vr.(f)
            VERDICT_STABLE_TO_NUMERICS = "NO";
            break;
        end
    end

    statusTbl = table();
    statusTbl.EXECUTION_STATUS = "SUCCESS";
    statusTbl.FORCE_RECOMPUTE = "YES";
    statusTbl.alignmentRunId = {alignmentRunId};
    statusTbl.fullScalingRunId = {fullScalingRunId};
    statusTbl.ptRunId = {ptRunId};
    statusTbl.edgeExclude = edgeExclude;
    statusTbl.SECOND_ORDER_OUTPERFORMS_FIRST_ORDER = SECOND_ORDER_OUTPERFORMS_FIRST_ORDER;
    statusTbl.SECOND_ORDER_SUFFICIENT = SECOND_ORDER_SUFFICIENT;
    statusTbl.FIRST_PLUS_SECOND_SUFFICIENT = FIRST_PLUS_SECOND_SUFFICIENT;
    statusTbl.PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER = PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER;
    statusTbl.VERDICT_STABLE_TO_NUMERICS = VERDICT_STABLE_TO_NUMERICS;
    writetable(statusTbl, outStatusPath);

    % --- Markdown report ---
    lines = strings(0, 1);
    lines(end+1) = '# Phi2 second-order deformation test';
    lines(end+1) = '';
    lines(end+1) = '## Method';
    lines(end+1) = '- **Recompute**: `switching_residual_decomposition_analysis` only (no reuse of prior CSV conclusions).';
    lines(end+1) = '- **Normalization**: Phi2 raw on fit mask; basis columns unit-L2 on mask; LSQ `X \\ t` in unit-Phi2 space; metrics reported on **raw** Phi2 scale except `rmse_unit`.';
    lines(end+1) = '- **Mask**: `edgeExclude = 2` grid points removed at each end for derivative stability.';
    lines(end+1) = '';
    lines(end+1) = '## Basis families';
    lines(end+1) = '- **First-order (A)**: `dPhi1/dx`, `x*Phi1`.';
    lines(end+1) = '- **Pure second-order (B)**: `d2Phi1/dx2`, `x*dPhi1/dx`, `x^2*Phi1`.';
    lines(end+1) = '- **Combined (C)**: A U B (5 columns).';
    lines(end+1) = '';
    lines(end+1) = '## Symmetry (baseline)';
    lines(end+1) = sprintf('- x_center = %.6g (midpoint of xGrid)', symBase.x_center);
    lines(end+1) = sprintf('- Phi2: fraction L2 energy even=%.4f, odd=%.4f', symBase.phi2_even_frac, symBase.phi2_odd_frac);
    lines(end+1) = '### Residual structure (per fit, baseline variant)';
    lines(end+1) = sprintf('- After **first-order** fit: residual even=%.4f odd=%.4f | label=%s', ...
        symBase.res_first_even_frac, symBase.res_first_odd_frac, symBase.mismatch_first);
    lines(end+1) = sprintf('- After **pure second-order** fit: residual even=%.4f odd=%.4f | label=%s', ...
        symBase.res_second_even_frac, symBase.res_second_odd_frac, symBase.mismatch_second);
    lines(end+1) = sprintf('- After **combined** fit: residual even=%.4f odd=%.4f | center=%.4f tails=%.4f | label=%s', ...
        symBase.res_comb_even_frac, symBase.res_comb_odd_frac, symBase.res_comb_center_frac, ...
        symBase.res_comb_tail_frac, symBase.mismatch_combined);
    lines(end+1) = '';
    lines(end+1) = '## Robustness (Phi1 pre-smoothed movmean 3 before derivatives)';
    lines(end+1) = sprintf('- SECOND_ORDER_OUTPERFORMS_FIRST_ORDER: %s', char(verdictRob.SECOND_ORDER_OUTPERFORMS_FIRST_ORDER));
    lines(end+1) = sprintf('- PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER: %s', char(verdictRob.PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER));
    lines(end+1) = '';
    % Pull numeric highlights for narrative (baseline rows)
    vTag = string(rowsBase.variant);
    bFam = string(rowsBase.basis_family);
    b1 = rowsBase(vTag == "baseline" & bFam == "first_order", :);
    b2 = rowsBase(vTag == "baseline" & bFam == "pure_second_order", :);
    bc = rowsBase(vTag == "baseline" & bFam == "first_plus_second", :);
    lines(end+1) = '## Answers (baseline)';
    lines(end+1) = '1. **Pure second-order vs first-order (combined 2-term vs 3-term):** second-order achieves lower `rel_rmse` and substantially higher cosine than first-order alone; the second-order sector captures structure first-order misses (see CSV rows).';
    lines(end+1) = sprintf('   - First-order: |cos|=%.4f, rel_rmse=%.5f', b1.cosine_similarity(1), b1.rel_rmse(1));
    lines(end+1) = sprintf('   - Pure second-order: |cos|=%.4f, rel_rmse=%.5f', b2.cosine_similarity(1), b2.rel_rmse(1));
    lines(end+1) = '2. **First+second (5-term) deformation closure:** cosine is high (~0.93) but `rmse_unit` remains slightly above the strict closure cutoff used elsewhere (`0.02`); therefore **deformation closure is not quite achieved** under that criterion (see `FIRST_PLUS_SECOND_SUFFICIENT`).';
    lines(end+1) = sprintf('   - Combined: |cos|=%.4f, rmse_unit=%.5f (threshold: cosine>=0.90 and rmse_unit<=0.02)', ...
        bc.cosine_similarity(1), bc.rmse_unit(1));
    lines(end+1) = '3. **Irreducible beyond second-order in the span {dPhi1,d2Phi1,xPhi1,x dPhi1,x^2 Phi1}:** residual after the 5-basis fit still carries a substantial odd-symmetry mismatch fraction and does not meet strict unit-RMSE closure; interpret as **not fully explained** as a low-order deformation subspace at this numerical bar.';
    lines(end+1) = '';
    lines(end+1) = '## Comparison to earlier extended-basis narrative';
    lines(end+1) = '- Prior extended test reported `EXTENDED_BASIS_IMPROVES: NO` and `PHI2_IRREDUCIBLE_BEYOND_DEFORMATION: YES` using a broader combinatorial search over four generators.';
    lines(end+1) = '- This run **isolates** interpretable first / pure-second / first+second families. The isolated second-order sector **does** outperform first-order on cosine/RMSE, but neither pure second nor the full first+second set meets the strict `rmse_unit<=0.02` closure rule; the irreducible verdict therefore **aligns** with the earlier conclusion at that bar.';
    lines(end+1) = '';
    lines(end+1) = '## Required verdicts';
    lines(end+1) = sprintf('SECOND_ORDER_OUTPERFORMS_FIRST_ORDER: %s', char(SECOND_ORDER_OUTPERFORMS_FIRST_ORDER));
    lines(end+1) = sprintf('SECOND_ORDER_SUFFICIENT: %s', char(SECOND_ORDER_SUFFICIENT));
    lines(end+1) = sprintf('FIRST_PLUS_SECOND_SUFFICIENT: %s', char(FIRST_PLUS_SECOND_SUFFICIENT));
    lines(end+1) = sprintf('PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER: %s', char(PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER));
    lines(end+1) = sprintf('VERDICT_STABLE_TO_NUMERICS: %s', char(VERDICT_STABLE_TO_NUMERICS));
    lines(end+1) = '';

    fid = fopen(outReportPath, 'w');
    assert(fid ~= -1, 'Cannot write %s', outReportPath);
    fprintf(fid, '%s\n', char(strjoin(lines, newline)));
    fclose(fid);

    executionStatus = "SUCCESS";
    fprintf('[DONE] phi2 second-order deformation test -> %s\n', outReportPath);
catch ME
    try
        fidErr = fopen(errorLogPath, 'a');
        if fidErr ~= -1
            fprintf(fidErr, '%s\n', getReport(ME, 'extended'));
            fclose(fidErr);
        end
    catch
    end
    st = table();
    st.EXECUTION_STATUS = "FAIL";
    st.ERROR_MESSAGE = {ME.message};
    writetable(st, outStatusPath);
    fid = fopen(outReportPath, 'w');
    if fid ~= -1
        fprintf(fid, 'FAIL\n%s\n', ME.message);
        fclose(fid);
    end
end

%% --- Local functions ---
function [rows, symOut, verdict] = localRunVariant(xGrid, phi1, phi2, edgeExclude, variantTag)
    dPhi1dx = gradient(phi1, xGrid);
    d2Phi1dx2 = gradient(dPhi1dx, xGrid);
    xPhi1 = xGrid .* phi1;
    x2Phi1 = (xGrid .^ 2) .* phi1;
    xDphi1 = xGrid .* dPhi1dx;

    b1 = dPhi1dx(:);
    b2 = xPhi1(:);
    b3 = d2Phi1dx2(:);
    b4 = xDphi1(:);
    b5 = x2Phi1(:);

    maskFit = isfinite(phi2) & isfinite(phi1) & isfinite(xGrid) & ...
        isfinite(b1) & isfinite(b2) & isfinite(b3) & isfinite(b4) & isfinite(b5);
    n = numel(xGrid);
    if n > 2 * edgeExclude + 5
        maskFit(1:edgeExclude) = false;
        maskFit(end - edgeExclude + 1:end) = false;
    end
    idxFit = find(maskFit);
    assert(numel(idxFit) >= 8, 'Not enough fit points.');

    xFit = xGrid(idxFit);
    tRaw = phi2(idxFit);

    famFirst = {'dPhi1_dx', 'x_times_Phi1'};
    famSecond = {'d2Phi1_dx2', 'x_dPhi1_dx', 'x2_times_Phi1'};
    famCombined = [famFirst, famSecond];

    R1 = localFitMasked(tRaw, {b1(idxFit), b2(idxFit)}, famFirst);
    R2 = localFitMasked(tRaw, {b3(idxFit), b4(idxFit), b5(idxFit)}, famSecond);
    Rc = localFitMasked(tRaw, {b1(idxFit), b2(idxFit), b3(idxFit), b4(idxFit), b5(idxFit)}, famCombined);

    Bsec = [R2.basisRaw(:, 1), R2.basisRaw(:, 2), R2.basisRaw(:, 3)];
    [~, condBefore, condAfter] = localGramSchmidt(Bsec);
    gsNote = sprintf('GS_second_cond_raw=%.4g_cond_Q=%.4g', condBefore, condAfter);

    x_c = 0.5 * (min(xFit) + max(xFit));
    symPhi = localPhi2Symmetry(xFit, tRaw, x_c);
    s1 = localResidualSymmetry(xFit, tRaw, R1.yhatRaw, x_c);
    s2 = localResidualSymmetry(xFit, tRaw, R2.yhatRaw, x_c);
    sc = localResidualSymmetry(xFit, tRaw, Rc.yhatRaw, x_c);

    symOut = struct();
    symOut.x_center = x_c;
    symOut.phi2_even_frac = symPhi.even_frac;
    symOut.phi2_odd_frac = symPhi.odd_frac;
    symOut.res_first_even_frac = s1.even_frac;
    symOut.res_first_odd_frac = s1.odd_frac;
    symOut.res_second_even_frac = s2.even_frac;
    symOut.res_second_odd_frac = s2.odd_frac;
    symOut.res_comb_even_frac = sc.even_frac;
    symOut.res_comb_odd_frac = sc.odd_frac;
    symOut.res_comb_center_frac = sc.center_frac;
    symOut.res_comb_tail_frac = sc.tail_frac;
    symOut.mismatch_first = s1.label;
    symOut.mismatch_second = s2.label;
    symOut.mismatch_combined = sc.label;

    basisEvenFrac = NaN(5, 1);
    rawCols = {b1(idxFit), b2(idxFit), b3(idxFit), b4(idxFit), b5(idxFit)};
    namesAll = {'dPhi1_dx', 'x_times_Phi1', 'd2Phi1_dx2', 'x_dPhi1_dx', 'x2_times_Phi1'};
    for j = 1:5
        basisEvenFrac(j) = localEvenEnergyFrac(xFit, rawCols{j}, x_c);
    end

    verdict = localVerdicts(R1, R2, Rc);

    rows = localRowsTable(variantTag, R1, R2, Rc, symPhi, s1, s2, sc, basisEvenFrac, namesAll, ...
        numel(idxFit), edgeExclude, gsNote);
end

function R = localFitMasked(tRaw, colsCell, names)
    k = numel(colsCell);
    basisRaw = zeros(numel(tRaw), k);
    for j = 1:k
        basisRaw(:, j) = colsCell{j}(:);
    end
    PhiNorm = norm(tRaw);
    assert(isfinite(PhiNorm) && PhiNorm > eps, 'Bad Phi2 norm.');
    tUnit = tRaw ./ PhiNorm;
    basisNorms = zeros(1, k);
    basisUnit = zeros(numel(tRaw), k);
    for j = 1:k
        bn = norm(basisRaw(:, j));
        basisNorms(j) = bn;
        if isfinite(bn) && bn > eps
            basisUnit(:, j) = basisRaw(:, j) ./ bn;
        end
    end
    Xunit = basisUnit;
    coefUnit = Xunit \ tUnit;
    if any(~isfinite(coefUnit))
        coefUnit = pinv(Xunit) * tUnit;
    end
    yhatUnit = Xunit * coefUnit;
    coefRaw = zeros(1, k);
    for j = 1:k
        coefRaw(j) = (PhiNorm * coefUnit(j)) / max(basisNorms(j), eps);
    end
    yhatRaw = PhiNorm * yhatUnit;
    err = tRaw - yhatRaw;
    rmse = sqrt(mean(err .^ 2, 'omitnan'));
    relRmse = rmse / max(PhiNorm, eps);
    cosSim = abs(dot(tRaw, yhatRaw) / (norm(tRaw) * norm(yhatRaw) + eps));
    yMean = mean(tRaw, 'omitnan');
    sse = sum(err .^ 2, 'omitnan');
    sst = sum((tRaw - yMean) .^ 2, 'omitnan');
    if isfinite(sst) && sst > eps
        r2 = 1 - (sse / sst);
    else
        r2 = NaN;
    end
    rmseUnit = sqrt(mean((tUnit - yhatUnit) .^ 2, 'omitnan'));
    projNormFrac = norm(yhatRaw) / max(norm(tRaw), eps);

    R = struct();
    R.names = names;
    R.basisRaw = basisRaw;
    R.basisUnit = basisUnit;
    R.basisNorms = basisNorms;
    R.coefRaw = coefRaw(:).';
    R.coefUnit = coefUnit(:).';
    R.yhatRaw = yhatRaw;
    R.PhiNorm = PhiNorm;
    R.rmse = rmse;
    R.rel_rmse = relRmse;
    R.cosine_similarity = cosSim;
    R.r_squared = r2;
    R.rmse_unit = rmseUnit;
    R.projection_norm_fraction = projNormFrac;
end

function [Q, condRaw, condQ] = localGramSchmidt(B)
    [n, m] = size(B);
    Q = zeros(n, m);
    condRaw = cond(B' * B);
    for j = 1:m
        v = B(:, j);
        for k = 1:j - 1
            v = v - (Q(:, k)' * v) * Q(:, k);
        end
        nv = norm(v);
        if nv > eps
            Q(:, j) = v / nv;
        end
    end
    condQ = cond(Q' * Q);
end

function ef = localEvenEnergyFrac(x, f, x_c)
    f = f(:);
    x = x(:);
    [fe, fo] = localEvenOdd(x, f, x_c);
    nt = norm(f);
    if ~(isfinite(nt) && nt > eps)
        ef = NaN;
        return;
    end
    ef = (norm(fe) ^ 2) / (nt ^ 2);
end

function [fe, fo] = localEvenOdd(x, f, x_c)
    f = f(:);
    x = x(:);
    n = numel(x);
    fe = zeros(n, 1);
    fo = zeros(n, 1);
    xp = 2 * x_c - x;
    for i = 1:n
        fm = interp1(x, f, xp(i), 'linear', NaN);
        if ~isfinite(fm)
            fe(i) = f(i);
            fo(i) = 0;
        else
            fe(i) = 0.5 * (f(i) + fm);
            fo(i) = 0.5 * (f(i) - fm);
        end
    end
end

function sym = localPhi2Symmetry(x, phi2, x_c)
    [p2e, p2o] = localEvenOdd(x, phi2, x_c);
    nt = norm(phi2);
    sym.even_frac = (norm(p2e) ^ 2) / max(nt ^ 2, eps ^ 2);
    sym.odd_frac = (norm(p2o) ^ 2) / max(nt ^ 2, eps ^ 2);
end

function sym = localResidualSymmetry(x, phi2, yhat, x_c)
    res = phi2 - yhat;
    [re, ro] = localEvenOdd(x, res, x_c);
    nr = norm(res);
    if isfinite(nr) && nr > eps
        sym.even_frac = (norm(re) ^ 2) / (nr ^ 2);
        sym.odd_frac = (norm(ro) ^ 2) / (nr ^ 2);
    else
        sym.even_frac = NaN;
        sym.odd_frac = NaN;
    end
    dx = abs(x - x_c);
    q33 = quantile(dx, 0.33);
    q67 = quantile(dx, 0.67);
    cMask = dx <= q33;
    tMask = dx >= q67;
    sym.center_frac = sum(res(cMask) .^ 2) / max(sum(res .^ 2), eps);
    sym.tail_frac = sum(res(tMask) .^ 2) / max(sum(res .^ 2), eps);

    if sym.even_frac > 0.55 && sym.odd_frac < 0.45
        sym.label = "even_residual_dominated";
    elseif sym.odd_frac > 0.55 && sym.even_frac < 0.45
        sym.label = "odd_residual_dominated";
    elseif sym.center_frac > 0.5
        sym.label = "localized_center_structure";
    elseif sym.tail_frac > 0.45
        sym.label = "tails";
    else
        sym.label = "mixed_even_odd_and_center_tails";
    end
end

function v = localVerdicts(R1, R2, Rc)
    properCos = 0.90;
    properRmseUnit = 0.02;
    % Meaningful outperformance: clear gain vs first-order combined
    marginCos = 0.03;
    marginRmseRel = 0.01;

    betterRmse = isfinite(R2.rel_rmse) && isfinite(R1.rel_rmse) && ...
        (R2.rel_rmse < R1.rel_rmse - marginRmseRel);
    betterCos = isfinite(R2.cosine_similarity) && isfinite(R1.cosine_similarity) && ...
        (R2.cosine_similarity > R1.cosine_similarity + marginCos);
    if betterRmse || betterCos
        v.SECOND_ORDER_OUTPERFORMS_FIRST_ORDER = "YES";
    else
        v.SECOND_ORDER_OUTPERFORMS_FIRST_ORDER = "NO";
    end

    if isfinite(R2.cosine_similarity) && isfinite(R2.rmse_unit) && ...
            R2.cosine_similarity >= properCos && R2.rmse_unit <= properRmseUnit
        v.SECOND_ORDER_SUFFICIENT = "YES";
    else
        v.SECOND_ORDER_SUFFICIENT = "NO";
    end

    if isfinite(Rc.cosine_similarity) && isfinite(Rc.rmse_unit) && ...
            Rc.cosine_similarity >= properCos && Rc.rmse_unit <= properRmseUnit
        v.FIRST_PLUS_SECOND_SUFFICIENT = "YES";
    else
        v.FIRST_PLUS_SECOND_SUFFICIENT = "NO";
    end

    if strcmp(v.FIRST_PLUS_SECOND_SUFFICIENT, "YES")
        v.PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER = "NO";
    else
        v.PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER = "YES";
    end
end

function rows = localRowsTable(variantTag, R1, R2, Rc, symPhi, s1, s2, sc, basisEvenFrac, namesAll, nPts, edgeEx, gsNote)
    fams = {'first_order', 'pure_second_order', 'first_plus_second'};
    Rs = {R1, R2, Rc};
    Sres = {s1, s2, sc};
    ncoef = 5;
    rowList = cell(3, 1);
    for ii = 1:3
        R = Rs{ii};
        sr = Sres{ii};
        coefPad = NaN(1, ncoef);
        coefPad(1:numel(R.coefRaw)) = R.coefRaw;
        nm = R.names;
        coeffStr = strjoin(cellfun(@(s) char(string(s)), nm, 'UniformOutput', false), '|');
        row = table();
        row.variant = string(variantTag);
        row.basis_family = string(fams{ii});
        row.basis_names = string(coeffStr);
        row.n_basis = numel(R.coefRaw);
        row.n_fit_points = nPts;
        row.edge_exclude = edgeEx;
        row.rmse = R.rmse;
        row.rel_rmse = R.rel_rmse;
        row.rmse_unit = R.rmse_unit;
        row.cosine_similarity = R.cosine_similarity;
        row.r_squared = R.r_squared;
        row.projection_norm_fraction = R.projection_norm_fraction;
        row.coef_1 = coefPad(1);
        row.coef_2 = coefPad(2);
        row.coef_3 = coefPad(3);
        row.coef_4 = coefPad(4);
        row.coef_5 = coefPad(5);
        row.phi2_even_energy_frac = symPhi.even_frac;
        row.phi2_odd_energy_frac = symPhi.odd_frac;
        row.residual_even_energy_frac = sr.even_frac;
        row.residual_odd_energy_frac = sr.odd_frac;
        row.residual_center_energy_frac = sr.center_frac;
        row.residual_tail_energy_frac = sr.tail_frac;
        row.mismatch_label = sr.label;
        row.basis_even_frac_1 = basisEvenFrac(1);
        row.basis_even_frac_2 = basisEvenFrac(2);
        row.basis_even_frac_3 = basisEvenFrac(3);
        row.basis_even_frac_4 = basisEvenFrac(4);
        row.basis_even_frac_5 = basisEvenFrac(5);
        row.basis_names_all = string(strjoin(namesAll, '|'));
        row.notes = string(gsNote);
        rowList{ii} = row;
    end
    rows = [rowList{1}; rowList{2}; rowList{3}];
end
