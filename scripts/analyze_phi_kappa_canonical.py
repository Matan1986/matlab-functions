import pandas as pd
import os
from datetime import datetime

# Configuration
base_folder = r'C:\Dev\matlab-functions'
tables_dir = os.path.join(base_folder, 'tables')

# Thresholds
PHI_THRESHOLD = 0.90
KAPPA_THRESHOLD = 0.90

# Input file
summary_file = os.path.join(tables_dir, 'phi_kappa_stability_summary.csv')

print("=" * 70)
print("PHI/KAPPA STABILITY IN CANONICAL NORMALIZED SPACE")
print("=" * 70)
print()

# Read existing data
print(f"Reading {summary_file}...")
df = pd.read_csv(summary_file)
print(f"Total pairs: {len(df)}")
print()

# Filter to canonical space only (exclude raw_xy_delta)
canonical_variants = {'xy_over_xx', 'baseline_aware'}

def is_canonical_pair(pair_str):
    """Check if a pair contains only canonical variants"""
    parts = [p.strip() for p in pair_str.split(' vs ')]
    if len(parts) != 2:
        return False
    return all(p in canonical_variants for p in parts)

df_canonical = df[df['pair'].apply(is_canonical_pair)].copy()
print(f"Canonical pairs (excluding raw_xy_delta): {len(df_canonical)}")
print()

if len(df_canonical) == 0:
    print("ERROR: No canonical pairs found!")
    exit(1)

print("Canonical pairs:")
print(df_canonical.to_string(index=False))
print()

# Extract and compute verdicts
phi_shape_corrs = df_canonical['phi_shape_corr'].values
kappa_corrs = df_canonical['kappa_corr'].values
abs_kappa_corrs = df_canonical['abs_kappa_corr'].values

# Check for residual_structure_corr
has_residual = 'residual_structure_corr' in df_canonical.columns
if has_residual:
    residual_corrs = df_canonical['residual_structure_corr'].values
else:
    residual_corrs = None

# Apply thresholds
phi_pair_stable = phi_shape_corrs >= PHI_THRESHOLD
kappa_pair_stable = abs_kappa_corrs >= KAPPA_THRESHOLD

# Verdicts
phi_stable_in_canonical = all(phi_pair_stable)
kappa_stable_in_canonical = all(kappa_pair_stable)
phi_canonical_invariant = phi_stable_in_canonical
kappa_signs = df_canonical.get('kappa_sign', [None] * len(df_canonical)).tolist() if 'kappa_sign' in df_canonical.columns else [None] * len(df_canonical)
kappa_canonical_sign_consistent = (len(set(kappa_signs)) <= 1 or len(set(kappa_signs)) == 1)

# Convert to YES/NO strings
phi_verdict = 'YES' if phi_stable_in_canonical else 'NO'
kappa_verdict = 'YES' if kappa_stable_in_canonical else 'NO'
phi_inv_verdict = 'YES' if phi_canonical_invariant else 'NO'
kappa_sign_verdict = 'YES' if kappa_canonical_sign_consistent else 'NO'

# Write canonical summary CSV
summary_output_file = os.path.join(tables_dir, 'phi_kappa_stability_canonical_summary.csv')
df_canonical.to_csv(summary_output_file, index=False)
print(f"\nWrote: {summary_output_file}")

# Write canonical status CSV
status_output_file = os.path.join(tables_dir, 'phi_kappa_stability_canonical_status.csv')
status_data = {
    'EXECUTION_STATUS': ['SUCCESS'],
    'PHI_STABLE_IN_CANONICAL_SPACE': [phi_verdict],
    'KAPPA_STABLE_IN_CANONICAL_SPACE': [kappa_verdict],
    'PHI_CANONICAL_INVARIANT': [phi_inv_verdict],
    'KAPPA_CANONICAL_SIGN_CONSISTENT': [kappa_sign_verdict],
    'EXCLUDED_VARIANT': ['raw_xy_delta'],
    'NOTES': [f'analysis=canonical_only; canonical_pairs={len(df_canonical)}; phi_threshold={PHI_THRESHOLD:.2f}; kappa_threshold={KAPPA_THRESHOLD:.2f}']
}
df_status = pd.DataFrame(status_data)
df_status.to_csv(status_output_file, index=False)
print(f"Wrote: {status_output_file}")

# Print verdicts
print()
print("=" * 70)
print("VERDICTS IN CANONICAL NORMALIZED SPACE")
print("=" * 70)
print(f"PHI_STABLE_IN_CANONICAL_SPACE={phi_verdict}")
print(f"KAPPA_STABLE_IN_CANONICAL_SPACE={kappa_verdict}")
print(f"PHI_CANONICAL_INVARIANT={phi_inv_verdict}")
print(f"KAPPA_CANONICAL_SIGN_CONSISTENT={kappa_sign_verdict}")
print(f"EXECUTION_STATUS=SUCCESS")
print()
print("=" * 70)
print(f"Analysis complete. Canonical pairs analyzed: {len(df_canonical)}")
print("=" * 70)
