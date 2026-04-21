function out = run_temperature_boundary_audit(repoRootIn)
%RUN_TEMPERATURE_BOUNDARY_AUDIT Audit whether 4K/30K are boundary artifacts.

if nargin < 1 || isempty(repoRootIn)
    thisFile = mfilename('fullpath');
    analysisDir = fileparts(thisFile);
    repoRoot = fileparts(analysisDir);
else
    repoRoot = char(string(repoRootIn));
end

phiPath = fullfile(repoRoot, 'tables', 'phi1_observable_failure_by_T.csv');
if exist(phiPath, 'file') ~= 2
    error('Missing required input: %s', phiPath);
end

if ~local_phi_boundary_csv_ok(phiPath)
    error('run_temperature_boundary_audit:InvalidPhiCsv', 'Phi table failed precondition: %s', phiPath);
end

kapPath = resolveKappaPath(repoRoot);
if ~local_kappa_boundary_csv_ok(kapPath)
    error('run_temperature_boundary_audit:InvalidKappaCsv', 'Kappa table failed precondition: %s', kapPath);
end

phiTbl = readtable(phiPath, 'VariableNamingRule', 'preserve');
kapTbl = readtable(kapPath, 'VariableNamingRule', 'preserve');

if ismember('T', kapTbl.Properties.VariableNames) && ~ismember('T_K', kapTbl.Properties.VariableNames)
    kapTbl.Properties.VariableNames{'T'} = 'T_K';
end
assert(ismember('T_K', kapTbl.Properties.VariableNames), 'kappa_vs_T.csv must contain T_K or T');

kap2Name = pickFirstExisting(kapTbl.Properties.VariableNames, {'kappa2', 'kappa_2', 'kappa_alt', 'kappa_secondary'});
if isempty(kap2Name)
    kap2Vec = nan(height(kapTbl), 1);
else
    kap2Vec = toNumericColumn(kapTbl.(kap2Name));
end

kapKeep = table(toNumericColumn(kapTbl.T_K), toNumericColumn(kapTbl.kappa), kap2Vec, ...
    'VariableNames', {'T_K', 'kappa1_from_kappa_table', 'kappa2'});

if ~ismember('T_K', phiTbl.Properties.VariableNames)
    error('phi1 table must contain T_K');
end

joined = outerjoin(phiTbl, kapKeep, 'Keys', 'T_K', 'MergeKeys', true, 'Type', 'left');
joined = sortrows(joined, 'T_K');

errPrimary = resolveErrorMetric(joined);
errName = resolveErrorMetricName(joined);
if isempty(errPrimary)
    error('Could not resolve an error metric column from phi1_observable_failure_by_T.csv');
end
errZ = robustZ(errPrimary);

kap1 = resolveKappa1(joined);
kap1Z = robustZ(kap1);
kap2 = toNumericIfExists(joined, 'kappa2');
kap2Z = robustZ(kap2);

targetTemps = [4; 30];
rows = table();
for i = 1:numel(targetTemps)
    rows = [rows; buildBoundaryRow(joined, targetTemps(i), errPrimary, errZ, kap1, kap1Z, kap2, kap2Z)]; %#ok<AGROW>
end

rows.error_metric = repmat(string(errName), height(rows), 1);

lowFlag = decideEdgeFlag(rows(rows.T_K == 4, :));
highFlag = decideEdgeFlag(rows(rows.T_K == 30, :));
excludeFlag = "NO";
if lowFlag == "YES" || highFlag == "YES"
    excludeFlag = "YES";
end

% Optional exclusion experiments
fitRows = runOptionalExclusionFits(joined, errPrimary);

if ~isempty(fitRows)
    rows = outerjoin(rows, fitRows, 'Keys', 'T_K', 'MergeKeys', true, 'Type', 'left');
else
    rows.delta_rmse_exclude_this = nan(height(rows), 1);
    rows.delta_rmse_exclude_both = nan(height(rows), 1);
end

