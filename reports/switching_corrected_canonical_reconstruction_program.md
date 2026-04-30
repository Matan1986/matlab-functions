# Switching corrected-canonical reconstruction program

- Scope: Switching only
- Mode: planning/audit/documentation only
- Scientific execution in this task: none

## Stage 1 - Repository history narrative

1. The old non-canonical Switching stack carried much of the paper-intended physical analysis, but it was outside the new canonical infrastructure.
2. A new canonical module (`Switching/analysis/run_switching_canonical.m`) was created and correctly produced canonical source `S_percent`.
3. The same producer also emitted PT/CDF/model-backbone, residual, and Phi/kappa outputs in neighboring canonical artifacts, creating mixed-output confusion risk.
4. Governance later reclassified those PT/CDF/mode outputs as diagnostic (`EXPERIMENTAL_PTCDF_DIAGNOSTIC` and `DIAGNOSTIC_MODE_ANALYSIS`), forbidden as corrected-old manuscript evidence.
5. The project selected corrected-old restoration: replay the old physical recipe inside corrected canonical governance, using clean canonical `S_percent` plus locked validated inputs and verified legacy PT template provenance.
6. The corrected-old authoritative builder now exists and produced authoritative corrected-old backbone/residual/Phi1/kappa1/mode1/remainder/quality artifacts under gated execution.
7. The current need is full reconstruction closure: identify all old analysis families, map current replacements, isolate gaps, and sequence safe remaining tasks without reintroducing contamination.

Key evidence:
- `docs/switching_governance_persistence_manifest.md`
- `docs/switching_analysis_map.md`
- `reports/switching_canonical_output_separation_design.md`
- `reports/switching_corrected_old_authoritative_builder.md`
- `tables/switching_corrected_old_authoritative_builder_status.csv`
- `tables/switching_corrected_old_authoritative_quality_metrics.csv`
- TASK_002A diagnostic visual QA refinement (optional manual review): `reports/switching_corrected_old_quality_metrics_visual_QA_refinement.md`, `tables/switching_corrected_old_quality_metrics_visual_QA_refined_status.csv`, `figures/switching/diagnostics/corrected_old_task002_quality_QA_refined/`

## Stage 2 - Deep old-analysis inventory

Deep old-analysis families found and inventoried:

- raw/processed map and collapse products
- PT/CDF/barrier/PT_matrix branch
- backbone construction lineage
- residual map and decomposition lineage
- SVD/Phi/kappa mode families
- rank structure and mode-boundary branches
- asymmetry/LR branches
- transition/crossover branches (including T22)
- effective-observable and WI/X branches
- width/W, `I_peak`, `S_peak`, and related mapping branches
- gauge/coordinate/atlas/geocanon branches
- robustness/sensitivity and preprocessing branches
- figure-generation/provenance branches
- manuscript claim-language and semantic inventories
- contamination/quarantine forensic registries

Structured artifact:
- `tables/switching_old_analysis_deep_inventory.csv`

## Stage 3 - Current corrected/canonical inventory

Current products were classified into:
- `canonical_source`
- `validated_input`
- `corrected_old_authoritative`
- `experimental_diagnostic`
- `diagnostic_only`
- `legacy_reference_only`
- `quarantined`
- `missing`

Explicitly mapped:
- clean canonical source view (`S_percent` boundary)
- locked effective observables
- verified legacy PT_matrix route
- corrected-old authoritative backbone/residual/Phi1/kappa1/reconstruction outputs
- separated canonical PT/CDF diagnostic view
- separated canonical mode diagnostic view
- stale/quarantined corrected-old attempts and misleading pre-authoritative artifacts

Structured artifact:
- `tables/switching_current_corrected_canonical_inventory.csv`

## Stage 4 - Old-to-current reconstruction matrix

Per old component, the matrix maps:
- corrected/canonical replacement (if any)
- reconstruction status
- missing reason
- next action
- priority and manuscript relevance

Structured artifact:
- `tables/switching_old_to_corrected_canonical_reconstruction_matrix.csv`

## Stage 5 - Guard-compatibility audit

Guard-compatibility principle was applied: keep anti-contamination protections strong, but make approved corrected-old reintegration explicit.

Still blocked by guards (must remain blocked):
- mixed canonical diagnostic PT/CDF/residual/Phi/kappa as manuscript evidence
- quarantined corrected-old attempts as evidence
- old figures as data
- fallback-only replay
- ambiguous unnamespaced `X`/`collapse`/`phi`/`kappa`/`canonical`
- uncontrolled old/new mixing

Explicitly allowed by precise guarded path:
- clean canonical `S_percent` source view
- locked `I_peak`, `S_peak`
- `W/width` as alignment-only input
- verified legacy PT_matrix as template-locked reference
- corrected-old authoritative outputs from gated builder run

W/width conclusion:
- Allowed as validated alignment input (`ALIGNMENT_INPUT_ONLY`)
- Forbidden as universal canonical coordinate claim (`WIDTH_CANONICAL_OVERCLAIMED=NO`, `X_CANONICAL_OVERCLAIMED=NO`)

