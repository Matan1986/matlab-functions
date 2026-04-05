function out = run_phi_temperature_derivative_test(cfg)
% run_phi_temperature_derivative_test
% Mechanism test: compare empirical residual mode Phi(x) to the leading x-mode of
% d/dT [ S_peak(T) * CDF(P_T)(I) ], mapped to x = (I - I_peak) / w and stacked over T.
%
% Consumes existing decomposition tables (phi_shape, kappa_vs_T, optional sources manifest),
% PT_matrix, alignment map, and full-scaling parameters. Does not modify source runs.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

analysisDir = fileparts(mfilename('fullpath'));
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = applyDefaults(cfg);

decTablesDir = resolveDecompositionTablesDir(repoRoot, cfg.decompositionRunId);
phiPath = fullfile(decTablesDir, 'phi_shape.csv');
kappaPath = fullfile(decTablesDir, 'kappa_vs_T.csv');
srcPath = fullfile(decTablesDir, 'residual_decomposition_sources.csv');

assert(exist(phiPath, 'file') == 2, 'Missing phi_shape.csv: %s', phiPath);
assert(exist(kappaPath, 'file') == 2, 'Missing kappa_vs_T.csv: %s', kappaPath);

phiTbl = readtable(phiPath);
xGrid = double(phiTbl.x(:));
phiEmp = double(phiTbl.Phi(:));

kappaTbl = readtable(kappaPath);
kn = string(kappaTbl.Properties.VariableNames);
kappaTcol = localNumericColumn(kappaTbl, kn, ["T", "T_K"]);
kappaVals = double(kappaTbl.kappa(:));

runDataset = sprintf('phi_dT_cdf_test | decomp:%s', cfg.decompositionRunId);
run = createSwitchingRunContext(repoRoot, struct('runLabel', cfg.runLabel, 'dataset', runDataset));
runDir = run.run_dir;

fprintf('Phi temperature-derivative test run directory:\n%s\n', runDir);
fprintf('Decomposition source run: %s\n', char(cfg.decompositionRunId));

appendText(run.log_path, sprintf('[%s] run_phi_temperature_derivative_test started\n', stampNow()));
appendText(run.log_path, sprintf('decomposition_run: %s\n', char(cfg.decompositionRunId)));

[ptPath, alignId, scaleId] = resolvePathsFromSourcesOrCfg(repoRoot, srcPath, cfg);
appendText(run.log_path, sprintf('PT_matrix: %s\n', char(ptPath)));
appendText(run.log_path, sprintf('alignment_run: %s | scaling_run: %s\n', char(alignId), char(scaleId)));

slice = loadAlignmentScalingSlice(repoRoot, alignId, scaleId, ptPath);
Smap = slice.Smap;
temps = slice.temps;
currents = slice.currents;
Ipeak = slice.Ipeak;
Speak = slice.Speak;
width = slice.width;
ptData = slice.ptData;

[Scdf, cdfMeta] = buildScdfMatrix(Smap, currents, temps, Speak, ptData, cfg.fallbackSmoothWindow);
assert(cdfMeta.ptRowsUsed > 0, 'PT_matrix produced no CDF rows; this test requires PT-backed CDF(P_T).');

monoTbl = cdfMonotonicityTable(Scdf ./ max(Speak, eps), currents);
save_run_table(monoTbl, 'Scdf_over_Speak_monotonicity.csv', runDir);

dScdf_dT_raw = temperatureDerivativeNonuniform(temps, Scdf);
dScdf_dT_smooth = smoothDerivativeAlongT(dScdf_dT_raw, cfg.sgolayWindow);

tiny = max(1e-12, 1e-6 * max(Scdf, [], 'all', 'omitnan'));
logScdf = log(max(Scdf, tiny));
dLogScdf_dT_raw = temperatureDerivativeNonuniform(temps, logScdf);
dLogScdf_dT_smooth = smoothDerivativeAlongT(dLogScdf_dT_raw, cfg.sgolayWindow);

variantDefs = {
    'dScdf_dT_raw', dScdf_dT_raw
    'dScdf_dT_smooth', dScdf_dT_smooth
    'dLogScdf_dT_raw', dLogScdf_dT_raw
    'dLogScdf_dT_smooth', dLogScdf_dT_smooth
    };

