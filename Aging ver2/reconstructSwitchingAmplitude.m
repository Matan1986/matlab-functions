function result = reconstructSwitchingAmplitude(mode, pauseRuns, params, Tp, Tsw, Rsw)

% Ensure column vectors
Tp  = Tp(:);
Tsw = Tsw(:);
Rsw = Rsw(:);

% ===============================
% Extract aging metrics
% ===============================
nPauses = numel(pauseRuns);
Dp = zeros(nPauses,1);
Fp = zeros(nPauses,1);

switch lower(mode)

    case 'experimental'
        for i = 1:nPauses
            pr = pauseRuns(i);

            T = pr.T_common(:);
            DeltaM = pr.DeltaM(:);
            Tp_i = Tp(i);

            dip_mask = abs(T - Tp_i) <= params.dipWindowK;

            % baseline excluding dip window
            T_base = T(~dip_mask);
            M_base = DeltaM(~dip_mask);

            if numel(T_base) > 2
                p = polyfit(T_base, M_base, 1);
                baseline = polyval(p, T);
            else
                baseline = mean(DeltaM);
            end

            % --- Dip metric (integrated negative signal)
            dip_signal = DeltaM(dip_mask) - baseline(dip_mask);
            dip_neg = max(0, -dip_signal);
            if numel(dip_neg) > 1
                Dp(i) = trapz(T(dip_mask), dip_neg);
            end

            % --- FM metric (RMS outside dip in wide window)
            wide_mask = abs(T - Tp_i) <= params.wideWindowK & ~dip_mask;
            wide_signal = DeltaM(wide_mask) - baseline(wide_mask);
            if numel(wide_signal) > 1
                Fp(i) = sqrt(mean(wide_signal.^2));
            end
        end

    case 'fit'
        for i = 1:nPauses
            Dp(i) = pauseRuns(i).Dip_area;
            Fp(i) = pauseRuns(i).FM_E;
        end

    otherwise
        error('Mode must be experimental or fit')
end

% ===============================
% Interpolate to switching grid
% ===============================
valid = Dp>0 & Fp>0;
Tp = Tp(valid);
Dp = Dp(valid);
Fp = Fp(valid);

D_interp = interp1(Tp, Dp, Tsw, 'pchip', 'extrap');
F_interp = interp1(Tp, Fp, Tsw, 'pchip', 'extrap');

D_interp = max(D_interp,0);
F_interp = max(F_interp,0);

% Normalize to [0,1]
Dn = D_interp ./ max(D_interp + eps);
Fn = F_interp ./ max(F_interp + eps);

% ===============================
% Define physics window + noise-floor cutoff
% ===============================

% temperature window
mask_T = (Tsw >= params.fitTmin) & (Tsw <= params.fitTmax);

% automatic noise-floor rejection (high-T tail)
noiseFloor = 0.02 * max(Rsw);   % 2% of peak signal (conservative)
mask_SNR = Rsw > noiseFloor;

% final mask used everywhere
mask = mask_T & mask_SNR;

% ===============================
% Lambda scan
% ===============================
lambda_grid = linspace(params.lambdaMin, params.lambdaMax, params.nLambda);

best_sse = Inf;

for lambda = lambda_grid

    Deff = 1 - exp(-Dn/lambda);

    % normalize both symmetrically
    A1 = Deff / max(Deff + eps);
    B1 = Fn   / max(Fn   + eps);

    % coexistence functional
    C = 1 - abs(A1 - B1);
    C = max(min(C,1),0);

    X = [C, ones(size(C))];

    % fit only in the chosen window
    beta = X(mask,:) \ Rsw(mask);

    Rhat = X * beta;

    sse = sum((Rhat(mask) - Rsw(mask)).^2);

    if sse < best_sse
        best_sse = sse;
        best_lambda = lambda;
        best_a = beta(1);
        best_b = beta(2);
        best_Rhat = Rhat;
        best_A = A1;
        best_B = B1;
        best_C = C;
    end
end

% ===============================
% R² (same window)
% ===============================
Ruse      = Rsw(mask);
Rhat_use  = best_Rhat(mask);

SS_tot = sum((Ruse - mean(Ruse)).^2);
SS_res = sum((Rhat_use - Ruse).^2);
R2 = 1 - SS_res/SS_tot;

