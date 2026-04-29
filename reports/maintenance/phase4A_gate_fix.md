# Phase 4A-GATE-FIX — surgical policy fix

**Files modified:** exactly two — `.gitignore`, `docs/switching_governance_persistence_manifest.md`.  
**No other content files touched** (this report and `tables/maintenance_phase4A_gate_fix_status.csv` are new deliverables from this step).

---

## `.gitignore`

### Removed (lines deleted)

These three lines immediately after `!tables/maintenance_*.csv` **re-ignored** filenames that already matched `maintenance_*.csv`:

```text
tables/maintenance_artifact_atlas_locations.csv
tables/maintenance_artifact_writer_patterns.csv
tables/maintenance_findings_events.csv
```

### Added

After `tables/*cleanup_debug*` and **after** the entire block of broad `tables/*` guards (including `tables/*status*`, `tables/*summary*`, `tables/*_log*`), one **re-assertion**:

```text
# Broad table/* guards above must not hide tables/maintenance_*.csv (re-assert after later patterns).
!tables/maintenance_*.csv
```

This matches the user’s **Option B** intent for patterns that would otherwise override the first `!tables/maintenance_*.csv`: no later rule wins over paths matching `tables/maintenance_*.csv` without being undone again.

### Note on requested literal patterns

The task text listed removing `tables/maintenance_*status.csv` etc.; those lines **do not exist** in this repo. The overrides that existed were the three **explicit** CSV paths above; broad overrides came from `tables/*status*`, `tables/*summary*`, `tables/*_log*`, which are addressed by the **trailing** `!tables/maintenance_*.csv`.

### Confirmation

Only the `.gitignore` sections described above were edited; no unrelated lines changed outside these hunks.

---

## `docs/switching_governance_persistence_manifest.md`

### Bullet 7 — before

```text
7. **Additional** corrected-old rebuilds or replays remain subject to explicit authorization and `tables/switching_corrected_old_replay_input_contract.csv` — the **recorded** full builder run completed successfully per the builder report. *(Supersedes blanket “build blocked” language referring to pre-authoritative state.)*
```

### Bullet 7 — after

```text
7. **Additional** corrected-old rebuilds or replays remain subject to explicit authorization and `tables/switching_corrected_old_replay_input_contract.csv` — the **recorded** full builder run completed successfully **as reflected in** `tables/switching_corrected_old_authoritative_builder_status.csv`. *(Supersedes blanket “build blocked” language referring to pre-authoritative state.)*
```

**Change:** Replaced vague **“per the builder report”** with explicit gate artifact **`tables/switching_corrected_old_authoritative_builder_status.csv`**, with minimal softening **“as reflected in”** (no new factual claims).

### Confirmation

No other bullets or sections were modified.

---

## Verdict file

See `tables/maintenance_phase4A_gate_fix_status.csv`.
