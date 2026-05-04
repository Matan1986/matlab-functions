% run_switching_canonical_state_audit
%
% Switching governance / canonical-state audit runner (tables + markdown report).
% This script performs no physics fitting, no parameter estimation, and no new scientific inference.
% It emits governance inventories and editorial syntheses for human and agent routing.
%
% Execution infrastructure: addpath(repoRoot/Aging/utils) is required only because shared
% createRunContext / createSwitchingRunContext live under Aging/utils. That is repository
% execution plumbing, not an Aging dataset dependency, Aging science dependency, or Relaxation
% dependency. Do not interpret this path as coupling this runner to Aging analysis inputs.
%
% Verdict hygiene: rows in switching_canonical_state_status.csv use legacy short key names;
% their values are STATIC_DECLARED / EDITORIAL synthesis unless stated otherwise in code
% comments — they are not automatically recomputed from authoritative gate CSV columns at
% runtime. Use authoritative source CSVs for live gates; use completed_tests for file-existence
% probes only.
%
% Does not run physics fits; does not read Relaxation inputs.
%
% Outputs (repo-root durable):
%   tables/switching/switching_canonical_state_family_inventory.csv
%   tables/switching/switching_canonical_state_claim_safety_matrix.csv
%   tables/switching/switching_canonical_state_completed_tests.csv
%   tables/switching/switching_canonical_state_open_tasks.csv
%   tables/switching/switching_canonical_state_cross_module_blockers.csv
%   tables/switching/switching_canonical_state_status.csv
%   reports/switching/switching_canonical_state_audit.md

clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
% INFRA_ONLY: Aging/utils hosts createRunContext.m (shared run allocation). Not Aging data/science.
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

outTblDir = fullfile(repoRoot, 'tables', 'switching');
outRepDir = fullfile(repoRoot, 'reports', 'switching');
if exist(outTblDir, 'dir') ~= 7
    mkdir(outTblDir);
end
if exist(outRepDir, 'dir') ~= 7
    mkdir(outRepDir);
end

runDir = '';
errMsg = '';

try
    cfg = struct();
    cfg.runLabel = 'switching_canonical_state_audit';
    cfg.dataset = 'switching_canonical_state_audit';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    rdTbl = fullfile(runDir, 'tables');
    rdRep = fullfile(runDir, 'reports');
    if exist(rdTbl, 'dir') ~= 7, mkdir(rdTbl); end
    if exist(rdRep, 'dir') ~= 7, mkdir(rdRep); end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0
        fprintf(fidTop, 'SCRIPT_ENTERED\n');
        fclose(fidTop);
    end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'canonical state audit initializing'}, false);

    auditStamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

    familyInventory = buildFamilyInventory(repoRoot);
    claimMatrix = buildClaimSafetyMatrix();
    completedTests = buildCompletedTests(repoRoot);
    openTasks = buildOpenTasks();
    blockers = buildCrossModuleBlockers();

    writetable(familyInventory, fullfile(outTblDir, 'switching_canonical_state_family_inventory.csv'));
    writetable(claimMatrix, fullfile(outTblDir, 'switching_canonical_state_claim_safety_matrix.csv'));
    writetable(completedTests, fullfile(outTblDir, 'switching_canonical_state_completed_tests.csv'));
    writetable(openTasks, fullfile(outTblDir, 'switching_canonical_state_open_tasks.csv'));
    writetable(blockers, fullfile(outTblDir, 'switching_canonical_state_cross_module_blockers.csv'));

    statusTbl = buildStatusVerdicts(repoRoot);
    writetable(statusTbl, fullfile(outTblDir, 'switching_canonical_state_status.csv'));

    writeMarkdownReport(fullfile(outRepDir, 'switching_canonical_state_audit.md'), repoRoot, auditStamp, statusTbl);

    copyfile(fullfile(outTblDir, 'switching_canonical_state_status.csv'), fullfile(rdTbl, 'switching_canonical_state_status.csv'));
    copyfile(fullfile(outRepDir, 'switching_canonical_state_audit.md'), fullfile(rdRep, 'switching_canonical_state_audit.md'));

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, height(familyInventory), ...
        {'wrote durable canonical state audit tables'}, true);

    fprintf('switching_canonical_state_audit: SUCCESS\n');
    fprintf('Tables: %s\n', outTblDir);
    fprintf('Report: %s\n', fullfile(outRepDir, 'switching_canonical_state_audit.md'));

