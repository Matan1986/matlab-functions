# Switching Artifact Policy

## Scope
This policy defines Switching artifact organization and indexing rules for Phase 3 documentation coverage only. It does not authorize file movement, deletion, scientific rewrites, or cross-module synthesis claims.

## Switching Artifact Family Taxonomy
Switching artifacts are organized into explicit families that must remain separate.

### Mandatory Family Separation
- `legacy_old`: historical/legacy Switching artifacts and old run surfaces retained for historical replay/reference.
- `canonical_residual_decomposition`: canonical residual/decomposition lineage and derivatives.
- `canonical_geometric_decomposition`: canonical geocanon/ridge geometric decomposition lineage.
- `canonical_replay`: replay/parity artifacts used to reproduce or audit prior recipes without redefining canonical outputs.

These four families are mandatory and must not be merged, collapsed, or renamed.

### Phi1 / decomposition vocabulary pointer

Phi1 naming (manuscript vs diagnostic), the misleading filename **`switching_canonical_phi1.csv`**, and blocked phrases **`Phi1_canon`** / **`canonical Phi1`**: **`docs/switching_phi1_terminology_contract.md`** and **`tables/switching_phi1_terminology_registry.csv`**. Artifact inventory rows remain authoritative in **`tables/switching_corrected_old_authoritative_artifact_index.csv`**.

## Source-of-Truth Hierarchy (Switching)
Priority order for Switching artifact truth:
1. `results/switching/runs/<run_id>/` lineage containers (run manifest, status, logs, run-scoped outputs).
2. Durable promoted Switching layers: `tables/switching/`, `reports/switching/`, and `figures/switching/`.
3. Governance/policy context in `docs/` and `reports/maintenance/` or `tables/maintenance_*.csv`.
4. Legacy namespaces (`results_old/`, `tables_old/`, legacy source surfaces) for historical replay/reference only.

## Run-Level vs Durable Promoted Outputs
- Run-level outputs belong under `results/switching/runs/<run_id>/` and preserve lineage evidence.
- Durable promoted outputs belong in `tables/switching/`, `reports/switching/`, and `figures/switching/` only after lineage-aware promotion.
- Durable promotion must keep backlinks to source run and producer script.

## Geocanon Naming Constraints
Switching geocanon naming must preserve approved geocanon semantics and avoid deprecated aliases.

### Forbidden New Names
- `X_canon`
- `collapse_canon`
- `Phi_geo`
- `kappa_geo`
- `mode_geo`
- `width_canon`
- `reactivity_canon`
- `A_active`

### Allowed Geocanon Naming Examples
- `active_ridge_geocanon`
- `ridge_center_geocanon`
- `ridge_tangent_geocanon`
- `ridge_normal_geocanon`
- `w_perp_geocanon`
- `S_ridge_amp_geocanon`
- `S_ridge_area_geocanon`
- `ridge_curvature_geocanon`
- `skew_perp_geocanon`
- `tail_weight_perp_geocanon`
- `reactivity_geocanon_candidate`

## Family Handling Rules
- Canonical artifacts: remain in canonical family scope with lineage-first indexing.
- Diagnostic artifacts: non-canonical by default; must be explicitly marked diagnostic and linked to source run/script.
- Replay artifacts: kept in `canonical_replay` and must not be relabeled as canonical residual/geometric outputs.
- Legacy artifacts: kept in `legacy_old` historical scope and treated as write-closed reference context.

## Cross-Module Claim Restriction
This document is Switching-only governance. It makes no cross-module scientific claims and does not synthesize Aging/Relaxation scientific evidence into Switching canonical status claims.

## Cleanup Restrictions
- No file moves.
- No file renames.
- No file deletions.
- No scientific artifact rewrites.
- No family merges.
- No geocanon concept renames.
- No relocation of Switching artifacts without lineage and consumer checks.
- Safe cleanup is not authorized by this policy stage.
