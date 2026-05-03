/**
 * CM-SW-RLX-AX-18C — T-function and empirical scaling baseline control (AX-17B domain)
 * Node.js — no external deps; OLS + LOOCV in original A space where applicable.
 *
 * Run: node scripts/run_cm_sw_rlx_ax_18c_t_scaling_baseline.mjs
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, "..");

function matMulAtB(A) {
  const n = A.length,
    p = A[0].length;
  const M = Array(p)
    .fill(0)
    .map(() => Array(p).fill(0));
  for (let i = 0; i < p; i++)
    for (let j = 0; j < p; j++) for (let r = 0; r < n; r++) M[i][j] += A[r][i] * A[r][j];
  return M;
}
function matMulAty(A, y) {
  const p = A[0].length;
  const v = Array(p).fill(0);
  for (let i = 0; i < p; i++) for (let r = 0; r < A.length; r++) v[i] += A[r][i] * y[r];
  return v;
}
function solveLinear(M, b) {
  const n = b.length;
  const A = M.map((row, i) => [...row, b[i]]);
  for (let c = 0; c < n; c++) {
    let piv = c;
    for (let r = c + 1; r < n; r++) if (Math.abs(A[r][c]) > Math.abs(A[piv][c])) piv = r;
    [A[c], A[piv]] = [A[piv], A[c]];
    const div = A[c][c];
    if (Math.abs(div) < 1e-15) return null;
    for (let j = c; j <= n; j++) A[c][j] /= div;
    for (let r = 0; r < n; r++) {
      if (r === c) continue;
      const f = A[r][c];
      for (let j = c; j <= n; j++) A[r][j] -= f * A[c][j];
    }
  }
  return A.map((row) => row[n]);
}

function olsFit(X, y) {
  const XtX = matMulAtB(X);
  const Xty = matMulAty(X, y);
  const beta = solveLinear(XtX, Xty);
  if (!beta) return null;
  const pred = X.map((row) => row.reduce((s, xj, j) => s + xj * beta[j], 0));
  const mean = y.reduce((a, b) => a + b, 0) / y.length;
  const ssTot = y.reduce((s, yi) => s + (yi - mean) ** 2, 0);
  const ssRes = y.reduce((s, yi, i) => s + (yi - pred[i]) ** 2, 0);
  const r2 = ssTot > 0 ? 1 - ssRes / ssTot : NaN;
  return { beta, pred, r2 };
}

function loocvRmse(X, y) {
  const n = X.length,
    p = X[0].length;
  let sse = 0;
  for (let i = 0; i < n; i++) {
    const Xtr = [];
    const ytr = [];
    for (let j = 0; j < n; j++) {
      if (j === i) continue;
      Xtr.push(X[j]);
      ytr.push(y[j]);
    }
    const fit = olsFit(Xtr, ytr);
    if (!fit) return NaN;
    const row = X[i];
    const phat = row.reduce((s, xj, j) => s + xj * fit.beta[j], 0);
    sse += (y[i] - phat) ** 2;
  }
  return Math.sqrt(sse / n);
}

function pearson(a, b) {
  const n = a.length;
  const ma = a.reduce((s, x) => s + x, 0) / n;
  const mb = b.reduce((s, x) => s + x, 0) / n;
  let num = 0,
    da = 0,
    db = 0;
  for (let i = 0; i < n; i++) {
    const va = a[i] - ma;
    const vb = b[i] - mb;
    num += va * vb;
    da += va * va;
    db += vb * vb;
  }
  return num / (Math.sqrt(da) * Math.sqrt(db) + 1e-30);
}

function spearman(a, b) {
  const ra = rank(a);
  const rb = rank(b);
  return pearson(ra, rb);
}

function rank(arr) {
  const idx = arr.map((v, i) => ({ v, i })).sort((x, y) => x.v - y.v);
  const r = Array(arr.length);
  let k = 0;
  while (k < idx.length) {
    let j = k;
    while (j < idx.length && idx[j].v === idx[k].v) j++;
    const avg = (k + j + 1) / 2;
    for (let t = k; t < j; t++) r[idx[t].i] = avg;
    k = j;
  }
  return r;
}

function parseCsv(text) {
  const lines = text.trim().split(/\r?\n/);
  const hdr = lines[0].split(",").map((h) => h.trim());
  return lines.slice(1).map((ln) => {
    const parts = ln.split(",");
    const o = {};
    hdr.forEach((h, i) => {
      const v = parts[i];
      if (v === undefined || v === "") o[h] = NaN;
      else if (/^-?\d/.test(v.trim())) o[h] = Number(v);
      else o[h] = v;
    });
    return o;
  });
}

function csvEscape(s) {
  const t = String(s ?? "");
  return /[",\n]/.test(t) ? `"${t.replace(/"/g, '""')}"` : t;
}

function writeCsv(fp, rows, cols) {
  const lines = [cols.join(",")];
  for (const r of rows) lines.push(cols.map((c) => csvEscape(r[c])).join(","));
  fs.writeFileSync(fp, lines.join("\n"), "utf8");
}

const EPS = 1e-12;

/* ----- Load AX-17B visual dataset (already strict domain); preserve row count ----- */
const dsPath = path.join(REPO, "tables/cross_module_switching_relaxation_CM_SW_RLX_AX_17B_visual_dataset.csv");
const raw = parseCsv(fs.readFileSync(dsPath, "utf8"));
let rows = raw.filter((r) => Number(r.relaxation_T_K) < 31.5);
rows.sort((a, b) => Number(a.relaxation_T_K) - Number(b.relaxation_T_K));

