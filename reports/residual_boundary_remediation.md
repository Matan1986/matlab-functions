# Phase 1.7 — Residual boundary remediation (Switching canonical)

**Rules followed:** Scope limited to the **four** Phase 1.6 residual boundary blockers; no validator/wrapper changes; no Phase 2 execution; no scientific analysis; no remediation of `REPO_TABLES_FALLBACK_WRITE` or deferred `tools/*` items.

**Baseline reference:** `HEAD` before remediation was **`e1506a4`** (`repo: cleanup + canonical stabilization`). **Remediation commit:** **`bfee3be`** — adds `Switching/analysis/run_switching_canonical.m` and `tools/write_execution_marker.m` only.

---

## 1. Remediation decision table (one action per blocker)

| Blocker | Decision | Rationale (canonical-boundary truth) |
|---------|----------|--------------------------------------|
| `Switching/analysis/run_switching_canonical.m` | **MUST_COMMIT_AS_BASELINE** | Registry/closure identifies this as the sole Switching runner; it had **no** `HEAD` blob—**MUST_TRACK** alone does not create a reproducible baseline; **commit** establishes the accepted baseline. |
| `tools/write_execution_marker.m` | **MUST_COMMIT_AS_BASELINE** | On the static closure path from the runner; same committed-baseline gap; committed **in the same commit** as the runner (minimal surface). |
| `Aging/utils/createRunContext.m` | **MUST_RESTORE** | Phase 1.6: **modified vs HEAD** = unreviewed drift on a **CANONICAL_REQUIRED** closure file; minimal fix is **align to `HEAD`**, not expand scope. |
| `Switching ver12/main/Switching_main.m` | **MUST_RESTORE** | Same: drift on closure **EXTERNAL_INPUT**; **restore to `HEAD`** aligns the fileread donor with the frozen baseline. |

**Not used:** `MUST_REMOVE_FROM_CLOSURE` — no blocker required shrinking the documented closure.

---

## 2. Exact actions executed

| Step | Action |
|------|--------|
| 1 | Restored **`Switching ver12/main/Switching_main.m`** to match **`HEAD`** (`git restore` / `git checkout HEAD --`). |
| 2 | Restored **`Aging/utils/createRunContext.m`** toward **`HEAD`**; where the index/working tree still reported modified with **empty textual diff** (EOL / stat cache), ran **`git add Aging/utils/createRunContext.m`** so the index matches **`HEAD`** with no net staged patch vs **`e1506a4**` content. |
| 3 | Staged **`Switching/analysis/run_switching_canonical.m`** and **`tools/write_execution_marker.m`** only. |
| 4 | Committed: **`bfee3be`** — *Phase 1.7: track canonical Switching runner and write_execution_marker closure* (2 files, +761 lines). |

---

## 3. Exact files changed (by this phase)

- **New in git (committed):** `Switching/analysis/run_switching_canonical.m`, `tools/write_execution_marker.m`
- **Restored / index-normalized to baseline:** `Aging/utils/createRunContext.m`, `Switching ver12/main/Switching_main.m` (no remaining diff vs pre-remediation **`HEAD`** for those paths; see verification below)

---

## 4. Post-remediation verification (per blocker)

| Blocker | Final state | Differs from accepted baseline? | Still blocks boundary cleanliness? |
|---------|-------------|-----------------------------------|-------------------------------------|
| `run_switching_canonical.m` | Tracked at **`bfee3be`** | No (defines new baseline) | No |
| `write_execution_marker.m` | Tracked at **`bfee3be`** | No | No |
| `createRunContext.m` | Matches **`HEAD`** content (`e1506a4` for that path) | No | No |
| `Switching_main.m` | Matches **`HEAD`** content | No | No |

Verification command used (four paths only): `git status --short` and `git diff HEAD` on each path — **clean**.

---

## 5. Intentionally not touched (non-blocking per Phase 1.6)

- **`REPO_TABLES_FALLBACK_WRITE`** — documented violation on `write_execution_marker.m` behavior; **not** remediated in this phase.
- **Deferred `tools/*`** (MEDIUM automation risk) — **not** modified.
- **Other modified/deleted/untracked paths** elsewhere in the repo — **out of scope** for Phase 1.7; full working tree may still be dirty.

---

## 6. Gate decision

| Metric | Value |
|--------|-------|
| `RESIDUAL_BOUNDARY_BLOCKERS_PRESENT` | **NO** |
| `ALL_BLOCKERS_REMEDIATED` | **YES** |
| `CANONICAL_SCOPE_CLEAN_NOW` | **YES** (for the **four** blocker paths vs `HEAD` after **`bfee3be`**) |
| `READY_FOR_PHASE_2` | **YES** (for proceeding past the **Phase 1.6 residual committed-baseline** gate; governance/policy items remain documented separately) |

**Recommendation:** **Move to Phase 2** under the definition that Phase 1.7 only gated the **four** residual blockers. If Phase 2 also requires a **fully clean** full-repo working tree or remediation of **`REPO_TABLES_FALLBACK_WRITE`**, treat those as **separate** gates.

---

## 7. Machine-readable status

See `tables/residual_boundary_remediation_status.csv`.
