function pauseRuns = analyzeAgingMemory( ...
    T_no, M_no, pauseRuns, dip_window_K, subtractOrder)
% analyzeAgingMemory - Build DeltaM observables and canonical signed DeltaM.
% Canonical sign definition (project-locked):
%   DeltaM_signed = M_pause - M_noPause
% Legacy subtractOrder values are compatibility observables only.
if nargin < 5 || isempty(subtractOrder)
    subtractOrder = 'pauseMinusNo';
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

    % CANONICAL PHYSICS DEFINITION (project-locked):
    %   DeltaM_signed = M_pause - M_noPause
    %
    % Compatibility note:
    %   pauseRuns(i).DeltaM still follows subtractOrder for legacy behavior.
    %   If subtractOrder='noMinusPause', that observable is NON-CANONICAL.
    canonicalDeltaM = M_pa_i - M_no_i;
    switch lower(subtractOrder)
        case 'nominuspause'
            % LEGACY / NON-CANONICAL OBSERVABLE:
            %   DeltaM = M_noPause - M_pause
            dM = M_no_i - M_pa_i;
            DeltaM_signed = canonicalDeltaM;
            deltaMDefinition = 'LEGACY (NON-CANONICAL): DeltaM = M_{no-pause} - M_{pause}';
            deltaMConventionClass = 'legacy_noncanonical_observable';
        case 'pauseminusno'
            % CANONICAL OBSERVABLE:
            %   DeltaM = M_pause - M_noPause
            dM = M_pa_i - M_no_i;
            DeltaM_signed = canonicalDeltaM;
            deltaMDefinition = 'DeltaM = M_{pause} - M_{no-pause}';
            deltaMConventionClass = 'canonical';

        otherwise
            error('Unknown subtractOrder: %s', subtractOrder);
    end


    pauseRuns(i).T_common = Tgrid;
    pauseRuns(i).DeltaM   = dM;
    pauseRuns(i).DeltaM_signed = DeltaM_signed;
    pauseRuns(i).DeltaM_canonical = DeltaM_signed;
    pauseRuns(i).DeltaM_definition_canonical = 'DeltaM = M_{pause} - M_{no-pause}';
    pauseRuns(i).DeltaM_convention_class = deltaMConventionClass;
    pauseRuns(i).DeltaM_is_canonical_observable = strcmp(deltaMConventionClass, 'canonical');

    pauseRuns(i).subtractOrder = subtractOrder;

    % ----- human-readable definition of Î”M -----
    pauseRuns(i).DeltaM_definition = deltaMDefinition;
    pauseRuns(i).DeltaM_definition_used = deltaMDefinition;
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

    % ---------- Derivative of Î”M ----------
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

