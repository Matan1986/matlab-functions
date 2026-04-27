clear; clc;

% Canonical kappa3 amplitude-scale sensitivity audit (Switching only).
% Tests whether S_peak driver is specific vs generic scale leakage.

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

outSens = fullfile(repoRoot, 'tables', 'switching_kappa3_amplitude_scale_sensitivity.csv');
outModels = fullfile(repoRoot, 'tables', 'switching_kappa3_scale_control_models.csv');
outPart = fullfile(repoRoot, 'tables', 'switching_kappa3_scale_partial_correlations.csv');
outRep = fullfile(repoRoot, 'reports', 'switching_kappa3_amplitude_scale_sensitivity.md');

% ------------------------ Evidence gate ------------------------
gatePath = fullfile(repoRoot, 'tables', 'switching_mode_evidence_certification_status.csv');
if exist(gatePath, 'file') ~= 2
    error('run_switching_kappa3_amplitude_scale_sensitivity_audit:MissingGate', 'Missing gate table.');
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
        error('run_switching_kappa3_amplitude_scale_sensitivity_audit:GateFailed', ...
            'Evidence gate failed at %s.', checks{i});
    end
end

priorPartPath = fullfile(repoRoot, 'tables', 'switching_kappa3_partial_correlations.csv');
priorModelPath = fullfile(repoRoot, 'tables', 'switching_kappa3_explanatory_models.csv');
if exist(priorPartPath, 'file') ~= 2 || exist(priorModelPath, 'file') ~= 2
    error('run_switching_kappa3_amplitude_scale_sensitivity_audit:MissingPriorAudit', ...
        'Required prior kappa3 anatomy outputs are missing.');
end

% --------------------- Canonical lock + inputs ---------------------
idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
if exist(idPath, 'file') ~= 2 || exist(ampPath, 'file') ~= 2
    error('run_switching_kappa3_amplitude_scale_sensitivity_audit:MissingIdentityAmp', ...
        'Missing identity or amplitudes tables.');
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
    error('run_switching_kappa3_amplitude_scale_sensitivity_audit:MissingRunId', 'CANONICAL_RUN_ID missing.');
end
runRoot = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId));
sLongPath = fullfile(runRoot, 'tables', 'switching_canonical_S_long.csv');
phi1Path = fullfile(runRoot, 'tables', 'switching_canonical_phi1.csv');
if exist(sLongPath, 'file') ~= 2 || exist(phi1Path, 'file') ~= 2
    error('run_switching_kappa3_amplitude_scale_sensitivity_audit:MissingCanonicalInputs', ...
        'Missing canonical S_long or phi1 table.');
end

ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'phi1_shape')));
validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

sLong = readtable(sLongPath);
phi1Tbl = readtable(phi1Path);
ampTbl = readtable(ampPath);

% --------------------- Locked hierarchy + proxies ---------------------
T = double(sLong.T_K); I = double(sLong.current_mA);
S = double(sLong.S_percent); B = double(sLong.S_model_pt_percent); C = double(sLong.CDF_pt);
v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B) & isfinite(C);
T = T(v); I = I(v); S = S(v); B = B(v); C = C(v);
G = groupsummary(table(T, I, S, B, C), {'T', 'I'}, 'mean', {'S', 'B', 'C'});
allT = unique(double(G.T), 'sorted');
allI = unique(double(G.I), 'sorted');
nT = numel(allT); nI = numel(allI);
Smap = NaN(nT, nI); Bmap = NaN(nT, nI);
for it = 1:nT
    for ii = 1:nI
        m = abs(double(G.T) - allT(it)) < 1e-9 & abs(double(G.I) - allI(ii)) < 1e-9;
        if any(m)
            j = find(m, 1);
            Smap(it, ii) = double(G.mean_S(j));
            Bmap(it, ii) = double(G.mean_B(j));
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

