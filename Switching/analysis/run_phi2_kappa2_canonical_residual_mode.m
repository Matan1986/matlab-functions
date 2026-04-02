fprintf('[RUN] run_phi2_kappa2_canonical_residual_mode\n');
clearvars;

repoRoot = 'C:/Dev/matlab-functions';
analysisDir = fullfile(repoRoot, 'Switching', 'analysis');
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
statusDir = fullfile(repoRoot, 'status');
errorLogPath = fullfile(repoRoot, 'matlab_error.log');

if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end
if exist(statusDir, 'dir') ~= 7, mkdir(statusDir); end

summaryPath = fullfile(tablesDir, 'phi2_kappa2_summary.csv');
modesPath = fullfile(tablesDir, 'phi2_modes.csv');
verdictsPath = fullfile(tablesDir, 'phi2_verdicts.csv');
residualMapPath = fullfile(tablesDir, 'phi2_residual_map.csv');
reportPath = fullfile(reportsDir, 'phi2_analysis_report.md');
statusPath = fullfile(statusDir, 'phi2_status.txt');

summaryTbl = table(NaN, NaN, NaN, NaN, NaN, NaN, ...
    'VariableNames', {'T', 'kappa1', 'kappa2', 'rmse_rank1', 'rmse_rank2', 'improvement_ratio'});
modesTbl = table(NaN, NaN, NaN, 'VariableNames', {'x', 'phi1', 'phi2'});
verdictsTbl = table("NO", "NO", "NO", "NO", "NO", "NO", "NO", "NO", ...
    'VariableNames', {'RANK1_SUFFICIENT', 'MODE2_SIGNIFICANT', 'RANK2_IMPROVES_RECONSTRUCTION', ...
    'PHI2_SYMMETRIC', 'PHI2_ODD_DOMINANT', 'PHI2_IS_DEFORMATION', ...
    'KAPPA2_LINKED_TO_KAPPA1', 'KAPPA2_REGIME_DEPENDENT'});

phi2ExtractionSuccess = "NO";
kappa2Defined = "NO";
secondModePhysical = "NO";

