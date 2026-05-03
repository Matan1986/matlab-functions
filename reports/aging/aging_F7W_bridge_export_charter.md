# Aging F7W — Fit-vs-direct decomposition bridge/export charter

## Purpose

Define the **exact bridge/export contract** for a **neutral, lineage-preserving comparison layer** between **fit-based (Track A / stage5–6)** and **direct/non-fit (stage4 / consolidation Track B–style)** decomposition products. This charter **does not** implement the bridge, rerun decomposition, extract tau, execute ratios, fit models, unify physics meaning, or elevate diagnostics to model-safe status.

**Anchors:** F7V (`405e385`), F7U (`a18efb7`), governance (`docs/aging_measurement_definition_freeze.md`, F7J scope map).

## Bridge/export objective

The bridge is a **dual-track neutral export**, not a canonical single observable:

- Preserve **distinct identities** for Track A and Track B streams (`branch_family`, `decomposition_path_id`, explicit tags).
- Record **how each value was produced** (producer, `source_artifact`, `source_run`, lineage).
- Enable **side-by-side and policy-gated comparison** only where F7V pairing policy allows—**without** claiming that `AFM_like` equals `Dip_depth` or `FM_like` equals `FM_abs`.
- **No silent substitution** of one track for the other in numerators, denominators, or tau readers.

## Future output artifact families (not created by this task)

| Artifact (future) | Role |
|-------------------|------|
| `aging_F7W_bridge_component_long.csv` | One row per observation: component value on declared grid with full metadata and eligibility flags. |
| `aging_F7W_bridge_component_index.csv` | One row per **component stream** (path + component_id): semantic contract, claims, tau/ratio use status. |
| `aging_F7W_bridge_pairing_policy.csv` | Machine-readable allowed/forbidden **pairings** between fit and direct streams (references `component_stream_id`). |
| `aging_F7W_bridge_status.csv` | **Post-implementation** execution verdicts (only when real bridge outputs exist on disk). Distinct from charter-phase `aging_F7W_status.csv`. |

**Schema definitions only** (this task): see `tables/aging/aging_F7W_future_*_schema.csv`. These files describe **required columns** for future generators—**not** populated bridge tables.

## Required schema authority

- **Long table:** `tables/aging/aging_F7W_future_bridge_component_long_schema.csv`
- **Index:** `tables/aging/aging_F7W_future_bridge_component_index_schema.csv`
- **Pairing policy:** `tables/aging/aging_F7W_future_bridge_pairing_policy_schema.csv`

## No-substitution guardrails

Authoritative rows: `tables/aging/aging_F7W_no_substitution_guardrails.csv` (aligned with F7V forbidden substitutions and measurement freeze).

## Minimal implementation scope (future)

Authoritative rows: `tables/aging/aging_F7W_minimal_implementation_scope.csv` — read/consolidate **existing** structured outputs where possible; **no** new decomposition math, fitting, tau extraction, or ratio execution inside the bridge job.

## Validation gates (future implementation)

Authoritative rows: `tables/aging/aging_F7W_validation_gates.csv`. Bridge must not self-report success until gates pass (columns present, lineage complete, forbidden pairings absent from ratio-eligible flags, etc.).

## Downstream transition rules

When the project may move to tau charters, baseline ratio, or multipath robustness: `tables/aging/aging_F7W_downstream_transition_rules.csv`.

**Multipath ratio robustness** remains **blocked** until bridge implementation **and** paired tau paths exist per F7V/F7T contracts—**not** authorized by this charter alone.

## Remaining blockers

`tables/aging/aging_F7W_remaining_blockers.csv`.

## Machine-readable verdicts (charter phase)

`tables/aging/aging_F7W_status.csv` — charter complete; bridge **not** implemented.
