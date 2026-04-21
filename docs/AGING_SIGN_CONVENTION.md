# Aging Sign Convention

This document is the single source of truth for sign conventions in the aging pipeline.

## DeltaM definition options

- `cfg.subtractOrder = 'noMinusPause'`  
  `DeltaM = M_noPause - M_pause`
- `cfg.subtractOrder = 'pauseMinusNo'`  
  `DeltaM = M_pause - M_noPause`

## FM definition options

- `cfg.FMConvention = 'rightMinusLeft'`  
  `FM = baseR - baseL`
- `cfg.FMConvention = 'leftMinusRight'`  
  `FM = baseL - baseR`

## Current project choice

- `DeltaM = M_pause - M_noPause`
- `FM = baseL - baseR`

## Physical interpretation under current choice

- A memory dip in `DeltaM(T)` is negative.
- `FM > 0` means the left plateau is higher than the right plateau.
- `FM < 0` means the right plateau is higher than the left plateau.

## Example values (MG119 60-minute dataset, Tp ~ 22 K)

From the latest sign audit run:

- `mean DeltaM (dip region) = -5.65065354e-07`
- `mean DeltaM (plateau region) = 4.6125617e-07`
- `baseL = 1.14731609e-06`
- `baseR = -2.6921573e-08`
- `FM = baseL - baseR = 1.17423766e-06`

These values are consistent with the project convention: negative dip with positive left-minus-right FM.

## Historical confusion and resolution

- Historically, parts of analysis and interpretation used `DeltaM = M_noPause - M_pause` (literature-style).
- This project intentionally uses the opposite sign: `DeltaM = M_pause - M_noPause`.
- Prior ambiguity came from mixed assumptions across scripts and comments, not from a single physical model change.
- The pipeline now keeps both conventions as explicit config options and records the active definitions in run metadata and exported tables.
