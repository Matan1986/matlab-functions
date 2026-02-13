function plot_harmonic_locking(symRes, fourierPhys)
% plot_harmonic_locking
% ---------------------------------------------------------
% Plot physical axis rotation Δθ0(T) for multiple harmonics
% ONE FIGURE PER FIELD.
%
% Uses: θ0,n = -wrapTo180(φ_n) / n
%
% INPUTS:
%   symRes      – output struct of analyze_AMR_symmetry (zf or fc)
%   fourierPhys – options struct:
%                 .harmonics
%                 .mode
%                 .lockingFields_T   (optional)
%                 .valid.relFrac
%                 .valid.minSpecWeight
%                 .show.lockingOneFigPerField (true/false)

%% -------- sanity checks --------
assert(isstruct(symRes) && isfield(symRes,'channels') && isfield(symRes,'meta'), ...
    'plot_harmonic_locking: symRes must contain .channels and .meta');

T      = symRes.meta.temps(:);
Fields = symRes.meta.fields(:);

C = symRes.channels;
assert(numel(C)==1, 'plot_harmonic_locking expects ONE channel only');
C = C(1);

assert(isfield(C,'n') && isfield(C,'Phi') && isfield(C,'Amp'), ...
    'plot_harmonic_locking: channel must contain n, Phi, Amp');

nAll = C.n(:);

%% -------- harmonics --------
harmonics = fourierPhys.harmonics(:).';
if isempty(harmonics)
    warning('plot_harmonic_locking: no harmonics requested');
    return;
end

%% -------- mode string --------
if isfield(fourierPhys,'mode')
    modeStr = string(fourierPhys.mode);
else
    modeStr = "mode";
end

%% -------- choose fields by VALUE (not index) --------
fieldIdxList = 1:numel(Fields);

if isfield(fourierPhys,'lockingFields_T') && ~isempty(fourierPhys.lockingFields_T)
    reqB = fourierPhys.lockingFields_T(:).';
    tol  = 0.1;   % 100 mT tolerance (physical)
    fieldIdxList = find(arrayfun(@(b) any(abs(b-reqB) < tol), Fields));
    fieldIdxList = fieldIdxList(:).';   % force row vector of scalars
end

if isempty(fieldIdxList)
    warning('plot_harmonic_locking: no fields matched selection');
    return;
end

%% -------- thresholds --------
relFrac = 0.10;
if isfield(fourierPhys,'valid') && isfield(fourierPhys.valid,'relFrac')
    relFrac = fourierPhys.valid.relFrac;
end

minSpecWeight = -Inf;
if isfield(fourierPhys,'valid') && isfield(fourierPhys.valid,'minSpecWeight')
    minSpecWeight = fourierPhys.valid.minSpecWeight;
end

haveSpecW = isfield(C,'SpecWeight');

%% -------- plotting mode --------
oneFigPerField = true;
if isfield(fourierPhys,'show') && isfield(fourierPhys.show,'lockingOneFigPerField')
    oneFigPerField = fourierPhys.show.lockingOneFigPerField;
end

cmap = turbo(numel(harmonics));

%% ================= LOOP OVER FIELDS =================
for f = fieldIdxList

    Bval = Fields(f);

    % --- new figure FOR THIS FIELD ---
    if oneFigPerField
        figure('Color','w','NumberTitle','off');
        hold on;
        set(gcf,'Name',sprintf('%s | Harmonic locking | B = %.2f T', modeStr, Bval));


        set(gcf,'Color','w', ...
            'NumberTitle','off', ...
            'Name',sprintf('%s | Harmonic locking | B = %.2f T', modeStr, Bval));

        hold on;

    end

    legends = {};

    %% ----- loop harmonics -----
    for ih = 1:numel(harmonics)
        disp('---');
        disp(['Plotting field index f = ' num2str(f)]);
        disp(['B = ' num2str(Fields(f)) ' T']);
        nVal = harmonics(ih);
        hIdx = find(nAll == nVal, 1);
        if isempty(hIdx), continue; end

        phi = squeeze(C.Phi(hIdx,:,f)).';
        Amp = squeeze(C.Amp(hIdx,:,f)).';

        Amax = max(Amp(:), [], 'omitnan');
        mask = true(size(Amp));

        if ~isempty(Amax) && isfinite(Amax) && Amax > 0
            mask = Amp >= relFrac * Amax;
        end

        if haveSpecW
            SpecW = squeeze(C.SpecWeight(hIdx,:,f)).';
            mask = mask & (SpecW >= minSpecWeight);
        end

        phi(~mask) = NaN;

        theta0 = -phi / nVal;
        theta0 = wrapTo180(theta0);   % או wrapTo90 / wrapToX — אבל אחיד לכולם

        plot(T, theta0, '-o', ...
            'Color', cmap(ih,:), ...
            'LineWidth', 2, ...
            'MarkerSize', 5);

        legends{end+1} = sprintf('n = %d', nVal);
    end

    %% ----- cosmetics -----
    yline(0,'--','Color',[0.5 0.5 0.5]);
    grid on;

    xlabel('Temperature [K]');
    ylabel('\Delta\theta_0  [deg]');
    title(sprintf('%s | Harmonic locking | B = %.2f T', modeStr, Bval));

    if ~isempty(legends)
        legend(legends,'Location','best');
    else
        text(0.02,0.95,'No valid harmonics', ...
            'Units','normalized','FontSize',12);
    end

end
end

%% -------- helper --------
function y = wrapTo180(x)
y = mod(x+180,360)-180;
end
