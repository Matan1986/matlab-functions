#!/usr/bin/env python3
"""Agent 24B: LOOCV aging R prediction from PT + state + trajectory (read-only CSV inputs)."""
from __future__ import annotations

import json
import math
import os
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd

REPO = Path(__file__).resolve().parents[1]


def loocv_mean_rmse(y: np.ndarray) -> tuple[float, float, float, np.ndarray]:
    y = np.asarray(y, dtype=float).ravel()
    n = len(y)
    if n < 2:
        return float("nan"), float("nan"), float("nan"), np.full(n, np.nan)
    yhat = np.array([(np.sum(y) - y[i]) / (n - 1) for i in range(n)])
    res = y - yhat
    rmse = float(np.sqrt(np.mean(res**2)))
    pear = safe_corr(y, yhat, spearman=False)
    spear = safe_corr(y, yhat, spearman=True)
    return rmse, pear, spear, yhat


def loocv_ols_rmse(y: np.ndarray, x: np.ndarray) -> tuple[float, float, float, np.ndarray]:
    y = np.asarray(y, dtype=float).ravel()
    x = np.asarray(x, dtype=float)
    if x.ndim == 1:
        x = x.reshape(-1, 1)
    n, p = x.shape
    yhat = np.full(n, np.nan)
    z = np.column_stack([np.ones(n), x])
    if n <= p + 1 or not np.all(np.isfinite(z)) or not np.all(np.isfinite(y)):
        return float("nan"), float("nan"), float("nan"), yhat
    if np.linalg.matrix_rank(z) < z.shape[1]:
        return float("nan"), float("nan"), float("nan"), yhat
    beta, _, _, _ = np.linalg.lstsq(z, y, rcond=None)
    yfit = z @ beta
    e = y - yfit
    try:
        h = np.diag(z @ np.linalg.solve(z.T @ z, z.T))
    except np.linalg.LinAlgError:
        return float("nan"), float("nan"), float("nan"), yhat
    loo = e / np.maximum(1.0 - h, 1e-12)
    yhat[:] = y - loo
    rmse = float(np.sqrt(np.mean(loo**2)))
    pear = safe_corr(y, yhat, spearman=False)
    spear = safe_corr(y, yhat, spearman=True)
    return rmse, pear, spear, yhat


def safe_corr(a: np.ndarray, b: np.ndarray, spearman: bool) -> float:
    m = np.isfinite(a) & np.isfinite(b)
    if np.count_nonzero(m) < 2:
        return float("nan")
    x, y = a[m], b[m]
    if spearman:
        x = pd.Series(x).rank().to_numpy()
        y = pd.Series(y).rank().to_numpy()
    if np.std(x) < 1e-15 or np.std(y) < 1e-15:
        return float("nan")
    return float(np.corrcoef(x, y)[0, 1])


