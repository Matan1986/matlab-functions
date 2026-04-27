clear; clc;

% Canonical Switching map-observable dictionary audit.
% Builds canonical observable definitions and per-T features from locked canonical map/hierarchy.

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

outDict = fullfile(repoRoot, 'tables', 'switching_canonical_observable_dictionary.csv');
outFeat = fullfile(repoRoot, 'tables', 'switching_canonical_observable_features_by_T.csv');
outStat = fullfile(repoRoot, 'tables', 'switching_canonical_observable_feature_status.csv');
outRep = fullfile(repoRoot, 'reports', 'switching_canonical_observable_dictionary.md');

% ------------------------------ Inputs + gates ------------------------------
idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
legacyInvPath = fullfile(repoRoot, 'tables', 'switching_legacy_observable_definition_inventory.csv');
legacyPlanPath = fullfile(repoRoot, 'tables', 'switching_observable_definition_porting_plan.csv');
modeGatePath = fullfile(repoRoot, 'tables', 'switching_mode_evidence_certification_status.csv');
ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');

req = {idPath, legacyInvPath, legacyPlanPath, modeGatePath, ampPath};
for i = 1:numel(req)
    if exist(req{i}, 'file') ~= 2
        error('run_switching_canonical_observable_dictionary_audit:MissingInput', ...
            'Missing required input: %s', req{i});
    end
end

gate = readtable(modeGatePath, 'TextType', 'string');
need = { ...
    'MODE_EVIDENCE_CERTIFICATION_COMPLETE', ...
    'FAILED_PHI2_REPLACEMENT_EXCLUDED', ...
    'CRITICAL_MODE_AUDITS_CERTIFIED', ...
    'CANONICAL_ONLY_NEXT_AUDIT_EVIDENCE_AVAILABLE'};
for i = 1:numel(need)
    ix = find(strcmpi(strtrim(gate.check), need{i}), 1);
    if isempty(ix) || upper(strtrim(gate.result(ix))) ~= "YES"
        error('run_switching_canonical_observable_dictionary_audit:GateFailed', ...
            'Evidence gate failed at %s.', need{i});
    end
end

idRaw = readcell(idPath, 'Delimiter', ',');
canonicalRunId = "";
for r = 2:size(idRaw, 1)
    key = strtrim(string(idRaw{r,1}));
    key = regexprep(key, "^\xFEFF", "");
    if strcmpi(key, "CANONICAL_RUN_ID")
        canonicalRunId = strtrim(string(idRaw{r,2}));
        break;
    end
end
if strlength(canonicalRunId) == 0
    error('run_switching_canonical_observable_dictionary_audit:MissingRunId', 'CANONICAL_RUN_ID missing.');
end

runRoot = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId));
sLongPath = fullfile(runRoot, 'tables', 'switching_canonical_S_long.csv');
phi1Path = fullfile(runRoot, 'tables', 'switching_canonical_phi1.csv');
if exist(sLongPath, 'file') ~= 2 || exist(phi1Path, 'file') ~= 2
    error('run_switching_canonical_observable_dictionary_audit:MissingCanonicalTables', ...
        'Missing canonical S_long or phi1 table in locked run.');
end

% Canonical metadata validation for required hierarchy inputs.
ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'phi1_shape')));
validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

sLong = readtable(sLongPath);
phi1Tbl = readtable(phi1Path);
ampTbl = readtable(ampPath);
legacyPlanRaw = readcell(legacyPlanPath, 'Delimiter', ',');

% ------------------------ Reconstruct locked hierarchy -----------------------
T = double(sLong.T_K);
I = double(sLong.current_mA);
S = double(sLong.S_percent);
B = double(sLong.S_model_pt_percent);
C = double(sLong.CDF_pt);
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
if isempty(iPhi1)
    error('run_switching_canonical_observable_dictionary_audit:MissingPhi1Column', 'Phi1 column not found.');
end
phi1 = interp1(double(phi1Tbl.current_mA), double(phi1Tbl{:, iPhi1}), allI, 'linear', 'extrap');
phi1 = phi1(:); phi1(~isfinite(phi1)) = 0;
if norm(phi1) > 0, phi1 = phi1 / norm(phi1); end

kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