outCsv = fullfile(repoRoot, 'tables', 'temperature_boundary_audit.csv');
outMd = fullfile(repoRoot, 'reports', 'temperature_boundary_audit.md');
if exist(fileparts(outCsv), 'dir') ~= 7, mkdir(fileparts(outCsv)); end
if exist(fileparts(outMd), 'dir') ~= 7, mkdir(fileparts(outMd)); end
writetable(rows, outCsv);

writeReport(outMd, phiPath, kapPath, rows, lowFlag, highFlag, excludeFlag);

fprintf('Wrote %s\n', outCsv);
fprintf('Wrote %s\n', outMd);
fprintf('LOW_T_EDGE_EFFECT: %s\n', lowFlag);
fprintf('HIGH_T_BOUNDARY_EFFECT: %s\n', highFlag);
fprintf('SHOULD_EXCLUDE_FROM_MODEL: %s\n', excludeFlag);

out = struct();
out.csv = string(outCsv);
out.report = string(outMd);
out.low_t_edge_effect = lowFlag;
out.high_t_boundary_effect = highFlag;
out.should_exclude_from_model = excludeFlag;
end

function r = buildBoundaryRow(tbl, Tq, err, errZ, kap1, kap1Z, kap2, kap2Z)
ix = find(toNumericColumn(tbl.T_K) == Tq, 1);
assert(~isempty(ix), 'Temperature %g K not found in table.', Tq);
t = toNumericColumn(tbl.T_K);

edgeErr = err(ix);
medErr = median(err, 'omitnan');
edgeZ = errZ(ix);

leftIx = find(t < Tq, 1, 'last');
rightIx = find(t > Tq, 1, 'first');
neiErr = [pick(err, leftIx), pick(err, rightIx)];
neiErrMed = median(neiErr, 'omitnan');
if ~isfinite(neiErrMed), neiErrMed = medErr; end

kap1Nei = [pick(kap1, leftIx), pick(kap1, rightIx)];
kap2Nei = [pick(kap2, leftIx), pick(kap2, rightIx)];
kap1NeiMed = median(kap1Nei, 'omitnan');
kap2NeiMed = median(kap2Nei, 'omitnan');

r = table();
r.T_K = Tq;
r.error_value = edgeErr;
r.error_median_all = medErr;
r.error_ratio_to_median = edgeErr ./ max(medErr, eps);
r.error_z_robust = edgeZ;
r.neighbor_error_median = neiErrMed;
r.error_ratio_to_neighbors = edgeErr ./ max(neiErrMed, eps);
r.error_abs_delta_vs_neighbors = abs(edgeErr - neiErrMed);
r.neighbor_consistent_error = abs(edgeErr - neiErrMed) <= 1.5 * localScale(err);

r.kappa1_value = kap1(ix);
r.kappa1_z_robust = kap1Z(ix);
r.kappa1_neighbor_median = kap1NeiMed;
r.kappa1_abs_delta_vs_neighbors = abs(kap1(ix) - kap1NeiMed);
r.neighbor_consistent_kappa1 = abs(kap1(ix) - kap1NeiMed) <= 1.5 * localScale(kap1);

r.kappa2_value = kap2(ix);
r.kappa2_z_robust = kap2Z(ix);
r.kappa2_neighbor_median = kap2NeiMed;
r.kappa2_abs_delta_vs_neighbors = abs(kap2(ix) - kap2NeiMed);
r.neighbor_consistent_kappa2 = abs(kap2(ix) - kap2NeiMed) <= 1.5 * localScale(kap2);
end

function flag = decideEdgeFlag(row)
isOutlier = abs(row.error_z_robust) >= 1.5 || row.error_ratio_to_median >= 1.3 || row.error_ratio_to_neighbors >= 1.3;
isNeighborBreak = ~row.neighbor_consistent_error;
kappaBreak = (~row.neighbor_consistent_kappa1) || (~isnan(row.neighbor_consistent_kappa2) && ~row.neighbor_consistent_kappa2);

if isOutlier && (isNeighborBreak || kappaBreak)
    flag = "YES";
else
    flag = "NO";
end
end

