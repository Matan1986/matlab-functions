# Switching analysis namespace declaration (copy into report or script header)

Use this block at the top of new Switching analysis reports, run notes, or agent summaries. Replace angle-bracket placeholders.

---

- **`namespace_id`:** `<e.g. CORRECTED_CANONICAL_OLD_ANALYSIS | CANON_GEN_SOURCE | EXPERIMENTAL_PTCDF_DIAGNOSTIC | LEGACY_OLD_TEMPLATE | technical OLD_* / CANON_GEN / …>`
- **`analysis_role`:** `<MAIN_MANUSCRIPT | SOURCE_DATA | EXPERIMENTAL_DIAGNOSTIC | LEGACY_TEMPLATE | FIGURE_ONLY | DIAGNOSTIC_FORENSIC>`
- **`source_data_namespace`:** `<e.g. CANON_GEN_SOURCE for S from switching_canonical_S_long; NONE if alignment-only>`
- **`primary_input_artifacts`:** `<paths or run_id + switching_canonical_S_long.csv / alignment cores / …>`
- **`backbone_object`:** `<symbolic: e.g. Speak*cdfRow on x-grid | Scdf from S_model_pt_percent | scaled S/Speak vs x | NONE>`
- **`residual_object`:** `<e.g. deltaS Rlow Rfill | NONE>`
- **`svd_input`:** `<explicit formula S minus WHAT matrix or vector>`
- **`coordinate_grid`:** `<native current_mA | x = (I-I_peak)/width | CDF_pt axis for overlay | …>`
- **`uses_Ipeak`:** `<YES | NO | PARTIAL — note where>`
- **`uses_width`:** `<YES | NO | PARTIAL — note where>`
- **`relation_to_dS_dI`:** `<N/A | gradient of repaired quasi-CDF per EXPERIMENTAL | legacy PT_matrix gradient path | …>`
- **`claim_status`:** `<MANUSCRIPT_PRIMARY under B09 | DIAGNOSTIC | HISTORICAL_TEMPLATE | …>`
- **`manuscript_safe`:** `<YES | PARTIAL | NO — cite tables/switching_allowed_evidence_by_use_case.csv row>`
- **`forbidden_conflations_checked`:** `<YES — reviewed switching_forbidden_ambiguous_phrases.csv | NO>`

---

**Contract reminder:** If this block is missing or `namespace_id` is ambiguous, do not use **“canonical backbone”** language (see `tables/switching_forbidden_ambiguous_phrases.csv`).