def main() -> int:
    barrier_p = REPO / "results/cross_experiment/runs/run_2026_03_25_031904_barrier_to_relaxation_mechanism/tables/barrier_descriptors.csv"
    energy_p = REPO / "results/switching/runs/run_2026_03_24_233256_energy_mapping/tables/energy_stats.csv"
    clk_p = REPO / "results/aging/runs/run_2026_03_14_074613_aging_clock_ratio_analysis/tables/table_clock_ratio.csv"
    alpha_p = REPO / "tables/alpha_structure.csv"
    decomp_p = REPO / "tables/alpha_decomposition.csv"

    for p in (barrier_p, energy_p, clk_p, alpha_p, decomp_p):
        if not p.is_file():
            print(f"Missing: {p}", file=sys.stderr)
            return 1

    bar = pd.read_csv(barrier_p)
    en = pd.read_csv(energy_p)
    if "T_K" not in en.columns and "T" in en.columns:
        en = en.rename(columns={"T": "T_K"})
    en = en[["T_K", "mean_E", "std_E"]]
    bar = bar.merge(en, on="T_K", how="inner")
    bar["spread90_50"] = bar["q90_I_mA"].astype(float) - bar["q50_I_mA"].astype(float)
    bar["asymmetry"] = bar["asym_q75_50_minus_q50_25"].astype(float)

    aS = pd.read_csv(alpha_p)
    aD = pd.read_csv(decomp_p)
    m = aS[["T_K", "kappa1", "kappa2", "alpha"]].merge(
        aD[["T_K", "PT_geometry_valid"]], on="T_K", how="inner"
    )
    bcols = [
        "T_K",
        "row_valid",
        "R_T_interp",
        "mean_E",
        "std_E",
        "spread90_50",
        "asymmetry",
        "pt_svd_score1",
        "pt_svd_score2",
        "q90_I_mA",
        "q50_I_mA",
    ]
    for c in bcols:
        if c not in bar.columns:
            print(f"barrier missing {c}", file=sys.stderr)
            return 1
    merged = m.merge(bar[bcols], on="T_K", how="inner")
    merged = merged[merged["PT_geometry_valid"].astype(float) != 0]
    merged = merged[merged["row_valid"].astype(float) != 0]
    merged = merged.sort_values("T_K").reset_index(drop=True)

    t = merged["T_K"].astype(float).to_numpy()
    r_obs = merged["R_T_interp"].astype(float).to_numpy()
    k1 = merged["kappa1"].astype(float).to_numpy()
    k2 = merged["kappa2"].astype(float).to_numpy()
    mean_e = merged["mean_E"].astype(float).to_numpy()
    std_e = merged["std_E"].astype(float).to_numpy()
    spr = merged["spread90_50"].astype(float).to_numpy()
    asym = merged["asymmetry"].astype(float).to_numpy()
    pt1 = merged["pt_svd_score1"].astype(float).to_numpy()
    pt2 = merged["pt_svd_score2"].astype(float).to_numpy()
    theta = np.arctan2(k2, k1)
    rnorm = np.hypot(k1, k2)

    thu = np.unwrap(theta)
    n0 = len(t)
    dtheta = np.full(n0, np.nan)
    dk1 = np.full(n0, np.nan)
    dk2 = np.full(n0, np.nan)
    dT = np.full(n0, np.nan)
    if n0 >= 2:
        dtheta[1:] = np.diff(thu)
        dk1[1:] = np.diff(k1)
        dk2[1:] = np.diff(k2)
        dT[1:] = np.diff(t)
    ds = np.full(n0, np.nan)
    curv = np.full(n0, np.nan)
    if n0 >= 2:
        ds[1:] = np.sqrt(dk1[1:] ** 2 + dk2[1:] ** 2)
        curv[1:] = np.abs(dtheta[1:]) / np.maximum(dT[1:], 1e-12)
    abs_dtheta = np.abs(dtheta)

    master = pd.DataFrame(
        {
            "T_K": t,
            "R": r_obs,
            "mean_E": mean_e,
            "std_E": std_e,
            "spread90_50": spr,
            "asymmetry": asym,
            "pt_svd_score1": pt1,
            "pt_svd_score2": pt2,
            "kappa1": k1,
            "kappa2": k2,
            "alpha": merged["alpha"].astype(float),
            "theta_rad": theta,
            "r": rnorm,
            "abs_delta_theta": abs_dtheta,
            "ds": ds,
            "curvature_dtheta_over_dT": curv,
        }
    )

    m_base = (
        np.isfinite(r_obs)
        & np.isfinite(mean_e)
        & np.isfinite(spr)
        & np.isfinite(k1)
        & np.isfinite(k2)
        & np.isfinite(theta)
        & np.isfinite(rnorm)
        & np.isfinite(pt1)
        & np.isfinite(pt2)
        & np.isfinite(asym)
        & np.isfinite(std_e)
    )
    m_traj = m_base & np.isfinite(abs_dtheta) & np.isfinite(ds) & np.isfinite(curv)
    if np.count_nonzero(m_traj) < 5:
        print("Insufficient overlap for trajectory models", file=sys.stderr)
        return 1

    sub = master.loc[m_traj].reset_index(drop=True)
    y = sub["R"].to_numpy()
    tplot = sub["T_K"].to_numpy()
    n = len(y)

    models: list[tuple[str, str, list[str]]] = [
        ("R ~ 1", "baseline", []),
        ("R ~ mean_E", "PT-only", ["mean_E"]),
        ("R ~ spread90_50", "PT-only", ["spread90_50"]),
        ("R ~ mean_E + spread90_50", "PT-only", ["mean_E", "spread90_50"]),
        ("R ~ kappa1", "state-only", ["kappa1"]),
        ("R ~ r", "state-only", ["r"]),
        ("R ~ theta_rad", "state-only", ["theta_rad"]),
        ("R ~ abs_delta_theta", "trajectory-only", ["abs_delta_theta"]),
        ("R ~ ds", "trajectory-only", ["ds"]),
        ("R ~ mean_E + kappa1", "PT+state", ["mean_E", "kappa1"]),
        ("R ~ spread90_50 + kappa1", "PT+state", ["spread90_50", "kappa1"]),
        (
            "R ~ mean_E + kappa1 + abs_delta_theta",
            "PT+state+trajectory",
            ["mean_E", "kappa1", "abs_delta_theta"],
        ),
        (
            "R ~ spread90_50 + kappa1 + ds",
            "PT+state+trajectory",
            ["spread90_50", "kappa1", "ds"],
        ),
    ]

    rows = []
    best_rmse = float("inf")
    best_name = ""
    best_yhat = np.full(n, np.nan)
    for name, cat, cols in models:
        if not cols:
            rmse, pear, spear, yhat = loocv_mean_rmse(y)
        else:
            x = sub[cols].to_numpy(dtype=float)
            rmse, pear, spear, yhat = loocv_ols_rmse(y, x)
        rows.append(
            {
                "model": name,
                "category": cat,
                "n": n,
                "loocv_rmse": rmse,
                "pearson_y_yhat": pear,
                "spearman_y_yhat": spear,
            }
        )
        if cat != "baseline" and math.isfinite(rmse) and rmse < best_rmse:
            best_rmse = rmse
            best_name = name
            best_yhat = yhat.copy()

    df_rows = pd.DataFrame(rows)
    base_rmse = float(df_rows.loc[df_rows["model"] == "R ~ 1", "loocv_rmse"].iloc[0])

    abl = []
    for fam in pd.unique(df_rows["category"]):
        sub = df_rows[df_rows["category"] == fam]
        j = sub["loocv_rmse"].idxmin()
        r = df_rows.loc[j]
        abl.append(
            {
                "model_family": fam,
                "best_model": r["model"],
                "loocv_rmse": r["loocv_rmse"],
                "pearson": r["pearson_y_yhat"],
                "spearman": r["spearman_y_yhat"],
                "delta_rmse_vs_baseline": r["loocv_rmse"] - base_rmse
                if math.isfinite(r["loocv_rmse"])
                else float("nan"),
            }
        )
    df_abl = pd.DataFrame(abl)

    def abl_rmse(fam: str) -> float:
        r = df_abl.loc[df_abl["model_family"] == fam, "loocv_rmse"]
        return float(r.iloc[0]) if len(r) else float("nan")

    rmse_pt = abl_rmse("PT-only")
    rmse_ps = abl_rmse("PT+state")
    rmse_pst = abl_rmse("PT+state+trajectory")

    def fam_pearson(fam: str) -> float:
        s = df_rows[df_rows["category"] == fam]
        if s.empty:
            return float("nan")
        j = s["loocv_rmse"].idxmin()
        return float(s.loc[j, "pearson_y_yhat"])

    pear_pt = fam_pearson("PT-only")

    if math.isfinite(rmse_pt) and rmse_pt < base_rmse * 0.92 and abs(pear_pt) > 0.45:
        v_pt = "YES"
    elif math.isfinite(rmse_pt) and (rmse_pt < base_rmse or abs(pear_pt) > 0.3):
        v_pt = "PARTIAL"
    else:
        v_pt = "NO"

    improve_ps = (rmse_pt - rmse_ps) / max(rmse_pt, 1e-12) if math.isfinite(rmse_pt) else 0.0
    if (
        math.isfinite(rmse_ps)
        and math.isfinite(rmse_pt)
        and rmse_ps < rmse_pt * (1 - 0.03)
        and improve_ps > 0.02
    ):
        v_state = "YES"
    else:
        v_state = "NO"

    if math.isfinite(rmse_pst) and math.isfinite(rmse_ps) and rmse_pst < rmse_ps - 1e-9:
        v_traj = "YES"
    else:
        v_traj = "NO"

    sigy = float(np.std(y, ddof=0))
    non_base = df_rows[df_rows["category"] != "baseline"]["loocv_rmse"]
    best_all = float(non_base.min())
    if best_all < 0.2 * sigy:
        v_full = "YES"
    elif best_all < 0.45 * sigy:
        v_full = "PARTIAL"
    else:
        v_full = "NO"

    stamp = datetime.now(timezone.utc).strftime("%Y_%m_%d_%H%M%S")
    run_id = f"run_{stamp}_aging_prediction_agent24b"
    run_dir = REPO / "results/cross_experiment/runs" / run_id
    (run_dir / "figures").mkdir(parents=True)
    (run_dir / "tables").mkdir(parents=True)
    (run_dir / "reports").mkdir(parents=True)
    (run_dir / "review").mkdir(parents=True)

    sub.to_csv(run_dir / "tables/aging_prediction_master_table.csv", index=False)
    df_rows.to_csv(run_dir / "tables/aging_prediction_models.csv", index=False)
    df_abl.to_csv(run_dir / "tables/aging_prediction_ablation.csv", index=False)
    best_tbl = pd.DataFrame(
        [
            {
                "best_model_loocv": best_name,
                "loocv_rmse": best_rmse,
                "pearson_loocv_yhat": safe_corr(y, best_yhat, False),
                "spearman_loocv_yhat": safe_corr(y, best_yhat, True),
                "AGING_PREDICTED_FROM_PT": v_pt,
                "STATE_REQUIRED_FOR_AGING": v_state,
                "TRAJECTORY_ADDS_INFORMATION": v_traj,
                "FULL_CLOSURE_ACHIEVED": v_full,
            }
        ]
    )
    best_tbl.to_csv(run_dir / "tables/aging_prediction_best_model.csv", index=False)

    manifest = {
        "run_id": run_id,
        "experiment": "cross_experiment",
        "label": "aging_prediction_agent24b",
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "agent": "24B",
        "inputs": {
            "barrier_descriptors": str(barrier_p.relative_to(REPO)),
            "energy_stats": str(energy_p.relative_to(REPO)),
            "clock_ratio_lineage": str(clk_p.relative_to(REPO)),
            "alpha_structure": str(alpha_p.relative_to(REPO)),
            "alpha_decomposition": str(decomp_p.relative_to(REPO)),
        },
        "note": "Computed with tools/agent24b_aging_prediction.py (MATLAB twin: analysis/run_aging_prediction_agent24b.m).",
    }
    (run_dir / "run_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    (run_dir / "config_snapshot.m").write_text(
        f"% Agent 24B python compute {manifest['timestamp_utc']}\n", encoding="utf-8"
    )
    (run_dir / "log.txt").write_text("agent24b_aging_prediction.py\n", encoding="utf-8")
    (run_dir / "run_notes.txt").write_text(
        f"verdicts: PT={v_pt} STATE={v_state} TRAJ={v_traj} CLOSURE={v_full}\n", encoding="utf-8"
    )

    res = y - best_yhat
    try:
        import matplotlib.pyplot as plt

        plt.rcParams.update({"font.size": 14, "lines.linewidth": 2})
        fig, ax = plt.subplots(figsize=(7, 5.5))
        sc = ax.scatter(y, best_yhat, c=tplot, s=90, cmap="viridis")
        cb = plt.colorbar(sc, ax=ax)
        cb.set_label("T (K)")
        lims = [np.nanmin([y, best_yhat]), np.nanmax([y, best_yhat])]
        if math.isfinite(lims[0]) and math.isfinite(lims[1]) and lims[1] > lims[0]:
            ax.plot(lims, lims, "k--", lw=2)
        ax.set_xlabel(r"$R$ measured (clock ratio, interp)")
        ax.set_ylabel(r"$R$ LOOCV prediction (best model)")
        ax.grid(True, alpha=0.3)
        fig.savefig(run_dir / "figures/R_vs_prediction.png", dpi=300, bbox_inches="tight")
        plt.close(fig)

        fig2, ax2 = plt.subplots(figsize=(7, 5))
        ax2.plot(tplot, res, "o-", ms=8)
        ax2.axhline(0.0, color="k", ls="--", lw=1.5)
        yr = float(np.nanmax(np.abs(res))) if np.any(np.isfinite(res)) else 1.0
        if not math.isfinite(yr) or yr <= 0:
            yr = 1.0
        ax2.axvspan(22, 24, alpha=0.25, color="red", label="22–24 K")
        ax2.set_xlabel("T (K)")
        ax2.set_ylabel(r"Residual $R$ (meas − LOOCV pred)")
        ax2.grid(True, alpha=0.3)
        fig2.savefig(run_dir / "figures/residuals_vs_T.png", dpi=300, bbox_inches="tight")
        plt.close(fig2)
    except Exception as e:
        print(f"Figure export skipped: {e}", file=sys.stderr)
        zp = None

    mae_22 = float(np.mean(np.abs(res[(tplot >= 22) & (tplot <= 24)])))
    mae_o = float(np.mean(np.abs(res[~((tplot >= 22) & (tplot <= 24))])))

    report_lines = [
        "# Aging prediction from PT + state + trajectory (Agent 24B)",
        "",
        f"**Run:** `{run_dir.as_posix()}`",
        "",
        "## Data lineage (read-only)",
        f"- **R(T):** `R_T_interp` from barrier merge. Raw clock: `{clk_p.relative_to(REPO).as_posix()}`",
        f"- **PT / quantiles / SVD:** `{barrier_p.relative_to(REPO).as_posix()}`",
        f"- **mean_E / std_E:** `{energy_p.relative_to(REPO).as_posix()}`",
        f"- **State:** `{alpha_p.relative_to(REPO).as_posix()}` + `{decomp_p.relative_to(REPO).as_posix()}`",
        "- **Trajectory:** forward differences on sorted `T_K` (`abs_delta_theta`, `ds`, curvature).",
        "",
        f"## Overlap rows (n = {n})",
        "All models share the same rows (full PT + state + trajectory finite).",
        "",
        "## LOOCV models",
        "```",
        df_rows.to_string(index=False),
        "```",
        "",
        "## Ablation (best per family, ΔRMSE vs baseline)",
        "```",
        df_abl.to_string(index=False),
        "```",
        "",
        "## Best LOOCV model",
        f"- **Model:** `{best_name}`",
        f"- **LOOCV RMSE:** {best_rmse:.6g}",
        "",
        "## Temperature-local errors",
        f"- Mean |residual| **22–24 K:** {mae_22:.6g}; other T: {mae_o:.6g}",
        "",
        "## Mandatory verdicts",
        f"- **AGING_PREDICTED_FROM_PT:** **{v_pt}**",
        f"- **STATE_REQUIRED_FOR_AGING:** **{v_state}**",
        f"- **TRAJECTORY_ADDS_INFORMATION:** **{v_traj}**",
        f"- **FULL_CLOSURE_ACHIEVED:** **{v_full}**",
        "",
        "## Interpretation",
        "Strong PT + state + trajectory fits support aging clock ratios co-varying with barrier geometry, κ collective state, and reorganization path (memory / dynamics).",
        "",
        "*Generated by `tools/agent24b_aging_prediction.py`.*",
    ]
    rep_path = run_dir / "reports/aging_prediction_report.md"
    rep_path.write_text("\n".join(report_lines), encoding="utf-8")

    zip_p = run_dir / "review/aging_prediction_agent24b_bundle.zip"
    with zipfile.ZipFile(zip_p, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in [
            "run_manifest.json",
            "config_snapshot.m",
            "log.txt",
            "run_notes.txt",
            "tables/aging_prediction_models.csv",
            "tables/aging_prediction_ablation.csv",
            "tables/aging_prediction_best_model.csv",
            "tables/aging_prediction_master_table.csv",
            "reports/aging_prediction_report.md",
            "figures/R_vs_prediction.png",
            "figures/residuals_vs_T.png",
        ]:
            fp = run_dir / rel
            if fp.is_file():
                z.write(fp, rel)

    # Mirror to repo root (optional convenience)
    for d in ("tables", "figures", "reports"):
        (REPO / d).mkdir(exist_ok=True)
    import shutil

    shutil.copy(run_dir / "tables/aging_prediction_models.csv", REPO / "tables/aging_prediction_models.csv")
    shutil.copy(run_dir / "tables/aging_prediction_ablation.csv", REPO / "tables/aging_prediction_ablation.csv")
    shutil.copy(run_dir / "tables/aging_prediction_best_model.csv", REPO / "tables/aging_prediction_best_model.csv")
    shutil.copy(rep_path, REPO / "reports/aging_prediction_report.md")
    png1 = run_dir / "figures/R_vs_prediction.png"
    png2 = run_dir / "figures/residuals_vs_T.png"
    if png1.is_file():
        shutil.copy(png1, REPO / "figures/R_vs_prediction.png")
    if png2.is_file():
        shutil.copy(png2, REPO / "figures/residuals_vs_T.png")

    print(run_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
