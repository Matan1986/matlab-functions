# Phase 4A-GATE — Policy validation (two files only)

**Scope:** `.gitignore`, `docs/switching_governance_persistence_manifest.md` only.  
**Method:** `git diff -- "<path>"` plus full-file read of those paths. No other paths opened; no repo mutation.

---

## 1. `.gitignore`

### Classification

**REQUIRE_FIX** (not `SAFE_TO_KEEP` as-is).

### Checks

| Check | Result |
|--------|--------|
| `tables/maintenance_*.csv` visibility | **Risk:** Line 91 `!tables/maintenance_*.csv` un-ignores all `tables/maintenance_*.csv`. **Lines 92–94** add explicit ignore rules for three filenames that **match** that glob. In `.gitignore`, a later matching rule typically **wins**; these lines **re-ignore** those three CSVs. |
| `reports/maintenance/**` | **Unchanged by diff.** Existing structure: `reports/**` then `!reports/maintenance/` and `!reports/maintenance/*.md`; nested ignores under `reports/maintenance/agent_outputs/**`, `logs/**`, and `status_pack_latest.md`. Maintenance markdown under `reports/maintenance/*.md` remains intended to be visible; subfolders outside `*.md` direct children may still follow `reports/**` rules—pre-existing, not part of this diff. |
| Negation overridden later | **YES — confirmed for three paths:** `tables/maintenance_artifact_atlas_locations.csv`, `tables/maintenance_artifact_writer_patterns.csv`, `tables/maintenance_findings_events.csv`. |
| Broad `tables/*` without exceptions | Pre-existing `tables/**` + layered exceptions remains broad; diff does not remove `!tables/maintenance_*.csv`. |

### Exact problematic rule(s)

```text
tables/maintenance_artifact_atlas_locations.csv
tables/maintenance_artifact_writer_patterns.csv
tables/maintenance_findings_events.csv
```

Placed **after** `!tables/maintenance_*.csv`, they override the un-ignore for those three files.

### Minimal fix (suggestion only — not applied)

**Option A (preferred):** Delete lines 92–94 if those files must remain trackable like other `maintenance_*.csv`.

**Option B:** If hiding those three is intentional, append **after** line 94 three lines that re-un-ignore (last rule wins):

```gitignore
!tables/maintenance_artifact_atlas_locations.csv
!tables/maintenance_artifact_writer_patterns.csv
!tables/maintenance_findings_events.csv
```

*(Verify spelling: third filename must match the ignore line exactly — use `maintenance_findings_events.csv` per current file.)*

### Pre-existing advisory (same file, not introduced by diff)

Line `tables/*status*` can match any table whose name contains `status`, including gate/status CSVs under `tables/` unless listed in the small `!` exceptions block. If maintenance gate CSVs must always track, consider a narrow `!tables/maintenance_*status*.csv` (policy decision outside this gate’s edit).

### Decision mapping

| Verdict option | Mapping |
|----------------|---------|
| `SAFE_TO_KEEP` | **No** — override issue above. |
| `REQUIRE_FIX` | **Yes** — resolve lines 92–94 vs `!tables/maintenance_*.csv`. |
| `SHOULD_BE_RESTORED` | **Not necessarily** — reverting the whole hunk removes the override but may not match intent if the three lines were meant to hide noise; prefer surgical Option A/B over blind `git restore`. |

---

## 2. `docs/switching_governance_persistence_manifest.md`

### Classification

**REQUIRE_FIX** (linguistic / anchoring — not `SAFE_TO_KEEP` without tightening).

### Risky or verification-dependent sentences

1. **Bullet 6** — Asserts existence of authoritative corrected-old **tables for the gated builder run** and names `tables/switching_corrected_old_authoritative_artifact_index.csv` and `tables/switching_corrected_old_authoritative_builder_status.csv`. **This gate did not open those paths**; truth is **policy-dependent on repo contents**. If either artifact is missing or stale, the sentence is false.

2. **Bullet 7** — States the **recorded** full builder run **completed successfully** “per the builder report.” **Risk:** “the builder report” is **not** given as a single concrete path here (unlike bullet 6). Success language could **overstate** closure if the gate record is conditional or partial.

3. **Bullets 6–8** overall — Correctly distinguish **authoritative tables** vs **quarantined non-authoritative** outputs (bullet 8). That separation is **sound**; the fix need is **anchoring** bullet 7, not rewriting scope.

### Minimal wording correction (surgical)

**Bullet 7 — replace vague “per the builder report”** with an explicit tie to the same gate artifact already named in bullet 6, for example:

> … **the recorded full builder run completed successfully** **as recorded in `tables/switching_corrected_old_authoritative_builder_status.csv`** (and any report row it references).

Optionally soften “completed successfully” → “**completed per the gate record**” if your governance prefers avoiding absolute success wording.

### Decision mapping

| Verdict option | Mapping |
|----------------|---------|
| `SAFE_TO_KEEP` | **No** — bullet 7 needs anchoring; bullet 6 needs external verification before treating manifest as ground truth. |
| `REQUIRE_FIX` | **Yes** — minimal edit to bullet 7 (+ human verification of cited CSVs). |
| `SHOULD_BE_RESTORED` | **No** — restoring old bullets 6–8 would reintroduce known-stale “do not exist” language superseded by governance intent; prefer surgical edit over full restore. |

---

## Final gate verdict

| Status key | Value |
|------------|-------|
| GITIGNORE_SAFE | NO |
| MANIFEST_SAFE | NO |
| FIX_REQUIRED | YES |
| SAFE_TO_PROCEED_PHASE4B | NO |

**Phase 4B** should not proceed until: **(1)** `.gitignore` lines 92–94 are reconciled with `!tables/maintenance_*.csv`, and **(2)** manifest bullet 7 is anchored (and bullets 6–8 validated against actual artifacts by a human or a later scoped audit).

---

## Success criteria (self-check)

- Only two paths inspected for content/diff: **yes**
- Zero repo mutation: **yes**
- Precise policy risks: **yes** (negation override + manifest anchoring)
- Minimal fixes: **yes** (line-level suggestions only)
