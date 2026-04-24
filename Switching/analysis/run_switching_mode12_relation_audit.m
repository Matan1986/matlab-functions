clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

try
    cfg = struct();
    cfg.runLabel = 'switching_mode12_relation_audit';
    cfg.dataset = 'canonical_mode_relation_audit';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTablesDir = fullfile(runDir, 'tables');
    runReportsDir = fullfile(runDir, 'reports');
    if exist(runTablesDir, 'dir') ~= 7, mkdir(runTablesDir); end
    if exist(runReportsDir, 'dir') ~= 7, mkdir(runReportsDir); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0, fprintf(fidTop, 'SCRIPT_ENTERED\n'); fclose(fidTop); end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    trPath = fullfile(repoRoot, 'tables', 'switching_transition_detection.csv');
    sPath = resolveLatestSLong(repoRoot);
    if exist(ampPath, 'file') ~= 2 || exist(trPath, 'file') ~= 2 || exist(sPath, 'file') ~= 2
        error('run_switching_mode12_relation_audit:MissingInput', 'Required input tables missing.');
    end

    ampTbl = readtable(ampPath);
    trTbl = readtable(trPath);
    sTbl = readtable(sPath);

    reqAmp = {'T_K', 'kappa1', 'kappa2'};
    for i = 1:numel(reqAmp)
        if ~ismember(reqAmp{i}, ampTbl.Properties.VariableNames)
            error('run_switching_mode12_relation_audit:BadAmpSchema', 'Missing %s in mode amplitudes table.', reqAmp{i});
        end
    end
    if ~ismember('T_K', trTbl.Properties.VariableNames) || ~ismember('transition_flag', trTbl.Properties.VariableNames)
        error('run_switching_mode12_relation_audit:BadTransitionSchema', 'Transition table missing required columns.');
    end
    reqS = {'T_K', 'current_mA', 'S_percent', 'S_model_pt_percent'};
    for i = 1:numel(reqS)
        if ~ismember(reqS{i}, sTbl.Properties.VariableNames)
            error('run_switching_mode12_relation_audit:BadSLongSchema', 'S_long missing %s.', reqS{i});
        end
    end

    T = double(ampTbl.T_K(:));
    k1 = double(ampTbl.kappa1(:));
    k2 = double(ampTbl.kappa2(:));
    [T, idx] = sort(T);
    k1 = k1(idx); k2 = k2(idx);
    nT = numel(T);

    regimePhysical = strings(nT, 1);
    regimePhysical(T < 24) = "pre";
    regimePhysical(T >= 24 & T < 31.5) = "transition";
    regimePhysical(T >= 31.5) = "post";

    regimeData = strings(nT, 1); regimeData(:) = "unflagged";
    Ttr = double(trTbl.T_K(:));
    Ftr = string(trTbl.transition_flag(:));
    for i = 1:nT
        j = find(abs(Ttr - T(i)) < 1e-9, 1);
        if ~isempty(j) && strcmpi(strtrim(char(Ftr(j))), 'YES')
            regimeData(i) = "flagged_transition";
        end
    end

    dk1 = NaN(nT, 1);
    if nT >= 2
        dk1 = gradient(k1, T);
    end
    ratio21 = NaN(nT, 1);
    vRatio = isfinite(k1) & abs(k1) > 1e-12 & isfinite(k2);
    ratio21(vRatio) = k2(vRatio) ./ k1(vRatio);

    couplingIndicator = strings(nT, 1);
    for i = 1:nT
        if ~isfinite(ratio21(i))
            couplingIndicator(i) = "UNDEFINED";
        elseif abs(ratio21(i)) < 0.15
            couplingIndicator(i) = "WEAK";
        elseif abs(ratio21(i)) < 0.40
            couplingIndicator(i) = "MODERATE";
        else
            couplingIndicator(i) = "STRONG";
        end
    end
    couplingTbl = table(T, regimePhysical, regimeData, k1, k2, ratio21, dk1, couplingIndicator, ...
        'VariableNames', {'T_K','regime_label_physical','regime_label_datadriven','kappa1','kappa2','kappa2_over_kappa1','dkappa1_dT','coupling_indicator'});

    % Build global mode_1 / mode_2 from canonical residual.
    [currents, mode1, mode2, Rfill] = buildModesFromSLong(sTbl, T);
    x = linspace(-1, 1, numel(currents))';
    x = x - mean(x);

    d1 = gradient(mode1);
    d2 = gradient(d1);
    basis = [normalizeVec(d1), normalizeVec(x .* mode1), normalizeVec(d2), normalizeVec(x .* d1), normalizeVec((x.^2) .* mode1)];
    basisIds = string({'dmode1_dx','x_mode1','d2mode1_dx2','x_dmode1_dx','x2_mode1'})';
    basisDesc = string({'first derivative of mode_1', 'x times mode_1', 'second derivative of mode_1', 'x times first derivative', 'x^2 times mode_1'})';

    mode2n = normalizeVec(mode2);
    nB = size(basis, 2);
    cosB = NaN(nB,1); rmseB = NaN(nB,1); expB = NaN(nB,1);
    for i = 1:nB
        b = basis(:, i);
        cosB(i) = abs(dot(mode2n, b));
        fit = dot(mode2, b) * b;
        rmseB(i) = sqrt(mean((mode2 - fit).^2, 'omitnan'));
        expB(i) = 1 - sum((mode2 - fit).^2) / max(sum(mode2.^2), eps);
    end
    geomTbl = table(basisIds, basisDesc, cosB, rmseB, expB, ...
        'VariableNames', {'basis_id','basis_description','cosine_to_mode2','rmse_to_mode2','explained_fraction'});

    % Regime-resolved relation summary.
    regNames = ["pre"; "transition"; "post"];
    rowsReg = repmat(struct('regime_label_physical',"",'n_temperatures',0,'corr_kappa2_kappa1',NaN, ...
        'corr_kappa2_abs_kappa1',NaN,'mean_kappa2_over_kappa1',NaN,'std_kappa2_over_kappa1',NaN, ...
        'best_geometric_basis',"",'best_basis_cosine',NaN,'best_basis_rmse',NaN), 3,1);

    bestIdx = find(cosB == max(cosB), 1, 'first');
    for r = 1:3
        m = regimePhysical == regNames(r);
        rowsReg(r).regime_label_physical = regNames(r);
        rowsReg(r).n_temperatures = sum(m);
        if sum(m) >= 2
            rowsReg(r).corr_kappa2_kappa1 = corr(k2(m), k1(m), 'Type', 'Pearson', 'Rows', 'complete');
            rowsReg(r).corr_kappa2_abs_kappa1 = corr(k2(m), abs(k1(m)), 'Type', 'Pearson', 'Rows', 'complete');
            rowsReg(r).mean_kappa2_over_kappa1 = mean(ratio21(m), 'omitnan');
            rowsReg(r).std_kappa2_over_kappa1 = std(ratio21(m), 'omitnan');
        end
        rowsReg(r).best_geometric_basis = basisIds(bestIdx);
        rowsReg(r).best_basis_cosine = cosB(bestIdx);
        rowsReg(r).best_basis_rmse = rmseB(bestIdx);
    end
    relByRegTbl = struct2table(rowsReg);

    % Post-31.5 specific audit against lower-T best basis relation.
    lowerMask = T < 31.5;
    postMask = T >= 31.5;
    bestBasis = basis(:, bestIdx);
    cosLowerRef = abs(dot(mode2n, bestBasis));
    postRows = sum(postMask);
    postAuditTbl = table('Size', [postRows, 7], ...
        'VariableTypes', {'double','double','double','double','double','double','string'}, ...
        'VariableNames', {'T_K','kappa1','kappa2','kappa2_over_kappa1','cosine_mode2_to_best_lowerT_basis','deviation_from_lowerT_relation','post315_relation_break_flag'});
    ip = 0;
    lowerRatioMu = mean(ratio21(lowerMask), 'omitnan');
    lowerRatioSd = std(ratio21(lowerMask), 'omitnan');
    if ~isfinite(lowerRatioSd) || lowerRatioSd <= 0
        lowerRatioSd = max(abs(lowerRatioMu)*0.1, 1e-6);
    end
    for i = 1:nT
        if ~postMask(i), continue; end
        ip = ip + 1;
        ri = Rfill(i, :)';
        cosi = abs(dot(normalizeVec(ri), bestBasis));
        dev = abs(cosi - cosLowerRef);
        breakFlag = "NO";
        if abs(ratio21(i) - lowerRatioMu) > 2*lowerRatioSd || dev > 0.25
            breakFlag = "YES";
        end
        postAuditTbl.T_K(ip) = T(i);
        postAuditTbl.kappa1(ip) = k1(i);
        postAuditTbl.kappa2(ip) = k2(i);
        postAuditTbl.kappa2_over_kappa1(ip) = ratio21(i);
        postAuditTbl.cosine_mode2_to_best_lowerT_basis(ip) = cosi;
        postAuditTbl.deviation_from_lowerT_relation(ip) = dev;
        postAuditTbl.post315_relation_break_flag(ip) = breakFlag;
    end

    % Localization comparison mode1 vs mode2.
    ridgeMask = currents >= 35 & currents <= 45;
    if ~any(ridgeMask)
        q = quantile(currents, [0.55, 0.80]);
        ridgeMask = currents >= q(1) & currents <= q(2);
    end
    e1 = mode1.^2; e2 = mode2.^2;
    ridgeFrac1 = sum(e1(ridgeMask)) / max(sum(e1), eps);
    ridgeFrac2 = sum(e2(ridgeMask)) / max(sum(e2), eps);
    support1 = e1 >= 0.25 * max(e1);
    support2 = e2 >= 0.25 * max(e2);
    overlap = sum(support1 & support2) / max(sum(support1 | support2), 1);
    cm1 = sum(currents .* e1) / max(sum(e1), eps);
    cm2 = sum(currents .* e2) / max(sum(e2), eps);
    w1 = sqrt(sum(((currents - cm1).^2) .* e1) / max(sum(e1), eps));
    w2 = sqrt(sum(((currents - cm2).^2) .* e2) / max(sum(e2), eps));
    locCompTbl = table( ...
        string({'ridge_energy_fraction';'support_overlap_fraction';'center_of_mass_mA';'energy_width_mA'}), ...
        [ridgeFrac1; overlap; cm1; w1], ...
        [ridgeFrac2; overlap; cm2; w2], ...
        string({'mode2 more ridge localized if larger';'shared high-energy support overlap';'difference indicates shifted localization';'difference indicates broader/narrower support'}), ...
        'VariableNames', {'metric','mode1_value','mode2_value','comparison_note'});

    % Verdicts
    corr21 = corr(k2, k1, 'Type', 'Pearson', 'Rows', 'complete');
    corr2abs1 = corr(k2, abs(k1), 'Type', 'Pearson', 'Rows', 'complete');
    ratioStdByReg = [std(ratio21(regimePhysical=="pre"), 'omitnan'); std(ratio21(regimePhysical=="transition"), 'omitnan'); std(ratio21(regimePhysical=="post"), 'omitnan')];
    ratioRegimeDependent = nanmax(ratioStdByReg) - nanmin(ratioStdByReg);
    postBreakFrac = mean(postAuditTbl.post315_relation_break_flag == "YES", 'omitnan');
    ampCoupled = "NO";
    if abs(corr21) >= 0.7 || abs(corr2abs1) >= 0.7
        ampCoupled = "YES";
    elseif abs(corr21) >= 0.4 || abs(corr2abs1) >= 0.4
        ampCoupled = "PARTIAL";
    end
    geomDef = "NO";
    if cosB(bestIdx) >= 0.85 && expB(bestIdx) >= 0.60
        geomDef = "YES";
    elseif cosB(bestIdx) >= 0.6 && expB(bestIdx) >= 0.35
        geomDef = "PARTIAL";
    end
    regimeDep = "NO";
    if ratioRegimeDependent > 0.15 || abs(rowsReg(1).corr_kappa2_kappa1 - rowsReg(2).corr_kappa2_kappa1) > 0.3
        regimeDep = "YES";
    end
    changePost315 = "NO";
    if isfinite(postBreakFrac) && postBreakFrac >= 0.5
        changePost315 = "YES";
    end
    compatibleSame = "YES";
    if changePost315 == "YES" && cosB(bestIdx) < 0.7
        compatibleSame = "NO";
    end
    safeDeformation = "NO";
    if strcmp(geomDef, "YES") && strcmp(compatibleSame, "YES")
        safeDeformation = "YES";
    end
    safePhysical = "NO";
    if strcmp(ampCoupled, "YES") || strcmp(geomDef, "YES") || strcmp(geomDef, "PARTIAL")
        safePhysical = "YES";
    end

    statusTbl = table( ...
        string('SUCCESS'), ...
        string('YES'), ...
        nT, ...
        string('pre:T<24; transition:24<=T<31.5; post:T>=31.5'), ...
        string('from tables/switching_transition_detection.csv transition_flag'), ...
        string(yesno(any(postMask))), ...
        string(sprintf('source=%s;best_basis=%s;best_cosine=%.6g', sPath, basisIds(bestIdx), cosB(bestIdx))), ...
        'VariableNames', {'STATUS','INPUT_FOUND','N_temperatures','physical_regime_definition_used','datadriven_regime_definition_used','post315_rows_present','execution_notes'});

    report = {};
    report{end+1} = '# Canonical Mode-2 vs Mode-1 Relation Audit';
    report{end+1} = '';
    report{end+1} = '## 1. Why 31.5 K is treated separately';
    report{end+1} = '- 31.5 K is enforced here as a physical regime boundary (pre / transition / post).';
    report{end+1} = '- This is distinct from data-driven transition flags, which are retained only as auxiliary labels.';
    report{end+1} = '';
    report{end+1} = '## 2. Amplitude Coupling';
    report{end+1} = sprintf('- corr(kappa2, kappa1) = %.6g', corr21);
    report{end+1} = sprintf('- corr(kappa2, |kappa1|) = %.6g', corr2abs1);
    report{end+1} = sprintf('- kappa2/kappa1 mean pre=%.6g, transition=%.6g, post=%.6g', ...
        mean(ratio21(regimePhysical=="pre"), 'omitnan'), mean(ratio21(regimePhysical=="transition"), 'omitnan'), mean(ratio21(regimePhysical=="post"), 'omitnan'));
    report{end+1} = '';
    report{end+1} = '## 3. Geometric Relation';
    report{end+1} = sprintf('- best geometric basis: %s', basisIds(bestIdx));
    report{end+1} = sprintf('- best cosine_to_mode2 = %.6g', cosB(bestIdx));
    report{end+1} = sprintf('- best explained_fraction = %.6g', expB(bestIdx));
    report{end+1} = '';
    report{end+1} = '## 4. Regime Dependence';
    report{end+1} = sprintf('- relation regime-dependent flag: %s', regimeDep);
    report{end+1} = sprintf('- pre corr(k2,k1)=%.6g, transition corr(k2,k1)=%.6g, post corr(k2,k1)=%.6g', ...
        rowsReg(1).corr_kappa2_kappa1, rowsReg(2).corr_kappa2_kappa1, rowsReg(3).corr_kappa2_kappa1);
    report{end+1} = '';
    report{end+1} = '## 5. Post-31.5 Interpretation Gate';
    report{end+1} = sprintf('- post315 relation break fraction = %.6g', postBreakFrac);
    report{end+1} = sprintf('- relation changes above 31.5 K: %s', changePost315);
    report{end+1} = '';
    report{end+1} = '## Final Verdicts';
    report{end+1} = sprintf('- MODE2_AMPLITUDE_COUPLED_TO_MODE1 = %s', ampCoupled);
    report{end+1} = sprintf('- MODE2_GEOMETRIC_DEFORMATION_OF_MODE1 = %s', geomDef);
    report{end+1} = sprintf('- MODE2_RELATION_TO_MODE1_REGIME_DEPENDENT = %s', regimeDep);
    report{end+1} = sprintf('- MODE2_RELATION_CHANGES_ABOVE_31_5K = %s', changePost315);
    report{end+1} = sprintf('- POST_31_5K_BEHAVIOR_COMPATIBLE_WITH_SAME_MODE_FAMILY = %s', compatibleSame);
    report{end+1} = sprintf('- SAFE_TO_CALL_MODE2_A_DEFORMATION = %s', safeDeformation);
    report{end+1} = sprintf('- SAFE_TO_PROCEED_TO_PHYSICAL_LABELING = %s', safePhysical);

    writeBoth(couplingTbl, repoRoot, runTablesDir, 'switching_mode12_coupling_vs_T.csv');
    writeBoth(geomTbl, repoRoot, runTablesDir, 'switching_mode2_geometric_similarity.csv');
    writeBoth(relByRegTbl, repoRoot, runTablesDir, 'switching_mode12_relation_by_regime.csv');
    writeBoth(postAuditTbl, repoRoot, runTablesDir, 'switching_mode12_post315_audit.csv');
    writeBoth(locCompTbl, repoRoot, runTablesDir, 'switching_mode12_localization_comparison.csv');
    writeBoth(statusTbl, repoRoot, runTablesDir, 'switching_mode12_relation_status.csv');
    writeLines(fullfile(runReportsDir, 'switching_mode12_relation_audit.md'), report);
    writeLines(fullfile(repoRoot, 'reports', 'switching_mode12_relation_audit.md'), report);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'switching mode12 relation audit completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_mode12_relation_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end
    statusTbl = table(string('FAILED'), string('NO'), 0, string('pre:T<24; transition:24<=T<31.5; post:T>=31.5'), ...
        string('from tables/switching_transition_detection.csv transition_flag'), string('NO'), string(ME.message), ...
        'VariableNames', {'STATUS','INPUT_FOUND','N_temperatures','physical_regime_definition_used','datadriven_regime_definition_used','post315_rows_present','execution_notes'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_mode12_relation_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_mode12_relation_status.csv'));
    lines = {};
    lines{end+1} = '# Canonical Mode-2 vs Mode-1 Relation Audit FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    writeLines(fullfile(runDir, 'reports', 'switching_mode12_relation_audit.md'), lines);
    writeLines(fullfile(repoRoot, 'reports', 'switching_mode12_relation_audit.md'), lines);
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'switching mode12 relation audit failed'}, true);
    rethrow(ME);
