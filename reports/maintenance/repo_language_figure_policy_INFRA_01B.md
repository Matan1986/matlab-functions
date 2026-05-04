# REPO-INFRA-01B: Repository-wide language and figure-output policy

## 1. Executive summary

This report establishes the repository-wide policy for scientific analysis language, use of non-MATLAB accelerators, MATLAB parity and review requirements, figure generation language, required figure export formats, and rules for canonical and manuscript promotion. It supersedes the **scope** of RLX-INFRA-01 (Relaxation-only) while **not** deleting or invalidating those Relaxation artifacts. MATLAB is the default scientific language for this repository. MATLAB is mandatory for scientific figure generation unless the user explicitly approves another language for that specific task. Every scientific figure task must export both `.fig` and `.png` unless the user overrides that in that specific task. Non-MATLAB scripts may serve as labeled table or audit accelerators; they must not produce scientific or publication or review figures unless explicitly approved for that task. Non-MATLAB scientific metrics and heavier analyses remain provisional until MATLAB parity or explicit review. Canonical and manuscript evidence must be MATLAB-native or parity-validated.

## 2. What went wrong in the prior Relaxation-only framing

Relaxation work triggered useful clarification of language accelerator parity and figure rules. RLX-INFRA-01 correctly captured that policy **for the Relaxation module** but implied module-local authority. The same accelerators, figure expectations, and parity gates apply to Switching, Aging, MT, cross-module analyses, and maintenance or infrastructure scripts whenever they touch scientific results or publication-style outputs.

## 3. Why the policy must be repository-wide

The repository is MATLAB-first for inspectability and reproducibility of science and figures across experiments. Allowing different implicit rules per folder would let cross-module or script-driven workflows drift into non-MATLAB figure or metric paths without a consistent gate. A single policy aligns agents and humans with the same defaults and exceptions.

## 4. Supersession of Relaxation-only artifacts

The following Relaxation-only artifacts remain on disk and remain **valid historical records** for the Relaxation-focused INFRA-01 task. For **repository-wide** language, figure, accelerator, and promotion policy, **INFRA-01B is authoritative**.

| Historical artifact | Status |
| --- | --- |
| `reports/relaxation/relaxation_language_figure_policy_INFRA_01.md` | Superseded in **scope** only |
| `tables/relaxation/relaxation_language_figure_policy_INFRA_01_*.csv` | Superseded in **scope** only |

Authoritative supersession table: `tables/maintenance_repo_language_figure_policy_INFRA_01B_supersession.csv`.

## 5. Repository-wide language policy

Verbatim policy text (authoritative for INFRA-01B):

```text
MATLAB is the default scientific analysis language for this repository.
MATLAB is mandatory for scientific figure generation unless the user explicitly approves another language for that specific task.
Every scientific figure task must export both .fig and .png unless the user explicitly overrides this in that specific task.
Node/JavaScript/Python or other non-MATLAB scripts may be used as non-visual table/audit accelerators when clearly labeled.
Non-MATLAB scripts must not generate scientific or publication/review figures unless explicitly approved by the user for that specific task.
Non-MATLAB scientific metrics are provisional until MATLAB parity or explicit review is documented.
Any non-MATLAB result involving smoothing, derivatives, interpolation, fitting, time-warping, rate-spectrum extraction, reconstruction, decomposition, or model selection requires MATLAB parity/review before canonical or manuscript use.
Existing non-MATLAB outputs are not automatically invalidated by language choice, but they must be labeled provisional until reviewed or MATLAB-parity checked.
Canonical/manuscript evidence must be MATLAB-native or parity-validated.
```

## 6. Repository-wide figure-output policy

- Default: scientific figures are produced in MATLAB using workflows that can be opened and edited by the user.
- Every scientific figure task exports both `.fig` and `.png` unless the user explicitly overrides that requirement for that specific task.
- Publication or review figures follow `docs/visualization_rules.md` and `docs/figure_style_guide.md`.
- The helper `tools/save_run_figure.m` also exports PDF in addition to PNG and FIG; that is compatible with publication pipelines and does not remove the `.fig` and `.png` expectation for scientific figure tasks.

## 7. Non-MATLAB accelerator policy

- Node, JavaScript, Python, and other non-MATLAB tools may be used for **non-visual** table generation, audits, inventory, and similar accelerators when outputs are **clearly labeled** as to language and role.
- They **must not** generate scientific or publication or review **figures** unless the user explicitly approves that language for that specific task.

## 8. MATLAB parity/review requirements

- Smoothing, derivatives, interpolation, fitting, time-warping, rate-spectrum extraction, reconstruction, decomposition, and model selection implemented outside MATLAB require **MATLAB parity or explicit review** before canonical or manuscript use.
- Cross-module analyses must carry **explicit lineage** (inputs, module boundaries, transforms) when cited as evidence.

## 9. Required future prompt block

A reusable machine-readable prompt for agents is in `tables/maintenance_repo_language_figure_policy_INFRA_01B_future_prompt_block.csv`.

## 10. What is not invalidated

- Relaxation-only INFRA_01 artifacts are **not** deleted and **not** invalidated as historical task outputs.
- Existing non-MATLAB outputs are **not** automatically invalidated solely because they were produced outside MATLAB.

## 11. What remains provisional

- Non-MATLAB scientific metrics and heavier analyses remain **provisional** until MATLAB parity or documented review.
- Any output touching the parity domains in section 8 remains **provisional** until gated.

## 12. Recommended next step

**REPO-INFRA-02** — Repository-wide non-MATLAB inventory and MATLAB conversion/parity plan.

This follow-on task should survey **all modules** and classify non-MATLAB scripts and outputs as:

- safe table or audit accelerators,
- provisional scientific scripts needing MATLAB parity,
- figure-related scripts requiring MATLAB conversion or explicit per-task approval,
- obsolete or unknown items needing human review.

---

## Supporting artifacts

| Artifact | Path |
| --- | --- |
| Supersession table | `tables/maintenance_repo_language_figure_policy_INFRA_01B_supersession.csv` |
| Document inventory | `tables/maintenance_repo_language_figure_policy_INFRA_01B_doc_inventory.csv` |
| Policy matrix | `tables/maintenance_repo_language_figure_policy_INFRA_01B_policy_matrix.csv` |
| Future prompt block | `tables/maintenance_repo_language_figure_policy_INFRA_01B_future_prompt_block.csv` |
| Status flags | `tables/maintenance_repo_language_figure_policy_INFRA_01B_status.csv` |
