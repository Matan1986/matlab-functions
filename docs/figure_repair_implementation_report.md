# Figure Repair Implementation Report

Date: March 10, 2026

## Files created

### Module

- `tools/figure_repair/inspect_fig_contents.m`
- `tools/figure_repair/apply_fig_style_repair.m`
- `tools/figure_repair/export_repaired_figure.m`
- `tools/figure_repair/write_repair_metadata.m`
- `tools/figure_repair/repair_fig_file.m`
- `tools/figure_repair/repair_fig_directory.m`
- `tools/figure_repair/demo_repair_example.m`

### Documentation

- `docs/figure_repair_repo_scan.md`
- `docs/figure_repair_system.md`
- `docs/figure_repair_workflow.md`
- `docs/figure_repair_policy.md`
- `docs/figure_repair_implementation_report.md`

## Functions implemented

- `inspect_fig_contents`: inspects FIG contents and returns structured metadata for axes, lines, scatter objects, images, legends, colorbars, limits, interpreters, and figure sizing.
- `apply_fig_style_repair`: applies safe formatting repairs aligned with the repository publication style guide.
- `export_repaired_figure`: exports repaired outputs as vector PDF, 600 dpi PNG, and repaired FIG.
- `write_repair_metadata`: writes `repair_metadata.json` with source, repair action, classification, and requester information.
- `repair_fig_file`: explicit single-file repair workflow with inspection, repair, quality check, validation, export, and metadata generation.
- `repair_fig_directory`: repairs all FIG files from a run root or figures directory into a sibling `repaired_figures/` tree.
- `demo_repair_example`: demonstrates intentional repair of an existing run artifact.

## Safety mechanisms

- Output-directory guardrail: `repair_fig_file` rejects any output directory inside the original `figures/` directory.
- No pipeline integration: all repair logic lives under `tools/figure_repair/` and is invoked manually.
- Structural validation: the system compares pre-repair and post-repair inspections to detect forbidden changes in axis limits, scaling, object counts, visibility, and colormap state.
- Explicit classification: each repair is labeled as `style_only`, `layout_only`, or `manual_review_required`.
- Audit trail: every repaired output directory receives `repair_metadata.json`.
- Reuse of repository-safe helpers: repair aligns with `apply_publication_style.m` and `figure_quality_check.m` without reusing legacy `General ver2/` utilities.

## Example output directory

```text
results/aging/runs/run_2026_03_10_112842_geometry_visualization/
    figures/
        aging_map_heatmap.fig
    repaired_figures/
        aging_map_heatmap/
            repaired.fig
            repaired.pdf
            repaired.png
            repair_metadata.json
```

## Analysis and pipeline impact

- No experiment pipelines were modified.
- No analysis scripts were modified.
- The repair system is fully optional and user-triggered.

## Future extension possibilities

- Add a read-only comparison report that summarizes source-versus-repaired style differences.
- Add a batch summary report for `repair_fig_directory` runs.
- Add optional journal-specific presets on top of the repository publication standard.
- Add manual-review templates for figures classified as `manual_review_required`.