end

function sPath = resolveLatestSLong(repoRoot)
runsRoot = switchingCanonicalRunRoot(repoRoot);
sPaths = {};
if exist(runsRoot, 'dir') == 7
    d = dir(fullfile(runsRoot, 'run_*_switching_canonical'));
    for i = 1:numel(d)
        p = fullfile(runsRoot, d(i).name, 'tables', 'switching_canonical_S_long.csv');
        if exist(p, 'file') == 2
            sPaths{end+1,1} = p; %#ok<AGROW>
        end
    end
end
if isempty(sPaths), sPath = ''; return; end
[~, idx] = max(cellfun(@(p) dir(p).datenum, sPaths));
sPath = sPaths{idx};
end

function [currents, mode1, mode2, Rfill] = buildModesFromSLong(sTbl, Tref)
TT = double(sTbl.T_K);
II = double(sTbl.current_mA);
SS = double(sTbl.S_percent);
SP = double(sTbl.S_model_pt_percent);
currents = sort(unique(II(isfinite(II))));
nT = numel(Tref); nI = numel(currents);
R = NaN(nT, nI);
for it = 1:nT
    t = Tref(it);
    mt = abs(TT - t) < 1e-9;
    for ii = 1:nI
        m = mt & abs(II - currents(ii)) < 1e-9;
        if any(m)
            R(it, ii) = mean(SS(m) - SP(m), 'omitnan');
        end
    end
end
Rfill = R; Rfill(~isfinite(Rfill)) = 0;
[~, ~, V] = svd(Rfill, 'econ');
mode1 = V(:, 1);
mode2 = zeros(nI, 1);
if size(V, 2) >= 2, mode2 = V(:, 2); end
end

function v = normalizeVec(v)
n = norm(v);
if n > 0, v = v ./ n; end
end

function out = yesno(tf)
out = 'NO';
if tf, out = 'YES'; end
end

function writeBoth(tbl, repoRoot, runTablesDir, name)
writetable(tbl, fullfile(runTablesDir, name));
writetable(tbl, fullfile(repoRoot, 'tables', name));
end

function writeLines(pathOut, lines)
fid = fopen(pathOut, 'w');
if fid < 0
    error('run_switching_mode12_relation_audit:WriteFail', 'Cannot write %s', pathOut);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);
end
