# MATLAB Functions Library

## Quantum Materials Analysis Pipelines

### Overview
This library provides MATLAB scripts and utilities for analyzing quantum materials experiments across multiple module pipelines and versions.

### Module Table
| Module Name | Version | File | Description |
|---|---|---|---|
| AC HC MagLab | ver8 | `ACHC_main.m` | ACHC_main.m |
| Aging | ver2 | `Main_Aging.m` | MAIN_AGING_MEMORY — Spin-glass aging memory analysis (no fitting) Reads all aging-memory .dat files, identifies "pause" vs "no-pause" runs, computes ΔM(T) = M_noPause - M_pause, and plots M(T) and ΔM(T). |
| FieldSweep | ver3 | `FieldSweep_main.m` | Transport_FieldSweep_auto.m — Automatic channels (raw or filtered) |
| HC | ver1 | `HC_main.m` | =========================== HC_main  –  Full Version Compatible with auto mass detection in getFileListHC =========================== |
| MH | ver1 | `MH_main.m` | MH_main.m |
| MT | ver2 | `MT_main.m` | intro |
| PS | ver4 | `PS_main.m` | PS_dynamic_channels_dynamic_auto.m — Median + smoothing + outlier removal + post-normalization filtering + RAW MODE |
| Relaxation | ver3 | `main_relexation.m` | MAIN_RELAXATION — TRM/IRM Relaxation Analysis |
| Resistivity | ver6 | `Resistivity_main.m` | Resistivity_main.m Transport (ρ/R) vs Temperature using TEX interpreter |
| Resistivity MagLab | ver1 | `ACHC_RH_main.m` | Main script for RH plotting based on slow & fast variables |
| Susceptibility | ver1 | `main_Susceptibility.m` | AC susceptibility module for Co1/3TaS2 |

### Utilities
- General ver2/ contains shared analysis helpers and plotting utilities.
- Tools ver1/ contains general purpose tools used across modules.

### Usage
1. Open MATLAB and set the current folder to this repository root.
2. Run a module main script, for example:

```matlab
run(fullfile('Aging ver2','Main_Aging.m'))
```

### Dependencies
- MATLAB base installation.
- Additional toolboxes may be required by specific modules.

