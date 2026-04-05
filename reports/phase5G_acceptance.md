# Phase 5G Acceptance Check — Final Report

**Date:** 2026-04-05  
**Scope:** Review of Phase 5G generated contracts  
**Reference:** Phase 5F validation results + system implementation  

---

## Executive Summary

**PHASE_5G_ACCEPTED = NO (with caveats)**

The Phase 5G contracts accurately capture the core canonical behavior but contain **three specific issues** that affect minimality and precision:

1. **Artifact contract clauses overstate enforcement level**
2. **Checkpoint PARTIAL rule has inverted required/enforced flags** (critical, systematic error)
3. **Onboarding artifact rules lack clarity on pattern vs. enforcement**

All three issues are **correctible without rescoping Phase 5G logic**. The core contract structure is sound.

---

## VERDICT DETAILS

### 1. CONTRACTS_ACCURATE

**Status: MOSTLY YES, with 1 systematic error**

#### Accurate Claims:
- ✅ Execution contract (createSwitchingRunContext → createRunContext allocation)
- ✅ Manifest/fingerprint creation and immutability
- ✅ Final status enforcement (SUCCESS/FAILED only)
- ✅ Failure path allocation and FAILED write
- ✅ Detection contract classification signals
- ✅ Entrypoint identity definition
- ✅ Onboarding pattern structure (5 steps)

#### Inaccurate Claim:
- ❌ **Checkpoint PARTIAL enforcement rule:**
  ```
  "Non-final checkpoints use EXECUTION_STATUS=PARTIAL only"
  required=NO, enforced=YES
  ```
  **PROBLEM:** The flags are **inverted**. The writer function explicitly enforces this:
  ```matlab
  if ~isFinal
      if ~strcmp(es, 'PARTIAL')
          error('writeSwitchingExecutionStatus:CheckpointNotPartial', ...
  ```
  **VERDICT:** This is required AND enforced. Flags should be: `required=YES, enforced=YES`.

#### Phase 5F Alignment:
- ✅ Contracts correctly reflect Phase 5F run-scoped isolation
- ✅ No contradiction with validation results (markers only under run_dir)
- ✅ Manifest behavior unchanged from Phase 5F

---

### 2. CONTRACTS_MINIMAL

**Status: NO**

Two artifact contract clauses are **overdesigned** relative to actual enforcement:

#### Clause 1: "Valid artifact: file written inside run_dir for the active canonical run"
```
required=YES, enforced=NO
notes: "Path discipline is implemented by current entrypoint/helper usage; no global filesystem guard"
```

**Assessment:** This is correctly flagged as not globally enforced, but marking it `required=YES` is **aspirational**, not binding. Reality:
- Helper-based enforcement only (when `createRunContext` is used)
- Non-canonical paths can bypass this
- Contract is pattern-based, not system-enforced

**Verdict:** Should be either:
- `required=NO, enforced=NO` (if describing permission)
- OR moved to **Onboarding section** (where pattern requirements belong)

#### Clause 2: "Forbidden: writes outside active run_dir as canonical outputs"  
```
required=YES, enforced=NO
notes: "Phase 5F removed marker fallback global write; contract remains run-scoped"
```

**Assessment:** Phase 5F DID remove the fallback path in `write_execution_marker`, **but this is not a global prohibition**. Reality:
- Phase 5F fixed **observability/marker** behavior (write_execution_marker no longer uses `tables/` fallback)
- No script currently writes other artifacts outside run_dir
- The rule is a **consequence of helper design**, not a hard safety property

**Verdict:** This clause conflates two concerns:
1. **Helper design** (write_execution_marker now run-scoped) — achieved ✓
2. **Global prohibition** (no script can write outside) — not enforced ✗

Should note: "Phase 5F removes marker fallback; canonical outputs are run-scoped under current helper usage."

#### Overall Minimality Verdict:
The Execution, Detection, and Entrypoint contracts are minimal and necessary. The two Artifact clauses above add complexity without enforcement scope. They should be **clarified or relocated to Onboarding** where pattern-based requirements belong.

---

### 3. CONTRACTS_CONSISTENT

**Status: MOSTLY YES, minor ambiguity**

#### Consistent with Phase 5F:
- ✅ Run-scoped isolation achieved (markers in run_dir, no fallback)
- ✅ No contradictions with validated marker behavior
- ✅ Manifest and fingerprint structure unchanged
- ✅ Detection classification remains post-hoc and non-blocking

