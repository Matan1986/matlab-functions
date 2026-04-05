function out = run_phi_pt_restricted_deformation(cfg)
% run_phi_pt_restricted_deformation
% Determine whether Phi(x) can be reconstructed using a PT-only restricted basis.
%
% Restricted PT-only basis (no arbitrary kernels):
% - PT mean (low-T normalized densities)
% - Centered PT -> PCA/SVD modes (right singular vectors)
% - dPT/dT (mean derivative across the canonical subset; derivative computed from PT-only data)
% - PT-derived moment directions (median first/second central-moment weights)
%
% Mapping:
% - PT perturbations dP(I) are pushed through CDF into switching residual space
%   using the same PT-backed CDF construction and linearized deltaS response.
%
% Outputs (run-scoped):
% - tables/phi_pt_restricted_reconstruction_summary.csv
% - tables/phi_local_tangent_summary.csv
% - figures/phi_vs_pt_reconstruction.png
% - figures/variance_explained_vs_modes.png
% - reports/phi_pt_restricted_deformation_report.md
%
% Notes:
% - Exclude-22K is implemented as an evaluation/training temperature mask.

set(0, 'DefaultFigureVisible', 'off');

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

analysisDir = fileparts(mfilename('fullpath'));
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = localApplyDefaults(cfg);

decTablesDir = localResolveDecompositionTablesDir(repoRoot, cfg.decompositionRunId);
phiPath = fullfile(decTablesDir, 'phi_shape.csv');
kappaPath = fullfile(decTablesDir, 'kappa_vs_T.csv');
srcPath = fullfile(decTablesDir, 'residual_decomposition_sources.csv');

assert(exist(phiPath, 'file') == 2, 'Missing phi_shape.csv: %s', phiPath);
assert(exist(kappaPath, 'file') == 2, 'Missing kappa_vs_T.csv: %s', kappaPath);
assert(exist(srcPath, 'file') == 2, 'Missing residual_decomposition_sources.csv: %s', srcPath);

phiTbl = readtable(phiPath);
xGrid = double(phiTbl.x(:));
phiEmp = double(phiTbl.Phi(:));

kappaTbl = readtable(kappaPath);
kn = string(kappaTbl.Properties.VariableNames);
kappaTcol = localNumericColumnName(kappaTbl, kn, ["T", "T_K"]);
kappaVals = double(kappaTbl.kappa(:));

runDataset = sprintf('phi_pt_restricted_deformation | decomp:%s', cfg.decompositionRunId);
run = createSwitchingRunContext(repoRoot, struct('runLabel', cfg.runLabel, 'dataset', runDataset));
runDir = run.run_dir;

fprintf('Phi PT restricted deformation run directory:\n%s\n', runDir);
fprintf('Decomposition source run: %s\n', char(cfg.decompositionRunId));

appendText(run.log_path, sprintf('[%s] run_phi_pt_restricted_deformation started\n', localStampNow()));

[ptPath, alignId, scaleId] = localResolvePathsFromSourcesOrCfg(repoRoot, srcPath, cfg);
appendText(run.log_path, sprintf('PT_matrix: %s\n', char(ptPath)));
appendText(run.log_path, sprintf('alignment_run: %s | scaling_run: %s\n', char(alignId), char(scaleId)));

slice = localLoadAlignmentScalingSlice(repoRoot, alignId, scaleId, ptPath);
Smap = slice.Smap;
temps = slice.temps;
currents = slice.currents;
Ipeak = slice.Ipeak;
Speak = slice.Speak;
width = slice.width;
ptData = slice.ptData;

[Scdf, cdfMeta] = localBuildScdfMatrix(Smap, currents, temps, Speak, ptData, cfg.fallbackSmoothWindow);
assert(cdfMeta.ptRowsUsed == numel(temps), ...
    'PT-backed CDF rows missing: %d/%d used (pt-backup is required for restricted PT basis test).', ...
    cdfMeta.ptRowsUsed, numel(temps));

deltaS_I = Smap - Scdf;