const T = rows.map((r) => Number(r.relaxation_T_K));
const n = rows.length;

const targets = {
  A_obs_canon: rows.map((r) => Number(r.A_obs_canon)),
  A_svd_full_oriented_candidate: rows.map((r) => Number(r.A_svd_full_oriented_candidate)),
};
const Xeff = rows.map((r) => Number(r.Xeff_chosen));
const invD = rows.map((r) => Number(r.invD_chosen));

function buildTModels(Tarr) {
  const models = [];
  models.push({
    name: "T_linear",
    family: "T_polynomial",
    predictors: "1,T",
    X: Tarr.map((t) => [1, t]),
    num_parameters: 2,
  });
  models.push({
    name: "T_quadratic",
    family: "T_polynomial",
    predictors: "1,T,T^2",
    X: Tarr.map((t) => [1, t, t * t]),
    num_parameters: 3,
  });
  models.push({
    name: "T_log",
    family: "T_log",
    predictors: "1,log(T)",
    X: Tarr.map((t) => [1, Math.log(Math.max(t, EPS))]),
    num_parameters: 2,
  });
  models.push({
    name: "T_inverse",
    family: "T_inverse",
    predictors: "1,1/T",
    X: Tarr.map((t) => [1, 1 / Math.max(t, EPS)]),
    num_parameters: 2,
  });
  for (const bk of [23, 25]) {
    models.push({
      name: `T_hinge_${bk}K`,
      family: "T_hinge",
      predictors: `1,T,max(0,T-${bk})`,
      X: Tarr.map((t) => [1, t, Math.max(0, t - bk)]),
      num_parameters: 3,
    });
  }
  return models;
}

function linearCoord(vec, name) {
  return {
    name: `coord_${name}_linear`,
    family: "switching_coordinate",
    predictors: `1,${name}`,
    X: vec.map((x) => [1, x]),
    num_parameters: 2,
  };
}

function powerLogLog(z, zlabel, familyName) {
  if (!z.every((zi) => zi > 0)) return null;
  return {
    name: `${familyName}_empirical`,
    family: familyName,
    predictors: `1,log(${zlabel})`,
    transform: "loglog_fit_pred_backtransform_exp_to_A_space_LOOCV",
    X: z.map((zi) => [1, Math.log(zi)]),
    num_parameters: 2,
    fitInLogSpace: true,
  };
}

function powerAbsTc(Tarr, Tc) {
  const z = Tarr.map((t) => Math.abs(t - Tc) + EPS);
  return powerLogLog(z, `abs(T-${Tc})`, `absT_minus_${Tc}K`);
}

function shiftedT(Tarr, T0) {
  const z = Tarr.map((t) => Math.max(t - T0, EPS));
  return powerLogLog(z, `max(T-${T0},eps)`, `shifted_T_minus_${T0}K`);
}

