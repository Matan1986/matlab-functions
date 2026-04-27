% F6H - Pre-fit y(tw) curve audit: legacy Dip_depth/FM_abs vs canonical TrackB inputs.
% Writes tables/aging/aging_F6H_*.csv, reports/aging/aging_F6H_prefit_tau_shape_mismatch_audit.md,
% figures/aging_F6H_prefit_*_Tp22_26_30.png. Does not modify F4A/F4B outputs.
%
% Execute via: tools\run_matlab_safe.bat "<ABS_PATH>\run_aging_F6H_prefit_tau_shape_mismatch_audit.m"

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('F6H:RepoRootMissing', 'Repository root not found: %s', repoRoot);
end

fidTopProbe = fopen(fullfile(repoRoot, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_F6H_prefit_shape_audit';
cfg.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F6H_prefit_tau_shape_mismatch_audit.m');

executionStatus = table({'FAILED'}, {'NO'}, {'Not started'}, 0, {'F6H pre-fit audit not executed'}, ...
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

    pointerPath = fullfile(run.repo_root, 'run_dir_pointer.txt');
    fidPointer = fopen(pointerPath, 'w');
    if fidPointer < 0
        error('F6H:PointerWriteFailed', 'Failed to write run_dir_pointer.txt');
    end
    fprintf(fidPointer, '%s\n', run.run_dir);
    fclose(fidPointer);

    rp = @(rel) fullfile(repoRoot, strrep(rel, '/', filesep));

    legacyPath = rp('results_old/aging/runs/run_2026_03_12_211204_aging_dataset_build/tables/aging_observable_dataset.csv');
    tauDipOldPath = rp('results_old/aging/runs/run_2026_03_12_223709_aging_timescale_extraction/tables/tau_vs_Tp.csv');
    tauFmOldPath = rp('results_old/aging/runs/run_2026_03_13_013634_aging_fm_timescale_analysis/tables/tau_FM_vs_Tp.csv');

    f4aDomain = rp('tables/aging/aging_F4A_AFM_tau_input_domain.csv');
    f4aFits = rp('tables/aging/aging_F4A_AFM_tau_model_fits.csv');
    f4aSel = rp('tables/aging/aging_F4A_AFM_tau_selected_values.csv');
    f4aQual = rp('tables/aging/aging_F4A_AFM_tau_fit_quality.csv');

    f4bDomain = rp('tables/aging/aging_F4B_FM_tau_input_domain.csv');
    f4bFits = rp('tables/aging/aging_F4B_FM_tau_model_fits.csv');
    f4bSel = rp('tables/aging/aging_F4B_FM_tau_selected_values.csv');
    f4bQual = rp('tables/aging/aging_F4B_FM_tau_fit_quality.csv');

    req = { legacyPath; tauDipOldPath; tauFmOldPath; f4aDomain; f4aFits; f4aSel; f4aQual; ...
        f4bDomain; f4bFits; f4bSel; f4bQual };
    for ii = 1:numel(req)
        assert(exist(req{ii}, 'file') == 2, 'F6H:MissingRequiredInput:%s', req{ii});
    end

    tblLegacy = readLegacyObservableCsv(legacyPath);

    tblTauDip = readtable(tauDipOldPath, 'TextType', 'string');
    tblTauFm = readtable(tauFmOldPath, 'TextType', 'string');

    tblAfmIn = readF4aInputDomainCsv(f4aDomain);
    tblFmIn = readF4bInputDomainCsv(f4bDomain);

    primaryTp = [22; 26; 30];
    secondaryTp = [14; 18; 34];
    allTp = unique([primaryTp; secondaryTp]);

    %% Tw domain comparison
    rowsDom = table('Size', [0 12], ...
        'VariableTypes', { 'double', 'string', 'string', 'string', 'string', ...
        'double', 'double', 'double', 'string', 'string', 'string', 'string' }, ...
        'VariableNames', { ...
        'Tp', 'sector', 'legacy_tw_list', 'canonical_tw_list', 'intersection_tw_list', ...
        'n_legacy_tw', 'n_canonical_tw', 'n_intersection', ...
        'missing_in_canonical_relative_to_legacy', 'missing_in_legacy_relative_to_canonical', ...
        'domains_directly_comparable', 'notes' });

    for ti = 1:numel(allTp)
        tp = allTp(ti);
        leg = tblLegacy(tblLegacy.Tp == tp, :);
        twLdip = sort(unique(leg.tw(~isnan(leg.Dip_depth))));
        twLfm = sort(unique(leg.tw(~isnan(leg.FM_abs))));

        afm = tblAfmIn(tblAfmIn.Tp == tp, :);
        twA = sort(unique(afm.tw));

        fm = tblFmIn(tblFmIn.Tp == tp, :);
        twF = sort(unique(fm.tw(~isnan(fm.FM_signed_direct_TrackB_sign_aligned))));

        interD = intersect(twLdip, twA);
        interF = intersect(twLfm, twF);

        rowsDom = [rowsDom; table( ...
            tp, "DIP", joinTw(twLdip), joinTw(twA), joinTw(interD), ...
            numel(twLdip), numel(twA), numel(interD), ...
            fmtMissing(twLdip, twA), fmtMissing(twA, twLdip), ...
            string(domainComparable(numel(interD), twLdip, twA)), ...
            sprintf("legacy Dip_depth vs TrackB Dip_depth_direct; intersection n=%d", numel(interD)), ...
            'VariableNames', rowsDom.Properties.VariableNames)];

        rowsDom = [rowsDom; table( ...
            tp, "FM", joinTw(twLfm), joinTw(twF), joinTw(interF), ...
            numel(twLfm), numel(twF), numel(interF), ...
            fmtMissing(twLfm, twF), fmtMissing(twF, twLfm), ...
            string(domainComparable(numel(interF), twLfm, twF)), ...
            sprintf("legacy FM_abs vs signed TrackB FM; intersection n=%d", numel(interF)), ...
            'VariableNames', rowsDom.Properties.VariableNames)];
    end

    getLegacyDip = @(tp) extractCurve(tblLegacy, tp, 'tw', 'Dip_depth');
    getLegacyFm = @(tp) extractCurve(tblLegacy, tp, 'tw', 'FM_abs');
    getCanonDip = @(tp) extractCurve(tblAfmIn, tp, 'tw', 'Dip_depth_direct_TrackB');
    getCanonFm = @(tp) extractCurve(tblFmIn, tp, 'tw', 'FM_signed_direct_TrackB_sign_aligned');

    %% Shape metrics (full curves per side) + scale tests (shared tw)
    shapeRows = table();
    scaleRows = table();

    sectors = ["DIP", "FM"];
    for si = 1:numel(sectors)
        sec = sectors(si);
        for ti = 1:numel(allTp)
            tp = allTp(ti);
            if sec == "DIP"
                cL = getLegacyDip(tp);
                cC = getCanonDip(tp);
                curveL = "legacy_Dip_depth";
                curveC = "canonical_Dip_depth_direct_TrackB";
            else
                cL = getLegacyFm(tp);
                cC = getCanonFm(tp);
                curveL = "legacy_FM_abs";
                curveC = "canonical_FM_signed_TrackB";
            end

            shapeRows = [shapeRows; shapeMetrics(cL.tw, cL.y, curveL, tp)];
            shapeRows = [shapeRows; shapeMetrics(cC.tw, cC.y, curveC, tp)];

            [twS, yL, yC] = alignedPair(cL, cC);

            if numel(twS) >= 2 && all(isfinite(yL)) && all(isfinite(yC))
                [aa, bb, ra, nrmA] = affineFit(yL, yC);
                [as, rs, nrmS] = scaleFit(yL, yC);
                compat = shapeCompatible(ra, rs, nrmA, aa);
                note = sprintf('shared_tw=%s', joinTw(twS));
                scaleRows = [scaleRows; table(tp, sec, numel(twS), aa, bb, ra, nrmA, as, rs, nrmS, string(compat), string(note), ...
                    'VariableNames', {'Tp', 'sector', 'n_shared_tw', 'affine_a', 'affine_b', 'affine_r2', 'affine_nrmse', ...
                    'scale_only_a', 'scale_only_r2', 'scale_only_nrmse', 'SHAPE_COMPATIBLE_UP_TO_SCALE', 'notes'})];
            else
                scaleRows = [scaleRows; table(tp, sec, numel(twS), NaN, NaN, NaN, NaN, NaN, NaN, NaN, "NO", ...
                    "insufficient overlapping finite points", ...
                    'VariableNames', {'Tp', 'sector', 'n_shared_tw', 'affine_a', 'affine_b', 'affine_r2', 'affine_nrmse', ...
                    'scale_only_a', 'scale_only_r2', 'scale_only_nrmse', 'SHAPE_COMPATIBLE_UP_TO_SCALE', 'notes'})];
            end
        end
    end

    %% 26 K focused
    tpk = 26;
    [tw26d, yLd, yCd] = alignedPair(getLegacyDip(tpk), getCanonDip(tpk));
    [tw26f, yLf, yCf] = alignedPair(getLegacyFm(tpk), getCanonFm(tpk));

    smCd = shapeMetrics(getCanonDip(tpk).tw, getCanonDip(tpk).y, "canonical_Dip_depth_direct_TrackB", tpk);

    rowScaleDip = scaleRows(scaleRows.Tp == tpk & scaleRows.sector == "DIP", :);
    rowScaleFm = scaleRows(scaleRows.Tp == tpk & scaleRows.sector == "FM", :);

    dipIncompat = rowScaleDip.SHAPE_COMPATIBLE_UP_TO_SCALE ~= "YES";
    fmIncompat = rowScaleFm.SHAPE_COMPATIBLE_UP_TO_SCALE ~= "YES";

    canonLateDom = logical(smCd.last_point_dominates_range(1));
    canonNonmono = smCd.monotonic_class == "nonmonotonic";

    legacyFastHalf = false;
    row26tau = tblTauDip(tblTauDip.Tp == tpk, :);
    if ~isempty(row26tau)
        legacyFastHalf = row26tau.tau_logistic_half_seconds(1) < 30 && row26tau.tau_half_range_seconds(1) < 30;
    end

    focMetrics = [ ...
        "legacy_dip_y_tw"; "canonical_afm_y_tw"; "legacy_fm_y_tw"; "canonical_fm_y_tw"; ...
        "dip_scale_r2"; "dip_affine_r2"; "fm_scale_r2"; "fm_affine_r2"; ...
        "dip_tau_mismatch_visible_prefit"; "fm_tau_mismatch_visible_prefit"; ...
        "canonical_afm_late_point_dominated"; "canonical_afm_nonmonotonic"; "legacy_dip_fast_half_rise_heuristic"];

    focVals = { ...
        vec2str(tw26d, yLd); vec2str(tw26d, yCd); vec2str(tw26f, yLf); vec2str(tw26f, yCf); ...
        rowScaleDip.scale_only_r2(1); rowScaleDip.affine_r2(1); ...
        rowScaleFm.scale_only_r2(1); rowScaleFm.affine_r2(1); ...
        char(ternCell(dipIncompat)); char(ternCell(fmIncompat)); ...
        char(ternCell(canonLateDom)); char(ternCell(canonNonmono)); char(ternCell(legacyFastHalf))};

    focus26 = table(focMetrics, focVals(:), 'VariableNames', {'metric', 'value_26K'});

    %% Fit source (existing tables only)
    rDip = tblTauDip(tblTauDip.Tp == 26, :);
    rFm = tblTauFm(tblTauFm.Tp == 26, :);

    afmSel26 = readtable(f4aSel, 'TextType', 'string');
    afmSel26 = afmSel26(afmSel26.Tp == 26, :);
    fmSel26 = readtable(f4bSel, 'TextType', 'string');
    fmSel26 = fmSel26(fmSel26.Tp == 26, :);
    afmQ26 = readtable(f4aQual, 'TextType', 'string');
    afmQ26 = afmQ26(afmQ26.Tp == 26, :);

    dipCode = classifyABCD(dipIncompat, fmIncompat);

    fitFields = { ...
        'legacy_26K_dip_tau_consensus_seconds'; ...
        'legacy_26K_dip_tau_logistic_half_seconds'; ...
        'legacy_26K_dip_tau_stretched_half_seconds'; ...
        'legacy_26K_dip_tau_half_range_seconds'; ...
        'legacy_26K_dip_consensus_methods'; 'legacy_26K_dip_method_count'; ...
        'legacy_26K_dip_method_spread_decades'; 'legacy_26K_fm_tau_consensus_seconds'; 'legacy_26K_fm_consensus_methods'; ...
        'legacy_26K_fm_method_count'; 'legacy_26K_fm_method_spread_decades'; ...
        'canonical_26K_AFM_selected_model'; 'canonical_26K_AFM_tau_seconds'; 'canonical_26K_AFM_r2_primary'; ...
        'canonical_26K_AFM_rmse_primary'; 'canonical_26K_FM_selected_model'; 'canonical_26K_FM_tau_seconds'; ...
        'canonical_26K_FM_r2_primary'; 'mismatch_ABCD_code'; 'mismatch_note'};

    fitVals = { ...
        rDip.tau_effective_seconds(1); ...
        rDip.tau_logistic_half_seconds(1); ...
        rDip.tau_stretched_half_seconds(1); ...
        rDip.tau_half_range_seconds(1); ...
        char(rDip.tau_consensus_methods(1)); rDip.tau_consensus_method_count(1); ...
        rDip.tau_method_spread_decades(1); rFm.tau_effective_seconds(1); char(rFm.tau_consensus_methods(1)); ...
        rFm.tau_consensus_method_count(1); rFm.tau_method_spread_decades(1); ...
        char(afmSel26.selected_model(1)); afmSel26.tau_AFM_physical_canon_replay(1); afmSel26.r2_primary(1); ...
        afmQ26.rmse_primary(1); char(fmSel26.selected_model(1)); fmSel26.tau_FM_physical_canon_replay(1); ...
        fmSel26.r2_primary(1); dipCode; ...
        'Legacy dip: consensus tau_effective_seconds blends logistic_log_tw, stretched_exp, half_range (tau_vs_Tp row). Canonical AFM/FM: single_exponential_approach_primary selection in model_fits + selected_values.' };

    fitResp = table(fitFields(:), fitVals(:), 'VariableNames', {'field', 'value'});

    %% Verdicts
    dipPrim = scaleRows(ismember(scaleRows.Tp, primaryTp) & scaleRows.sector == "DIP", :);
    fmPrim = scaleRows(ismember(scaleRows.Tp, primaryTp) & scaleRows.sector == "FM", :);
    dipCompatAll = height(dipPrim) == numel(primaryTp) && all(dipPrim.SHAPE_COMPATIBLE_UP_TO_SCALE == "YES");
    fmCompatAll = height(fmPrim) == numel(primaryTp) && all(fmPrim.SHAPE_COMPATIBLE_UP_TO_SCALE == "YES");

    idxDomPrimDip = ismember(rowsDom.Tp, primaryTp) & rowsDom.sector == "DIP";
    sharedExists = all(rowsDom.n_intersection(idxDomPrimDip) >= 2);

    fmFitModelCause = fmIncompat == false;
    signalShapeCause = dipIncompat;
    domainGateCause = sharedExists == false;

    verdicts = {
        'F6H_PREFIT_SHAPE_AUDIT_COMPLETED', 'YES';
        'LEGACY_PREFIT_DATA_FOUND', 'YES';
        'CANONICAL_PREFIT_DATA_FOUND', 'YES';
        'SHARED_TW_DOMAIN_EXISTS', char(ternCell(sharedExists));
        'DIP_SHAPE_COMPATIBLE_UP_TO_SCALE', char(ternCell(dipCompatAll));
        'FM_SHAPE_COMPATIBLE_UP_TO_SCALE', char(ternCell(fmCompatAll));
        'DIP_TAU_MISMATCH_VISIBLE_PREFIT', char(ternCell(dipIncompat));
        'FM_TAU_MISMATCH_VISIBLE_PREFIT', char(ternCell(fmIncompat));
        'CANONICAL_26K_AFM_LATE_POINT_DOMINATED', char(ternCell(canonLateDom));
        'CANONICAL_26K_AFM_NONMONOTONIC', char(ternCell(canonNonmono));
        'LEGACY_26K_DIP_FAST_HALF_RISE', char(ternCell(legacyFastHalf));
        'FIT_MODEL_PRIMARY_CAUSE', char(ternCell(fmFitModelCause));
        'SIGNAL_SHAPE_PRIMARY_CAUSE', char(ternCell(signalShapeCause));
        'DOMAIN_GATE_PRIMARY_CAUSE', char(ternCell(domainGateCause));
        'OLD_VALUES_USED_AS_CANONICAL_EVIDENCE', 'NO';
        'NEW_TAU_FITTING_PERFORMED', 'NO';
        'MECHANISM_VALIDATION_PERFORMED', 'NO';
        'CROSS_MODULE_SYNTHESIS_PERFORMED', 'NO';
        'READY_FOR_NEXT_ACTION', 'YES'
        };

    statusTbl = cell2table(verdicts, 'VariableNames', {'verdict_key', 'verdict_value'});

    %% Write repo outputs
    outTables = rp('tables/aging');
    outRep = rp('reports/aging');
    outFig = rp('figures');
    if exist(outTables, 'dir') ~= 7, mkdir(outTables); end
    if exist(outRep, 'dir') ~= 7, mkdir(outRep); end
    if exist(outFig, 'dir') ~= 7, mkdir(outFig); end

    writetable(rowsDom, fullfile(outTables, 'aging_F6H_prefit_tw_domain_comparison.csv'));
    writetable(shapeRows, fullfile(outTables, 'aging_F6H_prefit_shape_metrics.csv'));
    writetable(scaleRows, fullfile(outTables, 'aging_F6H_prefit_scale_affine_tests.csv'));
    writetable(focus26, fullfile(outTables, 'aging_F6H_26K_focused_diagnosis.csv'));
    writetable(fitResp, fullfile(outTables, 'aging_F6H_fit_source_responsibility.csv'));
    writetable(statusTbl, fullfile(outTables, 'aging_F6H_prefit_shape_audit_status.csv'));

    writetable(rowsDom, fullfile(runTablesDir, 'aging_F6H_prefit_tw_domain_comparison.csv'));
    writetable(shapeRows, fullfile(runTablesDir, 'aging_F6H_prefit_shape_metrics.csv'));
    writetable(scaleRows, fullfile(runTablesDir, 'aging_F6H_prefit_scale_affine_tests.csv'));
    writetable(focus26, fullfile(runTablesDir, 'aging_F6H_26K_focused_diagnosis.csv'));
    writetable(fitResp, fullfile(runTablesDir, 'aging_F6H_fit_source_responsibility.csv'));
    writetable(statusTbl, fullfile(runTablesDir, 'aging_F6H_prefit_shape_audit_status.csv'));

    %% Figures
    figDip = makeOverlayFig(primaryTp, getLegacyDip, getCanonDip, ...
        'legacy Dip\_depth', 'canonical Dip\_depth direct TrackB', 'F6H DIP pre-fit shape (normalized)');
    exportgraphics(figDip, fullfile(outFig, 'aging_F6H_prefit_dip_shape_overlay_Tp22_26_30.png'), 'Resolution', 150);
    exportgraphics(figDip, fullfile(runFigDir, 'aging_F6H_prefit_dip_shape_overlay_Tp22_26_30.png'), 'Resolution', 150);
    close(figDip);

    figFm = makeOverlayFig(primaryTp, getLegacyFm, getCanonFm, ...
        'legacy FM\_abs', 'canonical FM signed TrackB', 'F6H FM pre-fit shape (normalized)');
    exportgraphics(figFm, fullfile(outFig, 'aging_F6H_prefit_fm_shape_overlay_Tp22_26_30.png'), 'Resolution', 150);
    exportgraphics(figFm, fullfile(runFigDir, 'aging_F6H_prefit_fm_shape_overlay_Tp22_26_30.png'), 'Resolution', 150);
    close(figFm);

    mdPath = fullfile(outRep, 'aging_F6H_prefit_tau_shape_mismatch_audit.md');
    writeReport(mdPath, scaleRows, focus26, fitResp, statusTbl, legacyPath);
    copyfile(mdPath, fullfile(runReportsDir, 'aging_F6H_prefit_tau_shape_mismatch_audit.md'));

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, numel(allTp), ...
        {'F6H pre-fit audit tables, figures, report written'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    executionStatus = table({'FAILED'}, {'YES'}, {ME.message}, 0, ...
        {'F6H failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    runDirFail = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_F6H_failure');
    if ~isempty(run) && isstruct(run) && isfield(run, 'run_dir') && strlength(string(run.run_dir)) > 0
        runDirFail = run.run_dir;
    end
    if exist(runDirFail, 'dir') ~= 7
        mkdir(runDirFail);
    end
    writetable(executionStatus, fullfile(runDirFail, 'execution_status.csv'));
    rethrow(ME);
end

if ~isempty(run) && isstruct(run) && isfield(run, 'run_dir')
    writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
end

%% ---- Local functions ----
function T = readLegacyObservableCsv(path)
opts = delimitedTextImportOptions('NumVariables', 5);
opts.VariableNames = {'Tp', 'tw', 'Dip_depth', 'FM_abs', 'source_run'};
opts.VariableTypes = {'double', 'double', 'double', 'double', 'string'};
opts.VariableNamesLine = 1;
opts.DataLines = [2 Inf];
opts = setvaropts(opts, 'source_run', 'WhitespaceRule', 'preserve');
T = readtable(path, opts);
end

function T = readF4aInputDomainCsv(path)
opts = delimitedTextImportOptions('NumVariables', 7);
opts.VariableNames = {'Tp', 'tw', 'Dip_depth_direct_TrackB', 'source_run_TrackB', ...
    'finite_dip_depth', 'F3_domain_eligible', 'candidate_namespace'};
opts.VariableTypes = {'double', 'double', 'double', 'string', 'string', 'string', 'string'};
opts.VariableNamesLine = 1;
opts.DataLines = [2 Inf];
T = readtable(path, opts);
T.Dip_depth_direct_TrackB = double(T.Dip_depth_direct_TrackB);
end

function T = readF4bInputDomainCsv(path)
opts = delimitedTextImportOptions('NumVariables', 7);
opts.VariableNames = {'Tp', 'tw', 'FM_signed_direct_TrackB_sign_aligned', 'source_run_TrackB', ...
    'finite_fm_signed', 'F3b_domain_eligible', 'candidate_namespace'};
opts.VariableTypes = {'double', 'double', 'double', 'string', 'string', 'string', 'string'};
opts.VariableNamesLine = 1;
opts.DataLines = [2 Inf];
T = readtable(path, opts);
T.FM_signed_direct_TrackB_sign_aligned = double(T.FM_signed_direct_TrackB_sign_aligned);
end

function s = extractCurve(tbl, tp, twField, yField)
sub = tbl(tbl.Tp == tp, :);
twRaw = double(sub.(twField));
yvRaw = double(sub.(yField));
mask = ~isnan(yvRaw) & ~isnan(twRaw);
twRaw = twRaw(mask);
yvRaw = yvRaw(mask);
if isempty(twRaw)
    s.tw = []; s.y = []; return;
end
[u, ~, ic] = unique(twRaw);
acc = accumarray(ic, yvRaw, [], @mean);
s.tw = u;
s.y = acc;
[~, ord] = sort(s.tw);
s.tw = s.tw(ord);
s.y = s.y(ord);
end

function [twS, yL, yC] = alignedPair(tl, tc)
twS = intersect(tl.tw, tc.tw);
yL = nan(numel(twS), 1);
yC = nan(numel(twS), 1);
for k = 1:numel(twS)
    idxL = tl.tw == twS(k);
    idxC = tc.tw == twS(k);
    yL(k) = mean(tl.y(idxL));
    yC(k) = mean(tc.y(idxC));
end
end

function s = shapeMetrics(tw, y, curveId, tp)
if isempty(tw)
    s = emptyShapeRow(curveId, tp); return;
end
dy = diff(y);
tol = max(1, max(abs(y))) * 1e-12;
if all(dy >= -tol)
    mc = "increasing";
elseif all(dy <= tol)
    mc = "decreasing";
elseif (max(y) - min(y)) <= tol * 10
    mc = "flat_noisy";
else
    mc = "nonmonotonic";
end
sg = sign(dy);
sg(sg == 0) = 1;
if numel(sg) < 2
    turns = 0;
else
    turns = sum(sg(1:end - 1) ~= sg(2:end));
end
dr = max(y) - min(y);
relDr = dr / max(max(abs(y)), eps);
[~, imax] = max(y);
peakTw = tw(imax);
hr = halfRiseTw(tw, y);
earlyC = contrastAt(tw, y, 3, 36);
lateC = contrastAt(tw, y, 360, 3600);
lastDom = false;
if numel(y) >= 2 && dr > 0
    [~, idxMax] = max(y);
    if idxMax == numel(y)
        jump = y(end) - y(end - 1);
        lastDom = abs(jump) / dr > 0.35;
    end
end

s = table(tp, curveId, numel(tw), min(tw), max(tw), dr, relDr, mc, turns, peakTw, hr, NaN, earlyC, lateC, lastDom, ...
    sprintf("n=%d", numel(tw)), ...
    'VariableNames', { ...
    'Tp', 'curve_id', 'n_points', 'tw_min_seconds', 'tw_max_seconds', 'dynamic_range', ...
    'relative_dynamic_range', 'monotonic_class', 'n_turns', 'peak_tw_seconds', ...
    'half_rise_tw_seconds_linear', 'half_range_seconds_heuristic', 'early_contrast_y36_minus_y3', ...
    'late_contrast_y3600_minus_y360', 'last_point_dominates_range', 'notes' });
end

function s = emptyShapeRow(curveId, tp)
s = table(tp, curveId, 0, NaN, NaN, NaN, NaN, "flat_noisy", NaN, NaN, NaN, NaN, NaN, NaN, false, "empty", ...
    'VariableNames', { ...
    'Tp', 'curve_id', 'n_points', 'tw_min_seconds', 'tw_max_seconds', 'dynamic_range', ...
    'relative_dynamic_range', 'monotonic_class', 'n_turns', 'peak_tw_seconds', ...
    'half_rise_tw_seconds_linear', 'half_range_seconds_heuristic', 'early_contrast_y36_minus_y3', ...
    'late_contrast_y3600_minus_y360', 'last_point_dominates_range', 'notes' });
end

function hr = halfRiseTw(tw, y)
hr = NaN;
if numel(y) < 2, return; end
ymin = min(y); ymax = max(y);
rng = ymax - ymin;
if rng <= eps * max(1, ymax), return; end
target = ymin + 0.5 * rng;
for k = 1:numel(y) - 1
    if (y(k) - target) * (y(k + 1) - target) <= 0
        tlo = tw(k); thi = tw(k + 1);
        ylo = y(k); yhi = y(k + 1);
        if abs(yhi - ylo) < eps
            hr = 0.5 * (tlo + thi);
        else
            hr = tlo + (target - ylo) * (thi - tlo) / (yhi - ylo);
        end
        return;
    end
end
end

function c = contrastAt(tw, y, ta, tb)
ia = find(abs(tw - ta) < 1e-6, 1);
ib = find(abs(tw - tb) < 1e-6, 1);
if isempty(ia) || isempty(ib)
    c = NaN;
else
    c = y(ib) - y(ia);
end
end

function [a, b, r2, nrmse] = affineFit(x, y)
n = numel(x);
X = [ones(n, 1), x(:)];
beta = X \ y(:);
b = beta(1);
a = beta(2);
pred = X * beta;
ssRes = sum((y(:) - pred).^2);
ssTot = sum((y(:) - mean(y)).^2);
if ssTot <= eps
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
end
nrmse = sqrt(mean((y(:) - pred).^2)) / max(std(y(:)), eps);
end

function [a, r2, nrmse] = scaleFit(x, y)
den = sum(x.^2);
if den <= 0
    a = NaN; r2 = NaN; nrmse = NaN; return;
end
a = sum(x .* y) / den;
pred = a * x;
ssRes = sum((y - pred).^2);
ssTot = sum((y - mean(y)).^2);
if ssTot <= eps
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
end
nrmse = sqrt(mean((y - pred).^2)) / max(std(y), eps);
end

function ok = shapeCompatible(rAffine, rScale, nrmA, a)
ok = "NO";
if isnan(rAffine), return; end
if max(rAffine, rScale) >= 0.90 && nrmA < 0.35 && a > 0
    ok = "YES";
elseif max(rAffine, rScale) >= 0.95 && nrmA < 0.5
    ok = "YES";
end
end

function s = fmtMissing(a, b)
miss = setdiff(a, b);
if isempty(miss)
    s = "";
else
    s = strjoin(string(miss'), ',');
end
end

function s = domainComparable(nInter, twA, twB)
if nInter >= 3 && abs(numel(twA) - numel(twB)) <= 1
    s = 'YES';
elseif nInter >= 2
    s = 'PARTIAL';
else
    s = 'NO';
end
end

function s = joinTw(v)
if isempty(v)
    s = "";
else
    s = strjoin(string(v'), ',');
end
end

function s = vec2str(tw, y)
parts = strings(numel(y), 1);
for i = 1:numel(y)
    parts(i) = sprintf('%.6e', y(i));
end
s = sprintf('tw:[%s] y:[%s]', strjoin(string(tw'), ','), strjoin(parts, ' '));
end

function s = ternCell(cond)
if cond
    s = 'YES';
else
    s = 'NO';
end
end

function code = classifyABCD(dipInc, fmInc)
if dipInc && ~fmInc
    code = 'A_DIP_PREFIT_SHAPE_B_FM_FIT_PIPELINE';
elseif dipInc && fmInc
    code = 'A_PREFIT_SHAPE_BOTH';
elseif ~dipInc && fmInc
    code = 'B_OR_C_FM_ONLY';
else
    code = 'D_SIMILAR_CURVES_CHECK_FIT';
end
end

function fig = makeOverlayFig(tpList, fnLeg, fnCan, lblL, lblC, ttl)
fig = figure('Position', [100 100 900 520], 'Color', 'w');
hold on;
cols = lines(numel(tpList));
mk = {'o', 's', '^'};
for ti = 1:numel(tpList)
    tp = tpList(ti);
    sL = fnLeg(tp);
    sC = fnCan(tp);
    [twS, yL, yC] = alignedPair(sL, sC);
    if isempty(twS), continue; end
    rngL = max(yL) - min(yL);
    rngC = max(yC) - min(yC);
    if rngL <= eps
        yLn = zeros(size(yL));
    else
        yLn = (yL - min(yL)) / rngL;
    end
    if rngC <= eps
        yCn = zeros(size(yC));
    else
        yCn = (yC - min(yC)) / rngC;
    end
    lx = log10(double(twS));
    plot(lx, yLn, '-', 'Color', cols(ti, :), 'LineWidth', 1.2);
    plot(lx, yCn, '--', 'Color', cols(ti, :), 'LineWidth', 1.4);
    plot(lx, yLn, mk{mod(ti - 1, numel(mk)) + 1}, 'Color', cols(ti, :), 'MarkerFaceColor', cols(ti, :));
    plot(lx, yCn, mk{mod(ti - 1, numel(mk)) + 1}, 'Color', cols(ti, :), 'MarkerEdgeColor', cols(ti, :), 'MarkerFaceColor', 'none');
end
hold off;
grid on;
xlabel('log_{10}(tw / s)');
ylabel('min-max normalized y');
title(sprintf('%s (solid/filled=%s, dashed/open=%s)', ttl, lblL, lblC));
legendEntries = {};
for ti = 1:numel(tpList)
    legendEntries{end + 1} = sprintf('Tp=%d legacy', tpList(ti)); %#ok<AGROW>
    legendEntries{end + 1} = sprintf('Tp=%d canonical', tpList(ti)); %#ok<AGROW>
end
legend(legendEntries, 'Location', 'eastoutside', 'FontSize', 8);
end

function writeReport(mdPath, scaleRows, focus26, fitResp, statusTbl, legacyPath)
fid = fopen(mdPath, 'w');
assert(fid >= 0, 'report');
fprintf(fid, '# F6H Pre-fit tau shape mismatch audit (Aging)\n\n');
fprintf(fid, 'Legacy observable dataset: `%s`\n\n', legacyPath);
fprintf(fid, '## Summary\n\n');
fprintf(fid, 'Compares legacy `Dip_depth` / `FM_abs` to canonical TrackB columns on shared `tw`. ');
fprintf(fid, 'No new tau fitting; F4A/F4B tables unchanged.\n\n');
fprintf(fid, '## Verdicts\n\n');
for i = 1:height(statusTbl)
    fprintf(fid, '- **%s**: %s\n', statusTbl.verdict_key{i}, statusTbl.verdict_value{i});
end
fprintf(fid, '\n## Scale/affine tests (primary Tp 22, 26, 30)\n\n');
fprintf(fid, '| Tp | sector | n_shared | affine R2 | scale R2 | compatible |\n|---|---|---:|---:|---:|---|\n');
rs = scaleRows(ismember(scaleRows.Tp, [22 26 30]), :);
for i = 1:height(rs)
    fprintf(fid, '| %g | %s | %d | %.4f | %.4f | %s |\n', ...
        rs.Tp(i), rs.sector(i), rs.n_shared_tw(i), rs.affine_r2(i), rs.scale_only_r2(i), rs.SHAPE_COMPATIBLE_UP_TO_SCALE(i));
end
fprintf(fid, '\n## 26 K focused\n\n');
for i = 1:height(focus26)
    fprintf(fid, '- **%s**: %s\n', focus26.metric(i), fitValToStr(focus26.value_26K{i}));
end
fprintf(fid, '\n## Fit source (existing tables)\n\n');
for i = 1:height(fitResp)
    fprintf(fid, '- **%s**: %s\n', fitResp.field{i}, fitValToStr(fitResp.value{i}));
end
fprintf(fid, '\n## Interpretation boundary\n\n');
fprintf(fid, 'Shape / scale / domain descriptors only. No mechanism claims. ');
fprintf(fid, 'Legacy numbers are not treated as canonical evidence.\n');
fclose(fid);
end

function s = fitValToStr(v)
if isnumeric(v) && isscalar(v)
    s = sprintf('%.12g', v);
elseif isstring(v) && isscalar(v)
    s = char(v);
elseif ischar(v)
    s = v;
else
    s = char(string(v));
end
end
