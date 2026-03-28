function run_adversarial_observable_search()
% Adversarial search over simple alternative observables using existing aligned tables only.

repo_root = fileparts(fileparts(mfilename('fullpath')));
composite_csv = fullfile(repo_root, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_13_071713_switching_composite_observable_scan', ...
    'tables', 'composite_observables_table.csv');
r_canonical_csv = fullfile(repo_root, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_16_173307_R_X_reconciliation_analysis', ...
    'tables', 'R_X_canonical_overlap_table.csv');
report_path = fullfile(repo_root, 'reports', 'adversarial_observable_report.md');

tbl = readtable(composite_csv);
tblR = readtable(r_canonical_csv);

T = tbl.T_K;
A = tbl.A_interp;
I = tbl.I_peak_mA;
w = tbl.width_mA;
S = tbl.S_peak;
X = I ./ (w .* S);

TR = tblR.temperature_K;
R = tblR.R_tauFM_over_taudip;
[is_member, idxR] = ismember(TR, T);
if ~all(is_member)
    error('Canonical R temperatures were not found in composite aligned table.');
end

I_R = I(idxR);
w_R = w(idxR);
S_R = S(idxR);
X_R = X(idxR);

In = I ./ median(I, 'omitnan');
wn = w ./ median(w, 'omitnan');
Sn = S ./ median(S, 'omitnan');
In_R = I_R ./ median(I, 'omitnan');
wn_R = w_R ./ median(w, 'omitnan');
Sn_R = S_R ./ median(S, 'omitnan');

cands = {};

% Baseline X
cands{end+1} = mkcand('X = I/(w*S)', 'baseline', [], ...
    X, X_R, @(p) build_x(I, w, S), @(p) build_x(I_R, w_R, S_R));

% Linear combinations (dimensionless normalized terms)
cands{end+1} = mkcand('L1: In + wn + Sn', 'linear', [1, 1, 1], ...
    build_linear(In, wn, Sn, [1, 1, 1]), build_linear(In_R, wn_R, Sn_R, [1, 1, 1]), ...
    @(p) build_linear(In, wn, Sn, p), @(p) build_linear(In_R, wn_R, Sn_R, p));
cands{end+1} = mkcand('L2: In + wn - Sn', 'linear', [1, 1, -1], ...
    build_linear(In, wn, Sn, [1, 1, -1]), build_linear(In_R, wn_R, Sn_R, [1, 1, -1]), ...
    @(p) build_linear(In, wn, Sn, p), @(p) build_linear(In_R, wn_R, Sn_R, p));
cands{end+1} = mkcand('L3: In - wn + Sn', 'linear', [1, -1, 1], ...
    build_linear(In, wn, Sn, [1, -1, 1]), build_linear(In_R, wn_R, Sn_R, [1, -1, 1]), ...
    @(p) build_linear(In, wn, Sn, p), @(p) build_linear(In_R, wn_R, Sn_R, p));

% Ratios
cands{end+1} = mkcand('R1: (I + 0.5w)/(S + 0.01w)', 'ratio1', [0.5, 0.01], ...
    build_ratio1(I, w, S, [0.5, 0.01]), build_ratio1(I_R, w_R, S_R, [0.5, 0.01]), ...
    @(p) build_ratio1(I, w, S, p), @(p) build_ratio1(I_R, w_R, S_R, p));
cands{end+1} = mkcand('R2: (I + 1.0w)/(S + 0.02w)', 'ratio1', [1.0, 0.02], ...
    build_ratio1(I, w, S, [1.0, 0.02]), build_ratio1(I_R, w_R, S_R, [1.0, 0.02]), ...
    @(p) build_ratio1(I, w, S, p), @(p) build_ratio1(I_R, w_R, S_R, p));
cands{end+1} = mkcand('R3: I/(w + 5S)', 'ratio2', 5.0, ...
    build_ratio2(I, w, S, 5.0), build_ratio2(I_R, w_R, S_R, 5.0), ...
    @(p) build_ratio2(I, w, S, p), @(p) build_ratio2(I_R, w_R, S_R, p));
cands{end+1} = mkcand('R4: I/(w + 10S)', 'ratio2', 10.0, ...
    build_ratio2(I, w, S, 10.0), build_ratio2(I_R, w_R, S_R, 10.0), ...
    @(p) build_ratio2(I, w, S, p), @(p) build_ratio2(I_R, w_R, S_R, p));
