# CM-SW-RLX-AX-20D-PRE — Inspection of `scripts/run_cm_sw_rlx_ax_18c_t_scaling_baseline.mjs`

**Inspection-only.** Script **not** modified and **not** executed.

## Git gate

- **`git diff --cached --name-only`:** **empty** at audit time (safe to continue inspection).

## Target file

| Property | Value |
|----------|-------|
| **Path** | `scripts/run_cm_sw_rlx_ax_18c_t_scaling_baseline.mjs` |
| **Exists** | **Yes** |
| **Git status** | **Untracked** (`??`) |
| **Naming** | Matches CM-SW-RLX-AX-18C audit naming; **not** a scratch/temporary filename |

## Verdict summary

| Decision | Value |
|----------|-------|
| **Actual AX-18C producer** | **Yes** — header identifies AX-18C; writes all seven expected AX-18C artifacts under `reports/` and `tables/` |
| **Temporary / debug / scratch** | **No** — structured computation + CSV/report emission only |
| **Scope** | AX-18C T-function and empirical scaling baseline only (no full AX, no figures, no reconstruction runners invoked) |
| **Destructive operations** | **No** `unlink`, `rm`, `git`, shell subprocesses — only **`fs.writeFileSync`** to known paths (**overwrites** outputs when run; normal for a producer) |
| **Absolute hardcoded paths** | **None** — **`REPO = path.resolve(__dirname, "..")`** |
| **Interactive prompts** | **None** |
| **Git commands** | **None** |
| **Inputs** | **Primary:** `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_17B_visual_dataset.csv` only (read fully). **Secondary:** `fs.existsSync` on XEFF width audit paths **only** to set status flag `USED_XEFF_WIDTH_AUDIT_18` — **does not** parse Aging/tau/KWW data |
| **Outputs** | Exactly the seven paths enumerated in the task (see script lines ~549–693, ~696–750) |

## Caveats (non-blocking)

1. **CSV parsing** — Simple comma-split `parseCsv` (no full RFC 4180 quoting). Adequate if **AX-17B** export has no embedded commas in fields; if that changes, parsing could mis-align columns (**medium** maintainability risk, not a security issue).
2. **Producer overwrite** — Running the script **overwrites** the seven AX-18C artifacts (expected).

## Recommendation

- **`INCLUDE_SCRIPT_IN_COMMIT`:** **YES**
- **`SAFE_TO_STAGE_SCRIPT`:** **YES** (script path is **not** gitignored — use plain `git add`, not `-f`)
- **`REPRODUCIBILITY_VALUE`:** **HIGH**

**Staging (single path):**

```bat
git add "scripts/run_cm_sw_rlx_ax_18c_t_scaling_baseline.mjs"
```

## Tables

- Row-level checks: `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20D_PRE_script_inspection.csv`
- Machine-readable status: `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20D_PRE_status.csv`

**END**
