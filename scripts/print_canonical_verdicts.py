#!/usr/bin/env python3
"""
PHI/KAPPA STABILITY CANONICAL SPACE ANALYSIS - FINAL VERDICT PRINTER
This script reads the canonical analysis outputs and prints the final verdicts.
"""

import pandas as pd
import os

tables_dir = r'C:\Dev\matlab-functions\tables'

# Read the outputs
summary_file = os.path.join(tables_dir, 'phi_kappa_stability_canonical_summary.csv')
status_file = os.path.join(tables_dir, 'phi_kappa_stability_canonical_status.csv')

df_summary = pd.read_csv(summary_file)
df_status = pd.read_csv(status_file)

# Print verdicts exactly as specified in requirements
print("\n" + "="*70)
print("PHI/KAPPA STABILITY VERDICT - CANONICAL NORMALIZED SPACE")
print("="*70)
print()

# Extract verdicts from status file
execution_status = df_status['EXECUTION_STATUS'].values[0]
phi_stable = df_status['PHI_STABLE_IN_CANONICAL_SPACE'].values[0]
kappa_stable = df_status['KAPPA_STABLE_IN_CANONICAL_SPACE'].values[0]
phi_invariant = df_status['PHI_CANONICAL_INVARIANT'].values[0]
kappa_sign = df_status['KAPPA_CANONICAL_SIGN_CONSISTENT'].values[0]

# Print in exact format requested
print(f"PHI_STABLE_IN_CANONICAL_SPACE={phi_stable}")
print(f"KAPPA_STABLE_IN_CANONICAL_SPACE={kappa_stable}")
print(f"PHI_CANONICAL_INVARIANT={phi_invariant}")
print(f"KAPPA_CANONICAL_SIGN_CONSISTENT={kappa_sign}")
print(f"EXECUTION_STATUS={execution_status}")

print()
print("="*70)
print("FINAL SUMMARY")
print("="*70)
print(f"Canonical pairs analyzed: {len(df_summary)}")
print(f"Verdict files written:")
print(f"  - {summary_file}")
print(f"  - {status_file}")
print("="*70)
