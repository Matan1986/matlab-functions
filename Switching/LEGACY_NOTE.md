# Switching Module Status

## Current Status

The Switching module predates the current repository architecture.

It contains working but partially inconsistent analysis code and has not yet been refactored to the newer run-based structure used by the Aging module.

At this stage the priority of the project is physics analysis rather than architectural cleanup.

## Development Rule

Until explicitly instructed otherwise:

- The existing Switching pipeline should be treated as **legacy code**.
- Do **NOT refactor or reorganize Switching pipeline files**.
- Do **NOT change the internal behavior of existing Switching scripts**.

## Allowed Development

New analysis work should be implemented only in:

Switching/analysis/

These analysis scripts may call the existing Switching code but should not modify it.

This approach allows physics analysis to progress without risking instability in the large legacy module.

## Future Work

A full refactor of the Switching module may happen later, after the physical structure of the Switching data is better understood.
