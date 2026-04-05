# FAILURE_CLASS (agent logging)



**Use:** Values for `failure_class` in `tables/agent_runs_log.csv`. **Append-only**; non-blocking.



## Calibration contract (canonical execution system)



These align with `tools/run_matlab_safe.bat`, `tools/pre_execution_guard.ps1`, `tools/validate_matlab_runnable.ps1`, and MATLAB runtime.



| Class | When | MATLAB launches? | run_dir | execution_status | Block type |

| --- | --- | --- | --- | --- | --- |

| `PRE_EXECUTION_INVALID_SCRIPT` | Missing file, not `.m`, or empty arg after resolution | NO | NO | Row in `tables/pre_execution_failure_log.csv` only | Hard pre-guard |

| `PRE_EXECUTION_VALIDATION_BLOCK` | Reserved: batch does not invoke validator. If future wiring blocks, use this label. | N/A | N/A | N/A | N/A today |

| `MATLAB_LAUNCHED_NO_SCRIPT_ENTRY` | MATLAB started but script did not run meaningfully (rare; e.g. immediate process failure before `run`) | YES | NO | None from script | Hard / opaque |

| `MATLAB_RUNTIME_ERROR` | MATLAB returned nonzero; script error after entry | YES | Maybe | Often FAILED in `run_dir` if catch ran | Non-blocking soft path |

| `PARTIAL_ARTIFACT_FAILURE` | PARTIAL status or missing secondary outputs while script ran | YES | YES | PARTIAL or FAILED | Non-blocking |

| `SUCCESS` | Script completed success path | YES | YES | SUCCESS | OK |



**Legacy agent log values** (`NONE`, `NO_MATLAB`, …) remain valid for human/agent rows; map them to the calibration table where possible.



| FAILURE_CLASS | When |

| --- | --- |

| `NONE` | Run completed; `run_valid=YES`, or successful partial checkpoint with no fault. |

| `NO_MATLAB` | Wrapper or OS could not start MATLAB or `-batch` did not run. |

| `NO_ENTRY` | Script file not entered (no script-level signals under `run_dir`). |

| `NO_RUN_DIR` | `createRunContext` or equivalent did not yield a usable `run_dir`. |

| `WRITE_PARTIAL` | `execution_status.csv` or required CSV/MD incomplete vs script contract. |

| `DATA_MISSING` | Expected inputs (paths, raw folders) absent after entry. |

| `CONFIG_ERROR` | Path resolution, `createRunContext`, or repo layout error before data work. |

| `SCIENCE_ABORT` | Reserved: logic or numerical failure after inputs present (infra agents log `UNKNOWN` unless task is science). |

| `UNKNOWN` | Unclassified; use sparingly. |



**Mapping from `execution_status.csv` (canonical columns):**



- `EXECUTION_STATUS` = `SUCCESS` and empty `ERROR_MESSAGE` -> `NONE` / `SUCCESS`.

- `EXECUTION_STATUS` = `PARTIAL` -> `NONE` unless paired with a known soft issue -> `WRITE_PARTIAL` or `DATA_MISSING` / `PARTIAL_ARTIFACT_FAILURE`.

- `EXECUTION_STATUS` = `FAILED` -> choose row by `ERROR_MESSAGE` / script stage (`CONFIG_ERROR`, `DATA_MISSING`, `NO_RUN_DIR`, else `UNKNOWN` / `MATLAB_RUNTIME_ERROR`).


