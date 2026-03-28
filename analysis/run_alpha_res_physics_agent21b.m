function run_alpha_res_physics_agent21b(varargin)
%RUN_ALPHA_RES_PHYSICS_AGENT21B  Agent 21B — test whether alpha_res tracks physical state.
%
%   alpha_res = residual of alpha after best PT-geometry fit (Agent 20B), column
%   `residual_best` in `tables/alpha_from_PT.csv` (recompute via
%   analysis/run_alpha_from_pt_agent20b.m if needed).
%
%   Inputs merged on T_K: kappa1 from `tables/alpha_structure.csv`, R(T) from
%   `barrier_descriptors.csv` (column R_T_interp preferred).
%
%   Writes:
%     tables/alpha_res_physics.csv
%     reports/alpha_res_physics_report.md
%
%   Name-value pairs:
%     'repoRoot'       — repo root (default: two levels up from this file)
%     'alphaFromPtPath' — CSV with alpha_res (default: tables/alpha_from_PT.csv)
%     'alphaResColumn'  — column name (default: 'residual_best')
%     'alphaStructurePath' — kappa1 source (default: tables/alpha_structure.csv)
%     'barrierPath'     — barrier CSV with R(T); if missing, auto-pick newest
%                         under results/cross_experiment/runs/*/tables/barrier_descriptors.csv
%                         that contains R_T_interp

opts = localParseOpts(varargin{:});
repoRoot = opts.repoRoot;

alphaPtPath = opts.alphaFromPtPath;
if ~isfile(alphaPtPath)
    error('run_alpha_res_physics_agent21b:MissingAlphaPt', ...
        'Need %s (run analysis/run_alpha_from_pt_agent20b.m first).', alphaPtPath);
end

structPath = opts.alphaStructurePath;
assert(isfile(structPath), 'Missing %s', structPath);

barrierPath = opts.barrierPath;
if ~isfile(barrierPath)
    barrierPath = localFindBarrierWithR(repoRoot);
end
assert(isfile(barrierPath), ...
    'Could not locate barrier_descriptors.csv with R_T_interp (pass ''barrierPath'', ...).');

for d = {fullfile(repoRoot, 'tables'), fullfile(repoRoot, 'reports')}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

aPt = readtable(alphaPtPath, 'VariableNamingRule', 'preserve');
if ~ismember(opts.alphaResColumn, aPt.Properties.VariableNames)
    error('Column %s not found in %s', opts.alphaResColumn, alphaPtPath);
end
aStr = readtable(structPath, 'VariableNamingRule', 'preserve');
if ~ismember('kappa1', aStr.Properties.VariableNames)
    error('kappa1 column missing in %s', structPath);
end

bTbl = readtable(barrierPath, 'VariableNamingRule', 'preserve');
Rcol = localPickRTColumn(bTbl.Properties.VariableNames);

Tpt = double(aPt.T_K(:));
alphaRes = double(aPt.(opts.alphaResColumn)(:));
Ts = double(aStr.T_K(:));
k1 = double(aStr.kappa1(:));
Tb = double(bTbl.T_K(:));
Rv = double(bTbl.(Rcol)(:));

% Align: one row per temperature in alpha_from_PT (canonical T grid for residual)
n = numel(Tpt);
kappa1 = NaN(n, 1);
for i = 1:n
    j = find(abs(Ts - Tpt(i)) < 1e-6, 1);
    if ~isempty(j)
        kappa1(i) = k1(j);
    end
end
RT = NaN(n, 1);
for i = 1:n
    j = find(abs(Tb - Tpt(i)) < 1e-6, 1);
    if ~isempty(j)
        RT(i) = Rv(j);
    end
end

T = Tpt(:);

% --- Correlations (pairwise complete) ---
[rp_k, rs_k, nk] = localCorrPair(alphaRes, kappa1);
[rp_r, rs_r, nr] = localCorrPair(alphaRes, RT);
[rp_t, rs_t, nt] = localCorrPair(alphaRes, T);

% --- Regime means: T < 22 vs T > 24 (exclude [22,24]) ---
mLo = T < 22 & isfinite(alphaRes);
mHi = T > 24 & isfinite(alphaRes);
meanLo = mean(alphaRes(mLo), 'omitnan');
meanHi = mean(alphaRes(mHi), 'omitnan');
stdAll = std(alphaRes(isfinite(alphaRes)), 'omitnan');
[pReg, ~, ~] = localWelchOrNaN(alphaRes(mLo), alphaRes(mHi));

% --- Variance concentration in 22–24 K (fraction of total SS about global mean) ---
mBand = T >= 22 & T <= 24 & isfinite(alphaRes);
mu = mean(alphaRes(isfinite(alphaRes)), 'omitnan');
dev = alphaRes - mu;
mFin = isfinite(alphaRes);
SS_tot = sum(dev(mFin).^2, 'omitnan');
SS_band = sum(dev(mBand & mFin).^2, 'omitnan');
if SS_tot > 0 && isfinite(SS_tot)
    fracVarBand = SS_band / SS_tot;
else
    fracVarBand = NaN;
end

% --- Flags (documented thresholds; conservative for "linked") ---
thrLink = 0.35;
linkedR = localLinked(rp_r, rs_r, nr, thrLink);
linkedK = localLinked(rp_k, rs_k, nk, thrLink);
regimeVar = false;
if isfinite(meanLo) && isfinite(meanHi) && isfinite(stdAll) && stdAll > 0
    regimeVar = abs(meanLo - meanHi) > 0.5 * stdAll;
end
if isfinite(pReg) && pReg < 0.1
    regimeVar = true;
end

flagR = ternary(linkedR);
flagK = ternary(linkedK);
flagReg = ternary(regimeVar);

% --- CSV: tidy metrics (value column: numeric or YES/NO strings) ---
metrics = { ...
    'corr_pearson_alpha_res_kappa1'; 'corr_spearman_alpha_res_kappa1'; 'n_pair_alpha_res_kappa1'; ...
    'corr_pearson_alpha_res_R'; 'corr_spearman_alpha_res_R'; 'n_pair_alpha_res_R'; ...
    'corr_pearson_alpha_res_T'; 'corr_spearman_alpha_res_T'; 'n_pair_alpha_res_T'; ...
    'mean_alpha_res_T_lt_22'; 'mean_alpha_res_T_gt_24'; 'std_alpha_res_all'; ...
    'welch_t_pvalue_below22_vs_above24'; 'frac_SS_alpha_res_in_band_22_24K'; ...
    'ALPHA_RES_LINKED_TO_R'; 'ALPHA_RES_LINKED_TO_KAPPA1'; 'ALPHA_RES_IS_REGIME_VARIABLE' ...
    };
vals = { ...
    rp_k; rs_k; nk; ...
    rp_r; rs_r; nr; ...
    rp_t; rs_t; nt; ...
    meanLo; meanHi; stdAll; ...
    pReg; fracVarBand; ...
    flagR; flagK; flagReg ...
    };
outM = table(metrics, vals, 'VariableNames', {'metric', 'value'});

outCsv = fullfile(repoRoot, 'tables', 'alpha_res_physics.csv');
writetable(outM, outCsv);

% --- Report ---
outRep = fullfile(repoRoot, 'reports', 'alpha_res_physics_report.md');
fid = fopen(outRep, 'w');
assert(fid > 0, 'Cannot write %s', outRep);
fprintf(fid, '# Alpha residual physics test (Agent 21B)\n\n');
fprintf(fid, '**Goal:** test whether `alpha_res` (PT-geometry residual from Agent 20B) tracks physical scalars `kappa1`, `R(T)`, and temperature.\n\n');
fprintf(fid, '- **alpha_res source:** `%s` column `%s`\n', strrep(alphaPtPath, '\', '/'), opts.alphaResColumn);
fprintf(fid, '- **kappa1 source:** `%s`\n', strrep(structPath, '\', '/'));
fprintf(fid, '- **R(T) source:** `%s` (column `%s`)\n\n', strrep(barrierPath, '\', '/'), Rcol);

fprintf(fid, '## Correlations (pairwise complete observations)\n\n');
fprintf(fid, '| pair | Pearson | Spearman | n |\n');
fprintf(fid, '|---|---:|---:|---:|\n');
fprintf(fid, '| alpha_res vs kappa1 | %.6g | %.6g | %d |\n', rp_k, rs_k, nk);
fprintf(fid, '| alpha_res vs R(T) | %.6g | %.6g | %d |\n', rp_r, rs_r, nr);
fprintf(fid, '| alpha_res vs T | %.6g | %.6g | %d |\n\n', rp_t, rs_t, nt);

fprintf(fid, '## Regime test (below vs above 22–24 K)\n\n');
fprintf(fid, '- **Mean alpha_res for T < 22 K:** %.6g (n = %d)\n', meanLo, nnz(mLo));
fprintf(fid, '- **Mean alpha_res for T > 24 K:** %.6g (n = %d)\n', meanHi, nnz(mHi));
fprintf(fid, '- **Welch two-sample t-test** (unequal variance) p-value: **%.6g** (NaN if not enough data)\n', pReg);
fprintf(fid, '- **Regime flag heuristic:** |mean_lo − mean_hi| > 0.5·std(alpha_res) **or** p < 0.1.\n\n');

fprintf(fid, '## Variance concentration (22–24 K band)\n\n');
fprintf(fid, '- **Fraction of total sum-of-squares** of `alpha_res` about the global mean contributed by rows with **22 ≤ T ≤ 24**:\n');
fprintf(fid, '  **%.6g** (SS_band / SS_total).\n\n', fracVarBand);

fprintf(fid, '## Linked-to-physics flags (threshold |ρ| or |ρ_s| ≥ %.2f for “linked”; n ≥ 4)\n\n', thrLink);
fprintf(fid, '- **ALPHA_RES_LINKED_TO_R** = **%s**\n', flagR);
fprintf(fid, '- **ALPHA_RES_LINKED_TO_KAPPA1** = **%s**\n', flagK);
fprintf(fid, '- **ALPHA_RES_IS_REGIME_VARIABLE** = **%s**\n\n', flagReg);

fprintf(fid, '## Artifacts\n\n');
fprintf(fid, '- `%s` — metric/value summary\n\n', strrep(outCsv, '\', '/'));
fprintf(fid, '*Auto-generated by `analysis/run_alpha_res_physics_agent21b.m`.*\n');
fclose(fid);

fprintf('Wrote %s\n%s\n', outCsv, outRep);
end

function s = ternary(tf)
if tf
    s = 'YES';
else
    s = 'NO';
end
end

function ok = localLinked(rp, rs, n, thr)
if n < 4
    ok = false;
    return
end
ok = (isfinite(rp) && abs(rp) >= thr) || (isfinite(rs) && abs(rs) >= thr);
end

function [rp, rs, n] = localCorrPair(a, b)
m = isfinite(a) & isfinite(b);
n = nnz(m);
if n < 2
    rp = NaN; rs = NaN; return
end
rp = corr(a(m), b(m), 'type', 'Pearson', 'rows', 'complete');
if n >= 3
    rs = corr(a(m), b(m), 'type', 'Spearman', 'rows', 'complete');
else
    rs = NaN;
end
end

function [p, h, stats] = localWelchOrNaN(x, y)
p = NaN; h = NaN; stats = struct();
if numel(x) < 2 || numel(y) < 2
    return
end
try
    [h, p, ~, stats] = ttest2(x(:), y(:), 'Vartype', 'unequal');
catch
    p = NaN;
end
end

function col = localPickRTColumn(names)
cand = ["R_T_interp", "R_T", "R"];
for k = 1:numel(cand)
    if any(strcmp(names, cand(k)))
        col = char(cand(k));
        return
    end
end
error('No R(T) column (R_T_interp / R_T / R) in barrier table');
end

function pth = localFindBarrierWithR(repoRoot)
base = fullfile(repoRoot, 'results', 'cross_experiment', 'runs');
if exist(base, 'dir') ~= 7
    pth = '';
    return
end
d = dir(base);
best = '';
bestTime = datetime(1970, 1, 1);
for i = 1:numel(d)
    if ~d(i).isdir || strcmp(d(i).name, '.') || strcmp(d(i).name, '..')
        continue
    end
    cand = fullfile(base, d(i).name, 'tables', 'barrier_descriptors.csv');
    if exist(cand, 'file') ~= 2
        continue
    end
    t = dir(cand);
    if isempty(t), continue; end
    tt = datetime(t(1).date);
    try
        opts = detectImportOptions(cand, 'VariableNamingRule', 'preserve');
        vn = opts.VariableNames;
    catch
        continue
    end
    if ~any(ismember(vn, {'R_T_interp', 'R_T', 'R'}))
        continue
    end
    if isempty(best) || tt > bestTime
        best = cand;
        bestTime = tt;
    end
end
pth = best;
end

function opts = localParseOpts(varargin)
thisPath = mfilename('fullpath');
opts = struct();
opts.repoRoot = fileparts(fileparts(thisPath));
opts.alphaFromPtPath = fullfile(opts.repoRoot, 'tables', 'alpha_from_PT.csv');
opts.alphaResColumn = 'residual_best';
opts.alphaStructurePath = fullfile(opts.repoRoot, 'tables', 'alpha_structure.csv');
opts.barrierPath = fullfile(opts.repoRoot, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_25_031904_barrier_to_relaxation_mechanism', 'tables', 'barrier_descriptors.csv');

if mod(numel(varargin), 2) ~= 0
    error('Name-value pairs expected');
end
for k = 1:2:numel(varargin)
    nm = lower(string(varargin{k}));
    val = varargin{k + 1};
    switch nm
        case "reporoot"
            opts.repoRoot = char(string(val));
        case "alphafromptpath"
            opts.alphaFromPtPath = char(string(val));
        case "alpharescolumn"
            opts.alphaResColumn = char(string(val));
        case "alphastructurepath"
            opts.alphaStructurePath = char(string(val));
        case "barrierpath"
            opts.barrierPath = char(string(val));
        otherwise
            error('Unknown option: %s', varargin{k});
    end
end
opts.alphaFromPtPath = fullfile(opts.alphaFromPtPath);
opts.alphaStructurePath = fullfile(opts.alphaStructurePath);
opts.barrierPath = char(string(opts.barrierPath));
end
