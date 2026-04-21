import json
import math
import re
from pathlib import Path

import numpy as np
import pandas as pd


REPO = Path(__file__).resolve().parents[1]
INPUT_CSV = REPO / "tables" / "xx_relaxation_event_level_full_config2.csv"
OUT_CLASS = REPO / "tables" / "xx_tau_zero_classification.csv"
OUT_DELTAV = REPO / "tables" / "xx_tau_zero_vs_deltaV.csv"
OUT_REPORT = REPO / "reports" / "xx_tau_zero_physical_vs_algorithm.md"

BASE_DIR = Path(
    r"L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\FIB5_Switching_old_PPMS\Config2\Amp Temp Dep all"
)
REQ_MA = [25, 30, 35]


def parse_current_from_config(config_id: str) -> float:
    m = re.search(r"config2_(\d+)mA", str(config_id))
    return float(m.group(1)) if m else np.nan


def get_config_dirs():
    out = {}
    for ma in REQ_MA:
        candidates = sorted([p for p in BASE_DIR.glob(f"Temp Dep {ma}mA*") if p.is_dir()])
        if candidates:
            out[f"config2_{ma}mA"] = candidates[0]
    return out


def moving_std(x: np.ndarray, w: int) -> np.ndarray:
    out = np.full_like(x, np.nan, dtype=float)
    if w <= 1:
        return np.zeros_like(x, dtype=float)
    for i in range(w - 1, len(x)):
        out[i] = np.nanstd(x[i - w + 1 : i + 1])
    return out


def median_abs_dev(x: np.ndarray) -> float:
    x = x[np.isfinite(x)]
    if x.size == 0:
        return 0.0
    med = np.median(x)
    return float(np.median(np.abs(x - med)))


def find_peaks_simple(y: np.ndarray, min_height: float, min_dist: int) -> np.ndarray:
    idx = []
    i = 1
    n = len(y)
    while i < n - 1:
        if y[i] >= min_height and y[i] >= y[i - 1] and y[i] > y[i + 1]:
            idx.append(i)
            i += max(1, min_dist)
        else:
            i += 1
    return np.array(idx, dtype=int)


def find_pulse_end(abs_dvdt: np.ndarray, peak_idx: int, slope_floor: float, max_idx: int) -> int:
    idx = int(peak_idx)
    while idx < max_idx:
        if abs_dvdt[idx] < 1.2 * slope_floor:
            break
        idx += 1
    return min(idx, max_idx)


def find_relaxation_start(abs_dvdt: np.ndarray, pulse_end_idx: int, slope_floor: float, max_idx: int) -> int:
    idx = int(pulse_end_idx)
    need = 4
    while idx + need < max_idx:
        if np.all(abs_dvdt[idx : idx + need] < 1.1 * slope_floor):
            break
        idx += 1
    return min(idx, max_idx)


def find_stable_plateau_start(
    v: np.ndarray,
    abs_dvdt: np.ndarray,
    start_idx: int,
    max_idx: int,
    w: int,
    stable_n: int,
    eps_slope: float,
    eps_std: float,
):
    if start_idx + w + stable_n > max_idx:
        return None
    stable = np.zeros(max_idx + 1, dtype=bool)
    for k in range(start_idx, max_idx - w + 2):
        seg = v[k : k + w]
        slope_val = np.nanmean(abs_dvdt[k : k + w])
        stable[k] = bool((slope_val < eps_slope) and (np.nanstd(seg) < eps_std))
    run = 0
    for k in range(start_idx, max_idx - w + 2):
        if stable[k]:
            run += 1
            if run >= stable_n:
                return k - stable_n + 1
        else:
            run = 0
    return None