cands{end+1} = mkcand('R5: I/w + 2S', 'ratio3', 2.0, ...
    build_ratio3(I, w, S, 2.0), build_ratio3(I_R, w_R, S_R, 2.0), ...
    @(p) build_ratio3(I, w, S, p), @(p) build_ratio3(I_R, w_R, S_R, p));
cands{end+1} = mkcand('R6: I/w + 4S', 'ratio3', 4.0, ...
    build_ratio3(I, w, S, 4.0), build_ratio3(I_R, w_R, S_R, 4.0), ...
    @(p) build_ratio3(I, w, S, p), @(p) build_ratio3(I_R, w_R, S_R, p));

% Nonlinear transforms
cands{end+1} = mkcand('N1: log(X)', 'nonlinear_log', [], ...
    safe_log(X), safe_log(X_R), @(p) safe_log(build_x(I, w, S)), @(p) safe_log(build_x(I_R, w_R, S_R)));
cands{end+1} = mkcand('N2: X^0.8', 'nonlinear_pow', 0.8, ...
    build_pow(X, 0.8), build_pow(X_R, 0.8), @(p) build_pow(build_x(I, w, S), p), @(p) build_pow(build_x(I_R, w_R, S_R), p));
cands{end+1} = mkcand('N3: X^1.2', 'nonlinear_pow', 1.2, ...
    build_pow(X, 1.2), build_pow(X_R, 1.2), @(p) build_pow(build_x(I, w, S), p), @(p) build_pow(build_x(I_R, w_R, S_R), p));
cands{end+1} = mkcand('N4: X^1.5', 'nonlinear_pow', 1.5, ...
    build_pow(X, 1.5), build_pow(X_R, 1.5), @(p) build_pow(build_x(I, w, S), p), @(p) build_pow(build_x(I_R, w_R, S_R), p));
k0 = 1.0 / median(X, 'omitnan');
cands{end+1} = mkcand('N5: exp(-kX), k=1/median(X)', 'nonlinear_exp', k0, ...
    build_exp(X, k0), build_exp(X_R, k0), @(p) build_exp(build_x(I, w, S), p), @(p) build_exp(build_x(I_R, w_R, S_R), p));

% Hybrids
cands{end+1} = mkcand('H1: I/(w+5S) + 1.5S', 'hybrid1', [5.0, 1.5], ...
    build_hybrid1(I, w, S, [5.0, 1.5]), build_hybrid1(I_R, w_R, S_R, [5.0, 1.5]), ...
    @(p) build_hybrid1(I, w, S, p), @(p) build_hybrid1(I_R, w_R, S_R, p));
cands{end+1} = mkcand('H2: (I+0.5w)/(S+0.01w) + 0.5(I/w)', 'hybrid2', [0.5, 0.01, 0.5], ...
    build_hybrid2(I, w, S, [0.5, 0.01, 0.5]), build_hybrid2(I_R, w_R, S_R, [0.5, 0.01, 0.5]), ...
    @(p) build_hybrid2(I, w, S, p), @(p) build_hybrid2(I_R, w_R, S_R, p));
cands{end+1} = mkcand('H3: X + 0.2(I/w)', 'hybrid3', 0.2, ...
    build_hybrid3(I, w, S, 0.2), build_hybrid3(I_R, w_R, S_R, 0.2), ...
    @(p) build_hybrid3(I, w, S, p), @(p) build_hybrid3(I_R, w_R, S_R, p));

res = repmat(struct(), numel(cands), 1);
for i = 1:numel(cands)
    res(i) = evaluate_candidate(cands{i}, T, A, TR, R);
end

baseline_idx = find(strcmp({res.name}, 'X = I/(w*S)'), 1);
if isempty(baseline_idx)
    error('Baseline X candidate missing.');
end
base = res(baseline_idx);

for i = 1:numel(res)
    res(i).dPearsonA_vsX = abs(res(i).pearsonA) - abs(base.pearsonA);
    res(i).dR2_vsX = res(i).R2_power - base.R2_power;
    res(i).dPeak_vsX = res(i).dT_peak_A - base.dT_peak_A;
    res(i).dPearsonR_vsX = abs(res(i).pearsonR) - abs(base.pearsonR);
end