#### Consistent with run_validity behavior:
- ✅ Classification signals match writeRunValidityClassification function
- ✅ Enforcement_checked and modules_used flags correctly represented
- ✅ INVALID/NON_CANONICAL/CANONICAL states accurately described

#### Minor Ambiguity:
The Entrypoint contract states:
```
"Canonical identity is defined by designated canonical entrypoint execution, 
not by filename/location heuristics alone"
required=YES, enforced=NO
```

**Issue:** This is **partially enforced** at detection time:
- `writeRunValidityClassification` checks if `createRunContext` resolved correctly
- It verfies `enforcement_checked=true`
- But the script can still run without these checks; detection is post-hoc

**Verdict:** **Consistent but understated**. The contract should note: "Canonical identity is verified at detection time through entrypoint signal resolution, not blocked at execution time."

---

### 4. ONBOARDING_USABLE

**Status: MOSTLY YES**

#### Can a new canonical module be created from this spec?

**YES, but with caveats:**

**Steps from contract are clear:**
1. ✅ Create entrypoint script in module
2. ✅ Call createRunContext (or wrapper) before outputs
3. ✅ Write final status via module status writer
4. ✅ Produce run-scoped tables/reports/manifest
5. ✅ Call validity classification after status write

**Mandatory steps identified in contract?**
- ✅ createRunContext allocation (before manifest writes) — CLEAR
- ✅ execution_status.csv final write — CLEAR
- ✅ Manifest/fingerprint baseline — CLEAR
- ✅ validity classification — CLEAR (post-hoc, non-blocking)

**Missing mandatory step:**
- ⚠️ **Status writer implementation** is implied but not specified

The contract references:
- "module status writer" (generic)
- But doesn't require the writer to follow `writeSwitchingExecutionStatus` schema

**Verdict:** Onboarding is usable but **incomplete**:
- A new module could be created following the 5-step pattern
- But they would need to **invent their own status writer** or copy `writeSwitchingExecutionStatus`
- Contract should specify: "Use the schema from writeSwitchingExecutionStatus: EXECUTION_STATUS (PARTIAL/SUCCESS/FAILED), INPUT_FOUND, ERROR_MESSAGE, N_T, MAIN_RESULT_SUMMARY"

---

## DETAILED FINDINGS BY CLAUSE

### Artifact Contract — Problematic Clauses

**ROW 14:** "Valid artifact: file written inside run_dir for the active canonical run"
```
PROBLEM: required=YES but enforced=NO is contradictory
LOCATION: Artifact contract
IMPACT: Misleads that this is a hard requirement
ACTION: Move to Onboarding section OR mark required=NO
```

**ROW 15:** "Forbidden: writes outside active run_dir as canonical outputs"
```
PROBLEM: Conflates Phase 5F fix (marker fallback) with global prohibition
LOCATION: Artifact contract  
IMPACT: Makes contract appear more restrictive than implementations
ACTION: Clarify as pattern-based via helper design, not global guard
```

### Execution Contract — Systematic Error

**ROW 4:** "Non-final checkpoints use EXECUTION_STATUS=PARTIAL only"
```
PROBLEM: required=NO but enforced=YES (inverted flags)
EVIDENCE: writeSwitchingExecutionStatus throws error if non-final ≠ PARTIAL
ACTION: Change to required=YES, enforced=YES
SEVERITY: Critical (systematic mislabeling)
```

### Onboarding Contract — Incompleteness

**ROW 22-25:** (Onboarding artifact requirements)
```
PROBLEM: References "module status writer" without schema requirement
IMPACT: New module developer must reverse-engineer schema from example
ACTION: Add: "Status writer must enforce writeSwitchingExecutionStatus schema"
```

---

## PRECISE CORRECTIONS NEEDED

### Correction 1: CSV Row 4
**Current:** `"Non-final checkpoints use EXECUTION_STATUS=PARTIAL only","NO","YES","..."`  
**Corrected:** `"Non-final checkpoints use EXECUTION_STATUS=PARTIAL only","YES","YES","..."`

### Correction 2: CSV Row 14  
**Current:** `"Valid artifact: file written inside run_dir for the active canonical run","YES","NO","..."`  
**Action:** Either relocate to Onboarding section OR change required to NO with clarification that this is helper-based pattern enforcement.

### Correction 3: CSV Row 15
**Current:** `"Forbidden: writes outside active run_dir as canonical outputs","YES","NO","..."`  
**Action:** Add note clarifying Phase 5F removed marker fallback; contract is pattern-based via helper design, not globally enforced.

