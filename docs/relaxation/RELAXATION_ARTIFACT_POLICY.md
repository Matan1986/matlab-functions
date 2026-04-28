# Relaxation Artifact Policy

## Purpose and Scope
This policy defines the Relaxation artifact organization and promotion contract for Phase 3 index-layer completion.

Scope is documentation/index governance only.

Non-goals in this policy step:
- no file moves
- no renames
- no deletions
- no cleanup execution
- no scientific artifact rewrites
- no code refactors
- no figure regeneration

## Relaxation Artifact Family Taxonomy
Relaxation artifacts are organized into the following governance families:
- `RUN_LINEAGE`: run-scoped lineage bundles under `results/relaxation/runs/<run_id>/`.
- `CANONICAL_CANDIDATE_CURVE_FIRST`: curve-first canonical candidate runs (for example `results/relaxation_canonical/...`).
- `CANONICAL_CANDIDATE_POST_FIELD_OFF`: post-field-off canonical candidate runs (for example `results/relaxation_post_field_off_canonical/...`).
- `RF3R_CANONICAL_ADJACENT`: RF3R post-field-off canonical-adjacent run families (for example `results/relaxation_post_field_off_RF3R_canonical/...`).
- `RF3R2_REPAIRED_REPLAY`: repaired replay tables and downstream consumers rooted in `tables/relaxation/relaxation_RF3R2_repaired_*`.
- `DIAGNOSTICS_AND_AUDITS`: diagnostic, forensic, and governance artifacts that are non-canonical by default.
- `DURABLE_PROMOTED_TABLES`: durable promoted Relaxation tables in `tables/relaxation/`.
- `DURABLE_PROMOTED_REPORTS`: durable promoted Relaxation reports in `reports/relaxation/`.
- `DURABLE_PROMOTED_FIGURES`: durable promoted Relaxation figures/maps in `figures/relaxation/`.
- `LEGACY_OR_HISTORICAL`: historical replay/reference material in legacy namespaces; read/reference only.

## RF3R and RF3R2 Separation (Mandatory)
- RF3R and RF3R2 are distinct families and must remain distinct in naming, indexing, and lineage references.
- No policy action may collapse RF3R artifacts into RF3R2 artifacts, or RF3R2 artifacts into RF3R artifacts.
- RF3R2 publication-facing figures are durable only when source lineage and transform metadata are explicitly documented.

## Repaired Replay vs Canonical Candidate vs Diagnostics
- `REPAIRED_REPLAY` denotes reconstructed or repaired replay objects intended to preserve explicit lineage and reproducibility. This does not imply full canonical acceptance.
- `CANONICAL_CANDIDATE` denotes candidates under evaluation. Candidate status is not equivalent to final canonical status.
- `DIAGNOSTIC` denotes troubleshooting/audit/probe outputs. Diagnostics are non-canonical unless explicitly promoted with lineage and policy evidence.

## Tau/Collapse Readiness Caveat
- Tau and collapse outputs that consume RF3R2 repaired replay artifacts are tracked as candidate or diagnostic outputs unless their lineage, transform contract, and readiness class are explicitly declared.
- Presence of tau/collapse artifacts does not authorize full Relaxation canonical readiness claims.

## Publication-Ready vs Not-Publication-Ready
- `publication_ready`: artifact satisfies required lineage, transform, units, source, inclusion/exclusion, and style-policy metadata.
- `not_publication_ready`: missing one or more required metadata or readiness checks.
- Publication readiness is per artifact family/output, not a module-wide blanket status.

## Promotion Rules (Tables, Reports, Figures)
- Promotion to `tables/relaxation/`, `reports/relaxation/`, and `figures/relaxation/` requires:
  - explicit source run or source table/report reference
  - producer script reference
  - family tag and RF family tag where applicable
  - readiness tag (`canonical_candidate`, `repaired_replay`, `diagnostic`, etc.)
  - lineage link to run container or upstream durable source
- Figures/maps additionally require transform and units metadata plus inclusion/exclusion rules.
- Promotion must preserve RF3R/RF3R2 and view-family separation.

## No Cleanup Without Lineage Checks
- No cleanup, relocation, deduplication, or consolidation is authorized without lineage checks and consumer checks.
- Run-manifest-bound artifacts and execution-status evidence are lineage anchors and must not be treated as disposable.

## No Full Canonical Readiness Claim
- This policy does not claim full Relaxation canonical readiness.
- Any full-module canonical readiness claim is explicitly out of scope for this document.