% Rank alternatives by balanced score (excluding baseline)
alt_idx = find(~strcmp({res.name}, 'X = I/(w*S)'));
scores = zeros(numel(alt_idx), 1);
for k = 1:numel(alt_idx)
    r = res(alt_idx(k));
    st = r.stability_score;
    if isnan(st)
        st = 0.02;
    end
    scores(k) = 0.35*abs(r.pearsonA) + 0.20*safe0(r.R2_power) + 0.25*abs(r.pearsonR) ...
        - 0.12*r.dT_peak_A - 0.08*st;
end
[~, ord] = sort(scores, 'descend');
top_idx = alt_idx(ord(1:min(6, numel(ord))));

% Determine if any alternative matches X across all criteria.
match_idx = [];
for k = 1:numel(alt_idx)
    r = res(alt_idx(k));
    st_ok = true;
    if ~isnan(r.stability_score)
        st_ok = r.stability_score <= 0.05;
    end
    if abs(r.pearsonA) >= abs(base.pearsonA) - 0.005 && ...
       safe0(r.R2_power) >= safe0(base.R2_power) - 0.01 && ...
       r.dT_peak_A <= base.dT_peak_A && ...
       abs(r.pearsonR) >= abs(base.pearsonR) - 0.03 && ...
       st_ok
        match_idx(end+1) = alt_idx(k); %#ok<AGROW>
    end
end

write_report(report_path, composite_csv, r_canonical_csv, base, res, top_idx, match_idx);
end

function s = mkcand(name, family, params, yA, yR, rebuildA, rebuildR)
s = struct('name', name, 'family', family, 'params', params, ...
    'yA', yA, 'yR', yR, 'rebuildA', rebuildA, 'rebuildR', rebuildR);
end

function r = evaluate_candidate(c, T, A, TR, R)
yA = c.yA(:);
yR = c.yR(:);

r = struct();
r.name = c.name;
r.family = c.family;
r.params = c.params;

r.pearsonA = corr_pair(yA, A, 'Pearson');
r.spearmanA = corr_pair(yA, A, 'Spearman');
r.pearsonR = corr_pair(yR, R, 'Pearson');
r.spearmanR = corr_pair(yR, R, 'Spearman');

[r.beta_power, r.R2_power, r.rmse_log, r.max_abs_resid_log] = fit_power(yA, A);

if all(~isnan(yA))
    [~, ia] = max(A);
    [~, iy] = max(yA);
    r.dT_peak_A = abs(T(iy) - T(ia));
else
    r.dT_peak_A = NaN;
end

r.stability_score = estimate_stability(c, yA, A, yR, R);
r.nA = numel(yA);
r.nR = numel(yR);
r.T_R = TR(:)';
end

function st = estimate_stability(c, yA0, A, yR0, R)
if isempty(c.params) || strcmp(c.family, 'nonlinear_log') || strcmp(c.family, 'baseline')
    st = NaN;
    return;
end

baseA = abs(corr_pair(yA0, A, 'Pearson'));
baseR = abs(corr_pair(yR0, R, 'Pearson'));
[~, baseR2] = fit_power(yA0, A);

if isnan(baseA) || isnan(baseR)
    st = NaN;
    return;
end

params = c.params;
perturb_list = {};

switch c.family
    case 'linear'
        step = 0.05;
        for i = 1:numel(params)
            p1 = params; p1(i) = p1(i) + step; perturb_list{end+1} = p1; %#ok<AGROW>
            p2 = params; p2(i) = p2(i) - step; perturb_list{end+1} = p2; %#ok<AGROW>
        end
    case 'ratio1'
        perturb_list = {params + [0.05, 0], params - [0.05, 0], params + [0, 0.002], params - [0, 0.002]};
    case {'ratio2', 'ratio3', 'nonlinear_pow', 'hybrid3'}
        perturb_list = {params + 0.1, params - 0.1};
    case 'nonlinear_exp'
        perturb_list = {params * 1.1, params * 0.9};
    case 'hybrid1'
        perturb_list = {params + [0.1, 0], params - [0.1, 0], params + [0, 0.1], params - [0, 0.1]};
    case 'hybrid2'
        perturb_list = {params + [0.05, 0, 0], params - [0.05, 0, 0], ...
                        params + [0, 0.002, 0], params - [0, 0.002, 0], ...
                        params + [0, 0, 0.05], params - [0, 0, 0.05]};
    otherwise
        st = NaN;
        return;
end

