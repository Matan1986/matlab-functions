# Switching pre-replay contract reset — Phase 1 (audit + design)

## 1. Current anchor

- **HEAD:** `5edfc2f` — *Update Switching classification supersession status*
- **Matches expected origin/main anchor** per task brief.

## 2. Opening checks (path-specific)

| Check | Result |
|--------|--------|
| `git log --oneline -5` | `5edfc2f` at top |
| `git status --short` | Tracked tree clean; many **untracked** files (other modules + backlog) — **no** mass staging observed |
| `git diff --cached --name-only` | **Empty** — **nothing staged** |

**Stop rule:** Staged files would have blocked further work — **not triggered.**

## 3. What was inspected (Switching-only, read-only)

- **Docs:** `docs/switching_analysis_map.md`, `docs/switching_artifact_policy.md`, `docs/observables/switching_observables.md`, `docs/templates/switching_analysis_namespace_header.md`, `docs/decisions/switching_main_narrative_namespace_decision.md` (referenced from map), and cross-references inside `docs/switching_*.md` landscape.
- **Tables (representative):** `tables/switching_analysis_classification_status.csv`, `tables/switching_analysis_namespace_clean_map.csv`, `tables/switching_allowed_evidence_by_use_case.csv`, `tables/switching_corrected_old_authoritative_artifact_index.csv`, `tables/switching_corrected_old_authoritative_builder_status.csv`, `tables/switching_stale_governance_supersession.csv`, `tables/switching_analysis_claim_boundary_map.csv` (cited from map), `tables/switching_analysis_confusion_risks.csv` (cited), quarantine / generated-artifact classification tables (names from repo listing).
- **Reports:** `reports/switching_stale_governance_supersession.md`.
- **Code samples (writer patterns only):** `Switching/analysis/run_switching_canonical.m` (header contract block), `scripts/run_switching_stabilized_gauge_figure_replay.m` (paths + status keys).
- **MATLAB not run**; **no** analysis logic edits; **no** staging/commit.

## 4. A. Registry audit — what exists

| Asset | Path | Scope | Current vs historical | Observables | Artifacts | Allowed use | Canon/diagnostic/legacy | Source/lineage | Gaps |
|--------|------|-------|------------------------|-------------|-----------|-------------|---------------------------|----------------|------|
| Analysis map + narrative contract | `docs/switching_analysis_map.md` | Switching backbone/decomposition landscape | **Current** governance prose | Indirect (via namespace rows) | Script/output classes | **Yes** (safe/unsafe per section) | **Yes** (governance labels) | Partial (pointers to tables) | Not a single machine registry; **partial** coverage |
| Namespace clean map | `tables/switching_analysis_namespace_clean_map.csv` | `namespace_id` rows | **Current** | No | Scripts/inputs/outputs summarized | safe_uses / unsafe_uses | **Yes** | **Yes** (maps narrative ↔ technical) | **PARTIAL** — wide but not every file on disk |
| Authoritative artifact index | `tables/switching_corrected_old_authoritative_artifact_index.csv` | Corrected-old authoritative + related | **Current** for indexed paths | No | **Yes** | allowed_use / forbidden_use | **Yes** | **Yes** (producer_or_source) | **PARTIAL** — focused package, not all Switching outputs |
| Classification / status | `tables/switching_analysis_classification_status.csv` | Audit keys | **Mixed** — supersession note explains stale rows | No | No | Via keys | Via keys | Historical snapshot + **CURRENT_*** interpretation | **PARTIAL** — interpret with supersession |
| Allowed evidence | `tables/switching_allowed_evidence_by_use_case.csv` | Manuscript vs diagnostic | **Current** | No | Examples | **Yes** | **Yes** | Caveats | Does not list every artifact path |
| Observable doc | `docs/observables/switching_observables.md` | Physics definitions | **Current** reference | **Yes** | No | N/A | N/A | N/A | **Not** an artifact registry |
| Measurement register | `tables/switching_measurement_definition_evidence_register.csv` | Measurement-definition questions | **Specialized** | Partial | Links to reports | Verdicts | **PARTIAL** | Evidence refs | **Not** a full artifact index |

