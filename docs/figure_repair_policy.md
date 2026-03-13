# Figure Repair Policy

## Core rule

Figures are immutable artifacts.

Once a figure has been exported into a run folder, no script, helper, or agent may modify that figure automatically.

## Policy rules

- Repair is opt-in only.
- Repair must be invoked explicitly by a user or researcher.
- Repair functions must never overwrite original `.fig`, `.png`, or `.pdf` artifacts.
- Repaired outputs must be written to a separate repair location, typically `repaired_figures/`.
- No automatic repair hooks may be added to experiment pipelines, diagnostics, or run helpers.
- Automated repair may only perform style-safe and layout-safe changes.
- Automated repair must not change plotted data, axis limits, scaling, normalization, or trace visibility.
- If structural changes are detected, automated repair must fail instead of exporting silently.

## Repair classifications

- `style_only`: typography and formatting changes only.
- `layout_only`: figure-size or paper-size normalization without broader style changes.
- `manual_review_required`: the repaired figure still contains conditions that need human review, such as missing labels, forbidden colormaps, 3D axes, or quality-check warnings.

## Repository boundaries

- The repair system must remain under `tools/figure_repair/`.
- Existing experiment scripts and pipelines must remain unchanged.
- Legacy visualization utilities in `General ver2/` must not be reused.
- Publication standards must follow `docs/figure_style_guide.md` and `docs/visualization_rules.md`.

## Traceability requirements

Every repaired figure directory must contain `repair_metadata.json` documenting:

- source figure name
- source figure path
- repair date
- style guide version
- applied repair actions
- repair classification
- repair requester

This metadata exists so repaired outputs remain auditable and clearly distinct from the original run artifacts.