function tbl = runOptionalExclusionFits(joined, y)
if height(joined) < 8
    tbl = table();
    return;
end
t = toNumericColumn(joined.T_K);
x = t;
rmseAll = loocvLinearRmse(x, y, true(size(y)));

tbl = table([4; 30], nan(2, 1), nan(2, 1), ...
    'VariableNames', {'T_K', 'delta_rmse_exclude_this', 'delta_rmse_exclude_both'});

for i = 1:2
    mask = true(size(y));
    mask(t == tbl.T_K(i)) = false;
    rmseEx = loocvLinearRmse(x, y, mask);
    tbl.delta_rmse_exclude_this(i) = rmseEx - rmseAll;
end

maskBoth = true(size(y));
maskBoth(t == 4 | t == 30) = false;
rmseBoth = loocvLinearRmse(x, y, maskBoth);
tbl.delta_rmse_exclude_both(:) = rmseBoth - rmseAll;
end

function rmse = loocvLinearRmse(x, y, mask)
use = mask & isfinite(x) & isfinite(y);
xv = x(use);
yv = y(use);
n = numel(yv);
if n < 4
    rmse = nan;
    return;
end

pred = nan(n, 1);
for i = 1:n
    tr = true(n, 1);
    tr(i) = false;
    Xt = [ones(sum(tr), 1), xv(tr)];
    b = Xt \ yv(tr);
    pred(i) = [1, xv(i)] * b;
end
rmse = sqrt(mean((pred - yv) .^ 2, 'omitnan'));
end

function z = robustZ(v)
v = toNumericColumn(v);
medv = median(v, 'omitnan');
madv = median(abs(v - medv), 'omitnan');
if ~isfinite(madv) || madv < eps
    s = std(v, 'omitnan');
    if ~isfinite(s) || s < eps
        z = nan(size(v));
        return;
    end
    z = (v - medv) ./ s;
else
    z = 0.67448975 * (v - medv) ./ madv;
end
end

function s = localScale(v)
v = toNumericColumn(v);
s = mad(v, 1);
if ~isfinite(s) || s < eps
    s = std(v, 'omitnan');
end
if ~isfinite(s) || s < eps
    s = 0;
end
end

function writeReport(pathMd, phiPath, kapPath, rows, lowFlag, highFlag, excludeFlag)
fid = fopen(pathMd, 'w');
assert(fid > 0, 'Unable to write report: %s', pathMd);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Temperature Boundary Audit\n\n');
fprintf(fid, 'Assessed whether 4K (low-T edge) and 30K (high-T boundary) look like edge artifacts or robust physics.\n\n');
fprintf(fid, '## Inputs\n');
fprintf(fid, '- `phi1_observable_failure_by_T.csv`: `%s`\n', phiPath);
fprintf(fid, '- `kappa_vs_T.csv`: `%s`\n', kapPath);
fprintf(fid, '- Residual/error metric used: `%s`\n\n', rows.error_metric(1));

fprintf(fid, '## Boundary Metrics\n\n');
fprintf(fid, '| T (K) | Error | Error/Median | Error z (robust) | Error/Neighbors | kappa1 z | kappa2 z |\n');
fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(rows)
    fprintf(fid, '| %.0f | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g |\n', ...
        rows.T_K(i), rows.error_value(i), rows.error_ratio_to_median(i), ...
        rows.error_z_robust(i), rows.error_ratio_to_neighbors(i), ...
        rows.kappa1_z_robust(i), rows.kappa2_z_robust(i));
end
fprintf(fid, '\n');

fprintf(fid, '## Optional Exclusion Fit Check\n\n');
fprintf(fid, '| T (K) | Delta RMSE (exclude this T) | Delta RMSE (exclude both 4K and 30K) |\n');
fprintf(fid, '|---:|---:|---:|\n');
for i = 1:height(rows)
    fprintf(fid, '| %.0f | %.6g | %.6g |\n', ...
        rows.T_K(i), rows.delta_rmse_exclude_this(i), rows.delta_rmse_exclude_both(i));
end
fprintf(fid, '\n');

