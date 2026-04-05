# Determinism audit — Switching canonical (Phase 2.3 / 2.4)

**Rules:** `docs/repo_execution_rules.md`. **No code, wrapper, or validator changes.** Two controlled MATLAB executions only.

## Controlled double run

| # | Entry | Wrapper |
| --- | --- | --- |
| 1 | `C:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m` | `tools/run_matlab_safe.bat` |
| 2 | Same | Same |

**Run IDs**

- Run A: `run_2026_04_04_143211_switching_canonical`
- Run B: `run_2026_04_04_143749_switching_canonical`

No parameters were changed between runs (same repo state, same machine session class).

## Output comparison (summary)

### Byte-identical (`fc /b`)

- `execution_status.csv`
- `tables/switching_canonical_observables.csv`
- `tables/switching_canonical_phi1.csv`
- `tables/switching_canonical_S_long.csv`
- `tables/switching_canonical_validation.csv`
- `execution_probe.csv`

### Differs only in run-scoped identity (RUN_ID / `run_dir` / timestamps)

- `run_manifest.json` — `run_id`, `timestamp`, `execution_start`, `run_dir`, and path list in `required_outputs` differ; **fingerprint-related fields match** (see below).
- `tables/run_switching_canonical_implementation_status.csv` — data columns including RMSE and verdict flags are the same; **RUN_ID** and **RUN_DIR** columns differ by design.
- `execution_probe_status.csv` — paths include the run folder name.
- `reports/run_switching_canonical_report.md` — first bullet **RUN_DIR** path differs; all listed metrics (RMSE, cosine, Spearman, counts) match.
- `reports/run_switching_canonical_implementation.md` — run-scoped paths/timestamps.
- `runtime_execution_markers.txt`, `log.txt`, `run_notes.txt`, `config_snapshot.m` — expected to differ in time or run id.

## Identity consistency

From both `run_manifest.json` files:

| Field | Match |
| --- | --- |
| `script_path` | Identical (`...\run_switching_canonical.m`) |
| `script_hash` | Identical |
| `git_commit` | Identical |
| `label` | `switching_canonical` (both) |
| `experiment` | `Switching` (both) |
| `matlab_version`, `host`, `user`, `repo_root` | Identical |
| `dataset` | `raw_switching_dat_only` (both) |

## Drift detection

- **Timestamp-only (or run-id-only) differences:** **Yes** — manifests, logs, markers, and any artifact that embeds `RUN_ID` or wall-clock time.
- **Real content differences (numerical or logical pipeline output):** **None observed** — key table CSVs and `execution_status.csv` are binary-identical between runs.

## Verdict fields

| Field | Value |
| --- | --- |
| OUTPUTS_IDENTICAL | **YES** (core execution tables + `execution_status.csv` + `execution_probe.csv` byte-identical; run-scoped metadata files differ where they must record identity) |
| MANIFEST_IDENTICAL | **NO** (full JSON differs by `run_id` / time / paths) |
| FINGERPRINT_IDENTICAL | **YES** (`script_path`, `script_hash`, `git_commit`, environment fields, `label`) |
| NON_DETERMINISM_DETECTED | **NO** (no unexplained numeric or status drift) |
| PROOF_RUN_ID | **`run_2026_04_04_143749_switching_canonical`** (second controlled replicate) |
| EXECUTION_DETERMINISTIC | **YES** |
| EXECUTION_TRUSTED | **YES** |

---

**Deliverables:** `tables/determinism_audit.csv`, `tables/determinism_status.csv`, this report.
