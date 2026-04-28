# Maintenance Status Pack

## Purpose

This workflow reduces repeated copy/paste during repo-maintenance conversations.

Instead of manually pasting many commands such as `git status`, `git log`, snapshot checks, and file lists, run one local script and paste one generated Markdown report.

## Script

```powershell
powershell -ExecutionPolicy Bypass -File scripts/maintenance_status_pack.ps1
```

Generated artifacts:

- `reports/maintenance/status_pack_latest.md`
- `tables/maintenance_status_pack.csv`

## What it does

The script is local and lightweight. It:

- reads current Git branch and recent commits
- reads `git status --short`
- groups changed/untracked files by rough workstream
- performs lightweight snapshot ZIP open checks only
- writes a compact Markdown handoff report
- writes a CSV table of changed/untracked files

## What it does not do

It does not:

- run MATLAB
- rebuild snapshots
- modify tracked source files other than its two generated report/table artifacts
- run `git add`, `git commit`, or `git push`
- delete files
- enumerate large ZIP contents

## Intended chat workflow

1. Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/maintenance_status_pack.ps1
```

2. Paste:

```text
reports/maintenance/status_pack_latest.md
```

3. Ask for a commit plan / triage / next action.

## Notes

The snapshot check is intentionally shallow. It verifies product existence and lightweight ZIP open/readability, but does not inspect ZIP entries. This avoids the long timeouts that previously caused false unreadable classifications.
