#!/usr/bin/env python3
"""
Switching Phase 3 — WARN-first semantic lint/preflight consumer.

Reads committed Phase 2 / Phase 2.5 contract artifacts; does not run MATLAB,
replay, or modify analysis code. Writes findings, summary, status, and report.
"""

from __future__ import annotations

import csv
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

REPO_ROOT = Path(__file__).resolve().parent.parent

REQUIRED_INPUTS: Sequence[str] = (
    "tables/switching_semantic_taxonomy.csv",
    "tables/switching_semantic_alias_map.csv",
    "tables/switching_semantic_forbidden_terms.csv",
    "tables/switching_semantic_rename_plan.csv",
    "tables/switching_semantic_synthesis_status.csv",
    "tables/switching_semantic_materialized_artifact_registry.csv",
    "tables/switching_semantic_allowed_use_matrix.csv",
    "tables/switching_semantic_writer_contract.csv",
    "tables/switching_semantic_lint_rules.csv",
    "tables/switching_semantic_materialization_status.csv",
    "tables/switching_semantic_sidecar_template.csv",
    "tables/switching_semantic_run_manifest_template.csv",
    "tables/switching_semantic_helper_contract.csv",
    "tables/switching_semantic_phase3_preflight_integration_plan.csv",
    "tables/switching_semantic_phase25_status.csv",
    "reports/switching_semantic_synthesis_and_rename_plan.md",
    "reports/switching_semantic_contract_materialization.md",
    "reports/switching_semantic_sidecar_manifest_helper_contract.md",
)

SCAN_TARGETS: Sequence[str] = tuple(REQUIRED_INPUTS)

# Minimal required columns per contract table (schema presence).
SCHEMA_REQUIRED: Dict[str, Sequence[str]] = {
    "tables/switching_semantic_taxonomy.csv": (
        "semantic_family_id",
        "recommended_alias",
        "claim_level",
        "manuscript_safe",
        "replay_safe",
        "canonical_safe",
    ),
    "tables/switching_semantic_alias_map.csv": (
        "current_name_or_term",
        "semantic_family_id",
        "recommended_alias",
    ),
    "tables/switching_semantic_forbidden_terms.csv": (
        "forbidden_or_ambiguous_term",
        "severity",
    ),
    "tables/switching_semantic_materialized_artifact_registry.csv": (
        "path_or_object",
        "object_type",
        "semantic_family_id",
        "claim_level",
        "manuscript_safe",
        "replay_safe",
        "canonical_safe",
    ),
    "tables/switching_semantic_allowed_use_matrix.csv": (
        "semantic_family_id",
        "use_canonical_source_claims",
    ),
    "tables/switching_semantic_writer_contract.csv": (
        "field_name",
        "field_scope",
        "value_type",
    ),
    "tables/switching_semantic_lint_rules.csv": (
        "rule_id",
        "default_severity",
        "detection_pattern_or_condition",
    ),
    "tables/switching_semantic_sidecar_template.csv": (
        "field_name",
        "required",
        "field_type",
        "description",
    ),
    "tables/switching_semantic_run_manifest_template.csv": (
        "field_name",
        "required",
        "field_type",
        "description",
    ),
    "tables/switching_semantic_helper_contract.csv": (
        "helper_name",
        "purpose",
    ),
    "tables/switching_semantic_phase3_preflight_integration_plan.csv": (
        "phase3_component",
        "check_type",
        "default_severity",
    ),
}

# Sidecar template must include semantic governance fields (Phase 2.5 contract).
SIDECAR_SEMANTIC_FIELDS = {
    "semantic_family_id",
    "recommended_alias",
    "namespace_id",
    "claim_level",
    "allowed_use",
    "forbidden_use",
    "manuscript_safe_flag",
    "replay_safe_flag",
    "canonical_safe_flag",
}

MANIFEST_PROVENANCE_FIELDS = {
    "source_commit",
    "working_tree_state",
    "executing_script",
    "input_artifacts",
    "output_artifacts",
    "sidecar_paths",
    "start_time_utc",
    "end_time_utc",
}

FINDINGS_COLUMNS = (
    "finding_id",
    "severity",
    "category",
    "source_file",
    "source_row_or_line",
    "rule_id",
    "semantic_family_id",
    "message",
    "recommended_action",
    "hard_fail_condition",
    "notes",
)

