# Observable Layer

## Purpose

The observable layer defines standardized physical quantities extracted from experiments so results can be compared across measurements.

The layer separates two variable types:

- Coordinates
- Observables

Coordinates are minimal latent variables that describe the geometry of an experiment's data.

Observables are physical quantities derived from the experiment that may be compared between experiments.

Coordinates are experiment-specific.

Observables form a shared layer across experiments.

Each run exports observables to:

`results/<experiment>/runs/<run_id>/observables.csv`

## Observable Ontology

The project uses a layered observable hierarchy:

Layer 1 - Raw experimental measurements

Layer 2 - Experiment-specific analysis pipelines

Layer 3 - Observable layer (standardized variables)

Layer 4 - Cross-experiment physics analysis

This structure allows experiments with different native measurements (for example resistance, magnetization, or relaxation response) to be compared through a shared observable representation.
