# Relaxation activity naming contract (RLX-CANONICAL-SURVEY-08A)

## 1. Why a naming contract is required

Relaxation now exposes **two canonical coordinates with different roles**: a **direct observable amplitude** and a **rank-1 map coordinate family**. Legacy filenames (`m0`, `A`, `A_T`) overload symbols across pipelines. AR01 through CLOSURE-07 closed the numeric lineage for RF3R2 activity scalars; this contract prevents new analyses from reintroducing ambiguous prose or bare symbols.

## 2. Allowed canonical names

| Name | Meaning |
|------|---------|
| **A_obs_canon** | Canonical **direct observable** relaxation amplitude (maps to RCON **A_obs** column family with stated provenance). |
| **A_svd_canon** | Canonical **rank-1 SVD coordinate family** on the relaxation map (not one raw column; see aliases). |
| **A_T_canon** | Preferred **human-readable representative** of **A_svd_canon** when referencing the legacy definition **sigma1*U(:,1)** with rows=temperature. |
| **A_svd_LOO_canon** | Operational **non-leaky** representative (maps to **m0_LOO_SVD_projection** track). |
| **A_svd_full_canon** | Full-map reference representative (maps to **m0_svd** / **SVD_score_mode1**). |

## 3. Alias map

See `tables/relaxation/relaxation_activity_naming_contract_08A_aliases.csv`.

Informal summary:

- **A_obs_canon** aliases **A_obs** when sourced from `relaxation_RCON_02B_Aproj_vs_SVD_score.csv`.
- **A_svd_canon** spans **A_T_canon**, **m0_svd**, **SVD_score_mode1**, **m0_LOO_SVD_projection** under affine/sign conventions documented in Lineage-06 for RF3R2.
- **A_T_old** remains **non-numeric** (missing export).

## 4. Context-specific usage rules

See `tables/relaxation/relaxation_activity_naming_contract_08A_usage_rules.csv`.

Principles:

- **Main text figures:** label **direct observable** vs **rank-1 coordinate** explicitly; never imply competition without roles.
- **Supplement reconstruction:** prefer **A_svd_LOO_canon** for held-out robustness narratives.
- **Cross-module:** carry **both** **A_obs_canon** and an **A_svd_canon** member per governed protocol.

## 5. Forbidden bare terms

See `tables/relaxation/relaxation_activity_naming_contract_08A_forbidden_terms.csv`.

Minimum discipline:

- No bare **`A`**, **`m0`**, **`A_T`** in new manuscripts or new tables without namespace.
- No **`canonical amplitude`** singular without naming which coordinate.

## 6. Paper wording

Acceptable pattern:

> Relaxation analysis uses two canonical activity coordinates: **A_obs_canon** for direct observable transparency, and **A_svd_canon** for the intrinsic rank-1 map coordinate family. Within **A_svd_canon**, **A_T_canon** references the explicit legacy **sigma1*U(:,1)** construction; **m0_LOO_SVD_projection** is the operational non-leaky representative used in reconstruction robustness sweeps.

Do **not** write that **A_obs_canon** is less canonical than **A_T_canon**; they are **different roles**.

## 7. Code and table wording

- Prefer **`a_obs_canon`**, **`m0_loo`**, **`m0_full`**, **`a_t_canon`** as distinct variables when implementing new Relaxation-only tools.
- Preserve legacy MATLAB identifiers inside frozen scripts; **new** scripts should adopt suffixed names.

## 8. Correct versus incorrect examples

**Correct**

- "Panel A shows **A_obs_canon** versus temperature; Panel B shows **A_svd_LOO_canon** from LOO-SVD."

**Incorrect**

- "**m0** decreases with temperature" (bare symbol).

**Incorrect**

- "**A_T_canon** disproves **A_obs**" (role confusion).

**Incorrect**

- "**A_T_old** matches **m0_svd** numerically" (missing artifact).
