function allFits = fitAllRelaxations(Time_table, Moment_table, Temp_table, Field_table, ...
    debug, Hthresh, fitParams, ...
    fitWindow_extraStart_percent, fitWindow_extraEnd_percent,absThreshold,slopeThreshold)
% fitAllRelaxations — automatic relaxation analysis and fitting
%
% Performs:
%   1) window selection
%   2) stretched-exponential fit (using fitStretchedExp)
%
% Returns a table with:
%   Temp_K | Field_Oe | Minf | dM | M0 | tau | n | R2 | t_start | t_end | data_idx

%% --- Handle missing arguments ---
if nargin < 5, debug = false; end
if nargin < 6, Hthresh = 20; end
if nargin < 7, fitParams = struct(); end   % ensure struct exists

% Effective fitting debug gate:
% - debug input (from main debug mode)
% - optional fitParams.debugFit override
% This guarantees no debug figures unless one of these is enabled.
debugFit = logical(debug);
if isfield(fitParams,'debugFit') && ~isempty(fitParams.debugFit)
    debugFit = debugFit || logical(fitParams.debugFit);
end

n = numel(Time_table);
rows = [];

if debugFit
    fprintf('\n=== Performing automatic relaxation fits ===\n');
    fprintf('Window selection: |H| < %.1f Oe (fallback: dM/dt minimum)\n\n', Hthresh);
end

%% ========================================================
%                  MAIN FITTING LOOP
% =========================================================
for i = 1:n

    t = Time_table{i};
    M = Moment_table{i};
    if isempty(t) || isempty(M), continue; end

    % --- Clean NaN / Inf ---
    t = t(:); M = M(:);
    ok = isfinite(t) & isfinite(M);
    t = t(ok); M = M(ok);
    if numel(t) < 30, continue; end

    % --- Extract field (if available) ---
    if i <= numel(Field_table) && ~isempty(Field_table{i})
        H = Field_table{i};
    else
        H = [];
    end

    % === Window selection ===
    [t_fit, M_fit, info] = pickRelaxWindow(t, M, Field_table{i}, debugFit, Hthresh);
    if isempty(t_fit) || numel(t_fit) < 15, continue; end

    %% === User-controlled fit window after H-threshold ===

    % בסיס: חלון אוטומטי מהאלגוריתם
    t0_auto = info.t_start;
    t1_auto = info.t_end;

    % משך הרלקסציה שנבחר ע"י המנגנון האוטומטי
    t_total = t1_auto - t0_auto;
    if t_total <= 0
        continue;
    end

    % זמן התחלה חדש
    t0_new = t0_auto + fitWindow_extraStart_percent * t_total;

    % זמן סיום חדש
    t1_new = t1_auto - fitWindow_extraEnd_percent * t_total;

    % הגנה: שהחלון לא יתהפך
    if t1_new <= t0_new
        continue;
    end

    % בחירת הנקודות
    valid = (t >= t0_new) & (t <= t1_new);
    t_fit = t(valid);
    M_fit = M(valid);

    % הגנה – חייבים מינימום נקודות
    if numel(t_fit) < 15
        continue;
    end


    %% ===========================================
    %   Determine nominal temperature for this run
    % ===========================================
    Tnom = NaN;

    % Option 1: extract from filename in base workspace
    if evalin('base','exist("fileList","var")')
        flist = evalin('base','fileList');
        if i <= numel(flist)
            fname = string(flist{i});
            Tmatch = regexp(fname, '([0-9]+\.?[0-9]*)\s*[Kk]', 'tokens', 'once');
            if ~isempty(Tmatch)
                Tnom = str2double(Tmatch{1});
            end
        end
    end

    % Option 2: fallback to mean temperature from data
    if isnan(Tnom)
        if i <= numel(Temp_table) && ~isempty(Temp_table{i})
            Tnom = mean(Temp_table{i}, 'omitnan');
        else
            Tnom = NaN;
        end
    end

    % --- Reason for window selection (debug only) ---
    if isempty(H)
        reason = 'NO FIELD DATA (dM/dt used)';
    else
        reason = info.reason;
    end

    if debugFit
        fprintf('Run %2d: %.2f K — start @ %.1f min  [%s]\n', ...
            i, Tnom, t_fit(1)/60, reason);
    end

    %% --- Detect no-relaxation (temperature-blind) ---
    deltaM = max(M_fit) - min(M_fit);
    dMdt   = abs( gradient(M_fit) ./ gradient(t_fit) );
    meanSlope = mean(dMdt);

    if deltaM < absThreshold || meanSlope < slopeThreshold

        Minf_safe = mean(M_fit);
        dM_safe   = 0;
        M0_safe   = Minf_safe;
        tau_safe  = Inf;
        n_safe    = 1;
        R2_safe   = 1;

        tStart = scalarOrNaN(info.t_start);
        tEnd   = scalarOrNaN(info.t_end);

        if isempty(H)
            Fnom = NaN;
        else
            Fnom = mean(H, 'omitnan');
        end

        row = table( ...
            round(Tnom,2), round(Fnom,1),  ...
            Minf_safe, dM_safe, M0_safe, tau_safe, n_safe, R2_safe, ...
            tStart, tEnd, i, ...
            'VariableNames', ...
            {'Temp_K','Field_Oe','Minf','dM','M0','tau','n','R2','t_start','t_end','data_idx'} ...
            );

        rows = [rows; row];
        continue;
    end

    %% ===========================================
    %      Perform stretched-exponential fit
    % ===========================================
    [fitParamsOut, R2] = fitStretchedExp(t_fit, M_fit, Tnom, debugFit, fitParams);

    %% --- Extract fitted values safely ---
    Minf_safe = scalarOrNaN(fitParamsOut.Minf);
    dM_safe   = scalarOrNaN(fitParamsOut.dM);
    M0_safe   = scalarOrNaN(fitParamsOut.M0);
    tau_safe  = scalarOrNaN(fitParamsOut.tau);
    n_safe    = scalarOrNaN(fitParamsOut.n);
    R2_safe   = scalarOrNaN(R2);

    tStart = scalarOrNaN(info.t_start);
    tEnd   = scalarOrNaN(info.t_end);

    %% --- Mean field value (or NaN if not available) ---
    if isempty(H)
        Fnom = NaN;
    else
        Fnom = mean(H, 'omitnan');
    end

    %% === Build output row ===
    row = table( ...
        round(Tnom,2), ...
        round(Fnom,1), ...
        Minf_safe, dM_safe, M0_safe, tau_safe, n_safe, R2_safe, ...
        tStart, tEnd, i, ...
        'VariableNames', ...
        {'Temp_K','Field_Oe','Minf','dM','M0','tau','n','R2','t_start','t_end','data_idx'} ...
        );

    rows = [rows; row];
end

%% --- Sort output table ---
if isempty(rows)
    allFits = table();
elseif height(rows) < 2
    allFits = rows;
else
    allFits = sortrows(rows, {'Temp_K','Field_Oe'});
end

%% --- Summary ---
if debugFit
    if isempty(allFits)
        warning('No valid relaxation fits found.');
    else
        fprintf('\nFitted %d relaxation curves successfully.\n', height(allFits));
    end
end

end
