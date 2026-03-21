# Root Inventory Table

Last updated: 2026-03-21

| Folder | Category | Status | Snapshot Decision | Purpose |
|---|---|---|---|---|

## Category definitions

- independent experimental pipelines: Pipelines that are not part of the main unified stack, but are actively used and scientifically relevant.
| `.appdata` | local environment/system | local/noise | exclude | Local app runtime state. |
| `.codex_matlab_prefs` | local environment/system | local/noise | exclude | Local Codex/MATLAB preference cache. |
| `.codex_tmp` | local environment/system | local/noise | exclude | Temporary agent execution files. |
| `.git` | local environment/system | local/noise | exclude | Git metadata, not needed for runtime snapshots. |
| `.github` | shared infrastructure | canonical | include optionally | CI/workflow metadata for repository operations. |
| `.localappdata` | local environment/system | local/noise | exclude | Machine-local application state mirror. |
| `.matlab_pref` | local environment/system | local/noise | exclude | Local MATLAB pref directory. |
| `.matlab_prefs` | local environment/system | local/noise | exclude | Local MATLAB pref snapshots. |
| `.mwhome` | local environment/system | local/noise | exclude | Local MathWorks home/runtime state. |
| `.tmp_test` | local environment/system | local/noise | exclude | Temporary test workspace. |
| `.vscode` | local environment/system | local/noise | exclude | Editor workspace settings. |
| `AC HC MagLab ver8` | independent experimental pipelines | active (independent experimental pipeline) | include optionally | Active AC/HC MagLab analysis pipeline (`ACHC_main.m`, `ACHC_runAuto.m`). |
| `Aging` | active scientific pipeline | canonical | include always | Primary active aging pipeline and run helpers. |
| `Aging old` | legacy scientific pipeline | archive only | include only for reproducibility | Older pre-current Aging assets. |
| `analysis` | shared infrastructure | active (transitional) | include always | Cross-experiment analysis and synthesis scripts. |
| `ARPES ver1` | independent experimental pipelines | active (independent experimental pipeline) | include optionally | Active ARPES processing pipeline (`run_arpes_dual.m`, `run_arpes_json.m`). |
| `claims` | utility/tooling subsystem | active (transitional) | include optionally | Claim registry layer (`claims/*.json`, schema README). |
| `docs` | shared infrastructure | canonical | include always | Repository policy and architecture documentation. |
| `FieldSweep ver3` | independent experimental pipelines | active (independent experimental pipeline) | include optionally | Active FieldSweep pipeline (`FieldSweep_main.m`). |
| `Fitting ver1` | utility/tooling subsystem | archive only | include only for reproducibility | Legacy fitting routines and scripts. |
| `General ver2` | visualization/graphics engine | legacy but used | include only for reproducibility | Legacy shared parsing/visualization utilities; still reachable via broad path setup. |
| `github_repo` | utility/tooling subsystem | legacy but used | include optionally | Vendored external assets (colormaps and third-party utilities). |
| `GUIs` | visualization/graphics engine | active (transitional) | include optionally | Figure/annotation/export GUI stack (`FigureControlStudio`, `SmartFigureEngine`). |
| `HC ver1` | independent experimental pipelines | active (independent experimental pipeline) | include optionally | Active heat-capacity analysis pipeline (`HC_main.m`). |
| `MathWorks` | local environment/system | local/noise | exclude | Local MathWorks installer/runtime cache. |
| `MH ver1` | independent experimental pipelines | active (independent experimental pipeline) | include optionally | Active M(H) analysis pipeline (`MH_main.m`). |
| `MT ver2` | independent experimental pipelines | active (independent experimental pipeline) | include optionally | Active M(T) analysis pipeline (`MT_main.m`). |
| `PS ver4` | independent experimental pipelines | active (independent experimental pipeline) | include optionally | Active planar sweep pipeline (`PS_main.m`). |
| `Relaxation ver3` | active scientific pipeline | active (transitional) | include always | Active relaxation module with mixed legacy/main and modern diagnostics. |
| `reports` | utility/tooling subsystem | active (transitional) | include optionally | Review/report markdown outputs and summaries. |
| `Resistivity MagLab ver1` | independent experimental pipelines | active (independent experimental pipeline) | include optionally | Active resistivity MagLab workflow (`ACHC_RH_main.m`). |
| `Resistivity ver6` | independent experimental pipelines | active (independent experimental pipeline) | include optionally | Active resistivity analysis stack (`Resistivity_main.m`). |
| `results` | generated artifacts/results | active (transitional) | include optionally | Run-based output store; include only selected runs for reproducibility snapshots. |
| `runs` | shared infrastructure | canonical | include always | Operator entrypoints and wrapper scripts. |
| `surveys` | utility/tooling subsystem | active (transitional) | include optionally | Survey registry/output layer used by review tooling. |
| `Susceptibility ver1` | independent experimental pipelines | active (independent experimental pipeline) | include optionally | Active susceptibility workflow (`main_Susceptibility.m`). |
| `Switching` | active scientific pipeline | active (transitional) | include always | Active switching analysis layer. |
| `Switching ver12` | legacy scientific pipeline | legacy but used | include only for reproducibility | Legacy switching runtime still imported by active alignment audit. |
| `tests` | tests/verification | canonical | include always | Repo-level test surface. |
| `tmp` | local environment/system | local/noise | exclude | Temporary ad hoc scripts and scratch output. |
| `tmp_root_cleanup_quarantine` | local environment/system | local/noise | exclude | Quarantined temporary cleanup artifacts. |
| `tools` | shared infrastructure | canonical | include always | Shared run, figure, observables, review, and survey helpers. |
| `Tools ver1` | utility/tooling subsystem | archive only | include only for reproducibility | Legacy repo-organization helper scripts. |
| `zfAMR ver11` | independent experimental pipelines | active (independent experimental pipeline) | include optionally | Active zfAMR analysis package (`zfAMR_main.m`). |

## Coverage Check

- Total root directories classified: 44
- Classified exactly once: yes
- Source list: direct `Get-ChildItem -Directory -Force` at repository root