stabilityScenarios = {
    'all_T', @(T) true(size(T))
    'exclude_22K_band', @(T) ~(T >= 21.5 & T <= 22.5)
    'T_14_to_30', @(T) (T >= 14) & (T <= 30)
    };

stabCell = {};
modeCell = {};
corrCell = {};

phiDtPrimary = [];
svPrimary = [];
primaryVariant = 'dScdf_dT_smooth';
primaryScenario = 'all_T';

for vi = 1:size(variantDefs, 1)
    vname = char(variantDefs{vi, 1});
    Dfull = variantDefs{vi, 2};

    for si = 1:size(stabilityScenarios, 1)
        scenName = char(stabilityScenarios{si, 1});
        scenFn = stabilityScenarios{si, 2};
        maskT = scenFn(temps);
        maskT = maskT(:) & isfinite(temps);
        if nnz(maskT) < cfg.minRowsSvd
            continue
        end

        tempsSub = temps(maskT);
        [tempsSub, ord] = sort(tempsSub);
        Dsub = Dfull(maskT, :);
        Dsub = Dsub(ord, :);
        Ip = Ipeak(maskT);
        Ip = Ip(ord);
        wv = width(maskT);
        wv = wv(ord);
        kSub = lookupKappaAtT(kappaTcol, kappaVals, tempsSub);

        [mets, phiDt, sv, aProj, nUsed] = evalPhiDtVsPhi( ...
            Dsub, currents, Ip, wv, tempsSub, xGrid, phiEmp);

        ampCorr = NaN;
        if nnz(isfinite(kSub) & isfinite(aProj)) >= 5
            ampCorr = corr(aProj(:), kSub(:), 'rows', 'pairwise');
        end

        stabCell(end+1, :) = {vname, scenName, nUsed, mets.pearson, mets.cosine, ...
            mets.overlap, mets.signConsistency, mets.rank1EnergyFrac, ampCorr, mets.flipSign}; %#ok<AGROW>

        if strcmp(vname, primaryVariant) && strcmp(scenName, primaryScenario)
            phiDtPrimary = phiDt;
            svPrimary = sv;
        end

        if strcmp(scenName, 'all_T') && (strcmp(vname, 'dScdf_dT_raw') || strcmp(vname, 'dScdf_dT_smooth'))
            modeCell(end+1, :) = {vname, mets.pearson, mets.cosine, mets.overlap, ...
                mets.signConsistency, sv(1), sv(min(2, numel(sv))), mets.rank1EnergyFrac, ampCorr}; %#ok<AGROW>
        end

        corrCell(end+1, :) = {vname, scenName, mets.pearson, mets.cosine, mets.overlap, mets.signConsistency, ampCorr}; %#ok<AGROW>
    end
end

if isempty(phiDtPrimary)
    % fall back to first available smooth all_T
    idx = strcmp(stabCell(:,1), 'dScdf_dT_smooth') & strcmp(stabCell(:,2), 'all_T');
    if any(idx)
        % recompute once
        maskT = true(size(temps));
        [tempsSub, ord] = sort(temps);
        Dsub = dScdf_dT_smooth(ord, :);
        [~, phiDtPrimary, svPrimary, ~, ~] = evalPhiDtVsPhi(Dsub, currents, ...
            Ipeak(ord), width(ord), tempsSub, xGrid, phiEmp);
    end
end

if isempty(stabCell)
    error('No stability rows computed; check inputs, temperature masks, and cfg.minRowsSvd.');
end

stabTbl = cell2table(stabCell, 'VariableNames', { ...
    'derivative_variant', 'temperature_window', 'n_temperature_rows', ...
    'pearson_phi_phiDt', 'cosine_phi_phiDt', 'overlap_integral_L2unit', ...
    'sign_consistency_fraction', 'rank1_energy_fraction', 'pearson_kappa_aProj', 'phiDt_sign_flip'});

modeTbl = cell2table(modeCell, 'VariableNames', { ...
    'derivative_variant', 'pearson', 'cosine', 'overlap_integral', ...
    'sign_consistency', 'sigma1', 'sigma2', 'rank1_energy_fraction', 'pearson_kappa_aProj'});

