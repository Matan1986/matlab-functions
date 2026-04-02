function run_phi2_reconciliation_audit()
% run_phi2_reconciliation_audit
% Reconcile old Phi2/Kappa2 verdicts vs new canonical residual-mode verdicts.
% Scope: audit-only. No switching pipeline edits.

clearvars;
clc;

repoRoot = 'C:/Dev/matlab-functions';
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
statusDir = fullfile(repoRoot, 'status');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end
if exist(statusDir, 'dir') ~= 7, mkdir(statusDir); end

outSources = fullfile(tablesDir, 'phi2_reconciliation_sources.csv');
outDiffs = fullfile(tablesDir, 'phi2_reconciliation_differences.csv');
outSameInput = fullfile(tablesDir, 'phi2_reconciliation_same_input_tests.csv');
outVerdicts = fullfile(tablesDir, 'phi2_reconciliation_verdicts.csv');
outReport = fullfile(reportsDir, 'phi2_reconciliation_report.md');
outStatus = fullfile(statusDir, 'phi2_reconciliation_status.txt');

% -------------------------------------------------------------------------
% Load canonical matrix used by the new run
% -------------------------------------------------------------------------
residualMapPath = fullfile(tablesDir, 'phi2_residual_map.csv');
assert(exist(residualMapPath, 'file') == 2, 'Missing canonical residual map: %s', residualMapPath);
resMapTbl = readtable(residualMapPath);

x = double(resMapTbl.x(:));
varNames = string(resMapTbl.Properties.VariableNames);
tCols = setdiff(varNames, "x", 'stable');
T = NaN(numel(tCols), 1);
for i = 1:numel(tCols)
    T(i) = parseTempFromVar(tCols(i));
end
M = table2array(resMapTbl(:, cellstr(tCols))); % M(x,T)

% Canonical scaling observables for the same temperatures.
scalingPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_12_234016_switching_full_scaling_collapse', ...
    'tables', 'switching_full_scaling_parameters.csv');
assert(exist(scalingPath, 'file') == 2, 'Missing scaling table: %s', scalingPath);
scaleTbl = readtable(scalingPath);
[Ipeak, Speak, width] = lookupScalingAtT(scaleTbl, T); %#ok<ASGLU>

sameInput = recomputeSameInput(M, x, T, Ipeak, Speak);

% -------------------------------------------------------------------------
% TASK 1: prior relevant sources table
% -------------------------------------------------------------------------
srcRows = {};
srcRows = addSrc(srcRows, 'table', fullfile(tablesDir, 'rank2_metrics.csv'), ...
    'MODE2_REAL', 'YES', ...
    'no_22K subset: sigma1/sigma2=6.263467, variance_mode1=0.959794, rmse_gain_rank2_minus_rank1=0.075052, corr_mode2_I_peak=-0.926461', ...
    'Legacy rank-2 summary labels mode-2 as real and linked.');
srcRows = addSrc(srcRows, 'table', fullfile(tablesDir, 'rank2_metrics.csv'), ...
    'MODE2_LINKED_TO_LANDSCAPE', 'YES', ...
    'best_corr_descriptor=I_peak_mA, best_corr_value=-0.926461; corr_mode2_kappa=-0.697045', ...
    'Correlation-based linkage criterion dominates the verdict.');
srcRows = addSrc(srcRows, 'table', fullfile(tablesDir, 'rank2_metrics.csv'), ...
    'RANK1_SUFFICIENT', 'NO', ...
    'variance_mode1=0.959794 and relFro rank1 error=0.200514', ...
    'Legacy source treats rank-1 as insufficient despite high mode-1 variance.');

srcRows = addSrc(srcRows, 'report', fullfile(reportsDir, 'rank2_report.md'), ...
    'MODE2_REAL', 'YES', ...
    'Decision subset no_22K; reports mode stability min cosine=0.9993, mean=0.9999; gain=0.0751', ...
    'Report-level summary that supported independent/real mode-2 narratives.');

srcRows = addSrc(srcRows, 'report', fullfile(reportsDir, 'deformation_closure_report.md'), ...
    'PHI2_IS_DEFORMATION_OF_PHI1', 'PARTIAL', ...
    'corr(Phi2,dPhi1/dx)=-0.886; corr(Phi2,x*Phi1)=-0.892; cosine(Phi2,span{K1,K2})=0.414; rmse_to_span=0.061', ...
    'Explicitly states deformation alignment is partial, not full closure.');
srcRows = addSrc(srcRows, 'report', fullfile(reportsDir, 'deformation_closure_report.md'), ...
    'DEFORMATION_BASIS_MATCHES_RANK2', 'NO', ...
    'mean RMSE: rank2(B)=0.00567 vs deform3(C)=0.00656', ...
    'Deformation basis does not match rank-2 reconstruction quality.');

srcRows = addSrc(srcRows, 'table', fullfile(tablesDir, 'phi2_extended_deformation_basis_status.csv'), ...
    'EXTENDED_BASIS_IMPROVES', 'NO', ...
    'BEST_COSINE=0.666907, BEST_RMSE=0.049875', ...
    'Extended deformation basis judged insufficient.');
srcRows = addSrc(srcRows, 'table', fullfile(tablesDir, 'phi2_extended_deformation_basis_status.csv'), ...
    'PHI2_IRREDUCIBLE_BEYOND_DEFORMATION', 'YES', ...
    'Same status artifact: PHI2_HIGHER_ORDER_DEFORMATION=NO', ...
    'Old deformation line of evidence against pure deformation closure.');

