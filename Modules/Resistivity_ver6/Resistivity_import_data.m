function [TemperatureK, rxy1, rxx2, rxy3, rxx4] = Resistivity_import_data(import, old_ppms, filename, I, d, l, w, convenient_units)
    if import
        if old_ppms
            [~, ~, TemperatureK, ~, LI5_XV, ~, LI6_XV, ~] = read_data_old_ppms(filename);
            Rxy1 = LI5_XV;
            Rxx2 = LI6_XV;
            Rxy3 = zeros(size(TemperatureK)); % Placeholder if old_ppms is true
        else
            [~, ~, TemperatureK, ~, LI1_XV, ~, LI2_XV, ~, LI3_XV, ~, LI4_XV] = read_data(filename);
            Rxy1 = LI1_XV;
            Rxx2 = LI2_XV;
            Rxy3 = LI3_XV;
            Rxx4 = LI4_XV;
        end
        % Convert to resistivity
        A = w * d; % Cross-sectional area in square meters
        Scaling_factor = A / l * convenient_units;
        rxy1 = Rxy1 / I * Scaling_factor;
        rxx2 = Rxx2 / I * Scaling_factor;
        rxy3 = Rxy3 / I * Scaling_factor;
        rxx4 = Rxx4 / I * Scaling_factor;
    else
        error('Import flag is set to false. Data cannot be imported.');
    end
end
