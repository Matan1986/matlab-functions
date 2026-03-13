# Figure Repair Workflow

## Goal

Use the Figure Repair System when a run already contains archived `.fig` files and you want publication-oriented outputs without rerunning or modifying the original analysis code.

## Step-by-step workflow

1. Locate the run you want to prepare.

Example:

`results/relaxation/runs/run_2026_03_10_073818_svd_audit/`

2. Confirm the run contains editable source figures under:

`figures/`

3. Decide whether to repair one figure or the whole directory.

Single figure:

```matlab
repair_fig_file(source_fig_path, output_directory)
```

Whole run or figures directory:

```matlab
repair_fig_directory(run_directory)
repair_fig_directory(figures_directory)
```

4. Run the repair intentionally from MATLAB.

Example:

```matlab
repair_fig_file(
    'results/switching/runs/run_2026_03_10_205656_relaxation_switching_example/figures/example.fig', ...
    'results/switching/runs/run_2026_03_10_205656_relaxation_switching_example/repaired_figures/example');
```

5. Review the repaired outputs.

Expected files:

- `repaired.fig`
- `repaired.pdf`
- `repaired.png`
- `repair_metadata.json`

6. Check the metadata and quality warnings.

The metadata records:

- source figure path
- repair date
- style guide version
- applied repair actions
- repair classification
- quality-check findings

7. Perform final human review before publication use.

A repaired figure can still be classified as `manual_review_required` if the source artifact contains issues such as missing labels, forbidden colormaps, or other elements that should be reviewed by a researcher.

## Safety expectations

- Do not edit files inside the original `figures/` directory.
- Do not treat repair outputs as replacements for source artifacts.
- Do not add repair calls to experiment pipelines.
- Use repaired exports only after a researcher has visually reviewed them.

## Recommended review checklist

- Confirm the repaired PDF and PNG match the scientific content of the source FIG.
- Confirm axis limits and scaling were preserved.
- Confirm labels, legends, and colorbars are readable.
- Confirm any remaining quality warnings are acceptable or manually addressed.
- Keep the original FIG and repaired outputs together in the same run folder for traceability.