pred0 = Bmap;                          % PT-CDF backbone
pred1 = pred0 - kappa1(:) * phi1(:)'; % Phi1/kappa1 layer
R1 = Smap - pred1;                     % level-1 residual
R1z = R1; R1z(~isfinite(R1z)) = 0;
[~, ~, V1] = svd(R1z, 'econ');
if isempty(V1), phi2 = zeros(nI, 1); else, phi2 = V1(:,1); end
if norm(phi2) > 0, phi2 = phi2 / norm(phi2); end
pred2 = pred1 + kappa2(:) * phi2(:)'; % Phi2/kappa2 layer
deltaS = pred0 - Smap;                 % backbone-relative deficit map (backbone - S)

% ---------------------------- Region definitions ----------------------------
cdfAxis = mean(Cmap, 1, 'omitnan');
if any(~isfinite(cdfAxis))
    cdfAxis = fillmissing(cdfAxis, 'linear', 'EndValues', 'nearest');
end

coreMask = cdfAxis >= 0.35 & cdfAxis <= 0.65;
shoulderMask = (cdfAxis > 0.20 & cdfAxis < 0.35) | (cdfAxis > 0.65 & cdfAxis < 0.80);
tailMask = cdfAxis >= 0.80;
if ~any(coreMask), coreMask = cdfAxis > 0.3 & cdfAxis < 0.7; end
if ~any(shoulderMask), shoulderMask = cdfAxis > 0.2 & cdfAxis < 0.8 & ~coreMask; end
if ~any(tailMask), tailMask = cdfAxis >= prctile(cdfAxis, 80); end

[sortedI, ordI] = sort(allI(:), 'ascend');
nHC = min(2, numel(sortedI));
highCurrentMask = false(1, nI);
highCurrentMask(ordI(end-nHC+1:end)) = true;
endpointMask = false(1, nI);
endpointMask(ordI(1)) = true;
endpointMask(ordI(end)) = true;

i45 = find(abs(allI - 45) < 1e-9, 1);
i50 = find(abs(allI - 50) < 1e-9, 1);
has45and50 = ~isempty(i45) && ~isempty(i50);
has40 = any(abs(allI - 40) < 1e-9);

% ---------------------------- Feature computation ----------------------------
F = table();
F.T_K = allT(:);

for it = 1:nT
    rowS = Smap(it, :);
    rowB = Bmap(it, :);
    rowD = deltaS(it, :);
    rowR1 = R1(it, :);
    xi = allI(:)';

    % Raw map
    F.S_peak(it,1) = max(rowS, [], 'omitnan');
    F.S_tail_mean(it,1) = mean(rowS(tailMask), 'omitnan');
    F.S_core_mean(it,1) = mean(rowS(coreMask), 'omitnan');
    F.S_shoulder_mean(it,1) = mean(rowS(shoulderMask), 'omitnan');
    F.tail_core_ratio(it,1) = safeDiv(F.S_tail_mean(it), F.S_core_mean(it));
    F.tail_shoulder_ratio(it,1) = safeDiv(F.S_tail_mean(it), F.S_shoulder_mean(it));

    F.high_current_slope(it,1) = localSlope(xi(highCurrentMask), rowS(highCurrentMask));
    F.tail_slope(it,1) = localSlope(xi(tailMask), rowS(tailMask));
    F.tail_curvature(it,1) = localCurvature(xi(tailMask), rowS(tailMask));
    F.tail_rolloff(it,1) = localRolloff(xi(tailMask), rowS(tailMask));

    % Backbone-relative (deltaS = backbone - S)
    F.tail_deficit(it,1) = mean(rowD(tailMask), 'omitnan');
    F.shoulder_deficit(it,1) = mean(rowD(shoulderMask), 'omitnan');
    F.core_deficit(it,1) = mean(rowD(coreMask), 'omitnan');
    F.normalized_tail_deficit_by_S_peak(it,1) = safeDiv(F.tail_deficit(it), F.S_peak(it));
    F.normalized_tail_deficit_by_backbone_tail_norm(it,1) = safeDiv(F.tail_deficit(it), norm(rowB(tailMask)));
    F.backbone_tail_overshoot(it,1) = max(rowD(tailMask), [], 'omitnan');
    F.deficit_tail_shoulder_imbalance(it,1) = F.tail_deficit(it) - F.shoulder_deficit(it);

    % Residual / R1
    F.deltaS_tail_energy(it,1) = sum(rowD(tailMask).^2, 'omitnan');
    F.deltaS_tail_fraction(it,1) = safeDiv(F.deltaS_tail_energy(it), sum(rowD.^2, 'omitnan'));
    F.R1_tail_energy(it,1) = sum(rowR1(tailMask).^2, 'omitnan');
    F.R1_shoulder_energy(it,1) = sum(rowR1(shoulderMask).^2, 'omitnan');
    F.R1_core_energy(it,1) = sum(rowR1(coreMask).^2, 'omitnan');
    F.R1_tail_fraction(it,1) = safeDiv(F.R1_tail_energy(it), sum(rowR1.^2, 'omitnan'));
    F.R1_tail_shoulder_imbalance(it,1) = F.R1_tail_energy(it) - F.R1_shoulder_energy(it);
    F.R1_mirror_asymmetry(it,1) = localMirrorAsymmetry(cdfAxis, rowR1);
    F.R1_tail_curvature(it,1) = localCurvature(xi(tailMask), rowR1(tailMask));
    F.R1_second_derivative_tail_energy(it,1) = localSecondDerivativeEnergy(xi(tailMask), rowR1(tailMask));

    % Sign / endpoint
    F.tail_sign_mean(it,1) = mean(sign(rowD(tailMask)), 'omitnan');
    F.shoulder_sign_mean(it,1) = mean(sign(rowD(shoulderMask)), 'omitnan');
    F.core_sign_mean(it,1) = mean(sign(rowD(coreMask)), 'omitnan');
    if any(highCurrentMask)
        hiIdx = find(highCurrentMask);
        if numel(hiIdx) >= 2
            F.endpoint_high_current_difference(it,1) = rowS(hiIdx(end-1)) - rowS(hiIdx(end));
        else
            F.endpoint_high_current_difference(it,1) = NaN;
        end
    else
        F.endpoint_high_current_difference(it,1) = NaN;
    end
    if has45and50
        F.m45_minus_m50_difference(it,1) = rowS(i45) - rowS(i50);
    else
        F.m45_minus_m50_difference(it,1) = NaN;
    end