% Canonical residual decomposition coordinate map:
nT = numel(temps);
nI = numel(currents);
Xrows = NaN(nT, nI);
for it = 1:nT
    Xrows(it, :) = (currents(:)' - Ipeak(it)) ./ width(it);
end

lowMaskAll = temps <= cfg.canonicalMaxTemperatureK;
lowMaskNo22K = lowMaskAll & ~(abs(temps - 22) <= cfg.exclude22KBand);

% Actual residual in switching x-space:
Rall_x = localInterpolateRowsToGrid(Xrows, deltaS_I, xGrid);
phiEmp = localNormalizePhiToMaxAbs(phiEmp);

% Compute reconstruction + local tangent per scenario:
scenarios = {
    struct('id', 'all_lowT', 'mask', lowMaskAll, 'label', 'T<=canonical')
    struct('id', 'exclude_22K', 'mask', lowMaskNo22K, 'label', 'T<=canonical, excl 22K')
    };

reconRows = cell(numel(scenarios), 1);
localRows = cell(numel(scenarios), 1);

% Store best values for verdict:
bestAll = struct();
bestNo22K = struct();
bestReconPhiExclude22K = NaN(numel(xGrid), 1);
bestReconNExclude22K = NaN;

for si = 1:numel(scenarios)
    scen = scenarios{si};
    maskT = scen.mask(:);
    tempsSel = temps(maskT);
    SpeakSel = Speak(maskT);
    widthSel = width(maskT);
    IpeakSel = Ipeak(maskT);
    XrowsSel = Xrows(maskT, :);
    Rsel_x = Rall_x(maskT, :);

    kappaSel = localLookupKappaAtT(kn, kappaTbl, kappaVals, tempsSel);

    % PT-only restricted basis (on PT current grid; built from the scenario mask):
    basis = localBuildPTRestrictedBasis(ptData, tempsSel, cfg);

    % Push each PT perturbation basis vector through CDF -> induced residual x-kernels psi_k:
    psiBasis = localInducePsiFromPTBasis(ptData, tempsSel, currents, SpeakSel, Scdf(maskT, :), ...
        XrowsSel, xGrid, phiEmp, basis, cfg.finiteDiffEpsilon);

    % Reconstruction across number of modes (sensitivity to # modes):
    reconRes = localReconstructPhiFromPsiModes(phiEmp, Rsel_x, kappaSel, psiBasis, cfg.maxReconModes);

    reconTable = reconRes.table;
    reconTable.scenario = repmat(string(scen.id), height(reconTable), 1);
    reconRows{si} = reconTable;

    % Local PT tangent test:
    localRes = localLocalPTTangentTest(ptData, tempsSel, currents, SpeakSel, Scdf(maskT, :), ...
        XrowsSel, xGrid, phiEmp, kappaSel, Rsel_x, cfg);
    localTable = localRes.table;
    localTable.scenario = repmat(string(scen.id), height(localTable), 1);
    localRows{si} = localTable;

    % Determine "best" for this scenario (best correlation among reconstructions):
    [bestCorr, idxBest] = max(abs(reconTable.corr_phi_reconstruction));
    bestRmseRatio = reconTable.rmse_ratio_residual_to_kappaPhi(idxBest);
    bestVarExpl = reconTable.variance_explained_phi(idxBest);
    bestN = reconTable.n_modes_used(idxBest);

    if strcmp(scen.id, 'exclude_22K')
        bestReconPhiExclude22K = reconRes.reconPhi_by_m(:, bestN); %#ok<NASGU>
        bestReconNExclude22K = bestN; %#ok<NASGU>
    end

    if strcmp(scen.id, 'all_lowT')
        bestAll = struct('bestCorr', bestCorr, 'bestRmseRatio', bestRmseRatio, ...
            'bestVarExpl', bestVarExpl, 'bestN', bestN);
    else
        bestNo22K = struct('bestCorr', bestCorr, 'bestRmseRatio', bestRmseRatio, ...
            'bestVarExpl', bestVarExpl, 'bestN', bestN);
    end
end

reconSummaryTbl = vertcat(reconRows{:});
localTangentTbl = vertcat(localRows{:});

% Save required tables:
phiSummaryPath = save_run_table(reconSummaryTbl, 'phi_pt_restricted_reconstruction_summary.csv', runDir);
phiLocalPath = save_run_table(localTangentTbl, 'phi_local_tangent_summary.csv', runDir);

% Figures:
% - phi_vs_pt_reconstruction.png: use best multi-mode reconstruction for exclude_22K scenario
% - variance_explained_vs_modes.png: cumulative variance explained vs n_modes for exclude_22K scenario
[figPaths, figPick] = localMakeFigures(runDir, reconSummaryTbl, xGrid, phiEmp, ...
    bestReconPhiExclude22K, bestReconNExclude22K);

% Compute final verdict (global + local):
[globalVerdict, localVerdict, phiModeVerdict, verdictText] = localComputeVerdicts(bestAll, bestNo22K, localTangentTbl, cfg);

% Report:
reportText = localBuildReport(cfg, decTablesDir, ptPath, alignId, scaleId, runDir, ...
    xGrid, phiPath, kappaPath, Scdf, cdfMeta, reconSummaryTbl, localTangentTbl, ...
    bestAll, bestNo22K, figPaths, phiSummaryPath, phiLocalPath, ...
    globalVerdict, localVerdict, phiModeVerdict, verdictText);
reportPath = save_run_report(reportText, 'phi_pt_restricted_deformation_report.md', runDir);

zipPath = localBuildReviewZip(runDir, 'phi_pt_restricted_deformation_bundle.zip');

appendText(run.notes_path, sprintf('Summary: global=%s | local=%s | phi_as_pt_only=%s\n', ...
    globalVerdict, localVerdict, phiModeVerdict));
appendText(run.log_path, sprintf('[%s] complete | report: %s\n', localStampNow(), char(reportPath)));

fprintf('\n=== Phi PT restricted deformation verdict ===\n');
fprintf('GLOBAL_PT_DEFORMATION: %s\n', globalVerdict);
fprintf('LOCAL_PT_DEFORMATION: %s\n', localVerdict);
fprintf('PHI_AS_PT_ONLY_MODE: %s\n', phiModeVerdict);
fprintf('best correlation (exclude_22K): %.4f\n', bestNo22K.bestCorr);
fprintf('RMSE ratio (exclude_22K): %.4g\n', bestNo22K.bestRmseRatio);
fprintf('effect of removing 22K: corr %.4f -> %.4f, rmse_ratio %.4g -> %.4g\n', ...
    bestAll.bestCorr, bestNo22K.bestCorr, bestAll.bestRmseRatio, bestNo22K.bestRmseRatio);
fprintf('Run folder: %s\n', runDir);

out = struct();
out.runDir = string(runDir);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.globalVerdict = string(globalVerdict);
out.localVerdict = string(localVerdict);
out.phiModeVerdict = string(phiModeVerdict);
out.bestAll = bestAll;
out.bestNo22K = bestNo22K;
out.figurePaths = figPaths;
out.summaryTablePath = string(phiSummaryPath);
out.localTangentTablePath = string(phiLocalPath);
out.selectedRecon = figPick;
end

%% -------------------------------------------------------------------------
function cfg = localApplyDefaults(cfg)
cfg = localSetDef(cfg, 'runLabel', 'phi_pt_restricted_deformation');
cfg = localSetDef(cfg, 'decompositionRunId', 'run_2026_03_24_220314_residual_decomposition');
cfg = localSetDef(cfg, 'alignmentRunId', '');
cfg = localSetDef(cfg, 'fullScalingRunId', '');
cfg = localSetDef(cfg, 'ptMatrixPath', '');
cfg = localSetDef(cfg, 'canonicalMaxTemperatureK', 30);
cfg = localSetDef(cfg, 'exclude22KBand', 0.25);
cfg = localSetDef(cfg, 'fallbackSmoothWindow', 5);

cfg = localSetDef(cfg, 'nPcaModes', 4);
cfg = localSetDef(cfg, 'nMomentDirs', 2);
cfg = localSetDef(cfg, 'maxReconModes', 7);

cfg = localSetDef(cfg, 'finiteDiffEpsilon', 1e-4);
cfg = localSetDef(cfg, 'minRowsForBasis', 6);
cfg = localSetDef(cfg, 'epsFloor', 1e-12);
end

function cfg = localSetDef(cfg, f, v)
if ~isfield(cfg, f) || isempty(cfg.(f))
    cfg.(f) = v;
end
end

function decDir = localResolveDecompositionTablesDir(repoRoot, runId)
rid = char(string(runId));
candidates = {
    fullfile(switchingCanonicalRunRoot(repoRoot), rid, 'tables')
    fullfile(switchingCanonicalRunRoot(repoRoot), ['_extract_' rid], rid, 'tables')
    };
decDir = '';
for i = 1:numel(candidates)
    p = fullfile(candidates{i}, 'phi_shape.csv');
    if exist(p, 'file') == 2
        decDir = candidates{i};
        return
    end
end
error('Decomposition tables not found for run %s.', rid);
end

function [ptPath, alignId, scaleId] = localResolvePathsFromSourcesOrCfg(repoRoot, srcPath, cfg)
alignId = string(cfg.alignmentRunId);
scaleId = string(cfg.fullScalingRunId);
ptPath = string(cfg.ptMatrixPath);

if exist(srcPath, 'file') == 2
    st = readtable(srcPath);
    vn = st.Properties.VariableNames;
    roleCol = localPickVar(vn, {'source_role', 'SourceRole'});
    fileCol = localPickVar(vn, {'source_file', 'SourceFile'});
    if ~isempty(roleCol) && ~isempty(fileCol)
        roles = string(st.(roleCol));
        for i = 1:height(st)
            if roles(i) == "alignment_core_map" && strlength(alignId) == 0
                p = char(st.(fileCol)(i));
                alignId = string(localRunIdFromPath(p));
            elseif roles(i) == "full_scaling_parameters" && strlength(scaleId) == 0
                p = char(st.(fileCol)(i));
                scaleId = string(localRunIdFromPath(p));
            elseif roles(i) == "pt_matrix" && strlength(ptPath) == 0
                p = char(st.(fileCol)(i));
                ptPath = string(p);
            end
        end
    end
end

if strlength(alignId) == 0
    alignId = "run_2026_03_10_112659_alignment_audit";
end
if strlength(scaleId) == 0
    scaleId = "run_2026_03_12_234016_switching_full_scaling_collapse";
end
if strlength(ptPath) == 0
    ptPath = string(fullfile(switchingCanonicalRunRoot(repoRoot), ...
        'run_2026_03_24_212033_switching_barrier_distribution_from_map', 'tables', 'PT_matrix.csv'));
end

assert(exist(char(ptPath), 'file') == 2, 'PT_matrix.csv not found: %s', char(ptPath));
end

function col = localPickVar(varNames, candidates)
col = '';
for k = 1:numel(candidates)
    if any(strcmp(varNames, candidates{k}))
        col = candidates{k};
        return
    end
end
end

function id = localRunIdFromPath(p)
parts = split(string(p), filesep);
idx = find(parts == "runs", 1, 'last');
if isempty(idx) || idx >= numel(parts)
    id = "";
    return
end
id = parts(idx + 1);
end

function slice = localLoadAlignmentScalingSlice(repoRoot, alignId, scaleId, ptMatrixPath)
source.alignmentRunDir = fullfile(switchingCanonicalRunRoot(repoRoot), char(alignId));
source.fullScalingRunDir = fullfile(switchingCanonicalRunRoot(repoRoot), char(scaleId));
source.alignmentCorePath = fullfile(source.alignmentRunDir, 'switching_alignment_core_data.mat');
source.fullScalingParamsPath = fullfile(source.fullScalingRunDir, 'tables', 'switching_full_scaling_parameters.csv');

assert(exist(source.alignmentCorePath, 'file') == 2, 'Missing %s', source.alignmentCorePath);
assert(exist(source.fullScalingParamsPath, 'file') == 2, 'Missing %s', source.fullScalingParamsPath);

core = load(source.alignmentCorePath, 'Smap', 'temps', 'currents');
paramsTbl = readtable(source.fullScalingParamsPath);

[SmapAll, tempsAll, currentsAll] = localOrientAndSortMap(core.Smap, core.temps(:), core.currents(:));
[tempsScale, IpeakScale, SpeakScale, widthScale] = localExtractScalingColumns(paramsTbl);
[tempsCommon, iMap, iScale] = intersect(tempsAll, tempsScale, 'stable');

Smap = SmapAll(iMap, :);
Ipeak = IpeakScale(iScale);
Speak = SpeakScale(iScale);
width = widthScale(iScale);

valid = isfinite(tempsCommon) & isfinite(Ipeak) & isfinite(Speak) & isfinite(width);
valid = valid & (width > 0);
valid = valid & (Speak > 1e-3 * max(Speak, [], 'omitnan'));

slice = struct();
slice.Smap = Smap(valid, :);
slice.temps = tempsCommon(valid);
slice.currents = currentsAll(:);
slice.Ipeak = Ipeak(valid);
slice.Speak = Speak(valid);
slice.width = width(valid);
slice.ptData = localLoadPTData(ptMatrixPath);
end

function [Smap, temps, currents] = localOrientAndSortMap(SmapIn, tempsIn, currentsIn)
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

function [temps, Ipeak, Speak, width] = localExtractScalingColumns(tbl)
varNames = string(tbl.Properties.VariableNames);
temps = localNumericColumn(tbl, varNames, ["T_K", "T"]);
Ipeak = localNumericColumn(tbl, varNames, ["Ipeak_mA", "I_peak", "Ipeak"]);
Speak = localNumericColumn(tbl, varNames, ["S_peak", "Speak", "Speak_peak"]);
width = localNumericColumn(tbl, varNames, ["width_chosen_mA", "width_I", "width"]);
[temps, ord] = sort(temps);
Ipeak = Ipeak(ord);
Speak = Speak(ord);
width = width(ord);
end

function col = localNumericColumn(tbl, varNames, candidates)
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
        return
    end
end
end

function [Scdf, meta] = localBuildScdfMatrix(~, currents, temps, Speak, ptData, fallbackSmoothWindow) %#ok<INUSD>
nT = numel(temps);
nI = numel(currents);
Scdf = NaN(nT, nI);
ptRows = 0;
fbRows = 0;

for it = 1:nT
    cdfRow = [];
    if ptData.available
        cdfRow = localCdfFromPT(ptData, temps(it), currents);
    end
    if isempty(cdfRow)
        cdfRow = localCdfFallbackFromRow(zeros(size(currents)), currents, fallbackSmoothWindow);
        fbRows = fbRows + 1;
    else
        ptRows = ptRows + 1;
    end
    Scdf(it, :) = Speak(it) .* cdfRow(:).';
end
meta = struct('ptRowsUsed', ptRows, 'fallbackRowsUsed', fbRows);
end

function cdfRow = localCdfFromPT(ptData, targetT, currents)
pOnCurr = localNormDensityOnCurrents(ptData, targetT, currents);
if isempty(pOnCurr)
    cdfRow = [];
    return
end
cdfRow = cumtrapz(currents, pOnCurr);
if cdfRow(end) <= 0
    cdfRow = [];
    return
end
cdfRow = cdfRow ./ cdfRow(end);
cdfRow = min(max(cdfRow, 0), 1);
end

function cdfRow = localCdfFallbackFromRow(~, currents, smoothWindow) %#ok<INUSD>
% Fallback used only to keep shapes finite; restricted PT test asserts PT rows are used.
row = zeros(size(currents(:)));
valid = isfinite(row) & isfinite(currents(:));
if nnz(valid) < 3
    cdfRow = zeros(size(currents));
    return
end
rNorm = zeros(size(currents(:))).';
if smoothWindow >= 2
    rNorm = smoothdata(rNorm, 'movmean', min(smoothWindow, numel(rNorm)));
end
cdfRow = cumtrapz(currents, max(rNorm, 0));
if cdfRow(end) > 0
    cdfRow = cdfRow ./ cdfRow(end);
end
cdfRow = min(max(cdfRow, 0), 1);
end

function ptData = localLoadPTData(ptMatrixPath)
ptData = struct('available', false, 'temps', [], 'currents', [], 'PT', []);
if exist(ptMatrixPath, 'file') ~= 2
    return
end
tbl = readtable(ptMatrixPath);
varNames = string(tbl.Properties.VariableNames);
if any(varNames == "T_K")
    tCol = "T_K";
else
    tCol = varNames(1);
end
temps = tbl.(tCol);
if isnumeric(temps)
    temps = double(temps(:));
else
    temps = str2double(string(temps(:)));
end
currentCols = setdiff(varNames, tCol, 'stable');
currents = NaN(numel(currentCols), 1);
for j = 1:numel(currentCols)
    currents(j) = localParseCurrentFromColumnName(currentCols(j));
end
keep = isfinite(currents);
currents = currents(keep);
currentCols = currentCols(keep);
if isempty(currents)
    return
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
    return
end
m = regexp(char(string(name)), '[-+]?\d*\.?\d+', 'match', 'once');
if isempty(m)
    val = NaN;
else
    val = str2double(m);
end
end

function pOn = localNormDensityOnCurrents(ptData, targetT, currents)
tempsPT = ptData.temps(:);
currPT = ptData.currents(:);
PT = ptData.PT;
if numel(tempsPT) < 2 || size(PT, 2) ~= numel(currPT)
    pOn = [];
    return
end

pAtT = NaN(numel(currPT), 1);
for j = 1:numel(currPT)
    col = PT(:, j);
    m = isfinite(tempsPT) & isfinite(col);
    if nnz(m) < 2
        continue
    end
    pAtT(j) = interp1(tempsPT(m), col(m), targetT, 'linear', NaN);
end
if all(~isfinite(pAtT))
    pOn = [];
    return
end
pAtT(~isfinite(pAtT)) = 0;
pAtT = max(pAtT, 0);

% Normalize on ptData current grid:
areaPT = trapz(currPT, pAtT);
if ~(isfinite(areaPT) && areaPT > 0)
    pOn = [];
    return
end
pAtT = pAtT ./ areaPT;

% Interpolate to the requested switching currents grid and renormalize:
pOnCurrents = interp1(currPT, pAtT, currents(:), 'linear', 0);
pOnCurrents = max(pOnCurrents, 0);
area = trapz(currents(:), pOnCurrents);
if ~(isfinite(area) && area > 0)
    pOn = [];
    return
end
pOn = (pOnCurrents / area);
pOn = pOn(:);
end

function Rout = localInterpolateRowsToGrid(Xrows, Yrows, xGrid)
nRows = size(Xrows, 1);
nX = numel(xGrid);
Rout = NaN(nRows, nX);
for i = 1:nRows
    x = Xrows(i, :);
    y = Yrows(i, :);
    m = isfinite(x) & isfinite(y);
    if nnz(m) < 3
        continue
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

function v = localNormalizePhiToMaxAbs(v)
scale = max(abs(v), [], 'omitnan');
if ~(isfinite(scale) && scale > 0)
    scale = 1;
end
v = v ./ scale;
end

function name = kappaTcolNameToField(~) %#ok<INUSD>
% Compatibility placeholder (kappa column name is resolved in caller via localNumericColumnName).
name = '';
end

function colName = localNumericColumnName(tbl, vn, candidates)
colName = '';
for i = 1:numel(candidates)
    if any(vn == candidates(i))
        colName = candidates(i);
        return
    end
end
% Fallback: use first column if kappa table is single-column temperature.
colName = vn(1);
end

function kappaSel = localLookupKappaAtT(kn, kappaTbl, kappaVals, tempsSel)
% kn is unused except for robust interface; keep for consistency.
 %#ok<INUSD>
vn = string(kappaTbl.Properties.VariableNames);
if any(vn == "T_K")
    Tcol = "T_K";
elseif any(vn == "T")
    Tcol = "T";
else
    % If temperature column is not named, assume first variable is T.
    Tcol = vn(1);
end
Tref = double(kappaTbl.(Tcol)(:));

kappaSel = NaN(numel(tempsSel), 1);
for i = 1:numel(tempsSel)
    d = abs(Tref(:) - tempsSel(i));
    [md, ix] = min(d, [], 'omitnan');
    if isfinite(md) && md < 0.51
        kappaSel(i) = kappaVals(ix);
    end
end
end

function basis = localBuildPTRestrictedBasis(ptData, tempsSel, cfg)
% Build restricted PT-only basis on ptData.currents grid.
% Output: struct array with fields {id, vec}.

currPT = ptData.currents(:);
tempsSel = tempsSel(:);

% Build normalized PT densities for scenario temps:
Pn = localBuildNormalizedPTDensities(ptData, tempsSel, currPT);
mRows = isfinite(Pn(:, 1));
Pn = Pn(mRows, :);
Tvalid = tempsSel(mRows);

if size(Pn, 1) < cfg.minRowsForBasis
    error('Too few valid PT rows for PT-restricted basis (got %d).', size(Pn, 1));
end

% 1) PT mean:
vMean = mean(Pn, 1, 'omitnan');
vMean = localNormalizeVectorOnGrid(currPT, vMean(:));

% 2) Centered PT -> PCA/SVD modes:
Pcent = Pn - vMean(:).';
[~, ~, V] = svd(Pcent, 'econ');
nPca = min(cfg.nPcaModes, size(V, 2));
psiPca = cell(1, nPca);
for k = 1:nPca
    psiPca{k} = localNormalizeVectorOnGrid(currPT, V(:, k));
