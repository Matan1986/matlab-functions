function allFits = fitAllRelaxations(Time_table, Moment_table, Temp_table, Field_table, ...
    debug, Hthresh, fitParams, ...
    fitWindow_extraStart_percent, fitWindow_extraEnd_percent,absThreshold,slopeThreshold, fileList, relaxationModel)
% fitAllRelaxations - automatic relaxation analysis and fitting
%
% Performs:
%   1) window selection
%   2) model fit via fitRelaxationModel (log/kww/compare)
%
% Returns a table with:
%   Temp_K | Field_Oe | Minf | dM | M0 | tau | n | R2 | S | model_type | t_start | t_end | data_idx

%% --- Handle missing arguments ---
if nargin < 5, debug = false; end
if nargin < 6, Hthresh = 20; end
if nargin < 7, fitParams = struct(); end   % ensure struct exists
if nargin < 12 || isempty(fileList), fileList = {}; end
if nargin < 13 || isempty(relaxationModel), relaxationModel = 'log'; end

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

    % --- Extract field (if available) and keep vectors aligned ---
    if i <= numel(Field_table) && ~isempty(Field_table{i})
        H = Field_table{i}(:);
    else
        H = [];
    end

    % --- Clean NaN / Inf and enforce monotonic time ---
    t = t(:); M = M(:);
    if ~isempty(H)
        m = min([numel(t), numel(M), numel(H)]);
        t = t(1:m); M = M(1:m); H = H(1:m);
    else
        m = min(numel(t), numel(M));
        t = t(1:m); M = M(1:m);
    end

    ok = isfinite(t) & isfinite(M);
    t = t(ok); M = M(ok);
    if ~isempty(H), H = H(ok); end
    if isempty(t), continue; end

    [t, ord] = sort(t, 'ascend');
    M = M(ord);
    if ~isempty(H), H = H(ord); end

    [t, iu] = unique(t, 'stable');
    M = M(iu);
    if ~isempty(H), H = H(iu); end
    if numel(t) < 30, continue; end

    % === Window selection ===
    [t_fit, M_fit, info] = pickRelaxWindow(t, M, H, debugFit, Hthresh);
    if isempty(t_fit) || numel(t_fit) < 15, continue; end

    %% === User-controlled fit window after H-threshold ===

    % window-control step
    t0_auto = info.t_start;
    t1_auto = info.t_end;

    % window-control step
    t_total = t1_auto - t0_auto;
    if t_total <= 0
        continue;
    end

    % window-control step
    t0_new = t0_auto + fitWindow_extraStart_percent * t_total;

    % window-control step
    t1_new = t1_auto - fitWindow_extraEnd_percent * t_total;

    % window-control step
    if t1_new <= t0_new
        continue;
    end

    % window-control step
    valid = (t >= t0_new) & (t <= t1_new);
    t_fit = t(valid);
    M_fit = M(valid);

    % window-control step
    if numel(t_fit) < 15
        continue;
    end


    %% ===========================================
    %   Determine nominal temperature for this run
    % ===========================================
    Tnom = NaN;

    % Option 1: extract from filename passed via input argument
    if i <= numel(fileList)
        fname = string(fileList{i});
        Tmatch = regexp(fname, '([0-9]+\.?[0-9]*)\s*[Kk]', 'tokens', 'once');
        if ~isempty(Tmatch)
            Tnom = str2double(Tmatch{1});
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
        fprintf('Run %2d: %.2f K - start @ %.1f min  [%s]\n', ...
            i, Tnom, t_fit(1)/60, reason);
    end

    %% --- Detect no-relaxation (temperature-blind) ---
    deltaM = max(M_fit) - min(M_fit);
    dMdtRaw = gradient(M_fit) ./ gradient(t_fit);
    dMdt = abs(dMdtRaw(isfinite(dMdtRaw)));
    if isempty(dMdt)
        meanSlope = NaN;
    else
        meanSlope = mean(dMdt, 'omitnan');
    end

    if deltaM < absThreshold || (~isnan(meanSlope) && meanSlope < slopeThreshold)

        Minf_safe = mean(M_fit);
        dM_safe   = 0;
        M0_safe   = Minf_safe;
        tau_safe  = Inf;
        n_safe    = 1;
        R2_safe   = NaN;
        S_safe    = NaN;
        modelTypeSafe = "fallback";

        tStart = scalarOrNaN(t0_new);
        tEnd   = scalarOrNaN(t1_new);

        if isempty(H)
            Fnom = NaN;
        else
            Fnom = mean(H, 'omitnan');
        end

        row = table( ...
            round(Tnom,2), round(Fnom,1),  ...
            Minf_safe, dM_safe, M0_safe, tau_safe, n_safe, R2_safe, S_safe, modelTypeSafe, ...
            tStart, tEnd, i, ...
            'VariableNames', ...
            {'Temp_K','Field_Oe','Minf','dM','M0','tau','n','R2','S','model_type','t_start','t_end','data_idx'} ...
            );

        rows = [rows; row];
        continue;
    end

    %% ===========================================
    %      Perform configurable model fit
    % ===========================================
    [fitParamsOut, R2, ~, modelType] = fitRelaxationModel(t_fit, M_fit, Tnom, debugFit, fitParams, relaxationModel);

    %% --- Extract fitted values safely ---
    if isstruct(fitParamsOut) && isfield(fitParamsOut,'Minf')
        Minf_safe = scalarOrNaN(fitParamsOut.Minf);
    else
        Minf_safe = NaN;
    end
    if isstruct(fitParamsOut) && isfield(fitParamsOut,'dM')
        dM_safe = scalarOrNaN(fitParamsOut.dM);
    else
        dM_safe = NaN;
    end
    if isstruct(fitParamsOut) && isfield(fitParamsOut,'M0')
        M0_safe = scalarOrNaN(fitParamsOut.M0);
    else
        M0_safe = NaN;
    end
    if isstruct(fitParamsOut) && isfield(fitParamsOut,'tau')
        tau_safe = scalarOrNaN(fitParamsOut.tau);
    else
        tau_safe = NaN;
    end
    if isstruct(fitParamsOut) && isfield(fitParamsOut,'n')
        n_safe = scalarOrNaN(fitParamsOut.n);
    else
        n_safe = NaN;
    end
    R2_safe   = scalarOrNaN(R2);
    if isstruct(fitParamsOut) && isfield(fitParamsOut,'S')
        S_safe = scalarOrNaN(fitParamsOut.S);
    else
        S_safe = NaN;
    end
    modelTypeSafe = string(modelType);

    tStart = scalarOrNaN(t0_new);
    tEnd   = scalarOrNaN(t1_new);

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
        Minf_safe, dM_safe, M0_safe, tau_safe, n_safe, R2_safe, S_safe, modelTypeSafe, ...
        tStart, tEnd, i, ...
        'VariableNames', ...
        {'Temp_K','Field_Oe','Minf','dM','M0','tau','n','R2','S','model_type','t_start','t_end','data_idx'} ...
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

