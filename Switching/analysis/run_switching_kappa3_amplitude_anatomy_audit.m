clear; clc;

% Canonical kappa3 amplitude-anatomy audit (Switching only).
% Goal: identify dominant controls for diagnostic kappa3_diag.
% Scope guards:
% - certified canonical evidence gate required
% - no decomposition redefinition
% - no producer modification
% - failed Phi2 replacement audit excluded

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

outCorr = fullfile(repoRoot, 'tables', 'switching_kappa3_amplitude_correlations.csv');
outPart = fullfile(repoRoot, 'tables', 'switching_kappa3_partial_correlations.csv');
outModels = fullfile(repoRoot, 'tables', 'switching_kappa3_explanatory_models.csv');
outDom = fullfile(repoRoot, 'tables', 'switching_kappa3_domain_robustness.csv');
outRep = fullfile(repoRoot, 'reports', 'switching_kappa3_amplitude_anatomy.md');

% ---------------------------- Evidence gate ----------------------------
gatePath = fullfile(repoRoot, 'tables', 'switching_mode_evidence_certification_status.csv');
if exist(gatePath, 'file') ~= 2
    error('run_switching_kappa3_amplitude_anatomy_audit:MissingGate', 'Missing gate status table.');
end
g = readtable(gatePath, 'TextType', 'string');
checks = { ...
    'MODE_EVIDENCE_CERTIFICATION_COMPLETE', ...
    'FAILED_PHI2_REPLACEMENT_EXCLUDED', ...
    'CRITICAL_MODE_AUDITS_CERTIFIED', ...
    'CANONICAL_ONLY_NEXT_AUDIT_EVIDENCE_AVAILABLE', ...
    'SAFE_TO_RUN_PHI3_RELATIONSHIP_AUDITS'};
for i = 1:numel(checks)
    ix = find(strcmpi(strtrim(g.check), checks{i}), 1);
    if isempty(ix) || upper(strtrim(g.result(ix))) ~= "YES"
        error('run_switching_kappa3_amplitude_anatomy_audit:GateFailed', 'Evidence gate failed at %s.', checks{i});
    end
end

% ----------------------- Canonical identity lock -----------------------
idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
if exist(idPath, 'file') ~= 2 || exist(ampPath, 'file') ~= 2
    error('run_switching_kappa3_amplitude_anatomy_audit:MissingInputs', ...
        'Missing identity or amplitudes input.');
end

idRaw = readcell(idPath, 'Delimiter', ',');
canonicalRunId = "";
for r = 2:size(idRaw, 1)
    key = strtrim(string(idRaw{r, 1}));
    key = regexprep(key, "^\xFEFF", "");
    if strcmpi(key, "CANONICAL_RUN_ID")
        canonicalRunId = strtrim(string(idRaw{r, 2}));
        break;
    end
end
if strlength(canonicalRunId) == 0
    error('run_switching_kappa3_amplitude_anatomy_audit:MissingRunId', 'CANONICAL_RUN_ID missing.');
end

runRoot = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId));
sLongPath = fullfile(runRoot, 'tables', 'switching_canonical_S_long.csv');
phi1Path = fullfile(runRoot, 'tables', 'switching_canonical_phi1.csv');
if exist(runRoot, 'dir') ~= 7 || exist(sLongPath, 'file') ~= 2 || exist(phi1Path, 'file') ~= 2
    error('run_switching_kappa3_amplitude_anatomy_audit:MissingCanonicalArtifacts', ...
        'Missing identity-locked canonical artifacts.');
end

execPath = fullfile(runRoot, 'execution_status.csv');
if exist(execPath, 'file') == 2
    ex = readtable(execPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    vn = string(ex.Properties.VariableNames);
    if any(vn == "EXECUTION_STATUS")
        if upper(strtrim(ex.EXECUTION_STATUS(1))) ~= "SUCCESS"
            error('run_switching_kappa3_amplitude_anatomy_audit:CanonicalNotSuccess', ...
                'Canonical execution status is not SUCCESS.');
        end
    elseif any(vn == "WRITE_SUCCESS")
        if upper(strtrim(ex.WRITE_SUCCESS(1))) ~= "YES"
            error('run_switching_kappa3_amplitude_anatomy_audit:CanonicalWriteFail', ...
                'Canonical WRITE_SUCCESS is not YES.');
        end
    end
end

ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'phi1_shape')));
validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));
sLong = readtable(sLongPath);
phi1Tbl = readtable(phi1Path);
ampTbl = readtable(ampPath);