end

% 3) dPT/dT:
% Derivative along the scenario temperature ordering:
[Dpt, ~] = localFiniteDiffAlongT(Tvalid, Pn);
vD = median(Dpt, 1, 'omitnan');
vD = localNormalizeVectorOnGrid(currPT, vD(:));

% 4) PT-derived moment directions (median central-moment weights):
moment1 = NaN(size(Pn, 2), 1);
moment2 = NaN(size(Pn, 2), 1);

nValid = size(Pn, 1);
M1 = NaN(nValid, numel(currPT));
M2 = NaN(nValid, numel(currPT));

for it = 1:nValid
    p = Pn(it, :).';
    m = isfinite(p);
    if nnz(m) < 10
        continue
    end
    I = currPT(m);
    pv = p(m);
    mu = trapz(I, pv .* I);
    v2 = trapz(I, pv .* (I - mu).^2);
    m1v = (currPT - mu) .* p; %#ok<NBRAK> (pv extended to full with NaNs)
    m2v = ((currPT - mu).^2 - v2) .* p;
    M1(it, :) = m1v.';
    M2(it, :) = m2v.';
end
moment1 = median(M1, 1, 'omitnan').';
moment2 = median(M2, 1, 'omitnan').';
moment1 = localNormalizeVectorOnGrid(currPT, moment1);
moment2 = localNormalizeVectorOnGrid(currPT, moment2);

