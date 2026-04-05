function out = run_phi_pt_restricted_deformation_5_1(cfg)
% run_phi_pt_restricted_deformation_5_1
% AGENT 5.1 — PHI FROM PT RESTRICTED DEFORMATION TEST
%
% Implements:
%   Task 1: GLOBAL_PT_DEFORMATION via parametric P_T perturbations.
%   Task 2: LOCAL_PT_DEFORMATION via local PT-bin tangent functional derivative.
%
% Hard constraints followed:
% - Read-only: does not recompute P_T or residual decomposition.
% - Uses only existing run artifacts for Phi(x), kappa(T), alignment mapping, and PT_matrix.csv.
%
% Required outputs:
% - tables/phi_pt_restricted_reconstruction_summary.csv
% - tables/phi_local_tangent_summary.csv
% - reports/phi_pt_deformation_report.md

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

set(0, 'DefaultFigureVisible', 'off');

% -------------------- Repo + path setup --------------------
analysisDir = fileparts(mfilename('fullpath'));
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'analysis', 'knowledge'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = localApplyDefaults(cfg);

% -------------------- Inputs (existing runs/artifacts) --------------------
% Residual decomposition run (Phi, kappa, and source metadata)
decompRunId = string(cfg.decompositionRunId);
% Create the run folder early (before any heavy evidence loading) so the
% filesystem reflects progress even if later steps take time.
runDataset = sprintf('phi_pt_restricted_deformation | decomp:%s', char(decompRunId));
run = createSwitchingRunContext(repoRoot, struct('runLabel', cfg.runLabel, 'dataset', runDataset));
runDir = run.run_dir;
fprintf('Phi PT restricted deformation run directory:\n%s\n', runDir);

appendText(run.log_path, sprintf('[%s] run_phi_pt_restricted_deformation_5_1 started\n', localStampNow()));
appendText(run.log_path, sprintf('decompositionRunId=%s\n', char(decompRunId)));
evDecomp = load_run_evidence(decompRunId);
if strlength(evDecomp.path) == 0
    error('Decomposition run id not resolved by load_run_evidence: %s', decompRunId);
end

phiPath = localFindPathBySuffix(evDecomp.tables, 'phi_shape.csv');
kappaPath = localFindPathBySuffix(evDecomp.tables, 'kappa_vs_T.csv');
sourcesPath = localFindPathBySuffix(evDecomp.tables, 'residual_decomposition_sources.csv');
assert(exist(phiPath, 'file') == 2, 'Missing phi_shape.csv: %s', phiPath);
assert(exist(kappaPath, 'file') == 2, 'Missing kappa_vs_T.csv: %s', kappaPath);
assert(exist(sourcesPath, 'file') == 2, 'Missing residual_decomposition_sources.csv: %s', sourcesPath);

phiTbl = readtable(phiPath);
xGrid = double(phiTbl.x(:));
phiEmpRaw = double(phiTbl.Phi(:));
phiEmp = localNormalizeToMaxAbs(phiEmpRaw);

kappaTbl = readtable(kappaPath);
kn = string(kappaTbl.Properties.VariableNames);
kappaTcol = localPickVar(kn, ["T", "T_K"]);
kappaVals = double(kappaTbl.kappa(:));
tempsK = double(kappaTbl.(kappaTcol)(:));
assert(numel(xGrid) == numel(phiEmp), 'Phi shape length mismatch.');
fprintf('[phi_pt_restricted_deformation_5_1] Loaded Phi(x) + kappa(T). nX=%d, nT=%d\n', numel(xGrid), numel(tempsK));

% Latest robust PT extraction (PT_matrix.csv)
ptRobustRunId = localFindLatestPtRobustRunId(repoRoot);
evPT = load_run_evidence(ptRobustRunId);
ptMatrixPath = localFindPathBySuffix(evPT.tables, 'PT_matrix.csv');
assert(exist(ptMatrixPath, 'file') == 2, 'PT_matrix.csv not found for: %s', ptRobustRunId);
fprintf('[phi_pt_restricted_deformation_5_1] Latest pt_robust run resolved: %s\n', char(ptRobustRunId));

appendText(run.log_path, sprintf('pt_robust_run_id=%s\n', char(ptRobustRunId)));

% -------------------- Subsets (low-T and excluding T=22K) --------------------
maskAllLow = tempsK <= cfg.canonicalMaxTemperatureK + cfg.tempTolK;
maskNo22 = maskAllLow & ~(abs(tempsK - cfg.exclude22K) <= cfg.excludeTolK);
if ~any(maskNo22)
    % Handle pathological cases: fall back to all_lowT.
    maskNo22 = maskAllLow;
end

% -------------------- Load alignment mapping + decomp baseline deltaS --------------------
% Extract source_file paths from residual_decomposition_sources.csv.
sourcesTbl = readtable(sourcesPath);
alignmentCorePath = localFindSourceFile(sourcesTbl, 'alignment_core_map');
scalingParamsPath = localFindSourceFile(sourcesTbl, 'full_scaling_parameters');
ptMatrixDecompPath = localFindSourceFile(sourcesTbl, 'pt_matrix');

% Load alignment map and scaling parameters; align to the kappa temperatures.
[Smap, tempsMap, currents] = localLoadAlignmentCore(alignmentCorePath);
[Ipeak, Speak, width, tempsScale] = localLoadScalingParams(scalingParamsPath);

