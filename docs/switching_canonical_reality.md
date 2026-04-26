# Switching Canonical Reality (Factual Lock)

This document states **observed repository facts** from survey tables and related inventories. It is not a narrative, motivation, or implementation plan.

---

## Current Canonical Structure

- **Canonical is defined via a registered pipeline entrypoint:** `Switching/analysis/run_switching_canonical.m` is recorded as the canonical entrypoint in `tables/switching_canonical_entrypoint.csv` (see also `tables/survey_canonical_definition_mode.csv`).
- **No persisted canonical `S` object file is present in the surveyed snapshot:** `tables/survey_S_object_existence.csv` records `CANONICAL_S_OBJECT_EXISTS = NO`; `tables/canonical_switching_maps.csv` is cited in surveys as showing `exists_on_disk=NO` for the declared canonical map artifact.
- **A canonical entrypoint exists:** same registry and script path as above; `tables/survey_canonical_definition_mode.csv` lists `canonical_entrypoint_registry` and `canonical_entrypoint_script` as present.

---

## S Definition

- **`S` is constructed in the canonical pipeline flow** (in-memory `Smap`, with declared output name `switching_canonical_S_long.csv` under run-scoped paths per `reports/switching_micro_surveys.md` and `tables/survey_S_definitions.csv`).
- **`S` is not stored as a single canonical object file** in the current repository snapshot per the survey tables above.

---

## Channel Structure

- **Multiple `S` definitions / construction paths exist:** `tables/survey_S_definitions.csv` lists multiple scripts with `constructs_S = YES`, with `MULTIPLE_S_DEFINITIONS_EXIST = YES` and only one path marked canonical.
- **There is no explicit channel abstraction documented as a standalone subsystem** in the survey artifacts; channel behavior is described in terms of canonical script behavior (validation range, columns) and non-canonical experimental scripts (for example entries under `experimental/` in `tables/survey_canonical_scope.csv`).

---

## Canonical Scope

- **Survey flag:** `CANONICAL_SCOPE = MULTI_CHANNEL` (`tables/survey_canonical_scope.csv`).
- **Meaning in artifacts:** canonical script supports channel selection over numeric IDs `[1..4]` and carries `channel` as a data column; this is **not** the same as a fully formalized channel architecture document in the repo.

---

## System State

- **Canonical core exists** in the sense used by the playbook: validated canonical entrypoint and pipeline criteria (e.g. references to `SINGLE_SOURCE_RUN`, `FIXED_PIPELINE`, etc., in `docs/analysis_module_reconstruction_and_canonicalization.md`).
- **Canonical scope is not closed as a formal â€œchannel systemâ€ specification** beyond survey flags and code-linked evidence.
- **Channel system (as an explicit, documented abstraction for onboarding and authority) is not defined** in the survey outputs; experimental and non-canonical paths are referenced separately in the same survey tables.

---

## Final Flags (verbatim)

```
CANONICAL_S_OBJECT_EXISTS = NO
MULTIPLE_S_DEFINITIONS_EXIST = YES
CANONICAL_DEFINED_AS_PIPELINE = YES
CANONICAL_DEFINED_AS_OBJECT = NO
CANONICAL_SCOPE = MULTI_CHANNEL
```

---

*Evidence sources: `tables/survey_*.csv`, `reports/switching_micro_surveys.md`, `tables/switching_micro_surveys_status.csv`, playbook docs cross-referenced in those artifacts.*

### Updated Interpretation â€” Channel Model Clarification

The survey result:

CANONICAL_SCOPE = MULTI_CHANNEL

reflects the presence of multiple S construction paths.

However:

- These paths share a common computational structure
- Differences are primarily behavioral (rules, normalization, options)
- Not architectural (separate pipelines)

Therefore:

SYSTEM_STRUCTURE =
SINGLE PIPELINE + CHANNEL-AWARE BEHAVIOR

---

## 2026-04-26 Canonical scientific status update (append-only)

- This section is appended after the earlier survey-based structural notes above.
- The earlier sections remain historical repository-fact context and are not deleted or rewritten here.
- Current canonical scientific authority for Switching interpretation now comes from the Stage D4, Stage E, Stage E5, Stage E5B, and limited claim-readiness outputs under `tables/` and `reports/`.

### Current canonical model status

- The current canonical Switching model is the leading-order interpretable hierarchy:
  `S ~= S_backbone + kappa1 Phi1 + kappa2 Phi2`.
- Stage D4 resolved the current canonical mode relationship as:
  - `Phi1 = backbone_error`
  - `Phi2 = backbone_tail_residual`
  - `Kappa2 = tail_burden_tracker`
- Stage E passed canonical static observable mapping for `kappa1` and `kappa2`.

### Caveat and claims boundary

- The current rank-2 canonical model is not a full closure.
- Stage E5 and E5B keep a rank-3 branch open as `weak_structured_residual`.
- Rank-3 is documented only as an open residual branch and is not promoted as a physical mode.
- Limited canonical claims are allowed only with the explicit leading-order / not-full-closure caveat attached.
- Full-closure claims remain blocked.

### Canonical vs noncanonical separation rule

- Legacy or noncanonical `kappa1`, `kappa2`, `Phi1`, or `Phi2` findings remain historical / noncanonical unless they are revalidated in the canonical pipeline.
- Deprecated or historical files such as `docs/switching_canonical_definition.md` and older noncanonical Switching reports must not be treated as the current canonical scientific authority.
- Older noncanonical analysis history is preserved for provenance, but it must be read as historical context rather than current canonical truth.