% Compose basis:
basis = struct('id', {}, 'vec', {});

basis(end+1) = struct('id', 'pt_mean', 'vec', vMean); %#ok<AGROW>
for k = 1:numel(psiPca)
    basis(end+1) = struct('id', sprintf('pt_pca_mode_%d', k), 'vec', psiPca{k}); %#ok<AGROW>
end
basis(end+1) = struct('id', 'pt_dpdT_mean', 'vec', vD); %#ok<AGROW>

if cfg.nMomentDirs >= 1
    basis(end+1) = struct('id', 'pt_moment_dir_1', 'vec', moment1); %#ok<AGROW>
end
if cfg.nMomentDirs >= 2
    basis(end+1) = struct('id', 'pt_moment_dir_2', 'vec', moment2); %#ok<AGROW>
end
end

function Pn = localBuildNormalizedPTDensities(ptData, tempsSel, currPT)
nT = numel(tempsSel);
nI = numel(currPT);
Pn = NaN(nT, nI);
for it = 1:nT
    p = localNormDensityOnCurrents(ptData, tempsSel(it), currPT);
    if isempty(p)
        continue
    end
    Pn(it, :) = p(:).';
end
end

function [Dpt, Tmid] = localFiniteDiffAlongT(temps, Pn) %#ok<INUSD>
% Central difference derivative d/dT for each current column.
temps = temps(:);
nT = numel(temps);
nI = size(Pn, 2);
Dpt = NaN(nT, nI);