S_peak = max(Smap, [], 2, 'omitnan');
S_peak_z = (S_peak - mean(S_peak, 'omitnan')) / max(std(S_peak, 'omitnan'), eps);
medS = median(S_peak, 'omitnan');
madS = median(abs(S_peak - medS), 'omitnan');
S_peak_robust_z = (S_peak - medS) / max(1.4826 * madS, eps);
if all(abs(S_peak) > 0)
    log_abs_S_peak = log(abs(S_peak));
else
    log_abs_S_peak = NaN(size(S_peak));
end

total_map_row_norm = sqrt(sum(Smap.^2, 2, 'omitnan'));
pt_backbone_row_norm = sqrt(sum(Bmap.^2, 2, 'omitnan'));
R1_row_norm = sqrt(sum(R1.^2, 2, 'omitnan'));
R2_row_norm = sqrt(sum(R2.^2, 2, 'omitnan'));
residual_energy_ratio_R2_over_R1 = (R2_row_norm.^2) ./ max(R1_row_norm.^2, eps);
distance_to_31p5K = abs(allT(:) - 31.5);

F = table();
F.T_K = allT(:);
F.kappa3_diag = kappa3_diag(:);
F.abs_kappa3_diag = abs(kappa3_diag(:));
F.kappa2 = kappa2(:);
F.abs_kappa2 = abs(kappa2(:));
F.kappa1 = kappa1(:);
F.abs_kappa1 = abs(kappa1(:));
F.distance_to_31p5K = distance_to_31p5K(:);
F.S_peak = S_peak(:);
F.S_peak_z = S_peak_z(:);
F.S_peak_robust_z = S_peak_robust_z(:);
F.log_abs_S_peak = log_abs_S_peak(:);
F.total_map_row_norm = total_map_row_norm(:);
F.pt_backbone_row_norm = pt_backbone_row_norm(:);
F.R1_row_norm = R1_row_norm(:);
F.R2_row_norm = R2_row_norm(:);
F.residual_energy_ratio_R2_over_R1 = residual_energy_ratio_R2_over_R1(:);

% -------- Sensitivity table: each proxy vs kappa3 signed and abs --------
proxyNames = ["S_peak","S_peak_z","S_peak_robust_z","log_abs_S_peak","total_map_row_norm", ...
              "pt_backbone_row_norm","R1_row_norm","R2_row_norm","residual_energy_ratio_R2_over_R1","kappa1","abs_kappa1"];
rowsSens = table();
for i = 1:numel(proxyNames)
    x = F.(proxyNames(i));
    [spS, prS, nS] = corrPair(F.kappa3_diag, x);
    [spA, prA, nA] = corrPair(F.abs_kappa3_diag, x);
    rowsSens = [rowsSens; table(proxyNames(i), spS, prS, nS, spA, prA, nA, ...
        'VariableNames', {'proxy','spearman_kappa3','pearson_kappa3','n_signed','spearman_abs_kappa3','pearson_abs_kappa3','n_abs'})]; %#ok<AGROW>
end
writetable(rowsSens, outSens);

% --------------------- Partial correlations (scale controls) ---------------------
rowsPart = table();
rowsPart = [rowsPart; partialRow(F, 'kappa3_diag', 'S_peak', {'kappa1','R1_row_norm','R2_row_norm','distance_to_31p5K','kappa2'}, 'signed')];
rowsPart = [rowsPart; partialRow(F, 'kappa3_diag', 'S_peak_z', {'kappa1','R1_row_norm','R2_row_norm','distance_to_31p5K','kappa2'}, 'signed')];
rowsPart = [rowsPart; partialRow(F, 'kappa3_diag', 'R2_row_norm', {'kappa1','distance_to_31p5K','kappa2'}, 'signed')];
rowsPart = [rowsPart; partialRow(F, 'kappa3_diag', 'residual_energy_ratio_R2_over_R1', {'kappa1','distance_to_31p5K','kappa2'}, 'signed')];
rowsPart = [rowsPart; partialRow(F, 'abs_kappa3_diag', 'S_peak', {'abs_kappa1','R1_row_norm','R2_row_norm','distance_to_31p5K','abs_kappa2'}, 'abs')];
rowsPart = [rowsPart; partialRow(F, 'abs_kappa3_diag', 'R2_row_norm', {'abs_kappa1','distance_to_31p5K','abs_kappa2'}, 'abs')];
rowsPart = [rowsPart; partialRow(F, 'abs_kappa3_diag', 'residual_energy_ratio_R2_over_R1', {'abs_kappa1','distance_to_31p5K','abs_kappa2'}, 'abs')];
writetable(rowsPart, outPart);

