# Relaxation Reports Namespace README

## Namespace Role
`reports/relaxation/` is the durable Relaxation report namespace for policy-linked analysis, audits, and publication-prep narratives.

## Durable Relaxation Report Contract
- Reports must declare family tags and scope.
- RF3R and RF3R2 report lines must remain separated.
- Reports must carry readiness caveats when content is candidate/diagnostic/repaired-replay rather than fully canonical.
- Report presence does not imply full Relaxation canonical readiness.

## Report Family Tagging
Each report should include explicit tags such as:
- `family`
- `RF_family` (`RF3R`, `RF3R2`, or not-applicable)
- `artifact_class` (`diagnostic`, `repaired_replay`, `canonical_candidate`, `publication_prep`)
- `lineage_reference`

## Diagnostic vs Publication-Prep Reports
- `diagnostic` reports document probes, audits, and troubleshooting; they are non-canonical by default.
- `publication_prep` reports may summarize publication-targeted artifacts but require explicit lineage, transform, and units traceability.
- Publication-prep status is per report family/output, not a module-wide readiness claim.

## Preservation Rules
- Preserve RF3R/RF3R2 separation and view-family distinctions.
- No migration, cleanup, or deletion is authorized by this README.