% -------------------- Reconstruct locked hierarchy --------------------
T = double(sLong.T_K); I = double(sLong.current_mA);
S = double(sLong.S_percent); B = double(sLong.S_model_pt_percent); C = double(sLong.CDF_pt);
v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B) & isfinite(C);
T = T(v); I = I(v); S = S(v); B = B(v); C = C(v);
G = groupsummary(table(T, I, S, B, C), {'T', 'I'}, 'mean', {'S', 'B', 'C'});
allT = unique(double(G.T), 'sorted');
allI = unique(double(G.I), 'sorted');
nT = numel(allT); nI = numel(allI);
Smap = NaN(nT, nI); Bmap = NaN(nT, nI); Cmap = NaN(nT, nI);
for it = 1:nT
    for ii = 1:nI
        m = abs(double(G.T) - allT(it)) < 1e-9 & abs(double(G.I) - allI(ii)) < 1e-9;
        if any(m)
            j = find(m, 1);
            Smap(it, ii) = double(G.mean_S(j));
            Bmap(it, ii) = double(G.mean_B(j));
            Cmap(it, ii) = double(G.mean_C(j));
        end
    end
end

phiVars = string(phi1Tbl.Properties.VariableNames);
iPhi1 = find(strcmpi(phiVars, "phi1") | strcmpi(phiVars, "Phi1"), 1);
phi1 = interp1(double(phi1Tbl.current_mA), double(phi1Tbl{:, iPhi1}), allI, 'linear', 'extrap');
phi1 = phi1(:); phi1(~isfinite(phi1)) = 0;
if norm(phi1) > 0, phi1 = phi1 / norm(phi1); end

kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

pred0 = Bmap;
pred1 = pred0 - kappa1(:) * phi1(:)';
R1 = Smap - pred1;
R1z = R1; R1z(~isfinite(R1z)) = 0;
[~, ~, V1] = svd(R1z, 'econ');
if isempty(V1), phi2 = zeros(nI, 1); else, phi2 = V1(:, 1); end
if norm(phi2) > 0, phi2 = phi2 / norm(phi2); end

pred2 = pred1 + kappa2(:) * phi2(:)';
R2 = Smap - pred2;
R2z = R2; R2z(~isfinite(R2z)) = 0;
[~, ~, V2] = svd(R2z, 'econ');
if isempty(V2), phi3 = zeros(nI, 1); else, phi3 = V2(:, 1); end
if norm(phi3) > 0, phi3 = phi3 / norm(phi3); end
kappa3_diag = R2z * phi3;

rmseR1 = sqrt(mean(R1.^2, 2, 'omitnan'));
rmseR2 = sqrt(mean(R2.^2, 2, 'omitnan'));

cdfAxis = mean(Cmap, 1, 'omitnan');
if any(~isfinite(cdfAxis))
    cdfAxis = fillmissing(cdfAxis, 'linear', 'EndValues', 'nearest');
end
tailMask = cdfAxis >= 0.80;
midMask = cdfAxis > 0.40 & cdfAxis < 0.60;
if ~any(midMask), midMask = cdfAxis > 0.25 & cdfAxis < 0.75; end