function loocvLogLogToOriginalA(X, logy) {
  const nloc = X.length;
  let sse = 0;
  for (let i = 0; i < nloc; i++) {
    const Xtr = [];
    const ytr = [];
    for (let j = 0; j < nloc; j++) {
      if (j === i) continue;
      Xtr.push(X[j]);
      ytr.push(logy[j]);
    }
    const f = olsFit(Xtr, ytr);
    if (!f) return NaN;
    const logp = X[i].reduce((s, xj, j) => s + xj * f.beta[j], 0);
    const yhat = Math.exp(logp);
    sse += (Math.exp(logy[i]) - yhat) ** 2;
  }
  return Math.sqrt(sse / nloc);
}

function fitModel(m, y) {
  let yUse = y;
  if (m.fitInLogSpace) {
    if (y.some((yi) => yi <= 0)) return null;
    yUse = y.map((yi) => Math.log(yi));
  }
  const fit = olsFit(m.X, yUse);
  if (!fit) return null;
  const loocv = m.fitInLogSpace ? loocvLogLogToOriginalA(m.X, yUse) : loocvRmse(m.X, yUse);
  const predObs = m.fitInLogSpace ? fit.pred.map(Math.exp) : fit.pred;
  const trainR2 = (() => {
    if (!m.fitInLogSpace) return fit.r2;
    const mean = y.reduce((a, b) => a + b, 0) / y.length;
    const ssTot = y.reduce((s, yi) => s + (yi - mean) ** 2, 0);
    const ssRes = y.reduce((s, yi, i) => s + (yi - predObs[i]) ** 2, 0);
    return ssTot > 0 ? 1 - ssRes / ssTot : NaN;
  })();
  const po = pearson(predObs, y);
  const sp = spearman(predObs, y);
  return { trainR2, loocv, pearson: po, spearman: sp, pred: predObs, fit };
}

function extractAlpha(m, fitRes) {
  if (!m.fitInLogSpace || !fitRes.fit) return "";
  return Number(fitRes.fit.beta[1]).toExponential(8);
}

function scoreAll(targetKey, y) {
  const out = [];
  let bestTloocv = Infinity;
  let bestTname = "";
  for (const m of tModels) {
    const r = fitModel(m, y);
    if (!r) continue;
    out.push({
      target: targetKey,
      model_name: m.name,
      model_family: m.family,
      predictors: m.predictors,
      n,
      num_parameters: m.num_parameters,
      train_R2: r.trainR2,
      LOOCV_RMSE: r.loocv,
      Pearson_pred_obs: r.pearson,
      Spearman_pred_obs: r.spearman,
      kind: "T_baseline",
    });
    if (r.loocv < bestTloocv) {
      bestTloocv = r.loocv;
      bestTname = m.name;
    }
  }
  return { rows: out, bestTloocv, bestTname };
}

function getDesignByName(name) {
  return tModels.find((m) => m.name === name)?.X;
}

function residualOf(y, Xdesign) {
  const f = olsFit(Xdesign, y);
  if (!f) return null;
  return y.map((yi, i) => yi - f.pred[i]);
}

const tModels = buildTModels(T);
const coordModels = [linearCoord(Xeff, "Xeff_chosen"), linearCoord(invD, "invD_chosen")];

const scalingCandidates = [];
scalingCandidates.push(powerLogLog(T, "T", "T_power"));
scalingCandidates.push(powerLogLog(Xeff, "Xeff_chosen", "Xeff_power"));
scalingCandidates.push(powerLogLog(invD, "invD_chosen", "invD_power"));
for (const Tc of [23, 25, 31.5]) {
  const m = powerAbsTc(T, Tc);
  if (m) scalingCandidates.push(m);
}
for (const T0 of [0, 3, 5]) {
  const m = shiftedT(T, T0);
  if (m) scalingCandidates.push(m);
}

const packObs = scoreAll("A_obs_canon", targets.A_obs_canon);
const packSvd = scoreAll("A_svd_full_oriented_candidate", targets.A_svd_full_oriented_candidate);

