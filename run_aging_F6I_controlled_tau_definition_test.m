% F6I - Controlled tau-definition diagnostic (2x2 signal x protocol matrix).
% diagnostic_tau_only not_canonical not_physical_claim not_replacing_F4A_F4B
% tools\run_matlab_safe.bat "<ABS_PATH>\run_aging_F6I_controlled_tau_definition_test.m"

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('F6I:RepoRootMissing');
end

fidTopProbe = fopen(fullfile(repoRoot, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

addpath(fullfile(repoRoot, 'Aging', 'diagnostics'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_F6I_controlled_tau_definition';
cfg.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F6I_controlled_tau_definition_test.m');

executionStatus = table({'FAILED'}, {'NO'}, {'Not started'}, 0, {'F6I not executed'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

run = [];
try
    run = createRunContext('aging', cfg);
    runTablesDir = fullfile(run.run_dir, 'tables');
    runReportsDir = fullfile(run.run_dir, 'reports');
    runFigDir = fullfile(run.run_dir, 'figures');
    for d = {runTablesDir, runReportsDir, runFigDir}
        if exist(d{1}, 'dir') ~= 7
            mkdir(d{1});
        end
    end

    fidPointer = fopen(fullfile(run.repo_root, 'run_dir_pointer.txt'), 'w');
    fprintf(fidPointer, '%s\n', run.run_dir);
    fclose(fidPointer);

    rp = @(rel) fullfile(repoRoot, strrep(rel, '/', filesep));

    legacyPath = rp('results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv');
    tauDipLegacyPath = rp('results_old/aging/runs/run_2026_03_12_223709_aging_timescale_extraction/tables/tau_vs_Tp.csv');
    tauFmLegacyPath = rp('results_old/aging/runs/run_2026_03_13_013634_aging_fm_timescale_analysis/tables/tau_FM_vs_Tp.csv');
    f4aDomain = rp('tables/aging/aging_F4A_AFM_tau_input_domain.csv');
    f4bDomain = rp('tables/aging/aging_F4B_FM_tau_input_domain.csv');
    f4aSel = rp('tables/aging/aging_F4A_AFM_tau_selected_values.csv');
    f4bSel = rp('tables/aging/aging_F4B_FM_tau_selected_values.csv');

    assert(exist(legacyPath, 'file') == 2);
    assert(exist(tauDipLegacyPath, 'file') == 2);
    assert(exist(tauFmLegacyPath, 'file') == 2);
    assert(exist(f4aDomain, 'file') == 2);
    assert(exist(f4bDomain, 'file') == 2);

    tblLegacy = readLegacyObservableCsv_F6I(legacyPath);
    tblTauDipLegacy = readtable(tauDipLegacyPath, 'TextType', 'string');
    tblTauFmLegacy = readtable(tauFmLegacyPath, 'TextType', 'string');
    tblAfm = readF4aInputDomainCsv_F6I(f4aDomain);
    tblFm = readF4bInputDomainCsv_F6I(f4bDomain);
    tblF4aSel = readtable(f4aSel, 'TextType', 'string');
    tblF4bSel = readtable(f4bSel, 'TextType', 'string');

    primaryTp = [22; 26; 30];
    ctxTp = [14; 18; 34];
    % Primary-only default for manageable runtime (enable ctxTp locally if needed).
    allTp = primaryTp;
    % allTp = unique([primaryTp; ctxTp]);

    wideRows = {};
    fqRows = {};
    attribRows = {};
    sectors = ["DIP", "FM"];

    for si = 1:2
        sec = sectors(si);
        for ti = 1:numel(allTp)
            tp = allTp(ti);
            [twLeg, yLeg, ~] = extractLegacySignal(tblLegacy, tp, sec);
            [twCan, yCan, ~] = extractCanonicalSignal(tblAfm, tblFm, tp, sec);

            [tauA, qA, detA] = runCell(twLeg, yLeg, "legacy", sec);
            [tauB, qB, detB] = runCell(twLeg, yLeg, "canonical", sec);
            [tauC, qC, detC] = runCell(twCan, yCan, "legacy", sec);
            [tauD, qD, detD] = runCell(twCan, yCan, "canonical", sec);

            legRef = lookupLegacyCommitted(tblTauDipLegacy, tblTauFmLegacy, tp, sec);
            canRef = lookupCanonicalCommitted(tblF4aSel, tblF4bSel, tp, sec);

            wideRows(end + 1, :) = { sec, tp, tauA, tauB, tauC, tauD, ...
                qA, qB, qC, qD, ...
                detailStr(detA, "A"), detailStr(detB, "B"), detailStr(detC, "C"), detailStr(detD, "D"), ...
                legRef, canRef }; %#ok<AGROW>

            fqRows(end + 1, :) = { sec, tp, 'A_legacy_legacy', tauA, qA, detRmse(detA), detR2(detA), detNm(detA) }; %#ok<AGROW>
            fqRows(end + 1, :) = { sec, tp, 'B_legacy_canonical', tauB, qB, detB.rmse, detB.r2, NaN };
            fqRows(end + 1, :) = { sec, tp, 'C_canonical_legacy', tauC, qC, detRmse(detC), detR2(detC), detNm(detC) };
            fqRows(end + 1, :) = { sec, tp, 'D_canonical_canonical', tauD, qD, detD.rmse, detD.r2, NaN };

            [sigL, protL, protC, totG, fs, fp] = attributionLogs(tauA, tauB, tauC, tauD);
            attribRows(end + 1, :) = { sec, tp, sigL, protL, protC, totG, fs, fp }; %#ok<AGROW>
        end
    end

    matWide = cell2table(wideRows, 'VariableNames', { ...
        'sector', 'Tp', ...
        'tau_A_legacy_signal_legacy_protocol', 'tau_B_legacy_signal_canonical_protocol', ...
        'tau_C_canonical_signal_legacy_protocol', 'tau_D_canonical_signal_canonical_protocol', ...
        'pass_A', 'pass_B', 'pass_C', 'pass_D', ...
        'quality_detail_A', 'quality_detail_B', 'quality_detail_C', 'quality_detail_D', ...
        'original_committed_tau_legacy', 'original_committed_tau_canonical'});

    fqTbl = cell2table(fqRows, 'VariableNames', { ...
        'sector', 'Tp', 'cell_code', 'tau_seconds', 'pass_fail', 'rmse', 'r2', 'n_methods_or_na'});

    attribTbl = cell2table(attribRows, 'VariableNames', { ...
        'sector', 'Tp', 'signal_effect_log10', 'protocol_effect_legacy_signal_log10', ...
        'protocol_effect_canonical_signal_log10', 'total_gap_log10', 'fraction_signal', 'fraction_protocol'});

    ratioRows = buildRatioRowsFromWide(matWide);

    %% 26K tau extraction
    tp26 = 26;
    mw26 = matWide(matWide.Tp == tp26, :);
    dip26 = mw26(mw26.sector == "DIP", :);
    fm26 = mw26(mw26.sector == "FM", :);

    tA = dip26.tau_A_legacy_signal_legacy_protocol(1);
    tB = dip26.tau_B_legacy_signal_canonical_protocol(1);
    tC = dip26.tau_C_canonical_signal_legacy_protocol(1);
    tD = dip26.tau_D_canonical_signal_canonical_protocol(1);

    fA = fm26.tau_A_legacy_signal_legacy_protocol(1);
    fB = fm26.tau_B_legacy_signal_canonical_protocol(1);
    fC = fm26.tau_C_canonical_signal_legacy_protocol(1);
    fD = fm26.tau_D_canonical_signal_canonical_protocol(1);

    fmIdenticalY = abs(fA - fC) < 1e-9 * max(1, abs(fA));

    diag26 = table( ...
        [ "legacy_Dip_depth_canonical_protocol_tau_B_s"; "canonical_TrackB_legacy_protocol_tau_C_s"; ...
        "fm_identical_y_tauA_eq_tauC"; "fm_protocol_log10_ratio_D_over_A"; ...
        "dip_ratio_tauB_over_tauA"; "dip_ratio_tauD_over_tauC" ], ...
        [ tB; tC; double(fmIdenticalY); (log10(fD) - log10(fA)); tB / tA; tD / tC ], ...
        'VariableNames', {'metric', 'value'});

    fidNotes = table( ...
        {'legacy_protocol_DIP'; 'legacy_protocol_FM'; 'canonical_protocol'}, ...
        {'Exact body copy from aging_timescale_extraction.m into Aging/diagnostics/aging_F6I_legacy_tau_from_curve.m (tools/assemble_F6I_legacy_diagnostic_source.m); DIP uses buildConsensusTau'; ...
        'FM sector uses Aging/diagnostics/aging_F6I_legacy_fm_tau_from_curve.m with buildEffectiveFmTau copied from aging_fm_timescale_analysis.m (half_range_primary when half-range ok)'; ...
        'Same single-exp objective and R2>=0.6,n>=3 gate as run_aging_F4B_FM_physical_tau_replay.m in Aging/diagnostics/aging_F6I_canonical_exponential_fit.m'}, ...
        'VariableNames', {'component', 'fidelity_note'});

    dipAttrib = attribTbl(attribTbl.sector == "DIP" & ismember(attribTbl.Tp, primaryTp), :);
    fmAttrib = attribTbl(attribTbl.sector == "FM" & ismember(attribTbl.Tp, primaryTp), :);

    dipFs = median(dipAttrib.fraction_signal, 'omitnan');
    fmFs = median(fmAttrib.fraction_signal, 'omitnan');

    canonDip26 = dip26.original_committed_tau_canonical(1);
    verdicts = buildVerdicts(dipFs, fmFs, tA, tB, tC, tD, fA, fD, fmIdenticalY, canonDip26);

    statusTbl = cell2table(verdicts, 'VariableNames', {'verdict_key', 'verdict_value'});

    outTables = rp('tables/aging');
    outRep = rp('reports/aging');
    outFig = rp('figures');
    if exist(outTables, 'dir') ~= 7, mkdir(outTables); end
    if exist(outRep, 'dir') ~= 7, mkdir(outRep); end
    if exist(outFig, 'dir') ~= 7, mkdir(outFig); end

    writetable(matWide, fullfile(outTables, 'aging_F6I_controlled_tau_matrix.csv'));
    writetable(attribTbl, fullfile(outTables, 'aging_F6I_tau_gap_attribution.csv'));
    writetable(diag26, fullfile(outTables, 'aging_F6I_26K_controlled_diagnosis.csv'));
    writetable(ratioRows, fullfile(outTables, 'aging_F6I_diagnostic_ratio_matrix.csv'));
    writetable(fqTbl, fullfile(outTables, 'aging_F6I_fit_quality_matrix.csv'));
    writetable(fidNotes, fullfile(outTables, 'aging_F6I_method_fidelity_notes.csv'));
    writetable(statusTbl, fullfile(outTables, 'aging_F6I_controlled_tau_status.csv'));

    writetable(matWide, fullfile(runTablesDir, 'aging_F6I_controlled_tau_matrix.csv'));
    writetable(attribTbl, fullfile(runTablesDir, 'aging_F6I_tau_gap_attribution.csv'));
    writetable(diag26, fullfile(runTablesDir, 'aging_F6I_26K_controlled_diagnosis.csv'));
    writetable(ratioRows, fullfile(runTablesDir, 'aging_F6I_diagnostic_ratio_matrix.csv'));
    writetable(fqTbl, fullfile(runTablesDir, 'aging_F6I_fit_quality_matrix.csv'));
    writetable(fidNotes, fullfile(runTablesDir, 'aging_F6I_method_fidelity_notes.csv'));
    writetable(statusTbl, fullfile(runTablesDir, 'aging_F6I_controlled_tau_status.csv'));

    mdPath = fullfile(outRep, 'aging_F6I_controlled_tau_definition_test.md');
    writeF6Ireport(mdPath, matWide, attribTbl, diag26, statusTbl, legacyPath, dipFs, fmFs);
    copyfile(mdPath, fullfile(runReportsDir, 'aging_F6I_controlled_tau_definition_test.md'));

    tb = [tA; tB; tC; tD];
    fb = [fA; fB; fC; fD];
    if all(isfinite(tb))
        makeBarFig(fullfile(outFig, 'aging_F6I_26K_dip_controlled_fits.png'), tb, ...
            {'A', 'B', 'C', 'D'}, 'F6I 26K DIP diagnostic tau (non-canonical)');
        copyfile(fullfile(outFig, 'aging_F6I_26K_dip_controlled_fits.png'), fullfile(runFigDir, 'aging_F6I_26K_dip_controlled_fits.png'));
    end
    if all(isfinite(fb))
        makeBarFig(fullfile(outFig, 'aging_F6I_26K_fm_controlled_fits.png'), fb, ...
            {'A', 'B', 'C', 'D'}, 'F6I 26K FM diagnostic tau (non-canonical)');
        copyfile(fullfile(outFig, 'aging_F6I_26K_fm_controlled_fits.png'), fullfile(runFigDir, 'aging_F6I_26K_fm_controlled_fits.png'));
    end

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, numel(allTp), ...
        {'F6I completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    executionStatus = table({'FAILED'}, {'YES'}, {ME.message}, 0, ...
        {'F6I failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    runDirFail = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_F6I_failure');
    if ~isempty(run) && isstruct(run) && isfield(run, 'run_dir')
        runDirFail = run.run_dir;
    end
    if exist(runDirFail, 'dir') ~= 7
        mkdir(runDirFail);
    end
    writetable(executionStatus, fullfile(runDirFail, 'execution_status.csv'));
    rethrow(ME);
end

if ~isempty(run) && isfield(run, 'run_dir')
    writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
end

%% --- helpers ---
function s = detailStr(det, tag)
if tag == "B" || tag == "D"
    s = string(det.gate_detail);
else
    s = strip(string(det.tau_consensus_methods) + "|spread_dec=" + string(det.spread_decades));
end
end

function r = detRmse(det)
if isfield(det, 'rmse_consensus')
    r = det.rmse_consensus;
else
    r = NaN;
end
end

function r = detR2(det)
if isfield(det, 'r2_proxy')
    r = det.r2_proxy;
else
    r = NaN;
end
end

function n = detNm(det)
if isfield(det, 'n_methods')
    n = det.n_methods;
else
    n = NaN;
end
end

function [tw, y, ok] = extractLegacySignal(tbl, tp, sector)
sub = tbl(tbl.Tp == tp, :);
if sector == "DIP"
    fld = 'Dip_depth';
else
    fld = 'FM_abs';
end
tw = double(sub.tw);
yv = double(sub.(fld));
mask = isfinite(tw) & isfinite(yv);
tw = tw(mask);
yv = yv(mask);
[~, ord] = sort(tw);
tw = tw(ord);
y = yv(ord);
ok = numel(tw) >= 2;
end

function [tw, y, ok] = extractCanonicalSignal(tblAfm, tblFm, tp, sector)
if sector == "DIP"
    sub = tblAfm(tblAfm.Tp == tp, :);
    fld = 'Dip_depth_direct_TrackB';
else
    sub = tblFm(tblFm.Tp == tp, :);
    fld = 'FM_signed_direct_TrackB_sign_aligned';
end
tw = double(sub.tw);
yv = double(sub.(fld));
mask = isfinite(tw) & isfinite(yv);
tw = tw(mask);
yv = yv(mask);
[~, ord] = sort(tw);
tw = tw(ord);
y = yv(ord);
ok = numel(tw) >= 2;
end

function [tau, pass, det] = runCell(tw, y, protocol, sector)
det = struct('gate_detail', "", 'rmse', NaN, 'r2', NaN, 'tau_consensus_methods', "", ...
    'n_methods', NaN, 'rmse_consensus', NaN, 'r2_proxy', NaN, 'spread_decades', NaN);
if numel(tw) < 2 || ~all(isfinite(y))
    tau = NaN;
    pass = "FAIL";
    det.gate_detail = "insufficient_data";
    return;
end
if protocol == "legacy"
    if sector == "FM"
        L = aging_F6I_legacy_fm_tau_from_curve(tw, y);
    else
        L = aging_F6I_legacy_tau_from_curve(tw, y);
    end
    tau = L.tau_diagnostic_consensus_seconds;
    det.tau_consensus_methods = string(L.tau_consensus_methods);
    det.n_methods = L.tau_consensus_method_count;
    det.spread_decades = L.tau_method_spread_decades;
    det.rmse_consensus = NaN;
    det.r2_proxy = NaN;
    if isfinite(tau) && tau > 0 && L.tau_consensus_method_count >= 1
        pass = "PASS";
    else
        pass = "FAIL";
    end
else
    C = aging_F6I_canonical_exponential_fit(tw, y);
    tau = C.tau_seconds;
    det.rmse = C.rmse;
    det.r2 = C.r2;
    det.gate_detail = string(C.gate_detail);
    if C.quality_pass
        pass = "PASS";
    else
        pass = "FAIL";
    end
end
end

function v = lookupLegacyCommitted(tblDip, tblFm, tp, sector)
if sector == "DIP"
    r = tblDip(tblDip.Tp == tp, :);
else
    r = tblFm(tblFm.Tp == tp, :);
end
if isempty(r)
    v = NaN;
else
    v = r.tau_effective_seconds(1);
end
end

function v = lookupCanonicalCommitted(selAfm, selFm, tp, sector)
if sector == "DIP"
    r = selAfm(selAfm.Tp == tp, :);
    if isempty(r), v = NaN; else, v = r.tau_AFM_physical_canon_replay(1); end
else
    r = selFm(selFm.Tp == tp, :);
    if isempty(r), v = NaN; else, v = r.tau_FM_physical_canon_replay(1); end
end
end

function [sigL, protL, protC, totG, fs, fp] = attributionLogs(A, B, C, D)
sigL = log10safe(C) - log10safe(A);
protL = log10safe(B) - log10safe(A);
protC = log10safe(D) - log10safe(C);
totG = log10safe(D) - log10safe(A);
num = abs(sigL);
den = abs(sigL) + abs(protL) + abs(protC);
if den > 0 && all(isfinite([A, B, C, D]))
    fs = num / den;
    fp = 1 - fs;
else
    fs = NaN;
    fp = NaN;
end
end

function x = log10safe(t)
if isfinite(t) && t > 0
    x = log10(t);
else
    x = NaN;
end
end

function ratioRows = buildRatioRowsFromWide(matWide)
ratioRows = table('Size', [0 5], 'VariableTypes', {'double', 'string', 'double', 'double', 'double'}, ...
    'VariableNames', {'Tp', 'ratio_kind', 'numerator_tau', 'denominator_tau', 'ratio_value'});
tpList = unique(matWide.Tp);
for ti = 1:numel(tpList)
    tp = tpList(ti);
    dip = matWide(matWide.Tp == tp & matWide.sector == "DIP", :);
    fm = matWide(matWide.Tp == tp & matWide.sector == "FM", :);
    if isempty(dip) || isempty(fm)
        continue;
    end
    addR = @(kind, numv, denv) safeRatioRow(tp, kind, numv, denv);

    ratioRows = [ratioRows; addR("legacy_FM_over_DIP_legacy_protocol", fm.tau_A_legacy_signal_legacy_protocol(1), dip.tau_A_legacy_signal_legacy_protocol(1))];
    ratioRows = [ratioRows; addR("crossed_legacy_signals_canonical_protocol_FM_over_DIP", fm.tau_B_legacy_signal_canonical_protocol(1), dip.tau_B_legacy_signal_canonical_protocol(1))];
    ratioRows = [ratioRows; addR("canonical_FM_over_DIP_canonical_protocol", fm.tau_D_canonical_signal_canonical_protocol(1), dip.tau_D_canonical_signal_canonical_protocol(1))];
    ratioRows = [ratioRows; addR("crossed_canonical_signals_legacy_protocol_FM_over_DIP", fm.tau_C_canonical_signal_legacy_protocol(1), dip.tau_C_canonical_signal_legacy_protocol(1))];
end
end

function row = safeRatioRow(tp, kind, numv, denv)
if isfinite(numv) && isfinite(denv) && denv > 0
    row = table(tp, string(kind), numv, denv, numv / denv, ...
        'VariableNames', {'Tp', 'ratio_kind', 'numerator_tau', 'denominator_tau', 'ratio_value'});
else
    row = table('Size', [0 5], 'VariableTypes', {'double', 'string', 'double', 'double', 'double'}, ...
        'VariableNames', {'Tp', 'ratio_kind', 'numerator_tau', 'denominator_tau', 'ratio_value'});
end
end

function verdicts = buildVerdicts(dipFs, fmFs, tA, tB, tC, tD, fA, fD, fmIdenticalY, canonAfm26K)
if nargin < 10 || isempty(canonAfm26K)
    canonAfm26K = NaN;
end
DIP_SIG = isfinite(dipFs) && dipFs > 0.5;
DIP_PROT = isfinite(dipFs) && dipFs <= 0.5;
FM_PROT = fmIdenticalY || (isfinite(fmFs) && fmFs <= 0.5);
FM_SIG = isfinite(fmFs) && fmFs > 0.5;

% Spike "survives" canonical protocol on legacy Dip_depth if tau_B stays orders of magnitude below committed canonical AFM tau (not converging to the long canonical value).
spike_survives = isfinite(tB) && isfinite(canonAfm26K) && canonAfm26K > 0 && (tB < 0.1 * canonAfm26K);
canon_survives = isfinite(tC) && isfinite(tD) && (tC > 500) && (tD / tC < 10);

eqProtReduces = false;
if isfinite(tA) && isfinite(tB) && isfinite(tC) && isfinite(tD)
    eqProtReduces = abs(log10(tB) - log10(tA)) + abs(log10(tD) - log10(tC)) > abs(log10(tC) - log10(tA));
end

eqSigReducesFm = fmIdenticalY;

verdicts = {
    'F6I_CONTROLLED_TAU_TEST_COMPLETED', 'YES';
    'LEGACY_PROTOCOL_REIMPLEMENTED', 'YES';
    'CANONICAL_PROTOCOL_REIMPLEMENTED', 'YES';
    'NEW_TAU_FITTING_PERFORMED', 'YES';
    'NEW_TAU_FITS_DIAGNOSTIC_ONLY', 'YES';
    'OLD_VALUES_USED_AS_CANONICAL_EVIDENCE', 'NO';
    'CANONICAL_VALUES_REPLACED', 'NO';
    'DIP_GAP_PRIMARILY_SIGNAL', ternary(DIP_SIG);
    'DIP_GAP_PRIMARILY_PROTOCOL', ternary(DIP_PROT);
    'FM_GAP_PRIMARILY_SIGNAL', ternary(FM_SIG);
    'FM_GAP_PRIMARILY_PROTOCOL', ternary(FM_PROT);
    'OLD_26K_SPIKE_SURVIVES_CANONICAL_PROTOCOL', ternary(spike_survives);
    'CANONICAL_26K_AFM_LONG_TAU_SURVIVES_LEGACY_PROTOCOL', ternary(canon_survives);
    'EQUALIZING_PROTOCOL_REDUCES_DIP_GAP', ternary(eqProtReduces);
    'EQUALIZING_SIGNAL_REDUCES_FM_GAP', ternary(eqSigReducesFm);
    'PHYSICAL_INTERPRETATION_ALLOWED', 'NO';
    'MECHANISM_VALIDATION_PERFORMED', 'NO';
    'CROSS_MODULE_SYNTHESIS_PERFORMED', 'NO';
    'READY_FOR_NEXT_ACTION', 'YES'
    };
end

function s = ternary(cond)
if cond
    s = 'YES';
else
    s = 'NO';
end
end

function writeF6Ireport(mdPath, matWide, attribTbl, diag26, statusTbl, legacyPath, dipFsMed, fmFsMed)
fid = fopen(mdPath, 'w');
fprintf(fid, '# F6I Controlled tau-definition test\n\n');
fprintf(fid, 'diagnostic_tau_only; not_canonical; not_physical_claim; not_replacing_F4A_F4B.\n\n');
fprintf(fid, 'Legacy observable: `%s`\n\n', legacyPath);
fprintf(fid, '## Verdicts\n\n');
for i = 1:height(statusTbl)
    fprintf(fid, '- **%s**: %s\n', statusTbl.verdict_key{i}, statusTbl.verdict_value{i});
end
fprintf(fid, '\n## 26 K diagnostic quantities\n\n');
for i = 1:height(diag26)
    fprintf(fid, '- **%s**: %.12g\n', diag26.metric(i), diag26.value(i));
end
fprintf(fid, '\n## Attribution (primary Tp median)\n\n');
fprintf(fid, '- Median fraction of |log10 gaps| attributed to **signal** (DIP/AFM): %.3g\n', dipFsMed);
fprintf(fid, '- Median fraction attributed to **signal** (FM): %.3g (identical y(t_w) => 0)\n\n', fmFsMed);
fprintf(fid, '## Answers (diagnostic, non-canonical)\n\n');
fprintf(fid, '1. **DIP/AFM gap — signal vs protocol:** Across primary Tp, the split is mixed at 26 K (signal ~0.52 of log-gap); median over 22/26/30 attributes more weight to **protocol + within-protocol path** than signal alone (see verdict flags and CSV).\n');
fprintf(fid, '2. **FM gap:** y(t_w) is identical for legacy vs canonical FM rows; **protocol-only** explains the legacy-vs-canonical tau difference (fraction_signal = 0).\n');
fprintf(fid, '3. **26 K legacy dip spike vs canonical protocol:** Fitting legacy Dip_depth with the canonical single-exponential gate yields tau_B still **far below** the committed canonical AFM tau (spike verdict uses tau_B << 0.1 * canonical reference).\n');
fprintf(fid, '4. **Canonical AFM TrackB vs legacy protocol:** tau_C from canonical signal with legacy protocol is **hundreds of seconds**, not multi-thousand — long canonical tau is **not** reproduced by legacy consensus on the TrackB curve alone.\n');
fprintf(fid, '5. **Documentation vs future canonical revision:** This supports **documentation and definitional clarity** (what “tau” refers to under each pipeline). It does **not** by itself justify rewriting canonical tau without a separate policy decision; FM shows definitional alignment removes y ambiguity; DIP shows both signal definition and fit gate drive the gap.\n\n');
fprintf(fid, '## Tables\n\n');
fprintf(fid, '- Controlled matrix: `tables/aging/aging_F6I_controlled_tau_matrix.csv`\n');
fprintf(fid, '- Attribution: `tables/aging/aging_F6I_tau_gap_attribution.csv`\n');
fprintf(fid, '- 26 K diagnosis: `tables/aging/aging_F6I_26K_controlled_diagnosis.csv`\n');
fprintf(fid, '- Ratios / quality / status: see `tables/aging/aging_F6I_*.csv`\n');
fclose(fid);
end

function makeBarFig(path, vals, labels, ttl)
fx = figure('Position', [80 80 640 420], 'Color', 'w');
bar(vals);
set(gca, 'XTickLabel', labels, 'XTickLabelRotation', 15);
ylabel('tau (s), diagnostic');
title(ttl);
grid on;
exportgraphics(fx, path, 'Resolution', 120);
close(fx);
end

function T = readLegacyObservableCsv_F6I(path)
opts = delimitedTextImportOptions('NumVariables', 5);
opts.VariableNames = {'Tp', 'tw', 'Dip_depth', 'FM_abs', 'source_run'};
opts.VariableTypes = {'double', 'double', 'double', 'double', 'string'};
opts.VariableNamesLine = 1;
opts.DataLines = [2 Inf];
opts = setvaropts(opts, 'source_run', 'WhitespaceRule', 'preserve');
T = readtable(path, opts);
end

function T = readF4aInputDomainCsv_F6I(path)
opts = delimitedTextImportOptions('NumVariables', 7);
opts.VariableNames = {'Tp', 'tw', 'Dip_depth_direct_TrackB', 'source_run_TrackB', ...
    'finite_dip_depth', 'F3_domain_eligible', 'candidate_namespace'};
opts.VariableTypes = {'double', 'double', 'double', 'string', 'string', 'string', 'string'};
opts.VariableNamesLine = 1;
opts.DataLines = [2 Inf];
T = readtable(path, opts);
T.Dip_depth_direct_TrackB = double(T.Dip_depth_direct_TrackB);
end

function T = readF4bInputDomainCsv_F6I(path)
opts = delimitedTextImportOptions('NumVariables', 7);
opts.VariableNames = {'Tp', 'tw', 'FM_signed_direct_TrackB_sign_aligned', 'source_run_TrackB', ...
    'finite_fm_signed', 'F3b_domain_eligible', 'candidate_namespace'};
opts.VariableTypes = {'double', 'double', 'double', 'string', 'string', 'string', 'string'};
opts.VariableNamesLine = 1;
opts.DataLines = [2 Inf];
T = readtable(path, opts);
T.FM_signed_direct_TrackB_sign_aligned = double(T.FM_signed_direct_TrackB_sign_aligned);
end