R0 = Smap - Bmap;
tail_burden_ratio = mean(R0(:, tailMask).^2, 2, 'omitnan') ./ max(mean(R0(:, midMask).^2, 2, 'omitnan'), eps);
high_CDF_tail_weight = NaN(nT, 1);
symmetry_cdf_mirror = NaN(nT, 1);
for it = 1:nT
    y = Smap(it, :);
    xI = allI(:)';
    xC = Cmap(it, :);
    m = isfinite(y) & isfinite(xI) & isfinite(xC);
    y = y(m); xI = xI(m); xC = xC(m);
    if numel(y) < 4
        continue;
    end
    [xI, ord] = sort(xI, 'ascend');
    y = y(ord); xC = xC(ord);
    hi = xC >= 0.8;
    if sum(hi) >= 2
        high_CDF_tail_weight(it) = trapz(xI(hi), y(hi));
    end
    grid = linspace(0.1, 0.9, 9);
    sv = NaN(size(grid));
    for ic = 1:numel(grid)
        c1 = grid(ic); c2 = 1 - c1;
        [d1, i1] = min(abs(xC - c1));
        [d2, i2] = min(abs(xC - c2));
        if d1 < 0.15 && d2 < 0.15
            sv(ic) = y(i2) - y(i1);
        end
    end
    symmetry_cdf_mirror(it) = mean(abs(sv), 'omitnan');
end

S_peak = max(Smap, [], 2, 'omitnan');

distance_to_31p5K = abs(allT(:) - 31.5);
transition_flag_28_32K = double(allT(:) >= 28 & allT(:) <= 32);
edge_flag = double(allT(:) == min(allT) | allT(:) == max(allT));

% ------------------------- Feature matrix -------------------------
F = table();
F.T_K = allT(:);
F.kappa3_diag = kappa3_diag(:);
F.abs_kappa3_diag = abs(kappa3_diag(:));
F.kappa1 = kappa1(:);
F.abs_kappa1 = abs(kappa1(:));
F.kappa2 = kappa2(:);
F.abs_kappa2 = abs(kappa2(:));
F.S_peak = S_peak(:);
F.tail_burden_ratio = tail_burden_ratio(:);
F.high_CDF_tail_weight = high_CDF_tail_weight(:);
F.symmetry_cdf_mirror = symmetry_cdf_mirror(:);
F.rmse_R1 = rmseR1(:);
F.rmse_R2 = rmseR2(:);
F.distance_to_31p5K = distance_to_31p5K(:);
F.transition_flag_28_32K = transition_flag_28_32K(:);
F.edge_flag = edge_flag(:);

% -------------------- Pairwise Pearson / Spearman -------------------
pairVars = { ...
    'kappa3_diag','abs_kappa3_diag','kappa1','abs_kappa1','kappa2','abs_kappa2','S_peak', ...
    'tail_burden_ratio','high_CDF_tail_weight','symmetry_cdf_mirror','rmse_R1','rmse_R2', ...
    'distance_to_31p5K','transition_flag_28_32K','edge_flag','T_K'};

rowsCorr = table();
for i = 1:numel(pairVars)
    for j = i+1:numel(pairVars)
        a = F.(pairVars{i}); b = F.(pairVars{j});
        m = isfinite(a) & isfinite(b);
        if sum(m) >= 3
            rp = corr(a(m), b(m), 'Type', 'Pearson');
            rs = corr(a(m), b(m), 'Type', 'Spearman');
        else
            rp = NaN; rs = NaN;
        end
        rowsCorr = [rowsCorr; table(string(pairVars{i}), string(pairVars{j}), rp, rs, sum(m), ...
            'VariableNames', {'var_x','var_y','pearson','spearman','n'})]; %#ok<AGROW>
    end
end
writetable(rowsCorr, outCorr);