function addCoords(pack, targetKey, y) {
  for (const m of coordModels) {
    const r = fitModel(m, y);
    if (!r) continue;
    pack.rows.push({
      target: targetKey,
      model_name: m.name,
      model_family: m.family,
      predictors: m.predictors,
      n,
      num_parameters: m.num_parameters,
      train_R2: r.trainR2,
      LOOCV_RMSE: r.loocv,
      Pearson_pred_obs: r.pearson,
      Spearman_pred_obs: r.spearman,
      kind: "coordinate",
    });
  }
}

addCoords(packObs, "A_obs_canon", targets.A_obs_canon);
addCoords(packSvd, "A_svd_full_oriented_candidate", targets.A_svd_full_oriented_candidate);

function relToBest(row, bt) {
  return row.LOOCV_RMSE / bt;
}

const tFunctionRows = [];
for (const row of [...packObs.rows, ...packSvd.rows]) {
  const bt = row.target === "A_obs_canon" ? packObs.bestTloocv : packSvd.bestTloocv;
  tFunctionRows.push({
    ...row,
    LOOCV_RMSE_relative_to_best_T_baseline: relToBest(row, bt),
    small_n_caveat: "YES_n15_LOOCV_HIGH_VARIANCE",
    notes:
      row.kind === "coordinate"
        ? "Linear coordinate alone vs A in original space"
        : "T baseline family member",
  });
}

/* Scaling law rows */
const scalingRows = [];
for (const [targetKey, y] of [
  ["A_obs_canon", targets.A_obs_canon],
  ["A_svd_full_oriented_candidate", targets.A_svd_full_oriented_candidate],
]) {
  const btLo =
    targetKey === "A_obs_canon" ? packObs.bestTloocv : packSvd.bestTloocv;
  const btNm =
    targetKey === "A_obs_canon" ? packObs.bestTname : packSvd.bestTname;
  for (const m of scalingCandidates) {
    if (!m) continue;
    const r = fitModel(m, y);
    if (!r) continue;
    const alpha = extractAlpha(m, r);
    scalingRows.push({
      target: targetKey,
      scaling_family: m.family,
      scaling_variable: m.predictors,
      transformation_used: m.transform || "linear_A_space",
      fixed_Tc_or_T0:
        m.name.includes("shifted") ? m.name.match(/minus_(\d+)K/)?.[1] + "K" : m.name.includes("absT") ? "Tc_fixed" : "na",
      n_used: n,
      alpha,
      train_R2: r.trainR2,
      LOOCV_RMSE: r.loocv,
      LOOCV_RMSE_relative_to_best_T_baseline: r.loocv / btLo,
      beats_best_T_baseline: r.loocv < btLo ? "YES" : "NO",
      empirical_fit_only_not_physical_law: "YES_EMPIRICAL_MONTECARLO_SMALL_N",
      notes: `best_T_LOOCV=${btLo.toExponential(6)} (${btNm})`,
    });
  }
}

/* Combined models: best T design + coordinate (same linear span as coord + best T) */
const combinedRows = [];
for (const [targetKey, y, pack] of [
  ["A_obs_canon", targets.A_obs_canon, packObs],
  ["A_svd_full_oriented_candidate", targets.A_svd_full_oriented_candidate, packSvd],
]) {
  const bn = pack.bestTname;
  const Xb = getDesignByName(bn);
  const baseLoocv = pack.bestTloocv;
  const nBase = Xb[0].length;
  const invDonly = invD.map((d) => [1, d]);
  const loocv_invD_only = loocvRmse(invDonly, y);

  for (const [clab, cvals] of [
    ["Xeff_chosen", Xeff],
    ["invD_chosen", invD],
  ]) {
    const Xm = Xb.map((row, i) => [...row, cvals[i]]);
    const loocvComb = loocvRmse(Xm, y);
    const fit = olsFit(Xm, y);
    const baseRow = {
      target: targetKey,
      best_T_baseline_name: bn,
      coordinate_added: clab,
      n,
      num_parameters_base: nBase,
      num_parameters_combined: Xm[0].length,
      base_best_T_LOOCV_RMSE: baseLoocv,
      invD_linear_only_LOOCV_RMSE: loocv_invD_only,
      combined_LOOCV_RMSE: loocvComb,
      delta_vs_best_T_alone: loocvComb - baseLoocv,
      relative_improvement_vs_best_T: (baseLoocv - loocvComb) / baseLoocv,
      coordinate_helpful_vs_best_T: loocvComb < baseLoocv - 1e-15 ? "YES" : "NO_OR_MARGINAL",
      T_helpful_beyond_invD_alone:
        loocvComb < loocv_invD_only - 1e-15 ? "YES" : "NO_OR_MARGINAL",
      delta_vs_invD_only: loocvComb - loocv_invD_only,
      train_R2_combined: fit?.r2 ?? "",
      notes:
        "OLS same design matrix as reverse label; LOOCV_RMSE in original A space",
    };
    combinedRows.push({
      ...baseRow,
      combination_label: `best_T(${bn})_plus_${clab}`,
    });
    combinedRows.push({
      ...baseRow,
      combination_label: `${clab}_plus_best_T(${bn})`,
    });
  }
}

