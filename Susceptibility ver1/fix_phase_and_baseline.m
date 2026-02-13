function [chiP_corr, chiPP_corr, meta] = fix_phase_and_baseline(Temp_table, chiP_table, chiPP_table, freq_table, topFrac)
% fix_phase_and_baseline — Correct per-frequency phase and baseline
% Automatically determines the high-T region from each dataset.
%
% Inputs:
%   Temp_table, chiP_table, chiPP_table, freq_table — cell arrays
%   topFrac — fraction of highest temperatures to use for baseline (e.g. 0.2)
%
% Outputs:
%   chiP_corr, chiPP_corr — corrected cell arrays
%   meta — struct with per-frequency info (phase offset, baseline, etc.)

if nargin < 5
    topFrac = 0.2; % use top 20% of temperature range
end

n = numel(Temp_table);
chiP_corr  = chiP_table;
chiPP_corr = chiPP_table;
meta = struct('f',[],'delta_deg',[],'Tmin',[],'Tmax',[],...
              'baselineP',[],'baselinePP',[]);

for i = 1:n
    T  = Temp_table{i};
    P  = chiP_table{i};
    PP = chiPP_table{i};
    f  = mean(freq_table{i});

    % sort temperature just in case
    [T, idx] = sort(T);
    P = P(idx);
    PP = PP(idx);

    % --- automatically select top fraction of T range ---
    nPts = numel(T);
    nTop = max(round(topFrac * nPts), 5); % at least 5 points
    if nTop >= nPts
        nTop = floor(0.2 * nPts);
    end
    mask = false(size(T));
    mask(end-nTop+1:end) = true;  % top temperatures
    Tsel = T(mask);

    % --- complex form ---
    chi = P + 1i*PP;

    % --- estimate phase offset from high-T average ---
    mu = mean(chi(mask), 'omitnan');
    delta = angle(mu);   % rotate so mean at high-T is ~real
    chi_rot = chi * exp(-1i*delta);

    % --- baseline correction using high-T region ---
    baseP  = mean(real(chi_rot(mask)), 'omitnan');
    basePP = mean(imag(chi_rot(mask)), 'omitnan');
    chi_rot = chi_rot - (baseP + 1i*basePP);

    % --- store corrected data ---
    chiP_corr{i}  = real(chi_rot);
    chiPP_corr{i} = imag(chi_rot);

    % --- metadata ---
    meta(i).f = f;
    meta(i).delta_deg = delta * 180/pi;
    meta(i).Tmin = min(Tsel);
    meta(i).Tmax = max(Tsel);
    meta(i).baselineP = baseP;
    meta(i).baselinePP = basePP;
end
end