if nT < 2
    Tmid = temps;
    return
end

for it = 1:nT
    if it == 1
        dt = temps(2) - temps(1);
        if dt ~= 0
            Dpt(it, :) = (Pn(2, :) - Pn(1, :)) ./ dt;
        end
    elseif it == nT
        dt = temps(end) - temps(end-1);
        if dt ~= 0
            Dpt(it, :) = (Pn(end, :) - Pn(end-1, :)) ./ dt;
        end
    else
        den = temps(it+1) - temps(it-1);
        if den ~= 0
            Dpt(it, :) = (Pn(it+1, :) - Pn(it-1, :)) ./ den;
        end
    end
end
Tmid = temps;
end

function vN = localNormalizeVectorOnGrid(grid, v)
grid = grid(:);
v = v(:);
m = isfinite(v) & isfinite(grid);
if nnz(m) < 3
    vN = NaN(size(v));
    return
end
nv = sqrt(trapz(grid(m), v(m) .^ 2));
if ~(isfinite(nv) && nv > 0)
    vN = NaN(size(v));
    return
end
vN = v ./ nv;
end

function psiBasis = localInducePsiFromPTBasis(ptData, tempsSel, currents, SpeakSel, ScdfSel, ...
    XrowsSel, xGrid, phiEmp, basis, eps0)
% For each PT perturbation basis vector, push through CDF (linearized deltaS)
% and extract induced x-kernel via leading right singular vector.

nB = numel(basis);
nX = numel(xGrid);
psiBasis = struct('basis_id', {}, 'psi', {}, 'corr_phi_psi', {}, 'rmse_phi_psi', {});

% Keep only finite phi support for correlation consistency:
phiEmp = localNormalizePhiToMaxAbs(phiEmp(:));
mPhi = isfinite(phiEmp);

for bi = 1:nB
    bvec = basis(bi).vec(:);
    if all(~isfinite(bvec))
        continue
    end
    bvec(~isfinite(bvec)) = 0;
    if all(abs(bvec) <= eps)
        continue
    end

    % Interpolate deltaP direction to switching current grid:
    dOnCurr = interp1(ptData.currents(:), bvec, currents(:), 'linear', 0);
    dOnCurr = dOnCurr(:);
    % Normalize deltaP direction in switching currents:
    dOnCurr = localNormalizeVectorOnGrid(currents(:), dOnCurr);
    if all(~isfinite(dOnCurr))
        continue
    end

    R_I = localLinearizedDeltaS(ptData, tempsSel(:), currents(:), SpeakSel(:), ScdfSel, dOnCurr, eps0);
    Rx = localInterpolateRowsToGrid(XrowsSel, R_I, xGrid);

    % Leading mode in induced residual matrix:
    [psi, ~] = localLeadingModeFromResidual(Rx);

    % Sign align:
    ms = isfinite(psi) & mPhi;
    if nnz(ms) >= 3
        if dot(psi(ms), phiEmp(ms)) < 0
            psi = -psi;
        end
    end

    % Metrics against empirical Phi:
    corrVal = NaN;
    rmseVal = NaN;
    if nnz(ms) >= 3
        corrVal = corr(phiEmp(ms), psi(ms), 'Rows', 'complete');
        rmseVal = sqrt(mean((phiEmp(ms) - psi(ms)).^ 2, 'omitnan'));
    end

    psiBasis(end+1) = struct( ... %#ok<AGROW>
        'basis_id', basis(bi).id, ...
        'psi', psi, ...
        'corr_phi_psi', corrVal, ...
        'rmse_phi_psi', rmseVal);
end
end

function R_I = localLinearizedDeltaS(ptData, temps, currents, Speak, Scdf, dOnCurr, eps0)
nT = numel(temps);
nI = numel(currents);
R_I = NaN(nT, nI);

for it = 1:nT
    p0 = localNormDensityOnCurrents(ptData, temps(it), currents);
    if isempty(p0)
        continue
    end
    p1 = max(p0(:) + eps0 * dOnCurr(:), 0);
    a = trapz(currents, p1);
    if ~(isfinite(a) && a > 0)
        continue
    end
    p1 = p1 ./ a;

    cdf1 = cumtrapz(currents, p1);
    if cdf1(end) <= 0
        continue
    end
    cdf1 = cdf1 ./ cdf1(end);
    cdf1 = min(max(cdf1, 0), 1);
    S1 = Speak(it) .* cdf1(:).';
    R_I(it, :) = (S1 - Scdf(it, :)) ./ eps0;
end
end

function [psi, sv] = localLeadingModeFromResidual(Rlow)
R0 = double(Rlow);
R0(~isfinite(R0)) = 0;
[~, S, V] = svd(R0, 'econ');
sv = diag(S);
psi = V(:, 1);
scale = max(abs(psi), [], 'omitnan');
if ~(isfinite(scale) && scale > 0)
    scale = 1;
end
psi = psi ./ scale;
end

function reconRes = localReconstructPhiFromPsiModes(phiEmp, Rsel_x, kappaSel, psiBasis, maxReconModes)
% Build reconstruction using span of induced x-kernels.

phiEmp = localNormalizePhiToMaxAbs(phiEmp(:));
nX = numel(phiEmp);
phiMask = isfinite(phiEmp);

% Convert struct basis list into Psi matrix:
nB = numel(psiBasis);
Psi = NaN(nX, nB);
corrVals = NaN(1, nB);

for bi = 1:nB
    Psi(:, bi) = psiBasis(bi).psi(:);
    corrVals(bi) = psiBasis(bi).corr_phi_psi;
end

maskAll = phiMask & all(isfinite(Psi), 2);
% If too strict, fall back to phi finite support only:
if nnz(maskAll) < 10
    maskAll = phiMask;
end

Psi_v = Psi(maskAll, :);
phi_v = phiEmp(maskAll);

% Sort candidate modes by their individual L2 projection energy:
% (psi columns are not guaranteed orthonormal, but the subspace span is what matters)
phiNorm2 = sum(phi_v .^ 2, 'omitnan');
projEnergy = NaN(1, nB);
for bi = 1:nB
    v = Psi_v(:, bi);
    m = isfinite(v) & isfinite(phi_v);
    if nnz(m) < 3
        projEnergy(bi) = NaN;
    else
        % psi is already scaled (max abs = 1), so use L2 energy of raw projection:
        projEnergy(bi) = (dot(phi_v(m), v(m)) .^ 2) / max(phiNorm2, eps);
    end