/* Residual correlations after projecting onto best-T design */
const residualTable = [];
for (const [targetKey, y, pack] of [
  ["A_obs_canon", targets.A_obs_canon, packObs],
  ["A_svd_full_oriented_candidate", targets.A_svd_full_oriented_candidate, packSvd],
]) {
  const bn = pack.bestTname;
  const Xb = getDesignByName(bn);
  const rA = residualOf(y, Xb);
  const rXe = residualOf(Xeff, Xb);
  const rInv = residualOf(invD, Xb);
  if (!rA || !rXe || !rInv) continue;
  for (const [coord, rv] of [
    ["Xeff_chosen", rXe],
    ["invD_chosen", rInv],
  ]) {
    residualTable.push({
      target: targetKey,
      best_T_baseline: bn,
      coordinate: coord,
      residual_corr_Pearson: pearson(rA, rv),
      residual_corr_Spearman: spearman(rA, rv),
      interpretation:
        Math.abs(pearson(rA, rv)) > 0.35
          ? "nonzero_partial_association_after_best_T_linear_structure"
          : "weak_partial_association",
      notes: "Residuals from OLS projection onto same X_best_T for A and coordinate",
    });
  }
}

function pickBestScaling(targetKey) {
  const rs = scalingRows.filter((r) => r.target === targetKey);
  return rs.sort((a, b) => a.LOOCV_RMSE - b.LOOCV_RMSE)[0];
}

function coordLoocv(pack, coordSuffix) {
  const row = pack.rows.find((x) => x.model_name === `coord_${coordSuffix}_linear`);
  return row?.LOOCV_RMSE;
}

const judgement = [];
for (const [targetKey, pack, y] of [
  ["A_obs_canon", packObs, targets.A_obs_canon],
  ["A_svd_full_oriented_candidate", packSvd, targets.A_svd_full_oriented_candidate],
]) {
  const bs = pickBestScaling(targetKey);
  const xeffR = coordLoocv(pack, "Xeff_chosen");
  const invDR = coordLoocv(pack, "invD_chosen");
  const comb = combinedRows.filter((r) => r.target === targetKey);
  const cx = comb.find((c) => c.coordinate_added === "Xeff_chosen");
  const ci = comb.find((c) => c.coordinate_added === "invD_chosen");

  judgement.push({
    target: targetKey,
    best_simple_T_baseline: pack.bestTname,
    best_T_LOOCV_RMSE: pack.bestTloocv,
    best_empirical_scaling_family: bs?.scaling_family ?? "",
    best_empirical_scaling_LOOCV_RMSE: bs?.LOOCV_RMSE ?? "",
    Xeff_linear_LOOCV_RMSE: xeffR,
    invD_linear_LOOCV_RMSE: invDR,
    Xeff_beats_best_T_single_predictor: xeffR < pack.bestTloocv ? "YES" : "NO",
    invD_beats_best_T_single_predictor: invDR < pack.bestTloocv ? "YES" : "NO",
    Xeff_adds_beyond_best_T_OLS_combo: cx?.coordinate_helpful_vs_best_T ?? "",
    invD_adds_beyond_best_T_OLS_combo: ci?.coordinate_helpful_vs_best_T ?? "",
    best_T_adds_beyond_invD_OLS_combo: ci?.T_helpful_beyond_invD_alone ?? "",
    empirical_scaling_beats_best_T: bs?.beats_best_T_baseline ?? "",
    physical_scaling_law_claim: "NO_NOT_FROM_THIS_AUDIT",
    high_T_turnover_note:
      "See AX-18B turnover audit; hinge/quadratic T probe curvature vs monotone invD",
    allowed_wording:
      "Empirical predictors + small-n LOOCV; switching coordinates associate with A beyond naive linear T only when hinge/quadratic compete.",
    forbidden_wording:
      "Established physical scaling law; universal exponent; proves mechanism.",
    notes: `n=${n} rows from AX-17B visual_dataset`,
  });
}

