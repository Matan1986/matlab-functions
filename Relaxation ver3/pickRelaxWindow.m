function [t_fit, M_fit, info] = pickRelaxWindow(t, M, H, debug, Hthresh)
% pickRelaxWindow — automatic detection of relaxation fitting window
%
% Usage:
%   [t_fit, M_fit, info] = pickRelaxWindow(t, M, H, debug, Hthresh)
%
% Detects the time window where |H| < Hthresh (field off) to fit relaxation.
% Falls back to dM/dt minimum if no valid field region exists.

if nargin < 5, Hthresh = 1; end
if nargin < 4, debug = false; end
info = struct('t_start', NaN, 't_end', NaN, 'reason', '');

% --- Pre-clean ---
t = t(:);
M = M(:);
if ~isempty(H)
    H = H(:);
else
    H = nan(size(t));
end
ok = isfinite(t) & isfinite(M);
t = t(ok); M = M(ok);
if ~isempty(H)
    H = H(ok);
end

% --- Optional smoothing of field to avoid flicker near 0 Oe ---
if ~isempty(H)
    Hsmooth = smooth(H, 11, 'moving');
else
    Hsmooth = H;
end

% --- Main logic: find where |H| < Hthresh ---
mask = abs(Hsmooth) < Hthresh;
t_fit = []; M_fit = [];

if any(mask)
    % --- נזהה את כל המעברים של השדה דרך הסף ---
    below = abs(Hsmooth) < Hthresh;
    cross_idx = find(diff(below) == 1);  % נקודות שבהן נכנס מתחת לסף
    leave_idx = find(diff(below) == -1); % נקודות שבהן יצא מהסף

    % --- אם השדה נשאר מתחת לסף בסוף המדידה, נשתמש בכניסה האחרונה ---
    if isempty(cross_idx)
        idx_start = find(below, 1, 'first');
    else
        idx_start = cross_idx(end) + 1;
    end
    if isempty(leave_idx) || leave_idx(end) < idx_start
        idx_end = length(t);
    else
        idx_end = leave_idx(find(leave_idx > idx_start, 1));
        if isempty(idx_end)
            idx_end = length(t);
        end
    end

    % --- נוודא שהחלון באמת נשאר מתחת לסף ---
    if all(abs(Hsmooth(idx_start:idx_end)) < Hthresh)
        t_start = t(idx_start);
        t_end   = t(idx_end);

        info.t_start = t_start;
        info.t_end   = t_end;
        info.reason  = sprintf('|H| dropped below %.1f Oe and stayed low', Hthresh);

        t_fit = t(t >= t_start & t <= t_end);
        M_fit = M(t >= t_start & t <= t_end);
    end
end


% --- Fallback: if no field info or failed ---
if isempty(t_fit)
    % use derivative minimum
    dMdt = gradient(M) ./ gradient(t);
    [~, idx_min] = min(dMdt);
    t_start = t(idx_min);
    t_end = t_start + 0.2 * (t(end) - t(1));
    info.t_start = t_start;
    info.t_end   = t_end;
    info.reason  = 'dM/dt minimum fallback';
    t_fit = t(t >= t_start & t <= t_end);
    M_fit = M(t >= t_start & t <= t_end);
end

% --- Plot debug view ---
if debug
    figure('Name','Relaxation window','Color','w');
    tiledlayout(3,1);

    % --- Panel 1: M(t) with chosen window
    nexttile;
    plot(t/60, M, 'k'); hold on;
    if ~isempty(t_fit)
        fill([t_fit(1) t_fit(end) t_fit(end) t_fit(1)]/60, ...
             [min(M) min(M) max(M) max(M)], ...
             [0.8 1 0.8], 'FaceAlpha',0.3, 'EdgeColor','none');
        plot(t_fit/60, M(t >= t_fit(1) & t <= t_fit(end)), 'b', 'LineWidth', 1.5);
    end
    xlabel('Time (min)');
    ylabel('M');
    title('Chosen fitting window','FontWeight','bold');

    % --- Panel 2: dM/dt
    nexttile;
    dMdt = gradient(M) ./ gradient(t);
    plot(t/60, dMdt, 'k');
    yline(0,'r--');
    ylabel('dM/dt');
    xlabel('Time (min)');

    % --- Panel 3: Field
    nexttile;
    if ~isempty(H)
        plot(t/60, H, 'b'); hold on;
        yline(Hthresh, 'r--', 'threshold', 'LabelVerticalAlignment','bottom');
        yline(-Hthresh, 'r--');
        ylabel('Field (Oe)');
        xlabel('Time (min)');
        title(sprintf('Magnetic Field (|H| < %.1f Oe)', Hthresh));
    else
        text(0.1,0.5,'No field data available','Units','normalized');
    end
end
end