end

writetable(F, outFeat);

% ----------------------- Build canonical dictionary table --------------------
obsNames = setdiff(string(F.Properties.VariableNames), "T_K", 'stable');
dict = table();
lpHdr = lower(strtrim(string(legacyPlanRaw(1,:))));
obsCol = find(lpHdr=="observable_name" | lpHdr=="observable name", 1);
actCol = find(lpHdr=="action", 1);
if isempty(obsCol) || isempty(actCol)
    error('run_switching_canonical_observable_dictionary_audit:MissingLegacyPlanColumns', ...
        'Expected observable_name and action columns in legacy porting plan.');
end
lpData = legacyPlanRaw(2:end,:);
lpObs = string(lpData(:, obsCol));
lpAct = lower(strtrim(string(lpData(:, actCol))));
redefineGroups = unique(lower(strtrim(lpObs(lpAct=="redefine_canonically"))));

for i = 1:numel(obsNames)
    n = obsNames(i);
    info = inferDictionaryRow(n, redefineGroups);
    dict = [dict; table( ...
        n, info.formula, info.input_map, info.region, info.normalization, info.intended_latent_target, ...
        info.legacy_relation, "NO", info.must_validate_against_latent, ...
        'VariableNames', {'observable_name','formula','input_map','region','normalization','intended_latent_target', ...
        'legacy_relation','legacy_values_used','must_validate_against_latent'})]; %#ok<AGROW>
end
writetable(dict, outDict);

% ------------------------- Feature status/validation -------------------------
statusRows = table();
for i = 1:numel(obsNames)
    n = obsNames(i);
    x = F.(n);
    finiteFrac = mean(isfinite(x));
    missFrac = mean(~isfinite(x));
    isStable = finiteFrac >= 0.75;
    hasDenomRisk = contains(lower(dict.normalization(dict.observable_name==n)), "norm") || contains(lower(dict.normalization(dict.observable_name==n)), "s_peak");
    regionAvail = regionAvailable(n, coreMask, shoulderMask, tailMask, highCurrentMask, endpointMask);
    statusRows = [statusRows; table( ...
        n, finiteFrac, missFrac, string(regionAvail), string(yn(hasDenomRisk)), ...
        string(yn(any(contains(lower(n), "high_current") | contains(lower(n), "endpoint") | contains(lower(n), "m45_minus_m50")))), ...
        string(yn(has45and50)), string(yn(has40)), string(yn(isStable)), ...
        'VariableNames', {'observable_name','finite_fraction','missing_fraction','region_availability', ...
        'denominator_safety_checked','high_current_endpoint_required','endpoints_45_50_exist','current_40mA_exists','stable_enough_for_later_anatomy'})]; %#ok<AGROW>
