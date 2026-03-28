# Run System

This document defines the strict run contract for this repository.
This contract is deterministic and validator-ready.

## 1. Scope and precedence

This contract is normative for run identity, run layout, and required run artifacts.
Rules in this document are enforced with MUST and MUST NOT language only.

## 2. Canonical run root

run_dir MUST match exactly:

results/<experiment>/runs/run_<timestamp>_<label>/

Rules:

- ALL run outputs MUST be written inside run_dir.
- NO run outputs are allowed outside run_dir.
- Writing run outputs to repo root is FORBIDDEN.
- Writing run outputs to module folders is FORBIDDEN.
- Writing run outputs to legacy result paths is FORBIDDEN.

## 3. Status artifact (mandatory)

STATUS_FILENAME is fixed:

execution_status.csv

The status file MUST:

- Exist for every run.
- Be written at run root: run_dir/execution_status.csv.
- Be ASCII only.
- Be written on success and on failure.

No alternative status filename is allowed.

execution_status.csv MUST contain exactly these columns:

1. EXECUTION_STATUS
2. INPUT_FOUND
3. ERROR_MESSAGE
4. N_T
5. MAIN_RESULT_SUMMARY

## 4. Required outputs (strict)

required_outputs is fixed and MUST be represented in run_manifest.json exactly as:

{
  "tables": ["*.csv"],
  "reports": ["*.md"],
  "status": ["execution_status.csv"]
}

Rules:

- At least one CSV file MUST exist in run_dir (placeholder allowed).
- At least one MD file MUST exist in run_dir (minimal content allowed).
- execution_status.csv MUST exist in run_dir.
- ALL required outputs MUST be inside run_dir.
- Outputs outside run_dir are FORBIDDEN.

## 5. Manifest contract (final schema)

Exactly one manifest file is allowed per run.
Manifest filename is fixed:

run_manifest.json

Manifest location is fixed:

run_dir/run_manifest.json

Secondary manifest files are FORBIDDEN.

run_manifest.json MUST include all required fields:

1. run_id
2. timestamp
3. execution_start
4. experiment
5. label
6. repo_root
7. run_dir
8. script_path
9. script_hash
10. git_commit
11. matlab_version
12. host
13. user
14. required_outputs
15. manifest_valid

Optional field:

- manifest_schema_version

No other required fields are allowed by this contract.

## 6. Wrapper to run link (only allowed mechanism)

The executed script MUST write:

run_dir_pointer.txt

run_dir_pointer.txt content MUST be exactly one absolute path string to run_dir.

Rules:

- run_dir_pointer.txt MUST be written before script termination.
- Wrapper MUST read run_dir_pointer.txt after execution.
- Wrapper run discovery MUST use only run_dir_pointer.txt.
- Guessing run_dir is FORBIDDEN.
- Directory scanning to discover run_dir is FORBIDDEN.

## 7. Fingerprint contract (locked)

Fingerprint is fixed as:

{
  git_commit,
  script_hash,
  matlab_version,
  host,
  user
}

Rules:

- Fingerprint fields MUST be computed at run start.
- Fingerprint fields MUST be stored in run_manifest.json.
- Secondary fingerprint files are FORBIDDEN.

## 8. Execution contract

A valid run MUST satisfy all requirements below.

1. Invocation
- The run MUST be executed via:
  tools/run_matlab_safe.bat "<ABSOLUTE_PATH>"

2. Runnable script format
- The runnable file MUST be a pure script.
- Function definitions in the runnable file are FORBIDDEN.
- The runnable file MUST be ASCII only.
- The runnable file MUST start with:
  clear; clc;

3. Required run-context call
- The runnable script MUST call createRunContext.

4. Mandatory artifacts
- The runnable script MUST write execution_status.csv.
- The runnable script MUST write at least one CSV file.
- The runnable script MUST write at least one MD file.

5. Prohibited behavior
- Writing run artifacts outside run_dir is FORBIDDEN.
- Silent exit without required artifacts is FORBIDDEN.

## 9. Valid run definition

A run is valid if and only if all conditions in sections 2 through 8 are true.

If any condition in sections 2 through 8 is false, the run is invalid.

## 10. Determinism and enforcement

This contract contains no optional behavior and no implementation-defined behavior.
Validator logic MUST evaluate explicit field presence, fixed filenames, fixed locations,
fixed schema members, and required artifact existence without heuristics.