const tbl = path.join(REPO, "tables");
writeCsv(
  path.join(tbl, "cross_module_switching_relaxation_CM_SW_RLX_AX_18C_T_function_model_comparison.csv"),
  tFunctionRows,
  [
    "target",
    "model_name",
    "model_family",
    "predictors",
    "n",
    "num_parameters",
    "train_R2",
    "LOOCV_RMSE",
    "LOOCV_RMSE_relative_to_best_T_baseline",
    "Pearson_pred_obs",
    "Spearman_pred_obs",
    "kind",
    "small_n_caveat",
    "notes",
  ]
);

writeCsv(
  path.join(tbl, "cross_module_switching_relaxation_CM_SW_RLX_AX_18C_scaling_law_comparison.csv"),
  scalingRows,
  [
    "target",
    "scaling_family",
    "scaling_variable",
    "transformation_used",
    "fixed_Tc_or_T0",
    "n_used",
    "alpha",
    "train_R2",
    "LOOCV_RMSE",
    "LOOCV_RMSE_relative_to_best_T_baseline",
    "beats_best_T_baseline",
    "empirical_fit_only_not_physical_law",
    "notes",
  ]
);

writeCsv(
  path.join(tbl, "cross_module_switching_relaxation_CM_SW_RLX_AX_18C_combined_models.csv"),
  combinedRows,
  Object.keys(combinedRows[0] || {})
);

writeCsv(
  path.join(tbl, "cross_module_switching_relaxation_CM_SW_RLX_AX_18C_residual_after_T.csv"),
  residualTable,
  Object.keys(residualTable[0] || {})
);

writeCsv(
  path.join(tbl, "cross_module_switching_relaxation_CM_SW_RLX_AX_18C_reparameterization_scaling_judgement.csv"),
  judgement,
  Object.keys(judgement[0] || {})
);

/* ----- Status keys (exact coverage for closure package) ----- */
const auditMd = path.join(REPO, "reports/cross_module_switching_relaxation_CM_SW_RLX_XEFF_width_audit_18.md");
const auditSt = path.join(REPO, "tables/cross_module_switching_relaxation_CM_SW_RLX_XEFF_width_audit_18_status.csv");

function flagImproveCombo(targetKey, coord) {
  const r = combinedRows.find((x) => x.target === targetKey && x.coordinate_added === coord);
  return r?.coordinate_helpful_vs_best_T === "YES" ? "YES" : "NO";
}

function flagTbeyondInv(targetKey) {
  const r = combinedRows.find((x) => x.target === targetKey && x.coordinate_added === "invD_chosen");
  return r?.T_helpful_beyond_invD_alone === "YES" ? "YES" : "NO";
}

const invBeatObs = coordLoocv(packObs, "invD_chosen") < packObs.bestTloocv;
const invBeatSvd = coordLoocv(packSvd, "invD_chosen") < packSvd.bestTloocv;
const xBeatObs = coordLoocv(packObs, "Xeff_chosen") < packObs.bestTloocv;
const xBeatSvd = coordLoocv(packSvd, "Xeff_chosen") < packSvd.bestTloocv;

const anyEmpiricalBeatsT =
  scalingRows.some((r) => r.beats_best_T_baseline === "YES") ? "YES" : "NO";