% Ensure tempsScale and tempsMap include tempsK; align by nearest match.
nT = numel(tempsK);
IpeakK = NaN(nT, 1); SpeakK = NaN(nT, 1); widthK = NaN(nT, 1);
for it = 1:nT
    T = tempsK(it);
    idxM = find(abs(tempsMap - T) <= cfg.tempTolK, 1, 'first');
    idxS = find(abs(tempsScale - T) <= cfg.tempTolK, 1, 'first');
    if isempty(idxM) || isempty(idxS)
        continue;
    end
    IpeakK(it) = Ipeak(idxS);
    SpeakK(it) = Speak(idxS);
    widthK(it) = width(idxS);
end

% Load decomposition baseline PT_matrix (used to compute deltaS_actual).
ptDecompData = localLoadPTData(ptMatrixDecompPath);
pMatDecomp = localBuildPTdensitiesOnPtCurrents(ptDecompData, tempsK);

% Precompute xRow mapping for each temperature on the *switching currents* grid.
% xRow(it, iI) = (I - Ipeak(T))/width(T)
nI = numel(currents);
Xrows = NaN(nT, nI);
for it = 1:nT
    if ~isfinite(widthK(it)) || widthK(it) == 0
        continue;
    end
    Xrows(it, :) = (currents(:)' - IpeakK(it)) ./ widthK(it);
end

% Compute deltaS_actual(I,T) from Smap and PT-backed CDF using the decomp PT baseline.
% deltaS_actual = Smap - Speak(T) * CDF(P_T_decomp)
deltaS_actual_x = NaN(nT, numel(xGrid));

% Build Scdf rows and interpolate onto xGrid.
for it = 1:nT
    if ~maskAllLow(it) && ~maskNo22(it)
        % Still potentially needed for intermediate masks; skip if not in either subset.
        continue;
    end
    if any(~isfinite([SpeakK(it), IpeakK(it), widthK(it)]))
        continue;
    end
    idxM = find(abs(tempsMap - tempsK(it)) <= cfg.tempTolK, 1, 'first');
    if isempty(idxM)
        continue;
    end
    Srow = Smap(idxM, :);
    p0 = pMatDecomp(it, :).';
    if any(~isfinite(p0))
        continue;
    end
    cdf0 = localCdfFromPdfOnPtCurr(p0, ptDecompData.currents, currents);
    Scdf0 = SpeakK(it) .* cdf0(:).';
    dSrow = Srow - Scdf0;
    deltaS_actual_x(it, :) = localInterpolateRowToX(xGrid, Xrows(it, :), dSrow);
end

% Baseline RMSE used in ratios: RMSE(deltaS_actual - kappa*Phi)
rmseBaselineMask = maskNo22; % used later for baseline rmse comparisons inside metrics

% -------------------- PT baseline for perturbations (latest robust) --------------------
ptRobustData = localLoadPTData(ptMatrixPath);
pMatRobust = localBuildPTdensitiesOnPtCurrents(ptRobustData, tempsK);

% Precompute baseline CDF rows on switching currents grid for robust PT baseline.
cdfRobust0 = NaN(nT, nI);
for it = 1:nT
    if any(~isfinite(pMatRobust(it, :)))
        continue;
    end
    cdfRobust0(it, :) = localCdfFromPdfOnPtCurr(pMatRobust(it, :).', ptRobustData.currents, currents);
end

% -------------------- Task 1: Global parametric perturbations --------------------
pertTypes = {'mean_shift', 'width_scaling', 'skew_perturb', 'tail_reweight_highI'};
alphaGrids = struct();
alphaGrids.mean_shift = linspace(-0.8, 0.8, 9);            % shift = alpha * sigma(T)
alphaGrids.width_scaling = linspace(-0.4, 0.4, 9);       % scale s = exp(alpha)
alphaGrids.skew_perturb = linspace(-2.0, 2.0, 9);        % exponential tilt
alphaGrids.tail_reweight_highI = linspace(-2.0, 2.0, 9);  % high-I exponential reweight

bestByPert = struct();
for pi = 1:numel(pertTypes)
    bestByPert.(pertTypes{pi}).all_lowT = struct('corr', -Inf, 'rmseRatio', NaN);
    bestByPert.(pertTypes{pi}).no_22K = struct('corr', -Inf, 'rmseRatio', NaN);
end

% Helper: compute metrics for a given subset mask.
computeMetrics = @(phiPred, Ractual_x, kappaSel, Rpred_x) localMetricsForPhi(phiPred, Ractual_x, Rpred_x, kappaSel);

% Evaluate perturbations
for pi = 1:numel(pertTypes)
    pType = pertTypes{pi};
    alphaGrid = alphaGrids.(pType);
    appendText(run.log_path, sprintf('Task1: perturbation=%s (alphas=%d)\n', pType, numel(alphaGrid)));

    for ai = 1:numel(alphaGrid)
        alpha = alphaGrid(ai);
        try
            % Compute induced deltaS_pred_x(T,x) on the decomposition xGrid
            deltaS_pred_x = NaN(nT, numel(xGrid));

            for it = 1:nT
                if ~(maskAllLow(it) || maskNo22(it))
                    continue;
                end
                if ~isfinite(SpeakK(it)) || ~all(isfinite(Xrows(it, :)))
                    continue;
                end
                if any(~isfinite(pMatRobust(it, :)))
                    continue;
                end
                p0 = pMatRobust(it, :).';
                cdf0 = cdfRobust0(it, :).';
                if any(~isfinite(cdf0)) || any(cdf0 <= 0)
                    continue;
                end

                % Perturb pdf on ptCurrents and compute its induced CDF
                pPert = localPerturbPdf(p0, ptRobustData.currents, pType, alpha);
                if isempty(pPert) || any(~isfinite(pPert))
                    continue;
                end
                cdf1 = localCdfFromPdfOnPtCurr(pPert, ptRobustData.currents, currents);

                inducedCurrent = SpeakK(it) .* (cdf1(:).' - cdf0(:).');
                deltaS_pred_x(it, :) = localInterpolateRowToX(xGrid, Xrows(it, :), inducedCurrent);
            end

            % Subset metrics: all_lowT
            tSelIdxAll = find(maskAllLow);
            [phiPredAll, corrAll, rmseRatioAll] = localEvalOneSubset(phiEmp, phiEmp, xGrid, ...
                deltaS_actual_x, deltaS_pred_x, kappaVals, tSelIdxAll, cfg);

            if isfinite(corrAll) && corrAll > bestByPert.(pType).all_lowT.corr
                bestByPert.(pType).all_lowT.corr = corrAll;
                bestByPert.(pType).all_lowT.rmseRatio = rmseRatioAll;
            end

            % Subset metrics: no_22K
            tSelIdxNo22 = find(maskNo22);
            [phiPredNo22, corrNo22, rmseRatioNo22] = localEvalOneSubset(phiEmp, phiEmp, xGrid, ...
                deltaS_actual_x, deltaS_pred_x, kappaVals, tSelIdxNo22, cfg);

            if isfinite(corrNo22) && corrNo22 > bestByPert.(pType).no_22K.corr
                bestByPert.(pType).no_22K.corr = corrNo22;
                bestByPert.(pType).no_22K.rmseRatio = rmseRatioNo22;
            end
        catch ME
            appendText(run.log_path, sprintf('Task1 perturbation failed (type=%s alpha=%g): %s\n', pType, alpha, ME.message));
            continue;
        end
    end
end

% Assemble required Task 1 output table.
rows = {};
for pi = 1:numel(pertTypes)
    pType = pertTypes{pi};
    b1 = bestByPert.(pType).all_lowT;
    rows{end+1, 1} = table({pType}, b1.corr, b1.rmseRatio, {'all_lowT'}, ...
        'VariableNames', {'perturbation_type', 'corr_with_phi', 'rmse_ratio', 'subset'}); %#ok<AGROW>
    b2 = bestByPert.(pType).no_22K;
    rows{end+1, 1} = table({pType}, b2.corr, b2.rmseRatio, {'no_22K'}, ...
        'VariableNames', {'perturbation_type', 'corr_with_phi', 'rmse_ratio', 'subset'}); %#ok<AGROW>
end
reconSummaryTbl = vertcat(rows{:});
reconSummaryPath = save_run_table(reconSummaryTbl, 'phi_pt_restricted_reconstruction_summary.csv', runDir);

% Global best for verdicts (use no_22K)
subNo22 = reconSummaryTbl(reconSummaryTbl.subset == "no_22K", :);
[bestCorrGlobal, ixBest] = max(abs(subNo22.corr_with_phi), [], 'omitnan');
if isempty(ixBest) || ~isfinite(bestCorrGlobal)
    bestCorrGlobal = NaN; bestRmseGlobal = NaN; bestPertType = "";
else
    bestRow = subNo22(ixBest, :);
    bestRmseGlobal = double(bestRow.rmse_ratio);
    bestPertType = string(bestRow.perturbation_type);
end

subAll = reconSummaryTbl(reconSummaryTbl.subset == "all_lowT", :);
[bestCorrGlobalAll, ixBestAll] = max(abs(subAll.corr_with_phi), [], 'omitnan');
if isempty(ixBestAll) || ~isfinite(bestCorrGlobalAll)
    bestCorrGlobalAll = NaN; bestRmseGlobalAll = NaN;
else
    bestRowAll = subAll(ixBestAll, :);
    bestRmseGlobalAll = double(bestRowAll.rmse_ratio);
end

% -------------------- Task 2: Local tangent (functional derivative test) --------------------
% Build tangent basis vectors from local PT-bin perturbations around robust P_T baseline.
% Tangent bins are PT current columns in PT_matrix.csv.
tangentBinIdx = 1:numel(ptRobustData.currents);
nBins = numel(tangentBinIdx);
deltaS_bin_x = NaN(nBins, nT, numel(xGrid)); % bin x temperature x x-grid

epsRel = cfg.tangentEpsilonRel;
appendText(run.log_path, sprintf('Task2: local tangent basis bins=%d epsRel=%g\n', nBins, epsRel));

for bi = 1:nBins
    j = tangentBinIdx(bi);
    try
        for it = 1:nT
            if ~(maskAllLow(it) || maskNo22(it))
                continue;
            end
            if ~isfinite(SpeakK(it)) || any(~isfinite(Xrows(it, :)))
                continue;
            end
            if any(~isfinite(pMatRobust(it, :)))
                continue;
            end
            p0 = pMatRobust(it, :).';
            if ~isfinite(p0(j)) || p0(j) <= 0
                continue;
            end

            e = zeros(size(p0));
            e(j) = p0(j);
            p1un = p0 + epsRel * e;
            p1un = max(p1un, 0);
            area = trapz(ptRobustData.currents(:), p1un(:));
            if ~(isfinite(area) && area > 0)
                continue;
            end
            p1 = p1un(:) ./ area;

            cdf0 = cdfRobust0(it, :).';
            if any(~isfinite(cdf0)) || cdf0(end) <= 0
                continue;
            end
            cdf1 = localCdfFromPdfOnPtCurr(p1, ptRobustData.currents, currents);

            inducedCurrentDeriv = SpeakK(it) .* (cdf1(:).' - cdf0(:).') ./ epsRel;
            deltaS_bin_x(bi, it, :) = localInterpolateRowToX(xGrid, Xrows(it, :), inducedCurrentDeriv);
        end
    catch ME
        appendText(run.log_path, sprintf('Task2 failed bin=%d: %s\n', j, ME.message));
        continue;
    end
end

% Fit Phi(x) ≈ sum a_i * tangentBasis_i(x)
% where tangentBasis_i(x) is computed by kappa-weighted projection of bin response.
[corrT_all, rmseRatioT_all] = localFitPhiFromTangentBasis(phiEmp, deltaS_actual_x, deltaS_bin_x, kappaVals, maskAllLow, cfg);
[corrT_no22, rmseRatioT_no22] = localFitPhiFromTangentBasis(phiEmp, deltaS_actual_x, deltaS_bin_x, kappaVals, maskNo22, cfg);

localTangentTbl = table( ...
    [corrT_all; corrT_no22], ...
    [rmseRatioT_all; rmseRatioT_no22], ...
    ["all_lowT"; "no_22K"], ...
    'VariableNames', {'corr_tangent', 'rmse_ratio_tangent', 'subset'});
localTangentPath = save_run_table(localTangentTbl, 'phi_local_tangent_summary.csv', runDir);

% -------------------- Verdict logic (exact spec) --------------------
globalStrong = (isfinite(bestCorrGlobal) && bestCorrGlobal > cfg.globalCorrThreshold && isfinite(bestRmseGlobal) && bestRmseGlobal < cfg.globalRmseRatioThreshold);
if globalStrong
    globalVerdict = "SUPPORTED";
else
    if isfinite(bestCorrGlobal) && bestCorrGlobal >= cfg.partialCorrLower && bestCorrGlobal <= cfg.partialCorrUpper
        globalVerdict = "PARTIAL";
    else
        globalVerdict = "NOT_SUPPORTED";
    end
end

localStrong = (isfinite(corrT_no22) && corrT_no22 > cfg.globalCorrThreshold && isfinite(rmseRatioT_no22) && rmseRatioT_no22 < cfg.globalRmseRatioThreshold);
if localStrong
    localVerdict = "SUPPORTED";
else
    if isfinite(corrT_no22) && corrT_no22 >= cfg.partialCorrLower && corrT_no22 <= cfg.partialCorrUpper
        localVerdict = "PARTIAL";
    else
        localVerdict = "NOT_SUPPORTED";
    end
end

if globalStrong || localStrong
    phiModeVerdict = "YES";
elseif globalVerdict == "NOT_SUPPORTED" && localVerdict == "NOT_SUPPORTED"
    phiModeVerdict = "NO";
else
    phiModeVerdict = "PARTIAL";
end

% -------------------- Print required verdict lines --------------------
fprintf('\nGLOBAL_PT_DEFORMATION: %s\n', globalVerdict);
fprintf('LOCAL_PT_DEFORMATION: %s\n', localVerdict);
fprintf('PHI_AS_PT_ONLY_MODE: %s\n', phiModeVerdict);

% Additional requested prints (not part of the 3 verdict lines)
fprintf('Global best corr (no_22K): %.4f | rmse_ratio: %.4g | pert_type: %s\n', ...
    bestCorrGlobal, bestRmseGlobal, char(bestPertType));
fprintf('Global best corr (all_lowT): %.4f | rmse_ratio: %.4g\n', bestCorrGlobalAll, bestRmseGlobalAll);
fprintf('Local tangent corr (no_22K): %.4f | rmse_ratio: %.4g\n', corrT_no22, rmseRatioT_no22);
fprintf('Local tangent corr (all_lowT): %.4f | rmse_ratio: %.4g\n', corrT_all, rmseRatioT_all);

% -------------------- Report + review bundle --------------------
reportLines = strings(0, 1);
reportLines(end+1) = "# Phi from PT restricted deformation (AGENT 5.1)";
reportLines(end+1) = "";
reportLines(end+1) = "## Inputs (read-only runs)";
reportLines(end+1) = sprintf("- Residual decomposition run: `%s`", char(decompRunId));
reportLines(end+1) = sprintf("- Latest robust PT run (PT_matrix.csv): `%s`", char(ptRobustRunId));
reportLines(end+1) = "";
reportLines(end+1) = "## Subsets";
reportLines(end+1) = sprintf("- all_lowT: T <= %.1f K", cfg.canonicalMaxTemperatureK);
reportLines(end+1) = sprintf("- no_22K: excluding |T-%.1f| <= %.3g K", cfg.exclude22K, cfg.excludeTolK);
reportLines(end+1) = "";
reportLines(end+1) = "## Task 1 (Global PT deformations)";
reportLines(end+1) = "Parametric perturbation types: mean shift, width scaling, skew perturbation, high-I tail reweighting.";
reportLines(end+1) = sprintf("- Global best (no_22K): corr=%.4f rmse_ratio=%.4g from `%s`", ...
    bestCorrGlobal, bestRmseGlobal, char(bestPertType));
reportLines(end+1) = sprintf("- Global best (all_lowT): corr=%.4f rmse_ratio=%.4g", ...
    bestCorrGlobalAll, bestRmseGlobalAll);
reportLines(end+1) = "";
reportLines(end+1) = "## Task 2 (Local tangent test)";
reportLines(end+1) = sprintf("- Local tangent (no_22K): corr=%.4f rmse_ratio=%.4g", corrT_no22, rmseRatioT_no22);
reportLines(end+1) = sprintf("- Local tangent (all_lowT): corr=%.4f rmse_ratio=%.4g", corrT_all, rmseRatioT_all);
reportLines(end+1) = "";
reportLines(end+1) = "## Verdicts (spec thresholds)";
reportLines(end+1) = sprintf("- GLOBAL_PT_DEFORMATION: **%s**", globalVerdict);
reportLines(end+1) = sprintf("- LOCAL_PT_DEFORMATION: **%s**", localVerdict);
reportLines(end+1) = sprintf("- PHI_AS_PT_ONLY_MODE: **%s**", phiModeVerdict);
reportLines(end+1) = "";
reportLines(end+1) = "## Output paths";
reportLines(end+1) = sprintf("- tables/phi_pt_restricted_reconstruction_summary.csv: `%s`", char(reconSummaryPath));
reportLines(end+1) = sprintf("- tables/phi_local_tangent_summary.csv: `%s`", char(localTangentPath));

reportText = strjoin(reportLines, newline);
reportPath = save_run_report(reportText, 'phi_pt_deformation_report.md', runDir);

zipPath = localBuildReviewZip(runDir, 'phi_pt_restricted_deformation_bundle.zip');
appendText(run.log_path, sprintf('[%s] complete | report=%s | zip=%s\n', localStampNow(), char(reportPath), char(zipPath)));

out = struct();
out.runDir = string(runDir);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.globalVerdict = string(globalVerdict);
out.localVerdict = string(localVerdict);
out.phiModeVerdict = string(phiModeVerdict);
out.bestCorrGlobalNo22K = bestCorrGlobal;
out.bestRmseGlobalNo22K = bestRmseGlobal;
out.bestCorrGlobalAllLowT = bestCorrGlobalAll;
out.bestRmseGlobalAllLowT = bestRmseGlobalAll;
out.corrTangentNo22K = corrT_no22;
out.rmseRatioTangentNo22K = rmseRatioT_no22;
out.corrTangentAllLowT = corrT_all;
out.rmseRatioTangentAllLowT = rmseRatioT_all;
out.reconSummaryPath = string(reconSummaryPath);
out.localTangentPath = string(localTangentPath);

end

%% -------------------- Local helpers --------------------
function cfg = localApplyDefaults(cfg)
cfg = localSetDef(cfg, 'runLabel', 'phi_pt_restricted_deformation');
cfg = localSetDef(cfg, 'decompositionRunId', 'run_2026_03_24_220314_residual_decomposition');

cfg = localSetDef(cfg, 'canonicalMaxTemperatureK', 30);
cfg = localSetDef(cfg, 'exclude22K', 22);
cfg = localSetDef(cfg, 'excludeTolK', 1e-3);
cfg = localSetDef(cfg, 'tempTolK', 1e-3);

cfg = localSetDef(cfg, 'tangentEpsilonRel', 1e-3);
cfg = localSetDef(cfg, 'epsFloor', 1e-12);

% Verdict thresholds: exact spec
cfg = localSetDef(cfg, 'globalCorrThreshold', 0.9);
cfg = localSetDef(cfg, 'globalRmseRatioThreshold', 1.5);
cfg = localSetDef(cfg, 'partialCorrLower', 0.6);
cfg = localSetDef(cfg, 'partialCorrUpper', 0.9);
end

function cfg = localSetDef(cfg, f, v)
if ~isfield(cfg, f) || isempty(cfg.(f))
    cfg.(f) = v;
end
end

function p = localFindPathBySuffix(paths, suffix)
p = "";
for i = 1:numel(paths)
    if endsWith(string(paths{i}), suffix, 'IgnoreCase', true)
        p = string(paths{i});
        return;
    end
end
end

function stamp = localStampNow()
stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('Unable to append to %s.', filePath);
    return;
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', char(string(textValue)));
end

function s = localPickVar(varNames, candidates)
s = "";
for k = 1:numel(candidates)
    if any(varNames == string(candidates(k)))
        s = string(candidates(k));
        return;
    end
end
if strlength(s) == 0
    s = varNames(1);
end
end

function sourcesPath = localFindSourceFile(tbl, role)
vn = string(tbl.Properties.VariableNames);
assert(any(vn == "source_role"), 'sources csv missing source_role col');
assert(any(vn == "source_file"), 'sources csv missing source_file col');
roles = string(tbl.source_role(:));
idx = find(roles == role, 1, 'first');
if isempty(idx)
    error('Missing role=%s in residual_decomposition_sources.csv', role);
end
sourcesPath = string(tbl.source_file(idx));
end

function [Smap, temps, currents] = localLoadAlignmentCore(alignmentCorePath)
core = load(alignmentCorePath, 'Smap', 'temps', 'currents');
SmapIn = core.Smap;
tempsIn = core.temps;
currentsIn = core.currents;

Smap = double(SmapIn);
temps = double(tempsIn(:));
currents = double(currentsIn(:));

rowsAreTemps = size(Smap, 1) == numel(temps) && size(Smap, 2) == numel(currents);
rowsAreCurrents = size(Smap, 1) == numel(currents) && size(Smap, 2) == numel(temps);
if rowsAreCurrents && ~rowsAreTemps
    Smap = Smap.';
elseif ~(rowsAreTemps || rowsAreCurrents)
    error('Smap dimensions do not match temps/currents in %s', alignmentCorePath);
end

[temps, tOrd] = sort(temps);
[currents, iOrd] = sort(currents);
Smap = Smap(tOrd, iOrd);
end

function [Ipeak, Speak, width, tempsScale] = localLoadScalingParams(scalingParamsPath)
tbl = readtable(scalingParamsPath);
vn = string(tbl.Properties.VariableNames);

tempsScale = localNumericColumn(tbl, vn, ["T_K", "T"]);
Ipeak = localNumericColumn(tbl, vn, ["Ipeak_mA", "I_peak", "Ipeak"]);
Speak = localNumericColumn(tbl, vn, ["S_peak", "Speak", "Speak_peak"]);
width = localNumericColumn(tbl, vn, ["width_chosen_mA", "width_I", "width"]);

[tempsScale, ord] = sort(tempsScale);
Ipeak = Ipeak(ord);
Speak = Speak(ord);
width = width(ord);
end

function col = localNumericColumn(tbl, varNames, candidates)
col = NaN(height(tbl), 1);
for i = 1:numel(candidates)
    idx = find(varNames == string(candidates(i)), 1, 'first');
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

function ptData = localLoadPTData(ptMatrixPath)
ptData = struct('available', false, 'temps', [], 'currents', [], 'PT', []);
if strlength(string(ptMatrixPath)) == 0 || exist(char(ptMatrixPath), 'file') ~= 2
    return;
end

tbl = readtable(char(ptMatrixPath));
varNames = string(tbl.Properties.VariableNames);
if isempty(varNames)
    return;
end

if any(varNames == "T_K")
    tCol = "T_K";
else
    tCol = varNames(1);
end

temps = tbl.(tCol);
if ~isnumeric(temps)
    temps = str2double(string(temps));
end
temps = double(temps(:));

currentCols = setdiff(varNames, tCol, 'stable');
currents = NaN(numel(currentCols), 1);
for j = 1:numel(currentCols)
    currents(j) = localParseCurrentFromColumnName(currentCols(j));
end
keep = isfinite(currents);
currents = currents(keep);
currentCols = currentCols(keep);
if isempty(currents)
    return;
end

PT = table2array(tbl(:, currentCols));
PT = double(PT);
[currents, ord] = sort(currents);
PT = PT(:, ord);

ptData.available = true;
ptData.temps = temps;
ptData.currents = currents;
ptData.PT = PT;
end

function val = localParseCurrentFromColumnName(name)
s = char(string(name));
s = regexprep(s, '^Ith_', '', 'ignorecase');
s = regexprep(s, '_mA$', '', 'ignorecase');
sDot = strrep(s, '_', '.');
val = str2double(sDot);
if isfinite(val)
    return;
end
m = regexp(s, '[-+]?\d*\.?\d+', 'match', 'once');
if isempty(m)
    val = NaN;
else
    val = str2double(m);
end
end

function pMat = localBuildPTdensitiesOnPtCurrents(ptData, tempsK)
ptCurr = ptData.currents(:);
tempsPT = ptData.temps(:);
PT = ptData.PT;

nT = numel(tempsK);
nI = numel(ptCurr);
pMat = NaN(nT, nI);

for it = 1:nT
    T = tempsK(it);
    pAtT = NaN(nI, 1);
    for j = 1:nI
        col = PT(:, j);
        m = isfinite(tempsPT) & isfinite(col);
        if nnz(m) < 2
            continue;
        end
        pAtT(j) = interp1(tempsPT(m), col(m), T, 'linear', NaN);
    end
    pAtT(~isfinite(pAtT)) = 0;
    pAtT = max(pAtT, 0);
    area = trapz(ptCurr, pAtT);
    if ~(isfinite(area) && area > 0)
        continue;
    end
    pMat(it, :) = (pAtT ./ area).';
end
end

function cdf = localCdfFromPdfOnPtCurr(pOnPtCurr, ptCurr, switchingCurrents)
% pOnPtCurr is a pdf sampled on ptCurr. Returns CDF sampled on switchingCurrents.
ptCurr = ptCurr(:);
switchingCurrents = switchingCurrents(:);
p = pOnPtCurr(:);

% Map onto switching current grid.
pOn = interp1(ptCurr, p, switchingCurrents, 'linear', 0);
pOn = max(pOn, 0);
area = trapz(switchingCurrents, pOn);
if ~(isfinite(area) && area > 0)
    cdf = NaN(size(switchingCurrents));
    return;
end
pOn = pOn ./ area;

cdf = cumtrapz(switchingCurrents, pOn);
if cdf(end) <= 0 || ~isfinite(cdf(end))
    cdf = NaN(size(switchingCurrents));
    return;
end
cdf = cdf ./ cdf(end);
cdf = min(max(cdf, 0), 1);
end

function y = localInterpolateRowToX(xGrid, xRow, yRow)
xRow = double(xRow(:)).';
yRow = double(yRow(:)).';
m = isfinite(xRow) & isfinite(yRow);
if nnz(m) < 3
    y = NaN(size(xGrid));
    return;
end
x = xRow(m);
yv = yRow(m);
[x, ord] = sort(x);
yv = yv(ord);
[x, iu] = unique(x, 'stable');
yv = yv(iu);
y = interp1(x, yv, xGrid, 'linear', NaN);
end

function vN = localNormalizeToMaxAbs(v)
scale = max(abs(v), [], 'omitnan');
if ~(isfinite(scale) && scale > 0)
    scale = 1;
end
vN = v ./ scale;
end

function pPert = localPerturbPdf(p0, ptCurr, pType, alpha)
% Returns perturbed pdf on the SAME ptCurr grid, normalized to 1.
ptCurr = ptCurr(:);
p0 = p0(:);
pPert = NaN(size(p0));
if any(~isfinite(p0)) || trapz(ptCurr, p0) <= 0
    return;
end

% Base moments for parameterizations.
mu = trapz(ptCurr, p0 .* ptCurr);
var = trapz(ptCurr, p0 .* (ptCurr - mu) .^ 2);
sigma = sqrt(max(var, 0));
if ~(isfinite(sigma) && sigma > 0)
    sigma = 1;
end

switch pType
    case 'mean_shift'
        shift = alpha * sigma;
        pPert = interp1(ptCurr, p0, ptCurr - shift, 'linear', 0);
    case 'width_scaling'
        % Scale transformation around mean: J = mu + (I-mu)/s, pdf includes Jacobian 1/s
        s = exp(alpha);
        J = mu + (ptCurr - mu) ./ s;
        pPert = interp1(ptCurr, p0, J, 'linear', 0) ./ s;
    case 'skew_perturb'
        tilt = exp(alpha * (ptCurr - mu) ./ (sigma + eps));
        pPert = p0 .* tilt;
    case 'tail_reweight_highI'
        % Define a high-I threshold via CDF quantile; reweight only above threshold.
        cdf0 = cumtrapz(ptCurr, p0);
        if cdf0(end) > 0
            cdf0 = cdf0 ./ cdf0(end);
        else
            cdf0(:) = NaN;
        end
        qTail = 0.75;
        idx = find(cdf0 >= qTail, 1, 'first');
        if isempty(idx)
            Ithr = ptCurr(end);
        else
            Ithr = ptCurr(idx);
        end
        rewt = exp(alpha * max(0, ptCurr - Ithr) ./ (sigma + eps));
        pPert = p0 .* rewt;
    otherwise
        pPert(:) = NaN;
end

pPert = max(pPert, 0);
area = trapz(ptCurr, pPert);
if ~(isfinite(area) && area > 0)
    pPert(:) = NaN;
    return;
end
pPert = pPert ./ area;
end

function [phiPred, corrAbs, rmseRatio] = localEvalOneSubset(phiEmpBase, ~, ~, ...
    deltaS_actual_x, deltaS_pred_x, kappaVals, tSelIdx, cfg) %#ok<INUSD>
% phiEmpBase: used for correlation with and baseline RMSE.
% deltaS_pred_x: induced residual change mapped to xGrid for all temperatures.

xGrid = []; %#ok<NASGU>

kappaSel = kappaVals(tSelIdx(:));
RactualSel = deltaS_actual_x(tSelIdx, :);
RpredSel = deltaS_pred_x(tSelIdx, :);

% Project induced residual onto kappa(T) * Phi(x) to extract a Phi-shaped prediction.
% phiPred(x) = sum_T kappa(T) * Rpred(T,x) / sum_T kappa(T)^2 (with NaN-safe denom).
phiPred = NaN(1, size(RpredSel, 2));
for xi = 1:size(RpredSel, 2)
    m = isfinite(RpredSel(:, xi)) & isfinite(kappaSel);
    if nnz(m) < 2
        continue;
    end
    denom = sum((kappaSel(m) .^ 2), 'omitnan');
    if ~(isfinite(denom) && denom > 0)
        continue;
    end
    phiPred(xi) = sum(kappaSel(m) .* RpredSel(m, xi), 'omitnan') ./ denom;
end
phiPred = phiPred(:);
phiPred = localNormalizeToMaxAbs(phiPred);

% Correlation (abs) between phiPred and empirical phi
mCorr = isfinite(phiEmpBase) & isfinite(phiPred);
if nnz(mCorr) < 10
    corrAbs = NaN;
else
    if dot(phiPred(mCorr), phiEmpBase(mCorr)) < 0
        phiPred = -phiPred;
    end
    corrVal = corr(phiEmpBase(mCorr), phiPred(mCorr));
    corrAbs = abs(corrVal);
end

% RMSE ratio in residual space: RMSE(actual - kappa*phiPred) / RMSE(actual - kappa*phiEmp)
RhatPred = NaN(size(RpredSel));
RhatBase = NaN(size(RpredSel));
phiEmp = phiEmpBase(:);
for it = 1:numel(tSelIdx)
    RhatPred(it, :) = kappaSel(it) .* phiPred(:).';
    RhatBase(it, :) = kappaSel(it) .* phiEmp(:).';
end

rmsePred = localRMSE(RactualSel, RhatPred);
rmseBase = localRMSE(RactualSel, RhatBase);
rmseRatio = rmsePred / max(rmseBase, cfg.epsFloor);
end

function epsFloor = localGetEpsFloor()
epsFloor = 1e-12;
end

function rmse = localRMSE(A, B)
diff = double(A - B);
diff = diff(:);
diff = diff(isfinite(diff));
if isempty(diff)
    rmse = NaN;
    return;
end
rmse = sqrt(mean(diff .^ 2, 'omitnan'));
end

function [corr_tangent, rmseRatio] = localFitPhiFromTangentBasis(phiEmp, deltaS_actual_x, deltaS_bin_x, kappaVals, maskSubset, cfg)
% deltaS_bin_x: (nBins x nT x nX), derived induced residual derivative responses.
tIdx = find(maskSubset);
if numel(tIdx) < 3
    corr_tangent = NaN;
    rmseRatio = NaN;
    return;
end

nBins = size(deltaS_bin_x, 1);
nX = size(deltaS_bin_x, 3);

kappaSel = kappaVals(tIdx);
RactualSel = deltaS_actual_x(tIdx, :);

% Build tangent basis vectors in Phi(x) space:
% For each bin i, compute deltaPhi_i(x) by kappa-weighted projection of induced response.
D = NaN(nX, nBins);
for bi = 1:nBins
    Rb = squeeze(deltaS_bin_x(bi, tIdx, :)); % nSel x nX
    phiBi = NaN(nX, 1);
    for xi = 1:nX
        m = isfinite(Rb(:, xi)) & isfinite(kappaSel);
        if nnz(m) < 2
            continue;
        end
        denom = sum((kappaSel(m) .^ 2), 'omitnan');
        if ~(isfinite(denom) && denom > 0)
            continue;
        end
        phiBi(xi) = sum(kappaSel(m) .* Rb(m, xi), 'omitnan') ./ denom;
    end
    D(:, bi) = phiBi(:);
end

% Remove bins with all NaNs.
keepBins = false(1, nBins);
for bi = 1:nBins
    keepBins(bi) = any(isfinite(D(:, bi)));
end
if ~any(keepBins)
    corr_tangent = NaN;
    rmseRatio = NaN;
    return;
end
D = D(:, keepBins);
keepIdx = find(keepBins);
nBinsUsed = size(D, 2); %#ok<NASGU>

% Fit phiEmp using least squares on finite x positions.
maskX = isfinite(phiEmp) & any(isfinite(D), 2);
if nnz(maskX) < 10
    corr_tangent = NaN;
    rmseRatio = NaN;
    return;
end

Dsub = D(maskX, :);
ysub = phiEmp(maskX);

% Least-squares coefficients; pinv keeps things stable.
a = pinv(Dsub) * ysub;
phiRecon = NaN(nX, 1);
phiRecon(maskX) = Dsub * a;
phiRecon = localNormalizeToMaxAbs(phiRecon);

% Correlation
mCorr = isfinite(phiEmp) & isfinite(phiRecon);
if nnz(mCorr) < 10
    corr_tangent = NaN;
else
    if dot(phiRecon(mCorr), phiEmp(mCorr)) < 0
        phiRecon = -phiRecon;
    end
    corrVal = corr(phiEmp(mCorr), phiRecon(mCorr));
    corr_tangent = abs(corrVal);
end

% RMSE ratio in residual space
Rhat = NaN(size(RactualSel));
phiEmpVec = phiEmp(:);
for it = 1:numel(tIdx)
    Rhat(it, :) = kappaSel(it) .* phiRecon(:).';
end
rmsePred = localRMSE(RactualSel, Rhat);
Rbase = NaN(size(RactualSel));
for it = 1:numel(tIdx)
    Rbase(it, :) = kappaSel(it) .* phiEmpVec(:).';
end
rmseBase = localRMSE(RactualSel, Rbase);
rmseRatio = rmsePred / max(rmseBase, cfg.epsFloor);
end

function ptRobustRunId = localFindLatestPtRobustRunId(repoRoot)
% Latest run with pt_robust and tables/PT_matrix.csv in run_registry.csv.
registryPath = fullfile(repoRoot, 'analysis', 'knowledge', 'run_registry.csv');
if exist(registryPath, 'file') ~= 2
    error('Missing run_registry.csv at %s', registryPath);
end
reg = readtable(registryPath, 'Delimiter', ',', 'TextType', 'string');

if ~any(reg.Properties.VariableNames == "run_id")
    error('run_registry.csv missing run_id column.');
end
if ~any(reg.Properties.VariableNames == "tables_csv")
    error('run_registry.csv missing tables_csv column.');
end

runIds = string(reg.run_id(:));
tablesCsv = string(reg.tables_csv(:));
isPt = contains(runIds, 'pt_robust', 'IgnoreCase', true) & contains(tablesCsv, 'tables/PT_matrix.csv', 'IgnoreCase', true);
cand = runIds(isPt);
if isempty(cand)
    error('No pt_robust run with tables/PT_matrix.csv found in run_registry.csv.');
end

% Avoid slow/fragile datetime parsing; compare numeric timestamp keys.
keys = NaN(numel(cand), 1);
for i = 1:numel(cand)
    tok = regexp(char(cand(i)), '^run_(\d{4})_(\d{2})_(\d{2})_(\d{6})_', 'tokens', 'once');
    if isempty(tok)
        continue;
    end
    yyyy = tok{1}; mm = tok{2}; dd = tok{3}; hhmmss = tok{4};
    keys(i) = str2double([yyyy, mm, dd, hhmmss]); %#ok<AGROW>
end

[~, ix] = max(keys, [], 'omitnan');
ptRobustRunId = cand(ix);
end

function [phi, corrVal, rmseRatio] = localMetricsForPhi(phiPred, Ractual_x, Rpred_x, kappaSel) %#ok<INUSD>
% Placeholder for earlier implementation (not used).
phi = phiPred;
corrVal = NaN;
rmseRatio = NaN;
end

function z = localGetFirstFinite(x)
ix = find(isfinite(x), 1, 'first');
if isempty(ix)
    z = NaN;
else
    z = x(ix);
end
end

function c = localBuildReviewZip(runDir, zipName)
c = "";
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
c = zipPath;
end

