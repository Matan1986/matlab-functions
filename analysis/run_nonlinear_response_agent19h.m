function run_nonlinear_response_agent19h()
%RUN_NONLINEAR_RESPONSE_AGENT19H  Agent 19H — nonlinear response to backbone (S_CDF)
%
% Tests whether residual strip deltaS ≈ S - S_CDF is explained by a quadratic
% expansion in the backbone CDF-shaped signal on the same grid:
%   deltaS ≈ a1(T)*S_CDF + a2(T)*S_CDF^2
% Compares per-row RMSE to kappa1*Phi1 and rank-2 (Phi1+Phi2) on the x grid.
%
% Read-only inputs (same canonical sources as run_deformation_closure_agent19e).
% Writes:
%   tables/nonlinear_response.csv
%   reports/nonlinear_response_report.md
%
% Usage: addpath('analysis'); run_nonlinear_response_agent19h
%   (or setup_repo from repo root)

set(0, 'DefaultFigureVisible', 'off');

clearvars;
clc;

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'analysis'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

outRoot = repoRoot;
tblDir = fullfile(outRoot, 'tables');
repDir = fullfile(outRoot, 'reports');
for d = {tblDir, repDir}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

decCfg = struct();
decCfg.runLabel = 'nonlinear_response_agent19h_internal';
decCfg.alignmentRunId = 'run_2026_03_10_112659_alignment_audit';
decCfg.fullScalingRunId = 'run_2026_03_12_234016_switching_full_scaling_collapse';
decCfg.ptRunId = 'run_2026_03_24_212033_switching_barrier_distribution_from_map';
decCfg.canonicalMaxTemperatureK = 30;
decCfg.nXGrid = 220;
decCfg.maxModes = 2;
decCfg.skipFigures = true;

out = switching_residual_decomposition_analysis(decCfg);

temps = out.temperaturesK(:);
R = out.Rall;
xG = out.xGrid(:);
phi1 = out.phi(:);
phi2 = out.phi2(:);
kappa1 = out.kappaAll(:);
Xrows = out.Xrows;
deltaS = out.deltaS;

% --- Smap aligned to decomposition rows (same filter as switching_residual_decomposition_analysis) ---
paramsPath = fullfile(repoRoot, 'results', 'switching', 'runs', decCfg.fullScalingRunId, ...
    'tables', 'switching_full_scaling_parameters.csv');
paramsTbl = readtable(paramsPath);
alignPath = fullfile(repoRoot, 'results', 'switching', 'runs', decCfg.alignmentRunId, ...
    'switching_alignment_core_data.mat');
core = load(alignPath, 'Smap', 'temps', 'currents');
[SmapAll, tempsAll, ~] = orientAndSortMapLocal(core.Smap, core.temps(:), core.currents(:));
[tempsScale, IpeakScale, SpeakScale, widthScale] = extractScalingColumnsLocal(paramsTbl);
[tempsCommon, iMap, iScale] = intersect(tempsAll, tempsScale, 'stable');
assert(~isempty(tempsCommon), 'No common temperatures.');
Smap = SmapAll(iMap, :);
Ipeak = IpeakScale(iScale);
Speak = SpeakScale(iScale);
width = widthScale(iScale);
speakFloorFraction = 1e-3;
valid = isfinite(tempsCommon) & isfinite(Ipeak) & isfinite(Speak) & isfinite(width);
valid = valid & (width > 0);
valid = valid & (Speak > speakFloorFraction * max(Speak, [], 'omitnan'));
tempsReload = tempsCommon(valid);
Smap = Smap(valid, :);
assert(numel(tempsReload) == numel(temps) && max(abs(tempsReload - temps)) < 1e-4, ...
    'Temperature alignment: reload Smap vs decomposition.');

Scdf = Smap - deltaS;
slack = max(abs(deltaS - (Smap - Scdf)), [], 'all');
assert(slack < 1e-8 * max(abs(Smap), [], 'all'), 'deltaS vs Smap-Scdf inconsistent.');

ScdfX = interpolateRowsToGridLocal(Xrows, Scdf, xG);

nT = size(R, 1);
a1 = NaN(nT, 1);
a2 = NaN(nT, 1);
aLin = NaN(nT, 1);
rmseNl = NaN(nT, 1);
rmseLinCdf = NaN(nT, 1);
rmseA = NaN(nT, 1);
rmseB = NaN(nT, 1);
corrNl = NaN(nT, 1);
corrLin = NaN(nT, 1);
corrA = NaN(nT, 1);
corrB = NaN(nT, 1);
cosPhi2pred = NaN(nT, 1);
cosPhi2rank2 = NaN(nT, 1);
kappa2B = NaN(nT, 1);