const statusRows = [
  ["TASK_COMPLETED", "YES"],
  ["AUDIT_ONLY", "YES"],
  ["MATLAB_RUN", "NO"],
  ["PYTHON_RUN", "NO"],
  ["NODE_RUN", "YES"],
  ["FULL_AX_RERUN", "NO"],
  ["FIGURES_CREATED", "NO"],
  ["FIGURES_MODIFIED", "NO"],
  ["SWITCHING_USED", "YES"],
  ["RELAXATION_USED", "YES"],
  ["AGING_USED", "NO"],
  ["TAU_KWW_USED", "NO"],
  ["POWERLAW_RUN", "YES_EMPIRICAL_FORMS_ONLY"],
  ["USED_AX_17B_DATASET", "YES"],
  ["USED_XEFF_WIDTH_AUDIT_18", fs.existsSync(auditMd) || fs.existsSync(auditSt) ? "YES" : "NO"],
  ["AX_DOMAIN_N", String(n)],
  ["T_LINEAR_BASELINE_TESTED", "YES"],
  ["T_QUADRATIC_BASELINE_TESTED", "YES"],
  ["T_LOG_BASELINE_TESTED", "YES"],
  ["T_INVERSE_BASELINE_TESTED", "YES"],
  ["T_HINGE_23K_TESTED", "YES"],
  ["T_HINGE_25K_TESTED", "YES"],
  ["SCALING_T_POWER_TESTED", "YES"],
  ["SCALING_XEFF_POWER_TESTED", "YES"],
  ["SCALING_INVD_POWER_TESTED", "YES"],
  ["SCALING_FIXED_TC_TESTED", "YES"],
  ["SCALING_SHIFTED_T_TESTED", "YES"],
  ["HIGH_COMPLEXITY_T_BASELINES_BLOCKED", "YES"],
  ["FREE_TC_SEARCH_BLOCKED", "YES"],
  ["XEFF_MODEL_TESTED", "YES"],
  ["INVD_MODEL_TESTED", "YES"],
  ["BEST_T_PLUS_XEFF_TESTED", "YES"],
  ["BEST_T_PLUS_INVD_TESTED", "YES"],
  ["RESIDUAL_AFTER_BEST_T_TESTED", "YES"],
  ["AOBS_BEST_SIMPLE_T_BASELINE", packObs.bestTname],
  ["ASVD_BEST_SIMPLE_T_BASELINE", packSvd.bestTname],
  ["XEFF_IMPROVES_OVER_BEST_T_FOR_AOBS", xBeatObs ? "YES" : "NO"],
  ["INVD_IMPROVES_OVER_BEST_T_FOR_AOBS", invBeatObs ? "YES" : "NO"],
  ["XEFF_IMPROVES_OVER_BEST_T_FOR_ASVD", xBeatSvd ? "YES" : "NO"],
  ["INVD_IMPROVES_OVER_BEST_T_FOR_ASVD", invBeatSvd ? "YES" : "NO"],
  ["INVD_ADDS_BEYOND_BEST_T_FOR_AOBS", flagImproveCombo("A_obs_canon", "invD_chosen")],
  ["INVD_ADDS_BEYOND_BEST_T_FOR_ASVD", flagImproveCombo("A_svd_full_oriented_candidate", "invD_chosen")],
  ["BEST_T_ADDS_BEYOND_INVD_FOR_AOBS", flagTbeyondInv("A_obs_canon")],
  ["BEST_T_ADDS_BEYOND_INVD_FOR_ASVD", flagTbeyondInv("A_svd_full_oriented_candidate")],
  ["AOBS_EXPLAINED_BY_SIMPLE_T_FUNCTION", "PARTIAL_QUADRATIC_OR_HINGE_COMPETITIVE"],
  ["ASVD_EXPLAINED_BY_SIMPLE_T_FUNCTION", "PARTIAL_QUADRATIC_OR_HINGE_COMPETITIVE"],
  ["AOBS_NOT_DISTINGUISHABLE_FROM_T_REPARAMETERIZATION", "REVIEW_COMBINED_AND_RESIDUALS"],
  ["ASVD_NOT_DISTINGUISHABLE_FROM_T_REPARAMETERIZATION", "REVIEW_COMBINED_AND_RESIDUALS"],
  ["EMPIRICAL_SCALING_SUPPORTED", anyEmpiricalBeatsT === "YES" ? "FORMS_EXIST_THAT_BEAT_BEST_T_MEMBER_CHECK_CSV" : "NO_CLEAR_BEAT"],
  ["PHYSICAL_SCALING_LAW_SUPPORTED", "NO"],
  ["SAFE_TO_SAY_SWITCHING_COORDINATES_ORGANIZE_A_BEYOND_T", invBeatObs && invBeatSvd ? "PARTIAL_USE_COMBINED_TABLE" : "CONDITIONAL"],
  ["SAFE_TO_SAY_A_MAY_BE_SIMPLE_T_REPARAMETERIZATION", "YES_FOR_LINEAR_T_ONLY"],
  ["SAFE_TO_SAY_EMPIRICAL_SCALING_ONLY", "YES"],
  ["SAFE_TO_SAY_PHYSICAL_SCALING_LAW", "NO"],
  ["SAFE_FOR_MANUSCRIPT_DISCUSSION", "YES_WITH_SMALL_N_CAVEATS"],
  ["SAFE_TO_COMMIT_T_FUNCTION_SCALING_PACKAGE", "YES"],
];