end

% Add global checks + required final verdicts in same status table.
CANONICAL_OBSERVABLE_DICTIONARY_COMPLETE = yn(height(dict) > 0 && height(F) > 0);
LEGACY_VALUES_USED = "NO";
LEGACY_CORRELATIONS_USED = "NO";
ALL_OBSERVABLES_RECOMPUTED_CANONICALLY = "YES";
WIDTH_X_LEGACY_FEATURES_EXCLUDED = yn(~any(contains(lower(dict.observable_name), "width") | contains(lower(dict.observable_name), "xshape") | dict.observable_name=="X"));

DIRECT_OBSERVABLES_FOR_KAPPA1_AVAILABLE = targetAvailability(dict, statusRows, "kappa1");
DIRECT_OBSERVABLES_FOR_PHI1_AVAILABLE = targetAvailability(dict, statusRows, "Phi1");
DIRECT_OBSERVABLES_FOR_KAPPA2_AVAILABLE = targetAvailability(dict, statusRows, "kappa2");
DIRECT_OBSERVABLES_FOR_PHI2_AVAILABLE = targetAvailability(dict, statusRows, "Phi2");

READY_FOR_KAPPA1_KAPPA2_OBSERVABLE_ANATOMY = yn( ...
    (DIRECT_OBSERVABLES_FOR_KAPPA1_AVAILABLE ~= "NO") && ...
    (DIRECT_OBSERVABLES_FOR_KAPPA2_AVAILABLE ~= "NO") && ...
    CANONICAL_OBSERVABLE_DICTIONARY_COMPLETE=="YES" && ...
    LEGACY_VALUES_USED=="NO" && LEGACY_CORRELATIONS_USED=="NO");

globalRows = table( ...
    ["CANONICAL_OBSERVABLE_DICTIONARY_COMPLETE"; ...
     "LEGACY_VALUES_USED"; ...
     "LEGACY_CORRELATIONS_USED"; ...
     "ALL_OBSERVABLES_RECOMPUTED_CANONICALLY"; ...
     "WIDTH_X_LEGACY_FEATURES_EXCLUDED"; ...
     "DIRECT_OBSERVABLES_FOR_KAPPA1_AVAILABLE"; ...
     "DIRECT_OBSERVABLES_FOR_PHI1_AVAILABLE"; ...
     "DIRECT_OBSERVABLES_FOR_KAPPA2_AVAILABLE"; ...
     "DIRECT_OBSERVABLES_FOR_PHI2_AVAILABLE"; ...
     "READY_FOR_KAPPA1_KAPPA2_OBSERVABLE_ANATOMY"], ...
    [CANONICAL_OBSERVABLE_DICTIONARY_COMPLETE; ...
     LEGACY_VALUES_USED; ...
     LEGACY_CORRELATIONS_USED; ...
     ALL_OBSERVABLES_RECOMPUTED_CANONICALLY; ...
     WIDTH_X_LEGACY_FEATURES_EXCLUDED; ...
     DIRECT_OBSERVABLES_FOR_KAPPA1_AVAILABLE; ...
     DIRECT_OBSERVABLES_FOR_PHI1_AVAILABLE; ...
     DIRECT_OBSERVABLES_FOR_KAPPA2_AVAILABLE; ...
     DIRECT_OBSERVABLES_FOR_PHI2_AVAILABLE; ...
     READY_FOR_KAPPA1_KAPPA2_OBSERVABLE_ANATOMY], ...
    'VariableNames', {'observable_name','region_availability'});
globalRows.finite_fraction = NaN(height(globalRows),1);
globalRows.missing_fraction = NaN(height(globalRows),1);
globalRows.denominator_safety_checked = repmat("", height(globalRows), 1);
globalRows.high_current_endpoint_required = repmat("", height(globalRows), 1);
globalRows.endpoints_45_50_exist = repmat("", height(globalRows), 1);
globalRows.current_40mA_exists = repmat("", height(globalRows), 1);
globalRows.stable_enough_for_later_anatomy = repmat("", height(globalRows), 1);

