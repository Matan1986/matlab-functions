# SW-ID-RESOLVER-F01C — Switching identity doc/status alignment

Date: 2026-05-06  
Stage: F01C (documentation/status alignment only)  
Policy baseline: F01B (`47e1047`)

## Scope executed

Updated only:
- `docs/project_control_board.md`
- `tables/project_workstream_status.csv` (Switching row only)
- This F01C report + two maintenance CSV artifacts

No `.gitignore`, no `tables/switching_canonical_identity.csv`, no resolver/code changes.

## What was aligned

1. **Authoritative nomination source is explicit**
   - `analysis/knowledge/run_registry.csv` (`canonical_identity_anchor` row) is now stated as the authoritative nomination source for canonical Switching identity.

2. **Identity CSV role is deconflicted**
   - `tables/switching_canonical_identity.csv` is explicitly described as:
     - possibly present on local disk,
     - intended to become a tracked governance mirror in F01D,
     - not equivalent to portable/tracked truth before F01D.

3. **Conflict precedence is explicit**
   - If future tracked mirror conflicts with registry anchor, **registry anchor wins**.

4. **Canonical fallback language corrected**
   - Latest/newest-by-mtime fallback is explicitly documented as **not canonical** and deferred for implementation enforcement to F01E.

5. **Workstream contradiction removed**
   - Switching workstream blocker text no longer says identity is simply "missing"; it now distinguishes:
     - registry anchor exists,
     - local mirror may exist but is not portable until F01D,
     - silent mtime fallback cannot support canonical claims and must be handled in F01E.

## Deferred by design

- **F01D** remains required (`.gitignore` exception + tracked mirror portability).
- **F01E** remains required (resolver/caller semantics and fail-closed/advisory behavior enforcement).

## Outcome

F01C achieved policy-language consistency across the control board and Switching workstream status row without changing implementation or tracking policy.