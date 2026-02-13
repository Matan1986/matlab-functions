% =========================================================
% Plot Fourier symmetry maps for one AMR channel
%
% Phase is shown ONLY if:
% (1) Dominant harmonic amplitude at temperature T is significant:
%     AmaxT(T) >= symOpts.specWeightMin
% (2) Harmonic amplitude is significant יחסית לדומיננטית:
%     A(n,T) >= symOpts.phaseRelFrac * AmaxT(T)
%
% IMPORTANT:
% - NaNs MUST be transparent in imagesc (otherwise it looks like "no masking").
% =========================================================
function plot_AMR_maps_one_channel(chRes, fields, temps, symOpts, symMode)

%% ----------------- safe defaults (MUST BE FIRST) -----------------
if nargin < 4 || isempty(symOpts), symOpts = struct(); end
if nargin < 5 || isempty(symMode), symMode = ''; end

if ~isfield(symOpts,'specWeightMin'), symOpts.specWeightMin = 0; end
if ~isfield(symOpts,'phaseRelFrac'),  symOpts.phaseRelFrac  = 0.10; end

Amp  = chRes.Amp;   % [nH x nT x nF]
Phi  = chRes.Phi;   % [nH x nT x nF]
nVec = chRes.n;

nT = numel(temps);
xT = 1:nT;

%% ================= loop fields =================
for f = 1:numel(fields)

    A = Amp(:,:,f);   % [nH x nT]
    P = Phi(:,:,f);   % [nH x nT]

    if all(isnan(A),'all')
        continue;
    end

    % ---- dominant amplitude per temperature ----
    AmaxT = max(A, [], 1, 'omitnan');   % [1 x nT]

    % ---- debug print (once per field) ----
    fprintf('---\nplot_AMR_maps_one_channel | %s | B=%.3g T\n', chRes.tag, fields(f));
    fprintf('specWeightMin = %.3g | phaseRelFrac = %.3g\n', symOpts.specWeightMin, symOpts.phaseRelFrac);
    fprintf('AmaxT: min = %.3g | max = %.3g\n', min(AmaxT,[],'omitnan'), max(AmaxT,[],'omitnan'));

    %% ===============================
    % Amplitude map A_n(T)
    % ===============================
    figure('Name',sprintf('%sAMR | A_n(T) | %s | B = %.2f T', ...
        symMode, chRes.tag, fields(f)), 'Color','w');

    hA = imagesc(xT, nVec, A);
    axis xy;

    xticks(xT);
    xticklabels(string(temps));

    xlabel('Temperature [K]');
    ylabel('Harmonic order n');

    title(sprintf('%sAMR: Fourier amplitude A_n(T) | %s | B = %.2f T', ...
        symMode, chRes.tag, fields(f)), 'Interpreter','none');

    cb = colorbar;
    ylabel(cb,'A_n of \DeltaR/R','Interpreter','tex');

    % (optional) if you ever want NaNs in amplitude transparent too:
    % set(hA,'AlphaData',~isnan(A)); set(gca,'Color',[1 1 1]);

    %% ===============================
    % Phase map φ_n(T) with FULL masking
    % ===============================
    Pmasked = NaN(size(P));

    for t = 1:nT

        % (1) temperature-level validity: need some AMR signal
        if ~isfinite(AmaxT(t)) || (AmaxT(t) < symOpts.specWeightMin)
            continue;
        end

        % (2) harmonic-level validity: harmonic must be significant
        Athr = symOpts.phaseRelFrac * AmaxT(t);
        goodH = A(:,t) >= Athr;

        Pmasked(goodH, t) = P(goodH, t);
    end

    figure('Name',sprintf('%sAMR | \\phi_n(T) | %s | B = %.2f T', ...
        symMode, chRes.tag, fields(f)), 'Color','w');

    hP = imagesc(xT, nVec, Pmasked);
    axis xy;

    % --------- THE IMPORTANT FIX: make NaNs invisible ----------
    set(hP,'AlphaData', ~isnan(Pmasked));
   set(gca,'Color','none');    % ← שקיפות
    % -----------------------------------------------------------

    xticks(xT);
    xticklabels(string(temps));

    xlabel('Temperature [K]');
    ylabel('Harmonic order n');

    title(sprintf('%sAMR: Fourier phase \\phi_n(T) | %s | B = %.2f T', ...
        symMode, chRes.tag, fields(f)), 'Interpreter','none');

    cb = colorbar;
    ylabel(cb,'Phase \phi_n  [deg]','Interpreter','tex');

end

end