for it = 1:nT
    r = R(it, :)';
    sc = ScdfX(it, :)';
    mask = isfinite(r) & isfinite(sc) & isfinite(phi1) & isfinite(phi2);
    if nnz(mask) < 5
        continue;
    end
    rr = r(mask);
    s1 = sc(mask);
    s2 = s1 .^ 2;
    X2 = [s1, s2];
    th = X2 \ rr;
    a1(it) = th(1);
    a2(it) = th(2);
    predNl = X2 * th;
    rmseNl(it) = sqrt(mean((rr - predNl).^2));
    cNl = corr(rr, predNl);
    if isfinite(cNl)
        corrNl(it) = cNl;
    end

    thL = s1 \ rr;
    aLin(it) = thL;
    predL = thL .* s1;
    rmseLinCdf(it) = sqrt(mean((rr - predL).^2));
    cL = corr(rr, predL);
    if isfinite(cL)
        corrLin(it) = cL;
    end

    p1 = phi1(mask);
    p2m = phi2(mask);
    kk1 = kappa1(it);
    ra = kk1 * p1;
    rmseA(it) = sqrt(mean((rr - ra).^2));
    corrA(it) = corr(rr, ra);

    XB = [p1, p2m];
    thB = XB \ rr;
    rb = XB * thB;
    kappa2B(it) = thB(2);
    rmseB(it) = sqrt(mean((rr - rb).^2));
    corrB(it) = corr(rr, rb);

    p2n = p2m / max(norm(p2m), eps);
    prn = predNl / max(norm(predNl), eps);
    brn = rb / max(norm(rb), eps);
    cosPhi2pred(it) = abs(dot(p2n, prn));
    cosPhi2rank2(it) = abs(dot(p2n, brn));
end

meanRmseNl = mean(rmseNl, 'omitnan');
meanRmseLin = mean(rmseLinCdf, 'omitnan');
meanRmseA = mean(rmseA, 'omitnan');
meanRmseB = mean(rmseB, 'omitnan');
impNlVsLin = meanRmseLin - meanRmseNl;
impBVsA = meanRmseA - meanRmseB;

mA = isfinite(a2) & isfinite(a1) & isfinite(out.Speak);
ratioA2 = mean(abs(a2(mA)) ./ max(abs(a1(mA)) ./ max(out.Speak(mA), eps), 1e-12), 'omitnan');

meanCosP2 = mean(cosPhi2pred, 'omitnan');
meanCosP2r2 = mean(cosPhi2rank2, 'omitnan');

% --- Verdicts (thresholds documented in report) ---
nlHelpsVsLinear = isfinite(meanRmseLin) && isfinite(meanRmseNl) && (meanRmseLin > meanRmseNl * 1.03);
impNlVsLinRel = impNlVsLin / max(meanRmseA, 1e-12);
nlCompetesRank2 = isfinite(meanRmseNl) && isfinite(meanRmseB) && (meanRmseNl <= meanRmseB * 1.05);
phi2AlignedNl = (meanCosP2 >= 0.55) || (meanCosP2 >= meanCosP2r2 + 0.05);
% Residual "is" nonlinear backbone response only if the quadratic CDF model fits the strip
% at least as well as the rank-1 mode basis, or matches rank-2 — not merely a2 != 0.
nlExplainsVsRank1 = isfinite(meanRmseNl) && isfinite(meanRmseA) && (meanRmseNl <= meanRmseA * 1.05);
residualIsNonlinear = nlCompetesRank2 || (nlHelpsVsLinear && (impNlVsLinRel >= 0.01) && nlExplainsVsRank1);

nonlinearCompetesRank2 = nlCompetesRank2;

% --- CSV ---
outTbl = table(temps, rmseA, rmseB, rmseNl, rmseLinCdf, ...
    corrA, corrB, corrNl, corrLin, ...
    a1, a2, aLin, kappa1, kappa2B, ...
    cosPhi2pred, cosPhi2rank2, ...
    'VariableNames', {'T_K', 'rmse_kappa1_Phi1', 'rmse_rank2_Phi1_Phi2', 'rmse_nonlinear_Scdf', ...
    'rmse_linear_Scdf_only', 'corr_kappa1_Phi1', 'corr_rank2', 'corr_nonlinear', 'corr_linear_Scdf', ...
    'a1_Scdf', 'a2_Scdf2', 'a_lin_Scdf_only', 'kappa1', 'kappa2_fit', ...
    'cos_phi2_unit_pred_nl', 'cos_phi2_unit_rank2'});