% ------------------------- Partial correlations -------------------------
% Pearson partial via residualization.
rowsPart = table();
rowsPart = [rowsPart; partialRow(F, 'kappa3_diag', 'kappa2', {'distance_to_31p5K'}, 'signed')];
rowsPart = [rowsPart; partialRow(F, 'kappa3_diag', 'distance_to_31p5K', {'kappa2'}, 'signed')];
rowsPart = [rowsPart; partialRow(F, 'kappa3_diag', 'kappa1', {'kappa2','distance_to_31p5K'}, 'signed')];
rowsPart = [rowsPart; partialRow(F, 'kappa3_diag', 'S_peak', {'kappa2','distance_to_31p5K'}, 'signed')];
rowsPart = [rowsPart; partialRow(F, 'kappa3_diag', 'tail_burden_ratio', {'distance_to_31p5K'}, 'signed')];
rowsPart = [rowsPart; partialRow(F, 'kappa3_diag', 'high_CDF_tail_weight', {'distance_to_31p5K'}, 'signed')];
rowsPart = [rowsPart; partialRow(F, 'kappa3_diag', 'symmetry_cdf_mirror', {'distance_to_31p5K'}, 'signed')];
rowsPart = [rowsPart; partialRow(F, 'abs_kappa3_diag', 'abs_kappa2', {'distance_to_31p5K'}, 'abs')];
rowsPart = [rowsPart; partialRow(F, 'abs_kappa3_diag', 'abs_kappa1', {'abs_kappa2','distance_to_31p5K'}, 'abs')];
rowsPart = [rowsPart; partialRow(F, 'abs_kappa3_diag', 'S_peak', {'abs_kappa2','distance_to_31p5K'}, 'abs')];
rowsPart = [rowsPart; partialRow(F, 'abs_kappa3_diag', 'tail_burden_ratio', {'distance_to_31p5K'}, 'abs')];
rowsPart = [rowsPart; partialRow(F, 'abs_kappa3_diag', 'high_CDF_tail_weight', {'distance_to_31p5K'}, 'abs')];
rowsPart = [rowsPart; partialRow(F, 'abs_kappa3_diag', 'symmetry_cdf_mirror', {'distance_to_31p5K'}, 'abs')];
writetable(rowsPart, outPart);

% ---------------------- Explanatory models + LOOCV ----------------------
models = { ...
    'kappa3~distance', 'kappa3_diag', {'distance_to_31p5K'}; ...
    'kappa3~transition_flag', 'kappa3_diag', {'transition_flag_28_32K'}; ...
    'kappa3~kappa2', 'kappa3_diag', {'kappa2'}; ...
    'kappa3~kappa1', 'kappa3_diag', {'kappa1'}; ...
    'kappa3~S_peak', 'kappa3_diag', {'S_peak'}; ...
    'kappa3~kappa2+distance', 'kappa3_diag', {'kappa2','distance_to_31p5K'}; ...
    'kappa3~kappa1+kappa2+distance', 'kappa3_diag', {'kappa1','kappa2','distance_to_31p5K'}; ...
    'abs_kappa3~abs_kappa2+distance', 'abs_kappa3_diag', {'abs_kappa2','distance_to_31p5K'}; ...
    'abs_kappa3~abs_kappa1+abs_kappa2+distance', 'abs_kappa3_diag', {'abs_kappa1','abs_kappa2','distance_to_31p5K'} ...
    };

rowsModel = table();
for i = 1:size(models, 1)
    label = string(models{i, 1});
    yName = string(models{i, 2});
    xNames = string(models{i, 3});
    [r2, rmse, loocvRmse, n] = fitAndLoocv(F, yName, xNames);
    rowsModel = [rowsModel; table(label, yName, strjoin(xNames, '+'), r2, rmse, loocvRmse, n, ...
        'VariableNames', {'model_id','target','predictors','fit_r2','fit_rmse','loocv_rmse','n'})]; %#ok<AGROW>
end
writetable(rowsModel, outModels);

% ------------------------- Domain robustness -------------------------
domains = { ...
    'full_domain'; ...
    'exclude_28_32K'; ...
    'transition_only_28_32K'; ...
    'exclude_edge_temperatures'; ...
    'exclude_32K_only'};

rowsDom = table();
for i = 1:numel(domains)
    dom = string(domains{i});
    M = domainMask(F.T_K, F.edge_flag, dom);
    [rK2, pK2, n1] = corrInMask(F.kappa3_diag, F.kappa2, M);
    [rDist, pDist, n2] = corrInMask(F.kappa3_diag, F.distance_to_31p5K, M);
    [rAbsK2, pAbsK2, n3] = corrInMask(F.abs_kappa3_diag, F.abs_kappa2, M);
    [r2m, rmsem, loocvm, nm] = fitAndLoocv(F(M, :), "kappa3_diag", ["kappa2","distance_to_31p5K"]);
    rowsDom = [rowsDom; table(dom, rK2, pK2, rDist, pDist, rAbsK2, pAbsK2, r2m, rmsem, loocvm, min([n1,n2,n3,nm]), ...
        'VariableNames', {'domain','spearman_kappa3_vs_kappa2','pearson_kappa3_vs_kappa2','spearman_kappa3_vs_distance', ...
        'pearson_kappa3_vs_distance','spearman_abs_kappa3_vs_abs_kappa2','pearson_abs_kappa3_vs_abs_kappa2', ...
        'model_r2_kappa2_plus_distance','model_rmse_kappa2_plus_distance','model_loocv_rmse_kappa2_plus_distance','n'})]; %#ok<AGROW>
