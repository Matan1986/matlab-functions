# Topology refinement (Phase 5A.1 FIX)

**Source of truth:** `tables/repo_topology_map.csv` only (no filesystem rescan, no new paths).

## What changed from the original map

- **Classification vocabulary** replaced loose `INFRASTRUCTURE` with **`INFRA_RUNTIME`** vs **`INFRA_ENV`**, split former **`MODULE`** into true **`MODULE`** (Switching, Aging, Relaxation and their system-critical subtrees) vs **`ANALYSIS`** (other experiment version trees and cross-cutting analysis), and introduced **`SCRIPT`** for the root `scripts` tree.
- **`MIXED` reduced** to **only** the repository root (`.`); former `runs` and `surveys` were reassigned to **`INFRA_RUNTIME`** and **`ANALYSIS`** respectively.
- **New columns:** `relevance` (HIGH / MEDIUM / LOW) and `candidate_for_deep_dive` (YES / NO) for Phase 5 prioritization.
- **Notes shortened** to **3–6 words** each, naming role and rationale tersely.

## Where classification improved

| Area | Change |
|------|--------|
| Execution vs environment | `tools`, `templates`, `tests`, `runs` → **`INFRA_RUNTIME`**; caches, prefs, `tmp*`, editor dirs → **`INFRA_ENV`**. |
| Domain systems | Only **Switching**, **Aging**, **Relaxation** (plus **`Switching ver12`**, **`Switching/utils`**, **`Aging/utils`**) remain **`MODULE`** where they represent core domain systems or canonical wiring. |
| Experiment trees | Former blanket `MODULE` rows (e.g. `ARPES ver1`, `Resistivity ver6`, `zfAMR ver11`) → **`ANALYSIS`**. |
| `scripts` | **`SCRIPT`** — standalone scripts, not a full “system”. |
| `Switching/analysis` | **`ANALYSIS`** — runnable analyses under the Switching module (pipeline visibility without merging into `MODULE`). |
| `surveys` | **`ANALYSIS`** — avoids MIXED; residual ambiguity called out below. |
| Root | **`.`** stays **`MIXED`** as the only unavoidable aggregate. |

## Remaining ambiguities

- **`github_repo`:** Stays **`UNKNOWN`**; purpose not inferable from path alone.
- **`surveys`:** Classified as **`ANALYSIS`**; could include tooling vs outputs; no deeper split without new paths.
- **`Tools ver1` vs `tools`:** Lowercase **`tools`** is **`INFRA_RUNTIME`**; spaced **`Tools ver1`** is legacy experiment-style **`ANALYSIS`** to reflect naming parallel to other `* ver*` trees.

## Is this ready for Phase 5B?

**Yes.** The refined map is decision-usable: infra split, domain cores flagged, canonical-adjacent zones (`tables`, `claims`, `docs`, `status`, `templates`, `tools`, `runs`) marked **HIGH** relevance and **`candidate_for_deep_dive`** where appropriate, with **MIXED** minimized to the root.

**Artifacts**

- `tables/repo_topology_map_refined.csv`
- `tables/repo_topology_refined_status.csv`