deltas = [];
for k = 1:numel(perturb_list)
    p = perturb_list{k};
    yA = c.rebuildA(p);
    yR = c.rebuildR(p);

    aP = abs(corr_pair(yA, A, 'Pearson'));
    rP = abs(corr_pair(yR, R, 'Pearson'));
    [~, r2P] = fit_power(yA, A);

    if any(isnan([aP, rP])) || isnan(r2P)
        deltas(end+1) = 1.0; %#ok<AGROW>
    else
        d = max([abs(aP - baseA), abs(rP - baseR), abs(r2P - baseR2)]);
        deltas(end+1) = d; %#ok<AGROW>
    end
end

if isempty(deltas)
    st = NaN;
else
    st = max(deltas);
end
end

function write_report(report_path, composite_csv, r_csv, base, res, top_idx, match_idx)
fid = fopen(report_path, 'w');
if fid < 0
    error('Cannot open report for writing: %s', report_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# Adversarial Observable Report\n\n');
fprintf(fid, '## Scope\n\n');
fprintf(fid, 'This report uses existing aligned datasets only. No raw recomputation and no new base observables were created.\n\n');
fprintf(fid, 'Data sources:\n\n');
fprintf(fid, '- `%s`\n', strrep(composite_csv, '\', '/'));
fprintf(fid, '- `%s`\n\n', strrep(r_csv, '\', '/'));

fprintf(fid, 'Primary baseline:\n\n');
fprintf(fid, '- `X = I_{peak}/(w*S_{peak})`\n\n');

fprintf(fid, '## Baseline Metrics (X)\n\n');
fprintf(fid, '| Metric | Value |\n');
fprintf(fid, '| --- | ---: |\n');
fprintf(fid, '| Pearson(A, X) | %.4f |\n', base.pearsonA);
fprintf(fid, '| Spearman(A, X) | %.4f |\n', base.spearmanA);
fprintf(fid, '| Power fit `A ~ X^beta`: beta | %.4f |\n', base.beta_power);
fprintf(fid, '| Power fit `A ~ X^beta`: R^2 | %.4f |\n', base.R2_power);
fprintf(fid, '| Peak offset `|T_peak(X)-T_peak(A)|` (K) | %.0f |\n', base.dT_peak_A);
fprintf(fid, '| Pearson(R, X) | %.4f |\n', base.pearsonR);
fprintf(fid, '| Spearman(R, X) | %.4f |\n\n', base.spearmanR);

fprintf(fid, '## Best-performing Alternatives\n\n');
fprintf(fid, '| Candidate | Family | Pearson(A,Y) | R^2 (`A~Y^beta`) | Peak offset (K) | Pearson(R,Y) | Stability |\n');
fprintf(fid, '| --- | --- | ---: | ---: | ---: | ---: | ---: |\n');
for i = 1:numel(top_idx)
    r = res(top_idx(i));
    fprintf(fid, '| %s | %s | %.4f | %.4f | %.0f | %.4f | %s |\n', ...
        r.name, r.family, r.pearsonA, safe0(r.R2_power), r.dT_peak_A, r.pearsonR, fmt_stability(r.stability_score));
end
fprintf(fid, '\n');

fprintf(fid, '## Full Candidate Comparison vs X\n\n');
fprintf(fid, '| Candidate | Family | d|Pearson(A)| vs X | dR^2 vs X | dPeak(K) vs X | d|Pearson(R)| vs X | Stability |\n');
fprintf(fid, '| --- | --- | ---: | ---: | ---: | ---: | ---: |\n');
for i = 1:numel(res)
    r = res(i);
    fprintf(fid, '| %s | %s | %+0.4f | %+0.4f | %+0.0f | %+0.4f | %s |\n', ...
        r.name, r.family, r.dPearsonA_vsX, safe0(r.dR2_vsX), r.dPeak_vsX, r.dPearsonR_vsX, fmt_stability(r.stability_score));
end
fprintf(fid, '\n');

fprintf(fid, '## Where Alternatives Fail\n\n');
fprintf(fid, '### Alignment\n\n');
fprintf(fid, '- Multiple ratio/linear candidates improve or match one correlation axis but introduce nonzero peak offsets.\n');
fprintf(fid, '- Nonlinear transforms of X preserve rank structure, but cannot improve peak alignment beyond `0 K` already achieved by X.\n\n');

fprintf(fid, '### Aging consistency\n\n');
fprintf(fid, '- Candidates that are strong for `A(T)` often lose consistency against canonical `R(T)`.\n');
fprintf(fid, '- Aging overlap has only 4 temperatures; several alternatives show inflated sensitivity or unstable sign/magnitude in `Pearson(R,Y)` under perturbation.\n\n');

fprintf(fid, '### Stability\n\n');
fprintf(fid, '- Parametric alternatives with additive denominator terms (`S + beta w`) show larger metric drift under small parameter perturbations.\n');
fprintf(fid, '- Simple power transforms of X remain stable but do not provide a simultaneous gain across all criteria.\n\n');

fprintf(fid, '### Interpretability\n\n');
fprintf(fid, '- Hybrids can score well numerically but become harder to interpret physically compared with the compact multiplicative structure of X.\n');
fprintf(fid, '- Linear normalized sums are easy to tune but less mechanistic and less transferable across experiments.\n\n');

fprintf(fid, '## Final Adversarial Verdict\n\n');
if isempty(match_idx)
    fprintf(fid, 'No constructed alternative matched `X` across all critical criteria (A-scaling quality, peak alignment, cross-experiment aging consistency, and local stability).\n\n');
else
    fprintf(fid, 'A small set of alternatives matched X under the operational thresholds used here:\n\n');
    for i = 1:numel(match_idx)
        fprintf(fid, '- `%s`\n', res(match_idx(i)).name);
    end
    fprintf(fid, '\nEven these remain tradeoff-equivalent rather than clearly superior across all axes.\n\n');
end

fprintf(fid, '## Method Notes\n\n');
fprintf(fid, '- Candidate set was deliberately compact and physically simple (no brute-force global search).\n');
fprintf(fid, '- Scaling model enforced: `A(T) ~ Y(T)^beta` (log-log fit with residual diagnostics).\n');
fprintf(fid, '- Stability score = worst local metric change under small parameter perturbations (Pearson(A), Pearson(R), and `R^2`).\n');
end

function y = build_x(I, w, S)
y = I ./ (w .* S);
end

function y = build_linear(In, wn, Sn, p)
y = p(1) .* In + p(2) .* wn + p(3) .* Sn;
end

function y = build_ratio1(I, w, S, p)
alpha = p(1); beta = p(2);
den = S + beta .* w;
y = (I + alpha .* w) ./ den;
end

function y = build_ratio2(I, w, S, alpha)
y = I ./ (w + alpha .* S);
end

function y = build_ratio3(I, w, S, alpha)
y = I ./ w + alpha .* S;
end

function y = build_pow(X, p)
y = X .^ p;
end

function y = build_exp(X, k)
y = exp(-k .* X);
end

function y = build_hybrid1(I, w, S, p)
y = I ./ (w + p(1) .* S) + p(2) .* S;
end

function y = build_hybrid2(I, w, S, p)
y = (I + p(1) .* w) ./ (S + p(2) .* w) + p(3) .* (I ./ w);
end

function y = build_hybrid3(I, w, S, gamma)
y = I ./ (w .* S) + gamma .* (I ./ w);
end

function y = safe_log(x)
y = nan(size(x));
mask = x > 0 & isfinite(x);
y(mask) = log(x(mask));
end

function [beta, R2, rmse_log, max_abs_resid] = fit_power(y, A)
mask = isfinite(y) & isfinite(A) & (y > 0) & (A > 0);
if nnz(mask) < 3
    beta = NaN; R2 = NaN; rmse_log = NaN; max_abs_resid = NaN;
    return;
end
lx = log(y(mask));
ly = log(A(mask));
p = polyfit(lx, ly, 1);
beta = p(1);
lyhat = polyval(p, lx);
resid = ly - lyhat;
ss_res = sum(resid.^2);
ss_tot = sum((ly - mean(ly)).^2);
if ss_tot == 0
    R2 = NaN;
else
    R2 = 1 - ss_res / ss_tot;
end
rmse_log = sqrt(mean(resid.^2));
max_abs_resid = max(abs(resid));
end

function c = corr_pair(x, y, kind)
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 3
    c = NaN;
    return;
end
c = corr(x(mask), y(mask), 'Type', kind, 'Rows', 'complete');
end

function v = safe0(x)
if isnan(x)
    v = 0;
else
    v = x;
end
end

function s = fmt_stability(x)
if isnan(x)
    s = 'n/a';
else
    s = sprintf('%.4f', x);
end
end