catch ME
    errMsg = ME.message;
    if isempty(runDir)
        error('%s', errMsg);
    end
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'PARTIAL'}, {errMsg}, 0, {'canonical state audit failed'}, true);
    rethrow(ME);
end

function T = buildFamilyInventory(repoRoot)
% STATIC_EDITORIAL: family rows are declared narrative inventory (cell literals), not scraped from CSVs.
% missing_expected uses exist() only for optional path hints — not a full gate recompute.
family_id = {
    'CANONICAL_FOUNDATION'
    'CANONICAL_MAP_SPINE'
    'GEOCANON_RIDGE'
    'GEOCANON_WIDTH_FRAME'
    'COORDINATE_IDENTIFIABILITY'
    'COLLAPSE_COORDINATES'
    'CORRECTED_OLD_REPLAY_OR_NARRATIVE'
    'LEGACY_ONLY'
    'DIAGNOSTIC_ONLY'
    'SUPERSEDED_OR_UNSAFE'
    };
representative_scripts = {
    'Switching/analysis/run_switching_canonical.m; Switching/analysis/run_switching_PT_consistency_audit.m; Switching/analysis/run_switching_decomposition_foundation_audit.m'
    'scripts/run_switching_canonical_map_spine.ps1'
    'Switching/analysis/run_switching_geocanon_descriptor_audit.m; Switching/analysis/run_switching_geocanon_partial_status_diagnosis.m; Switching/analysis/run_switching_geocanon_T1_weighted_ridge_lock.m'
    'T2 width-frame consumers per T1 status (follow-on gates; not separately indexed here)'
    'Switching/analysis/run_switching_coordinate_identifiability_audit.ps1'
    'Switching/analysis/run_switching_phase4B_C01_X_like_panel_orientation_lock.m; run_switching_phase4B_C02_collapse_like_panel_range_lock.m; run_switching_phase4B_C02B_primary_collapse_variant_audit.m'
    'Switching/analysis/run_switching_corrected_old_authoritative_builder.m; docs/switching_analysis_map.md (CORRECTED_CANONICAL_OLD_ANALYSIS)'
    'Switching/analysis/switching_full_scaling_collapse.m; analysis/switching_barrier_distribution_from_map.m (OLD_* namespaces)'
    'CANON_GEN PT/CDF columns per EXPERIMENTAL_PTCDF_DIAGNOSTIC contract'
    'tables/switching_stale_governance_supersession.csv (stale rows)'
    };
representative_tables = {
    'tables/switching_main_narrative_namespace_decision.csv; tables/switching_allowed_evidence_by_use_case.csv; durable promoted CSVs from canonical run'
    'tables/switching_canonical_identity.csv; correlation spine outputs as run'
    'tables/switching_geocanon_descriptor_*.csv; tables/switching_geocanon_T1_weighted_ridge_status.csv; tables/switching_geocanon_partial_status_diagnosis.csv'
    'N/A_pending_T2_promotion'
    'tables/switching_coordinate_identifiability_status.csv; tables/switching_coordinate_identifiability_*_inventory.csv'
    'tables/switching_phase4B_C02B_*.csv; tables/switching_phase4B_C02B_status.csv'
    'tables/switching_corrected_old_authoritative_artifact_index.csv; tables/switching_phi1_terminology_registry.csv'
    'Legacy alignment-era outputs under results_old/tables_old as applicable'
    'switching_canonical_S_long PT_pdf/CDF_pt columns governed as diagnostic'
    'reports/switching_stale_governance_supersession.md'
    };