def analyze_file_events(dat_path: Path):
    df = pd.read_csv(dat_path, sep="\t")
    t_ms = df["Time (ms)"].to_numpy(dtype=float)
    t_sec = (t_ms - t_ms[0]) / 1000.0
    if "LI3_X (V)" in df.columns:
        v = df["LI3_X (V)"].to_numpy(dtype=float)
    else:
        v = df["LI2_X (V)"].to_numpy(dtype=float)

    dt = np.nanmedian(np.diff(t_sec))
    if (not np.isfinite(dt)) or dt <= 0:
        dt = 0.1
    known_spacing = 15.0
    abs_dvdt = np.abs(np.gradient(v, dt))
    q90, q99 = np.nanquantile(abs_dvdt, [0.90, 0.99])
    thr = max(q99, q90 + 3.0 * median_abs_dev(abs_dvdt))
    min_dist = max(int(round((0.6 * known_spacing) / dt)), 5)
    pulse_idx = find_peaks_simple(abs_dvdt, thr, min_dist)
    if pulse_idx.size < 4:
        thr2 = float(np.nanquantile(abs_dvdt, 0.995))
        pulse_idx = find_peaks_simple(abs_dvdt, thr2, max(int(round((0.4 * known_spacing) / dt)), 3))
    if pulse_idx.size == 0:
        return []

    mean_period = known_spacing
    if pulse_idx.size > 1:
        mean_period = float(np.nanmedian(np.diff(t_sec[pulse_idx])))
    w = max(int(round(0.12 * mean_period / dt)), 8)
    stable_n = max(int(round(w / 3.0)), 5)
    slope_floor = float(np.nanmedian(abs_dvdt) + 1.5 * median_abs_dev(abs_dvdt))
    roll_std = moving_std(v, w)
    std_floor = float(np.nanmedian(roll_std) + 2.0 * median_abs_dev(roll_std))
    if (not np.isfinite(std_floor)) or std_floor <= 0:
        std_floor = float(np.nanstd(v) * 0.1)
    threshold = max(2.0 * std_floor, 1e-12)

    out = []
    for p, this_peak in enumerate(pulse_idx, start=1):
        next_pulse = len(v) - 1
        if p < pulse_idx.size:
            next_pulse = int(pulse_idx[p] - 1)
        pulse_end = find_pulse_end(abs_dvdt, int(this_peak), slope_floor, next_pulse)
        relax_start = find_relaxation_start(abs_dvdt, pulse_end, slope_floor, next_pulse)
        plateau_start = find_stable_plateau_start(v, abs_dvdt, relax_start, next_pulse, w, stable_n, slope_floor, std_floor)
        row = {
            "pulse_index": p,
            "relax_start_idx": relax_start,
            "stop_idx": next_pulse,
            "window_samples": int(max(0, next_pulse - relax_start + 1)),
            "window_sec": float(max(0.0, t_sec[next_pulse] - t_sec[relax_start])),
            "dt_sec": float(dt),
            "threshold": float(threshold),
            "std_floor": float(std_floor),
            "plateau_detected_recalc": plateau_start is not None,
        }
        if plateau_start is not None:
            v_plateau = float(np.nanmean(v[plateau_start : next_pulse + 1]))
            diff = np.abs(v[relax_start : next_pulse + 1] - v_plateau)
            d0 = float(diff[0]) if diff.size else np.nan
            dmin = float(np.nanmin(diff)) if diff.size else np.nan
            dlast = float(diff[-1]) if diff.size else np.nan
            slope = float((v[next_pulse] - v[relax_start]) / max(t_sec[next_pulse] - t_sec[relax_start], 1e-12))
            row.update(
                {
                    "V_plateau_recalc": v_plateau,
                    "D0": d0,
                    "Dmin": dmin,
                    "Dend": dlast,
                    "distance_drop_ratio": (d0 - dmin) / d0 if np.isfinite(d0) and d0 > 0 else np.nan,
                    "window_slope": slope,
                }
            )
        out.append(row)
    return out


def classify_event(dv: float, d0: float, ratio: float, window_samples: int, dt_sec: float, window_sec: float):
    if not np.isfinite(dv):
        return "FAILURE"
    fast_sec = 3.0 * dt_sec
    if np.isfinite(window_sec) and window_sec <= fast_sec:
        return "TOO_FAST"
    if np.isfinite(d0) and np.isfinite(ratio):
        if d0 <= 2.5e-8:
            return "TOO_SMALL"
        if ratio < 0.08 and d0 <= 8.0e-8:
            return "NO_DECAY"
        if ratio >= 0.2 and d0 > 1.2e-7 and window_samples >= 8:
            return "FAILURE"
        if ratio < 0.12 and d0 > 1.2e-7:
            return "NO_DECAY"
        if ratio >= 0.08 and d0 <= 1.2e-7:
            return "TOO_SMALL"
    if window_samples <= 4:
        return "TOO_FAST"
    return "TOO_SMALL"