statusAll = [statusRows; globalRows(:, statusRows.Properties.VariableNames)];
writetable(statusAll, outStat);

% -------------------------------- Report --------------------------------
lines = {};
lines{end+1} = '# Switching canonical observable dictionary audit';
lines{end+1} = '';
lines{end+1} = '## Scope';
lines{end+1} = sprintf('- CANONICAL_RUN_ID: `%s`', canonicalRunId);
lines{end+1} = '- Switching-only, locked canonical run; decomposition unchanged.';
lines{end+1} = '- Legacy inventory/porting-plan used only for concept groups marked `redefine_canonically`.';
lines{end+1} = '- No legacy values copied and no legacy correlations/verdicts reused.';
lines{end+1} = '';
lines{end+1} = '## Dictionary/feature build';
lines{end+1} = sprintf('- Dictionary rows: **%d**', height(dict));
lines{end+1} = sprintf('- Per-temperature rows: **%d**', height(F));
lines{end+1} = sprintf('- Current endpoints include 45/50 mA: **%s**', yn(has45and50));
lines{end+1} = sprintf('- Current 40 mA exists: **%s**', yn(has40));
lines{end+1} = '';
lines{end+1} = '## Final verdicts';
lines{end+1} = sprintf('- CANONICAL_OBSERVABLE_DICTIONARY_COMPLETE = %s', CANONICAL_OBSERVABLE_DICTIONARY_COMPLETE);
lines{end+1} = sprintf('- LEGACY_VALUES_USED = %s', LEGACY_VALUES_USED);
lines{end+1} = sprintf('- LEGACY_CORRELATIONS_USED = %s', LEGACY_CORRELATIONS_USED);
lines{end+1} = sprintf('- ALL_OBSERVABLES_RECOMPUTED_CANONICALLY = %s', ALL_OBSERVABLES_RECOMPUTED_CANONICALLY);
lines{end+1} = sprintf('- WIDTH_X_LEGACY_FEATURES_EXCLUDED = %s', WIDTH_X_LEGACY_FEATURES_EXCLUDED);
lines{end+1} = sprintf('- DIRECT_OBSERVABLES_FOR_KAPPA1_AVAILABLE = %s', DIRECT_OBSERVABLES_FOR_KAPPA1_AVAILABLE);
lines{end+1} = sprintf('- DIRECT_OBSERVABLES_FOR_PHI1_AVAILABLE = %s', DIRECT_OBSERVABLES_FOR_PHI1_AVAILABLE);
lines{end+1} = sprintf('- DIRECT_OBSERVABLES_FOR_KAPPA2_AVAILABLE = %s', DIRECT_OBSERVABLES_FOR_KAPPA2_AVAILABLE);
lines{end+1} = sprintf('- DIRECT_OBSERVABLES_FOR_PHI2_AVAILABLE = %s', DIRECT_OBSERVABLES_FOR_PHI2_AVAILABLE);
lines{end+1} = sprintf('- READY_FOR_KAPPA1_KAPPA2_OBSERVABLE_ANATOMY = %s', READY_FOR_KAPPA1_KAPPA2_OBSERVABLE_ANATOMY);
lines{end+1} = '';
lines{end+1} = '## Outputs';
lines{end+1} = '- `tables/switching_canonical_observable_dictionary.csv`';
lines{end+1} = '- `tables/switching_canonical_observable_features_by_T.csv`';
lines{end+1} = '- `tables/switching_canonical_observable_feature_status.csv`';

switchingWriteTextLinesFile(outRep, lines, 'run_switching_canonical_observable_dictionary_audit:WriteFail');
fprintf('[DONE] switching canonical observable dictionary audit -> %s\n', outRep);

% -------------------------------- Helpers --------------------------------
function y = safeDiv(a, b)
if ~isfinite(a) || ~isfinite(b) || abs(b) <= eps
    y = NaN;
else
    y = a / b;
end
end

function v = pickVar(vars, candidates)
v = "";
for i = 1:numel(candidates)
    ix = find(strcmpi(strtrim(vars), strtrim(candidates(i))), 1);
    if ~isempty(ix)
        v = vars(ix);
        return;
    end
