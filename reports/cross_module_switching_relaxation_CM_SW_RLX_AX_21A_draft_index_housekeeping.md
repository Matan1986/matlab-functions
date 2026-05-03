# CM-SW-RLX-AX-21A — Draft AX index housekeeping audit

**Audit-only.** No edits to `docs/cross_module_switching_relaxation_AX_index.md`, `docs/cross_module_switching_relaxation_AX_index_draft.md`, or scientific artifacts.

## Git gate

- **`git diff --cached --name-only`:** **empty** (proceeded).

## Findings

### 1. Files

| File | Exists | Git |
|------|--------|-----|
| **`docs/cross_module_switching_relaxation_AX_index.md`** (canonical) | **Yes** | **Tracked**, clean vs `HEAD` (no line in `git status --short` for this path) |
| **`docs/cross_module_switching_relaxation_AX_index_draft.md`** | **Yes** | **Tracked**, **modified** (`M` in `git status --short`) — **local uncommitted changes** relative to last commit |

### 2. High-level comparison

- **Canonical** (`…_AX_index.md`): Full governance index **plus** **CM-SW-RLX-AX-20A** manuscript-evidence section (paths, classification, forbidden wording list), P0/P1 tables, machine-readable index list, etc.
- **Draft** (`…_AX_index_draft.md`): **Short stub** (~30 lines). **Line 3** explicitly tells readers to prefer **`docs/cross_module_switching_relaxation_AX_index.md`**. Overlaps **P0 family table** at a coarse level with canonical but **does not** duplicate the AX-20A synthesis block.

### 3. Staleness / duplication / contradiction

- **Duplicate of canonical?** **No** — draft is a **subset / pointer shell**, not a second full index.
- **Stale?** **Partially** — committed draft may lag canonical feature set (no AX-20A table in draft body); that is **acceptable** if the pointer is honored. **Risk:** the working-tree **`M`** state means the draft may **differ** from `HEAD`; editors should **`git diff docs/..._AX_index_draft.md`** before assuming what is on `main`.
- **Unique useful content?** **Yes** — explicit **“prefer official index”** navigation and **Relaxation-only neighbors** reminder (still useful).
- **Contradict canonical AX result?** **No** — draft does **not** assert scaling conclusions; it routes away from itself.
- **Forbidden wording in draft?** **No** matches for physical scaling law, universal exponent, mechanism proof, invD replaces X_eff, all scaling ruled out, Aging/tau/KWW (case-insensitive grep).

### 4. Canonical index — AX result present

Confirmed in canonical file body: **`EMPIRICAL_INVD_POWERLIKE_SCALING`**, **`invD = 1/(w*S_peak)`**, **alpha ≈ 0.56** with numeric alphas, **`PHYSICAL_SCALING_LAW_ESTABLISHED`:** **`NO`**, bounded roles and **forbidden extensions** list (no physical law / universal exponent / etc.).

### 5. Drift / confusion risk

- **Low–medium:** Two filenames are similar; **mitigated** by draft’s first navigation line. **Elevated** only if someone **ignores** that line or **commits** draft changes without reconciling to canonical.
- **Do not delete or rename** the draft (per task).

## Recommendations (describe only; not executed here)

1. **Leave draft as-is** at repo policy level (stub + pointer is valid).
2. **Review** `git diff docs/cross_module_switching_relaxation_AX_index_draft.md` locally: if **`M`** is accidental, **discard** or **commit** intentionally in a **separate docs** change — **not** part of this audit execution.
3. Optional tiny future edit (only if you open a follow-up): add one line at top of draft “Last reviewed CM-SW-RLX-AX-21A” — **not applied** in this task.

## Outputs

- This report: `reports/cross_module_switching_relaxation_CM_SW_RLX_AX_21A_draft_index_housekeeping.md`
- Table: `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_21A_draft_index_housekeeping.csv`
- Status: `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_21A_status.csv`

**END**
