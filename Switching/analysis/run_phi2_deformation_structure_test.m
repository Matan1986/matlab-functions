% run_phi2_deformation_structure_test
% AGENT 2 - PHI2 DEFORMATION STRUCTURE TEST
% Pure script: tests whether Phi2 can be represented as a deformation
% (tangent-like basis) of Phi1 using dPhi1/dx and x*Phi1.

fprintf('[RUN] phi2 deformation structure test\n');

clearvars;

repoRoot = 'C:/Dev/matlab-functions';
analysisDir = fullfile(repoRoot, 'Switching', 'analysis');

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
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
outCsvPath = fullfile(tablesDir, 'phi2_deformation_fit.csv');
outReportPath = fullfile(reportsDir, 'phi2_deformation_structure.md');
outMatPath = fullfile(tablesDir, 'phi2_deformation_fit.mat');
errorLogPath = fullfile(repoRoot, 'matlab_error.log');

model = {'dPhi1_dx'; 'x_times_Phi1'; 'a_dPhi1_dx_plus_b_xPhi1'; 'raw_Phi2_reference'};
cosine_similarity = [NaN; NaN; NaN; 1.0];
rmse_reconstruction = [NaN; NaN; NaN; 0.0];
coef_a = [NaN; NaN; NaN; NaN];
coef_b = [NaN; NaN; NaN; NaN];
fitTbl = table(model, cosine_similarity, rmse_reconstruction, coef_a, coef_b);

try
    cfg = struct();
    cfg.alignmentRunId = 'run_2026_03_10_112659_alignment_audit';
    cfg.fullScalingRunId = 'run_2026_03_12_234016_switching_full_scaling_collapse';
    cfg.ptRunId = 'run_2026_03_24_212033_switching_barrier_distribution_from_map';
    cfg.canonicalMaxTemperatureK = 30;
    cfg.nXGrid = 220;
    cfg.fallbackSmoothWindow = 5;
    cfg.yesCosineThreshold = 0.90;
    cfg.yesRmseThreshold = 0.45;
    cfg.yesLooCosMeanThreshold = 0.85;
    cfg.yesLooCoefCvThreshold = 0.35;
    cfg.partialCosineThreshold = 0.70;
    cfg.partialRmseThreshold = 0.75;
    cfg.basisSufficientCosineThreshold = 0.80;
    cfg.basisSufficientRmseThreshold = 0.62;

    decCfg = struct();
    decCfg.runLabel = 'phi2_deformation_structure_test';
    decCfg.alignmentRunId = cfg.alignmentRunId;
    decCfg.fullScalingRunId = cfg.fullScalingRunId;
    decCfg.ptRunId = cfg.ptRunId;
    decCfg.canonicalMaxTemperatureK = cfg.canonicalMaxTemperatureK;
    decCfg.nXGrid = cfg.nXGrid;
    decCfg.fallbackSmoothWindow = cfg.fallbackSmoothWindow;
    decCfg.skipFigures = true;
    outDec = switching_residual_decomposition_analysis(decCfg);

    xGrid = outDec.xGrid(:);
    phi1 = outDec.phi(:);
    phi2 = outDec.phi2;
    if isempty(phi2)
        error('run_phi2_deformation_structure_test:Phi2Missing', ...
            'Phi2 is missing (rank-2 decomposition required).');
    end
    phi2 = phi2(:);

    dPhi1dx = gradient(phi1, xGrid);
    xPhi1 = xGrid .* phi1;

    [phi2n, ~] = phi2_deformation_helpers('unit_l2', phi2);
    [dPhi1n, ~] = phi2_deformation_helpers('unit_l2', dPhi1dx);
    [xPhi1n, ~] = phi2_deformation_helpers('unit_l2', xPhi1);
    [cosD, rmseD, cD] = phi2_deformation_helpers('fit_single_basis', phi2n, dPhi1n);
    [cosX, rmseX, cX] = phi2_deformation_helpers('fit_single_basis', phi2n, xPhi1n);
    [cosCombo, rmseCombo, aCombo, bCombo, ~] = phi2_deformation_helpers('fit_two_basis', phi2n, dPhi1n, xPhi1n);
    [aLoo, bLoo, looCos, looRmse] = phi2_deformation_helpers('loo_two_basis', phi2n, dPhi1n, xPhi1n);
    aStats = phi2_deformation_helpers('stats', aLoo);
    bStats = phi2_deformation_helpers('stats', bLoo);
    looCosStats = phi2_deformation_helpers('stats', looCos);
    looRmseStats = phi2_deformation_helpers('stats', looRmse);

    cosRaw = 1.0;
    rmseRaw = 0.0;
    model = {'dPhi1_dx'; 'x_times_Phi1'; 'a_dPhi1_dx_plus_b_xPhi1'; 'raw_Phi2_reference'};
    cosine_similarity = [cosD; cosX; cosCombo; cosRaw];
    rmse_reconstruction = [rmseD; rmseX; rmseCombo; rmseRaw];
    coef_a = [cD; 0; aCombo; NaN];
    coef_b = [0; cX; bCombo; NaN];
    fitTbl = table(model, cosine_similarity, rmse_reconstruction, coef_a, coef_b);
    writetable(fitTbl, outCsvPath);
    save(outMatPath, 'fitTbl', 'cosD', 'cosX', 'cosCombo', 'rmseD', 'rmseX', 'rmseCombo', ...
        'aCombo', 'bCombo', 'aLoo', 'bLoo', 'looCos', 'looRmse');

    [bestCos, iBest] = max(abs([cosD, cosX, cosCombo]), [], 'omitnan');
    bestRmse = [rmseD, rmseX, rmseCombo];
    bestRmse = bestRmse(iBest);
    bestName = model{iBest};

    lines = strings(0,1);
    lines(end+1) = '# Phi2 deformation structure test';
    lines(end+1) = '- Best deformation model: **' + string(bestName) + '**';
    lines(end+1) = '- Best deformation |cosine(Phi2, recon)|: **' + sprintf('%.4f', bestCos) + '**';
    lines(end+1) = '- Best deformation RMSE: **' + sprintf('%.4f', bestRmse) + '**';
    lines(end+1) = 'SUCCESS';

    fid = fopen(outReportPath, 'w');
    fprintf(fid, 'SUCCESS\n');
    fprintf(fid, '%s', char(strjoin(lines, newline)));
    fclose(fid);
catch ME
    fidErr = fopen(errorLogPath, 'a');
    if fidErr ~= -1
        fprintf(fidErr, '%s\n', getReport(ME, 'extended'));
        fclose(fidErr);
    end
    try
        writetable(fitTbl, outCsvPath);
    catch
    end
    try
        save(outMatPath, 'fitTbl');
    catch
    end
    fid = fopen(outReportPath, 'w');
    if fid ~= -1
        fprintf(fid, 'FAIL\n%s\n', ME.message);
        fclose(fid);
    end
end