% ------------------------- Scale-control LOOCV models -------------------------
modelDefs = { ...
    'kappa3~S_peak', 'kappa3_diag', {'S_peak'}; ...
    'kappa3~kappa1', 'kappa3_diag', {'kappa1'}; ...
    'kappa3~row_norm', 'kappa3_diag', {'total_map_row_norm'}; ...
    'kappa3~residual_energy', 'kappa3_diag', {'residual_energy_ratio_R2_over_R1'}; ...
    'kappa3~S_peak+distance', 'kappa3_diag', {'S_peak','distance_to_31p5K'}; ...
    'kappa3~S_peak+kappa2', 'kappa3_diag', {'S_peak','kappa2'}; ...
    'kappa3~scale_proxy+distance+kappa2', 'kappa3_diag', {'R2_row_norm','distance_to_31p5K','kappa2'}; ...
    'abs_kappa3~S_peak+distance+kappa2', 'abs_kappa3_diag', {'S_peak','distance_to_31p5K','abs_kappa2'}; ...
    'abs_kappa3~residual_energy+distance+kappa2', 'abs_kappa3_diag', {'residual_energy_ratio_R2_over_R1','distance_to_31p5K','abs_kappa2'} ...
    };
rowsModels = table();
for i = 1:size(modelDefs, 1)
    label = string(modelDefs{i,1});
    yName = string(modelDefs{i,2});
    xNames = string(modelDefs{i,3});
    [r2, rmse, loocv, n] = fitAndLoocv(F, yName, xNames);
    rowsModels = [rowsModels; table(label, yName, strjoin(xNames, '+'), r2, rmse, loocv, n, ...
        'VariableNames', {'model_id','target','predictors','fit_r2','fit_rmse','loocv_rmse','n'})]; %#ok<AGROW>
end
writetable(rowsModels, outModels);

% ------------------------------ Verdicts ------------------------------
pSpeak = getPartial(rowsPart, "kappa3_diag", "S_peak");
pSpeakAbs = getPartial(rowsPart, "abs_kappa3_diag", "S_peak");
pR2 = getPartial(rowsPart, "kappa3_diag", "R2_row_norm");
pR2abs = getPartial(rowsPart, "abs_kappa3_diag", "R2_row_norm");
pRes = getPartial(rowsPart, "kappa3_diag", "residual_energy_ratio_R2_over_R1");
pResAbs = getPartial(rowsPart, "abs_kappa3_diag", "residual_energy_ratio_R2_over_R1");

rSpeak = getModel(rowsModels, "kappa3~S_peak", "fit_r2");
rScale = getModel(rowsModels, "kappa3~row_norm", "fit_r2");
rRes = getModel(rowsModels, "kappa3~residual_energy", "fit_r2");
rSpeakCtl = getModel(rowsModels, "kappa3~S_peak+kappa2", "fit_r2");
rScaleCtl = getModel(rowsModels, "kappa3~scale_proxy+distance+kappa2", "fit_r2");
rResCtlAbs = getModel(rowsModels, "abs_kappa3~residual_energy+distance+kappa2", "fit_r2");
rSpeakCtlAbs = getModel(rowsModels, "abs_kappa3~S_peak+distance+kappa2", "fit_r2");

% S_peak stable only if controlled partial stays nontrivial and outperforms generic scale.
speakStableYes = (abs(pSpeak) >= 0.30 || abs(pSpeakAbs) >= 0.30) && (rSpeakCtl >= rScaleCtl - 0.05);
speakStablePartial = (abs(pSpeak) >= 0.18 || abs(pSpeakAbs) >= 0.18);
KAPPA3_SPEAK_DRIVER_STABLE = ynp(speakStableYes, speakStablePartial);