### Correction 4: Markdown Onboarding Section (5. Minimal Onboarding Contract)
**Add after Step 4:** 
```
5b. Status writer schema
- Status writer must enforce five-column schema: 
  EXECUTION_STATUS, INPUT_FOUND, ERROR_MESSAGE, N_T, MAIN_RESULT_SUMMARY
- Reference implementation: writeSwitchingExecutionStatus in Switching/utils/
```

---

## QUALITY ASSESSMENT

| Aspect | Status | Evidence |
|--------|--------|----------|
| Core logic sound | ✅ YES | Execution, Detection, Entrypoint contracts are clean |
| No contradictions with Phase 5F | ✅ YES | Validation report confirms behavior  |
| Minimal necessary rules | ⚠️ PARTIAL | Two artifact clauses overstate enforcement level |
| Entrypoints accurately identified | ✅ YES | run_switching_canonical.m verified as canonical |
| Manifest/fingerprint requirements clear | ✅ YES | createRunContext behavior documented |
| Onboarding sufficient for new module | ⚠️ PARTIAL | Missing status writer schema requirement |
| No unnecessary mechanism additions | ✅ YES | Contracts only formalize existing behavior |

---

## FINAL VERDICT

### CONTRACTS_ACCURATE = **NO**
- **Issue:** Checkpoint PARTIAL rule has inverted required/enforced flags
- **Severity:** Critical (affects one enforcement contract, not all)
- **Fixability:** Straightforward (2-field correction in CSV)

### CONTRACTS_MINIMAL = **NO**
- **Issue:** Two artifact clauses overdesigned (required=YES but enforced=NO)
- **Severity:** Moderate (misleads but doesn't break usability)
- **Fixability:** Relocation or clarification needed

### CONTRACTS_CONSISTENT = **YES**
- **Verification:** All claims align with Phase 5F and current implementations
- **Note:** Minor ambiguity in Entrypoint rule (partially rather than unenforced)

### ONBOARDING_USABLE = **MOSTLY YES**
- **Status:** Pattern is followable but schema requirement is implicit
- **Fix:** Add status writer schema requirement to Onboarding section
- **Usability:** Would work but requires reverse-engineering from examples

---

## PHASE_5G_ACCEPTED = **NO**

**Reason for non-acceptance:**

Phase 5G contracts accurately document the core Switching canonical behavior and would support onboarding, but they contain:

1. **One systematic error** (inverted required/enforced flags in Execution contract)
2. **Two overdesigned artifact clauses** that state required=YES when enforcement is pattern-based only
3. **One missing specification** (status writer schema in Onboarding)

These are **not correctness failures** (the system works as described), but they are **precision failures** that violate the acceptance criteria:

> "Verify that Phase 5G contracts are: accurate, minimal, consistent with the real system, not overbuilt"

**Recommendation:** 

Accept Phase 5G with **MANDATORY CORRECTIONS**:
- ✏️ Fix Checkpoint PARTIAL flags (Row 4)
- ✏️ Clarify Artifact rules 14-15 (move or demote to pattern-based)  
- ✏️ Add status writer schema requirement to Onboarding

**Post-correction verdict:** PHASE_5G_ACCEPTED = YES

---

## APPENDIX: Contracted vs. Actual Behavior

### Checkpoint PARTIAL (Row 4)
**Contracted:** "required=NO, enforced=YES"  
**Actual:** Enforced by writeSwitchingExecutionStatus (throws error if non-final is not PARTIAL)  
**Verdict:** Classification is incorrect; should be required=YES, enforced=YES

### Artifact Path Discipline (Rows 14-15)
**Contracted:** "required=YES, enforced=NO" (via helper usage)  
**Actual:** Phase 5F removed marker fallback; write_execution_marker is now run-scoped only; other artifacts use createRunContext which is run-scoped by design  
**Verdict:** Pattern is enforced by helper design, not globally; should clarify enforcement mechanism

### Entrypoint Definition (Entrypoint contract)
**Contracted:** "Canonical identity defined by entrypoint, not heuristics; enforcement=NO"  
**Actual:** Detection checks entrypoint signal at classification time; enforcement is post-hoc  
**Verdict:** Accurate but could clarify that enforcement is at detection time, not execution time

### Onboarding Pattern (Section 5)
**Contracted:** 5-step model with module status writer  
**Actual:** writeSwitchingExecutionStatus is the implemented writer with specific schema  
**Verdict:** Pattern is correct but schema requirement should be explicit to avoid reverse-engineering

