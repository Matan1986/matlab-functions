# Switching Module â€” System Alignment Note

---

## 1. Context

The Switching module underwent additional formalization during Phase X. That work included:

- **Micro-surveys** (recorded in survey tables and summarized in related reports; see `docs/switching_canonical_reality.md` and `reports/switching_channel_expansion_attempt.md`).
- **Canonical reality lock** â€” factual consolidation of how canonical Switching is defined in the repository (pipeline vs object, `S` construction, scope flags); see `docs/switching_canonical_reality.md`.
- **Direction alignment (channel-aware model)** â€” explicit decision that structural differences are interpreted as a single pipeline with channel-aware behavior rather than multiple independent canonical pipelines; see `docs/switching_canonical_direction.md` and the post-analysis sections of `reports/switching_channel_expansion_attempt.md`.

This note is an **interpretation layer** only. It does not replace or edit system-level playbooks or switching survey documents.

---

## 2. System-Level Baseline

The following is summarized **strictly** from `docs/analysis_module_reconstruction_and_canonicalization.md` and `docs/analysis_module_reconstruction_and_canonicalization_full_workflow.md` (Phase 0â€“8 framing and companion sections):

- **Canonical is defined as protocol**, not by file or folder name alone. The full workflow states that canonical is defined by **entrypoint**, **backend**, **dependencies**, **execution contract**, and **validation** (â€œCanonical = Protocol (NOT Location)â€ in the full workflow).
- **Multiple entrypoints may exist** in the repository. The full workflowâ€™s runtime-reality discussion records **many entrypoints** while distinguishing them from **one canonical Switching protocol** (not â€œonly one script file in the repoâ€ in the sense of excluding all other scripts).
- **The system may contain mixed zones** â€” for example legacy analysis, mixed regions, or unknown entrypoints â€” while still protecting a canonical core and keeping deviation observable (full workflow Â§4.3 â€œProtect Truth â€” Donâ€™t Clean the Worldâ€ and related â€œpartially canonical by designâ€ snapshots).

This section does not add rules beyond what those documents state.

---

## 3. Switching-Level Observation

From switching-specific documentation (`docs/switching_canonical_reality.md`, `docs/switching_canonical_direction.md`, `reports/switching_channel_expansion_attempt.md`):

- **Switching analysis is implemented via a shared canonical pipeline** (survey-backed: canonical defined as pipeline; registered entrypoint and pipeline criteria cross-referenced in those docs).
- **Multiple `S` construction paths exist** in the repository snapshot; survey material records **multiple** definitions with **one** path marked canonical.
- **Differences** among paths and readouts are tied to **measurement channel** (e.g. **XX** / **XY** as used in the direction and expansion reports) and **channel-dependent processing rules**, rather than being treated in current scope as separate canonical pipelines (see direction lock and post-analysis clarifications in the same sources).

---

## 4. Resolution

**There is no contradiction** between system-level canonical definitions (playbooks) and module-level Switching formalization (Phase X surveys and direction lock).

**Interpretation:**

| Layer | Meaning |
|--------|--------|
| **SYSTEM LEVEL** | **Canonical = protocol-based definition** (entrypoint, backend, dependencies, execution contract, validation â€” as in the full workflow). |
| **SWITCHING LEVEL** | The canonical **protocol** is **instantiated** as: **single pipeline + channel-aware behavior** (explicit direction lock: `CHANNEL_MODEL = SINGLE_PIPELINE_WITH_CHANNEL_AWARENESS`; structural overlap and shared pipeline logic; differences described as behavioral). |

System vocabulary addresses **what counts as canonical** (protocol). Switching vocabulary addresses **how that protocol manifests** in this module (one pipeline with channel-aware rules).

---

## 5. Consistency Rule

**Module-specific interpretation is allowed** when all of the following hold:

- The **canonical entrypoint** (protocol anchor) is **preserved**.
- **Pipeline structure** remains **fixed** in the sense intended by the direction lock (not parallel unrelated canonical pipelines for the same role).
- **Differences are behavioral** (rules, normalization, options, channel-aware branches), **not** ad-hoc alternate canonical architectures.
- **Validation criteria** for canonical-labeled execution and outputs are **satisfied** (playbooks tie canonical trust to declared entrypoint, contracts, and validation â€” this note does not enumerate additional criteria).

If any prerequisite is unclear from existing docs, treat the needed detail as **UNKNOWN** until resolved from authoritative sources.

---

## 6. Boundary Clarification

- **Switching documentation and Phase X formalization do not redefine** system-level canonical rules in the playbooks.
- They provide a **concrete instantiation narrative** â€” how survey facts and direction lock **fit inside** protocol-based canonicality already described at system level.

---

## 7. Alignment Status

```
SYSTEM_ALIGNMENT_STATUS = CONSISTENT
MODULE_MODEL = SINGLE_PIPELINE_WITH_CHANNEL_AWARENESS
SYSTEM_MODEL = PROTOCOL_BASED_CANONICAL
```

---

## 8. Implication

- Future **channel extensions** (for example **XX** analysis discussed as a placeholder in `reports/switching_channel_expansion_attempt.md`) should be implemented, where possible, as **channel-aware extensions of the canonical pipeline** (behavior and rules within the fixed protocol), **not** as **separate canonical pipelines** â€” **unless** a separate pipeline is **proven necessary** after definition work and agreement (the expansion report frames scope formalization before implementation-only expansion).

This implication is **governance-oriented**, not a physics claim.

---

## 9. Classification

```
TYPE = ALIGNMENT_LAYER
SCOPE = SWITCHING_MODULE
MODIFICATION_TYPE = ADDITIVE_ONLY
SYSTEM_IMPACT = NONE
```

---

*End of alignment note.*

