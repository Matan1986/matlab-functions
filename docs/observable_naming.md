# Observable Naming Policy

## χ_amp(T) — formerly known as a1

### New canonical name

**χ_amp(T)** — temperature susceptibility of switching amplitude

### Definition

χ_amp(T) ≈ −dS_peak/dT

where S_peak(T) = max_I S(T, I) is the peak switching amplitude at temperature T.

### Physical interpretation

χ_amp(T) represents the rate of change of the switching amplitude with respect to temperature.
It peaks around ~10 K, marking the low-temperature dynamic susceptibility sector where the
switching response is most temperature-sensitive.

This observable serves as the primary indicator of the low-T dynamical regime (approximately 4–10 K)
in the cross-experiment phase diagram.

### Legacy identifier

The legacy code name for this observable is **a1**.

- Existing analysis scripts and MATLAB code use `a1` as the variable name.
- Historical run outputs in `results/` use the column header `a1` or `a_1`.
- New reports and documentation should use χ_amp(T) with a note "(legacy: a1)" at first mention.

### Name equivalence

| Context | Name to use |
|---|---|
| MATLAB code / variable names | `a1` |
| CSV column headers | `a1` |
| New reports and documentation | χ_amp(T) (legacy: a1) |
| After first mention in a report | χ_amp |

### Backward compatibility

All existing pipelines continue to use `a1` unchanged. The rename is documentation-only.
No scripts, function signatures, or CSV schemas have been modified.

### Background

The renaming was introduced at the phase-diagram synthesis stage (March 2026) when the
cross-experiment observable analysis established that this quantity measures the temperature
derivative response of the switching peak amplitude, making χ_amp the physically appropriate
symbol consistent with susceptibility notation conventions.

---

## See also

- [switching_observables.md](observables/switching_observables.md)
- [observable_registry.md](observables/observable_registry.md)
- Phase diagram synthesis run: `run_2026_03_17_063903_phase_diagram_synthesis`