corrTbl = cell2table(corrCell, 'VariableNames', { ...
    'derivative_variant', 'temperature_window', 'pearson', 'cosine', ...
    'overlap_integral', 'sign_consistency', 'pearson_kappa_aProj'});

save_run_table(corrTbl, 'phi_vs_derivative_correlation.csv', runDir);
save_run_table(modeTbl, 'mode_comparison_metrics.csv', runDir);
save_run_table(stabTbl, 'temperature_stability_metrics.csv', runDir);

figPaths = struct();
figPaths.phi_vs_phiDt = makeFigPhiVsPhiDt(phiEmp, phiDtPrimary, runDir);
figPaths.modes_overlay = makeFigModesOverlay(xGrid, phiEmp, phiDtPrimary, runDir);
figPaths.singular_spectrum = makeFigSingularSpectrum(svPrimary, runDir);
figPaths.corr_vs_window = makeFigCorrVsWindow(stabTbl, runDir);

[verdict, verdictLine] = localVerdictFromTable(stabTbl);

reportLines = buildReportMarkdown(cfg, decTablesDir, ptPath, alignId, scaleId, ...
    cdfMeta, monoTbl, stabTbl, verdict, verdictLine);
reportPath = save_run_report(strjoin(reportLines, newline), 'phi_temperature_derivative_report.md', runDir);

zipPath = buildReviewZip(runDir, 'phi_temperature_derivative_bundle.zip');

appendText(run.notes_path, sprintf('Verdict: %s\n', verdict));
appendText(run.log_path, sprintf('[%s] complete | report: %s\n', stampNow(), char(reportPath)));

out = struct();
out.runDir = string(runDir);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.stabilityTable = stabTbl;
out.verdict = string(verdict);
out.figurePaths = figPaths;

fprintf('\n=== Phi temperature-derivative test complete ===\n');
fprintf('Verdict: %s\n', verdict);
fprintf('Report: %s\n', reportPath);
end

%% -------------------------------------------------------------------------
function decDir = resolveDecompositionTablesDir(repoRoot, runId)
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
error('Decomposition tables not found for run %s (tried standard and _extract_ layouts).', rid);
end

function cfg = applyDefaults(cfg)
cfg = setDef(cfg, 'runLabel', 'phi_temperature_derivative_test');
cfg = setDef(cfg, 'decompositionRunId', 'run_2026_03_24_220314_residual_decomposition');
cfg = setDef(cfg, 'alignmentRunId', '');
cfg = setDef(cfg, 'fullScalingRunId', '');
cfg = setDef(cfg, 'ptMatrixPath', '');
cfg = setDef(cfg, 'fallbackSmoothWindow', 5);
cfg = setDef(cfg, 'canonicalMaxTemperatureK', 30);
cfg = setDef(cfg, 'sgolayWindow', 5);
cfg = setDef(cfg, 'minRowsSvd', 5);
cfg = setDef(cfg, 'speakFloorFraction', 1e-3);
end

function cfg = setDef(cfg, f, v)
if ~isfield(cfg, f) || isempty(cfg.(f))
    cfg.(f) = v;
end
end

function [ptPath, alignId, scaleId] = resolvePathsFromSourcesOrCfg(repoRoot, srcPath, cfg)
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
                ptPath = string(char(st.(fileCol)(i)));
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

function slice = loadAlignmentScalingSlice(repoRoot, alignId, scaleId, ptPath)
source.alignmentRunDir = fullfile(switchingCanonicalRunRoot(repoRoot), char(alignId));
source.fullScalingRunDir = fullfile(switchingCanonicalRunRoot(repoRoot), char(scaleId));
source.alignmentCorePath = fullfile(source.alignmentRunDir, 'switching_alignment_core_data.mat');
source.fullScalingParamsPath = fullfile(source.fullScalingRunDir, 'tables', 'switching_full_scaling_parameters.csv');

assert(exist(source.alignmentCorePath, 'file') == 2, 'Missing %s', source.alignmentCorePath);
assert(exist(source.fullScalingParamsPath, 'file') == 2, 'Missing %s', source.fullScalingParamsPath);