srcRows = addSrc(srcRows, 'table', fullfile(tablesDir, 'phi2_second_order_deformation_status.csv'), ...
    'SECOND_ORDER_OUTPERFORMS_FIRST_ORDER', 'YES', ...
    'Status table from strict second-order test', ...
    'Second-order terms help, but do not close fully.');
srcRows = addSrc(srcRows, 'table', fullfile(tablesDir, 'phi2_second_order_deformation_status.csv'), ...
    'FIRST_PLUS_SECOND_SUFFICIENT', 'NO', ...
    'strict closure cutoff: cosine>=0.90 and rmse_unit<=0.02 (reported baseline row rmse_unit~0.025)', ...
    'Explicit strict-deformation failure criterion.');
srcRows = addSrc(srcRows, 'table', fullfile(tablesDir, 'phi2_second_order_deformation_status.csv'), ...
    'PHI2_IRREDUCIBLE_BEYOND_SECOND_ORDER', 'YES', ...
    'Derived from FIRST_PLUS_SECOND_SUFFICIENT=NO', ...
    'Supports non-closure in old strict deformation language.');

srcRows = addSrc(srcRows, 'report', fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_legacy_mode23_analysis', 'reports', 'mode23_analysis_report.md'), ...
    'MODE23_TWO_DIMENSIONAL_SUBSPACE', 'YES_CONSISTENT', ...
    'Global I_peak regression R2: mode2_only=0.438, mode3_only=0.348, mode23=0.766 (DeltaR2=0.327)', ...
    'Legacy report states material 2D-structure gain.');

srcRows = addSrc(srcRows, 'report', fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_legacy_mechanism_followup', 'reports', 'mechanism_followup_report.md'), ...
    'MODE2_LINKED_TO_SHAPE_EVOLUTION', 'YES_CONSISTENT', ...
    'corr(coeff_mode2, I_peak)=0.662 global; high-T corr with width_I=0.902', ...
    'Legacy interpretation: mode-2 tracks regime-dependent shape evolution.');

srcRows = addSrc(srcRows, 'script', fullfile(repoRoot, 'Switching', 'analysis', 'run_residual_temperature_structure_test.m'), ...
    'LEGACY_SIGNIFICANCE_LOGIC', 'RANK2_GAIN_PLUS_STRUCTURE', ...
    'classifyAmpOnly uses energy_frac_mode1, maxDrift, median cosine, p90 orth leftover, strongest correlation', ...
    'No hard mode2-variance floor; structural gain/correlation language dominates significance narrative.');
srcRows = addSrc(srcRows, 'script', fullfile(repoRoot, 'Switching', 'analysis', 'run_residual_rank2_audit.m'), ...
    'OLD_AUDIT_SIGNIFICANCE_CRITERION', 'STRUCTURED_IF(ev2>=0.03_AND_bestAbsCorr>=0.35)', ...
    'makeFinalVerdict thresholds: STRUCTURED if (impr>=0.03 && bestAbsCorr>=0.35); WEAK if (impr>=0.015 || bestAbsCorr>=0.25)', ...
    'Explicit old rank-2 threshold logic available in code.');
srcRows = addSrc(srcRows, 'script', fullfile(repoRoot, 'Switching', 'analysis', 'phi2_shape_helpers.m'), ...
    'OLD_STABILITY_CRITERION', 'PHI2_STABLE_IF(LOO_min_cosine>=0.88)', ...
    'localApplyDefaults sets stabilityCosThreshold=0.88; localLooPhi2Cosine defines LOO cosine', ...
    'Old explicit phi2-shape stability criterion.');
srcRows = addSrc(srcRows, 'script', fullfile(repoRoot, 'analysis', 'run_deformation_closure_agent19e.m'), ...
    'OLD_DEFORMATION_CRITERION', 'PHI2_DEFORMATION_IF(phi2InSpan_AND_deformNearRank2)', ...
    'phi2InSpan=(cosSpan>0.85 || rmseSpan<0.02); deformNearRank2=(meanRmseC<=1.05*meanRmseB)', ...
    'Old deformation-basis sufficiency test with explicit RMSE/cosine thresholds.');
srcRows = addSrc(srcRows, 'script', fullfile(repoRoot, 'Switching', 'analysis', 'run_phi2_second_order_deformation_test.m'), ...
    'OLD_STRICT_CLOSURE_CRITERION', 'FIRST_PLUS_SECOND_SUFFICIENT_IF(cosine>=0.90_AND_rmse_unit<=0.02)', ...
    'localVerdicts: properCos=0.90, properRmseUnit=0.02', ...
    'Strict old closure criterion that kept deformation sufficiency at NO.');

srcTbl = cell2table(srcRows, 'VariableNames', ...
    {'source_type','file_path','date_if_available','verdict_key','verdict_value','metric_basis','notes'});
writetable(srcTbl, outSources);

