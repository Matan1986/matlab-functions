# Documents excluded from default agent prompts

**Purpose:** Reduce token load and drift. Agents should **not** attach or summarize these unless the task explicitly names a path below.

**Non-essential / redundant for routine Switching infrastructure work (15):**

1. `docs/repository_map.md` (use `docs/repo_map.md` for navigation)
2. `docs/repository_organization_audit.md`
3. `docs/figure_repair_workflow.md`
4. `docs/figure_repair_policy.md`
5. `docs/figure_repair_system.md`
6. `docs/figure_repair_repo_scan.md`
7. `docs/figure_repair_implementation_report.md`
8. `docs/figure_repair_directory_tests.md`
9. `docs/figure_repair_guardrail_tests.md`
10. `docs/figure_repair_test_cases.md`
11. `docs/figure_repair_metadata_schema.md`
12. `docs/figure_repair_inspection_audit.md`
13. `docs/figure_repair_performance.md`
14. `docs/figure_repair_validation_report.md`
15. `docs/figure_repair_report.md`

**Essential for infra instead:** `docs/AGENT_RULES.md`, `docs/repo_execution_rules.md`, `docs/infrastructure_laws.md`, `docs/run_system.md`, `docs/repo_context_minimal.md`, `docs/execution_status_schema.md`.
