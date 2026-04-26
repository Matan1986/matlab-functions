# Switching Source-of-Truth Owner Decision Audit

## Executive Summary

This audit confirms a real Switching source-of-truth ambiguity across three layers: (1) canonical run-root policy anchors, (2) repo-root mirrored tables used as operational inputs, and (3) identity routing that still permits newest-by-mtime selection. Current canonicalization work is adding canonical-adjacent producers and consumers on top of that mixed routing, so owner selection of one authoritative identity and consumption route is required before further expansion.

AUTHORITATIVE_SWITCHING_SOURCE_OF_TRUTH = Canonical Switching run-root data under `results/switching/runs/run_2026_04_03_000147_switching_canonical/`, produced via `Switching/analysis/run_switching_canonical.m`, with identity anchored by `CANONICAL_RUN_ID=run_2026_04_03_000147_switching_canonical`.

## Canonical Source-of-Truth Today

- Canonical data scope is explicitly constrained by `docs/switching_layer_boundary.md` to one run root: `results/switching/runs/run_2026_04_03_000147_switching_canonical/`.
- Canonical entrypoint is explicitly registered in `tables/switching_canonical_entrypoint.csv` as `Switching/analysis/run_switching_canonical.m`.
- Canonical identity anchor appears in `analysis/knowledge/run_registry.csv` with `canonical_identity_anchor` on `run_2026_04_03_000147_switching_canonical`.
- `tables/switching_canonical_identity.csv` currently exists and encodes the same run id, but `docs/project_control_board.md` still warns it is missing/downgraded. This is a governance contradiction that must be reconciled.
- Repo-root `tables/*.csv` and reports are boundary-classed as reference/root artifacts, not canonical run-backed physics truth.

## Repo-Root Mirror Map

Key mirror pattern confirmed:

- Shared mirror writer: `Switching/utils/switchingWriteTableBothPaths.m` writes to both run tables and repo-root `tables/`.
- Canonical-adjacent producers actively using the mirror writer include:
  - `run_switching_canonical_collapse_hierarchy.m`
  - `run_switching_canonical_reconstruction_visualization.m`
  - `run_switching_canonical_transition_highT_diagnostics.m`
  - `run_switching_canonical_map_visualization.m`
  - `run_switching_mode_admissibility_audit.m`
  - plus additional backbone/decomposition/audit scripts.
- Representative mirrored artifacts:
  - `tables/switching_canonical_collapse_hierarchy_error_vs_T.csv`
  - `tables/switching_canonical_collapse_hierarchy_status.csv`
  - `tables/switching_canonical_input_gate_status.csv`
  - `tables/switching_canonical_reconstruction_visualization_summary.csv`

Status class decision:

- Run-root copies are `CANONICAL_RUN_OUTPUT`.
- Repo-root copies are `REFERENCE_MIRROR` unless explicitly designated legacy/advisory.

## Identity Route Map

Identity/selection routes and classifications:

- `docs/switching_layer_boundary.md` single run-root anchor -> `AUTHORITATIVE`
- `tables/switching_canonical_entrypoint.csv` sole canonical entrypoint -> `AUTHORITATIVE`
- `tables/switching_canonical_identity.csv` explicit canonical id registry (currently present) -> `AUTHORITATIVE` pending board wording reconciliation
- `analysis/knowledge/run_registry.csv` `canonical_identity_anchor` row -> `ADVISORY` support anchor (discovery/registry layer)
- `Switching/utils/switchingResolveLatestCanonicalTable.m` newest-by-mtime selection across `run_*_switching_canonical` -> `ADVISORY` and conflict-prone for canonical identity
- `run_dir_pointer.txt` references in non-canonical/experimental scripts -> `DEPRECATED`

Identity-route conflict confirmed:

- Resolver logic is latest-by-mtime while policy anchors point to one locked canonical id. These can diverge silently when new runs are added.

## Consumer/Risk Map

High-risk consumers that read repo-root mirrors or combine mirror + mtime routes:

- `run_switching_backbone_validity_audit.m` reads repo-root canonical gate/hierarchy tables.
- `run_switching_canonical_transition_highT_diagnostics.m` reads repo-root canonical hierarchy/gate tables and emits mirrored outputs.
- `run_switching_mode_admissibility_audit.m` uses latest-by-mtime resolver and repo-root status dependencies.
- `run_switching_canonical_collapse_visualization.m` and `run_switching_canonical_reconstruction_visualization.m` load canonical inputs via mtime resolver and publish repo-root mirror outputs.

Legacy flat fallback/legacy references:

- `switching_alignment_audit.m` still has fallback output to `results/switching/alignment_audit`.
- Legacy report references remain in `switching_mechanism_followup.m`, `switching_mode23_analysis.m`, and `switching_shape_rank_analysis.m`.

Risk classification:

- `ACTION_NOW`: source-of-truth ambiguity from mirror-as-input plus mtime identity route on canonical-adjacent scripts.
- `WATCH`: governance contradiction between current identity table presence and control-board missing warning.
- `DEFER`: broad legacy cleanup and non-canonical report-path rewrites.

## Minimal Remediation Plan

1. `SAFE_NOW_DOC_ONLY`  
   Publish explicit label policy: repo-root Switching tables/reports are reference/mirror-only unless a row is explicitly governance-registry authoritative.

2. `SAFE_NOW_DOC_ONLY`  
   Reconcile control-board identity wording with actual file state for `tables/switching_canonical_identity.csv` (present vs downgraded warning) without changing scientific outputs.

3. `REQUIRES_OWNER_DECISION`  
   Select one authoritative identity locator order for canonical input resolution: identity table and locked run id first, then optional advisory fallback.

4. `SAFE_NOW_SINGLE_FILE`  
   After owner decision, apply one bounded patch in `Switching/utils/switchingResolveLatestCanonicalTable.m` to prefer explicit canonical identity anchor before mtime selection.

5. `REQUIRES_OWNER_DECISION`  
   Decide whether to keep repo-root mirrors as compatibility artifacts or retire selected mirrors; if kept, enforce reference-only wording in producer reports.

6. `SAFE_NOW_SINGLE_FILE`  
   After owner decision, apply one bounded patch in `Switching/analysis/switching_alignment_audit.m` to remove flat fallback `results/switching/alignment_audit` output route.

7. `DEFER`  
   Defer broad legacy script/report cleanup and path migrations until source-of-truth and identity order are locked.

## Safe Now vs Deferred

- `SAFE_NOW_DOC_ONLY` (2): mirror/reference labeling policy; control-board identity wording reconciliation.
- `SAFE_NOW_SINGLE_FILE` (2): resolver anchor-first patch; alignment-audit fallback removal patch.
- `REQUIRES_OWNER_DECISION` (2): identity locator precedence; mirror retention vs retirement policy.
- `DEFER` (1): broad legacy path cleanup.

## Final Verdicts

AUDIT_COMPLETED = YES  
AUTHORITATIVE_SOURCE_IDENTIFIED = YES  
ROOT_MIRROR_RISK_CONFIRMED = YES  
IDENTITY_ROUTE_CONFLICT_CONFIRMED = YES  
SAFE_NOW_DOC_ONLY_STEPS = 2  
SAFE_NOW_SINGLE_FILE_STEPS = 2  
CODE_MODIFIED = NO  
BACKLOG_MUTATED = NO  
SAFE_SCOPE_RESPECTED = YES  
READY_FOR_OWNER_DECISION = YES