genericScaleYes = (rScale >= rSpeak + 0.10 || rScaleCtl >= rSpeakCtl + 0.10) && ...
                  max(abs([pR2, pR2abs])) >= max(abs([pSpeak, pSpeakAbs])) - 0.05;
genericScalePartial = (rScale >= rSpeak) || (max(abs([pR2, pR2abs])) >= 0.20);
KAPPA3_DRIVER_IS_GENERIC_SCALE = ynp(genericScaleYes, genericScalePartial);

resEnergyYes = (rRes >= rSpeak + 0.10 || rResCtlAbs >= rSpeakCtlAbs + 0.10) && max(abs([pRes, pResAbs])) >= 0.30;
resEnergyPartial = (rRes >= rSpeak) || (max(abs([pRes, pResAbs])) >= 0.20);
KAPPA3_DRIVER_IS_RESIDUAL_ENERGY = ynp(resEnergyYes, resEnergyPartial);

if KAPPA3_DRIVER_IS_GENERIC_SCALE == "YES" || KAPPA3_DRIVER_IS_RESIDUAL_ENERGY == "YES"
    KAPPA3_SCALE_LEAKAGE_RISK = "YES";
elseif KAPPA3_DRIVER_IS_GENERIC_SCALE == "PARTIAL" || KAPPA3_DRIVER_IS_RESIDUAL_ENERGY == "PARTIAL"
    KAPPA3_SCALE_LEAKAGE_RISK = "PARTIAL";
else
    KAPPA3_SCALE_LEAKAGE_RISK = "NO";
end

if KAPPA3_SPEAK_DRIVER_STABLE == "YES" && KAPPA3_SCALE_LEAKAGE_RISK == "NO"
    KAPPA3_INTERPRETATION_AFTER_SCALE_TEST = "S_peak_specific";
elseif KAPPA3_DRIVER_IS_RESIDUAL_ENERGY == "YES"
    KAPPA3_INTERPRETATION_AFTER_SCALE_TEST = "residual_energy";
elseif KAPPA3_DRIVER_IS_GENERIC_SCALE == "YES"
    KAPPA3_INTERPRETATION_AFTER_SCALE_TEST = "generic_scale";
elseif KAPPA3_SCALE_LEAKAGE_RISK == "PARTIAL"
    KAPPA3_INTERPRETATION_AFTER_SCALE_TEST = "mixed";
else
    KAPPA3_INTERPRETATION_AFTER_SCALE_TEST = "unresolved";
end

if KAPPA3_INTERPRETATION_AFTER_SCALE_TEST == "S_peak_specific" && KAPPA3_SCALE_LEAKAGE_RISK == "NO"
    KAPPA3_SHOULD_REMAIN_DIAGNOSTIC = "PARTIAL";
else
    KAPPA3_SHOULD_REMAIN_DIAGNOSTIC = "YES";
end

% ------------------------------ Report ------------------------------
lines = {};
lines{end+1} = '# Switching canonical kappa3 amplitude-scale sensitivity audit';
lines{end+1} = '';
lines{end+1} = '## Scope and gate';
lines{end+1} = sprintf('- CANONICAL_RUN_ID: `%s`', canonicalRunId);
lines{end+1} = '- Uses prior kappa3 anatomy outputs and certified canonical evidence gate.';
lines{end+1} = '- Decomposition unchanged; failed Phi2 replacement audit excluded.';
lines{end+1} = '';
lines{end+1} = sprintf('## Proxy matrix n=%d', height(F));
lines{end+1} = '- Proxies include S_peak variants, map/backbone/residual norms, residual-energy ratio, and kappa1 scale terms.';
lines{end+1} = '';
lines{end+1} = '## Partial correlations (scale-controlled)';
for i = 1:height(rowsPart)
    lines{end+1} = sprintf('- `%s` vs `%s` | controls `%s`: partial=%.4f', ...
        rowsPart.target(i), rowsPart.feature(i), rowsPart.controls(i), rowsPart.partial_corr(i));