core = load(source.alignmentCorePath, 'Smap', 'temps', 'currents');
paramsTbl = readtable(source.fullScalingParamsPath);
[SmapAll, tempsAll, currents] = orientAndSortMap(core.Smap, core.temps(:), core.currents(:));
[tempsScale, IpeakScale, SpeakScale, widthScale] = extractScalingColumns(paramsTbl);
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
slice.currents = currents;
slice.Ipeak = Ipeak(valid);
slice.Speak = Speak(valid);
slice.width = width(valid);
slice.ptData = loadPTData(char(ptPath));
end

function kOut = lookupKappaAtT(Tref, kappaVals, Tq)
kOut = NaN(size(Tq));
for i = 1:numel(Tq)
    d = abs(Tref(:) - Tq(i));
    [md, ix] = min(d, [], 'omitnan');
    if isfinite(md) && md < 0.51
        kOut(i) = kappaVals(ix);
    end
end
end

function [metrics, phiDt, singularValues, aProj, nRows] = evalPhiDtVsPhi( ...
    D_I, currents, Ipeak, width, temps, xGrid, phiEmp)

nRows = size(D_I, 1);
nX = numel(xGrid);
Dx = NaN(nRows, nX);

for it = 1:nRows
    xAtI = (currents(:) - Ipeak(it)) ./ width(it);
    y = D_I(it, :)';
    m = isfinite(xAtI) & isfinite(y);
    if nnz(m) < 3
        continue
    end
    xu = xAtI(m);
    yu = y(m);
    [xu, ord] = sort(xu);
    yu = yu(ord);
    [xu, iu] = unique(xu, 'stable');
    yu = yu(iu);
    Dx(it, :) = interp1(xu, yu, xGrid(:), 'linear', NaN).';
end

W = rowUnitL2Normalize(Dx);
W(~isfinite(W)) = 0;

[~, S, V] = svd(W, 'econ');
singularValues = diag(S);
phiRaw = V(:, 1);
flipSign = dot(phiRaw, phiEmp) < 0;
phiDt = phiRaw;
if flipSign
    phiDt = -phiDt;
end

aProj = NaN(nRows, 1);
phiN = phiEmp(:);
denPhi = sum(phiN .^ 2, 'omitnan');
for it = 1:nRows
    row = Dx(it, :)';
    m = isfinite(row) & isfinite(phiN);
    if nnz(m) < 3 || denPhi <= eps
        continue
    end
    aProj(it) = sum(row(m) .* phiN(m), 'omitnan') / denPhi;
end

m = isfinite(phiDt) & isfinite(phiEmp);
metrics.pearson = corr(phiEmp(m), phiDt(m));
p = phiEmp(m); q = phiDt(m);
metrics.cosine = dot(p, q) / (norm(p) * norm(q) + eps);
pn = p / (norm(p) + eps);
qn = q / (norm(q) + eps);
xm = xGrid(m);
[xs, ix] = sort(xm);
if numel(xs) < 2
    metrics.overlap = NaN;
else
    metrics.overlap = trapz(xs, pn(ix) .* qn(ix));
end
metrics.signConsistency = mean(sign(p) == sign(q) | p == 0 | q == 0);
metrics.rank1EnergyFrac = singularValues(1)^2 / max(sum(singularValues.^2), eps);
metrics.flipSign = double(flipSign);
end

function W = rowUnitL2Normalize(D)
W = NaN(size(D));
for i = 1:size(D, 1)
    r = D(i, :)';
    m = isfinite(r);
    if nnz(m) < 3
        continue
    end
    n = norm(r(m));
    if n > eps
        W(i, m) = (r(m) / n).';
    end
end
end

function D = temperatureDerivativeNonuniform(temps, F)
temps = temps(:);
D = NaN(size(F));
nT = numel(temps);
for it = 1:nT
    if it == 1 && nT >= 2
        dt = temps(2) - temps(1);
        if dt ~= 0
            D(it, :) = (F(2, :) - F(1, :)) / dt;
        end
    elseif it == nT && nT >= 2
        dt = temps(end) - temps(end - 1);
        if dt ~= 0
            D(it, :) = (F(end, :) - F(end - 1, :)) / dt;
        end
    else
        den = temps(it + 1) - temps(it - 1);
        if den ~= 0
            D(it, :) = (F(it + 1, :) - F(it - 1, :)) / den;
        end
    end
end
end

