# reports/switching/ README

## Purpose
`reports/switching/` is the durable Switching report namespace for promoted markdown artifacts (audits, policy-linked summaries, and durable narrative outputs).

## Report Family Tagging
Each durable report should declare:
- report identifier/title
- `family` tag
- source run(s)
- producer script(s) or process
- canonicality/diagnostic/replay status

Family tags must preserve separation for:
- `legacy_old`
- `canonical_residual_decomposition`
- `canonical_geometric_decomposition`
- `canonical_replay`

## Source Lineage Expectations
- Reports must include backlinks to source run containers (`results/switching/runs/<run_id>/`) where applicable.
- If a report summarizes durable promoted tables/figures, it should cite the source table/figure paths and their lineage links.

## Diagnostic Report Handling
- Diagnostic reports are non-canonical by default.
- Diagnostic reports must be labeled as diagnostic and must not be presented as canonical outcomes unless explicitly promoted.

## Mixed-Family Claim Restriction
No mixed-family report claims are allowed unless the document is explicitly marked as synthesis and still preserves per-family boundaries and caveats.
