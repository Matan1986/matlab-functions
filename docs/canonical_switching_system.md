# Canonical Switching System

## 1. System Overview

- Canonical is protocol-based.
- The Switching system is a single pipeline with channel awareness.
- `S_canonical` is the system anchor.

## 2. Pipeline

- `processFilesSwitching` performs raw file processing and channel materialization.
- `analyzeSwitchingStability` consumes the processed channel state and produces the canonical stability object.
- The materialization boundary is the transition from processed local state to canonical channel representation.

## 3. Channel Model

- `measured_channels` = the physical channel ids present in the file, in stored order.
- `switching_channel` = the data-derived channel id used by stability detection.
- `normalization_channel` = the preset-driven reference channel used for normalization.

Rules:

- `switching_channel` is data-derived.
- `normalization_channel` is preset-based.

## 4. Channel Mapping

```text
local k -> physical = physIndex(k)
```

- `physIndex` comes from `processFilesSwitching`.
- `phys2local` is the inverse map.
- `phys2local(physIndex(k)) == k` is required.

## 5. Representation Contract

- `switching_channel_local` is the local channel id `k`.
- `switching_channel_physical` is `physIndex(k)`.
- `normalization_channel_physical` is the physical preset reference.
- Dual representation is required.
- Local-only representation is not valid downstream.

## 6. Enforcement Layer

- Before the `S_canonical` boundary: local indices are allowed.
- After the `S_canonical` boundary: physical indices are required.
- No local-as-physical usage is allowed.
- No downstream object may rely on local-only channel identity.

## 7. `S_canonical` Object

`S_canonical` contains:

- `S_map`
- `measured_channels`
- `switching_channel_local`
- `switching_channel_physical`
- `normalization_channel_physical`
- `physIndex`
- `phys2local`

Validation rules:

- `physIndex` must exist.
- `phys2local` must invert `physIndex`.
- `switching_channel_physical` must be valid.
- Mapping consistency must hold for every materialized channel.

Failure policy:

- Missing or inconsistent mapping fails materialization.
- No fallback, no guessing, no silent coercion.

## 8. Invariants

- `phys2local(physIndex(k)) == k`
- `switching_channel_physical` is valid
- mapping consistency is preserved across the boundary

## 9. What is NOT Canonical

- `summaryTable.channel`
- local-only indices downstream
- legacy usage patterns

## 10. System Status

```text
SYSTEM_CANONICAL_CLOSURE = YES
CORE_SYSTEM_STABLE = YES
CHANNEL_SYSTEM_RESOLVED = YES
SAFE_FOR_ANALYSIS = YES
LEGACY_ALIGNMENT_PENDING = YES
```