end

[~, order] = sort(projEnergy, 'descend', 'MissingPlacement', 'last');
order = order(:).';

maxReconModes = min(maxReconModes, nB);

% Baseline residual RMSE with kappa*Phi:
kappaSel = kappaSel(:);
Ractual = Rsel_x; % already masked rows in x grid
Ractual = double(Ractual);
RhatBase = kappaSel(:) .* phiEmp(:).';
rmseBaseline = sqrt(mean((Ractual(:) - RhatBase(:)) .^ 2, 'omitnan'));
rmseBaseline = max(rmseBaseline, 1e-15);

rows = cell(maxReconModes, 1);
reconPhi_by_m = NaN(nX, maxReconModes);
for m = 1:maxReconModes
    idxModes = order(1:m);
    Psi_m = Psi_v(:, idxModes);

    % Orthonormalize on finite mask:
    [Q, ~] = qr(Psi_m, 0);
    if isempty(Q)
        reconPhi_by_m(:, m) = NaN;
        rows{m} = table( ...
            m, NaN, NaN, NaN, NaN, ...
            'VariableNames', {'n_modes_used', 'variance_explained_phi', ...
            'corr_phi_reconstruction', 'rmse_phi', ...
            'rmse_ratio_residual_to_kappaPhi'});
        continue
    end
    proj = Q * (Q' * phi_v);
    recon_v = proj;

    % Metrics in phi space:
    corrVal = NaN;
    if nnz(isfinite(recon_v)) >= 3
        corrVal = corr(phi_v, recon_v, 'Rows', 'complete');
    end
    rmsePhi = sqrt(mean((phi_v - recon_v) .^ 2, 'omitnan'));
    varianceExpl = (norm(proj) ^ 2) / max(norm(phi_v) ^ 2, eps);

    % Residual RMSE ratio:
    reconPhi = NaN(nX, 1);
    reconPhi(maskAll) = recon_v;
    reconPhi_by_m(:, m) = reconPhi;
    RhatPred = kappaSel(:) .* reconPhi(:).';
    rmsePred = sqrt(mean((Ractual(:) - RhatPred(:)) .^ 2, 'omitnan'));
    rmseRatio = rmsePred / rmseBaseline;

    rows{m} = table( ...
        m, varianceExpl, corrVal, rmsePhi, rmseRatio, ...
        'VariableNames', {'n_modes_used', 'variance_explained_phi', ...
        'corr_phi_reconstruction', 'rmse_phi', ...
        'rmse_ratio_residual_to_kappaPhi'});
end

reconRes.table = vertcat(rows{:});
reconRes.reconPhi_by_m = reconPhi_by_m;
end

function res = localLocalPTTangentTest(ptData, tempsSel, currents, SpeakSel, ScdfSel, ...
    XrowsSel, xGrid, phiEmp, kappaSel, Rsel_x, cfg)
% Build local PT tangent dP/dT from PT-only data (with neighboring T finite differences),
% push through CDF -> induced residual curve, then compare at each temperature.

phiEmp = localNormalizePhiToMaxAbs(phiEmp(:));
tempsSel = tempsSel(:);
kappaSel = kappaSel(:);
Ractual = double(Rsel_x);
nT = numel(tempsSel);

ptCurr = ptData.currents(:);

% Normalized PT densities on PT current grid for the scenario temperatures:
PnPT = localBuildNormalizedPTDensitiesStandalone(ptData, tempsSel, ptCurr);
goodRow = isfinite(PnPT(:, 1));
PnPT = PnPT(goodRow, :);
tempsGood = tempsSel(goodRow);
ScdfGood = ScdfSel(goodRow, :);
SpeakGood = SpeakSel(goodRow);
XrowsGood = XrowsSel(goodRow, :);
kappaGood = kappaSel(goodRow);
RactualGood = Ractual(goodRow, :);

nGood = numel(tempsGood);
if nGood < 3
    res.table = table();
    return
end

% Local tangent vectors:
[DPT, ~] = localFiniteDiffAlongT(tempsGood, PnPT);

% Predicted deltaS curves in current space:
nI = numel(currents);
Rpred_I = NaN(nGood, nI);
for it = 1:nGood
    dVecPT = DPT(it, :).';
    dVecPT = localNormalizeVectorOnGrid(ptCurr, dVecPT);
    if all(~isfinite(dVecPT))
        continue
    end
    dOnCurr = interp1(ptCurr, dVecPT, currents(:), 'linear', 0);
    dOnCurr = dOnCurr(:);
    dOnCurr = localNormalizeVectorOnGrid(currents(:), dOnCurr);
    if all(~isfinite(dOnCurr))
        continue
    end

    p0 = localNormDensityOnCurrents(ptData, tempsGood(it), currents);
    if isempty(p0)
        continue
    end
    p1 = max(p0(:) + cfg.finiteDiffEpsilon * dOnCurr(:), 0);
    a = trapz(currents, p1);
    if ~(isfinite(a) && a > 0)
        continue
    end
    p1 = p1 ./ a;
    cdf1 = cumtrapz(currents, p1);
    if cdf1(end) <= 0
        continue
    end
    cdf1 = cdf1 ./ cdf1(end);
    cdf1 = min(max(cdf1, 0), 1);
    S1 = SpeakGood(it) .* cdf1(:).';
    Rpred_I(it, :) = (S1 - ScdfGood(it, :)) ./ cfg.finiteDiffEpsilon;
end

% Predicted curves in x-grid:
Rpred_x = localInterpolateRowsToGrid(XrowsGood, Rpred_I, xGrid);

% Compare per temperature:
rows = {};
for it = 1:nGood
    pred = Rpred_x(it, :).';
    actual = RactualGood(it, :).';
    base = kappaGood(it) * phiEmp(:);

    m = isfinite(pred) & isfinite(actual) & isfinite(base) & isfinite(phiEmp);
    if nnz(m) < 10
        continue
    end

    % Sign align:
    if dot(pred(m), actual(m)) < 0
        pred = -pred;
    end

    % Optional amplitude scaling (best scalar fit) for local curve comparison:
    denom = sum(pred(m) .^ 2, 'omitnan');
    if denom <= cfg.epsFloor
        aScale = NaN;
    else
        aScale = sum(pred(m) .* actual(m), 'omitnan') ./ denom;
    end
    predScaled = pred .* aScale;

    % Correlations:
    cPredActual = corr(actual(m), predScaled(m), 'Rows', 'complete');
    cPredBase = corr(base(m), predScaled(m), 'Rows', 'complete');

    % RMSE ratio vs kappa*Phi baseline at the same T:
    rmsePredActual = sqrt(mean((actual(m) - predScaled(m)) .^ 2, 'omitnan'));
    rmseBaseActual = sqrt(mean((actual(m) - base(m)) .^ 2, 'omitnan'));
    rmseRatio = rmsePredActual / max(rmseBaseActual, cfg.epsFloor);

    rows{end+1, 1} = table( ...
        tempsGood(it), aScale, cPredActual, rmsePredActual, ...
        rmseBaseActual, rmseRatio, cPredBase, ...
        'VariableNames', {'T_K', 'tangent_scale_factor', ...
        'corr_pred_vs_deltaS', 'rmse_pred_vs_deltaS', ...
        'rmse_kappaPhi_vs_deltaS', 'rmse_ratio_pred_vs_kappaPhi', ...
        'corr_pred_vs_kappaPhi'}); %#ok<AGROW>
end

if isempty(rows)
    res.table = table();
else
    res.table = vertcat(rows{:});
end
end

function PnPT = localBuildNormalizedPTDensitiesStandalone(ptData, tempsSel, ptCurr)
nT = numel(tempsSel);
nI = numel(ptCurr);
PnPT = NaN(nT, nI);
for it = 1:nT
    p = localNormDensityOnCurrents(ptData, tempsSel(it), ptCurr);
    if isempty(p)
        continue
    end
    PnPT(it, :) = p(:).';
end
end

function [figPaths, figPick] = localMakeFigures(runDir, reconSummaryTbl, xGrid, phiEmp, reconPhiBest, bestNBest)
figPaths = struct('phi', [], 'var', []);
reconPhi = reconPhiBest(:);
bestN = bestNBest;

% Figure 1: phi vs reconstruction
baseName = 'phi_vs_pt_reconstruction';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 14 10]);
ax = axes(fig);
plot(ax, xGrid, phiEmp, '-', 'LineWidth', 2.8, 'Color', [0 0.45 0.74], 'DisplayName', '\Phi(x) empirical');
hold(ax, 'on');
plot(ax, xGrid, reconPhi, '--', 'LineWidth', 2.2, 'Color', [0.85 0.33 0.1], 'DisplayName', sprintf('PT-only restricted recon (n=%d)', bestN));
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'x = (I - I_{peak}) / w (1)');
ylabel(ax, '\Phi(x) (arb. units)');
legend(ax, 'Location', 'best', 'Box', 'off');
title(ax, 'Empirical \Phi vs PT-only restricted reconstruction');
styleAxes(ax);
figPaths.phi = save_run_figure(fig, baseName, runDir);
close(fig);

