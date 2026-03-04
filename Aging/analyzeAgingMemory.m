function pauseRuns = analyzeAgingMemory( ...
    T_no, M_no, pauseRuns, dip_window_K, subtractOrder)
% analyzeAgingMemory — Compute ΔM(T) = M_noPause - M_pause
% and extract local memory indicators.
if nargin < 5 || isempty(subtractOrder)
    subtractOrder = 'noMinusPause';
end
for i = 1:numel(pauseRuns)

    T = pauseRuns(i).T;
    M = pauseRuns(i).M;

    % ---------- Common temperature range ----------
    Tmin = max(min(T_no), min(T));
    Tmax = min(max(T_no), max(T));
    if Tmax <= Tmin
        warning('No overlap with no-pause curve for run @ %.1f K.', pauseRuns(i).waitK);
        pauseRuns(i).T_common = [];
        pauseRuns(i).DeltaM   = [];
        continue;
    end

    % ---------- Interpolation ----------
    Tgrid  = linspace(Tmin, Tmax, max(300, numel(T)));
    M_no_i = interp1(T_no, M_no, Tgrid, 'linear');
    M_pa_i = interp1(T,    M,    Tgrid, 'linear');

    switch lower(subtractOrder)

        case 'nominuspause'
            % ΔM = M_noPause − M_pause
            dM = M_no_i - M_pa_i;

        case 'pauseminusno'
            % ΔM = M_pause − M_noPause
            dM = M_pa_i - M_no_i;

        otherwise
            error('Unknown subtractOrder: %s', subtractOrder);
    end


    pauseRuns(i).T_common = Tgrid;
    pauseRuns(i).DeltaM   = dM;

    pauseRuns(i).subtractOrder = subtractOrder;

    % ----- human-readable definition of ΔM -----
    switch lower(subtractOrder)
        case 'nominuspause'
            pauseRuns(i).DeltaM_definition = ...
                'DeltaM = M_{no-pause} - M_{pause}';
        case 'pauseminusno'
            pauseRuns(i).DeltaM_definition = ...
                'DeltaM = M_{pause} - M_{no-pause}';
    end
    % -------------------------------------------

    % ---------- Local memory metrics ----------
    pauseRuns(i).DeltaM_atPause = NaN;
    pauseRuns(i).DeltaM_localMin = NaN;
    pauseRuns(i).T_localMin = NaN;

    Tp = pauseRuns(i).waitK;
    if ~isnan(Tp)
        [~, idxNear] = min(abs(Tgrid - Tp));
        pauseRuns(i).DeltaM_atPause = dM(idxNear);

        if ~isempty(dip_window_K) && dip_window_K > 0
            mask = Tgrid > Tp - dip_window_K & Tgrid < Tp + dip_window_K;
            if any(mask)
                [pauseRuns(i).DeltaM_localMin, j] = min(dM(mask));
                tmask = Tgrid(mask);
                pauseRuns(i).T_localMin = tmask(j);
            end
        end
    end

    % ---------- Derivative of ΔM ----------
    pauseRuns(i).dDeltaM_dT = [];
    pauseRuns(i).dDeltaM_dT_rms = [];

    if numel(dM) >= 11

        % fill possible NaNs
        if any(isnan(dM))
            dM = fillmissing(dM,'linear','EndValues','nearest');
        end

        % smooth before derivative
        dM_s = sgolayfilt(dM, 2, 11);

        % numerical derivative
        dMdT = gradient(dM_s, Tgrid);

        % smooth derivative itself
        dMdT = sgolayfilt(dMdT, 2, 21);

        pauseRuns(i).dDeltaM_dT = dMdT;

        % ---------- Local RMS of derivative ----------
        Trange = Tmax - Tmin;
        rmsWin = round(numel(Tgrid) * (dip_window_K / Trange));
        rmsWin = max(rmsWin, 11);
        if mod(rmsWin,2)==0, rmsWin = rmsWin + 1; end

        pauseRuns(i).dDeltaM_dT_rms = sqrt(movmean(dMdT.^2, [rmsWin 0]));
    end
end
end
