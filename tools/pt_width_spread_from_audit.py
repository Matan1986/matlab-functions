#!/usr/bin/env python3
"""
Load PT_matrix.csv from PT robustness audit child runs, compute spread observables,
write a new switching run folder. Use when MATLAB is unavailable.

Canonical entry for interactive use: Switching/analysis/run_pt_width_spread_observable_analysis.m
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import subprocess
import sys
import zipfile
from datetime import datetime
from pathlib import Path

import numpy as np


def parse_current_headers(colnames: list[str]) -> np.ndarray:
    currents = []
    for name in colnames:
        if name == "T_K":
            continue
        if not name.startswith("Ith_") or not name.endswith("_mA"):
            raise ValueError(f"Bad column {name}")
        mid = name[len("Ith_") : -len("_mA")]
        for cand in (mid, mid.replace("_", "."), mid.replace("_", "")):
            try:
                currents.append(float(cand))
                break
            except ValueError:
                continue
        else:
            raise ValueError(f"Cannot parse current from {name}")
    return np.asarray(currents, dtype=float)


def load_pt_matrix(path: Path) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)
        rows = [r for r in reader if r]
    I = parse_current_headers(header)
    order = np.argsort(I)
    I = I[order]
    T_list = []
    PT_list = []
    for r in rows:
        T_list.append(float(r[0]))
        vals = np.array([float(x) if str(x).strip() != "" else np.nan for x in r[1:]], dtype=float)
        vals = vals[order]
        PT_list.append(vals)
    T = np.asarray(T_list)
    PT = np.vstack(PT_list)
    si = np.argsort(T)
    return T[si], I, PT[si, :]


def trapz(y: np.ndarray, x: np.ndarray) -> float:
    return float(np.trapz(y, x))


def cumtrapz_p(I: np.ndarray, p: np.ndarray) -> np.ndarray:
    c = np.zeros_like(I, dtype=float)
    for i in range(1, len(I)):
        c[i] = c[i - 1] + 0.5 * (p[i] + p[i - 1]) * (I[i] - I[i - 1])
    return c


def quantile_icdf(I: np.ndarray, cdf: np.ndarray, q: float) -> float:
    m = np.isfinite(cdf) & np.isfinite(I)
    c = cdf[m]
    x = I[m]
    if len(c) < 2:
        return float("nan")
    # Collapse CDF plateaus (duplicate c) by averaging I — matches MATLAB post-process.
    ucu, inv = np.unique(c, return_inverse=True)
    ux_agg = np.bincount(inv, weights=x, minlength=len(ucu)) / np.bincount(inv, minlength=len(ucu))
    qn = min(max(q, 0.0), 1.0)
    return float(np.interp(qn, ucu, ux_agg))


def spread_observables(I: np.ndarray, p_raw: np.ndarray) -> dict[str, float]:
    keys = (
        "rms_std_mA", "iqr_mA", "w50_mass_mA", "w60_mass_mA", "mad_mA",
        "mad_scaled_mA", "trim_rms_mA", "half_mass_width_mA",
    )
    out = {k: float("nan") for k in keys}
    m = np.isfinite(I) & np.isfinite(p_raw)
    I = I[m]
    p = p_raw[m]
    if len(I) < 2:
        return out
    p = np.maximum(p, 0.0)
    area = trapz(p, I)
    if not math.isfinite(area) or area <= 0:
        return out
    p = p / area
    mu = trapz(I * p, I)
    var = trapz((I - mu) ** 2 * p, I)
    out["rms_std_mA"] = math.sqrt(max(var, 0.0))
    cdf = cumtrapz_p(I, p)
    cmax = cdf[-1]
    if cmax <= 0:
        return out
    cdf = cdf / cmax
    q25 = quantile_icdf(I, cdf, 0.25)
    q50 = quantile_icdf(I, cdf, 0.50)
    q75 = quantile_icdf(I, cdf, 0.75)
    q20 = quantile_icdf(I, cdf, 0.20)
    q80 = quantile_icdf(I, cdf, 0.80)
    q05 = quantile_icdf(I, cdf, 0.05)
    q95 = quantile_icdf(I, cdf, 0.95)
    out["iqr_mA"] = q75 - q25
    out["w50_mass_mA"] = q75 - q25
    out["w60_mass_mA"] = q80 - q20
    mad = trapz(np.abs(I - q50) * p, I)
    out["mad_mA"] = mad
    out["mad_scaled_mA"] = 1.4826 * mad
    mask = (I >= q25) & (I <= q75)
    if np.count_nonzero(mask) >= 2:
        Ic = I[mask]
        pc = p[mask]
        ac = trapz(pc, Ic)
        if ac > 0:
            pc = pc / ac
            muc = trapz(Ic * pc, Ic)
            vc = trapz((Ic - muc) ** 2 * pc, Ic)
            out["half_mass_width_mA"] = math.sqrt(max(vc, 0.0))
    if all(math.isfinite(x) for x in (q05, q95)) and q95 > q05:
        mt = (I >= q05) & (I <= q95)
        if np.count_nonzero(mt) >= 2:
            It = I[mt]
            pt = p[mt]
            at = trapz(pt, It)
            if at > 0:
                pt = pt / at
                mut = trapz(It * pt, It)
                vt = trapz((It - mut) ** 2 * pt, It)
                out["trim_rms_mA"] = math.sqrt(max(vt, 0.0))
    return out


def l2_tertile_fractions(I: np.ndarray, dp: np.ndarray) -> tuple[float, float, float]:
    n = len(I)
    if n < 3:
        return (float("nan"), float("nan"), float("nan"))
    t1 = n // 3
    t2 = 2 * n // 3
    w = dp ** 2
    s = float(np.sum(w)) + 1e-30
    low = float(np.sum(w[:t1]))
    mid = float(np.sum(w[t1:t2]))
    high = float(np.sum(w[t2:]))
    return low / s, mid / s, high / s


def git_commit(repo: Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo), "rev-parse", "HEAD"],
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"


def pearson_r(a: np.ndarray, b: np.ndarray) -> float:
    m1 = np.isfinite(a) & np.isfinite(b)
    if np.count_nonzero(m1) < 2:
        return float("nan")
    x = a[m1]
    y = b[m1]
    if np.std(x) < 1e-15 or np.std(y) < 1e-15:
        return float("nan")
    return float(np.corrcoef(x, y)[0, 1])


def spearman_r(a: np.ndarray, b: np.ndarray) -> float:
    m1 = np.isfinite(a) & np.isfinite(b)
    if np.count_nonzero(m1) < 2:
        return float("nan")
    x = a[m1]
    y = b[m1]
    rx = np.argsort(np.argsort(x)).astype(float)
    ry = np.argsort(np.argsort(y)).astype(float)
    return pearson_r(rx, ry)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    ap.add_argument("--audit-dir", type=Path, default=None)
    ap.add_argument("--t-max", type=float, default=30.0)
    args = ap.parse_args()
    repo = args.repo_root.resolve()
    audit_dir = args.audit_dir or (
        repo / "results/switching/runs/run_2026_03_25_013346_pt_energy_robustness_audit"
    )
    child_csv = audit_dir / "tables/pt_variant_child_runs.csv"
    if not child_csv.is_file():
        print(f"Missing {child_csv}", file=sys.stderr)
        return 1

    variants = []
    with child_csv.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            variants.append(
                {
                    "variant_key": row["variant_key"].strip(),
                    "variant_label": row["variant_label"].strip(),
                    "child_run_dir": Path(row["child_run_dir"].strip()),
                }
            )

    ref_key = "canonical"
    matrices: dict[str, dict] = {}
    I_ref = None
    for v in variants:
        vk = v["variant_key"]
        pt_path = v["child_run_dir"] / "tables" / "PT_matrix.csv"
        T, I, PT = load_pt_matrix(pt_path)
        if I_ref is None:
            I_ref = I
        elif np.max(np.abs(I - I_ref)) > 1e-9:
            print("Current grid mismatch", vk, file=sys.stderr)
            return 1
        matrices[vk] = {"T": T, "I": I, "PT": PT}

    sets = [set(matrices[k]["T"].tolist()) for k in matrices]
    common_T = sorted(set.intersection(*sets))
    t_max = args.t_max
    common_T = [t for t in common_T if t <= t_max + 1e-9]

    def row_valid(PTrow: np.ndarray) -> bool:
        if not np.all(np.isfinite(PTrow)):
            return False
        if np.max(PTrow) <= 0:
            return False
        return trapz(np.maximum(PTrow, 0), I_ref) > 0

    usable_T: list[float] = []
    for t in common_T:
        ok = True
        for k in matrices:
            idx = np.where(np.abs(matrices[k]["T"] - t) < 1e-9)[0]
            if len(idx) != 1:
                ok = False
                break
            if not row_valid(matrices[k]["PT"][idx[0], :]):
                ok = False
                break
        if ok:
            usable_T.append(t)

    metric_names = [
        "rms_std_mA", "iqr_mA", "w50_mass_mA", "w60_mass_mA", "mad_mA",
        "mad_scaled_mA", "trim_rms_mA", "half_mass_width_mA",
    ]

    rows_comp = []
    for vk in matrices:
        M = matrices[vk]
        for t in usable_T:
            idx = int(np.where(np.abs(M["T"] - t) < 1e-9)[0])
            obs = spread_observables(M["I"], M["PT"][idx, :])
            row = {"variant_key": vk, "T_K": t, **{k: obs[k] for k in metric_names}}
            rows_comp.append(row)

    ts = datetime.now().strftime("%Y_%m_%d_%H%M%S")
    run_id = f"run_{ts}_pt_width_spread_observable"
    run_dir = repo / "results/switching/runs" / run_id
    for sub in ("figures", "tables", "reports", "review"):
        (run_dir / sub).mkdir(parents=True, exist_ok=True)

    comp_path = run_dir / "tables/spread_observable_comparison.csv"
    with comp_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["variant_key", "T_K", *metric_names])
        w.writeheader()
        for row in rows_comp:
            w.writerow(row)

    T_arr = np.asarray(usable_T, dtype=float)
    refM = matrices[ref_key]

    def series_for(vk: str, m: str) -> np.ndarray:
        M = matrices[vk]
        out = np.zeros(len(usable_T))
        for j, t in enumerate(usable_T):
            ii = int(np.where(np.abs(M["T"] - t) < 1e-9)[0])
            out[j] = spread_observables(M["I"], M["PT"][ii, :])[m]
        return out

    robust_rows = []
    for vk in matrices:
        row: dict = {"variant_key": vk}
        for m in metric_names:
            b0 = series_for(ref_key, m)
            b1 = series_for(vk, m)
            rel = np.abs(b1 - b0) / np.maximum(np.abs(b0), 1e-12)
            fin = np.isfinite(rel)
            row[f"pearson_vs_canonical_{m}"] = pearson_r(b0, b1)
            row[f"spearman_vs_canonical_{m}"] = spearman_r(b0, b1)
            row[f"max_rel_dev_{m}"] = float(np.max(rel[fin])) if np.any(fin) else float("nan")
            row[f"median_rel_dev_{m}"] = float(np.median(rel[fin])) if np.any(fin) else float("nan")
            i_peak0 = int(np.nanargmax(b0))
            i_peak1 = int(np.nanargmax(b1))
            row[f"peak_T_canonical_{m}"] = float(T_arr[i_peak0])
            row[f"peak_T_variant_{m}"] = float(T_arr[i_peak1])
            row[f"peak_T_agree_{m}"] = int(abs(T_arr[i_peak0] - T_arr[i_peak1]) < 1e-6)
            d0 = np.diff(b0)
            d1 = np.diff(b1)
            agree = np.sum(
                (np.sign(d0) == np.sign(d1))
                | ((np.abs(d0) < 1e-12) & (np.abs(d1) < 1e-12))
            )
            row[f"step_trend_agree_frac_{m}"] = float(agree / max(len(d0), 1))

            def rel_at(target: float) -> float:
                j = int(np.argmin(np.abs(T_arr - target)))
                if abs(T_arr[j] - target) > 0.51:
                    return float("nan")
                return float(rel[j]) if fin[j] else float("nan")

            row[f"rel_dev_22K_{m}"] = rel_at(22.0)
            band = [j for j in range(len(T_arr)) if 28.0 <= T_arr[j] <= 30.0]
            row[f"max_rel_dev_28_30K_{m}"] = (
                float(np.max(rel[band])) if band and np.any(fin[band]) else float("nan")
            )
        robust_rows.append(row)

    rob_fields = ["variant_key"]
    for m in metric_names:
        rob_fields.extend(
            [
                f"pearson_vs_canonical_{m}",
                f"spearman_vs_canonical_{m}",
                f"max_rel_dev_{m}",
                f"median_rel_dev_{m}",
                f"peak_T_canonical_{m}",
                f"peak_T_variant_{m}",
                f"peak_T_agree_{m}",
                f"step_trend_agree_frac_{m}",
                f"rel_dev_22K_{m}",
                f"max_rel_dev_28_30K_{m}",
            ]
        )
    rob_path = run_dir / "tables/spread_observable_robustness_metrics.csv"
    with rob_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=rob_fields)
        w.writeheader()
        for row in robust_rows:
            w.writerow(row)

    loc_rows = []
    worst_vk = "smooth_w7"
    if worst_vk in matrices and ref_key in matrices:
        t_tgt = 22.0
        for vk in (worst_vk, "sgolay_w5", "smooth_w3", "no_monotone_cdf"):
            if vk not in matrices:
                continue
            M = matrices[vk]
            R = matrices[ref_key]
            idx = int(np.where(np.abs(M["T"] - t_tgt) < 1e-9)[0])
            ir = int(np.where(np.abs(R["T"] - t_tgt) < 1e-9)[0])
            p0 = R["PT"][ir, :]
            p1 = M["PT"][idx, :]
            if not (np.all(np.isfinite(p0)) and np.all(np.isfinite(p1))):
                continue
            dp = p1 - p0
            low, mid, high = l2_tertile_fractions(I_ref, dp)
            loc_rows.append(
                {
                    "reference_variant": ref_key,
                    "compare_variant": vk,
                    "T_K": t_tgt,
                    "frac_l2_lowI": low,
                    "frac_l2_midI": mid,
                    "frac_l2_highI": high,
                    "sum_dp_pos": float(np.sum(dp[dp > 0])),
                    "sum_dp_neg": float(np.sum(dp[dp < 0])),
                }
            )
    loc_path = run_dir / "tables/spread_sensitivity_localization_22K.csv"
    if loc_rows:
        with loc_path.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(loc_rows[0].keys()))
            w.writeheader()
            w.writerows(loc_rows)

    def worst_for(m: str) -> tuple[str, float]:
        best = ("", 0.0)
        for row in robust_rows:
            if row["variant_key"] == ref_key:
                continue
            v = float(row[f"max_rel_dev_{m}"])
            if math.isfinite(v) and v > best[1]:
                best = (row["variant_key"], v)
        return best

    try:
        import matplotlib.pyplot as plt

        base_name = "spread_observable_comparison"
        fig, axes = plt.subplots(4, 1, figsize=(10, 14), sharex=True)
        cols = plt.cm.tab10(np.linspace(0, 1, len(matrices)))
        plot_metrics = ["rms_std_mA", "iqr_mA", "mad_scaled_mA", "trim_rms_mA"]
        titles = [
            "RMS width sqrt(var(I)) (mA)",
            "Interquantile IQR = Q75−Q25 (mA)",
            "MAD scale 1.4826·E[|I−median|] (mA)",
            "Trimmed RMS inside 5–95% mass (mA)",
        ]
        vk_order = [v["variant_key"] for v in variants]
        for ax, pm, tit in zip(axes, plot_metrics, titles):
            for ic, vk in enumerate(vk_order):
                y = series_for(vk, pm)
                ax.plot(T_arr, y, "-o", color=cols[ic], lw=2.2, ms=4, label=vk)
            ax.set_ylabel("mA")
            ax.grid(True, alpha=0.3)
            ax.legend(loc="best", fontsize=9)
            ax.tick_params(labelsize=11)
            ax.set_title(tit, fontsize=12)
        axes[-1].set_xlabel("Temperature T (K)", fontsize=12)
        fig.suptitle("P_T spread observables vs T (common valid rows, T≤30 K)", fontsize=13)
        fig.tight_layout()
        fig.savefig(run_dir / f"figures/{base_name}.png", dpi=300, bbox_inches="tight")
        fig.savefig(run_dir / f"figures/{base_name}.pdf", bbox_inches="tight")
        plt.close(fig)
    except ImportError:
        pass

    iqr_worst = worst_for("iqr_mA")[1]
    rms_worst = worst_for("rms_std_mA")[1]
    trim_worst = worst_for("trim_rms_mA")[1]

    if math.isfinite(iqr_worst) and math.isfinite(rms_worst) and iqr_worst < 0.85 * rms_worst:
        grade = "B"
        rec = (
            "**Recommendation:** Prefer **IQR (Q75−Q25)** / **central 50% mass width** as the primary P_T spread readout in I-space: "
            "under the audited extraction variants it shows materially lower max relative deviation vs canonical than RMS width while preserving a direct CDF interpretation of the switching mass."
        )
    elif math.isfinite(trim_worst) and trim_worst < rms_worst:
        grade = "B-trim"
        rec = (
            "**Recommendation:** If a second-moment width is required, **trimmed RMS (5–95% mass)** moderates tail-driven inflation vs full RMS, though smoothing sensitivity remains."
        )
    else:
        grade = "C"
        rec = (
            "**Conclusion (C):** All tested spread metrics remain materially extraction-sensitive when smoothing changes; treat width-like P_T numbers as **qualitative** unless extraction and/or the I grid are stabilized."
        )

    report_lines = [
        "# P_T width sensitivity and spread-observable robustness",
        "",
        "## Source audit",
        f"- Consumed child runs from `{audit_dir}` (`pt_variant_child_runs.csv`).",
        f"- New run directory: `{run_dir}`",
        "",
        "## Usable temperature overlap",
        f"- Common T (K) with finite P_T on the shared I grid for **all** variants, T≤{t_max:g} K:",
        f"  `{usable_T}`",
        f"- Count: **{len(usable_T)}** temperatures.",
        "",
        "## Diagnosis (where sensitivity comes from)",
        "",
        "### Variant drivers (audit metrics + this table)",
        "- **Dominant:** **`smooth_w7`** — max relative change in canonical `std_threshold_mA` **≈1.58×** vs baseline (`pt_robustness_metrics_by_variant.csv`).",
        "- **Substantial:** **`sgolay_w5`**, **`smooth_w3`** — max rel std **≈0.55** and **≈0.54**.",
        "- **Moderate:** **`no_monotone_cdf`** — max rel std **≈0.23** (reshapes nonnegative derivative mass without destroying mean ranking).",
        "- **Negligible here:** **`minpts_7`** — identical P_T to canonical on this map.",
        "",
        "### Mechanism",
        "- P_T is **dS/dI** of **smoothed** normalized S on a **sparse current grid**; wider/narrower smoothers move nonnegative derivative mass between bins.",
        "- **RMS width** weights **(I−⟨I⟩)²** and reacts strongly when shoulders/tails of P_T move — consistent with large **row L2** in the audit for smooth_w7/sgolay.",
    ]
    if loc_rows:
        wrow = next((r for r in loc_rows if r["compare_variant"] == "smooth_w7"), None)
        if wrow:
            report_lines.extend(
                [
                    f"- **22 K localization (`smooth_w7` vs canonical`):** squared ΔP_T is split across coarse **I-bin tertiles** as "
                    f"low-I **{wrow['frac_l2_lowI']:.3f}**, mid **{wrow['frac_l2_midI']:.3f}**, high-I **{wrow['frac_l2_highI']:.3f}** of ||ΔP_T||₂² "
                    "(tertiles = thirds of the **index-ordered** I samples, appropriate for this 7-point axis).",
                ]
            )

    report_lines.extend(
        [
            "",
            "## Spread observable robustness (vs canonical series on usable overlap)",
            "",
        ]
    )
    for m in metric_names:
        wvk, wv = worst_for(m)
        sp_vals = [
            float(r[f"spearman_vs_canonical_{m}"])
            for r in robust_rows
            if r["variant_key"] != ref_key
        ]
        sp_min = min((x for x in sp_vals if math.isfinite(x)), default=float("nan"))
        report_lines.append(
            f"- **{m}**: worst `{wvk}` max rel dev **{wv:.3f}**; min Spearman vs canonical **{sp_min:.3f}**."
        )

    report_lines.extend(
        [
            "",
            "## Recommendation class",
            f"- Assigned: **{grade}**.",
            "",
            rec,
            "",
            "## Visualization choices",
            "- Curves: 6 variants per panel (≤6 → legend).",
            "- Discrete colors (tab10); no colormap for line families.",
            "- No extra smoothing beyond each child extraction.",
            "",
            "## Artifacts",
            f"- `tables/spread_observable_comparison.csv`",
            f"- `tables/spread_observable_robustness_metrics.csv`",
            f"- `tables/spread_sensitivity_localization_22K.csv` (if generated)",
            f"- `figures/spread_observable_comparison.png` / `.pdf`",
            f"- `review/pt_width_sensitivity_bundle.zip`",
        ]
    )
    report_path = run_dir / "reports/pt_width_sensitivity_report.md"
    report_path.write_text("\n".join(report_lines), encoding="utf-8")

    manifest = {
        "run_id": run_id,
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "experiment": "switching",
        "label": "pt_width_spread_observable",
        "git_commit": git_commit(repo),
        "tool": "tools/pt_width_spread_from_audit.py",
        "source_audit_run": str(audit_dir),
        "usable_T_K": usable_T,
    }
    (run_dir / "run_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    (run_dir / "config_snapshot.m").write_text(
        f"% Auto snapshot\n% audit_dir = '{audit_dir.as_posix()}'\n% t_max_K = {t_max}\n",
        encoding="utf-8",
    )
    (run_dir / "log.txt").write_text(
        f"{manifest['timestamp']} pt_width_spread_from_audit.py completed\n", encoding="utf-8"
    )
    (run_dir / "run_notes.txt").write_text(
        "Post-processed existing PT robustness child runs; no barrier map re-extraction.\n", encoding="utf-8"
    )

    zip_path = run_dir / "review/pt_width_sensitivity_bundle.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for folder, globs in (("tables", ("*.csv",)), ("reports", ("*.md",)), ("figures", ("*.png", "*.pdf"))):
            d = run_dir / folder
            if not d.is_dir():
                continue
            for pat in globs:
                for fp in d.glob(pat):
                    zf.write(fp, arcname=f"{folder}/{fp.name}")
        for name in ("run_manifest.json", "config_snapshot.m", "log.txt", "run_notes.txt"):
            p = run_dir / name
            if p.is_file():
                zf.write(p, arcname=name)

    print(str(run_dir))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
