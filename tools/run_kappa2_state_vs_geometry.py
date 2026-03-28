"""
Agent 19A: kappa2 state vs geometry — read-only merge of existing CSVs.
Writes: tables/kappa2_state_vs_geometry.csv, figures/kappa2_vs_shape.png, reports/kappa2_state_geometry_report.md
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import numpy as np

try:
    import pandas as pd
    from scipy import stats
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError as e:
    print("Requires pandas, scipy, matplotlib:", e, file=sys.stderr)
    sys.exit(1)


REPO = Path(__file__).resolve().parents[1]


def safe_corr(x: np.ndarray, y: np.ndarray):
    m = np.isfinite(x) & np.isfinite(y)
    n = int(np.sum(m))
    if n < 3:
        return np.nan, np.nan, n
    a, b = x[m], y[m]
    r_p, _ = stats.pearsonr(a, b)
    r_s, _ = stats.spearmanr(a, b)
    return float(r_p), float(r_s), n


def loocv_linear_rmse_pearson(X: np.ndarray, y: np.ndarray):
    """X: n x p design including intercept column; OLS LOOCV."""
    n, p = X.shape
    if n < p + 1 or n < 3:
        return np.nan, np.nan
    XtX = X.T @ X
    try:
        XtX_inv = np.linalg.inv(XtX)
    except np.linalg.LinAlgError:
        XtX_inv = np.linalg.pinv(XtX)
    beta = XtX_inv @ (X.T @ y)
    yhat = X @ beta
    H = X @ XtX_inv @ X.T
    h = np.diag(H)
    denom = 1.0 - h
    if np.any(np.abs(denom) < 1e-15):
        return np.nan, np.nan
    y_loo = (yhat - h * y) / denom
    rmse = float(np.sqrt(np.mean((y - y_loo) ** 2)))
    r = float(np.corrcoef(y, y_loo)[0, 1]) if np.std(y_loo) > 0 else np.nan
    return rmse, r


def main():
    rs_path = REPO / "results/switching/runs/run_2026_03_25_043610_kappa_phi_temperature_structure_test/tables/residual_rank_structure_vs_T.csv"
    pt_path = REPO / "results/switching/runs/run_2026_03_25_013849_pt_robust_minpts7/tables/PT_summary.csv"
    bd_path = REPO / "results/cross_experiment/runs/run_2026_03_25_031904_barrier_to_relaxation_mechanism/tables/barrier_descriptors.csv"
    thr_path = REPO / "results/switching/runs/run_2026_03_24_013519_switching_threshold_residual_structure/tables/switching_threshold_residual_metrics_vs_temperature.csv"
    spec_path = REPO / "results/switching/runs/run_2026_03_25_043610_kappa_phi_temperature_structure_test/tables/residual_rank_spectrum.csv"

    rs = pd.read_csv(rs_path)
    rs = rs[rs["subset"].astype(str) == "T_le_30"].copy()
    rs = rs.rename(
        columns={
            "kappa": "kappa1",
            "rel_orth_leftover_norm": "kappa2",
        }
    )

    pt = pd.read_csv(pt_path)
    bd = pd.read_csv(bd_path)
    thr = pd.read_csv(thr_path)
    spec = pd.read_csv(spec_path)

    df = rs.merge(pt, on="T_K", how="left")
    df = df.merge(
        bd[
            [
                "T_K",
                "median_I_mA",
                "q50_I_mA",
                "q75_I_mA",
                "q90_I_mA",
                "q25_I_mA",
                "iq75_25_mA",
                "iq90_10_mA",
                "asym_q75_50_minus_q50_25",
                "skewness_quantile",
            ]
        ],
        on="T_K",
        how="left",
    )
    df = df.merge(
        thr[
            [
                "T_K",
                "residual_rmse",
                "residual_variance",
                "residual_l2",
            ]
        ],
        on="T_K",
        how="left",
    )

    df["gap_q90_q50"] = df["q90_I_mA"] - df["q50_I_mA"]
    df["gap_q75_q25"] = df["iq75_25_mA"]
    # barrier_descriptors has no q95; use upper-tail gap q90-q75 as proxy for "q95-q75" ask
    df["gap_q90_q75"] = df["q90_I_mA"] - df["q75_I_mA"]

    df["median_I_use"] = df["median_I_mA"].where(df["median_I_mA"].notna(), df["q50_I_mA"])
    df["kappa2_norm_S"] = df["kappa2"] / df["S_peak"].replace(0, np.nan)
    df["kappa2_norm_k1"] = df["kappa2"] / df["kappa1"].replace(0, np.nan)

    # Global stack: energy outside rank-1 (1 - E1) and mode2-only fraction
    srow = spec[spec["subset"].astype(str) == "T_le_30"]
    e1 = float(srow["variance_explained_mode1"].iloc[0])
    e12 = float(srow["variance_explained_modes1_plus_2"].iloc[0])
    energy_outside_rank1_global = 1.0 - e1
    energy_mode2_only_global = e12 - e1

    y = df["kappa2"].values.astype(float)

    corr_rows = []
    predictors = {
        "I_peak_mA": df["I_peak_mA"].values,
        "median_I_use": df["median_I_use"].values,
        "gap_q90_q50": df["gap_q90_q50"].values,
        "gap_q75_q25": df["gap_q75_q25"].values,
        "gap_q90_q75_proxy": df["gap_q90_q75"].values,
        "skewness_PT": df["skewness"].values,
        "skewness_quantile_barrier": df["skewness_quantile"].values,
        "asym_q_barrier": df["asym_q75_50_minus_q50_25"].values,
        "mean_threshold_mA": df["mean_threshold_mA"].values,
        "std_threshold_mA": df["std_threshold_mA"].values,
        "kappa1": df["kappa1"].values,
        "residual_rmse": df["residual_rmse"].values,
        "residual_variance": df["residual_variance"].values,
        "residual_l2": df["residual_l2"].values,
        "kappa2_norm_S": df["kappa2_norm_S"].values,
        "kappa2_norm_k1": df["kappa2_norm_k1"].values,
    }

    for name, xv in predictors.items():
        rp, rs_, nn = safe_corr(xv.astype(float), y)
        corr_rows.append(
            {
                "x_variable": name,
                "pearson": rp,
                "spearman": rs_,
                "n": nn,
            }
        )

    corr_tbl = pd.DataFrame(corr_rows)

    # Normalization robustness: corr(kappa2_norm_*, I_peak) vs corr(kappa2, I_peak)
    rp_raw, rs_raw, n_raw = safe_corr(df["I_peak_mA"].values, y)
    rp_ns, rs_ns, n_ns = safe_corr(df["kappa2_norm_S"].values, df["I_peak_mA"].astype(float).values)
    rp_nk, rs_nk, n_nk = safe_corr(df["kappa2_norm_k1"].values, df["I_peak_mA"].astype(float).values)

    norm_rows = pd.DataFrame(
        [
            {
                "comparison": "corr(kappa2, I_peak)",
                "pearson": rp_raw,
                "spearman": rs_raw,
                "n": n_raw,
            },
            {
                "comparison": "corr(kappa2/S_peak, I_peak)",
                "pearson": rp_ns,
                "spearman": rs_ns,
                "n": n_ns,
            },
            {
                "comparison": "corr(kappa2/kappa1, I_peak)",
                "pearson": rp_nk,
                "spearman": rs_nk,
                "n": n_nk,
            },
        ]
    )

    # Models (complete-case for each)
    def model_block(mask, Xcols, label):
        sub = df.loc[mask].copy()
        yy = sub["kappa2"].values.astype(float)
        if len(yy) < 4:
            return {
                "model": label,
                "n": len(yy),
                "loocv_rmse": np.nan,
                "loocv_pearson": np.nan,
            }
        Xp = np.column_stack([np.ones(len(yy))] + [sub[c].values.astype(float) for c in Xcols])
        rmse, r = loocv_linear_rmse_pearson(Xp, yy)
        return {"model": label, "n": len(yy), "loocv_rmse": rmse, "loocv_pearson": r}

    m1 = np.isfinite(df["I_peak_mA"]) & np.isfinite(df["kappa2"])
    shape_cols = ["I_peak_mA", "std_threshold_mA", "gap_q90_q50"]
    m2 = m1 & np.isfinite(df["std_threshold_mA"]) & np.isfinite(df["gap_q90_q50"])
    m3 = m2 & np.isfinite(df["kappa1"])

    models = [
        model_block(m1, ["I_peak_mA"], "kappa2 ~ I_peak"),
        model_block(m2, shape_cols, "kappa2 ~ I_peak + std_threshold + (q90-q50)"),
        model_block(m3, ["kappa1"] + shape_cols[1:], "kappa2 ~ kappa1 + std_threshold + (q90-q50)"),
    ]
    models_tbl = pd.DataFrame(models)

    # Wide CSV: correlations + footer rows for models and globals
    out_csv = REPO / "tables/kappa2_state_vs_geometry.csv"
    out_csv.parent.mkdir(parents=True, exist_ok=True)

    tidy_rows = []
    for _, r in corr_tbl.iterrows():
        tidy_rows.append(
            {
                "analysis_block": "correlation_vs_kappa2",
                "name": r["x_variable"],
                "pearson": r["pearson"],
                "spearman": r["spearman"],
                "n": r["n"],
                "loocv_rmse": np.nan,
                "loocv_pearson": np.nan,
                "global_metric_value": np.nan,
            }
        )
    for _, r in norm_rows.iterrows():
        tidy_rows.append(
            {
                "analysis_block": "normalization_vs_I_peak",
                "name": r["comparison"],
                "pearson": r["pearson"],
                "spearman": r["spearman"],
                "n": r["n"],
                "loocv_rmse": np.nan,
                "loocv_pearson": np.nan,
                "global_metric_value": np.nan,
            }
        )
    for _, r in models_tbl.iterrows():
        tidy_rows.append(
            {
                "analysis_block": "loocv_model",
                "name": r["model"],
                "pearson": np.nan,
                "spearman": np.nan,
                "n": r["n"],
                "loocv_rmse": r["loocv_rmse"],
                "loocv_pearson": r["loocv_pearson"],
                "global_metric_value": np.nan,
            }
        )
    tidy_rows.append(
        {
            "analysis_block": "global_stack_spectrum_T_le_30",
            "name": "energy_outside_rank1_1_minus_E1",
            "pearson": np.nan,
            "spearman": np.nan,
            "n": np.nan,
            "loocv_rmse": np.nan,
            "loocv_pearson": np.nan,
            "global_metric_value": energy_outside_rank1_global,
        }
    )
    tidy_rows.append(
        {
            "analysis_block": "global_stack_spectrum_T_le_30",
            "name": "energy_mode2_only_E12_minus_E1",
            "pearson": np.nan,
            "spearman": np.nan,
            "n": np.nan,
            "loocv_rmse": np.nan,
            "loocv_pearson": np.nan,
            "global_metric_value": energy_mode2_only_global,
        }
    )
    pd.DataFrame(tidy_rows).to_csv(out_csv, index=False)

    # Figure
    fig, axes = plt.subplots(2, 2, figsize=(9, 7))
    plot_mask = np.isfinite(df["kappa2"]) & np.isfinite(df["I_peak_mA"])
    ax = axes[0, 0]
    ax.scatter(df.loc[plot_mask, "I_peak_mA"], df.loc[plot_mask, "kappa2"], c=df.loc[plot_mask, "T_K"], cmap="viridis")
    ax.set_xlabel("I_peak_mA")
    ax.set_ylabel("kappa2")
    ax.set_title("kappa2 vs I_peak")

    pm = np.isfinite(df["kappa2"]) & np.isfinite(df["median_I_use"])
    axes[0, 1].scatter(df.loc[pm, "median_I_use"], df.loc[pm, "kappa2"], c=df.loc[pm, "T_K"], cmap="viridis")
    axes[0, 1].set_xlabel("median_I (barrier)")
    axes[0, 1].set_ylabel("kappa2")
    axes[0, 1].set_title("kappa2 vs median_I")

    pg = np.isfinite(df["kappa2"]) & np.isfinite(df["gap_q90_q50"])
    axes[1, 0].scatter(df.loc[pg, "gap_q90_q50"], df.loc[pg, "kappa2"], c=df.loc[pg, "T_K"], cmap="viridis")
    axes[1, 0].set_xlabel("q90 - q50 (mA)")
    axes[1, 0].set_ylabel("kappa2")
    axes[1, 0].set_title("kappa2 vs upper spread")

    pk = np.isfinite(df["kappa2"]) & np.isfinite(df["kappa1"])
    axes[1, 1].scatter(df.loc[pk, "kappa1"], df.loc[pk, "kappa2"], c=df.loc[pk, "T_K"], cmap="viridis")
    axes[1, 1].set_xlabel("kappa1")
    axes[1, 1].set_ylabel("kappa2")
    axes[1, 1].set_title("kappa2 vs kappa1")

    for ax in axes.flat:
        ax.grid(True, alpha=0.3)
    plt.tight_layout()
    fig_path = REPO / "figures/kappa2_vs_shape.png"
    fig_path.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(fig_path, dpi=150)
    plt.close()

    # --- Verdict heuristics (documented in report) ---
    geom_keys = ["I_peak_mA", "median_I_use", "gap_q90_q50", "gap_q75_q25", "skewness_PT", "std_threshold_mA"]
    state_keys = ["kappa1", "residual_rmse", "residual_variance"]

    def max_abs_spearman(keys):
        sub = corr_tbl[corr_tbl["x_variable"].isin(keys)]
        v = sub["spearman"].abs().max()
        return float(v) if len(sub) else np.nan

    geom_strength = max_abs_spearman(geom_keys)
    state_strength = max_abs_spearman(state_keys)
    corr_k1 = corr_tbl.loc[corr_tbl["x_variable"] == "kappa1", "spearman"].values
    corr_k1 = float(corr_k1[0]) if len(corr_k1) else np.nan

    best_rmse = models_tbl["loocv_rmse"].min()
    std_k2 = float(np.nanstd(y))
    rel_rmse = best_rmse / std_k2 if std_k2 > 0 else np.nan
    best_p = models_tbl.loc[models_tbl["loocv_rmse"].idxmin(), "loocv_pearson"]

    # Thresholds (conservative; stated in report)
    KAPPA2_IS_STATE_LIKE = state_strength >= 0.45 or abs(corr_k1) >= 0.45
    KAPPA2_IS_GEOMETRIC_LIKE = geom_strength >= 0.45
    KAPPA2_SIMPLE_PREDICTABLE = (rel_rmse < 0.55 and np.isfinite(best_p) and abs(best_p) >= 0.65) or (
        np.isfinite(best_p) and abs(best_p) >= 0.75
    )

    report = REPO / "reports/kappa2_state_geometry_report.md"
    report.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Kappa2 state vs geometry (Agent 19A)",
        "",
        "## Data sources (read-only)",
        f"- `kappa2(T)` = `rel_orth_leftover_norm`, subset **`T_le_30`**: `{rs_path.relative_to(REPO)}`",
        f"- PT summary: `{pt_path.relative_to(REPO)}`",
        f"- Barrier quantiles / asymmetry: `{bd_path.relative_to(REPO)}`",
        f"- Threshold residual metrics per T: `{thr_path.relative_to(REPO)}`",
        f"- Global rank spectrum (reference): `{spec_path.relative_to(REPO)}`",
        "",
        "## Definitions",
        "- **kappa1**: mode-1 amplitude from residual rank table (`kappa` column).",
        "- **kappa2**: mode-2 proxy `rel_orth_leftover_norm` (orthogonal leftover vs leading slice mode).",
        "- **median_I**: `median_I_mA` from barrier descriptors, falling back to `q50_I_mA`.",
        "- **q95-q75**: not in `barrier_descriptors.csv`; use **q90-q75** as upper-tail proxy (`gap_q90_q75_proxy`).",
        "- **Residual energy outside rank-1 (global stack)**: `1 - E1` = "
        f"{energy_outside_rank1_global:.6f} (constant across T in this export).",
        "- **Per-T residual norm proxy**: `residual_rmse` / `residual_l2` from threshold-residual run (aligned by `T_K`; missing rows reduce `n`).",
        "",
        "## 1. Correlations (Pearson / Spearman vs kappa2)",
        corr_tbl.to_csv(index=False).strip(),
        "",
        "## 2. Normalization robustness (vs I_peak)",
        norm_rows.to_csv(index=False).strip(),
        "",
        "## 3. LOOCV linear models",
        models_tbl.to_csv(index=False).strip(),
        "",
        "## 4. Figure",
        f"- `figures/kappa2_vs_shape.png`",
        "",
        "## FINAL VERDICT",
        f"- **KAPPA2_IS_STATE_LIKE**: {'YES' if KAPPA2_IS_STATE_LIKE else 'NO'} "
        f"(rule: max |Spearman| in {{{', '.join(state_keys)}}} ≥ 0.45 or |Spearman(kappa2,kappa1)| ≥ 0.45; "
        f"max state |Sp|={state_strength:.4f}, Sp(kappa1)={corr_k1:.4f})",
        f"- **KAPPA2_IS_GEOMETRIC_LIKE**: {'YES' if KAPPA2_IS_GEOMETRIC_LIKE else 'NO'} "
        f"(rule: max |Spearman| in PT/geometry list ≥ 0.45; max geom |Sp|={geom_strength:.4f})",
        f"- **KAPPA2_SIMPLE_PREDICTABLE**: {'YES' if KAPPA2_SIMPLE_PREDICTABLE else 'NO'} "
        f"(rule: best LOOCV RMSE/σ(kappa2) < 0.55 and |Pearson(LOO)|≥0.65, or |Pearson(LOO)|≥0.75; "
        f"best RMSE={best_rmse:.6g}, σ={std_k2:.6g}, ratio={rel_rmse:.4f}, best Pearson(LOO)={best_p:.4f})",
        "",
    ]
    report.write_text("\n".join(lines), encoding="utf-8")

    print("Wrote:", out_csv, fig_path, report)


if __name__ == "__main__":
    main()
