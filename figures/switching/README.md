# figures/switching/ README

## Purpose
`figures/switching/` is the durable Switching figure namespace for promoted visual artifacts intended for long-lived reference.

## Naming and Promotion Rules
- Figure names must include family/purpose context and avoid ambiguous canonical aliases.
- Promotion into `figures/switching/` must be explicit from run lineage, not implicit by copy location.
- Promoted figures must preserve family separation for `legacy_old`, `canonical_residual_decomposition`, `canonical_geometric_decomposition`, and `canonical_replay`.

## Lineage Backlink Requirement
Each promoted figure must include metadata or adjacent index entry with:
- source run path (`results/switching/runs/<run_id>/`)
- producer script
- promotion timestamp or promotion note
- family tag
- canonicality/diagnostic status

No figure promotion is allowed without lineage metadata.

## Diagnostic Figure Labeling
- Diagnostic figures must be labeled diagnostic and remain non-canonical unless explicitly promoted with policy approval.
- Replay figures must remain replay-scoped and must not be relabeled as canonical geometric/residual outputs.

## Geocanon Naming Restrictions
Forbidden new names:
- `X_canon`
- `collapse_canon`
- `Phi_geo`
- `kappa_geo`
- `mode_geo`
- `width_canon`
- `reactivity_canon`
- `A_active`

Allowed geocanon naming examples include:
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