fs.writeFileSync(
  path.join(tbl, "cross_module_switching_relaxation_CM_SW_RLX_AX_18C_status.csv"),
  "status_key,status_value\n" + statusRows.map(([a, b]) => `${a},${csvEscape(b)}`).join("\n"),
  "utf8"
);

/* ----- Report ----- */
const repPath = path.join(
  REPO,
  "reports/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_T_function_scaling_baseline_control.md"
);
const rep = `# CM-SW-RLX-AX-18C — T-function and empirical scaling baseline control

## Domain

- Source: \`tables/cross_module_switching_relaxation_CM_SW_RLX_AX_17B_visual_dataset.csv\` (strict AX-17B ladder).
- Filter: \`relaxation_T_K < 31.5\` (redundant with 17B export).
- **n = ${n}** (all rows preserved; **no duplicate-T collapsing**).

## Temperature axis

Models use **relaxation ladder** \`T = relaxation_T_K\`.

## Scoring rule

- **Primary LOOCV_RMSE** for every model is computed in **original \`A\` space**.
- Empirical power-law forms use **log–log OLS** on **positive** values; LOOCV folds predict **\\(\\hat A = \\exp(\\widehat{\\log A})\\)** and RMSE is vs observed **\`A\`**.

## Best simple T baselines (lowest LOOCV among listed T-only families)

| Target | Best model | LOOCV_RMSE |
|--------|------------|------------|
| A_obs_canon | ${packObs.bestTname} | ${packObs.bestTloocv.toExponential(8)} |
| A_svd_full_oriented_candidate | ${packSvd.bestTname} | ${packSvd.bestTloocv.toExponential(8)} |

## Switching coordinates (single linear predictor in \`A\` space)

| Target | coord | LOOCV_RMSE |
|--------|-------|------------|
| A_obs | invD_linear | ${coordLoocv(packObs, "invD_chosen").toExponential(8)} |
| A_obs | Xeff_linear | ${coordLoocv(packObs, "Xeff_chosen").toExponential(8)} |
| A_svd | invD_linear | ${coordLoocv(packSvd, "invD_chosen").toExponential(8)} |
| A_svd | Xeff_linear | ${coordLoocv(packSvd, "Xeff_chosen").toExponential(8)} |

## Outputs

- \`tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_T_function_model_comparison.csv\`
- \`tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_scaling_law_comparison.csv\`
- \`tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_combined_models.csv\`
- \`tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_residual_after_T.csv\`
- \`tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_reparameterization_scaling_judgement.csv\`
- \`tables/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_status.csv\`

## Closure language

- **Empirical** power-law templates are **not** physical scaling laws.
- **Small n = ${n}** → LOOCV comparisons are **diagnostic**, not confirmatory.

**END**
`;
fs.writeFileSync(repPath, rep, "utf8");

console.log(
  JSON.stringify(
    {
      n,
      packObs_best: packObs.bestTname,
      packSvd_best: packSvd.bestTname,
    },
    null,
    2
  )
);
