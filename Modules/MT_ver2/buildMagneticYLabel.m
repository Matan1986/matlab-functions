function yLabelStr = buildMagneticYLabel(unitsMode, plotQuantity)
% BUILDMAGNETICYLABEL
% MATLAB-safe axis labels (TeX interpreter, NOT LaTeX)
%
% unitsMode: 'raw' | 'per_mass' | 'per_co'
% plotQuantity: 'M' | 'M_over_H'

%% Quantity string
switch plotQuantity
    case 'M'
        qtyStr = 'M';
    case 'M_over_H'
        qtyStr = 'M/H';
    otherwise
        error('Unknown plotQuantity: %s', plotQuantity);
end

%% Units string
switch lower(unitsMode)

    case 'raw'
        % Raw MPMS moment
        unitStr = 'emu';

    case 'per_mass'
        if strcmp(plotQuantity,'M')
            unitStr = 'emu g^{-1}';
        else
            unitStr = 'emu g^{-1} Oe^{-1}';
        end

    case 'per_co'
        if strcmp(plotQuantity,'M')
            % μB per Co atom
            unitStr = '\mu_B Co^{-1}';
        else
            % M/H per Co per Oe (MPMS native field unit)
            unitStr = '\mu_B Co^{-1} Oe^{-1}';
        end

    otherwise
        error('Unknown unitsMode: %s', unitsMode);
end

%% Final label
yLabelStr = sprintf('%s (%s)', qtyStr, unitStr);

end