end
writetable(rowsDom, outDom);

% ----------------------------- Verdicts ------------------------------
pcK2 = getPartial(rowsPart, "kappa3_diag", "kappa2");
pcDist = getPartial(rowsPart, "kappa3_diag", "distance_to_31p5K");
pcK1 = getPartial(rowsPart, "kappa3_diag", "kappa1");
pcSPeak = getPartial(rowsPart, "kappa3_diag", "S_peak");
pcTail = max(abs([ ...
    getPartial(rowsPart, "kappa3_diag", "tail_burden_ratio"), ...
    getPartial(rowsPart, "kappa3_diag", "high_CDF_tail_weight")]));
pcAsym = abs(getPartial(rowsPart, "kappa3_diag", "symmetry_cdf_mirror"));
pcRes = max(abs([ ...
    corr(F.kappa3_diag, F.rmse_R2, 'Type', 'Spearman', 'Rows', 'complete'), ...
    corr(F.kappa3_diag, F.rmse_R1, 'Type', 'Spearman', 'Rows', 'complete')]));

r2Dist = getModel(rowsModel, "kappa3~distance", "fit_r2");
r2K2 = getModel(rowsModel, "kappa3~kappa2", "fit_r2");
r2Mix = getModel(rowsModel, "kappa3~kappa2+distance", "fit_r2");

scores = [abs(pcDist), abs(pcK2), abs(pcK1), abs(pcSPeak), pcTail, pcAsym, pcRes];
labels = ["transition","kappa2","kappa1","S_peak","tail","asymmetry","residual"];
[mx, imx] = max(scores);
if sum(scores >= max(0.9*mx, 0.20)) >= 2
    KAPPA3_PRIMARY_DRIVER = "mixed";
else
    KAPPA3_PRIMARY_DRIVER = labels(imx);
end

KAPPA3_COUPLED_TO_KAPPA2 = ynp(abs(pcK2) >= 0.35 || r2K2 >= 0.35, abs(pcK2) >= 0.20 || r2K2 >= 0.20);
KAPPA3_TRANSITION_DOMINATED = ynp(abs(pcDist) >= 0.40 || r2Dist >= 0.40, abs(pcDist) >= 0.20 || r2Dist >= 0.20);

mainDom = rowsDom(rowsDom.domain=="exclude_28_32K", :);
if isempty(mainDom), mainVal = NaN; else, mainVal = abs(mainDom.spearman_kappa3_vs_kappa2(1)); end
KAPPA3_HAS_MAIN_DOMAIN_SIGNAL = ynp(mainVal >= 0.30, mainVal >= 0.15);

KAPPA3_REDUCIBLE_TO_TRANSITION_DISTANCE = ynp(r2Dist >= 0.70 && abs(pcK2) < 0.15, r2Dist >= 0.45 && abs(pcK2) < 0.25);
KAPPA3_IS_LOW_MODE_AMPLITUDE_COUPLED = ynp((abs(pcK1) >= 0.30 || abs(pcK2) >= 0.30) && r2Mix >= 0.45, ...
                                           (abs(pcK1) >= 0.20 || abs(pcK2) >= 0.20));

if KAPPA3_REDUCIBLE_TO_TRANSITION_DISTANCE == "YES" && KAPPA3_HAS_MAIN_DOMAIN_SIGNAL == "NO"
    KAPPA3_SHOULD_REMAIN_DIAGNOSTIC = "YES";
