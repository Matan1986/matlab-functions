# Figure Repair Failure Modes

Date: March 11, 2026

The final validation pass tested several failure and edge conditions.

## Results

| Scenario | Expected behavior | Observed result | Pass |
| --- | --- | --- | --- |
| Corrupted `.fig` file | fail safely with clear error | `repair_fig_file:OpenFailed` with readable open/load message | `pass` |
| Unsupported object type (`patch`) | repair may proceed, but classification must require manual review | `manual_review_required`, `unsupported_count=1` | `pass` |
| Heatmap without colorbar | repair may proceed, but warning/classification must flag it | `manual_review_required`, warning: `Image-based content was detected without a colorbar.` | `pass` |
| Hidden handles | inspection must still see hidden-handle state and repair must remain safe | `style_only`, `hidden_handle_count=151` | `pass` |

## Conclusions

- Corrupted FIG input does not produce silent partial output.
- Unsupported graphics content is handled conservatively by marking the repaired figure for manual review.
- Missing heatmap colorbars are surfaced as repair warnings and manual-review classifications.
- Hidden handles do not prevent inspection or repair; `findall`-based traversal remains robust.

## Remaining note

Unsupported object types are detected and classified safely, but they are not restyled semantically. The current system prefers conservative `manual_review_required` behavior instead of attempting potentially destructive automatic changes.