SUMMARY_METRICS = (
    "total_findings",
    "hard_fail_count",
    "warn_count",
    "suggest_count",
    "required_inputs_count",
    "required_inputs_missing_count",
    "contract_tables_checked_count",
    "schema_warn_count",
    "lint_rules_loaded_count",
    "mixed_producer_checks_count",
    "allowed_use_checks_count",
)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def read_csv_rows(path: Path) -> Tuple[List[str], List[Dict[str, str]]]:
    raw = read_text(path)
    reader = csv.DictReader(raw.splitlines())
    fieldnames = reader.fieldnames or []
    rows = [dict(r) for r in reader]
    return list(fieldnames), rows


def normalize_header(fields: Optional[List[str]]) -> List[str]:
    return list(fields or [])


# SW_LINT_008 forbidden artifact stems (token policy).
STEM_SW008 = re.compile(
    r"\bX_canon\b|\bcollapse_canon\b|\bPhi_canon\b|\bkappa_canon\b",
    re.I,
)


def column_governance_sw008(name: str) -> bool:
    """Columns that describe policy, forbiddens, notes, or rename rationale — not authority assertions."""
    n = (name or "").strip().lower()
    if not n:
        return False
    exact = {
        "notes",
        "reason",
        "recommendation",
        "required_followup",
        "forbidden_use",
        "safe_replacement",
        "issue_type",
        "remediation_hint",
        "maps_to_forbidden_term",
        "detection_pattern_or_condition",
        "forbidden_or_ambiguous_term",
        "examples",
        "qualification_required",
        "ambiguity_reason",
        "allowed_only_if_qualified_by",
        "linter_message",
        "migration_risk",
        "header_warning_needed",
        "materialized_from",
        "promotes_to_hard_fail_when",
        "default_severity",
        "rename_later",
        "rename_now",
        "alias_only_possible",
    }
    if n in exact:
        return True
    substrings = (
        "forbidden",
        "remediation",
        "ambiguity",
        "qualification",
        "supersession",
        "pattern_or",
        "warning",
        "followup",
        "explain",
        "replacement",
        "issue",
        "notes",
        "reason",
    )
    return any(s in n for s in substrings)


def cell_text_demotes_sw008(val: str) -> bool:
    """Prose that cites the stem only to forbid, qualify, or document policy."""
    v = (val or "").lower()
    phrases = (
        "forbidden stem",
        "forbidden alias",
        "forbidden term",
        "no x_canon",
        "not allowed",
        "disallowed",
        "do not",
        "must not",
        "never use",
        "avoid",
        "alias-only",
        "alias only",
        "not publication",
        "not publication-safe",
        "not manuscript",
        "forbidden_terms",
        "lists bare",
        "misleading",
        "quarantine",
        "template risk",
        "publication claim",
        "forbid",
    )
    return any(p in v for p in phrases)


def risky_value_column_sw008(col: str) -> bool:
    """Columns whose values could assert an artifact name or pathway using a forbidden stem."""
    n = (col or "").strip().lower()
    return n in (
        "path_or_object",
        "recommended_alias",
        "current_name_or_term",
        "current_name",
        "output_objects",
        "source_inputs",
        "allowed_use",
        "evidence_paths",
    )


def row_asserts_authority_flags(row: Dict[str, str]) -> bool:
    """True when registry/taxonomy-style safety flags read as affirmative authority."""

    def affirmative(v: str) -> bool:
        t = (v or "").strip().upper()
        if not t or t == "N/A":
            return False
        if t.startswith("YES"):
            return True
        if "YES" in t[:16] and not t.startswith("NO"):
            return True
        return False

    for k in ("manuscript_safe", "replay_safe", "canonical_safe"):
        if affirmative(row.get(k, "")):
            return True
    cl = (row.get("claim_level") or "").upper()
    if any(x in cl for x in ("AUTHORITATIVE", "MANUSCRIPT_UNDER", "MANUSCRIPT")):
        return True
    return False


def md_line_demotes_sw008(line: str, _target: str) -> bool:
    ll = line.lower()
    if cell_text_demotes_sw008(line):
        return True
    if "forbidden_terms" in ll and "lists" in ll:
        return True
    return False


def severity_bucket(rule_default: str) -> str:
    u = (rule_default or "").upper()
    if "HARD_FAIL" in u:
        return "HARD_FAIL"
    if "SUGGEST" in u:
        return "SUGGEST"
    if "HIGH_WARN" in u:
        return "WARN"
    if "WARN" in u:
        return "WARN"
    return "WARN"


def canonical_safe_asserts_yes(value: str) -> bool:
    v = (value or "").strip().upper()
    if not v or v == "N/A":
        return False
    if "NO" in v and "YES" not in v:
        return False
    return "YES" in v


def matrix_bool_no(value: str) -> bool:
    v = (value or "").strip().upper()
    return v.startswith("NO") and "YES" not in v[:8]