end
if strlength(v) == 0
    error('run_switching_canonical_observable_dictionary_audit:MissingColumn', ...
        'Could not find expected column. Candidates: %s', strjoin(cellstr(candidates), ', '));
end
end

function s = localSlope(x, y)
x = x(:); y = y(:);
m = isfinite(x) & isfinite(y);
if sum(m) < 2
    s = NaN; return;
end
p = polyfit(x(m), y(m), 1);
s = p(1);
end

function c = localCurvature(x, y)
x = x(:); y = y(:);
m = isfinite(x) & isfinite(y);
if sum(m) < 3
    c = NaN; return;
end
p = polyfit(x(m), y(m), 2);
c = p(1);
end

function r = localRolloff(x, y)
x = x(:); y = y(:);
m = isfinite(x) & isfinite(y);
if sum(m) < 2
    r = NaN; return;
end
[x, ord] = sort(x(m), 'ascend');
y = y(m); y = y(ord);
r = y(1) - y(end);
end

function v = localMirrorAsymmetry(cdfAxis, row)
grid = linspace(0.1, 0.9, 9);
vals = NaN(size(grid));
for i = 1:numel(grid)
    c1 = grid(i);
    c2 = 1 - c1;
    [d1, i1] = min(abs(cdfAxis - c1));
    [d2, i2] = min(abs(cdfAxis - c2));
    if d1 < 0.15 && d2 < 0.15 && isfinite(row(i1)) && isfinite(row(i2))
        vals(i) = row(i2) - row(i1);
    end
end
v = mean(abs(vals), 'omitnan');
end

function e = localSecondDerivativeEnergy(x, y)
x = x(:); y = y(:);
m = isfinite(x) & isfinite(y);
if sum(m) < 3
    e = NaN; return;
end
x = x(m); y = y(m);
[x, ord] = sort(x, 'ascend');
y = y(ord);
dx = gradient(x);
d1 = gradient(y) ./ max(dx, eps);
d2 = gradient(d1) ./ max(dx, eps);
e = sum(d2.^2, 'omitnan');
end

function a = yn(tf)
if tf, a = "YES"; else, a = "NO"; end
end

function r = regionAvailable(obsName, coreMask, shoulderMask, tailMask, highCurrentMask, endpointMask)
n = lower(char(obsName));
if contains(n, "tail")
    r = yn(any(tailMask));
elseif contains(n, "shoulder")
    r = yn(any(shoulderMask));
elseif contains(n, "core")
    r = yn(any(coreMask));
elseif contains(n, "high_current")
    r = yn(any(highCurrentMask));
elseif contains(n, "endpoint") || contains(n, "m45_minus_m50")
    r = yn(any(endpointMask));
else
    r = "YES";
end
end

function out = targetAvailability(dict, statusRows, target)
m = dict.intended_latent_target == string(target) | contains(dict.intended_latent_target, string(target));
if ~any(m)
    out = "NO";
    return;
end
obs = dict.observable_name(m);
usable = false(size(obs));
for i = 1:numel(obs)
    ix = find(statusRows.observable_name == obs(i), 1);
    if ~isempty(ix)
        usable(i) = statusRows.stable_enough_for_later_anatomy(ix) == "YES";
    end
end
if any(usable) && all(usable)
    out = "YES";
elseif any(usable)
    out = "PARTIAL";
else
    out = "NO";
end
end

function d = inferDictionaryRow(name, redefineGroups)
n = lower(char(name));
d = struct();
d.formula = "";
d.input_map = "derived";
d.region = "full";
d.normalization = "none";
d.intended_latent_target = "general";
d.legacy_relation = "new_canonical";
d.must_validate_against_latent = "YES";

if any(contains(redefineGroups, "s_peak")) && contains(n, "s_peak")
    d.legacy_relation = "redefined_canonically";
elseif any(contains(redefineGroups, "i_peak")) && contains(n, "i_peak")
    d.legacy_relation = "redefined_canonically";
elseif any(contains(redefineGroups, "tail_burden_ratio")) && contains(n, "tail")
    d.legacy_relation = "redefined_canonically";
elseif any(contains(redefineGroups, "symmetry_cdf_mirror")) && contains(n, "mirror")
    d.legacy_relation = "redefined_canonically";