function Ds = smoothDerivativeAlongT(D, windowLen)
nT = size(D, 1);
wl = min(windowLen, nT);
if mod(wl, 2) == 0
    wl = wl - 1;
end
if wl < 3
    Ds = D;
    return
end
Ds = NaN(size(D));
for j = 1:size(D, 2)
    v = D(:, j);
    if all(~isfinite(v))
        continue
    end
    try
        Ds(:, j) = smoothdata(v, 'sgolay', wl);
    catch
        Ds(:, j) = smoothdata(v, 'movmean', min(3, nT));
    end
end
end

function [Scdf, meta] = buildScdfMatrix(Smap, currents, temps, Speak, ptData, fallbackSmoothWindow)
nT = numel(temps);
nI = numel(currents);
Scdf = NaN(nT, nI);
ptRows = 0;
fbRows = 0;
for it = 1:nT
    cdfRow = [];
    if ptData.available
        cdfRow = cdfFromPT(ptData, temps(it), currents);
    end
    if isempty(cdfRow)
        cdfRow = cdfFallbackFromRow(Smap(it, :), currents, fallbackSmoothWindow);
        fbRows = fbRows + 1;
    else
        ptRows = ptRows + 1;
    end
    Scdf(it, :) = Speak(it) .* cdfRow(:).';
end
meta = struct('ptRowsUsed', ptRows, 'fallbackRowsUsed', fbRows);
end

function tbl = cdfMonotonicityTable(Cnorm, currents)
nT = size(Cnorm, 1);
maxViol = NaN(nT, 1);
minVal = NaN(nT, 1);
maxVal = NaN(nT, 1);
for it = 1:nT
    c = Cnorm(it, :)';
    m = isfinite(c);
    if nnz(m) < 3
        continue
    end
    d = diff(c(m));
    maxViol(it) = max(0, max(-d, [], 'omitnan'));
    minVal(it) = min(c(m), [], 'omitnan');
    maxVal(it) = max(c(m), [], 'omitnan');
end
tbl = table((1:nT)', maxViol, minVal, maxVal, 'VariableNames', ...
    {'row_index', 'max_cdf_decrease', 'cdf_min', 'cdf_max'});
end

function ptData = loadPTData(ptMatrixPath)
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
    currents(j) = parseCurrentFromColumnName(currentCols(j));
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

function val = parseCurrentFromColumnName(name)
s = char(string(name));
s = regexprep(s, '^Ith_', '', 'ignorecase');
s = regexprep(s, '_mA$', '', 'ignorecase');
sDot = strrep(s, '_', '.');
val = str2double(sDot);
if isfinite(val)
    return
end
m = regexp(s, '[-+]?\d*\.?\d+', 'match', 'once');
if isempty(m)
    val = NaN;
else
    val = str2double(m);
end
end

function cdfRow = cdfFromPT(ptData, targetT, currents)
tempsPT = ptData.temps(:);
currPT = ptData.currents(:);
PT = ptData.PT;
if numel(tempsPT) < 2 || size(PT, 2) ~= numel(currPT)
    cdfRow = [];
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
    cdfRow = [];
    return
end
pAtT(~isfinite(pAtT)) = 0;
pAtT = max(pAtT, 0);
areaPT = trapz(currPT, pAtT);
if ~(isfinite(areaPT) && areaPT > 0)
    cdfRow = [];
    return
end
pAtT = pAtT ./ areaPT;
pOnCurrents = interp1(currPT, pAtT, currents(:), 'linear', 0);
pOnCurrents = max(pOnCurrents, 0);
area = trapz(currents, pOnCurrents);
if ~(isfinite(area) && area > 0)
    cdfRow = [];
    return
end
pOnCurrents = pOnCurrents ./ area;
cdfRow = cumtrapz(currents, pOnCurrents);
if cdfRow(end) <= 0
    cdfRow = [];
    return
end
cdfRow = cdfRow ./ cdfRow(end);
cdfRow = min(max(cdfRow, 0), 1);
end