try
    addpath(genpath(fullfile(repoRoot, 'Aging')));
    addpath(fullfile(repoRoot, 'tools'));
    addpath(fullfile(repoRoot, 'tools', 'figures'));
    addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');
    addpath(analysisDir, '-begin');

    decCfg = struct();
    decCfg.runLabel = 'phi2_kappa2_canonical_residual_mode';
    decCfg.alignmentRunId = 'run_2026_03_10_112659_alignment_audit';
    decCfg.fullScalingRunId = 'run_2026_03_12_234016_switching_full_scaling_collapse';
    decCfg.ptRunId = 'run_2026_03_24_212033_switching_barrier_distribution_from_map';
    decCfg.canonicalMaxTemperatureK = 30;
    decCfg.nXGrid = 220;
    decCfg.fallbackSmoothWindow = 5;
    decCfg.maxModes = 3;
    decCfg.skipFigures = true;

    outDec = switching_residual_decomposition_analysis(decCfg);

    T = outDec.temperaturesK(:);
    Ipeak = outDec.Ipeak_mA(:);
    Speak = outDec.Speak(:);
    xGrid = outDec.xGrid(:);

    Mfull = outDec.Rall.';
    if size(Mfull, 2) ~= numel(T)
        error('run_phi2_kappa2_canonical_residual_mode:ShapeMismatch', ...
            'Residual matrix size does not match temperature vector.');
    end

    alignedMask = all(isfinite(Mfull), 2) & isfinite(xGrid);
    if nnz(alignedMask) < 20
        error('run_phi2_kappa2_canonical_residual_mode:NotAligned', ...
            'Insufficient common aligned x-grid points across temperatures.');
    end

    M = Mfull(alignedMask, :);
    x = xGrid(alignedMask);

    [U, S, V] = svd(M, 'econ');
    if min(size(S)) < 2
        error('run_phi2_kappa2_canonical_residual_mode:RankTooLow', ...
            'Second mode not available from residual SVD.');
    end

    phi1 = U(:, 1);
    phi2 = U(:, 2);
    kappa1 = S(1, 1) * V(:, 1);
    kappa2 = S(2, 2) * V(:, 2);

    if corr(kappa1, Speak, 'rows', 'pairwise') < 0
        phi1 = -phi1;
        kappa1 = -kappa1;
    end

    dphi1dx = gradient(phi1, x);
    xphi1 = x .* phi1;
    cD = corr(phi2, dphi1dx, 'rows', 'pairwise');
    cX = corr(phi2, xphi1, 'rows', 'pairwise');
    if abs(cD) > abs(cX)
        if cD < 0
            phi2 = -phi2;
            kappa2 = -kappa2;
        end
    else
        if cX < 0
            phi2 = -phi2;
            kappa2 = -kappa2;
        end
    end

    sing = diag(S);
    ev = (sing .^ 2) / sum(sing .^ 2);
    mode1Var = ev(1);
    mode2Var = ev(2);

    M1 = U(:, 1) * S(1, 1) * V(:, 1)';
    M2 = U(:, 1:2) * S(1:2, 1:2) * V(:, 1:2)';

    rmseRank1 = NaN(numel(T), 1);
    rmseRank2 = NaN(numel(T), 1);
    for i = 1:numel(T)
        rmseRank1(i) = sqrt(mean((M(:, i) - M1(:, i)) .^ 2, 'omitnan'));
        rmseRank2(i) = sqrt(mean((M(:, i) - M2(:, i)) .^ 2, 'omitnan'));
    end
    improvementRatio = rmseRank2 ./ max(rmseRank1, eps);

    rmse1Global = sqrt(mean((M(:) - M1(:)) .^ 2, 'omitnan'));
    rmse2Global = sqrt(mean((M(:) - M2(:)) .^ 2, 'omitnan'));
    globalRatio = rmse2Global / max(rmse1Global, eps);

    phiNeg = interp1(x, phi2, -x, 'linear', NaN);
    goodSym = isfinite(phi2) & isfinite(phiNeg);
    evenPart = NaN(size(phi2));
    oddPart = NaN(size(phi2));
    evenPart(goodSym) = 0.5 * (phi2(goodSym) + phiNeg(goodSym));
    oddPart(goodSym) = 0.5 * (phi2(goodSym) - phiNeg(goodSym));
    evenEnergy = sum(evenPart(goodSym) .^ 2, 'omitnan');
    oddEnergy = sum(oddPart(goodSym) .^ 2, 'omitnan');
    totalEnergy = sum(phi2(goodSym) .^ 2, 'omitnan');
    evenFrac = evenEnergy / max(totalEnergy, eps);
    oddFrac = oddEnergy / max(totalEnergy, eps);

    centerMask = abs(x) <= 1.0;
    centerEnergyFrac = sum((phi2(centerMask) .^ 2), 'omitnan') / max(sum(phi2 .^ 2, 'omitnan'), eps);
    rmsX = sqrt(sum((x .^ 2) .* (phi2 .^ 2), 'omitnan') / max(sum(phi2 .^ 2, 'omitnan'), eps));

    corrXphi1 = corr(phi2, xphi1, 'rows', 'pairwise');
    corrDphi1 = corr(phi2, dphi1dx, 'rows', 'pairwise');
    bestDefCorr = max(abs([corrXphi1, corrDphi1]));

    corrK2K1 = corr(kappa2, kappa1, 'rows', 'pairwise');
    corrK2Ipeak = corr(kappa2, Ipeak, 'rows', 'pairwise');

    maskRegime = T >= 22 & T <= 24;
    maskOut = ~maskRegime;
    regMean = mean(abs(kappa2(maskRegime)), 'omitnan');
    outMean = mean(abs(kappa2(maskOut)), 'omitnan');
    regimeRatio = regMean / max(outMean, eps);

    rank1Sufficient = mode1Var >= 0.90;
    mode2Significant = mode2Var >= 0.05;
    rank2Improves = globalRatio <= 0.90;
    phi2Symmetric = evenFrac >= 0.55;
    phi2OddDominant = oddFrac > evenFrac;
    phi2IsDeformation = bestDefCorr >= 0.70;
    kappa2LinkedToKappa1 = abs(corrK2K1) >= 0.60;
    kappa2RegimeDependent = isfinite(regimeRatio) && (regimeRatio >= 1.20 || regimeRatio <= 0.80);

    summaryTbl = table(T, kappa1, kappa2, rmseRank1, rmseRank2, improvementRatio, ...
        'VariableNames', summaryTbl.Properties.VariableNames);
    modesTbl = table(x, phi1, phi2, 'VariableNames', modesTbl.Properties.VariableNames);

    verdictsTbl = table( ...
        string(yesno(rank1Sufficient)), ...
        string(yesno(mode2Significant)), ...
        string(yesno(rank2Improves)), ...
        string(yesno(phi2Symmetric)), ...
        string(yesno(phi2OddDominant)), ...
        string(yesno(phi2IsDeformation)), ...
        string(yesno(kappa2LinkedToKappa1)), ...
        string(yesno(kappa2RegimeDependent)), ...
        'VariableNames', verdictsTbl.Properties.VariableNames);

    resMapTbl = array2table(M, 'VariableNames', matlab.lang.makeValidName(compose('T_%.3fK', T)));
    resMapTbl = addvars(resMapTbl, x, 'Before', 1, 'NewVariableNames', 'x');

    writetable(summaryTbl, summaryPath);
    writetable(modesTbl, modesPath);
    writetable(verdictsTbl, verdictsPath);
    writetable(resMapTbl, residualMapPath);

    lines = strings(0,1);
    lines(end+1) = '# Phi2 and Kappa2 Canonical Residual Mode Analysis';
    lines(end+1) = '';
    lines(end+1) = '## Scope';
    lines(end+1) = '- Canonical switching outputs only: S(I,T), I_peak(T), width(T), S_peak(T).';
    lines(end+1) = '- Residual built from canonical CDF backbone using switching_residual_decomposition_analysis.';
    lines(end+1) = sprintf('- Aligned x-grid points used globally: %d', numel(x));
    lines(end+1) = sprintf('- Temperatures used: %d (T range %.3f to %.3f K)', numel(T), min(T), max(T));
    lines(end+1) = '';
    lines(end+1) = '## Mode Plots (Description)';
    lines(end+1) = '- Phi1(x) is the leading residual mode from global SVD of M(x,T).';
    lines(end+1) = '- Phi2(x) is the second residual mode from global SVD of M(x,T).';
    lines(end+1) = sprintf('- Phi2 symmetry metrics: even fraction = %.4f, odd fraction = %.4f.', evenFrac, oddFrac);
    lines(end+1) = sprintf('- Phi2 localization near x=0: center energy |x|<=1 is %.4f; weighted RMS x is %.4f.', centerEnergyFrac, rmsX);
    lines(end+1) = sprintf('- Corr(Phi2, x*Phi1)=%.4f; Corr(Phi2, dPhi1/dx)=%.4f.', corrXphi1, corrDphi1);
    lines(end+1) = '';
    lines(end+1) = '## Reconstruction Comparison';
    lines(end+1) = sprintf('- Mode-1 explained variance: %.6f', mode1Var);
    lines(end+1) = sprintf('- Mode-2 explained variance: %.6f', mode2Var);
    lines(end+1) = sprintf('- Global RMSE rank-1: %.6g', rmse1Global);
    lines(end+1) = sprintf('- Global RMSE rank-2: %.6g', rmse2Global);
    lines(end+1) = sprintf('- Global RMSE ratio rank2/rank1: %.6f', globalRatio);
    lines(end+1) = '- Per-temperature RMSE metrics are in tables/phi2_kappa2_summary.csv.';
    lines(end+1) = '';
    lines(end+1) = '## Interpretation of Phi2';
    lines(end+1) = sprintf('- PHI2_IS_DEFORMATION: %s (max deformation correlation %.4f).', yesno(phi2IsDeformation), bestDefCorr);
    lines(end+1) = sprintf('- Kappa correlations: Corr(kappa2,kappa1)=%.4f; Corr(kappa2,I_peak)=%.4f.', corrK2K1, corrK2Ipeak);
    lines(end+1) = sprintf('- Regime behavior 22-24 K (|kappa2| ratio vs outside): %.4f.', regimeRatio);
    lines(end+1) = '';
    lines(end+1) = '## Link to Aging Hypothesis (Qualitative)';
    lines(end+1) = '- A stable and reconstructive second residual mode is consistent with a structured correction layer beyond a single collective mode.';
    lines(end+1) = '- This is qualitatively compatible with the idea that memory/aging behavior can emerge from regime-dependent corrections to the leading switching manifold.';
    lines(end+1) = '';
    lines(end+1) = '## Verdicts';
    lines(end+1) = sprintf('- RANK1_SUFFICIENT=%s', yesno(rank1Sufficient));
    lines(end+1) = sprintf('- MODE2_SIGNIFICANT=%s', yesno(mode2Significant));
    lines(end+1) = sprintf('- RANK2_IMPROVES_RECONSTRUCTION=%s', yesno(rank2Improves));
    lines(end+1) = sprintf('- PHI2_SYMMETRIC=%s', yesno(phi2Symmetric));
    lines(end+1) = sprintf('- PHI2_ODD_DOMINANT=%s', yesno(phi2OddDominant));
    lines(end+1) = sprintf('- PHI2_IS_DEFORMATION=%s', yesno(phi2IsDeformation));
    lines(end+1) = sprintf('- KAPPA2_LINKED_TO_KAPPA1=%s', yesno(kappa2LinkedToKappa1));
    lines(end+1) = sprintf('- KAPPA2_REGIME_DEPENDENT=%s', yesno(kappa2RegimeDependent));

    fid = fopen(reportPath, 'w');
    if fid == -1
        error('run_phi2_kappa2_canonical_residual_mode:ReportWriteFail', 'Cannot write report file.');
    end
    fprintf(fid, '%s\n', strjoin(cellstr(lines), newline));
    fclose(fid);

    phi2ExtractionSuccess = "YES";
    kappa2Defined = string(yesno(all(isfinite(kappa2))));
    secondModePhysical = string(yesno(mode2Significant && rank2Improves && phi2IsDeformation));

catch ME
    fidErr = fopen(errorLogPath, 'a');
    if fidErr ~= -1
        fprintf(fidErr, '%s\n', getReport(ME, 'extended'));
        fclose(fidErr);
    end
end

try
    writetable(summaryTbl, summaryPath);
    writetable(modesTbl, modesPath);
    writetable(verdictsTbl, verdictsPath);
catch
end

fidStatus = fopen(statusPath, 'w');
if fidStatus ~= -1
    fprintf(fidStatus, 'PHI2_EXTRACTION_SUCCESS=%s\n', phi2ExtractionSuccess);
    fprintf(fidStatus, 'KAPPA2_DEFINED=%s\n', kappa2Defined);
    fprintf(fidStatus, 'SECOND_MODE_PHYSICAL=%s\n', secondModePhysical);
    fclose(fidStatus);
end

if ~isfile(reportPath)
    fid = fopen(reportPath, 'w');
    if fid ~= -1
        fprintf(fid, '# Phi2 and Kappa2 Canonical Residual Mode Analysis\n\nFAIL\n');
        fclose(fid);
    end
end

function s = yesno(tf)
if tf
    s = 'YES';
else
    s = 'NO';
end
end