elseif KAPPA3_IS_LOW_MODE_AMPLITUDE_COUPLED == "YES" && KAPPA3_TRANSITION_DOMINATED == "NO"
    KAPPA3_SHOULD_REMAIN_DIAGNOSTIC = "PARTIAL";
else
    KAPPA3_SHOULD_REMAIN_DIAGNOSTIC = "YES";
end

% ------------------------------ Report -------------------------------
lines = {};
lines{end+1} = '# Switching canonical kappa3 amplitude-anatomy audit';
lines{end+1} = '';
lines{end+1} = '## Scope and gate';
lines{end+1} = sprintf('- CANONICAL_RUN_ID: `%s`', canonicalRunId);
lines{end+1} = '- Evidence gate checks passed (all required YES).';
lines{end+1} = '- Hierarchy preserved: backbone -> Phi1/kappa1 -> Phi2/kappa2 -> diagnostic Phi3/kappa3_diag.';
lines{end+1} = '- Failed Phi2 replacement audit not used.';
lines{end+1} = '';
lines{end+1} = sprintf('## Per-temperature feature matrix n=%d', height(F));
lines{end+1} = '- Includes requested fields: kappa3_diag, abs(kappa3_diag), kappa1/abs, kappa2/abs, S_peak, tail/high-CDF/asymmetry, rmse_R1/R2, distance, transition flag, edge flag, T_K.';
lines{end+1} = '';
lines{end+1} = '## Key partial correlations';
for i = 1:height(rowsPart)
    lines{end+1} = sprintf('- `%s` vs `%s` | controls `%s`: partial=%.4f (n=%d)', ...
        rowsPart.target(i), rowsPart.feature(i), rowsPart.controls(i), rowsPart.partial_corr(i), rowsPart.n(i));
end
lines{end+1} = '';
lines{end+1} = '## LOOCV model summary';
for i = 1:height(rowsModel)
    lines{end+1} = sprintf('- `%s`: R2=%.4f, RMSE=%.4f, LOOCV RMSE=%.4f', ...
        rowsModel.model_id(i), rowsModel.fit_r2(i), rowsModel.fit_rmse(i), rowsModel.loocv_rmse(i));
end
lines{end+1} = '';
lines{end+1} = '## Domain robustness (`kappa3 ~ kappa2 + distance`)';
for i = 1:height(rowsDom)
    lines{end+1} = sprintf('- `%s`: Spearman(k3,k2)=%.4f, Spearman(k3,dist)=%.4f, model R2=%.4f', ...
        rowsDom.domain(i), rowsDom.spearman_kappa3_vs_kappa2(i), rowsDom.spearman_kappa3_vs_distance(i), rowsDom.model_r2_kappa2_plus_distance(i));
end
lines{end+1} = '';
lines{end+1} = '## Final verdicts';
lines{end+1} = sprintf('- KAPPA3_PRIMARY_DRIVER = %s', KAPPA3_PRIMARY_DRIVER);
lines{end+1} = sprintf('- KAPPA3_COUPLED_TO_KAPPA2 = %s', KAPPA3_COUPLED_TO_KAPPA2);
lines{end+1} = sprintf('- KAPPA3_TRANSITION_DOMINATED = %s', KAPPA3_TRANSITION_DOMINATED);
lines{end+1} = sprintf('- KAPPA3_HAS_MAIN_DOMAIN_SIGNAL = %s', KAPPA3_HAS_MAIN_DOMAIN_SIGNAL);
lines{end+1} = sprintf('- KAPPA3_REDUCIBLE_TO_TRANSITION_DISTANCE = %s', KAPPA3_REDUCIBLE_TO_TRANSITION_DISTANCE);
lines{end+1} = sprintf('- KAPPA3_IS_LOW_MODE_AMPLITUDE_COUPLED = %s', KAPPA3_IS_LOW_MODE_AMPLITUDE_COUPLED);
lines{end+1} = sprintf('- KAPPA3_SHOULD_REMAIN_DIAGNOSTIC = %s', KAPPA3_SHOULD_REMAIN_DIAGNOSTIC);
lines{end+1} = '';
lines{end+1} = '## Outputs';
lines{end+1} = '- `tables/switching_kappa3_amplitude_correlations.csv`';
lines{end+1} = '- `tables/switching_kappa3_partial_correlations.csv`';
lines{end+1} = '- `tables/switching_kappa3_explanatory_models.csv`';
lines{end+1} = '- `tables/switching_kappa3_domain_robustness.csv`';

