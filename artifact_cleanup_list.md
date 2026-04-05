# Artifact Cleanup List — Canonical Repository Classification

**Generated:** 2026-03-30  
**Scope:** tables/*, reports/*, *_status.csv artifacts  
**Method:** Read-only classification using canonical_state_freeze freeze point and integrity audit

---

## A. Canonical Artifacts (KEEP)

These artifacts derive from or represent the canonical state established under the freeze point.

### Core Canonical Reconstruction (PT + Φ₁)

- **tables/canonical_reconstruction_summary.csv** — Aggregated LOTO metrics; mean_RMSE_PT=0.0696, mean_RMSE_FULL=0.0194
- **tables/canonical_reconstruction_metrics.csv** — Per-fold reconstruction metrics
- **tables/canonical_reconstruction_status.csv** — Execution verdict: SUCCESS with 14/14 improvement
- **reports/canonical_reconstruction.md** — Official protocol documentation; final model = PT_PLUS_PHI1

### Φ₁ Canonical Enforcement (Post-Enforcement)

- **tables/phi1_enforcement_status.csv** — 13 pipelines with CANONICAL_ENFORCED status and mixing-guards active
- **reports/phi1_enforcement.md** — Enforcement rules and evidence
- **tables/phi1_audit.csv** — Phi1 source audit table
- **reports/phi1_audit.md** — Audit narrative

### Canonical Relaxation Measurement Definition

- **tables/relaxation_canonical_definition.csv** — Protocol definition under canonical measurement regime
- **reports/relaxation_canonical_definition.md** — Formal definition
- **tables/relaxation_canonical_implementation_check.csv** — Implementation verification
- **reports/relaxation_canonical_implementation_check.md** — Verification narrative
- **tables/relaxation_measurement_canonical_self_audit.csv** — Self-audit under canonical scope
- **reports/relaxation_measurement_canonical_self_audit.md** — Self-audit narrative
- **tables/relaxation_full_dataset.csv** — Complete dataset at canonical definition
- **reports/relaxation_full_dataset.md** — Dataset narrative
- **tables/tau_extracted.csv** — Extracted τ times under canonical protocol

### Relaxation Measurement Audit (Canonical Window)

- **tables/relaxation_measurement_focused_t0_norm_window_summary.csv** — Focused t₀ normalization window audit
- **reports/relaxation_measurement_focused_t0_norm_window.md** — Audit results
- **tables/relaxation_outlier_audit_status.csv** — Outlier audit execution context
- **reports/relaxation_outlier_audit.md** — Outlier audit narrative

### Κ₁ Extraction & Projection (Canonical Protocol)

- **tables/kappa1_from_PT.csv** — Direct projection of κ₁ from canonical PT reconstruction
- **reports/kappa1_from_PT_report.md** — Extraction protocol
- **tables/kappa1_from_PT_aligned.csv** — Aligned extraction post-validation
- **reports/kappa1_from_PT_aligned_report.md** — Alignment narrative

### Φ₂ Canonical Reconciliation (Same-Input Replay)

- **tables/phi2_reconciliation_same_input_tests.csv** — Same-input replay metrics for φ₂ conflict resolution
- **reports/phi2_reconciliation_canonical_summary.md** — Canonical summary of φ₂ reconciliation
- **reports/phi2_reconciliation_report.md** — Full φ₂ reconciliation analysis
- **tables/phi2_reconciliation_verdicts.csv** — Φ₂ verdict table
- **tables/phi2_reconciliation_sources.csv** — Source tracking

### Φ₂ Canonical Deformation Basis

- **tables/phi2_deformation_fit.csv** / **phi2_deformation_fit.mat** — Canonical deformation basis
- **tables/phi2_extended_deformation_basis.csv** — Extended basis
- **reports/phi2_extended_deformation_basis.md** — Basis analysis

### PT-to-Parameter Mapping (Canonical)

- **tables/PT_kappa_relaxation_mapping.csv** — PT → κ₁ mapping for relaxation
- **reports/PT_kappa_relaxation_mapping.md** — Mapping protocol
- **tables/PT_to_relaxation_mapping.csv** — PT → relaxation parameter mapping
- **reports/PT_to_relaxation_mapping.md** — Full mapping analysis

### Post-Enforcement Pipeline Stability

- **tables/switching_pipeline_stability_post_enforcement_status.csv** — Stability confirmed post-enforcement
- **reports/switching_pipeline_stability_post_enforcement.md** — Narrative
- **tables/phi_kappa_canonical_verdict.csv** — Final φ-κ canonical system verdict
- **reports/phi_kappa_canonical_verdict.md** — Verdict narrative

### Κ₂ Analysis (Within Canonical Scope)

- **tables/kappa2_phenomenological_audit.csv** — Phenomenological audit under canonical scope
- **reports/kappa2_phenomenological_audit.md** — Audit narrative
- **tables/kappa2_operational_signature.csv** — Operational signature in canonical system
- **reports/kappa2_operational_signature.md** — Signature analysis

### Master State Documentation

- **tables/canonical_state_freeze.csv** — Canonical freeze snapshot
- **tables/canonical_state_freeze_status.csv** — Freeze status indicators
- **reports/canonical_state_freeze.md** — Freeze narrative

### Integrity Audit (Master Record)

- **tables/integrity_invalid_artifacts_audit.csv** — **KEEP** — Master audit of all invalidity markers
- **reports/integrity_invalid_artifacts_audit.md** — **KEEP** — Master audit narrative
- **tables/integrity_invalid_artifacts_status.csv** — **KEEP** — Validation status of integrity audit

---

## B. Stale Artifacts (MARK_STALE/ARCHIVE)

These artifacts use non-canonical Φ₁ or represent pre-enforcement legacy implementations.

### Non-Canonical Φ₁ Variants (Local Implementation Attempts)

- **tables/kappa1_phi1_local_v2.csv** — Failed local φ₁ variant
- **reports/kappa1_phi1_local_v2.md** — Non-canonical attempt narrative
- **tables/kappa1_phi1_local_v2_20260329_234400.csv** — Timestamped variant
- **reports/kappa1_phi1_local_v2_20260329_234400.md** — Dated variant narrative
- **tables/kappa1_phi1_local_v2_20260329_234420.csv** — Another timestamped variant
- **reports/kappa1_phi1_local_v2_20260329_234420.md** — Another variant narrative
- **tables/phi1_instability_analysis.csv** — Analysis of non-canonical instability
- **reports/phi1_instability_analysis.md** — Instability narrative
- **tables/phi1_instability_status.csv** — Status showing coarse intersection grid mismatch

### Pre-Enforcement Bridge Representations (Non-Canonical)

- **tables/kappa1_bridge_comparison_v2.csv** — Non-canonical κ₁ bridge (v2)
- **tables/kappa1_bridge_comparison_v2_20260329_235900.csv** — Timestamped variant
- **reports/representation_bridge_v2.md** — Bridge representation (non-canonical v2)
- **tables/representation_bridge_status_v2.csv** — Status
- **tables/representation_bridge_status_v2_20260329_235900.csv** — Timestamped status variant
- **tables/phi1_bridge_metrics_v2.csv** — Non-canonical φ₁ bridge metrics
- **tables/phi1_bridge_metrics_v2_20260329_235900.csv** — Timestamped variant

### Pre-Enforcement Observable Analysis (LegacyAlpha Search)

- **tables/alpha_observable_debug.csv** — Pre-enforcement α observable debugging
- **tables/alpha_observable_debug_full.csv** — Extended debug
- **reports/alpha_observable_search.md** — Legacy α search narrative
- **tables/alpha_observable_models.csv** — Models from legacy search
- **tables/alpha_observable_status.csv** — Legacy status

**Action:** Mark as stale; these do not represent canonical φ₁ and should not be used for inference.

---

## C. Partial Artifacts (IGNORE UNTIL RERUN)

These artifacts represent incomplete execution or runs that did not materialize.

### Migration Pilots (Both Versions)

- **tables/switching_migration_pilot.csv**  
  → **switching_migration_pilot_status.csv**: EXECUTION_VALID = **NO** (MATLAB wrapper timeout at 300s)
- **reports/switching_migration_pilot.md** — Incomplete narrative
- **tables/switching_migration_pilot_v2.csv**  
  → **switching_migration_pilot_v2_status.csv**: EXECUTION_VALID = **NO** (Wrapper did not complete)
- **reports/switching_migration_pilot_v2.md** — Incomplete narrative

**Reason:** Preservation verdicts are invalid; migration scope is defined but pilot execution did not complete.

### Κ₁ Projection Validation (Fragile)

- **tables/kappa1_projection_test.csv**  
  → **kappa1_projection_test_status.csv**: EXECUTION_VALID = **NO**, RUN_COMPLETED = **NO**
- **reports/kappa1_projection_test.md** — Incomplete validation
- **tables/cleanup_kappa1_projection_attempt.csv** — Cleanup record
- **reports/cleanup_kappa1_projection_attempt.md** — Cleanup narrative

**Reason:** Projection validation attempts are not execution-valid; κ₁ robustness remains fragile.

### Parameter Robustness (Marked Partial)

- **tables/global_physics_stability_status.csv** — PARTIAL status; missing required inputs (map_pair_metrics.csv, observable_pair_by_temperature.csv)
- **reports/global_physics_stability_summary.md** — Incomplete stability assessment
- **tables/kappa2_kww_shape_test_status.csv** — Marked PARTIAL despite SUCCESS execution

**Reason:** Inputs unavailable or completeness not established.

### Estimator Design (Failed Execution)

- **tables/estimator_design_status.csv** — FAILURE: logical index out of bounds error
- **tables/estimator_design_width_comparison.csv**, **_kappa1_comparison.csv** — Incomplete outputs
- **reports/estimator_design_proposal.md** — Incomplete proposal

**Action:** Ignore until rerun; execution failed.

---

## D. Invalid Artifacts (ARCHIVE)

These artifacts explicitly contradict canonical policy or are marked with invalidity indicators.

### Aging Measurement Definition Contamination (Master Control)

**Root Markers:**
- **tables/aging_measurement_definition_audit.csv**: Contains `VALID_FOR_AGING=NO`, `DEFINITION_CONTAMINATION=YES`
- **reports/aging_measurement_definition_audit.md**: Explicitly marked INVALID AGING ANALYSIS
- **tables/aging_measurement_definition_audit_status.csv**: Status confirmation

**All downstream artifacts derived from contaminated definition:**

#### Aging Α (Alpha) Closure Analysis

- tables/aging_alpha_closure_best_model.csv
- tables/aging_alpha_closure_master_table.csv
- tables/aging_alpha_closure_models.csv
- tables/aging_alpha_closure_residual_audit.csv
- reports/aging_alpha_closure_report.md

#### Aging Hermetic Closure

- tables/aging_hermetic_closure_models.csv
- tables/aging_hermetic_closure_residuals.csv
- reports/aging_hermetic_closure_report.md

#### Aging Κ₁/Κ₂ Analysis

- tables/aging_kappa1_kappa2_models.csv
- tables/aging_kappa1_kappa2_status.csv
- tables/aging_kappa1_loocv.csv, aging_kappa1_models.csv
- tables/aging_kappa2_best_model.csv, aging_kappa2_master_table.csv, aging_kappa2_models.csv, aging_kappa2_residuals.csv
- reports/aging_kappa1_prediction.md
- reports/aging_kappa2_report.md
- tables/aging_kappa_comparison.csv, aging_kappa_comparison_status.csv
- reports/aging_kappa_comparison.md

#### Aging Meta-Audit (Derived from Contamination)

- tables/aging_meta_audit_model_ranking.csv
- tables/aging_meta_audit_result_inventory.csv
- reports/aging_meta_audit_verdict_summary.md
- reports/aging_meta_audit_latest_results.md

#### Aging Prediction & Comparisons

- tables/aging_model_comparison_strict.csv
- tables/aging_prediction_ablation.csv, aging_prediction_best_model.csv, aging_prediction_models.csv
- reports/aging_prediction_report.md

#### Cross-Domain Confusion (Aging ↔ Relaxation)

- tables/aging_relaxation_confusion_audit.csv
- tables/aging_relaxation_confusion_audit_status.csv
- reports/aging_relaxation_confusion_audit.md

**Action:** ARCHIVE — Do not use for any aging-related inference or comparison.

### IO Consistency Diagnostics (Stale Snapshot Artifacts)

- reports/io_consistency_20260327_151634.md, ...151752.md, ...151818.md, ...151857.md, ...151919.md, ...151934.md, ...154227.md, ...155921.md, ...161503.md

**Reason:** Snapshot state artifacts from development diagnostics; outputs_found=0, CONSISTENT_RUN=NO.

**Action:** ARCHIVE — diagnostic artifacts only.

---

## E. Cleanup Strategy (DETERMINISTIC)

### Phase 1: Preserve Canonical Core

**Keep (no action):**
- All 40+ canonical reconstruction, enforcement, and relaxation artifacts (Section A)
- Integrity audit master records (these document what is invalid)
- **canonical_state_freeze.*** files (state snapshot)

**Impact:** ~45 files preserved; foundation of repository integrity maintained.

---

### Phase 2: Mark Stale (Reclassify, Archive)

**Move to archive or mark NO_LONGER_ACTIVE:**
- All non-canonical Φ₁ variant attempts (kappa1_phi1_local_v2.*, representation_bridge_v2.*, alpha_observable_*.*)
- Pre-enforcement legacy implementations
- **~17 artifacts**

**Impact:** Prevents accidental use of non-enforced implementations. No scientific impact.

---

### Phase 3: Archive Partial (Incomplete Executions)

**Archive until rerun:**
- Migration pilots v1 & v2 (both EXECUTION_VALID=NO)
- Κ₁ projection test (EXECUTION_VALID=NO)
- Estimator design (FAILURE)
- Global physics stability (PARTIAL with missing inputs)
- **~15 artifacts**

**Impact:** Clears incomplete run artifacts; preservation verdicts remain invalid until pilots complete.

---

### Phase 4: Audit Invalid Contamination (Root Cause Cleanup)

**Archive all aging-derived artifacts:**
- Master: aging_measurement_definition_audit.* (root contamination marker)
- All downstream: aging_alpha_*, aging_hermetic_*, aging_kappa_*, aging_meta_*, aging_prediction_*, aging_relaxation_confusion_*
- **~40 artifacts with DEFINITION_CONTAMINATION=YES marked**

**Impact:** Removes false contaminated inference chain at source. Aging analysis is blocked with explicit invalidity marker.

---

### Phase 5: Remove Diagnostic Snapshots

**Archive IO consistency reports:** 9 stale snapshot diagnostic files.

**Impact:** Clean repository state; diagnostics no longer needed post-freeze.

---

## F. Summary Statistics

| Category | Count | Status |
|----------|-------|--------|
| **Canonical** | 45 | **KEEP** |
| **Stale** | 17 | `mark_stale` / `archive` |
| **Partial** | 15 | `ignore` (rerun pending) |
| **Invalid (Aging)** | 40+ | `archive` |
| **Invalid (Snapshots)** | 9 | `archive` |
| **TOTAL** | ~126 | |

**Canonical Retention Rate:** 45 / 126 ≈ **36%**  
(Remainder: 81 stale/partial/invalid artifacts removed from active use)

---

## G. Root-Cause Evidence

### Invalidity (Aging Contamination)

**Marker:** run_aging_measurement_definition_audit.m, line block:
```
INVALID_FOR_AGING = YES
DEFINITION_CONTAMINATION = YES
SHOULD_BE_USED = NO
```

**Master Audit:** tables/integrity_invalid_artifacts_audit.csv — documents all 40+ contaminated artifacts.

**Action Required:** Respect invalidity markers; do not use aging_*.* outputs for aging analysis.

### Partial (Migration Timeout)

**Evidence:**  
- switching_migration_pilot_status.csv:  
  `EXECUTION_STATUS=FAILED`, `MATLAB wrapper run timed out after 300 seconds (exit code 124)`
- switching_migration_pilot_v2_status.csv:  
  `Wrapper command ... did not complete in-session`

**Verdict:** EXECUTION_VALID = NO → preservation verdicts invalid.

### Stale (Non-Canonical Φ₁)

**Evidence:**  
- phi1_instability_status.csv:  
  `LOCAL_PHI1_BUILT_ON_COARSE_INTERSECTION_GRID ... NOT_MATCH_CANONICAL_PHI1`

**Verdict:** Φ₁ mixing guard blocks non-canonical usage post-enforcement.

---

## H. Next Steps (Execution Readiness)

Once this list is reviewed:

1. **Create archival directory:** `/archive/stale_artifacts/` and `/archive/partial_artifacts/` and `/archive/invalid_artifacts/`
2. **Move files** from tables/ and reports/ to appropriate archive folder
3. **Update .gitignore** to prevent re-commit of archived items
4. **Verify canonical core:** Run `integrity_invalid_artifacts_audit.md` consistency check post-move

**Expected outcome:** Clean, deterministic repository with explicit traceability for all removed artifacts.

---

**Classification Frozen:** 2026-03-30  
**Evidence Source:** canonical_state_freeze.csv, canonical_state_freeze.md  
**Audit Authority:** integrity_invalid_artifacts_audit.csv  
**No Manual Edits Applied** — all metrics from existing artifacts.