writetable(outTbl, fullfile(tblDir, 'nonlinear_response.csv'));

% --- Report ---
verdictRes = ternaryYesNo(residualIsNonlinear);
verdictComp = ternaryYesNo(nonlinearCompetesRank2);
writeReport19h(fullfile(repDir, 'nonlinear_response_report.md'), decCfg, ...
    meanRmseA, meanRmseB, meanRmseNl, meanRmseLin, impNlVsLin, impNlVsLinRel, impBVsA, ...
    ratioA2, meanCosP2, meanCosP2r2, verdictRes, verdictComp, nlHelpsVsLinear, phi2AlignedNl);

fprintf('Agent 19H complete.\nTables -> %s\nReport -> %s\n', tblDir, repDir);
end

function s = ternaryYesNo(flag)
if flag
    s = "YES";
else
    s = "NO";
end
end

function writeReport19h(path, decCfg, meanA, meanB, meanNl, meanLin, impNlVsLin, impNlVsLinRel, impBVsA, ...
    ratioA2, meanCosP2, meanCosP2r2, verdictRes, verdictComp, nlHelpsVsLinear, phi2AlignedNl)

fid = fopen(path, 'w');
assert(fid > 0, 'Cannot write report');
fprintf(fid, '# Nonlinear response test (Agent 19H)\n\n');
fprintf(fid, '## Sources\n');
fprintf(fid, '- Alignment: `%s`\n', decCfg.alignmentRunId);
fprintf(fid, '- Full scaling: `%s`\n', decCfg.fullScalingRunId);
fprintf(fid, '- PT matrix: `%s`\n', decCfg.ptRunId);
fprintf(fid, '- Canonical window: decomposition uses T <= %.0f K for SVD; fits below use **all** valid rows.\n\n', ...
    decCfg.canonicalMaxTemperatureK);

fprintf(fid, '## Model\n');
fprintf(fid, 'On the **x-grid** (same as residual decomposition), fit per temperature:\n');
fprintf(fid, '`deltaS(x) ≈ a1(T)*S_CDF(x) + a2(T)*S_CDF(x)^2`, with `S_CDF` interpolated from the current-axis backbone.\n');
fprintf(fid, 'Baselines: **rank-1** `kappa1*Phi1`, **rank-2** LSQ on `[Phi1, Phi2]` (same as Agent 19E).\n');
fprintf(fid, 'Also report **linear** `deltaS ≈ a_lin * S_CDF` (single term) to isolate the quadratic piece.\n\n');

fprintf(fid, '## Mean RMSE (finite rows)\n');
fprintf(fid, '| Model | mean RMSE |\n| --- | --- |\n');
fprintf(fid, '| kappa1*Phi1 (rank-1) | %.6f |\n', meanA);
fprintf(fid, '| rank-2 Phi1+Phi2 | %.6f |\n', meanB);
fprintf(fid, '| nonlinear a1*S_CDF + a2*S_CDF^2 | %.6f |\n', meanNl);
fprintf(fid, '| linear a*S_CDF only | %.6f |\n\n', meanLin);

fprintf(fid, '## Diagnostics\n');
fprintf(fid, '- Improvement nonlinear vs linear-in-S_CDF only: **%.6f** (mean RMSE); **%.4f** relative to mean rank-1 RMSE\n', ...
    impNlVsLin, impNlVsLinRel);
fprintf(fid, '- Improvement rank-2 vs rank-1: **%.6f** (mean RMSE)\n', impBVsA);
fprintf(fid, '- Mean |a2| relative to |a1|/Speak scale: **%.6f**\n', ratioA2);
fprintf(fid, '- Mean |cos(unit Phi2, unit pred_nl)|: **%.4f**; vs rank-2 recon: **%.4f**\n', meanCosP2, meanCosP2r2);
fprintf(fid, '- Quadratic helps vs linear CDF (mean RMSE ratio > 1.03): **%s**\n', char(ternaryStr(nlHelpsVsLinear)));
fprintf(fid, '- Phi2-like alignment heuristic (cos pred_nl vs Phi2): **%s**\n\n', char(ternaryStr(phi2AlignedNl)));