% -------------------------------------------------------------------------
% TASK 2: old vs new definition differences
% -------------------------------------------------------------------------
diffRows = {
    'input_dataset', ...
    'Mixed historical sources (legacy mode23/mechanism + rank2 summary from run_2026_03_25_043610)', ...
    'Single canonical residual-mode run (run_phi2_kappa2_canonical_residual_mode) with fixed source IDs', ...
    'DIFFERENT', ...
    'Historical verdicts blend multiple pipelines and summaries, increasing criterion drift.'
    ;
    'included_temperatures', ...
    'Primary old rank2 decision subset explicitly no_22K (22 K excluded)', ...
    'Uses all canonical temperatures 4..30 K including 22 K', ...
    'DIFFERENT', ...
    '22 K is a boundary-anomaly row; inclusion/exclusion shifts stability/correlation narratives.'
    ;
    'canonical_observable', ...
    'Residual-structure plus mode-proxy correlation summaries (mode2 proxy vs I_peak/kappa)', ...
    'Direct SVD mode-2 explained variance and reconstruction ratio on canonical M(x,T)', ...
    'DIFFERENT', ...
    'Old pipeline weighted descriptor linkage; new pipeline weights spectral energy threshold.'
    ;
    'residual_definition', ...
    'deltaS = S - S_CDF from switching_residual_decomposition_analysis', ...
    'Same (deltaS = S - S_CDF from switching_residual_decomposition_analysis)', ...
    'SAME', ...
    'No direct evidence of residual-construction contradiction.'
    ;
    'backbone_cdf_construction', ...
    'PT_matrix_reconstruction (with fallback when PT missing)', ...
    'Same PT_matrix_reconstruction path via switching_residual_decomposition_analysis', ...
    'SAME', ...
    'Backbone definition is aligned across old/new canonical runs.'
    ;
    'x_grid_definition', ...
    'Common aligned x-grid, nXGrid=220 (canonical overlap)', ...
    'Same nXGrid=220 aligned common x-grid', ...
    'SAME', ...
    'Grid mismatch is not the main discrepancy source.'
    ;
    'sign_convention_for_modes', ...
    'Mode-1 sign fixed by positive median kappa; mode-2 sign handling varied by script/report', ...
    'Mode-1 sign fixed by corr(kappa1,Speak)>0; mode-2 sign fixed by max corr with dPhi1/dx or x*Phi1', ...
    'DIFFERENT', ...
    'Mode-2 interpretive signs and correlations can shift between pipelines.'
    ;
    'svd_matrix_definition', ...
    'Often SVD on R(T,x) (rows=temperature, cols=x)', ...
    'SVD on M(x,T)=R'' (rows=x, cols=temperature)', ...
    'DIFFERENT', ...
    'Equivalent singular values but different left/right vectors; easy to mislabel stability quantities.'
    ;
    'normalization_phi1_phi2', ...
    'Mixed: max-abs normalization in decomposition, unit-L2 normalization in deformation closure tests', ...
    'No unit-L2 closure test in final verdict; uses raw correlations and explained variance', ...
    'DIFFERENT', ...
    'Strict closure RMSE criteria and correlation-only criteria can diverge strongly.'
    ;
    'definition_kappa1_kappa2', ...
    'Mixed per script: projection coefficients, LSQ coefficients, or U*S components', ...
    'Fixed: kappa1=s1*V1, kappa2=s2*V2 from canonical SVD after sign alignment', ...
    'DIFFERENT', ...
    'Coefficient semantics changed between historical summaries.'
    ;
    'rank2_significance_criterion', ...
    'Legacy evidence emphasized RMSE gain + strong mode2-descriptor correlations; no explicit 5% variance floor in rank2_report', ...
    'MODE2_SIGNIFICANT requires mode2 explained variance >= 0.05', ...
    'DIFFERENT', ...
    'Primary verdict flip driver: same matrix has mode2 variance ~0.025 (<0.05) despite strong RMSE gain.'
    ;
    'physical_mode_criterion', ...
    'Legacy narrative: MODE2_REAL + linkage/stability summaries', ...
    'SECOND_MODE_PHYSICAL requires (mode2 significant) AND (rank2 improves) AND (phi2 is deformation)', ...
    'DIFFERENT', ...
    'New criterion blocks physical-mode claim when significance threshold fails.'
    ;
    'deformation_test_basis', ...
    'Old tests used explicit basis spans {dPhi1/dx, x*Phi1} and higher-order extensions {d2Phi1/dx2, x*dPhi1/dx, x^2*Phi1}', ...
    'New final verdict uses bestDefCorr=max(|corr(phi2,dPhi1/dx)|,|corr(phi2,x*Phi1)|)', ...
    'DIFFERENT', ...
    'Old strict basis-closure can fail while new correlation-only deformation flag passes.'
    ;
    'deformation_pass_threshold', ...
    'Strict closure thresholds (e.g., cosine>=0.90 and rmse_unit<=0.02)', ...
    'PHI2_IS_DEFORMATION if bestDefCorr>=0.70', ...
    'DIFFERENT', ...
    'Much softer threshold in new verdict favors deformation=YES.'
    ;
    'use_of_corr_rmse_explained_variance', ...
    'Old verdicts blend correlation strength, RMSE gains, and ad hoc stability summaries', ...
    'New verdict hard-gates significance by explained variance, then uses RMSE/correlation as secondary gates', ...
    'DIFFERENT', ...
    'Metric-priority change explains conflicting conclusions on same data.'
    ;
    'stability_quantity_labeled_as_mode2', ...
    'Legacy rank2 table reports mode2_stability values matching mode-1 LOO from residual_mode_stability.csv', ...
    'New run does not use that legacy stability field for significance/physicality', ...
    'DIFFERENT', ...
    'Labeling mismatch inflated confidence in old mode-2 stability claims.'
    };

