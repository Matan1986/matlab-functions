# Switching layer boundary (canonical vs legacy / root)

This document defines an **enforceable boundary** between:

1. **Canonical run data** — the single designated Switching canonical results tree.
2. **Canonical execution governance** — registered entrypoint, lock tables, and definition artifacts that describe *how* canonical runs are executed (not a substitute for run-backed outputs).
3. **Legacy / root layers** — everything else under `tables/`, `reports/`, and `Switching/analysis/` that is **not** that results tree.

Normative execution rules remain in `docs/repo_execution_rules.md` and `docs/switching_canonical_definition.md`. This file fixes **scope and authority**: what counts as canonical **physics truth** vs **reference material**.

---

## What is canonical (strict data scope)

**Canonical Switching run outputs (authoritative numerical / run-backed artifacts) live ONLY under:**

`results/switching/runs/run_2026_04_03_000147_switching_canonical/`

No other directory is the canonical **data** layer for Switching. If an artifact is not in that run folder (or copied from it with explicit provenance), it is **not** canonical run truth.

---

## What is not canonical

- **Repository root outputs** — `tables/*.csv` (and related), `reports/*.md`, and similar: indexes, audits, inventories, and narratives. These may *describe* runs; they do not **define** canonical physics outputs unless they are clearly registry/governance rows (see below).
- **Legacy Switching backend and migration artifacts** — e.g. `ver12_*` tables/reports, phase-1 migration audits, superseded drafts (`*.PARTIAL_DO_NOT_USE`), experimental runners under `Switching/analysis/experimental/`.
- **Non-entrypoint Switching analysis** — all `Switching/analysis/*.m` files **except** the single registered canonical script (see below). Helpers and secondary runners are **not** canonical entrypoints; treat as **reference or tooling**, not as “the” Switching pipeline unless explicitly invoked by policy.

---

## What is allowed for computation (agents / automation)

Per `docs/repo_execution_rules.md`:

1. **Single approved wrapper** — `tools/run_matlab_safe.bat` with an **absolute** path to **one** script.
2. **Single canonical Switching entrypoint script** — `Switching/analysis/run_switching_canonical.m`, as registered in `tables/switching_canonical_entrypoint.csv`.
3. **Run identity and outputs** — valid runs produce signaling and artifacts under a `run_dir` under `results/switching/runs/...` per repository rules. **Canonical data scope** for Switching science outputs in this boundary document is **only** the run directory named above.

Do **not** treat `Switching ver12/main/Switching_main.m`, `run_minimal_canonical.m`, or arbitrary `Switching/analysis/*.m` files as substitute entrypoints. Disallowed scripts are listed in `tables/switching_noncanonical_scripts.csv`.

---

## What is reference only

- **`tables/` and `reports/`** — Use for **registry, classification, audits, and documentation**. They are **not** executable truth and **not** a replacement for `run_dir` contents under `results/`.
- **`LEGACY_REFERENCE` rows** in `tables/switching_layer_boundary_map.csv` — Historical or non-canonical runners and migration-era docs; **read-only context**, not execution targets.
- **`ROOT_ARTIFACT` rows** — Repo-root indexes and cross-cutting logs; **operational metadata**, not canonical Switching observables.
- **`UNKNOWN` rows** — Require manual reconciliation against this document (e.g. multi-run inventories superseded by the strict canonical run path above).

Full per-file classification: **`tables/switching_layer_boundary_map.csv`**.

---

## Root layer is non-executable

**Important:** Paths under `tables/`, `reports/`, and `Switching/analysis/` are **not** MATLAB “runs” and are **not** canonical result stores. Running or interpreting CSV/Markdown in those folders as if they were **`execution_status.csv`**-backed physics outputs is **invalid**. Executable Switching work is **only** via the wrapper + registered entrypoint script, with truth for the designated canonical run coming from **`results/switching/runs/run_2026_04_03_000147_switching_canonical/`**.

---

## Related tables

| Artifact | Role |
|----------|------|
| `tables/switching_canonical_entrypoint.csv` | Sole source of truth for the canonical `.m` path |
| `tables/switching_noncanonical_scripts.csv` | Explicitly disallowed or restricted scripts |
| `tables/switching_layer_boundary_map.csv` | Per-file layer: `CANONICAL_RUN`, `LEGACY_REFERENCE`, `ROOT_ARTIFACT`, `UNKNOWN` |