representative_reports = {
    'docs/decisions/switching_main_narrative_namespace_decision.md; docs/switching_analysis_map.md'
    'reports/switching_corrected_canonical_current_state.md (if present); spine header CURRENT_STATE_ENTRYPOINT'
    'reports/switching_geocanon_descriptor_audit.md; reports/switching_geocanon_partial_status_diagnosis.md; reports/switching_geocanon_T1_weighted_ridge_lock.md'
    'Blocked until T2 frame artifacts indexed'
    'reports/switching_coordinate_identifiability_audit.md (when produced)'
    'reports/switching_phase4B_C02B_primary_collapse_variant_audit.md; reports/switching_phase4B_C02B_review.md'
    'docs/switching_phi1_terminology_contract.md; docs/switching_pre_replay_contract_reset.md'
    'Namespace sections in docs/switching_analysis_map.md'
    'Contract text isolating EXPERIMENTAL_PTCDF_DIAGNOSTIC'
    'reports/switching_stale_governance_supersession.md'
    };
status_verdicts = {
    'COMPLETE documentation contract; producer run-dependent for promoted tables'
    'COMPLETE script inventory; SAFE_TO_COMPARE_TO_RELAXATION NO in spine verdict pattern'
    'PARTIAL descriptors; T1 ridge lock YES; interpretation NO; Relaxation compare NO'
    'OPEN gate-driven'
    'PARTIAL SAFE_TO_TEST_SCALING_COORDINATES YES (audit) vs NO (map spine) — resolve before scaling claims'
    'COMPLETE Phase4B C02B slice per review; QA not physics interpretation'
    'COMPLETE governance separation; replay artifacts run-scoped'
    'REFERENCE_ONLY unless replayed under CORRECTED_CANONICAL_OLD_ANALYSIS'
    'ALLOWED diagnostics only for backbone narrative'
    'Use supersession table before citing stale governance rows'
    };
what_found = {
    'Explicit namespace decision: manuscript backbone = CORRECTED_CANONICAL_OLD_ANALYSIS; CANON_GEN_SOURCE for S; PT/CDF diagnostic separated.'
    'Spine correlates canonical S_long columns with declared namespaces; no scaling physics.'
    'Multiple ridge-center variants diagnosed; weighted primary locked; geocanon interpretation still blocked at T1.'
    'Proceed flag exists to T2 in T1 status; dedicated durable width-frame index still thin in this audit.'
    'Coordinate screening vs identifiability audits exist; scaling-coordinate readiness is gate-dependent.'
    'Primary collapse variants catalogued; defects/residuals QA; SAFE_TO_INTERPRET_PHYSICS NO.'
    'Phi1 terminology registry + authoritative artifact index constrain manuscript vs diagnostic filenames.'
    'Historical OLD_* pipelines documented; must not be called canonical backbone without namespace.'
    'PT/CDF from CANON_GEN not selected as main backbone under narrative decision.'
    'Stale governance rows flagged; follow supersession CSV.'
    };
safe_claims = {
    'Namespace-qualified citations for S provenance and corrected-old narrative scope.'
    'Column-level safe use for map spine diagnostics per script header warnings.'
    'T1 weighted ridge primary lock; comparator variants diagnostic-only per status.'
    'N/A'
    'Finite-coordinate identifiability checks where audit completed successfully.'
    'Collapse variant QA parity vs references; registry semantic boundaries.'
    'Manuscript Phi1 uses corrected-old authoritative paths per registry.'
    'Legacy pipelines reproducible under explicit OLD_* labels.'
    'PT/CDF usable as labeled diagnostic experiments.'
    'Prefer current rows in supersession-indexed artifacts.'
    };
unsafe_claims = {
    'Equating CANON_GEN PT/CDF with manuscript backbone; bare canonical backbone language.'
    'Treating spine output as corrected-old backbone evidence.'
    'Universal geocanon interpretation or Relaxation comparison.'
    'Premature width-frame physical closure without T2 artifacts.'
    'Ignoring divergent SAFE_TO_TEST_SCALING_COORDINATES verdicts across gates.'
    'Physics interpretation of C02B QA panels (flagged NO).'
    'Equating switching_canonical_phi1.csv filename with manuscript Phi1.'
    'Calling OLD_* outputs current manuscript evidence without replay.'
    'Promoting diagnostic PT/CDF to main narrative.'
    'Citing superseded governance without checking supersession.'
    };