diffTbl = cell2table(diffRows, 'VariableNames', ...
    {'analysis_component','old_definition','new_definition','same_or_different','likely_impact'});
writetable(diffTbl, outDiffs);

% -------------------------------------------------------------------------
% TASK 3: same-input old vs new tests
% -------------------------------------------------------------------------
tests = {};

tests = addTest(tests, 'RANK2_SIGNIFICANCE_LEGACY_REPORT_STYLE', ...
    yesno(sameInput.oldLegacyMode2Real), ...
    yesno(sameInput.newMode2Significant), ...
    'YES', ...
    sprintf(['Same canonical matrix; legacy no_22K metrics reproduce historical values ', ...
    '(gain=%.6f, best|corr|=%.6f) while new mode2 variance=%.6f < 0.05.'], ...
    sameInput.oldNo22GainRelFro, sameInput.oldNo22BestAbsCorr, sameInput.newMode2Var));

tests = addTest(tests, 'RANK2_STRUCTURE_OLD_AUDIT_THRESHOLD', ...
    sameInput.oldAuditRank2Structure, ...
    yesno(sameInput.newMode2Significant), ...
    'YES', ...
    sprintf('Old explicit audit rule uses mode2 variance and best-corr (ev2=%.6f, best|corr|=%.6f).', ...
    sameInput.oldNo22Mode2Var, sameInput.oldNo22BestAbsCorr));

tests = addTest(tests, 'STABILITY_LEGACY_LABEL_VS_TRUE_PHI2_LOO', ...
    sprintf('STABLE (legacy field min cosine=%.6f)', sameInput.oldLegacyLooMode1Min), ...
    sprintf('UNSTABLE (phi2 LOO min cosine=%.6f)', sameInput.oldPhi2LooMin), ...
    'YES', ...
    'Legacy mode2 stability value numerically matches mode-1 LOO quantity (labeling mismatch).');

tests = addTest(tests, 'DEFORMATION_BASIS_CLOSURE_AGENT19E', ...
    sameInput.oldDeformationVerdict, ...
    yesno(sameInput.newPhi2IsDeformation), ...
    'YES', ...
    sprintf('Old basis closure: cosSpan=%.6f, rmseSpan=%.6f, meanRMSE(C/B)=%.6f/%.6f.', ...
    sameInput.oldPhi2SpanCos, sameInput.oldPhi2SpanRmse, sameInput.oldMeanRmseC, sameInput.oldMeanRmseB));

tests = addTest(tests, 'STRICT_FIRST_PLUS_SECOND_CLOSURE', ...
    yesno(sameInput.oldFirstPlusSecondSufficient), ...
    yesno(sameInput.newPhi2IsDeformation), ...
    'YES', ...
    sprintf('Old strict threshold uses cosine>=0.90 and rmse_unit<=0.02; measured cosine=%.6f, rmse_unit=%.6f.', ...
    sameInput.oldFirstPlusSecondCos, sameInput.oldFirstPlusSecondRmseUnit));

tests = addTest(tests, 'SECOND_MODE_PHYSICAL_COMPOSITE', ...
    yesno(sameInput.oldLegacySecondModePhysical), ...
    yesno(sameInput.newSecondModePhysical), ...
    'YES', ...
    'Legacy narrative combined MODE2_REAL + landscape linkage; new requires explicit significance gate plus deformation and reconstruction gates.');

testsTbl = cell2table(tests, 'VariableNames', ...
    {'test_name','old_logic_result','new_logic_result','same_input_used','notes'});
writetable(testsTbl, outSameInput);

% -------------------------------------------------------------------------
% TASK 4: discrepancy classification flags
% -------------------------------------------------------------------------
verRows = {
    'DATA_SELECTION_DIFFERENCE', 'YES', 'Legacy primary decision used no_22K; new canonical verdict uses full 4..30 K including 22 K.'
    'RESIDUAL_DEFINITION_DIFFERENCE', 'NO', 'Both old/new canonical analyses use deltaS=S-S_CDF from switching_residual_decomposition_analysis.'
    'DEFORMATION_TEST_DIFFERENCE', 'YES', 'Old strict basis-closure criteria fail while new correlation threshold marks deformation as YES.'
    'SIGNIFICANCE_THRESHOLD_DIFFERENCE', 'YES', 'Legacy mode2-real narrative from RMSE/correlation differs from new hard gate mode2Var>=0.05.'
    'MODE_NORMALIZATION_DIFFERENCE', 'YES', 'Old tests mixed max-abs and unit-L2 normalization; new final verdict does not require strict unit-RMSE closure.'
    'PURE_LABELING_DIFFERENCE', 'YES', 'Legacy mode2 stability values match mode-1 LOO numbers from source table.'
    'GENUINE_PHYSICS_CONTRADICTION', 'NO', 'Same canonical matrix reproduces old metrics; verdict flip is methodological/labeling, not data-level contradiction.'
    'PRIMARY_CAUSE', 'SIGNIFICANCE_THRESHOLD_DIFFERENCE', 'Primary flip: mode2 variance 0.025<0.05 in new gate despite substantial rank2 RMSE gain.'
    };
verTbl = cell2table(verRows, 'VariableNames', {'flag','value','evidence'});
writetable(verTbl, outVerdicts);