function cdfRow = cdfFallbackFromRow(row, currents, smoothWindow)
row = double(row(:)');
currents = double(currents(:));
valid = isfinite(row) & isfinite(currents(:)');
if nnz(valid) < 3
    cdfRow = zeros(size(currents));
    return
end
r = row(valid);
I = currents(valid);
rMin = min(r, [], 'omitnan');
rMax = max(r, [], 'omitnan');
if ~(isfinite(rMin) && isfinite(rMax) && rMax > rMin)
    cdfRow = zeros(size(currents));
    return
end
rNorm = (r - rMin) ./ (rMax - rMin);
if smoothWindow >= 2
    rNorm = smoothdata(rNorm, 'movmean', min(smoothWindow, numel(rNorm)));
end
rNorm = enforceMonotoneNondecreasing(rNorm);
p = gradient(rNorm, I);
p = max(p, 0);
area = trapz(I, p);
if ~(isfinite(area) && area > 0)
    cdfRow = zeros(size(currents));
    return
end
p = p ./ area;
pFull = interp1(I, p, currents, 'linear', 0);
pFull = max(pFull, 0);
areaFull = trapz(currents, pFull);
if areaFull > 0
    pFull = pFull ./ areaFull;
end
cdfRow = cumtrapz(currents, pFull);
if cdfRow(end) > 0
    cdfRow = cdfRow ./ cdfRow(end);
end
cdfRow = min(max(cdfRow, 0), 1);
end

function y = enforceMonotoneNondecreasing(x)
y = x(:).';
for i = 2:numel(y)
    if y(i) < y(i - 1)
        y(i) = y(i - 1);
    end
end
if y(end) > 0
    y = y ./ y(end);
end
end

function [Smap, temps, currents] = orientAndSortMap(SmapIn, tempsIn, currentsIn)
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

function [temps, Ipeak, Speak, width] = extractScalingColumns(tbl)
varNames = string(tbl.Properties.VariableNames);
temps = numericColumn(tbl, varNames, ["T_K", "T"]);
Ipeak = numericColumn(tbl, varNames, ["Ipeak_mA", "I_peak", "Ipeak"]);
Speak = numericColumn(tbl, varNames, ["S_peak", "Speak", "Speak_peak"]);
width = numericColumn(tbl, varNames, ["width_chosen_mA", "width_I", "width"]);
[temps, ord] = sort(temps);
Ipeak = Ipeak(ord);
Speak = Speak(ord);
width = width(ord);
end

function col = numericColumn(tbl, varNames, candidates)
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

function col = localNumericColumn(tbl, varNames, candidates)
col = numericColumn(tbl, varNames, candidates);
end

function lines = buildReportMarkdown(cfg, decTablesDir, ptPath, alignId, scaleId, ...
    cdfMeta, monoTbl, stabTbl, verdict, verdictLine)

lines = strings(0, 1);
lines(end+1) = "# Phi temperature-derivative mechanism test";
lines(end+1) = "";
lines(end+1) = "## 1. Hypothesis";
lines(end+1) = "Test whether the empirical residual mode **Phi(x)** aligns with the leading **x-shaped** mode of **d/dT [ S_peak(T) CDF(P_T)(I) ]** after mapping **x = (I - I_peak(T)) / w(T)**.";
lines(end+1) = "";
lines(end+1) = "## 2. Method";
lines(end+1) = "- **CDF(P_T):** same PT-matrix reconstruction as `switching_residual_decomposition_analysis` (cumtrapz of normalized P_T on the alignment current grid).";
lines(end+1) = "- **S_CDF:** `S_peak(T) * CDF` with enforced monotonic CDF in [0,1].";
lines(end+1) = "- **d/dT:** central differences on the measured temperature grid; forward/backward at ends.";
lines(end+1) = "- **Smoothed derivative:** Savitzky–Golay along T (fixed window from config; not tuned per correlation).";
lines(end+1) = "- **x-map:** per-T interpolation of dS_CDF/dT from I to the decomposition **x** grid from `phi_shape.csv`.";
lines(end+1) = "- **SVD:** rows = temperatures, columns = x; each row **L2-normalized** before SVD; leading right singular vector **Phi_dT(x)**.";
lines(end+1) = "- **Bonus:** same pipeline on **d/dT log(S_CDF)** (floor at small positive value).";
lines(end+1) = "";
lines(end+1) = "## Inputs (read-only)";
lines(end+1) = "- Decomposition run: `" + string(cfg.decompositionRunId) + "`";
lines(end+1) = "- `phi_shape.csv` / `kappa_vs_T.csv` directory: `" + string(decTablesDir) + "`";
lines(end+1) = "- PT matrix: `" + string(ptPath) + "`";
lines(end+1) = "- Alignment run: `" + alignId + "` | Scaling run: `" + scaleId + "`";
lines(end+1) = "";
lines(end+1) = "## CDF reconstruction diagnostics";
lines(end+1) = sprintf("- PT-backed rows: %d | fallback rows: %d", cdfMeta.ptRowsUsed, cdfMeta.fallbackRowsUsed);
lines(end+1) = sprintf("- CDF monotonicity (max downward step of CDF/S_peak): median %.3g, max %.3g", ...
    median(monoTbl.max_cdf_decrease, 'omitnan'), max(monoTbl.max_cdf_decrease, [], 'omitnan'));
lines(end+1) = "";
lines(end+1) = "## 3. Results";
lines(end+1) = localTableToMd(stabTbl);
lines(end+1) = "";
lines(end+1) = "## 4. Interpretation";
lines(end+1) = "- **Phi as temperature-response mode:** compare Pearson / cosine / overlap for `dScdf_dT` variants across temperature windows.";
lines(end+1) = "- **Amplitude:** `pearson_kappa_aProj` links decomposition **kappa(T)** to projection of dS_CDF/dT onto **Phi**.";
lines(end+1) = "";
lines(end+1) = "## 5. Conclusion (mandatory)";
lines(end+1) = "**" + string(verdict) + "** — " + string(verdictLine);
lines(end+1) = "";
lines(end+1) = "## Related analyses";
lines(end+1) = "- `run_phi_physical_identification.m` compares Phi to median low-T kernels including dCDF/dT slices (different aggregation than SVD mode here).";
end

function s = localTableToMd(tbl)
if isempty(tbl) || height(tbl) == 0
    s = "_No stability rows computed._";
    return
end
vn = tbl.Properties.VariableNames;
sep = " | ";
head = "| " + strjoin(string(vn), sep) + " |";
rule = "|" + strjoin(repmat("---", 1, numel(vn)), "|") + "|";
rows = strings(height(tbl), 1);
for i = 1:height(tbl)
    cells = strings(1, numel(vn));
    for j = 1:numel(vn)
        v = tbl.(vn{j})(i);
        if iscell(v)
            v = v{1};
        end
        if isstring(v) || ischar(v)
            cells(j) = string(v);
        elseif isnumeric(v)
            cells(j) = sprintf('%.6g', double(v));
        else
            cells(j) = string(v);
        end
    end
    rows(i) = "| " + strjoin(cells, sep) + " |";
end
s = strjoin([head; rule; rows], newline);
end

function [verdict, line] = localVerdictFromTable(stabTbl)
rows = stabTbl(strcmp(stabTbl.derivative_variant, 'dScdf_dT_smooth'), :);
if isempty(rows)
    rows = stabTbl(strcmp(stabTbl.derivative_variant, 'dScdf_dT_raw'), :);
end
if isempty(rows)
    verdict = 'Not supported';
    line = 'Insufficient data to evaluate dScdf/dT modes.';
    return
end
rAll = rows(strcmp(rows.temperature_window, 'all_T'), :);
if ~isempty(rAll)
    c = abs(rAll.pearson_phi_phiDt(1));
else
    c = abs(max(rows.pearson_phi_phiDt, [], 'omitnan'));
end
r142 = rows(strcmp(rows.temperature_window, 'T_14_to_30'), :);
c2 = NaN;
if ~isempty(r142)
    c2 = abs(r142.pearson_phi_phiDt(1));
end
stable = isfinite(c2) && c2 >= 0.65 && abs(c - c2) <= 0.15;

if c >= 0.8 && stable
    verdict = 'Supported';
    line = sprintf('Smoothed dS_CDF/dT leading mode matches Phi (|r|~%.2f) with modest sensitivity to T window.', c);
elseif c >= 0.5
    verdict = 'Partially supported';
    line = sprintf('Non-trivial alignment (|r|~%.2f) but below the pre-set 0.8 bar and/or window sensitivity.', c);
else
    verdict = 'Not supported';
    line = sprintf('Weak shape match (|r|~%.2f) between Phi and the dS_CDF/dT SVD mode.', c);
end
end

function figPath = makeFigPhiVsPhiDt(phiE, phiD, runDir)
baseName = 'phi_vs_phi_dT_comparison';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 10 8]);
ax = axes(fig);
if isempty(phiD)
    text(ax, 0.1, 0.5, 'Leading \Phi_{dT} not computed', 'FontSize', 14);
    axis(ax, 'off');
