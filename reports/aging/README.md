# reports/aging README

## Durable Aging report namespace
- `reports/aging/` is the durable Aging narrative/report layer.
- It stores Aging audit reports, replay reports, diagnostics summaries, and policy-linked writeups.

## Aging-only vs cross-module reports
- Aging-only reports may use only Aging-owned scope evidence.
- Cross-module bridge/comparison reports must be marked excluded for Aging-only claims.
- Named bridge/comparison paths remain blocked as Aging-only evidence even if they include Aging tokens.

## Report status and lifecycle
- Suggested lifecycle statuses:
  - `draft`
  - `diagnostic`
  - `replay`
  - `canonical_candidate_support`
  - `superseded`
  - `excluded_cross_module`
- Reports that rely on contaminated or ambiguous evidence must be marked `superseded` or `excluded_cross_module`.

## Contamination warning policy
- Clean rerun policy is authoritative for Aging-only reporting.
- If contamination is detected, the report must:
  - declare contamination clearly
  - avoid Aging-only scientific claims from contaminated evidence
  - require rerun before policy-level Aging-only conclusions
- Current clean baseline expected by this namespace:
  - `AGING_ARTIFACT_AUDIT_CONTAMINATED=NO`
  - `NEEDS_AGING_AUDIT_RERUN=NO`
