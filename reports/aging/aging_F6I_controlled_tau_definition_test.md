# F6I Controlled tau-definition test

diagnostic_tau_only; not_canonical; not_physical_claim; not_replacing_F4A_F4B.

Legacy observable: `C:\Dev\matlab-functions\results_old\aging\runs\run_2026_03_12_211204_aging_dataset_build\tables\aging_observable_dataset.csv`

## Verdicts

- **F6I_CONTROLLED_TAU_TEST_COMPLETED**: YES
- **LEGACY_PROTOCOL_REIMPLEMENTED**: YES
- **CANONICAL_PROTOCOL_REIMPLEMENTED**: YES
- **NEW_TAU_FITTING_PERFORMED**: YES
- **NEW_TAU_FITS_DIAGNOSTIC_ONLY**: YES
- **OLD_VALUES_USED_AS_CANONICAL_EVIDENCE**: NO
- **CANONICAL_VALUES_REPLACED**: NO
- **DIP_GAP_PRIMARILY_SIGNAL**: NO
- **DIP_GAP_PRIMARILY_PROTOCOL**: YES
- **FM_GAP_PRIMARILY_SIGNAL**: NO
- **FM_GAP_PRIMARILY_PROTOCOL**: YES
- **OLD_26K_SPIKE_SURVIVES_CANONICAL_PROTOCOL**: YES
- **CANONICAL_26K_AFM_LONG_TAU_SURVIVES_LEGACY_PROTOCOL**: YES
- **EQUALIZING_PROTOCOL_REDUCES_DIP_GAP**: NO
- **EQUALIZING_SIGNAL_REDUCES_FM_GAP**: YES
- **PHYSICAL_INTERPRETATION_ALLOWED**: NO
- **MECHANISM_VALIDATION_PERFORMED**: NO
- **CROSS_MODULE_SYNTHESIS_PERFORMED**: NO
- **READY_FOR_NEXT_ACTION**: YES

## 26 K diagnostic quantities

- **legacy_Dip_depth_canonical_protocol_tau_B_s**: 1.42323138979
- **canonical_TrackB_legacy_protocol_tau_C_s**: 771.038461886
- **fm_identical_y_tauA_eq_tauC**: 1
- **fm_protocol_log10_ratio_D_over_A**: 0.490698621065
- **dip_ratio_tauB_over_tauA**: 0.151518118638
- **dip_ratio_tauD_over_tauC**: 9.39427630049

## Attribution (primary Tp median)

- Median fraction of |log10 gaps| attributed to **signal** (DIP/AFM): 0.458
- Median fraction attributed to **signal** (FM): 0 (identical y(t_w) => 0)

## Answers (diagnostic, non-canonical)

1. **DIP/AFM gap — signal vs protocol:** Across primary Tp, the split is mixed at 26 K (signal ~0.52 of log-gap); median over 22/26/30 attributes more weight to **protocol + within-protocol path** than signal alone (see verdict flags and CSV).
2. **FM gap:** y(t_w) is identical for legacy vs canonical FM rows; **protocol-only** explains the legacy-vs-canonical tau difference (fraction_signal = 0).
3. **26 K legacy dip spike vs canonical protocol:** Fitting legacy Dip_depth with the canonical single-exponential gate yields tau_B still **far below** the committed canonical AFM tau (spike verdict uses tau_B << 0.1 * canonical reference).
4. **Canonical AFM TrackB vs legacy protocol:** tau_C from canonical signal with legacy protocol is **hundreds of seconds**, not multi-thousand — long canonical tau is **not** reproduced by legacy consensus on the TrackB curve alone.
5. **Documentation vs future canonical revision:** This supports **documentation and definitional clarity** (what “tau” refers to under each pipeline). It does **not** by itself justify rewriting canonical tau without a separate policy decision; FM shows definitional alignment removes y ambiguity; DIP shows both signal definition and fit gate drive the gap.

## Tables

- Controlled matrix: `tables/aging/aging_F6I_controlled_tau_matrix.csv`
- Attribution: `tables/aging/aging_F6I_tau_gap_attribution.csv`
- 26 K diagnosis: `tables/aging/aging_F6I_26K_controlled_diagnosis.csv`
- Ratios / quality / status: see `tables/aging/aging_F6I_*.csv`