def main():
    events = pd.read_csv(INPUT_CSV)
    events["current"] = events["config_id"].map(parse_current_from_config)
    events["event_id"] = np.arange(1, len(events) + 1)
    tau_zero = events[events["tau_relax"] == 0].copy()
    tau_pos = events[events["tau_relax"] > 0].copy()

    cfg_dirs = get_config_dirs()
    by_file = {}
    for file_id in tau_zero["file_id"].unique():
        for cfg_id, d in cfg_dirs.items():
            p = d / file_id
            if p.exists():
                by_file[file_id] = p
                break

    # representative set: cover temperatures and currents
    reps = []
    if len(tau_zero):
        tmp = tau_zero.sort_values(["temperature", "current", "pulse_index"])
        stride = max(1, int(math.floor(len(tmp) / 8)))
        reps = list(tmp.iloc[::stride].head(10)["event_id"].values)
    rep_set = set(reps)

    # cache per-file signal analysis
    file_analysis = {}
    missing_raw = set()
    for fid, p in by_file.items():
        try:
            file_analysis[fid] = analyze_file_events(p)
        except Exception:
            missing_raw.add(fid)

    class_rows = []
    rep_rows = []
    for _, r in tau_zero.iterrows():
        fid = r["file_id"]
        pidx = int(r["pulse_index"])
        rec = None
        if fid in file_analysis and pidx - 1 < len(file_analysis[fid]):
            rec = file_analysis[fid][pidx - 1]
        if rec is None:
            cls = "FAILURE"
            vis = "NO_DECAY_VISIBLE"
            ws = np.nan
            wsec = np.nan
            d0 = np.nan
            ratio = np.nan
            note = "RAW_MISSING_OR_PULSE_MAP_FAIL"
        else:
            ws = rec.get("window_samples", np.nan)
            wsec = rec.get("window_sec", np.nan)
            d0 = rec.get("D0", np.nan)
            ratio = rec.get("distance_drop_ratio", np.nan)
            cls = classify_event(float(r["DeltaV"]), d0, ratio, int(ws), float(rec["dt_sec"]), wsec)
            if cls == "TOO_FAST":
                vis = "DECAY_TOO_FAST"
            elif cls == "TOO_SMALL":
                vis = "DECAY_TOO_SMALL"
            elif cls == "NO_DECAY":
                vis = "NO_DECAY_VISIBLE"
            else:
                vis = "CLEAR_DECAY_PRESENT"
            note = ""
        class_rows.append({"event_id": int(r["event_id"]), "classification": cls})
        if int(r["event_id"]) in rep_set:
            rep_rows.append(
                {
                    "event_id": int(r["event_id"]),
                    "file_id": fid,
                    "temperature": float(r["temperature"]),
                    "current": float(r["current"]) if np.isfinite(r["current"]) else np.nan,
                    "pulse_index": int(r["pulse_index"]),
                    "DeltaV": float(r["DeltaV"]),
                    "V_plateau": float(r["V_plateau"]),
                    "visibility_class": vis,
                    "classification": cls,
                    "window_samples": ws,
                    "window_sec": wsec,
                    "D0_recalc": d0,
                    "distance_drop_ratio": ratio,
                    "note": note,
                }
            )

    class_df = pd.DataFrame(class_rows).sort_values("event_id")
    class_df.to_csv(OUT_CLASS, index=False)

    # DeltaV comparison summary table
    def stats(s: pd.Series, prefix: str):
        return {
            f"{prefix}_n": int(s.notna().sum()),
            f"{prefix}_mean": float(s.mean()),
            f"{prefix}_median": float(s.median()),
            f"{prefix}_p10": float(s.quantile(0.10)),
            f"{prefix}_p90": float(s.quantile(0.90)),
        }

    summary = {}
    summary.update(stats(tau_zero["DeltaV"], "tau0_DeltaV"))
    summary.update(stats(tau_pos["DeltaV"], "taupos_DeltaV"))
    if len(tau_zero) and len(tau_pos):
        summary["tau0_frac_below_taupos_p10"] = float((tau_zero["DeltaV"] <= tau_pos["DeltaV"].quantile(0.10)).mean())
        summary["tau0_frac_above_taupos_median"] = float((tau_zero["DeltaV"] >= tau_pos["DeltaV"].median()).mean())
    else:
        summary["tau0_frac_below_taupos_p10"] = np.nan
        summary["tau0_frac_above_taupos_median"] = np.nan

    delta_rows = [{"metric": k, "value": v} for k, v in summary.items()]
    pd.DataFrame(delta_rows).to_csv(OUT_DELTAV, index=False)

    # Additional diagnostics for report
    tau0_with_cls = tau_zero.merge(class_df, on="event_id", how="left")
    cls_counts = tau0_with_cls["classification"].value_counts(dropna=False).to_dict()
    cls_pct = {k: 100.0 * v / max(len(tau0_with_cls), 1) for k, v in cls_counts.items()}

    # temperature dependence
    temp_grp = events.groupby("temperature", dropna=False)
    temp_tbl = temp_grp.apply(lambda g: pd.Series({"n_total": len(g), "n_tau0": int((g["tau_relax"] == 0).sum())})).reset_index()
    temp_tbl["frac_tau0"] = temp_tbl["n_tau0"] / temp_tbl["n_total"].replace(0, np.nan)
    temp_tbl = temp_tbl.sort_values("temperature")

    # window adequacy: compare recalculated windows for tau0 reps vs tau>0 reps in same files when possible
    rep_df = pd.DataFrame(rep_rows)
    taupos_rep = tau_pos.sort_values(["temperature", "current", "pulse_index"]).head(min(40, len(tau_pos))).copy()
    taupos_windows = []
    for _, r in taupos_rep.iterrows():
        fid = r["file_id"]
        pidx = int(r["pulse_index"])
        if fid in file_analysis and pidx - 1 < len(file_analysis[fid]):
            rec = file_analysis[fid][pidx - 1]
            taupos_windows.append(rec.get("window_sec", np.nan))
    tau0_windows = rep_df["window_sec"].dropna().to_numpy() if not rep_df.empty else np.array([])
    taupos_windows = np.array([w for w in taupos_windows if np.isfinite(w)])

    def mfmt(x):
        return "NaN" if (x is None or (isinstance(x, float) and not np.isfinite(x))) else f"{x:.4g}"

    primary_cause = "DETECTION_FAILURE"
    if cls_counts:
        primary_cause = max(cls_counts, key=cls_counts.get)
        if primary_cause == "FAILURE":
            primary_cause = "DETECTION_FAILURE"

    tau_zero_is_physical = "YES" if cls_counts.get("NO_DECAY", 0) + cls_counts.get("TOO_SMALL", 0) + cls_counts.get("TOO_FAST", 0) > cls_counts.get("FAILURE", 0) else "NO"
    tau_zero_is_artifact = "YES" if cls_counts.get("FAILURE", 0) >= max(1, int(0.3 * len(tau_zero))) else "NO"
    safe_to_continue = "NO" if tau_zero_is_artifact == "YES" else "YES"

    lines = []
    lines.append("# Tau=0 Physical vs Algorithmic Diagnosis")
    lines.append("")
    lines.append("## Scope")
    lines.append("- Input: `tables/xx_relaxation_event_level_full_config2.csv`")
    lines.append("- Task: discriminate physical non-measurable relaxation vs extraction artifact for `tau_relax == 0`.")
    lines.append("- No pipeline logic was modified.")
    lines.append("")
    lines.append("## Tau=0 extraction")
    lines.append(f"- Total events: {len(events)}")
    lines.append(f"- `tau_relax == 0` events: {len(tau_zero)}")
    lines.append(f"- `tau_relax > 0` events: {len(tau_pos)}")
    lines.append("")
    lines.append("## Classification breakdown")
    for k in ["NO_DECAY", "TOO_FAST", "TOO_SMALL", "FAILURE"]:
        lines.append(f"- {k}: {cls_counts.get(k, 0)} ({cls_pct.get(k, 0.0):.1f}%)")
    lines.append("")
    lines.append("## DeltaV comparison")
    lines.append(f"- tau0 DeltaV median: {mfmt(summary.get('tau0_DeltaV_median', np.nan))}")
    lines.append(f"- tau>0 DeltaV median: {mfmt(summary.get('taupos_DeltaV_median', np.nan))}")
    lines.append(f"- tau0 fraction below tau>0 p10: {mfmt(summary.get('tau0_frac_below_taupos_p10', np.nan))}")
    lines.append(f"- tau0 fraction above tau>0 median: {mfmt(summary.get('tau0_frac_above_taupos_median', np.nan))}")
    lines.append("")
    lines.append("## Time-window adequacy")
    if tau0_windows.size:
        lines.append(f"- tau0 representative window_sec median: {np.nanmedian(tau0_windows):.3f}")
    else:
        lines.append("- tau0 representative window_sec median: NaN")
    if taupos_windows.size:
        lines.append(f"- tau>0 sample window_sec median: {np.nanmedian(taupos_windows):.3f}")
    else:
        lines.append("- tau>0 sample window_sec median: NaN")
    if tau0_windows.size and taupos_windows.size:
        lines.append(f"- Window ratio (tau0/tau>0 medians): {np.nanmedian(tau0_windows)/np.nanmedian(taupos_windows):.3f}")
    lines.append("")
    lines.append("## Temperature dependence of tau=0 fraction")
    for _, r in temp_tbl.iterrows():
        lines.append(f"- T={r['temperature']:.2f} K: tau0 fraction={r['frac_tau0']:.3f} ({int(r['n_tau0'])}/{int(r['n_total'])})")
    lines.append("")
    lines.append("## Representative tau=0 events")
    rep_out = rep_df.sort_values(["temperature", "current", "pulse_index"]) if not rep_df.empty else pd.DataFrame()
    if rep_out.empty:
        lines.append("- No representative events could be evaluated from raw files.")
    else:
        for _, r in rep_out.head(10).iterrows():
            lines.append(
                f"- event_id={int(r['event_id'])}, T={r['temperature']:.2f}K, I={r['current']:.0f}mA, pulse={int(r['pulse_index'])}, "
                f"DeltaV={r['DeltaV']:.3e}, vis={r['visibility_class']}, class={r['classification']}, window={r['window_sec']:.3f}s"
            )
    lines.append("")
    lines.append("```text id=\"q7e6a1\"")
    lines.append(f"TAU_ZERO_IS_PHYSICAL = {tau_zero_is_physical}")
    lines.append(f"TAU_ZERO_IS_ALGORITHM_ARTIFACT = {tau_zero_is_artifact}")
    lines.append(f"PRIMARY_CAUSE = {primary_cause}")
    lines.append(f"SAFE_TO_CONTINUE_AFTER_FIX = {safe_to_continue}")
    lines.append("```")
    lines.append("")
    lines.append("## Outputs")
    lines.append("- `tables/xx_tau_zero_classification.csv`")
    lines.append("- `tables/xx_tau_zero_vs_deltaV.csv`")
    lines.append("- `reports/xx_tau_zero_physical_vs_algorithm.md`")

    OUT_REPORT.write_text("\n".join(lines), encoding="utf-8")

    # store representatives in report-adjacent json for traceability
    if not rep_df.empty:
        aux = OUT_REPORT.with_suffix(".representative_events.json")
        aux.write_text(rep_df.to_json(orient="records", indent=2), encoding="utf-8")

    print(json.dumps({"tau0_n": int(len(tau_zero)), "taupos_n": int(len(tau_pos)), "missing_raw_files": len(missing_raw)}))


if __name__ == "__main__":
    main()