next_task = {
    'Maintain promoted canonical tables + run identity sidecars.'
    'Keep CURRENT_STATE report aligned with spine entrypoint when regenerated.'
    'Complete T2 width-frame durable index + interpretation gate review.'
    'Produce/refresh T2 durable tables under explicit namespace.'
    'Publish reconciliation note when scaling-coordinate readiness conflicts across gates.'
    'Promote only after slice gates; keep QA vs physics separation.'
    'Refresh authoritative index when new replay runs promoted.'
    'Keep replay scripts labeled; no silent promotion.'
    'Keep diagnostic figures supplementary.'
    'Resolve Phase5A bundle before Phase5B atomic staging.'
    };
missing_expected = {
    ''
    iifMissing(repoRoot, 'reports/switching_corrected_canonical_current_state.md')
    ''
    ''
    ''
    ''
    ''
    ''
    ''
    ''
    };
T = table(family_id, representative_scripts, representative_tables, representative_reports, ...
    status_verdicts, what_found, safe_claims, unsafe_claims, next_task, missing_expected, ...
    'VariableNames', {'family_id', 'representative_scripts', 'representative_tables', ...
    'representative_reports', 'status_verdicts', 'what_found', 'safe_claims', 'unsafe_claims', ...
    'next_task', 'missing_expected_paths'});
end

function s = iifMissing(repoRoot, rel)
p = fullfile(repoRoot, rel);
if exist(p, 'file') == 2
    s = '';
else
    s = char(rel);
end
end

function T = buildClaimSafetyMatrix()
% STATIC_EDITORIAL: claim_topic / evidence pointers are curated policy summaries, not live reads of gate columns.
claim_topic = {
    'Manuscript backbone narrative (Phi-kappa collapse)'
    'Canonical S maps / identity'
    'Geocanon ridge descriptors physical interpretation'
    'Scaling coordinate tests beyond T'
    'Phase4B collapse QA panels'
    'Rank-2 residual hierarchy leading order'
    'Rank-3 / Phi3 promotion'
    'Relaxation comparison readiness'
    };
main_text = {'PARTIAL'; 'PARTIAL'; 'NO'; 'NO'; 'NO'; 'PARTIAL'; 'NO'; 'NO'};
supplement = {'YES'; 'YES'; 'PARTIAL'; 'PARTIAL'; 'YES'; 'YES'; 'DIAGNOSTIC_ONLY'; 'NO'};
blocked_reason = {
    'Full closure blocked; Stage E5B limited claims only'
    'Must cite CANON_GEN_SOURCE + run id'
    'SAFE_TO_WRITE_GEOCANON_INTERPRETATION NO at T1 and descriptor audit PARTIAL'
    'Conflicting gates: coordinate audit YES vs map spine NO — document before tests'
    'SAFE_TO_INTERPRET_PHYSICS NO in C02B status'
    'CLAIMS_ALLOWED_LIMITED YES; CLAIMS_BLOCKED_FULL_CLOSURE YES'
    'RANK3_PROMOTION_ALLOWED NO'
    'Multiple artifacts: SAFE_TO_COMPARE_TO_RELAXATION NO'
    };
primary_evidence = {
    'tables/switching_stage_e5b_claim_boundary_review.csv; docs/switching_analysis_map.md'
    'tables/switching_canonical_identity.csv; Switching/analysis/run_switching_canonical.m'
    'tables/switching_geocanon_descriptor_status.csv; tables/switching_geocanon_T1_weighted_ridge_status.csv'
    'scripts/run_switching_phase4A_scaling_coordinate_screening.ps1; scripts/run_switching_canonical_map_spine.ps1'
    'tables/switching_phase4B_C02B_status.csv'
    'tables/switching_stage_e5b_claim_boundary_review.csv'
    'tables/switching_stage_e5b_claim_boundary_review.csv'
    'tables/switching_geocanon_descriptor_status.csv; scripts/run_switching_canonical_map_spine.ps1'
    };
