function [unitsRatio, yLabelStr] = compute_unitsRatio_MT(unitsMode, mass)
% COMPUTE_UNITSRATIO_MT
%   Returns unitsRatio for MT measurements + proper ylabel string.
%
% unitsMode options:
%   'raw'       – raw MPMS moment units (emu)
%   'per_mass'  – normalized by sample mass (emu/g)
%   'per_co'    – convert to μB per Co atom (for Co1/3TaS2)
%
% mass – sample mass in mg

switch lower(unitsMode)

    case 'raw'
        % Raw MPMS moment
        unitsRatio = 1;
        yLabelStr  = 'M (emu)';

    case 'per_mass'
        % Normalize by sample mass (g)
        unitsRatio = 1 / (mass * 1e-3);
        yLabelStr  = 'M / mass (emu g^{-1})';

    case 'per_co'
        % Convert MPMS moment (emu) → μB per Co atom

        % --- Step 1: molar mass of Co_{1/3}TaS_{2} ---
        M_molar = (1/3)*58.9332 + 180.948 + 2*32.066;   % g/mol

        % --- Step 2: total moles of material ---
        n_mols = (mass * 1e-3) / M_molar;

        % --- Step 3: moles of Co ---
        Co_mols = n_mols / 3;

        % --- Step 4: number of Co atoms ---
        Co_atoms = Co_mols * 6.02214076e23;

        % --- Step 5: emu → μB conversion ---
        emu_to_muB = 1.078e20;

        % --- Final normalization ---
        unitsRatio = emu_to_muB / Co_atoms;

        % ✔ Clear division, no inverse power, no oxidation state
        yLabelStr = 'M (\mu_B / Co)';

    otherwise
        error('Unknown unitsMode: %s', unitsMode);
end

end