**Verdict:** A **usable but fragmented** registry ecosystem exists: strong **namespace + claim-boundary** tables and a **corrected-old authoritative index**, plus many specialized inventories. There is **no single** “all observables + all artifacts” machine table that is both **complete** and **current** without cross-walking multiple CSVs and supersession rules.

**Registry layer maturity:** **PARTIAL** (rich governance, distributed sources).

## 5. B. Namespace audit — family separation

**Documented separation (evidence):**

- **`docs/switching_artifact_policy.md`** explicitly mandates **four families not merged:** `legacy_old`, `canonical_residual_decomposition`, `canonical_geometric_decomposition`, `canonical_replay`.
- **`docs/switching_analysis_map.md`** + **`tables/switching_analysis_namespace_clean_map.csv`** separate **governance** ids (`CORRECTED_CANONICAL_OLD_ANALYSIS`, `CANON_GEN_SOURCE`, `EXPERIMENTAL_PTCDF_DIAGNOSTIC`, `LEGACY_OLD_TEMPLATE`) from **technical** namespaces (`OLD_*`, `CANON_GEN`, `REPLAY_*`, `DIAGNOSTIC_FORENSIC`, etc.).
- **Corrected-old authoritative** path is documented via **artifact index** + **builder status** + **stale supersession** (do not read pre-remediation “blocked” as current).

**Gaps / risks (still present):**

- **Naming collisions:** Policy forbids ambiguous geocanon aliases (`X_canon`, `collapse_canon`, `Phi_geo`, …); **grep-level** risk remains for legacy scripts and verdict keys (e.g. figure replay scripts may **track** `X_CANON_CLAIMED` as a **negative** gate — see `run_switching_stabilized_gauge_figure_replay.m`).
- **PT/CDF vs corrected-old:** Repeated quarantine: diagnostic PT/CDF/mode columns from mixed producer must **not** become **CORRECTED_CANONICAL_OLD_ANALYSIS** authority — see classification status + supersession report.
- **Residual vs geometric canon:** Separated in artifact policy; agents must **not** collapse families when replaying or promoting outputs.
- **Cross-module:** Switching docs explicitly restrict cross-module synthesis in places; **no** Relaxation/Aging comparison readiness gates were audited here (**out of scope**).

**Namespace layer maturity:** **PRESENT** for documentation + main CSV maps; **PARTIAL** for exhaustive path-level enforcement (no single automated gate in-repo for all writers).

## 6. C. Lineage audit

**Where lineage is strong:**

- **Authoritative artifact index** rows: `artifact_path`, `namespace_id`, `producer_or_source`, `allowed_use`, `forbidden_use`, `current_status`, `notes`.
- **`run_switching_canonical.m`** header: mixed producer namespaces, evidence status, safe/unsafe use, pointer to current-state entrypoint.
- **Supersession** machinery: `reports/switching_stale_governance_supersession.md` + CSV — **supersedes** stale “no artifacts” interpretations.

**Where lineage is partial or missing:**

- **Ad hoc scripts** under `scripts/` vary: some hardcode `repoRoot`, others use bootstrap patterns — **not** one consistent sidecar schema for every runner.
- **Historical-only** rows in classification CSV without reading **CURRENT_*** / supersession → **CONFLICTING** interpretation risk.

**Lineage maturity (overall):** **PARTIAL** — **PRESENT** for canonical producer + authoritative corrected-old package; **MISSING** or **HISTORICAL_ONLY** for scattered diagnostics unless traced via inventories.

## 7. D. Writer-contract audit

**Consistent elements observed:**

- **Producer-level** contract blocks (example: `run_switching_canonical.m` lines 4–12): writer identity, namespace split, coordinate grid, safe/unsafe use, pointer to reports/tables.
- **Replay/maintenance scripts** often declare **output paths**, **status CSV**, **report path**, and **verdict keys** (example: `scripts/run_switching_stabilized_gauge_figure_replay.m`).
- **Template:** `docs/templates/switching_analysis_namespace_header.md` lists fields agents should fill.

