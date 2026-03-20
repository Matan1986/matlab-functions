function plot_MT_2D_maps_segments( ...
    Temp_table, VSM_table, Field_table, ...
    increasing_temp_cell_array, decreasing_temp_cell_array, ...
    sortedFields, unitsRatio, plotQuantity, fontsize)

% ============================================
% INIT
% ============================================
T_ZFC = []; H_ZFC = []; M_ZFC = [];
T_FCW = []; H_FCW = []; M_FCW = [];

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

    % column vectors
    T = T(:); M = M(:); H = H(:);

    N = min([numel(T), numel(M), numel(H)]);
    T = T(1:N);
    M = M(1:N);
    H = H(1:N);

    % 🔥 discretize field
    H = round(H / 100) * 100;

    % units
    M = M .* unitsRatio;

    % M/H
    if strcmpi(plotQuantity,'M_over_H')
        valid = abs(H) > 1e-6;
        M(valid) = M(valid)./H(valid);
        M(~valid) = NaN;
    end

    % segments
    inc_seg = increasing_temp_cell_array{i};

    if isempty(inc_seg)
        continue;
    end

    for s = 1:numel(inc_seg)

        seg = inc_seg{s};
        idx = seg(1):seg(2);
        idx = idx(idx>=1 & idx<=N);

        if s == 1
            % ZFC
            T_ZFC = [T_ZFC; T(idx)];
            H_ZFC = [H_ZFC; H(idx)];
            M_ZFC = [M_ZFC; M(idx)];

        elseif s == 2
            % FCW
            T_FCW = [T_FCW; T(idx)];
            H_FCW = [H_FCW; H(idx)];
            M_FCW = [M_FCW; M(idx)];
        end
    end
end

% ============================================
% CLEAN
% ============================================
[T_ZFC,H_ZFC,M_ZFC] = clean_triplet(T_ZFC,H_ZFC,M_ZFC);
[T_FCW,H_FCW,M_FCW] = clean_triplet(T_FCW,H_FCW,M_FCW);

% ============================================
% GRID (REAL PHYSICAL GRID)
% ============================================
Hq = unique([H_ZFC; H_FCW]);
Hq = sort(Hq);

Tmin = min([T_ZFC; T_FCW]);
Tmax = max([T_ZFC; T_FCW]);

nT = 200;
Tq = linspace(Tmin, Tmax, nT);

Z_ZFC = NaN(length(Hq), length(Tq));
Z_FCW = NaN(length(Hq), length(Tq));

dT = 1.75;   % 🔥 temperature bin width

% ============================================
% BINNING
% ============================================
for iH = 1:length(Hq)
    for iT = 1:length(Tq)

        % ZFC
        mask = abs(H_ZFC - Hq(iH)) < 1e-6 & ...
               abs(T_ZFC - Tq(iT)) < dT;

        if any(mask)
            weights = exp(-((T_ZFC(mask)-Tq(iT)).^2)/(2*dT^2));
            Z_ZFC(iH,iT) = sum(weights .* M_ZFC(mask)) / sum(weights);
        end

        % FCW
        mask = abs(H_FCW - Hq(iH)) < 1e-6 & ...
               abs(T_FCW - Tq(iT)) < dT;

        if any(mask)
            weights = exp(-((T_FCW(mask)-Tq(iT)).^2)/(2*dT^2));
            Z_FCW(iH,iT) = sum(weights .* M_FCW(mask)) / sum(weights);
        end
    end
end

Z_DIFF = Z_FCW - Z_ZFC;

% ============================================
% 🔥 OPTIONAL SMOOTHING (SAFE)
% ============================================
sigma = [1.5 0.3];

if exist('imgaussfilt','file')
    Z_ZFC  = imgaussfilt(Z_ZFC, sigma);
    Z_FCW  = imgaussfilt(Z_FCW, sigma);
    Z_DIFF = imgaussfilt(Z_DIFF, sigma);
end

% ============================================
% PLOT
% ============================================
titles = {'ZFC','FCW','FCW - ZFC'};
maps   = {Z_ZFC, Z_FCW, Z_DIFF};

for k = 1:3
    figure('Color','w');
    imagesc(Tq,Hq,maps{k});
    set(gca,'YDir','normal');

    colormap(parula);

    clim = [min(maps{k}(:),[],'omitnan'), ...
            max(maps{k}(:),[],'omitnan')];

    if isfinite(clim(1)) && isfinite(clim(2)) && diff(clim) > 0
        caxis(clim);
    end

    colorbar;

    xlabel('Temperature (K)','FontSize',fontsize);
    ylabel('Field (Oe)','FontSize',fontsize);

    if strcmpi(plotQuantity,'M_over_H')
        ylabel(colorbar,'M/H');
    else
        ylabel(colorbar,'M');
    end

    title(titles{k},'FontSize',fontsize);
    set(gca,'FontSize',0.7*fontsize);

    axis tight;
end

end

% ============================================
% HELPERS
% ============================================
function [T,H,M] = clean_triplet(T,H,M)
    valid = isfinite(T) & isfinite(H) & isfinite(M);
    T = T(valid);
    H = H(valid);
    M = M(valid);
end