% ===============================
% Output
% ===============================
result.Rhat    = best_Rhat;
result.lambda  = best_lambda;
result.a       = best_a;
result.b       = best_b;
result.R2      = R2;
result.Tsw     = Tsw;

result.A_basis = best_A;
result.B_basis = best_B;
result.C_basis = best_C;

% for backward compatibility with your old plotting names:
result.D_basis = best_A;
result.F_basis = best_B;

% ===============================
% Mechanism correlations (same window)
% ===============================
A = best_A(mask);
B = best_B(mask);
C = best_C(mask);
R = Ruse;

R_dom = corr(R, 1-A, 'rows','complete');
R_co  = corr(R, C,   'rows','complete');
dA = gradient(A, Tsw(mask));
dB = gradient(B, Tsw(mask));
R_inst = corr(R, abs(dA) + abs(dB), 'rows','complete');

fprintf('\nMechanism correlations:\n');
fprintf('Dominance:   %.3f\n', R_dom);
fprintf('Coexistence: %.3f\n', R_co);
fprintf('Instability: %.3f\n', R_inst);

%% =========================================================
%  Additional overlap models + decision table
% ==========================================================


% Physics window (already defined earlier, reuse it)
A = A(mask);
B = B(mask);
R = R(mask);

% --- Overlap models ---
C1 = 1 - abs(A - B);                 % linear coexistence (already used)
C1 = max(min(C1,1),0);

C2 = A .* B;                        % multiplicative overlap

C3 = 2*A.*B ./ (A + B + eps);      % harmonic-type overlap (requires both finite)


% --- Dominance + Instability ---
Dom = 1 - A;

dA = gradient(A, Tsw(mask));
dB = gradient(B, Tsw(mask));
Inst = abs(dA) + abs(dB);

% --- Balanced overlap (rewards similarity without requiring both large) ---
C4 = 1 - (A - B).^2;
C4 = max(min(C4,1),0);

models = struct();

models(1).name = 'Dominance (1-A)';
models(1).X = Dom;

models(2).name = 'Coexistence |A-B|';
models(2).X = C1;

models(3).name = 'Overlap A*B';
models(3).X = C2;

models(4).name = 'Overlap harmonic';
models(4).X = C3;

models(5).name = 'Instability |dA|+|dB|';
models(5).X = Inst;

% insert as an additional model
models(end+1).name = 'Balanced overlap 1-(A-B)^2';
models(end).X = C4;

nM = numel(models);

R2_list   = zeros(nM,1);
Corr_list = zeros(nM,1);

for k = 1:nM

    Xk = models(k).X(:);
    Xfit = [Xk, ones(size(Xk))];

    beta = Xfit \ R;

    Rhat_k = Xfit * beta;

    SS_tot = sum((R - mean(R)).^2);
    SS_res = sum((Rhat_k - R).^2);

    R2_list(k) = 1 - SS_res/SS_tot;
    Corr_list(k) = corr(R, Xk, 'rows','complete');

end

DecisionTable = table( ...
    string({models.name})', ...
    Corr_list, ...
    R2_list, ...
    'VariableNames', {'Model','Correlation','R2'});
DecisionTable = sortrows(DecisionTable, 'R2', 'descend');
disp(' ');
disp('=== Mechanism decision table ===');
disp(DecisionTable);

% also attach to result struct
result.DecisionTable = DecisionTable;

%% =========================================================
%  Diagnostic: A vs B scatter (balance vs anti-correlation)
% =========================================================
figure('Color','w','Name','A vs B scatter','NumberTitle','off');

A_sc = best_A(mask);
B_sc = best_B(mask);
T_sc = Tsw(mask);

scatter(A_sc, B_sc, 80, T_sc, 'filled');
xlabel('A (Deff normalized)','Interpreter','none');
ylabel('B (FM normalized)','Interpreter','none');
title('A vs B (colored by T)','Interpreter','none');
colorbar; grid on;

R_AB = corr(A_sc, B_sc, 'rows','complete');
fprintf('corr(A,B) = %.3f\n', R_AB);
fprintf('corr(R,T) = %.3f\n', corr(Ruse, Tsw(mask), 'rows','complete'));
fprintf('corr(A*B,T) = %.3f\n', corr((A.*B), Tsw(mask), 'rows','complete'));
fprintf('corr(C1,T) = %.3f\n', corr((1-abs(A-B)), Tsw(mask), 'rows','complete'));

% attach for later use
result.corrAB = R_AB;
end