fprintf(fid, '## Verdicts\n\n');
fprintf(fid, '- LOW_T_EDGE_EFFECT: **%s**\n', lowFlag);
fprintf(fid, '- HIGH_T_BOUNDARY_EFFECT: **%s**\n', highFlag);
fprintf(fid, '- SHOULD_EXCLUDE_FROM_MODEL: **%s**\n', excludeFlag);
end

function nm = resolveErrorMetricName(tbl)
prior = {'reconstruction_rmse_M2', 'abs_fit_residual', 'fit_residual_abs', 'fit_residual', 'error', 'residual'};
nm = pickFirstExisting(tbl.Properties.VariableNames, prior);
end

function v = resolveErrorMetric(tbl)
nm = resolveErrorMetricName(tbl);
if isempty(nm)
    v = [];
else
    v = toNumericColumn(tbl.(nm));
end
end

function v = resolveKappa1(tbl)
if ismember('kappa1', tbl.Properties.VariableNames)
    v = toNumericColumn(tbl.kappa1);
elseif ismember('kappa1_from_kappa_table', tbl.Properties.VariableNames)
    v = toNumericColumn(tbl.kappa1_from_kappa_table);
elseif ismember('kappa', tbl.Properties.VariableNames)
    v = toNumericColumn(tbl.kappa);
else
    error('Could not resolve kappa1 from inputs.');
end
end

function out = toNumericIfExists(tbl, name)
if ismember(name, tbl.Properties.VariableNames)
    out = toNumericColumn(tbl.(name));
else
    out = nan(height(tbl), 1);
end
end

function v = toNumericColumn(v)
if iscell(v) || isstring(v) || ischar(v)
    v = str2double(string(v));
elseif islogical(v)
    v = double(v);
end
v = double(v(:));
end

function nm = pickFirstExisting(candidates, priority)
nm = '';
for i = 1:numel(priority)
    if any(strcmp(candidates, priority{i}))
        nm = priority{i};
        return;
    end
end
end

function x = pick(v, idx)
if isempty(idx)
    x = nan;
else
    x = v(idx);
end
end

function path = resolveKappaPath(repoRoot)
candidates = {
    fullfile(repoRoot, 'tables', 'kappa_vs_T.csv')
    fullfile(repoRoot, 'results', 'switching', 'runs', '_extract_run_2026_03_24_220314_residual_decomposition', ...
        'run_2026_03_24_220314_residual_decomposition', 'tables', 'kappa_vs_T.csv')
    };
for i = 1:numel(candidates)
    if exist(candidates{i}, 'file') == 2
        path = candidates{i};
        return;
    end
end

paths = dir(fullfile(repoRoot, 'results', '**', 'kappa_vs_T.csv'));
if isempty(paths)
    error('Could not find kappa_vs_T.csv in repo.');
end
[~, ix] = max([paths.datenum]);
path = fullfile(paths(ix).folder, paths(ix).name);
end

function tf = local_phi_boundary_csv_ok(path)
tf = false;
prior = {'reconstruction_rmse_M2', 'abs_fit_residual', 'fit_residual_abs', 'fit_residual', 'error', 'residual'};
try
    tbl = readtable(path, 'VariableNamingRule', 'preserve');
    if ~ismember('T_K', tbl.Properties.VariableNames)
        return;
    end
    if isempty(pickFirstExisting(tbl.Properties.VariableNames, prior))
        return;
    end
    tf = height(tbl) >= 1;
catch
    tf = false;
end
end

function tf = local_kappa_boundary_csv_ok(path)
tf = false;
try
    tbl = readtable(path, 'VariableNamingRule', 'preserve');
    if ismember('T', tbl.Properties.VariableNames) && ~ismember('T_K', tbl.Properties.VariableNames)
        tbl.Properties.VariableNames{'T'} = 'T_K';
    end
    if ~ismember('T_K', tbl.Properties.VariableNames)
        return;
    end
    if ~ismember('kappa', tbl.Properties.VariableNames)
        return;
    end
    tf = height(tbl) >= 1;
catch
    tf = false;
end
end
