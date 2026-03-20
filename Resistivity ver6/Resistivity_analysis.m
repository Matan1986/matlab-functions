function [smoothed_data, fit_data, TC_index, TC2_index, resistivity_at_TH, max_temp_index, ...
          fit_TemperatureK, fit_params, RRR, TC_to_TL_drop, TC_to_TL_drop_normalized, best_fit_model, ...
          dR_dT, d2R_dT2] = ...
          Resistivity_analysis(TemperatureK, resistivity, TH, TL, delta_T, ...
          smoothing_window, edge_ignore_range, sgolay_order, sgolay_frame_length, forced_log_fit, twoTCs)
% RESISTIVITY_ANALYSIS
% Input "resistivity" is already filtered/smoothed externally.

    % ========= DEFAULT OUTPUTS (IMPORTANT!) ========= %
    smoothed_data = resistivity;      % unchanged (we no longer filter inside)
    fit_data = [];
    fit_params = [];
    fit_TemperatureK = [];

    TC_index = NaN;
    TC2_index = NaN;

    resistivity_at_TH = NaN;
    max_temp_index = [];

    RRR = NaN;
    TC_to_TL_drop = NaN;
    TC_to_TL_drop_normalized = NaN;
    dR_dT = [];
    d2R_dT2 = [];

    best_fit_model = '';

    filtered_data = resistivity;   % alias

    % ========= FIND TH INDEX ========= %
    [~, idxNearTH] = min(abs(TemperatureK - TH));
    if abs(TemperatureK(idxNearTH) - TH) <= delta_T
        max_temp_index = idxNearTH;
    end

    % ========= FIND TC (MAIN DISCONTINUITY) ========= %
    first_derivative = diff(smoothed_data);

    if length(first_derivative) < edge_ignore_range*2 + 3
        warning('Not enough points to detect TC');
        return;
    end

    region = first_derivative(edge_ignore_range : end-edge_ignore_range);
    discontinuities = abs(diff(region));

    [maxdisc, TC_index_original] = max(discontinuities);
    if isempty(maxdisc) || maxdisc < 0
        warning('No TC discontinuity found.');
        return;
    end

    TC_index = TC_index_original + edge_ignore_range;

    % ========= FIND SECOND TC IF REQUESTED ========= %
    if twoTCs
        discontinuities(TC_index_original) = -Inf;

        [~, TC2_index_original] = max(discontinuities);

        if isempty(TC2_index_original) || TC2_index_original <= 0
            warning('TC2 not found');
        else
            TC2_index = TC2_index_original + edge_ignore_range;
        end
    end

    % ========= FIND ρ(TL) ========= %
    idxTL = find(abs(TemperatureK - TL) <= delta_T);
    if ~isempty(idxTL)
        resistivity_at_TL = mean(filtered_data(idxTL));
    else
        [~, idxNearTL] = min(abs(TemperatureK - TL));
        resistivity_at_TL = filtered_data(idxNearTL);
    end
    if ~isfinite(resistivity_at_TL) || resistivity_at_TL <= 0
        resistivity_at_TL = max(eps, resistivity_at_TL);
    end

    % ========= FIND ρ(TH) OR FIT IT ========= %
    if ~isempty(max_temp_index)
        resistivity_at_TH = filtered_data(max_temp_index);
    else
        % No TH near data → need to fit
        [~, max_temp_index] = max(TemperatureK);

        Tfit = TemperatureK(TC_index:-1:max_temp_index);
        Rfit = filtered_data(TC_index:-1:max_temp_index);

        [Tfit, idxU] = unique(Tfit);
        Rfit = Rfit(idxU);

        sqrt_model = @(b,x) b(1)*sqrt(x) + b(2);
        log_model  = @(b,x) b(1)*log(x)  + b(2);

        beta0 = [1,0];

        sqrt_params = nlinfit(Tfit, Rfit, sqrt_model, beta0);
        log_params  = nlinfit(Tfit, Rfit, log_model, beta0);

        sqrt_fit_data = sqrt_model(sqrt_params, Tfit);
        log_fit_data  = log_model(log_params,  Tfit);

        sqrt_resid = sum((Rfit - sqrt_fit_data).^2);
        log_resid  = sum((Rfit - log_fit_data).^2);

        if forced_log_fit || (log_resid < sqrt_resid)
            fit_data       = log_fit_data;
            fit_params     = log_params;
            best_fit_model = 'logarithmic';
            resistivity_at_TH = log_model(fit_params, TH);
            fit_TemperatureK = Tfit;
        else
            fit_data       = sqrt_fit_data;
            fit_params     = sqrt_params;
            best_fit_model = 'square_root';
            resistivity_at_TH = sqrt_model(fit_params, TH);
            fit_TemperatureK = Tfit;
        end
    end

    % ========= FINAL METRICS ========= %
    rhoTC = filtered_data(TC_index);
    if ~isfinite(rhoTC) || rhoTC <= 0
        rhoTC = max(eps, rhoTC);
    end

    RRR = resistivity_at_TH / rhoTC;
    TC_to_TL_drop = rhoTC / resistivity_at_TL;
    TC_to_TL_drop_normalized = TC_to_TL_drop / RRR;

    % ========= OPTIONAL DERIVATIVES ========= %
    % Temperature-aware gradients from already prepared smoothed_data.
    dR_dT = gradient(smoothed_data, TemperatureK);
    d2R_dT2 = gradient(dR_dT, TemperatureK);

end
