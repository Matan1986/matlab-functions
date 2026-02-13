function out = analyze_physical_fourier(symResults, fourierPhys)
% analyze_physical_fourier
% ------------------------------------------------------------
% Physical Fourier analysis for AMR
%
% Supports:
%   - multiple magnetic fields
%   - harmonic selection
%   - field selection
%   - optional complex-plane visualization
%   - physical phase → anisotropy-axis rotation
%
% Main physical quantity:
%   Δθ0(T) = -Δφ_n(T) / n
%
% Required symResults fields:
%   symResults.channels(ic):
%       tag, n, Amp, Phi, Acos, Bsin
%   symResults.meta:
%       temps, fields
%
% fourierPhys options:
%   .harmonics        : vector of n
%   .Tref             : 'firstValid' | numeric
%   .pickFieldIdx     : [] or indices
%   .show.vector      : true/false
%   .show.axisRotation: true/false
%   .valid.relFrac    : relative amplitude threshold

%% ================= defaults =================
if ~isfield(fourierPhys,'harmonics'), fourierPhys.harmonics = []; end
if ~isfield(fourierPhys,'Tref'), fourierPhys.Tref = 'firstValid'; end
if ~isfield(fourierPhys,'pickFieldIdx'), fourierPhys.pickFieldIdx = []; end

if ~isfield(fourierPhys,'show'), fourierPhys.show = struct(); end
if ~isfield(fourierPhys.show,'vector'), fourierPhys.show.vector = true; end
if ~isfield(fourierPhys.show,'axisRotation'), fourierPhys.show.axisRotation = true; end

if ~isfield(fourierPhys,'valid'), fourierPhys.valid = struct(); end
if ~isfield(fourierPhys.valid,'relFrac'), fourierPhys.valid.relFrac = 0.1; end

if ~isfield(fourierPhys,'mode'), fourierPhys.mode = 'AMR'; end

%% ================= metadata =================
T = symResults.meta.temps(:);
B = symResults.meta.fields(:);
nB = numel(B);

if isempty(fourierPhys.pickFieldIdx)
    fieldIdxList = 1:nB;
else
    fieldIdxList = fourierPhys.pickFieldIdx(:).';
end

C = symResults.channels;
out = struct();

%% ================= mode string =================
switch lower(fourierPhys.mode)
    case 'zf', modeStr = 'Zero-field AMR';
    case 'fc', modeStr = 'Field-cooled AMR';
    otherwise, modeStr = 'AMR';
end

%% ================= loop channels =================
for ic = 1:numel(C)

    Ct  = C(ic);
    tag = Ct.tag;
    key = matlab_safe_key(tag);

    fprintf('Analyzing channel "%s" (%s)\n', tag, modeStr);

    out.(key).T = T;
    out.(key).B = B(fieldIdxList);

    nAll = Ct.n(:);
    if isempty(fourierPhys.harmonics)
        harms = nAll.';
    else
        harms = intersect(fourierPhys.harmonics, nAll.');
    end

    %% ================= loop fields =================
    for ib = 1:numel(fieldIdxList)

        f = fieldIdxList(ib);
        Bval = B(f);

        %% --- amplitude stack for validity ---
        Astack = nan(numel(harms), numel(T));
        for k = 1:numel(harms)
            hIdx = find(nAll==harms(k),1);
            Ac = squeeze(Ct.Acos(hIdx,:,f)).';
            Bs = squeeze(Ct.Bsin(hIdx,:,f)).';
            Astack(k,:) = hypot(Ac, Bs);
        end
        maxA = max(Astack,[],1,'omitnan').';

        %% ================= loop harmonics =================
        for h = 1:numel(harms)

            nVal = harms(h);
            hIdx = find(nAll==nVal,1);

            Ac = squeeze(Ct.Acos(hIdx,:,f)).';
            Bs = squeeze(Ct.Bsin(hIdx,:,f)).';
            V  = Ac + 1i*Bs;

            mask = abs(V) >= fourierPhys.valid.relFrac .* maxA;
            V(~mask) = NaN;

            refIdx = choose_ref_index(T, mask, fourierPhys.Tref);
            vref   = V(refIdx);

            %% --- phase → physical axis rotation ---
            phiRel   = rad2deg(angle(V .* conj(vref)));
            phiRel   = wrapTo180(phiRel);
            thetaRel = -phiRel / nVal;
            thetaRel(~mask) = NaN;

            %% ---- store ----
            out.(key).field(ib).n(h).nVal     = nVal;
            out.(key).field(ib).n(h).thetaRel = thetaRel;
            out.(key).field(ib).n(h).V        = V;
            out.(key).field(ib).B             = Bval;

            %% ================= plots =================

            % ---- Δθ0(T) only (phase / axis rotation) ----
            if fourierPhys.show.axisRotation
                figure('Color','w', ...
                    'Name',sprintf('%s | %s | B=%.2fT | n=%d | axis rotation', ...
                    modeStr, tag, Bval, nVal));

                ok = isfinite(thetaRel);
                plot(T(ok), thetaRel(ok), '-', ...
                    'Color',[0.7 0.7 0.7],'LineWidth',1.5);
                hold on;
                scatter(T(ok), thetaRel(ok), 60, T(ok), 'filled');

                yline(0,'--','Color',[0.5 0.5 0.5]);
                grid on;

                xlabel('Temperature [K]');
                ylabel(sprintf('\\Delta\\theta_0 (n=%d) [deg]', nVal));

                cb = colorbar;
                cb.Label.String = 'Temperature [K]';

                title({sprintf('%s | %s', modeStr, tag), ...
                    sprintf('B = %.2f T | Harmonic n = %d', Bval, nVal), ...
                    sprintf('Reference T = %.2f K', T(refIdx))});
            end

            % ---- optional complex plane ----
            if fourierPhys.show.vector
                ok = isfinite(real(V));
                if any(ok)
                    figure('Color','w', ...
                        'Name',sprintf('%s | %s | B=%.2fT | n=%d | Fourier vector', ...
                        modeStr, tag, Bval, nVal));

                    plot(real(V(ok)), imag(V(ok)), '-', ...
                        'Color',[0.7 0.7 0.7],'LineWidth',1.5);
                    hold on;
                    scatter(real(V(ok)), imag(V(ok)), 70, T(ok), 'filled');

                    plot(real(vref), imag(vref), '*', ...
                        'Color',[0 0 0.6],'MarkerSize',14,'LineWidth',2);

                    axis equal;
                    grid on;
                    xlabel(sprintf('A_{cos,%d}', nVal));
                    ylabel(sprintf('B_{sin,%d}', nVal));

                    cb = colorbar;
                    cb.Label.String = 'Temperature [K]';

                    title(sprintf('V_{%d}(T) | %s | B = %.2f T', ...
                        nVal, tag, Bval));
                end
            end

        end
    end
end
end

%% ================= helpers =================
function idx = choose_ref_index(T, mask, Tref)
if ischar(Tref)
    idx = find(mask,1,'first');
    if isempty(idx), idx = 1; end
else
    [~,idx] = min(abs(T - Tref));
end
end

function y = wrapTo180(x)
y = mod(x+180,360)-180;
end

function key = matlab_safe_key(tag)
tag = regexprep(tag,'[^A-Za-z0-9_]','_');
if ~isletter(tag(1)), tag = ['x' tag]; end
key = ['ch_' tag];
end