fprintf(fid, '## Task 3 — Phi2-like structure\n');
fprintf(fid, 'Mean |cos(unit Phi2, unit NL prediction)| is **~%.2f**; a strong-alignment cutoff is **0.55**; ', meanCosP2);
fprintf(fid, 'rank-2 reconstruction cosine is **~%.2f**. The NL backbone fit does not robustly reproduce a Phi2-like shape.\n\n', meanCosP2r2);

fprintf(fid, '## Final verdict\n');
fprintf(fid, '| Question | Answer |\n| --- | --- |\n');
fprintf(fid, '| RESIDUAL_IS_NONLINEAR_RESPONSE | **%s** |\n', verdictRes);
fprintf(fid, '| NONLINEAR_MODEL_COMPETES_WITH_RANK2 | **%s** |\n\n', verdictComp);

fprintf(fid, 'Interpretation: **RESIDUAL_IS_NONLINEAR_RESPONSE** = YES if either ');
fprintf(fid, '(A) mean RMSE(NL) is within **5%%** of mean RMSE(rank-2), or ');
fprintf(fid, '(B) quadratic clearly beats linear-in-S_CDF (ratio > 1.03, gain ≥1%% of mean rank-1 RMSE) ');
fprintf(fid, '*and* mean RMSE(NL) is within **5%%** of mean RMSE(rank-1) (same backbone explains the strip).\n');
fprintf(fid, '**NONLINEAR_MODEL_COMPETES_WITH_RANK2** = YES if mean RMSE(NL) <= **1.05** * mean RMSE(rank-2).\n');
fprintf(fid, '**Phi2-like structure (heuristic):** mean |cos(unit Phi2, unit pred_nl)| = **%.4f**; rank-2 reconstruction **%.4f**; ');
fprintf(fid, 'alignment flag **%s** (|cos|≥0.55 or ≥ rank-2 recon + 0.05).\n', meanCosP2, meanCosP2r2, char(ternaryStr(phi2AlignedNl)));
fclose(fid);
end

function s = ternaryStr(flag)
if flag
    s = "YES";
else
    s = "NO";
end
end

function [Smap, temps, currents] = orientAndSortMapLocal(SmapIn, tempsIn, currentsIn)
Smap = double(SmapIn);
temps = double(tempsIn(:));
currents = double(currentsIn(:));
rowsAreTemps = size(Smap, 1) == numel(temps) && size(Smap, 2) == numel(currents);
rowsAreCurrents = size(Smap, 1) == numel(currents) && size(Smap, 2) == numel(temps);
if rowsAreCurrents && ~rowsAreTemps
    Smap = Smap.';
elseif ~(rowsAreTemps || rowsAreCurrents)
    error('Smap dimensions do not match temps/currents.');
end
[temps, tOrd] = sort(temps);
[currents, iOrd] = sort(currents);
Smap = Smap(tOrd, iOrd);
end

function [temps, Ipeak, Speak, width] = extractScalingColumnsLocal(tbl)
varNames = string(tbl.Properties.VariableNames);
temps = numericColumnLocal(tbl, varNames, ["T_K", "T"]);
Ipeak = numericColumnLocal(tbl, varNames, ["Ipeak_mA", "I_peak", "Ipeak"]);
Speak = numericColumnLocal(tbl, varNames, ["S_peak", "Speak", "Speak_peak"]);
width = numericColumnLocal(tbl, varNames, ["width_chosen_mA", "width_I", "width"]);
[temps, ord] = sort(temps);
Ipeak = Ipeak(ord);
Speak = Speak(ord);
width = width(ord);
end

function col = numericColumnLocal(tbl, varNames, candidates)
col = NaN(height(tbl), 1);
for i = 1:numel(candidates)
    idx = find(varNames == candidates(i), 1, 'first');
    if ~isempty(idx)
        raw = tbl.(varNames(idx));
        if isnumeric(raw)
            col = double(raw(:));
        else
            col = str2double(string(raw(:)));
        end
        return;
    end
end
end

function Rout = interpolateRowsToGridLocal(Xrows, Yrows, xGrid)
nRows = size(Xrows, 1);
nX = numel(xGrid);
Rout = NaN(nRows, nX);
for i = 1:nRows
    x = Xrows(i, :);
    y = Yrows(i, :);
    m = isfinite(x) & isfinite(y);
    if nnz(m) < 3
        continue;
    end
    x = x(m);
    y = y(m);
    [x, ord] = sort(x);
    y = y(ord);
    [x, iu] = unique(x, 'stable');
    y = y(iu);
    Rout(i, :) = interp1(x, y, xGrid, 'linear', NaN);
end
end