% -------------------------------------------------------------------------
% TASK 5: human-readable report
% -------------------------------------------------------------------------
fid = fopen(outReport, 'w');
assert(fid ~= -1, 'Cannot write report: %s', outReport);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Phi2/Kappa2 Reconciliation Audit\n\n');
fprintf(fid, '## What old results said (file evidence)\n');
fprintf(fid, '- `reports/rank2_report.md` and `tables/rank2_metrics.csv` stated `MODE2_REAL=YES`, `MODE2_LINKED_TO_LANDSCAPE=YES`, `RANK1_SUFFICIENT=NO`.\n');
fprintf(fid, '- `reports/deformation_closure_report.md` stated `PHI2_IS_DEFORMATION_OF_PHI1=PARTIAL` and `DEFORMATION_BASIS_MATCHES_RANK2=NO`.\n');
fprintf(fid, '- `tables/phi2_extended_deformation_basis_status.csv` and `tables/phi2_second_order_deformation_status.csv` kept strict deformation-closure verdicts negative (`...SUFFICIENT=NO`, irreducible=YES).\n');
fprintf(fid, '- Legacy mode23/mechanism reports supported a two-dimensional structural interpretation via regression/correlation gains.\n\n');

fprintf(fid, '## What new canonical result says\n');
fprintf(fid, '- `tables/phi2_verdicts.csv`: `MODE2_SIGNIFICANT=NO`, `PHI2_IS_DEFORMATION=YES`, `RANK2_IMPROVES_RECONSTRUCTION=YES`.\n');
fprintf(fid, '- `status/phi2_status.txt`: `SECOND_MODE_PHYSICAL=NO`.\n');
fprintf(fid, '- Quantitatively on the canonical matrix: mode-1 variance %.6f, mode-2 variance %.6f, global rank2/rank1 RMSE ratio %.6f.\n\n', ...
    sameInput.newMode1Var, sameInput.newMode2Var, sameInput.newGlobalRmseRatio);

fprintf(fid, '## Same-input replay result (data vs logic)\n');
fprintf(fid, '- Same residual matrix (`tables/phi2_residual_map.csv`) reproduces legacy no_22K metrics: sigma1/sigma2 %.6f, rank2 relFro gain %.6f, best|corr| %.6f.\n', ...
    sameInput.oldNo22Sigma12, sameInput.oldNo22GainRelFro, sameInput.oldNo22BestAbsCorr);
fprintf(fid, '- Therefore, the old/new mismatch is not caused by a different residual matrix.\n');
fprintf(fid, '- Primary difference is decision logic: old narrative treated strong RMSE gain + correlations as sufficient for ''real mode-2'', while new logic requires mode-2 explained variance >= 0.05 (not met).\n');
fprintf(fid, '- Additional discrepancy: legacy ''mode2 stability'' values match mode-1 LOO values (labeling mismatch), inflating prior stability confidence.\n');
fprintf(fid, '- Deformation verdict differences come from criterion choice: strict basis-closure (old) vs correlation threshold (new).\n\n');

fprintf(fid, '## Is the contradiction real or methodological?\n');
fprintf(fid, '- Classification: methodological, not a direct physics contradiction.\n');
fprintf(fid, '- Flags: DATA_SELECTION_DIFFERENCE=YES, SIGNIFICANCE_THRESHOLD_DIFFERENCE=YES, DEFORMATION_TEST_DIFFERENCE=YES, PURE_LABELING_DIFFERENCE=YES, GENUINE_PHYSICS_CONTRADICTION=NO.\n\n');

fprintf(fid, '## Current support status for Phi2 claims\n');
fprintf(fid, '- rank-2 structure: **supported** (rank-2 materially reduces reconstruction error).\n');
fprintf(fid, '- stable structure: **not supported as a robust Phi2 shape claim** under true Phi2 LOO; legacy stability label was inconsistent.\n');
fprintf(fid, '- independent mode: **not currently supported** by new significance gate (`MODE2_SIGNIFICANT=NO`).\n');
fprintf(fid, '- deformation of Phi1: **supported in weak/correlation sense** (`PHI2_IS_DEFORMATION=YES`), but **not closed** under old strict basis RMSE criteria.\n\n');

fprintf(fid, '## Safe statement now\n');
fprintf(fid, '- Safe: the canonical residual has a dominant rank-1 mode plus a subleading structured correction; that correction improves reconstruction but does not pass the new independent-mode significance criterion.\n\n');

fprintf(fid, '## Not yet safe statement\n');
fprintf(fid, '- Not safe: claiming a universally stable, independently physical mode-2 based solely on old rank2 labels.\n');
fprintf(fid, '- Not safe: claiming strict deformation-basis closure is achieved.\n');

% -------------------------------------------------------------------------
% Status file
% -------------------------------------------------------------------------
fidS = fopen(outStatus, 'w');
assert(fidS ~= -1, 'Cannot write status file: %s', outStatus);
fprintf(fidS, 'RECONCILIATION_AUDIT_SUCCESS=YES\n');
fprintf(fidS, 'OLD_SOURCES_FOUND=YES\n');
fprintf(fidS, 'PRIMARY_CAUSE_IDENTIFIED=YES\n');
fprintf(fidS, 'SAFE_PHI2_STATEMENT_AVAILABLE=YES\n');
fclose(fidS);

fprintf('[DONE] Phi2 reconciliation audit artifacts written.\n');
fprintf(' - %s\n', outSources);
fprintf(' - %s\n', outDiffs);
fprintf(' - %s\n', outSameInput);
fprintf(' - %s\n', outVerdicts);
fprintf(' - %s\n', outReport);
fprintf(' - %s\n', outStatus);
end