% Figure 2: variance explained vs modes
baseName2 = 'variance_explained_vs_modes';
fig2 = create_figure('Name', baseName2, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 14 10]);
ax2 = axes(fig2);
hold(ax2, 'on');

for eachScen in ["exclude_22K", "all_lowT"]
    sub2 = reconSummaryTbl(reconSummaryTbl.scenario == eachScen, :);
    if isempty(sub2)
        continue
    end
    [~, ord] = sort(sub2.n_modes_used, 'ascend');
    sub2 = sub2(ord, :);
    plot(ax2, sub2.n_modes_used, sub2.variance_explained_phi, 'o-', ...
        'LineWidth', 2.2, 'DisplayName', char(eachScen));
end
hold(ax2, 'off');
grid(ax2, 'on');
xlabel(ax2, 'Number of PT-only restricted modes used');
ylabel(ax2, 'Variance explained by PT-only span');
legend(ax2, 'Location', 'best', 'Box', 'off');
title(ax2, '\Phi variance explained vs PT-only restricted modes');
styleAxes(ax2);
figPaths.var = save_run_figure(fig2, baseName2, runDir);
close(fig2);

figPick = struct('bestN_exclude_22K', bestN);
end

function styleAxes(ax)
set(ax, 'FontName', 'Helvetica', 'FontSize', 14, 'LineWidth', 1.0, ...
    'TickDir', 'out', 'Box', 'off', 'Layer', 'top', ...
    'XMinorTick', 'off', 'YMinorTick', 'off');
end

function [globalVerdict, localVerdict, phiModeVerdict, verdictText] = localComputeVerdicts(bestAll, bestNo22K, localTangentTbl, cfg)
% Decide global/local support. Thresholds are intentionally moderate.
%
% Global:
% - YES if best correlation >= 0.80 AND rmse_ratio <= 1.8
% - PARTIAL if best correlation >= 0.65 OR rmse_ratio <= 2.8
% - else NO
%
% Local:
% - YES if median corr_pred_vs_deltaS >= 0.70 and rmse_ratio median <= 2.0 (exclude_22K scenario)
% - PARTIAL if median corr >= 0.55 and rmse_ratio <= 3.0
% - else NO
%
% PHI_AS_PT_ONLY_MODE:
% - SUPPORTED if GLOBAL==YES
% - PARTIALLY_SUPPORTED if GLOBAL==PARTIAL
% - NOT_SUPPORTED otherwise

if bestNo22K.bestCorr >= 0.80 && bestNo22K.bestRmseRatio <= 1.8
    globalVerdict = "YES";
elseif bestNo22K.bestCorr >= 0.65 && bestNo22K.bestRmseRatio <= 2.8
    globalVerdict = "PARTIAL";
else
    globalVerdict = "NO";
end

sub = localTangentTbl(localTangentTbl.scenario == "exclude_22K", :);
if isempty(sub)
    sub = localTangentTbl(localTangentTbl.scenario == "all_lowT", :);
end
medianCorr = NaN;
medianRmseRatio = NaN;
if ~isempty(sub) && any(isfinite(sub.corr_pred_vs_deltaS))
    medianCorr = median(sub.corr_pred_vs_deltaS, 'omitnan');
end
if ~isempty(sub) && any(isfinite(sub.rmse_ratio_pred_vs_kappaPhi))
    medianRmseRatio = median(sub.rmse_ratio_pred_vs_kappaPhi, 'omitnan');
end

if isfinite(medianCorr) && isfinite(medianRmseRatio)
    if medianCorr >= 0.70 && medianRmseRatio <= 2.0
        localVerdict = "YES";
    elseif medianCorr >= 0.55 && medianRmseRatio <= 3.0
        localVerdict = "PARTIAL";
    else
        localVerdict = "NO";
    end
else
    localVerdict = "NO";
end

if globalVerdict == "YES"
    phiModeVerdict = "SUPPORTED";
elseif globalVerdict == "PARTIAL"
    phiModeVerdict = "PARTIALLY_SUPPORTED";
else
    phiModeVerdict = "NOT_SUPPORTED";
end

verdictText = sprintf('exclude_22K bestCorr=%.4f bestRmseRatio=%.4g | local median corr=%.3f median rmse_ratio=%.3f', ...
    bestNo22K.bestCorr, bestNo22K.bestRmseRatio, medianCorr, medianRmseRatio);
end

function reportText = localBuildReport(cfg, decTablesDir, ptPath, alignId, scaleId, runDir, ...
    xGrid, phiPath, kappaPath, Scdf, cdfMeta, reconSummaryTbl, localTangentTbl, ...
    bestAll, bestNo22K, figPaths, phiSummaryPath, phiLocalPath, ...
    globalVerdict, localVerdict, phiModeVerdict, verdictText)