Main compatibility finding:
- Most guards are compatible.
- A subset of pre-authoritative status artifacts is stale and can falsely suggest corrected-old reintegration is still blocked.
- Required fix is narrow supersession/update of stale state keys, not guard weakening.

Structured artifact:
- `tables/switching_guard_compatibility_audit.csv`

## Stage 6 - Contamination/confusion audit

Audited risk vectors include:
- mixed canonical diagnostic-column reuse
- legacy `results_old` promoted as data instead of provenance reference
- quarantined script/artifact reuse
- stale pre-authoritative status reuse
- old figures reused as data
- ambiguous bare naming and namespace conflation
- guards that are stale/ambiguous against approved corrected-old path

Structured artifact:
- `tables/switching_corrected_canonical_contamination_audit.csv`

## Stage 7 - Missing reconstruction tasks

Missing/partial/decision-gated work was converted to tasks with:
- required inputs
- forbidden inputs
- expected outputs
- required gates
- dependencies
- risk and priority
- manuscript relevance
- recommended agent type (narrow/broad)
- parallelization status

Structured artifact:
- `tables/switching_missing_reconstruction_tasks.csv`

## Stage 8 - Full corrected-canonical reconstruction program

Safe execution order:

1. Post-authoritative finite-grid/interpolation closure audit. (blocking)
2. Authoritative old-vs-corrected backbone parity bridge. (blocking before several branches)
3. In parallel after closure: asymmetry/LR replay, mode-2+ boundary reaffirmation, and stale-artifact supersession prep.
4. T22 crossover corrected audit (after asymmetry branch dependencies).
5. WI/X gauge reconstruction with strict non-overclaim rules.
6. Gauge/atlas re-grounding on corrected-old authoritative outputs.
7. Legacy PT/CDF diagnostic branch documentation refresh (diagnostic-only).
8. Figure provenance remap and figure safety gate update.
9. Final manuscript claim audit.
10. Publication figure authorization decision.

## Program-level conclusions

- Corrected-old authoritative core now exists and is the intended manuscript path.
- Full reconstruction closure is still partial across asymmetry, crossover, WI/X gauge, atlas, and figure-provenance layers.
- Anti-contamination protections should remain in force; only stale-state guard records need narrow compatibility updates.
- Publication figures are not yet fully authorized.

## Visualization and inspection requirements for reconstruction

Every old-analysis reconstruction stage that produces numerical outputs should also produce at least one human-inspection figure when scientifically meaningful. These figures are QA/inspection artifacts first, not manuscript claims.

Default figure policy:

- Prefer PNG outputs for inspection.
- Do not generate MATLAB `.fig` files by default unless explicitly requested.
- Follow repository visualization/export guidance:
  - `docs/visualization_rules.md`
  - `docs/figure_style_guide.md`
  - `docs/figure_export_infrastructure.md`
  - `docs/figure_repair_priority.md`
  - `tools/save_run_figure.m` where applicable.

Semantic labeling requirements:

- Figures must clearly state source family, semantic family, and variant in the report text or caption.
- Figures must not silently mix `legacy_old`, corrected-old / `CORRECTED_CANONICAL_OLD_ANALYSIS`, `canonical_residual_decomposition`, `canonical_geometric_decomposition`, `canonical_replay`, or diagnostic / experimental PTCDF outputs.
- Figures must expose orientation and plotted range choices explicitly, especially for X-like and collapse-like panels.
- Any display-only transform must be labelled as display-only and must not be written back into source data.
- If an inspection figure looks wrong, first check source family, orientation, axis choice, range limits, and display transform before interpreting physics.

Readiness rule:

A reconstruction stage is not considered reviewable unless it writes machine-readable outputs and human-inspection material, including figures when applicable.

## Lessons learned from initial reconstruction confusion

The initial attempt to restart the Switching old-analysis reconstruction exposed several semantic and workflow risks. These lessons are now part of the reconstruction contract:

- Do not treat `switching_canonical_S_long` as a single semantic family; it is a mixed producer requiring column-level classification.
- `S_percent` / measured source S belongs to `CANON_GEN_SOURCE`.
- PT/CDF/backbone/residual diagnostic columns belong to `EXPERIMENTAL_PTCDF_DIAGNOSTIC`.
- Do not promote PTCDF diagnostic outputs to corrected-old authority.
- Do not use forbidden stems such as `X_canon`, `collapse_canon`, `Phi_canon`, or `kappa_canon` for new outputs.
- Do not assume the word “canonical” means manuscript-safe, publication-safe, or corrected-old authoritative.
- Do not start broad old-analysis replay until semantic preflight is committed, reviewed, and passing.
- Do not execute rename from the alias/rename plan until a separate rename-execution phase is explicitly approved.
- Keep old/corrected-old/canonical residual/geocanon/replay/diagnostic families separated in filenames, reports, captions, and tables.
- When a lint rule flags a forbidden token inside policy/forbidden-use/notes text, distinguish real unsafe promotion from governance documentation before changing contract content.
- Every reconstruction stage must document what it did as repository artifacts, not only chat summaries.