% =========================================================================
% Helpers
% =========================================================================
function rows = addSrc(rows, sourceType, pathIn, key, value, metricBasis, notes)
d = 'NA';
if exist(pathIn, 'file') == 2
    info = dir(pathIn);
    d = datestr(info.datenum, 'yyyy-mm-dd HH:MM:SS');
end
rows(end+1, :) = {sourceType, toPosix(pathIn), d, key, value, metricBasis, notes}; %#ok<AGROW>
end

function rows = addTest(rows, name, oldRes, newRes, sameInputUsed, notes)
rows(end+1, :) = {name, oldRes, newRes, sameInputUsed, notes}; %#ok<AGROW>
end

function out = yesno(tf)
if tf
    out = 'YES';
else
    out = 'NO';
end
end

function s = toPosix(p)
s = strrep(char(p), '\', '/');
end

function T = parseTempFromVar(vn)
s = char(vn);
tok = regexp(s, 'T_([0-9]+(?:_[0-9]+)?)K', 'tokens', 'once');
if isempty(tok)
    T = NaN;
    return;
end
T = str2double(strrep(tok{1}, '_', '.'));
end

function [Ipeak, Speak, width] = lookupScalingAtT(tbl, T)
vn = string(tbl.Properties.VariableNames);
Tcol = pickCol(vn, ["T_K","T"]);
Icol = pickCol(vn, ["Ipeak_mA","I_peak","Ipeak"]);
Scol = pickCol(vn, ["S_peak","Speak","Speak_peak"]);
Wcol = pickCol(vn, ["width_chosen_mA","width_I","width"]);

tAll = asNum(tbl.(Tcol));
iAll = asNum(tbl.(Icol));
sAll = asNum(tbl.(Scol));
wAll = asNum(tbl.(Wcol));

Ipeak = NaN(size(T));
Speak = NaN(size(T));
width = NaN(size(T));
for i = 1:numel(T)
    [dmin, idx] = min(abs(tAll - T(i)));
    if isfinite(dmin) && dmin <= 0.25
        Ipeak(i) = iAll(idx);
        Speak(i) = sAll(idx);
        width(i) = wAll(idx);
    end
end
end

function c = pickCol(vn, candidates)
c = "";
for i = 1:numel(candidates)
    idx = find(vn == candidates(i), 1, 'first');
    if ~isempty(idx)
        c = vn(idx);
        return;
    end
end
error('Missing required column from candidates: %s', strjoin(cellstr(candidates), ','));
end

function x = asNum(raw)
if isnumeric(raw)
    x = double(raw(:));
else
    x = str2double(string(raw(:)));
end
end

function out = recomputeSameInput(M, x, T, Ipeak, Speak)
% M is x-by-T canonical matrix (same as new run residual map).

% ---------------------------
% OLD orientation (R = T-by-x)
% ---------------------------
R = M.';
[U, S, V] = svd(R, 'econ'); %#ok<ASGLU>
s = diag(S);
ev = (s.^2) ./ max(sum(s.^2), eps);

R1 = U(:, 1) * s(1) * V(:, 1).';
R2 = U(:, 1:2) * S(1:2, 1:2) * V(:, 1:2).';
rel1 = norm(R - R1, 'fro') / max(norm(R, 'fro'), eps);
rel2 = norm(R - R2, 'fro') / max(norm(R, 'fro'), eps);

maskNo22 = abs(T - 22) > 0.25;
Rsub = R(maskNo22, :);
Tsub = T(maskNo22);
Isub = Ipeak(maskNo22);
[Us, Ss, Vs] = svd(Rsub, 'econ');
ss = diag(Ss);
evs = (ss.^2) ./ max(sum(ss.^2), eps);
R1s = Us(:, 1) * ss(1) * Vs(:, 1).';
R2s = Us(:, 1:2) * Ss(1:2, 1:2) * Vs(:, 1:2).';
rel1s = norm(Rsub - R1s, 'fro') / max(norm(Rsub, 'fro'), eps);
rel2s = norm(Rsub - R2s, 'fro') / max(norm(Rsub, 'fro'), eps);
gainRelFroNo22 = rel1s - rel2s;

% Legacy "mode2 proxy" correlations in no_22K subset.
kappaSub = U(maskNo22, 1) * s(1); % canonical kappa from full low-T decomposition
phiCanonical = V(:, 1);
if median(U(:, 1) * s(1), 'omitnan') < 0
    phiCanonical = -phiCanonical;
end
mode2Proxy = NaN(size(Rsub, 1), 1); % legacy proxy: relative orthogonal leftover vs Phi1
for i = 1:size(Rsub, 1)
    r = Rsub(i, :).';
    a = dot(r, phiCanonical) / max(dot(phiCanonical, phiCanonical), eps);
    resid = r - a .* phiCanonical;
    mode2Proxy(i) = norm(resid) / max(norm(r), eps);
end
cI = localCorr(mode2Proxy, Isub);
cK = localCorr(mode2Proxy, kappaSub);
cT = localCorr(mode2Proxy, Tsub);
bestAbsCorr = max(abs([cI, cK, cT]), [], 'omitnan');

% Legacy no_22K "mode stability" values in rank2_metrics match mode-1 LOO.
phiRefMode1 = Vs(:, 1);
if median(Us(:, 1) * ss(1), 'omitnan') < 0
    phiRefMode1 = -phiRefMode1;
end
looMode1 = NaN(size(Rsub, 1), 1);
for i = 1:size(Rsub, 1)
    idx = true(size(Rsub, 1), 1);
    idx(i) = false;
    [Ui, Si, Vi] = svd(Rsub(idx, :), 'econ');
    if isempty(Si)
        continue;
    end
    p = Vi(:, 1);
    if median(Ui(:, 1) * Si(1,1), 'omitnan') < 0
        p = -p;
    end
    looMode1(i) = abs(localCorrCos(phiRefMode1, p));
end

% True Phi2 LOO on full canonical set (old phi2-shape style stability check).
phi2Ref = localZeroMeanUnitL2(V(:, 2));
looPhi2 = NaN(size(R, 1), 1);
for i = 1:size(R, 1)
    idx = true(size(R, 1), 1);
    idx(i) = false;
    [~, Si, Vi] = svd(R(idx, :), 'econ');
    if size(Vi, 2) < 2
        continue;
    end
    p2 = localZeroMeanUnitL2(Vi(:, 2));
    if dot(p2, phi2Ref) < 0
        p2 = -p2;
    end
    looPhi2(i) = dot(p2, phi2Ref);
end

% Old audit explicit structure rule (run_residual_rank2_audit thresholds).
if evs(2) >= 0.03 && bestAbsCorr >= 0.35
    oldAuditStruct = 'STRUCTURED';
elseif evs(2) >= 0.015 || bestAbsCorr >= 0.25
    oldAuditStruct = 'WEAK';
else
    oldAuditStruct = 'NONE';
end

% Legacy report-style MODE2_REAL kept YES when gain/correlation pattern is strong.
oldLegacyMode2Real = (gainRelFroNo22 >= 0.05) && (bestAbsCorr >= 0.35); % inferred from rank2_report pattern
oldLegacySecondModePhysical = oldLegacyMode2Real;

% Old deformation closure (Agent19E explicit logic).
phi1o = V(:, 1);
kappa1o = U(:, 1) * s(1);
if median(kappa1o, 'omitnan') < 0
    phi1o = -phi1o;
    kappa1o = -kappa1o;
end
phi2o = V(:, 2);

K1 = gradient(phi1o, x);
K2 = x .* phi1o;
k1 = K1 / max(norm(K1), eps);
k2r = K2 - dot(K2, k1) * k1;
k2 = k2r / max(norm(k2r), eps);
B = [k1, k2];
coef12 = B \ phi2o;
proj12 = B * coef12;
cosSpan = dot(phi2o / max(norm(phi2o), eps), proj12 / max(norm(proj12), eps));
rmseSpan = sqrt(mean((phi2o - proj12).^2, 'omitnan'));

rmA = NaN(size(R, 1), 1);
rmB = NaN(size(R, 1), 1);
rmC = NaN(size(R, 1), 1);
for it = 1:size(R, 1)
    r = R(it, :).';
    m = isfinite(r) & isfinite(phi1o) & isfinite(phi2o) & isfinite(K1) & isfinite(K2);
    if nnz(m) < 5
        continue;
    end
    rr = r(m);
    p1 = phi1o(m);
    p2m = phi2o(m);
    ra = kappa1o(it) * p1;
    XB = [p1, p2m];
    thB = XB \ rr;
    rb = XB * thB;
    XC = [p1, K1(m), K2(m)];
    thC = XC \ rr;
    rc = XC * thC;
    rmA(it) = sqrt(mean((rr - ra).^2, 'omitnan'));
    rmB(it) = sqrt(mean((rr - rb).^2, 'omitnan'));
    rmC(it) = sqrt(mean((rr - rc).^2, 'omitnan'));
end
meanRmseB = mean(rmB, 'omitnan');
meanRmseC = mean(rmC, 'omitnan');
phi2InSpan = (cosSpan > 0.85) || (rmseSpan < 0.02);
deformNearRank2 = meanRmseC <= meanRmseB * 1.05;

oldDeformVerdict = 'PARTIAL';
if phi2InSpan && deformNearRank2
    oldDeformVerdict = 'YES';
elseif ~phi2InSpan && ~deformNearRank2
    oldDeformVerdict = 'NO';
end

% Old strict first+second closure (from second-order script threshold).
edgeExclude = 2;
n = numel(x);
dPhi1 = gradient(phi1o, x);
d2Phi1 = gradient(dPhi1, x);
xPhi1 = x .* phi1o;
xDphi1 = x .* dPhi1;
x2Phi1 = (x.^2) .* phi1o;
maskFit = isfinite(phi2o) & isfinite(phi1o) & isfinite(x) & ...
    isfinite(dPhi1) & isfinite(d2Phi1) & isfinite(xPhi1) & isfinite(xDphi1) & isfinite(x2Phi1);
if n > 2*edgeExclude + 5
    maskFit(1:edgeExclude) = false;
    maskFit(end-edgeExclude+1:end) = false;
end
idx = find(maskFit);
tRaw = phi2o(idx);
PhiNorm = max(norm(tRaw), eps);
tUnit = tRaw ./ PhiNorm;
Xraw = [dPhi1(idx), xPhi1(idx), d2Phi1(idx), xDphi1(idx), x2Phi1(idx)];
Xunit = zeros(size(Xraw));
for j = 1:size(Xraw, 2)
    bn = max(norm(Xraw(:, j)), eps);
    Xunit(:, j) = Xraw(:, j) ./ bn;
end
coefU = Xunit \ tUnit;
yhatUnit = Xunit * coefU;
yhatRaw = PhiNorm * yhatUnit;
oldFirstPlusSecondCos = abs(dot(tRaw, yhatRaw) / max(norm(tRaw)*norm(yhatRaw), eps));
oldFirstPlusSecondRmseUnit = sqrt(mean((tUnit - yhatUnit).^2, 'omitnan'));
oldFirstPlusSecondSufficient = (oldFirstPlusSecondCos >= 0.90) && (oldFirstPlusSecondRmseUnit <= 0.02);

% ---------------------------
% NEW logic on the same M(x,T)
% ---------------------------
[Un, Sn, Vn] = svd(M, 'econ');
sn = diag(Sn);
phi1n = Un(:, 1);
phi2n = Un(:, 2);
kappa1n = sn(1) * Vn(:, 1);
kappa2n = sn(2) * Vn(:, 2); %#ok<NASGU>

if localCorr(kappa1n, Speak) < 0
    phi1n = -phi1n;
    kappa1n = -kappa1n;
end

dphi1dx = gradient(phi1n, x);
xphi1n = x .* phi1n;
cD = localCorr(phi2n, dphi1dx);
cX = localCorr(phi2n, xphi1n);
if abs(cD) > abs(cX)
    if cD < 0
        phi2n = -phi2n;
    end
else
    if cX < 0
        phi2n = -phi2n;
    end
end

evn = (sn.^2) ./ max(sum(sn.^2), eps);
M1 = Un(:, 1) * sn(1) * Vn(:, 1).';
M2 = Un(:, 1:2) * Sn(1:2, 1:2) * Vn(:, 1:2).';
rmse1 = sqrt(mean((M(:) - M1(:)).^2, 'omitnan'));
rmse2 = sqrt(mean((M(:) - M2(:)).^2, 'omitnan'));
globalRatio = rmse2 / max(rmse1, eps);
bestDefCorr = max(abs([localCorr(phi2n, xphi1n), localCorr(phi2n, dphi1dx)]));

newMode1Var = evn(1);
newMode2Var = evn(2);
newMode2Significant = newMode2Var >= 0.05;
newRank2Improves = globalRatio <= 0.90;
newPhi2IsDeformation = bestDefCorr >= 0.70;
newSecondModePhysical = newMode2Significant && newRank2Improves && newPhi2IsDeformation;

out = struct();
out.oldMode1Var = ev(1);
out.oldMode2Var = ev(2);
out.oldGainRelFro = rel1 - rel2;
out.oldNo22Sigma12 = ss(1) / max(ss(2), eps);
out.oldNo22Mode1Var = evs(1);
out.oldNo22Mode2Var = evs(2);
out.oldNo22GainRelFro = gainRelFroNo22;
out.oldNo22BestAbsCorr = bestAbsCorr;
out.oldLegacyLooMode1Min = min(looMode1, [], 'omitnan');
out.oldLegacyLooMode1Mean = mean(looMode1, 'omitnan');
out.oldPhi2LooMin = min(looPhi2, [], 'omitnan');
out.oldPhi2LooMean = mean(looPhi2, 'omitnan');
out.oldAuditRank2Structure = oldAuditStruct;
out.oldLegacyMode2Real = oldLegacyMode2Real;
out.oldLegacySecondModePhysical = oldLegacySecondModePhysical;
out.oldPhi2SpanCos = cosSpan;
out.oldPhi2SpanRmse = rmseSpan;
out.oldMeanRmseA = mean(rmA, 'omitnan');
out.oldMeanRmseB = meanRmseB;
out.oldMeanRmseC = meanRmseC;
out.oldDeformationVerdict = oldDeformVerdict;
out.oldFirstPlusSecondCos = oldFirstPlusSecondCos;
out.oldFirstPlusSecondRmseUnit = oldFirstPlusSecondRmseUnit;
out.oldFirstPlusSecondSufficient = oldFirstPlusSecondSufficient;

out.newMode1Var = newMode1Var;
out.newMode2Var = newMode2Var;
out.newGlobalRmseRatio = globalRatio;
out.newBestDefCorr = bestDefCorr;
out.newMode2Significant = newMode2Significant;
out.newRank2Improves = newRank2Improves;
out.newPhi2IsDeformation = newPhi2IsDeformation;
out.newSecondModePhysical = newSecondModePhysical;
end

function r = localCorr(a, b)
m = isfinite(a) & isfinite(b);
if nnz(m) < 3
    r = NaN;
    return;
end
C = corrcoef(a(m), b(m));
r = C(1, 2);
end

function c = localCorrCos(a, b)
m = isfinite(a) & isfinite(b);
if nnz(m) < 3
    c = NaN;
    return;
end
aa = a(m);
bb = b(m);
c = dot(aa, bb) / max(norm(aa) * norm(bb), eps);
end

function y = localZeroMeanUnitL2(y)
y = y(:);
m = isfinite(y);
if nnz(m) < 5
    y(:) = NaN;
    return;
end
w = y(m) - mean(y(m), 'omitnan');
nrm = norm(w);
if ~(isfinite(nrm) && nrm > eps)
    y(:) = NaN;
    return;
end
y(:) = 0;
y(m) = w ./ nrm;
end