% Basic report; keep it informative and aligned to repository style.
lines = strings(0, 1);
lines(end+1) = "# Phi PT-only restricted deformation report";
lines(end+1) = "";
lines(end+1) = "## Goal";
lines(end+1) = "Determine whether the empirical universal residual shape \Phi(x) can be reconstructed using a PT-only restricted basis (no arbitrary kernels), and test whether the same PT-only structure also appears in a local PT tangent response.";
lines(end+1) = "";
lines(end+1) = "## Inputs (read-only)";
lines(end+1) = sprintf("- Decomposition tables: `%s`", char(decTablesDir));
lines(end+1) = sprintf("- `phi_shape.csv`: `%s`", char(phiPath));
lines(end+1) = sprintf("- `kappa_vs_T.csv`: `%s`", char(kappaPath));
lines(end+1) = sprintf("- `PT_matrix.csv`: `%s`", char(ptPath));
lines(end+1) = sprintf("- Alignment run: `%s` | scaling run: `%s`", char(alignId), char(scaleId));
lines(end+1) = "";

lines(end+1) = "## Method (restricted basis + CDF pushforward)";
lines(end+1) = "- Low-T subset: `T <= canonicalMaxTemperatureK = " + string(cfg.canonicalMaxTemperatureK) + " K`.";
lines(end+1) = "- Exclude-22K band: `abs(T-22K) <= " + string(cfg.exclude22KBand) + " K`.";
lines(end+1) = "";
lines(end+1) = "### PT-only basis vectors (on PT current grid)";
lines(end+1) = "- `pt_mean`: mean normalized PT density over the selected low-T subset.";
lines(end+1) = "- `pt_pca_mode_{1..n}`: PCA/SVD right-singular vectors of centered PT densities (centered before SVD).";
lines(end+1) = "- `pt_dpdT_mean`: mean of the PT density derivative `dP_T/dT` computed via finite differences on PT-only data.";
lines(end+1) = "- `pt_moment_dir_1` and `pt_moment_dir_2`: median first/second central-moment weight directions of the PT density.";
lines(end+1) = "";
lines(end+1) = "### Push through CDF -> switching residual x-space";
lines(end+1) = "- Construct PT-backed CDF rows on the alignment currents grid and build `S_CDF(I,T)=S_peak(T)*CDF(P_T)(I)`.";
lines(end+1) = "- Apply a linearized PT perturbation response: `p1 = normalize(max(p0 + eps * dP, 0))`, `deltaS = (S_peak*CDF(p1)-S_CDF)/eps`.";
lines(end+1) = "- Map `deltaS(I,T)` to the decomposition coordinate `x=(I-I_peak)/w` and interpolate onto the saved `phi_shape.csv` x-grid.";
lines(end+1) = "";
lines(end+1) = "### Reconstruction and metrics";
lines(end+1) = "- For each PT perturbation basis direction, extract an induced x-kernel via the leading right singular vector of the induced residual stack in the selected low-T subset.";
lines(end+1) = "- Single-mode: best induced kernel alone.";
lines(end+1) = "- Multi-mode: least-squares projection of \Phi(x) onto the PT-induced span using the first `n` ranked modes; report correlation, \f$RMSE\f$, and variance explained in \Phi space, plus residual RMSE ratio relative to `kappa(T)*Phi(x)` baseline.";
lines(end+1) = "";

lines(end+1) = "## Outputs";
lines(end+1) = "- Tables:";
lines(end+1) = sprintf("  - `%s`", char(phiSummaryPath));
lines(end+1) = sprintf("  - `%s`", char(phiLocalPath));
lines(end+1) = "- Figures:";
if isstruct(figPaths)
    if isfield(figPaths, 'phi') && isfield(figPaths.phi, 'png')
        lines(end+1) = sprintf("  - `%s`", char(figPaths.phi.png));
    else
        lines(end+1) = "- `figures/phi_vs_pt_reconstruction.png`";
    end
    if isfield(figPaths, 'var') && isfield(figPaths.var, 'png')
        lines(end+1) = sprintf("  - `%s`", char(figPaths.var.png));
    else
        lines(end+1) = "- `figures/variance_explained_vs_modes.png`";
    end
end
lines(end+1) = "";

lines(end+1) = "## Key reconstruction numbers (exclude-22K)";
maskNo22 = reconSummaryTbl.scenario == "exclude_22K";
subNo22 = reconSummaryTbl(maskNo22, :);
if ~isempty(subNo22)
    [~, ix] = max(abs(subNo22.corr_phi_reconstruction));
    bestCorr = subNo22.corr_phi_reconstruction(ix);
    bestRmseRatio = subNo22.rmse_ratio_residual_to_kappaPhi(ix);
    bestN = subNo22.n_modes_used(ix);
    lines(end+1) = sprintf("- Best correlation: %.4f (n_modes=%d)", bestCorr, bestN);
    lines(end+1) = sprintf("- RMSE ratio to kappa*Phi baseline: %.4g", bestRmseRatio);
else
    lines(end+1) = "- No reconstruction rows found for exclude_22K (unexpected).";
end
lines(end+1) = sprintf("- Remove 22K effect: corr %.4f -> %.4f ; rmse_ratio %.4g -> %.4g", ...
    bestAll.bestCorr, bestNo22K.bestCorr, bestAll.bestRmseRatio, bestNo22K.bestRmseRatio);
lines(end+1) = "";

lines(end+1) = "## Verdicts";
lines(end+1) = "- GLOBAL_PT_DEFORMATION: **" + globalVerdict + "**";
lines(end+1) = "- LOCAL_PT_DEFORMATION: **" + localVerdict + "**";
lines(end+1) = "- PHI_AS_PT_ONLY_MODE: **" + phiModeVerdict + "**";
lines(end+1) = "";
lines(end+1) = "Verdict rationale: " + verdictText;
lines(end+1) = "";

lines(end+1) = "## Visualization choices";
lines(end+1) = "- Number of curves: <=2 lines per figure for reconstruction/mode span.";
lines(end+1) = "- Legend vs colormap: explicit legends (curves <= 6).";
lines(end+1) = "- Colormap used: none (line colors only).";
lines(end+1) = "- Smoothing applied: none (variance and reconstruction are algebraic projections).";
lines(end+1) = "- Justification: figures directly target the requested reconstruction correlation and the variance-vs-mode saturation curve.";
lines(end+1) = "";

lines(end+1) = "## Run folder";
lines(end+1) = "- `" + runDir + "`";
lines(end+1) = "";

% Minimal sanity line to ensure report doesn't omit context:
lines(end+1) = "Implementation check: PT-backed CDF rows used in CDF model: " + string(cdfMeta.ptRowsUsed) + " / " + string(cdfMeta.ptRowsUsed + cdfMeta.fallbackRowsUsed) + ".";

reportText = strjoin(lines, newline);
end

function zipPath = localBuildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', ...
    'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
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

function out = localStampNow()
out = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