else
    hold(ax, 'on');
    plot(ax, phiE, phiD, 'o', 'MarkerSize', 6, 'LineWidth', 2);
    xl = max(abs(phiE), [], 'omitnan');
    if isfinite(xl) && xl > 0
        plot(ax, [-xl xl], [-xl xl], 'k--', 'LineWidth', 1.5);
    end
    hold(ax, 'off');
    grid(ax, 'on');
    xlabel(ax, '\Phi(x) empirical');
    ylabel(ax, '\Phi_{dT}(x) leading mode');
    title(ax, 'Empirical \Phi vs temperature-derivative CDF-sector mode');
    styleAxes(ax);
end
figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figPath = makeFigModesOverlay(xg, phiE, phiD, runDir)
baseName = 'phi_modes_overlay';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 12 7]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, xg, phiE, '-', 'LineWidth', 2.5, 'DisplayName', '\Phi empirical');
if ~isempty(phiD)
    plot(ax, xg, phiD, '-', 'LineWidth', 2.5, 'DisplayName', '\Phi_{dT} (leading)');
end
hold(ax, 'off');
legend(ax, 'Location', 'best', 'Box', 'off');
grid(ax, 'on');
xlabel(ax, 'x = (I - I_{peak}) / w');
ylabel(ax, 'Mode amplitude');
title(ax, 'Shape comparison on decomposition x grid');
styleAxes(ax);
figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figPath = makeFigSingularSpectrum(sv, runDir)
baseName = 'singular_value_spectrum';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 10 6]);
ax = axes(fig);
if isempty(sv)
    text(ax, 0.1, 0.5, 'No singular values', 'FontSize', 14);
    axis(ax, 'off');