T = table(claim_topic, main_text, supplement, blocked_reason, primary_evidence, ...
    'VariableNames', {'claim_topic', 'safe_main_text', 'safe_supplement', 'blocked_or_note', 'primary_evidence_pointer'});
end

function T = buildCompletedTests(repoRoot)
% LIVE_REPO_PROBE: artifact_present is YES/NO from exist(fullfile(repoRoot,...), 'file') only — file presence, not CSV semantics.
test_name = {
    'Main narrative namespace decision recorded'
    'Artifact policy family separation'
    'Geocanon descriptor audit emitted durable tables'
    'Geocanon partial-status diagnosis'
    'T1 weighted ridge primary lock'
    'S observable identity audit (PS gate)'
    'Canonical map spine (PS)'
    'Phase4B C02B primary collapse variant audit + human review'
    'Stage E5B claim boundary review'
    'Phi1 terminology registry + authoritative artifact index'
    };
relPaths = {
    fullfile('tables', 'switching_main_narrative_namespace_decision.csv')
    fullfile('docs', 'switching_artifact_policy.md')
    fullfile('tables', 'switching_geocanon_descriptor_status.csv')
    fullfile('tables', 'switching_geocanon_partial_status_diagnosis.csv')
    fullfile('tables', 'switching_geocanon_T1_weighted_ridge_status.csv')
    fullfile('scripts', 'run_switching_S_observable_identity_audit.ps1')
    fullfile('scripts', 'run_switching_canonical_map_spine.ps1')
    fullfile('tables', 'switching_phase4B_C02B_status.csv')
    fullfile('tables', 'switching_stage_e5b_claim_boundary_review.csv')
    fullfile('tables', 'switching_phi1_terminology_registry.csv')
    };
artifact_present = cell(numel(relPaths), 1);
for i = 1:numel(relPaths)
    artifact_present{i} = ifelse(exist(fullfile(repoRoot, relPaths{i}), 'file') == 2, 'YES', 'NO');
end
evidence_path = relPaths;
notes = {
    ''
    ''
    ''
    ''
    ''
    'Verdict keys emitted by runner pattern — see script for SAFE_TO_* defaults'
    'Declares diagnostic-only use for PT/CDF columns'
    'SAFE_TO_INTERPRET_PHYSICS NO'
    'Rank-2 allowed limited; rank-3 blocked promotion'
    ''
    };
T = table(test_name, artifact_present, evidence_path, notes, ...
    'VariableNames', {'test_name', 'artifact_present', 'evidence_path', 'notes'});
end

