# SW-ID-RESOLVER-F01A — Switching canonical identity / source-of-truth audit

**Date:** 2026-05-04 (audit run)  
**Scope:** Switching identity governance only (F01 from `MAINT-FINDINGS-TRIAGE-01`).  
**Mode:** Read-only; no modification to existing repository files; no `tables/switching_canonical_identity.csv` edits.

## 1. Executive answer

| Question | Result (this worktree) |
|----------|-------------------------|
| Does `tables/switching_canonical_identity.csv` exist on disk? | **Yes** — file found; `CANONICAL_RUN_ID` = `run_2026_04_03_000147_switching_canonical`, `STATUS` = `LOCKED`. |
| Is it version-controlled? | **No** — not in the git index; path is **gitignored** by the broad `tables/**` rule (see `.gitignore` with only selective `!tables/maintenance_*.csv` un-ignore). |
| Is the reported F01 “conflict” real? | **Yes** — at least **three interlocking layers**: (A) **documentation vs workstream** claims about “present” vs “missing,” (B) **git policy** (generated/ignored `tables/*.csv` vs a file that must anchor identity in every clone), (C) **implementation** in `switchingResolveLatestCanonicalTable` that is **identity-first when the file exists** and **newest-mtime among `run_*_switching_canonical` when the file is missing or the anchored path is missing/invalid**. |

## 2. Authoritative artifacts (for this question)

- **Run registry anchor (tracked):** `analysis/knowledge/run_registry.csv` includes `run_2026_04_03_000147_switching_canonical` with role `canonical_identity_anchor` (row observed in audit).
- **Module status (tracked):** `tables/module_canonical_status.csv` — Switching is `CANONICAL` with `CANONICAL_RUN_IDENTITY=YES` (not a per-file pointer to `switching_canonical_identity.csv`).
- **Operational gate (tracked):** `docs/project_control_board.md` — states `tables/switching_canonical_identity.csv` is **present** but warns consumers must not treat newest-mtime or repo-root mirrors as truth.
- **Workstream row (tracked):** `tables/project_workstream_status.csv` — Switching workstream `primary_blocker` text says the **authoritative reference to `tables/switching_canonical_identity.csv` is downgraded because the file is missing** (contradicts “present” in a typical local dev tree where the file exists; aligns with a **no-file-in-git / clean-clone** reading of “missing”).
- **Identity table (local, not tracked):** `tables/switching_canonical_identity.csv` — small key/value table; **not** in `git ls-files` in this worktree; `git check-ignore` attributes it to `tables/**`.
- **Resolver (tracked code):** `Switching/utils/switchingResolveLatestCanonicalTable.m` — implements **locked run-root path** when identity file + anchored artifact exist; otherwise **warnings + mtime** among matching run directories.

## 3. Identity modes implied by the repo today

| Mode | Where | When it applies |
|------|--------|------------------|
| **Locked identity (run-root)** | Identity CSV + `results/switching/runs/<CANONICAL_RUN_ID>/tables/<file>` | Resolver uses this when identity file exists and the anchored file exists under the locked run id. |
| **Latest-resolution (mtime)** | Same resolver fallback | When identity file missing, malformed, missing `CANONICAL_RUN_ID`, empty id, or anchored artifact missing — **newest** `run_*_switching_canonical` wins among paths that contain the target filename. |
| **Registry anchor (discovery)** | `analysis/knowledge/run_registry.csv` | Declares which run is the canonical identity anchor; does not by itself replace the identity CSV for resolver path logic. |
| **Corrected-old manuscript authority** | `tables/switching_corrected_old_authoritative_artifact_index.csv`, builder status, reader hub | **Separate** namespace from “which run id resolves `switching_canonical_S_long.csv` for diagnostics” — manuscript claims route through **CORRECTED_CANONICAL_OLD_ANALYSIS** artifacts; still must not be conflated silently with resolver fallback behavior. |

## 4. Exact contradiction

1. **`docs/project_control_board.md`** asserts the identity CSV **is present** (and warns about mtime/mirrors).  
2. **`tables/project_workstream_status.csv`** states the authoritative reference is **downgraded because the file is missing.**  
3. In **this** worktree the file **exists**, so (1) and (2) **contradict** unless “missing” is interpreted as **missing from git / absent after clone / governance downgrade**, not “absent from disk here.”  
4. **Git policy:** the identity table path matches **`tables/**` ignore** and is **not** listed in `git ls-files`, so **fresh clones** will not carry it unless generated or force-added — matching steward/agents seeing **no identity file** while docs say “present.”  
5. **Implementation:** when the file is absent, **`switchingResolveLatestCanonicalTable`** explicitly falls back to **mtime**, which can diverge from the **locked** run id in the registry — the steward-reported conflict (**SAS_SOURCE_009**).

**Contradiction type (classification):** **All of the below:**  
- **Documentation / status-table contradiction** (control board vs workstream wording and staleness).  
- **Missing portable source-of-truth artifact** at the **git** layer (ignored/untracked identity CSV).  
- **Resolver behavior conflict** (silent mtime substitution vs locked-run narrative).

## 5. Decision needed before broad output-path fixes (F02)

Owners must agree on **one** coherent story:

- Whether **`tables/switching_canonical_identity.csv`** is **generated-only**, **tracked canonical metadata**, or **both** with a defined regeneration contract; and  
- Whether **mtime fallback** remains **allowed**, **warn-only**, or **disallowed** for “canonical-looking” consumers; and  
- How **`project_workstream_status.csv`** should describe **missing** (filesystem vs index vs clone).

No single artifact currently reconciles **clone reproducibility**, **docs**, and **resolver** without explicit decision.

## 6. Deliverables from this audit

- `tables/maintenance_switching_identity_resolver_F01A_evidence.csv` — per-artifact claims and conflict roles.  
- `tables/maintenance_switching_identity_resolver_F01A_options.csv` — options for **F01B** (no policy lock-in here).  
- `tables/maintenance_switching_identity_resolver_F01A_status.csv` — task flags.

## 7. References read for this audit

Includes: triage artifacts (`reports/maintenance/maintenance_findings_triage_01.md`, `tables/maintenance_findings_triage_01_deduped_families.csv`, `tables/maintenance_findings_triage_01_action_plan.csv`), `docs/project_control_board.md`, `tables/project_workstream_status.csv`, `tables/module_canonical_status.csv`, `docs/switching_canonical_reader_hub.md`, `docs/switching_governance_persistence_manifest.md`, `reports/switching_corrected_canonical_current_state.md`, `docs/decisions/switching_main_narrative_namespace_decision.md`, `.gitignore`, `tables/switching_canonical_identity.csv`, `Switching/utils/switchingResolveLatestCanonicalTable.m`, `analysis/knowledge/run_registry.csv`, plus targeted grep for resolver usage.