end
lines{end+1} = '';
lines{end+1} = '## LOOCV model summary';
for i = 1:height(rowsModels)
    lines{end+1} = sprintf('- `%s`: R2=%.4f, LOOCV RMSE=%.4f', rowsModels.model_id(i), rowsModels.fit_r2(i), rowsModels.loocv_rmse(i));
end
lines{end+1} = '';
lines{end+1} = '## Final verdicts';
lines{end+1} = sprintf('- KAPPA3_SPEAK_DRIVER_STABLE = %s', KAPPA3_SPEAK_DRIVER_STABLE);
lines{end+1} = sprintf('- KAPPA3_DRIVER_IS_GENERIC_SCALE = %s', KAPPA3_DRIVER_IS_GENERIC_SCALE);
lines{end+1} = sprintf('- KAPPA3_DRIVER_IS_RESIDUAL_ENERGY = %s', KAPPA3_DRIVER_IS_RESIDUAL_ENERGY);
lines{end+1} = sprintf('- KAPPA3_SCALE_LEAKAGE_RISK = %s', KAPPA3_SCALE_LEAKAGE_RISK);
lines{end+1} = sprintf('- KAPPA3_INTERPRETATION_AFTER_SCALE_TEST = %s', KAPPA3_INTERPRETATION_AFTER_SCALE_TEST);
lines{end+1} = sprintf('- KAPPA3_SHOULD_REMAIN_DIAGNOSTIC = %s', KAPPA3_SHOULD_REMAIN_DIAGNOSTIC);
lines{end+1} = '';
lines{end+1} = '## Outputs';
lines{end+1} = '- `tables/switching_kappa3_amplitude_scale_sensitivity.csv`';
lines{end+1} = '- `tables/switching_kappa3_scale_control_models.csv`';
lines{end+1} = '- `tables/switching_kappa3_scale_partial_correlations.csv`';

switchingWriteTextLinesFile(outRep, lines, 'run_switching_kappa3_amplitude_scale_sensitivity_audit:WriteFail');
fprintf('[DONE] switching kappa3 amplitude-scale sensitivity audit -> %s\n', outRep);

function [rs, rp, n] = corrPair(a, b)
m = isfinite(a) & isfinite(b);
n = sum(m);
if n >= 3
    rs = corr(a(m), b(m), 'Type', 'Spearman');
    rp = corr(a(m), b(m), 'Type', 'Pearson');
else
    rs = NaN; rp = NaN;
end
end

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
        p = corr(ym, xm, 'Type', 'Pearson');
    end
end
row = table(string(target), string(feat), string(strjoin(string(controls), '+')), string(variant), p, n, ...
    'VariableNames', {'target','feature','controls','variant','partial_corr','n'});
end

function [r2, rmse, loocv, n] = fitAndLoocv(F, yName, xNames)
y = F.(yName);
X = [];
for i = 1:numel(xNames)
    X = [X, F.(xNames(i))]; %#ok<AGROW>
end
m = isfinite(y) & all(isfinite(X), 2);
y = y(m); X = X(m, :); n = numel(y);
if n < size(X, 2) + 2
    r2 = NaN; rmse = NaN; loocv = NaN; return;
end
X1 = [ones(n, 1), X];
b = X1 \ y;
yhat = X1 * b;
sse = sum((y - yhat).^2); sst = sum((y - mean(y)).^2);
r2 = 1 - sse / max(sst, eps);
rmse = sqrt(mean((y - yhat).^2));
e = NaN(n, 1);
for i = 1:n
    tr = true(n, 1); tr(i) = false;
    if sum(tr) < size(X1, 2), continue; end
    bi = X1(tr, :) \ y(tr);
    e(i) = y(i) - X1(i, :) * bi;
end
loocv = sqrt(mean(e.^2, 'omitnan'));
end

function v = getPartial(tbl, target, feature)
m = tbl.target == string(target) & tbl.feature == string(feature);
if any(m), v = tbl.partial_corr(find(m, 1)); else, v = NaN; end
end

function v = getModel(tbl, modelId, col)
m = tbl.model_id == string(modelId);
if any(m), v = tbl.(col)(find(m, 1)); else, v = NaN; end
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