function out = ifelse(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end

function T = buildOpenTasks()
% STATIC_EDITORIAL / DECLARED_OPEN_WORK: task rows are editorial backlog pointers, not ticket automation.
task_id = {
    'GEOCANON_T2_WIDTH_FRAME_INDEX'
    'SCALING_COORDINATE_GATE_RECONCILIATION'
    'GAUGE_ATLAS_PHASE5B_STAGING'
    'SEMANTIC_CONTRACT_REPORTS_PRESENT'
    'CURRENT_STATE_REPORT_PRESENT'
    };
priority = {'P0'; 'P0'; 'P1'; 'P2'; 'P2'};
description = {
    'Promote durable width-frame tables/reports under explicit namespace once T2 completes.'
    'Resolve SAFE_TO_TEST_SCALING_COORDINATES YES vs NO across coordinate screening vs map spine.'
    'tables/maintenance_phase5A_gauge_atlas_review_status.csv: SAFE_TO_PROCEED_PHASE5B NO.'
    'Expected paths from scripts (e.g. switching_semantic_contract_materialization.md) missing — register or retire pointers.'
    'Spine references reports/switching_corrected_canonical_current_state.md — ensure exists or update spine pointer.'
    };
T = table(task_id, priority, description, 'VariableNames', {'task_id', 'priority', 'description'});
end

function T = buildCrossModuleBlockers()
% STATIC_EDITORIAL: blocker narrative summarizes documented Switching posture; not a live Relaxation execution trace.
blocker_id = {
    'RELAXATION_COMPARE_DEFAULT_NO'
    'GEOCANON_INTERPRETATION_BLOCKED'
    'GAUGE_BUNDLE_INCOMPLETE'
    };
source_artifact = {
    'tables/switching_geocanon_descriptor_status.csv (SAFE_TO_COMPARE_TO_RELAXATION NO)'
    'tables/switching_geocanon_T1_weighted_ridge_status.csv (SAFE_TO_WRITE_GEOCANON_INTERPRETATION NO)'
    'tables/maintenance_phase5A_gauge_atlas_review_status.csv (SAFE_TO_PROCEED_PHASE5B NO)'
    };
detail = {
    'Explicit NO across geocanon + canonical spine scripts unless a future gate sets YES.'
    'T1 lock completes ridge center but forbids interpretation narrative at this step.'
    'Cross-module placement tightening should wait for Switching-only gauge classification review closure.'
    };
T = table(blocker_id, source_artifact, detail, ...
    'VariableNames', {'blocker_id', 'source_artifact', 'rationale_switching_only'});
end

function T = buildStatusVerdicts(repoRoot)
% repoRoot reserved for future live probes; currently STATIC_DECLARED verdict rows only.
% Legacy verdict_key strings kept for stable CSV schema; values are editorial synthesis, not
% automated gate reads from authoritative status CSVs (contrast: buildCompletedTests exist() probes).
keys = {
    'SWITCHING_CANONICAL_STATE_AUDIT_COMPLETE'
    'SWITCHING_ONLY'
    'RELAXATION_USED'
    'CROSS_MODULE_CLAIM_CREATED'
    'CANONICAL_FOUNDATION_INDEXED'
    'CANONICAL_MAP_SPINE_INDEXED'
    'GEOCANON_T1_STATUS_INDEXED'
    'GEOCANON_T2_STATUS_INDEXED'
    'COORDINATE_IDENTIFIABILITY_INDEXED'
    'COLLAPSE_STATUS_INDEXED'
    'CORRECTED_OLD_STATUS_INDEXED'
    'LEGACY_SEPARATED_FROM_CANONICAL'
    'SAFE_CLAIMS_LISTED'
    'UNSAFE_CLAIMS_LISTED'
    'OPEN_TASKS_LISTED'
    'SAFE_TO_COMPARE_TO_RELAXATION_NOW'
    'SAFE_TO_WRITE_SWITCHING_CANONICAL_INTERPRETATION_NOW'
    'SAFE_TO_RUN_CROSS_MODULE_PLACEMENT_TIGHTENING_NEXT'
    };
vals = {
    'YES'
    'YES'
    'NO'
    'NO'
    'YES'
    'YES'
    'YES'
    'PARTIAL_OPEN_GATE'
    'PARTIAL'
    'YES'
    'YES'
    'YES'
    'YES'
    'YES'
    'YES'
    'NO'
    'PARTIAL'
    'YES'
    };
T = table(keys(:), vals(:), 'VariableNames', {'verdict_key', 'value'});
end

function writeMarkdownReport(pathMd, repoRoot, auditStamp, statusTbl)
% STATIC_EDITORIAL prose + embedded status table (same provenance as buildStatusVerdicts).
fid = fopen(pathMd, 'w');
if fid < 0
    error('writeMarkdownReport:OpenFailed', pathMd);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# Switching canonical analysis state audit\n\n');
fprintf(fid, '**Generated:** %s (MATLAB runner `Switching/analysis/run_switching_canonical_state_audit.m`).\n\n', auditStamp);
fprintf(fid, '**Scope:** Switching-only governance synthesis from existing docs/tables — **no new physics**, **no Relaxation comparison**, **no cross-module AX claims**.\n\n');

fprintf(fid, '## Missing expected paths (inventory)\n\n');
fprintf(fid, '- `reports/switching_corrected_canonical_reconstruction_program.md` — **not found** in repo snapshot (use narrative/docs substitutes).\n');
fprintf(fid, '- `reports/switching_pre_replay_contract_reset_phase1.md` — referenced from `docs/switching_pre_replay_contract_reset.md`; verify copy exists when tightening docs.\n');
fprintf(fid, '- `reports/switching_semantic_contract_materialization.md` — referenced from tooling scripts; **not found** locally.\n');
fprintf(fid, '- `reports/switching_corrected_canonical_current_state.md` — referenced as CURRENT_STATE entrypoint in `scripts/run_switching_canonical_map_spine.ps1`; confirm presence before citing spine.\n\n');

fprintf(fid, '## Solid / complete areas\n\n');
fprintf(fid, '- **Namespace governance:** decision record + `docs/switching_analysis_map.md` separate **`CORRECTED_CANONICAL_OLD_ANALYSIS`** vs **`CANON_GEN_SOURCE`** vs **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**.\n');
fprintf(fid, '- **Stage E5B:** bounded **rank-2** interpretive allowance; **rank-3 promotion blocked** (`tables/switching_stage_e5b_claim_boundary_review.csv`).\n');
fprintf(fid, '- **Phase4B C02B:** variant registry + QA residuals; **physics interpretation explicitly NO** in status.\n');
fprintf(fid, '- **Geocanon T1:** weighted ridge primary lock **COMPLETE**; Relaxation compare **NO**; interpretation **NO** at this step.\n\n');

fprintf(fid, '## Partial / gated areas\n\n');
fprintf(fid, '- **Geocanon descriptors:** many **PARTIAL** rows in descriptor status; interpretation readiness **PARTIAL** overall.\n');
fprintf(fid, '- **Scaling coordinates:** identifiability audit can emit **SAFE_TO_TEST_SCALING_COORDINATES YES** while canonical map spine emits **NO** — reconcile before declaring scaling tests authorized.\n');
fprintf(fid, '- **Gauge atlas Phase 5B:** **SAFE_TO_PROCEED_PHASE5B NO** (`tables/maintenance_phase5A_gauge_atlas_review_status.csv`).\n\n');

fprintf(fid, '## Open work before Relaxation comparison\n\n');
fprintf(fid, '- Switching artifacts still emit **`SAFE_TO_COMPARE_TO_RELAXATION = NO`** by default — **do not** treat Switching as Relaxation-comparable until an explicit gate sets YES with traceability.\n');
fprintf(fid, '- Complete **T2 width-frame** durable promotion and interpretation policy **after** T1 gates.\n');
fprintf(fid, '- Close **gauge atlas / Phase5B** staging per maintenance tables.\n\n');

fprintf(fid, '## Machine-readable verdicts\n\n');
fprintf(fid, 'See `tables/switching/switching_canonical_state_status.csv`.\n\n');

fprintf(fid, '| Key | Value |\n|-----|-------|\n');
for i = 1:height(statusTbl)
    fprintf(fid, '| `%s` | `%s` |\n', char(string(statusTbl.verdict_key(i))), char(string(statusTbl.value(i))));
end
fprintf(fid, '\n');

fprintf(fid, '## Sources consulted (minimum set)\n\n');
fprintf(fid, '- `docs/switching_analysis_map.md`, `docs/switching_artifact_policy.md`\n');
fprintf(fid, '- `docs/switching_pre_replay_contract_reset.md`\n');
fprintf(fid, '- `tables/switching_main_narrative_namespace_decision.csv`\n');
fprintf(fid, '- `tables/switching_geocanon_descriptor_status.csv`, `tables/switching_geocanon_T1_weighted_ridge_status.csv`\n');
fprintf(fid, '- `tables/switching_phase4B_C02B_status.csv`, `reports/switching_phase4B_C02B_review.md`\n');
fprintf(fid, '- `tables/switching_stage_e5b_claim_boundary_review.csv`\n');
fprintf(fid, '- `tables/maintenance_phase5A_gauge_atlas_review_status.csv`\n');
end