else
    bar(ax, 1:min(12, numel(sv)), sv(1:min(12, numel(sv))), 'FaceColor', [0.2 0.45 0.7]);
    xlabel(ax, 'Singular value index');
    ylabel(ax, 'Magnitude');
    title(ax, 'SVD spectrum (row-normalized dS_{CDF}/dT in x)');
    styleAxes(ax);
end
figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figPath = makeFigCorrVsWindow(stabTbl, runDir)
baseName = 'correlation_vs_T_window';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 12 7]);
ax = axes(fig);
winOrder = {'all_T', 'exclude_22K_band', 'T_14_to_30'};
vars = {'dScdf_dT_raw', 'dScdf_dT_smooth'};
hold(ax, 'on');
for vi = 1:numel(vars)
    y = NaN(1, numel(winOrder));
    for wi = 1:numel(winOrder)
        hit = stabTbl(strcmp(stabTbl.derivative_variant, vars{vi}) & ...
            strcmp(stabTbl.temperature_window, winOrder{wi}), :);
        if height(hit) >= 1
            y(wi) = hit.pearson_phi_phiDt(1);
        end
    end
    plot(ax, 1:numel(winOrder), y, 'o-', 'LineWidth', 2.5, 'DisplayName', vars{vi});
end
hold(ax, 'off');
set(ax, 'XTick', 1:numel(winOrder), 'XTickLabel', winOrder);
xtickangle(ax, 20);
ylabel(ax, 'Pearson corr(\Phi, \Phi_{dT})');
xlabel(ax, 'Temperature subset');
title(ax, 'Stability: correlation vs temperature window');
legend(ax, 'Location', 'best', 'Box', 'off');
grid(ax, 'on');
ylim(ax, [-1.05 1.05]);
styleAxes(ax);
figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function styleAxes(ax)
set(ax, 'FontName', 'Helvetica', 'FontSize', 14, 'LineWidth', 1.0, ...
    'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
end

function zipPath = buildReviewZip(runDir, zipName)
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
    return
end
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s', char(string(textValue)));
end

function out = stampNow()
out = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
