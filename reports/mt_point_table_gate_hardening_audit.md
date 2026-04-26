# MT Point-Table Gate Hardening Audit (Stage 4.4)

## Scope and basis

This is a read-only gate-strength audit of Stage 4.2 point-table validation logic in `runs/run_mt_canonical.m`, using the validated run:

- `run_2026_04_26_112155_mt_real_data_diagnostic`

No MATLAB execution and no code edits were performed in this audit stage.

## Executive conclusion

- All gates `G01`-`G11` are currently `PASS` in the Stage 4.2 run output.
- Gate coverage is directionally correct, but multiple PASS outcomes are **superficial** (existence/declaration level rather than semantic proof).
- No single severe correctness defect was identified that requires emergency code change before any continuation.
- Hardening is still required before claiming robust next-stage observables readiness.

## Gate-by-gate strength assessment

- `G01 schema_columns_present`: **ADEQUATE**  
  Checks required schema column presence across all four tables.

- `G02 required_fields_nonmissing`: **WEAK**  
  Checks selected string fields but does not broadly validate numeric required semantics or per-table requiredness comprehensively.

- `G03 row_parity_raw_clean_derived`: **ADEQUATE**  
  Correctly checks parity of row counts across RAW/CLEAN/DERIVED.

- `G04 key_uniqueness`: **STRONG**  
  Explicitly verifies uniqueness of immutable key (`file_id,row_index`) within each point table.

- `G05 no_float_coordinate_joins`: **SUPERFICIAL**  
  PASS is set from construction narrative (`details`) without an actual join-audit proof.

- `G06 clean_raw_traceability`: **ADEQUATE**  
  Verifies `M_emu_raw` consistency against RAW `M_emu`, including finite-mask mismatch path.

- `G07 smooth_not_clean_replacement`: **SUPERFICIAL**  
  PASS is effectively declarative (`details` string), not enforced by computation-path checks.

- `G08 derived_source_isolation`: **SUPERFICIAL**  
  Currently checks column presence assumptions, not true lineage isolation from RAW reads.

- `G09 time_channel_assumption_check`: **SUPERFICIAL**  
  PASS depends on descriptive detail (`time_rel_s explicit`) rather than semantic misuse detection.

- `G10 segmentation_annotation_check`: **SUPERFICIAL**  
  Placeholder-state detail check; does not prove segmentation is non-cleaning semantics in future/non-placeholder cases.

- `G11 observables_provenance_check`: **ADEQUATE**  
  Checks non-empty provenance fields (`source_columns`, `aggregation_method`, `definition`) for non-empty observables table.

## Required-check focus findings

1. Immutable key enforcement  
   - uniqueness: present and strong (`G04`)  
   - key-set equality across RAW/CLEAN/DERIVED: **missing explicit gate**

2. Row parity and key-set equality  
   - parity: present (`G03`)  
   - key-set equality: not explicitly validated (gap)

3. No float-coordinate joins  
   - currently declared, not audited (`G05` superficial)

4. RAW/CLEAN traceability  
   - minimal moment-channel traceability present (`G06` adequate)

5. Smooth channel not replacing clean  
   - policy declared, semantic enforcement weak (`G07` superficial)

6. DERIVED from CLEAN only  
   - intent clear, lineage check not hard (`G08` superficial)

7. `time_s` imported vs elapsed semantics  
   - contract stated, misuse detection not hard (`G09` superficial)

8. Segmentation annotation semantics  
   - placeholder conventions checked; semantic boundary enforcement still weak (`G10` superficial)

9. Observables provenance  
   - baseline provenance presence validated (`G11` adequate)

## Hardening interpretation

Current gate suite is suitable for first minimal implementation milestone (`FULL_CANONICAL_DATA_PRODUCT=PARTIAL`) but not yet robust enough to justify stronger readiness upgrades without additional semantic checks.

This audit therefore recommends hardening actions before advancing to richer observables/physics stages.
