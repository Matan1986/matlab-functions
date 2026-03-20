function Plots_MT_Tcuts( ...
    Temp_table, VSM_table, Field_table, ...
    increasing_temp_cell_array, ...
    sortedFields, unitsRatio, ...
    plotQuantity, fontsize, ...
    T_targets)

% ============================================
% USER: TEMPERATURE CUTS
% ============================================
dT = 0.5;                        % tolerance

% ============================================
% INIT STORAGE
% ============================================
nTcuts = numel(T_targets);
H_all = cell(nTcuts,1);
M_all = cell(nTcuts,1);

% ============================================
% LOOP FILES
% ============================================
for i = 1:numel(sortedFields)

    T = Temp_table{i};
    M = VSM_table{i};
    H = Field_table{i};

    if isempty(T) || isempty(M) || isempty(H)
        continue;
    end

    % column + match length
    T = T(:); M = M(:); H = H(:);
    N = min([numel(T), numel(M), numel(H)]);
    T = T(1:N); M = M(1:N); H = H(1:N);

    % round field (important!)
    H = round(H/100)*100;

    % units
    M = M .* unitsRatio;

    % quantity
    if strcmpi(plotQuantity,'M_over_H')
        valid = abs(H) > 1e-6;
        M(valid) = M(valid)./H(valid);
        M(~valid) = NaN;
    end

    % only increasing segments (cleanest)
    inc_seg = increasing_temp_cell_array{i};

    if isempty(inc_seg)
        continue;
    end

    for s = 1:numel(inc_seg)

        seg = inc_seg{s};
        idx = seg(1):seg(2);

        idx = idx(idx>=1 & idx<=N);

        Tseg = T(idx);
        Hseg = H(idx);
        Mseg = M(idx);

        % ====================================
        % MATCH TO TARGET TEMPERATURES
        % ====================================
        for k = 1:nTcuts

            mask = abs(Tseg - T_targets(k)) < dT;

            if any(mask)
                H_all{k} = [H_all{k}; Hseg(mask)];
                M_all{k} = [M_all{k}; Mseg(mask)];
            end
        end
    end
end

% ============================================
% PLOT
% ============================================
figure('Color','w'); hold on; box on; grid on;

colors = lines(nTcuts);

for k = 1:nTcuts

    Hk = H_all{k};
    Mk = M_all{k};

    if isempty(Hk)
        continue;
    end

    % sort for clean curves
    [Hk, idx] = sort(Hk);
    Mk = Mk(idx);

    plot(Hk, Mk, ...
        'LineWidth',2, ...
        'Color',colors(k,:), ...
        'DisplayName', sprintf('%.1f K', T_targets(k)));
end

xlabel('Field (Oe)','FontSize',fontsize);

if strcmpi(plotQuantity,'M_over_H')
    ylabel('M/H','FontSize',fontsize);
else
    ylabel('M','FontSize',fontsize);
end

legend('show','Location','best');
set(gca,'FontSize',fontsize);

end