elseif any(contains(redefineGroups, "residual_energy_rmse")) && (contains(n, "r1_") || contains(n, "deltas"))
    d.legacy_relation = "redefined_canonically";
end

function v = pickVar(vars, candidates)
v = "";
for i = 1:numel(candidates)
    ix = find(strcmpi(strtrim(vars), strtrim(candidates(i))), 1);
    if ~isempty(ix)
        v = vars(ix);
        return;
    end
end
if strlength(v) == 0
    error('run_switching_canonical_observable_dictionary_audit:MissingColumn', ...
        'Could not find expected column. Candidates: %s', strjoin(cellstr(candidates), ', '));
end
end

if contains(n, "s_peak")
    d.formula = "max_I S(T,I)";
    d.input_map = "S";
    d.region = "full";
    d.normalization = "none";
    d.intended_latent_target = "kappa1";
elseif contains(n, "s_tail_mean")
    d.formula = "mean_{I in tail} S(T,I)";
    d.input_map = "S";
    d.region = "tail";
    d.intended_latent_target = "kappa2";
elseif contains(n, "s_core_mean")
    d.formula = "mean_{I in core} S(T,I)";
    d.input_map = "S";
    d.region = "core";
    d.intended_latent_target = "general";
elseif contains(n, "s_shoulder_mean")
    d.formula = "mean_{I in shoulder} S(T,I)";
    d.input_map = "S";
    d.region = "shoulder";
    d.intended_latent_target = "Phi2";
elseif contains(n, "tail_core_ratio")
    d.formula = "mean_tail(S)/mean_core(S)";
    d.input_map = "S";
    d.region = "tail";
    d.normalization = "row_norm";
    d.intended_latent_target = "kappa2";
elseif contains(n, "tail_shoulder_ratio")
    d.formula = "mean_tail(S)/mean_shoulder(S)";
    d.input_map = "S";
    d.region = "tail";
    d.normalization = "row_norm";
    d.intended_latent_target = "kappa2";
elseif contains(n, "high_current_slope")
    d.formula = "linear_slope(S over high-current points)";
    d.input_map = "S";
    d.region = "high-current";
    d.intended_latent_target = "Phi1";
elseif contains(n, "tail_slope")
    d.formula = "linear_slope(S over tail region)";
    d.input_map = "S";
    d.region = "tail";
    d.intended_latent_target = "Phi2";
elseif contains(n, "tail_curvature")
    d.formula = "quadratic_curvature(S over tail region)";
    d.input_map = "S";
    d.region = "tail";
    d.intended_latent_target = "Phi2";
elseif contains(n, "tail_rolloff")
    d.formula = "S(tail_start)-S(tail_end)";
    d.input_map = "S";
    d.region = "tail";
    d.intended_latent_target = "kappa2";
elseif contains(n, "deficit") || contains(n, "overshoot") || contains(n, "deltas_")
    d.input_map = "deltaS";
    d.intended_latent_target = "kappa2";
    if contains(n, "tail"), d.region = "tail"; end
    if contains(n, "core"), d.region = "core"; end
    if contains(n, "shoulder"), d.region = "shoulder"; end
    if contains(n, "normalized")
        if contains(n, "s_peak")
            d.normalization = "S_peak";
        elseif contains(n, "backbone")
            d.normalization = "backbone_norm";
        else
            d.normalization = "residual_norm";
        end
    end
    d.formula = string(name) + " from backbone-S region aggregate";
elseif startsWith(n, "r1_")
    d.input_map = "R1";
    d.intended_latent_target = "Phi2";
    if contains(n, "tail"), d.region = "tail"; end
    if contains(n, "core"), d.region = "core"; end
    if contains(n, "shoulder"), d.region = "shoulder"; end
    d.formula = string(name) + " from post-Phi1 residual map";
elseif contains(n, "sign_mean")
    d.formula = "mean(sign(backbone-S) in region)";
    d.input_map = "deltaS";
    if contains(n, "tail"), d.region = "tail"; end
    if contains(n, "core"), d.region = "core"; end
    if contains(n, "shoulder"), d.region = "shoulder"; end
    d.intended_latent_target = "general";
elseif contains(n, "endpoint") || contains(n, "m45_minus_m50")
    d.formula = string(name) + " endpoint contrast";
    d.input_map = "S";
    d.region = "endpoint";
    d.intended_latent_target = "Phi1";
end
end
