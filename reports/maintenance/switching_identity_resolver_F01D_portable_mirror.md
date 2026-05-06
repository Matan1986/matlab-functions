# SW-ID-RESOLVER-F01D — Portable Switching identity mirror

Date: 2026-05-06  
Branch: `maintenance/switching-identity-f01`

## Scope

F01D only:
- add narrow `.gitignore` exception so `tables/switching_canonical_identity.csv` can be tracked,
- normalize `tables/switching_canonical_identity.csv` as a governance mirror of registry anchor,
- emit F01D maintenance artifacts.

No resolver/caller changes (F01E deferred).

## Registry anchor confirmation

- Registry file inspected read-only: `analysis/knowledge/run_registry.csv`.
- Unique Switching `canonical_identity_anchor` row found:
  - `run_2026_04_03_000147_switching_canonical`
  - run root: `results/switching/runs/run_2026_04_03_000147_switching_canonical`

## Mirror path and policy

- Mirror path: `tables/switching_canonical_identity.csv`
- Mirror value set to registry anchor run id.
- Mirror role explicitly documented as:
  - `ROLE=TRACKED_GOVERNANCE_MIRROR`
  - `AUTHORITY_RULE=REGISTRY_ANCHOR_WINS_ON_CONFLICT`

This preserves policy: registry nomination is authoritative; mirror is portable governance metadata.

## `.gitignore` change

- Added narrow exception:
  - `!tables/switching_canonical_identity.csv`
- Existing `tables/**` ignore behavior for other generated table outputs remains intact.

## Force-add expectation

- After this exception, normal explicit `git add tables/switching_canonical_identity.csv` should be sufficient.
- `git add -f` is not expected to be required unless another later ignore rule is introduced.

## Why resolver remains unchanged

F01D is portability/governance only. Resolver and caller semantics (including fail-closed/advisory enforcement and mtime fallback handling) are explicitly deferred to F01E.

## Remaining F01E work

- Implement canonical fail-closed or explicitly labeled advisory behavior in resolver/callers.
- Remove silent canonical interpretation of newest-by-mtime fallback.
- Validate caller behavior boundaries and publish follow-up status.