switchingWriteTextLinesFile(outRep, lines, 'run_switching_kappa3_amplitude_anatomy_audit:WriteFail');
fprintf('[DONE] switching kappa3 amplitude anatomy audit -> %s\n', outRep);

function row = partialRow(F, target, feat, controls, variant)
y = F.(target); x = F.(feat);
Z = ones(height(F), 1);
for i = 1:numel(controls)
    Z = [Z, F.(controls{i})]; %#ok<AGROW>
end
m = isfinite(y) & isfinite(x) & all(isfinite(Z), 2);
n = sum(m);
if n < size(Z, 2) + 2 || std(y(m)) == 0 || std(x(m)) == 0
    p = NaN;
else
    ym = y(m) - Z(m, :) * (Z(m, :) \ y(m));
    xm = x(m) - Z(m, :) * (Z(m, :) \ x(m));
    if std(ym) == 0 || std(xm) == 0
        p = NaN;
    else
        p = corr(ym, xm, 'Type', 'Pearson', 'Rows', 'complete');
    end
end
row = table(string(target), string(feat), string(strjoin(string(controls), '+')), string(variant), p, n, ...
    'VariableNames', {'target','feature','controls','variant','partial_corr','n'});
end

function [rS, rP, n] = corrInMask(a, b, mask)
m = isfinite(a) & isfinite(b) & mask;
n = sum(m);
if n >= 3
    rS = corr(a(m), b(m), 'Type', 'Spearman');
    rP = corr(a(m), b(m), 'Type', 'Pearson');
else
    rS = NaN; rP = NaN;
end
end

function [r2, rmse, loocvRmse, n] = fitAndLoocv(F, yName, xNames)
y = F.(yName);
X = [];
for i = 1:numel(xNames)
    X = [X, F.(xNames(i))]; %#ok<AGROW>
end
m = isfinite(y) & all(isfinite(X), 2);
y = y(m); X = X(m, :);
n = numel(y);
if n < size(X, 2) + 2
    r2 = NaN; rmse = NaN; loocvRmse = NaN; return;
end
X1 = [ones(n,1), X];
b = X1 \ y;
yhat = X1 * b;
sse = sum((y - yhat).^2);
sst = sum((y - mean(y)).^2);
r2 = 1 - sse / max(sst, eps);
rmse = sqrt(mean((y - yhat).^2));

e = NaN(n,1);
for i = 1:n
    tr = true(n,1); tr(i) = false;
    if sum(tr) < size(X1, 2)
        continue;
    end
    bi = X1(tr, :) \ y(tr);
    e(i) = y(i) - X1(i, :) * bi;
end
loocvRmse = sqrt(mean(e.^2, 'omitnan'));
end

function m = domainMask(T, edgeFlag, domain)
switch char(domain)
    case 'full_domain'
        m = true(size(T));
    case 'exclude_28_32K'
        m = ~(T >= 28 & T <= 32);
    case 'transition_only_28_32K'
        m = (T >= 28 & T <= 32);
    case 'exclude_edge_temperatures'
        m = edgeFlag == 0;
    case 'exclude_32K_only'
        m = abs(T - 32) > 1e-9;
    otherwise
        m = true(size(T));
end
end

function v = getPartial(tbl, target, feature)
m = tbl.target == string(target) & tbl.feature == string(feature);
if any(m)
    v = tbl.partial_corr(find(m, 1));
else
    v = NaN;
end
end

function v = getModel(tbl, modelId, col)
m = tbl.model_id == string(modelId);
if any(m)
    v = tbl.(col)(find(m, 1));
else
    v = NaN;
end
end

function out = ynp(condYes, condPartial)
if condYes
    out = "YES";
elseif condPartial
    out = "PARTIAL";
else
    out = "NO";
end
end