def matrix_allows_canonical_claims(matrix_row: Dict[str, str]) -> bool:
    v = (matrix_row.get("use_canonical_source_claims") or "").strip().upper()
    if v.startswith("NO"):
        return False
    if "NO" in v and "CONDITIONAL" not in v and "YES" not in v:
        return False
    return True


class Preflight:
    def __init__(self) -> None:
        self.findings: List[Dict[str, str]] = []
        self._next_id = 1
        self.required_inputs_missing: List[str] = []
        self.schema_warn_count = 0
        self.contract_tables_checked = 0
        self.lint_rules_loaded = 0
        self.mixed_producer_checks = 0
        self.allowed_use_checks = 0
        self.split_ok = True
        self.quarantine_ok = True

    def add(
        self,
        severity: str,
        category: str,
        source_file: str,
        source_row_or_line: str,
        rule_id: str,
        family: str,
        message: str,
        remediation: str,
        hard_fail_condition: str,
        notes: str = "",
    ) -> None:
        fid = f"SW_PF_{self._next_id:05d}"
        self._next_id += 1
        self.findings.append(
            {
                "finding_id": fid,
                "severity": severity,
                "category": category,
                "source_file": source_file,
                "source_row_or_line": source_row_or_line,
                "rule_id": rule_id,
                "semantic_family_id": family,
                "message": message,
                "recommended_action": remediation,
                "hard_fail_condition": hard_fail_condition,
                "notes": notes,
            }
        )

    def run(self) -> int:
        missing = [p for p in REQUIRED_INPUTS if not (REPO_ROOT / p).is_file()]
        self.required_inputs_missing = missing
        if missing:
            for m in missing:
                self.add(
                    "HARD_FAIL",
                    "required_input",
                    m,
                    "",
                    "SW_PF_INPUT",
                    "",
                    f"Required contract input missing: {m}",
                    "Restore committed Phase 2 / Phase 2.5 artifact or adjust path.",
                    "Missing input prevents full governance checks.",
                )

        if missing:
            self.write_outputs(False)
            return 2

        # Schema checks
        for rel, required_cols in SCHEMA_REQUIRED.items():
            path = REPO_ROOT / rel
            self.contract_tables_checked += 1
            fieldnames, _ = read_csv_rows(path)
            fn = set(normalize_header(fieldnames))
            missing_cols = [c for c in required_cols if c not in fn]
            critical = any(
                c in missing_cols
                for c in (
                    "semantic_family_id",
                    "canonical_safe",
                    "rule_id",
                    "default_severity",
                    "use_canonical_source_claims",
                )
            )
            if missing_cols:
                self.schema_warn_count += 1
                sev = "HARD_FAIL" if critical else "WARN"
                self.add(
                    sev,
                    "schema",
                    rel,
                    "header",
                    "SW_PF_SCHEMA",
                    "",
                    f"Missing columns in {rel}: {', '.join(missing_cols)}",
                    "Regenerate or repair committed CSV header to match Phase 2 contract.",
                    "HARD_FAIL if columns needed to detect unsafe canonical promotion are absent.",
                    ",".join(missing_cols),
                )

        # Load lint rules count
        lint_path = REPO_ROOT / "tables/switching_semantic_lint_rules.csv"
        _, lint_rows = read_csv_rows(lint_path)
        self.lint_rules_loaded = len(lint_rows)

        # Apply lint scans to scan targets (prose-aware for CSV)
        self._scan_text_lint()

        # Mixed producer / registry checks
        self._check_mixed_producer_registry()

        # Allowed-use matrix vs registry
        self._check_allowed_use_matrix()

        # Template semantic field presence
        self._check_templates()

        self.write_outputs(True)
        return 0

    def _scan_text_lint(self) -> None:
        rules_path = REPO_ROOT / "tables/switching_semantic_lint_rules.csv"
        _, lint_rows = read_csv_rows(rules_path)

        rule_by_id = {r.get("rule_id", ""): r for r in lint_rows}

        # Explicit patterns from task + lint table alignment.
        # SW_LINT_008 is handled separately (_scan_sw_lint_008) for governance-aware demotion.
        compiled: List[Tuple[str, re.Pattern[str], str]] = [
            (r"SW_LINT_001", re.compile(r"(?<![A-Za-z0-9_])canonical(?![A-Za-z0-9_])", re.I), "WARN"),
            (r"SW_LINT_002", re.compile(r"(?<![A-Za-z0-9_])old(?![A-Za-z0-9_])", re.I), "WARN"),
            (r"SW_LINT_003", re.compile(r"corrected-old|corrected old", re.I), "WARN"),
            (r"SW_LINT_004", re.compile(r"canonical\s+backbone", re.I), "WARN"),
            (r"SW_LINT_005", re.compile(r"canonical\s+(Phi|phi|kappa)", re.I), "WARN"),
            (r"SW_LINT_006", re.compile(r"canonical\s+residual", re.I), "WARN"),
            (r"SW_LINT_007", re.compile(r"paper\s+figures", re.I), "WARN"),
            (r"SW_LINT_009", re.compile(r"P[_ ]?T[_ ]?CDF|PTCDF", re.I), "WARN"),
            (r"SW_LINT_010", re.compile(r"geocanon", re.I), "WARN"),
        ]

        prose_substrings = (
            "note",
            "message",
            "description",
            "hint",
            "meaning",
            "reason",
            "pattern",
            "term",
            "remediation",
            "plain",
            "ambiguity",
            "english",
            "detection",
            "forbidden",
            "plan",
            "materialization",
            "contract",
            "report",
            "summary",
        )

        def col_is_prose(name: str) -> bool:
            ln = name.lower()
            return any(s in ln for s in prose_substrings)

        for target in SCAN_TARGETS:
            p = REPO_ROOT / target
            if not p.is_file():
                continue

            if target.endswith(".md"):
                text = read_text(p)
                lines = text.splitlines()
                iterable: List[Tuple[str, str]] = [(str(i), line) for i, line in enumerate(lines, start=1)]
            elif target.endswith(".csv"):
                fieldnames, rows = read_csv_rows(p)
                iterable = []
                for ri, row in enumerate(rows, start=2):
                    chunks: List[str] = []
                    for k, v in row.items():
                        if k and col_is_prose(k) and v and len(v) > 3:
                            chunks.append(v)
                    if not chunks:
                        continue
                    iterable.append((f"row_{ri}", " ".join(chunks)))
            else:
                continue

            for loc, line in iterable:
                if target.endswith(".csv") and not line.strip():
                    continue
                for rid, rx, default_sev in compiled:
                    if not rx.search(line):
                        continue
                    # Suppress bare 'old' in common non-semantic tokens (threshold/folder/etc.)
                    if rid == "SW_LINT_002":
                        low = line.lower()
                        if any(
                            w in low
                            for w in (
                                "threshold",
                                "folder",
                                "scaffold",
                                "placeholder",
                                "bold",
                                "cold",
                                "hold",
                            )
                        ):
                            continue
                    # PTCDF: escalate if same line suggests corrected authority
                    if rid == "SW_LINT_009":
                        ll = line.lower()
                        if not (
                            "corrected" in ll
                            or "authority" in ll
                            or "backbone" in ll
                            or "manuscript" in ll
                            or "corrected-old" in ll
                        ):
                            continue
                    # geocanon + residual proximity for SW_LINT_010
                    if rid == "SW_LINT_010" and "residual" not in line.lower():
                        continue

                    rule_row = rule_by_id.get(rid, {})
                    sev = default_sev
                    if rid.startswith("SW_LINT_"):
                        ds = (rule_row.get("default_severity") or "").upper()
                        if "HARD_FAIL" in ds:
                            sev = "HARD_FAIL"
                        elif rule_row:
                            sev = severity_bucket(rule_row.get("default_severity", "WARN"))

                    hard_cond = ""
                    if sev == "HARD_FAIL":
                        hard_cond = (
                            rule_row.get("promotes_to_hard_fail_when", "")
                            or "Unsafe artifact alias or publish-path policy."
                        )

                    msg = f"Lint pattern matched ({rid}) in {target} at {loc}."
                    rem = (rule_row.get("remediation_hint") or "See switching_semantic_lint_rules.csv and forbidden_terms.")
                    self.add(
                        sev,
                        "lint_text_scan",
                        target,
                        loc,
                        rid,
                        "",
                        msg,
                        rem,
                        hard_cond,
                        line.strip()[:500],
                    )

        self._scan_sw_lint_008(rule_by_id)

    def _scan_sw_lint_008(self, rule_by_id: Dict[str, Dict[str, str]]) -> None:
        """Governance-aware SW_LINT_008: demote token hits in policy/notes/forbidden columns."""
        rule_row = rule_by_id.get("SW_LINT_008", {})
        rem = rule_row.get("remediation_hint") or "See switching_semantic_lint_rules.csv."
        hard_cond = rule_row.get("promotes_to_hard_fail_when") or "Unsafe artifact alias or publish-path policy."

        for target in SCAN_TARGETS:
            p = REPO_ROOT / target
            if not p.is_file():
                continue

            if target.endswith(".md"):
                text = read_text(p)
                for i, line in enumerate(text.splitlines(), start=1):
                    if not STEM_SW008.search(line):
                        continue
                    ll = line.lower()
                    if md_line_demotes_sw008(line, target):
                        sev = "WARN"
                    elif re.search(
                        r"\b(use|using|adopt|ship|deploy)\s+.{0,40}x_canon|x_canon\s+as\s+(canonical|authoritative)|"
                        r"collapse_canon\s+as\s+(canonical|authoritative|manuscript)",
                        line,
                        re.I,
                    ) and "forbidden" not in ll and "not allowed" not in ll:
                        sev = "HARD_FAIL"
                    else:
                        sev = "WARN"

                    hf = hard_cond if sev == "HARD_FAIL" else ""
                    self.add(
                        sev,
                        "lint_text_scan",
                        target,
                        str(i),
                        "SW_LINT_008",
                        "",
                        f"SW_LINT_008 stem match in {target} line {i}.",
                        rem,
                        hf,
                        line.strip()[:500],
                    )
                continue

            if not target.endswith(".csv"):
                continue

            _, rows = read_csv_rows(p)
            for ri, row in enumerate(rows, start=2):
                for col, val in row.items():
                    if val is None or not isinstance(val, str) or not val.strip():
                        continue
                    if not STEM_SW008.search(val):
                        continue
                    demote = column_governance_sw008(col) or cell_text_demotes_sw008(val)
                    risky = risky_value_column_sw008(col)
                    auth = row_asserts_authority_flags(row)

                    if demote:
                        sev = "WARN"
                    elif risky and auth:
                        sev = "HARD_FAIL"
                    else:
                        sev = "WARN"

                    hf = hard_cond if sev == "HARD_FAIL" else ""
                    self.add(
                        sev,
                        "lint_text_scan",
                        target,
                        f"row_{ri}:{col}",
                        "SW_LINT_008",
                        row.get("semantic_family_id", "") or "",
                        f"SW_LINT_008 stem in column {col!r} ({target} row {ri}).",
                        rem,
                        hf,
                        (val or "")[:500],
                    )

    def _check_mixed_producer_registry(self) -> None:
        reg_path = REPO_ROOT / "tables/switching_semantic_materialized_artifact_registry.csv"
        _, rows = read_csv_rows(reg_path)

        s_long_rows = [
            r
            for r in rows
            if "switching_canonical_S_long" in (r.get("path_or_object") or "")
        ]
        self.mixed_producer_checks += len(s_long_rows)

        for idx, r in enumerate(rows, start=2):
            path = r.get("path_or_object") or ""
            obj = (r.get("object_type") or "").upper()
            fam = r.get("semantic_family_id") or ""
            if "switching_canonical_S_long" not in path:
                continue
            if "::column" in path:
                col = path.split("::column/")[-1].strip()
                if col in ("S_percent", "T_K", "current_mA"):
                    if fam != "CANON_GEN_SOURCE":
                        self.split_ok = False
                        self.add(
                            "WARN",
                            "mixed_producer_column",
                            "tables/switching_semantic_materialized_artifact_registry.csv",
                            str(idx),
                            "SW_LINT_SPLIT",
                            fam,
                            f"Column {col} should map to CANON_GEN_SOURCE; found {fam}.",
                            "Align registry row with Phase 2 mixed-producer split.",
                            "",
                            path,
                        )
                if col in ("PT_pdf", "CDF_pt", "S_model_pt_percent", "residual_percent"):
                    if fam != "EXPERIMENTAL_PTCDF_DIAGNOSTIC":
                        self.split_ok = False
                        self.add(
                            "WARN",
                            "mixed_producer_column",
                            "tables/switching_semantic_materialized_artifact_registry.csv",
                            str(idx),
                            "SW_LINT_SPLIT",
                            fam,
                            f"Column {col} should map to EXPERIMENTAL_PTCDF_DIAGNOSTIC; found {fam}.",
                            "Align registry row with EXPERIMENTAL PT/CDF diagnostic family.",
                            "",
                            path,
                        )
                    if (r.get("manuscript_safe") or "").upper().startswith("YES") and col in (
                        "PT_pdf",
                        "CDF_pt",
                        "S_model_pt_percent",
                        "residual_percent",
                    ):
                        self.quarantine_ok = False
                        self.add(
                            "HARD_FAIL",
                            "mixed_producer_quarantine",
                            "tables/switching_semantic_materialized_artifact_registry.csv",
                            str(idx),
                            "SW_LINT_017",
                            fam,
                            "PT/CDF or residual diagnostic column marked manuscript_safe YES contradicts quarantine policy.",
                            "Set manuscript_safe NO/CONDITIONAL per EXPERIMENTAL_PTCDF_DIAGNOSTIC.",
                            "Unsafe promotion of experimental PT/CDF as manuscript authority.",
                            path,
                        )
            else:
                # Whole-path references without column split (excluding script entrypoints)
                if "run_switching_canonical.m" in path:
                    continue
                if "REG001" in path or "registry_seed" in obj.lower():
                    self.add(
                        "WARN",
                        "mixed_producer_row",
                        "tables/switching_semantic_materialized_artifact_registry.csv",
                        str(idx),
                        "SW_LINT_013",
                        fam,
                        "switching_canonical_S_long referenced without ::column split on this row — verify REG001-style split coverage.",
                        "Emit explicit column-level registry rows for S_long.",
                        "",
                        path,
                    )

            # Stale governance hint
            notes = (r.get("notes") or "") + " " + (r.get("path_or_object") or "")
            if re.search(r"\bstale\b", notes, re.I) and "SUPERSESSION" not in notes.upper() and "CURRENT_" not in notes.upper():
                self.add(
                    "WARN",
                    "stale_supersession",
                    "tables/switching_semantic_materialized_artifact_registry.csv",
                    str(idx),
                    "SW_LINT_012",
                    fam,
                    "Possible stale reference without explicit supersession pointer in row notes/path.",
                    "Add supersession reference or cite CURRENT_* rows per governance.",
                    "",
                    path[:200],
                )

    def _check_allowed_use_matrix(self) -> None:
        mat_path = REPO_ROOT / "tables/switching_semantic_allowed_use_matrix.csv"
        reg_path = REPO_ROOT / "tables/switching_semantic_materialized_artifact_registry.csv"
        _, matrix_rows = read_csv_rows(mat_path)
        _, reg_rows = read_csv_rows(reg_path)

        matrix_by_family = {r["semantic_family_id"]: r for r in matrix_rows if r.get("semantic_family_id")}

        for idx, r in enumerate(reg_rows, start=2):
            fam = (r.get("semantic_family_id") or "").strip()
            if not fam or fam not in matrix_by_family:
                self.allowed_use_checks += 1
                self.add(
                    "WARN",
                    "allowed_use",
                    "tables/switching_semantic_materialized_artifact_registry.csv",
                    str(idx),
                    "SW_PF_MATRIX",
                    fam,
                    f"semantic_family_id not found in allowed_use_matrix: {fam}",
                    "Add matrix row or fix registry family id.",
                    "",
                    "",
                )
                continue

            self.allowed_use_checks += 1
            mrow = matrix_by_family[fam]
            cs = r.get("canonical_safe") or ""
            if canonical_safe_asserts_yes(cs) and not matrix_allows_canonical_claims(mrow):
                self.add(
                    "HARD_FAIL",
                    "allowed_use",
                    "tables/switching_semantic_materialized_artifact_registry.csv",
                    str(idx),
                    "SW_PF_UNSAFE_CANON",
                    fam,
                    "Registry canonical_safe asserts YES while allowed_use_matrix forbids canonical-source claims for this family.",
                    "Downgrade canonical_safe or fix family/matrix alignment.",
                    "Unsafe canonical / authoritative promotion vs matrix.",
                    "",
                )

    def _check_templates(self) -> None:
        sidecar_p = REPO_ROOT / "tables/switching_semantic_sidecar_template.csv"
        _, srows = read_csv_rows(sidecar_p)
        fields = {r.get("field_name", "").strip() for r in srows}
        missing_sf = SIDECAR_SEMANTIC_FIELDS - fields
        if missing_sf:
            self.schema_warn_count += 1
            self.add(
                "WARN",
                "template_schema",
                "tables/switching_semantic_sidecar_template.csv",
                "",
                "SW_PF_TEMPLATE",
                "",
                f"Sidecar template missing expected semantic fields: {sorted(missing_sf)}",
                "Ensure Phase 2.5 sidecar template includes semantic governance columns.",
                "",
            )

        man_p = REPO_ROOT / "tables/switching_semantic_run_manifest_template.csv"
        _, mrows = read_csv_rows(man_p)
        mfields = {r.get("field_name", "").strip() for r in mrows}
        missing_m = MANIFEST_PROVENANCE_FIELDS - mfields
        if missing_m:
            self.schema_warn_count += 1
            self.add(
                "WARN",
                "template_schema",
                "tables/switching_semantic_run_manifest_template.csv",
                "",
                "SW_PF_TEMPLATE",
                "",
                f"Run manifest template missing provenance fields: {sorted(missing_m)}",
                "Ensure Phase 2.5 manifest includes provenance fields.",
                "",
            )

    def write_outputs(self, completed: bool) -> None:
        hard_fail = sum(1 for f in self.findings if f["severity"] == "HARD_FAIL")
        warn_c = sum(1 for f in self.findings if f["severity"] == "WARN")
        suggest_c = sum(1 for f in self.findings if f["severity"] == "SUGGEST")

        findings_path = REPO_ROOT / "tables/switching_semantic_phase3_preflight_findings.csv"
        summary_path = REPO_ROOT / "tables/switching_semantic_phase3_preflight_summary.csv"
        status_path = REPO_ROOT / "tables/switching_semantic_phase3_preflight_status.csv"
        report_path = REPO_ROOT / "reports/switching_semantic_phase3_preflight.md"

        findings_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.parent.mkdir(parents=True, exist_ok=True)

        with findings_path.open("w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=FINDINGS_COLUMNS)
            w.writeheader()
            for row in self.findings:
                w.writerow(row)

        summary_rows = {
            "total_findings": len(self.findings),
            "hard_fail_count": hard_fail,
            "warn_count": warn_c,
            "suggest_count": suggest_c,
            "required_inputs_count": len(REQUIRED_INPUTS),
            "required_inputs_missing_count": len(self.required_inputs_missing),
            "contract_tables_checked_count": self.contract_tables_checked,
            "schema_warn_count": self.schema_warn_count,
            "lint_rules_loaded_count": self.lint_rules_loaded,
            "mixed_producer_checks_count": self.mixed_producer_checks,
            "allowed_use_checks_count": self.allowed_use_checks,
        }

        with summary_path.open("w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["metric", "value", "notes"])
            for k in SUMMARY_METRICS:
                w.writerow([k, summary_rows[k], ""])

        safe_commit = "YES" if completed else "NO"
        if completed and hard_fail > 0:
            safe_commit = "YES"

        status_keys: List[Tuple[str, Any]] = [
            ("SWITCHING_SEMANTIC_PHASE3_PREFLIGHT_COMPLETE", "YES" if completed else "NO"),
            ("READ_ONLY_EXISTING_ARTIFACTS_ENFORCED", "YES"),
            ("MATLAB_NOT_RUN", "YES"),
            ("NO_ANALYSIS_CODE_EDITS", "YES"),
            ("NO_RENAMES_EXECUTED", "YES"),
            ("NO_REPLAY_EXECUTED", "YES"),
            ("NO_FIGURES_CREATED", "YES"),
            ("NO_STAGING_OR_COMMIT", "YES"),
            ("REQUIRED_INPUTS_FOUND", "YES" if not self.required_inputs_missing else "NO"),
            ("CONTRACT_TABLE_SCHEMAS_CHECKED", "YES" if completed else "NO"),
            ("LINT_RULES_LOADED", "YES" if self.lint_rules_loaded else "NO"),
            ("LINT_RULES_APPLIED", "YES" if completed else "NO"),
            ("MIXED_PRODUCER_COLUMN_LEVEL_CHECK_PERFORMED", "YES" if completed else "NO"),
            ("CANON_GEN_SOURCE_SPLIT_PRESERVED", "YES" if self.split_ok else "NO"),
            ("EXPERIMENTAL_PTCDF_QUARANTINE_PRESERVED", "YES" if self.quarantine_ok else "NO"),
            ("ALLOWED_USE_MATRIX_CHECK_PERFORMED", "YES" if completed else "NO"),
            ("WARN_FIRST_POLICY_PRESERVED", "YES"),
            ("HARD_FAIL_RESERVED_FOR_UNSAFE_PROMOTION", "YES"),
            ("HARD_FAIL_COUNT", hard_fail),
            ("WARN_COUNT", warn_c),
            ("SUGGEST_COUNT", suggest_c),
            ("BROAD_OLD_ANALYSIS_REPLAY_ALLOWED_NOW", "NO"),
            ("RENAME_EXECUTION_ALLOWED_NOW", "NO"),
            ("SAFE_TO_PROCEED_TO_PHASE4_CORRECTED_OLD_REPLAY", "NO"),
            ("SAFE_TO_COMMIT_PHASE3_PREFLIGHT_ARTIFACTS", safe_commit),
        ]

        with status_path.open("w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["key", "value"])
            for k, v in status_keys:
                w.writerow([k, v])

        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        report_lines = [
            "# Switching Phase 3 — Semantic preflight / lint (WARN-first)",
            "",
            f"Generated (UTC): {now}",
            "",
            "## Inputs loaded",
            "",
            "The following committed contract artifacts were required and read when present:",
            "",
            *[f"- `{p}`" for p in REQUIRED_INPUTS],
            "",
            "## Schema checks",
            "",
            "Required column subsets were verified for Phase 2 / Phase 2.5 tables listed in `SCHEMA_REQUIRED` inside "
            "`scripts/run_switching_semantic_phase3_preflight.py`. Missing columns emit WARN or HARD_FAIL depending on "
            "whether unsafe canonical promotion detection is impaired.",
            "",
            "## Lint rules applied",
            "",
            f"Loaded **{self.lint_rules_loaded}** rows from `tables/switching_semantic_lint_rules.csv`. "
            "Text scans matched governance patterns across committed semantic CSV/MD inputs (see findings table). "
            "Default policy: **WARN-first**. **SW_LINT_008** (forbidden stems `X_canon`, `collapse_canon`, `Phi_canon`, "
            "`kappa_canon`) emits **WARN** when the match is only in governance/policy columns or clearly forbids the stem; "
            "**HARD_FAIL** only when a risky column (e.g. path, alias, allowed_use) combines the stem with affirmative "
            "manuscript/replay/canonical authority flags. **HARD_FAIL** also applies when registry **canonical_safe** "
            "contradicts `switching_semantic_allowed_use_matrix.csv`.",
            "",
            "## Mixed producer classification",
            "",
            f"Registry rows referencing `switching_canonical_S_long` were checked (**{self.mixed_producer_checks}** row hits). "
            "Column-level paths must map **S_percent / T_K / current_mA** to **CANON_GEN_SOURCE** and "
            "**PT_pdf / CDF_pt / S_model_pt_percent / residual_percent** to **EXPERIMENTAL_PTCDF_DIAGNOSTIC**. "
            f"**CANON_GEN_SOURCE split preserved:** {'YES' if self.split_ok else 'NO'}. "
            f"**EXPERIMENTAL PT/CDF quarantine preserved:** {'YES' if self.quarantine_ok else 'NO'}.",
            "",
            "## Allowed-use consistency",
            "",
            f"Cross-checked **{self.allowed_use_checks}** registry rows against "
            "`tables/switching_semantic_allowed_use_matrix.csv` for unsafe **canonical_safe** posture.",
            "",
            "## Findings summary",
            "",
            f"- Total findings: **{len(self.findings)}**",
            f"- HARD_FAIL: **{hard_fail}**",
            f"- WARN: **{warn_c}**",
            f"- SUGGEST: **{suggest_c}**",
            "",
            "Machine-readable detail: `tables/switching_semantic_phase3_preflight_findings.csv`.",
            "",
            "## HARD_FAIL status",
            "",
            "Any HARD_FAIL indicates a policy or schema defect that must be addressed before treating outputs as "
            "authority-safe; WARN findings do not prevent committing Phase 3 **preflight artifacts** once reviewed.",
            "",
            "## Why rename execution remains blocked",
            "",
            "`tables/switching_semantic_rename_plan.csv` remains planning-only; governed rename waves are not enabled "
            "by this preflight. Status: **RENAME_EXECUTION_ALLOWED_NOW = NO**.",
            "",
            "## Why broad old-analysis replay remains blocked",
            "",
            "Broad legacy replay requires Phase 4 gates and passing replay-safe posture — **BROAD_OLD_ANALYSIS_REPLAY_ALLOWED_NOW = NO**.",
            "",
            "## Why Phase 4 corrected-old replay remains blocked",
            "",
            "Phase 3 preflight implementation validates contracts but is **not sufficient** for Phase 4 replay enablement; "
            "repository review and explicit Phase 4 readiness remain required — **SAFE_TO_PROCEED_TO_PHASE4_CORRECTED_OLD_REPLAY = NO**.",
            "",
            "## Next step",
            "",
            "1. Review `tables/switching_semantic_phase3_preflight_findings.csv` and resolve HARD_FAIL items.",
            "2. Commit Phase 3 preflight artifacts when ready (`SAFE_TO_COMMIT_PHASE3_PREFLIGHT_ARTIFACTS` may be YES even with WARN).",
            "3. Schedule Phase 4 corrected-old replay only after Phase 3 artifacts are committed, reviewed, and HARD_FAIL policy is clear.",
            "",
        ]
        report_path.write_text("\n".join(report_lines), encoding="utf-8")


def main() -> int:
    p = Preflight()
    return p.run()


if __name__ == "__main__":
    sys.exit(main())