**Inconsistencies / gaps:**

- Not every script includes the full template; **hardcoded paths** appear in some runners (fragility called out in `docs/switching_analysis_map.md` quarantine table).
- **Overwrite policy**, **MATLAB required**, and **required status keys** are **script-dependent**, not unified.

**Writer-contract maturity:** **PARTIAL** — strong exemplars exist; **no** single enforced schema across all Switching writers.

## 8. E. Assistive contract layer (design — Phase 1)

Phase 1 **materializes design artifacts only** (this task):

| Artifact | Purpose |
|----------|---------|
| `docs/switching_pre_replay_contract_reset.md` | Human-readable index + principles + links |
| `tables/switching_pre_replay_registry_contract.csv` | Seed rows for registry contract (expand in Phase 2) |
| `tables/switching_pre_replay_namespace_contract.csv` | Namespace/family rules + enforcement mode |
| `tables/switching_pre_replay_writer_contract_template.csv` | Field-by-field writer checklist |
| `tables/switching_pre_replay_contract_reset_status.csv` | Phase 1 completion / safety flags |

**Agent-facing templates (pre-existing, referenced):** `docs/templates/switching_analysis_namespace_header.md` — copy into new reports/scripts; Phase 2 may add a Switching-specific “preflight snippet” without changing analysis code.

**Assistive-first:** Default modes are **WARN**, **SUGGEST**, **SOFT_FAIL** for missing metadata; **HARD_FAIL** reserved for **unsafe canonical/authoritative promotion** (wrong namespace, forbidden source, diagnostic labeled as manuscript backbone).

## 9. F. Proposed enforcement modes

| Mode | Meaning | Typical use |
|------|---------|-------------|
| **WARN** | Log + continue | Exploratory diagnostics, draft tables |
| **SUGGEST** | Offer template / fixit text | New scripts missing optional header fields |
| **SOFT_FAIL** | Non-zero exit in gated CI only | Maintenance runners that must emit status CSV |
| **HARD_FAIL** | Block promotion / write to authoritative paths | Declaring canonical manuscript outputs from forbidden namespaces or unknown writers |

**Explicit rules (design):**

9. **Do not block exploratory/diagnostic agents unnecessarily** — missing optional lineage should trigger **WARN/SUGGEST**, not **HARD_FAIL**, unless the operation attempts **authoritative** writes.

10. **Block only unsafe canonical/authoritative promotion** — e.g. writing or claiming **CORRECTED_CANONICAL_OLD_ANALYSIS** authority from **EXPERIMENTAL_PTCDF_DIAGNOSTIC** outputs or **unknown** namespace.

## 10. Go / no-go

| Gate | Recommendation |
|------|------------------|
| **Phase 2 — contract materialization** (populate registries, optional validators) | **GO** — evidence base exists; Phase 2 should **enumerate** remaining scripts and align with existing tables **without** merging families. |
| **Old-analysis replay** (broad) | **NO-GO for unattended / blind replay** — governance is strong but **distributed**; assistive layer should be **populated** and runners should declare lineage. **Targeted** replay under existing contracts remains a **separate** governed program (not executed in Phase 1). |

## 11. Confusion risks still present

- **Stale rows** in status CSVs without consulting supersession.
- **Mixed `switching_canonical_S_long.csv`** — column-selective reads required.
- **Filename “canonical”** on non-canonical first stages (`PHI2_KAPPA2_HYBRID` called out in map).
- **Untracked backlog** in working tree — must not be staged blindly (per task).

## 12. Recommended next phase

**Phase 2:** Expand `switching_pre_replay_registry_contract.csv` from inventories (`switching_generated_artifact_classification.csv`, `switching_analysis_script_classification.csv`, etc.); add optional **lint** / **preflight** script (WARN-first) that reads namespace CSV and quarantine index; **do not** merge artifact families or weaken PT/CDF quarantine.

---

*Phase 1 is documentation and design only. No MATLAB execution. No modification to analysis algorithms or existing governed CSV semantics beyond adding new parallel design files listed above.*
