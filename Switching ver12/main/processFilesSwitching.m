function [stored_data, tableData] = processFilesSwitching( ...
    directory, fileList, sortedValues, ...
    I, Scaling_factor, hampel_filter_window_size, med_filter_window_size, ...
    HampelGlobalPercent, SG_filter_poly_order, SG_filter_frame_size, ...
    swap_Rxy_direction, delay_between_pulses, ...
    num_of_pulses_with_same_dep, safety_margin_for_average_between_pulses_in_percent, ...
    pulses_with_other_num_of_pulses_with_same_dep, num_of_pulses_with_same_dep2, ...
    Normalize_to, RemovePulseOutliers, PulseOutlierPercent, safety_margin_for_outlier_clean_in_percent, debugMode,pulseScheme)

% --- DEFAULT FLAGS ---
if nargin < 17 || isempty(Normalize_to)
    Normalize_to = 1;
end
if nargin < 18 || isempty(RemovePulseOutliers)
    RemovePulseOutliers = false;
end
if nargin < 19 || isempty(PulseOutlierPercent)
    PulseOutlierPercent = 200;
end
if nargin < 20 || isempty(safety_margin_for_outlier_clean_in_percent)
    safety_margin_for_outlier_clean_in_percent = 10;   % default cleaning window (%)
end
if nargin < 21 || isempty(debugMode)
    debugMode = false;
end
if nargin < 22 || isempty(pulseScheme)
    pulseScheme.mode = "alternating";
end
safety_margin_for_average_between_pulses = ...
    delay_between_pulses * (safety_margin_for_average_between_pulses_in_percent/100);

safety_margin_for_outlier_clean = ...
    delay_between_pulses * (safety_margin_for_outlier_clean_in_percent/100);

Nfiles = numel(fileList);
stored_data = cell(Nfiles, 8);
tableData   = struct('ch1', [], 'ch2', [], 'ch3', [], 'ch4', []);

original_num_of_pulses_with_same_dep = num_of_pulses_with_same_dep;

hampel_filter = @(x) hampel(x, hampel_filter_window_size, HampelGlobalPercent); %#ok<NASGU>

for i = 1:Nfiles
    stored_data{i,6} = [];
    stored_data{i,7} = [];
    stored_data{i,8} = [];
    % -----------------------------
    % 1) קריאת קובץ וערוצים
    % -----------------------------
    filename = fullfile(directory, fileList(i).name);
    fileData = importdata(filename);

    time  = fileData.data(:,1);
    nCols = size(fileData.data,2);

    has_LI1 = nCols >= 5  && any(~isnan(fileData.data(:,5)));
    has_LI2 = nCols >= 7  && any(~isnan(fileData.data(:,7)));
    has_LI3 = nCols >= 9  && any(~isnan(fileData.data(:,9)));
    has_LI4 = nCols >= 11 && any(~isnan(fileData.data(:,11)));

    LI_raw    = {};
    physIndex = [];



    if has_LI1
        LI1_XV = fileData.data(:,5);
        if swap_Rxy_direction
            LI1_XV = -LI1_XV;
        end
        LI_raw{end+1}    = LI1_XV; %#ok<AGROW>
        physIndex(end+1) = 1;      %#ok<AGROW>
    end
    if has_LI2
        LI_raw{end+1}    = fileData.data(:,7); %#ok<AGROW>
        physIndex(end+1) = 2;                  %#ok<AGROW>
    end
    if has_LI3
        LI_raw{end+1}    = fileData.data(:,9); %#ok<AGROW>
        physIndex(end+1) = 3;                  %#ok<AGROW>
    end
    if has_LI4
        LI_raw{end+1}    = fileData.data(:,11); %#ok<AGROW>
        physIndex(end+1) = 4;                   %#ok<AGROW>
    end

    numCh = numel(LI_raw);
    % map physical channel number (1..4) -> local column index (1..numCh)
    phys2local = nan(1,4);
    for kk = 1:numCh
        phys2local(physIndex(kk)) = kk;
    end
    assertChannelMappingInvariant_(physIndex, numCh, phys2local);
    if numCh == 0
        warning('processFilesSwitching: No valid LI channels in file %s', fileList(i).name);
        continue;
    end

    % -----------------------------
    % 2) Resistivity UNFILTERED
    % -----------------------------
    R_unf = cell(1,numCh);
    for k = 1:numCh
        R_unf{k} = LI_raw{k} / I * Scaling_factor;
    end

    % -----------------------------
    % 3) FILTERING (Improved Robust Filtering)
    % -----------------------------
    LI_filt = cell(1,numCh);

    for k = 1:numCh
        x = LI_raw{k};

        % ----- Hampel: robust spike removal -----
        xH = hampel(x, hampel_filter_window_size, HampelGlobalPercent);

        % Boundary repair
        if numel(xH)>=2
            xH(1)=xH(2);
            xH(end)=xH(end-1);
        end

        % ----- SG filter: preserves switching edges -----
        N = numel(xH);

        if N >= SG_filter_frame_size
            xSG = sgolayfilt(xH, SG_filter_poly_order, SG_filter_frame_size);
        else
            % fallback: בלי סינון
            xSG = xH;
        end
        if numel(xSG)>=2
            xSG(1)=xSG(2);
            xSG(end)=xSG(end-1);
        end

        % ----- Small median: removes micro-outliers without smearing -----
        xM = medfilt1(xSG, med_filter_window_size);
        if numel(xM)>=2
            xM(1)=xM(2);
            xM(end)=xM(end-1);
        end

        LI_filt{k} = xM;
    end

    % Convert to R
    R_filt = cell(1,numCh);
    R_cent = cell(1,numCh);
    for k = 1:numCh
        R_filt{k} = LI_filt{k} / I * Scaling_factor;
        R_cent{k} = R_filt{k} - mean(R_filt{k});
    end

    % ==========================================
    % 3b) GLOBAL OUTLIER CLEANING (removes huge spikes)
    % ==========================================
    for k = 1:numCh
        x = R_filt{k};

        medx = median(x,'omitnan');
        sigx = 1.4826 * mad(x,1);   % robust sigma estimate

        thr_hi = medx + 8 * sigx;
        thr_lo = medx - 8 * sigx;

        idx_big = (x > thr_hi) | (x < thr_lo);

        if any(idx_big)
            x(idx_big) = medx;
        end

        R_filt{k} = x;
        R_cent{k} = x - mean(x);
    end

    % ==========================================
    % 5) Pulse geometry
    % ==========================================
    if ~isnan(num_of_pulses_with_same_dep2) && ismember(i, pulses_with_other_num_of_pulses_with_same_dep)
        num_of_pulses = num_of_pulses_with_same_dep2;
    else
        num_of_pulses = original_num_of_pulses_with_same_dep;
    end

    pulse_times = time(1) + (0:num_of_pulses-1) * delay_between_pulses;

    intervel_avg_res            = zeros(num_of_pulses, numCh);
    valid_indices_of_all_pulses = false(size(time));

    % ==========================================
    % 6) OUTLIERS near pulses (improved version)
    % ==========================================
    if RemovePulseOutliers
        for k = 1:numCh
            x = R_filt{k};  % work on filtered signal

            for j = 1:num_of_pulses
                t0 = pulse_times(j);

                % ---------- BEFORE pulse ----------
                idx_clean_before = (time >= (t0 - safety_margin_for_outlier_clean)) & (time <= t0);

                if j == 1
                    refIdx = time < t0 - safety_margin_for_average_between_pulses;
                else
                    refIdx = (time >= (pulse_times(j-1) + safety_margin_for_average_between_pulses)) & ...
                        (time <= (t0 - safety_margin_for_average_between_pulses));
                end

                refVals = R_unf{k}(refIdx);

                if numel(refVals) >= 5
                    muB  = median(refVals);
                    sigB = 1.4826 * mad(refVals,1);
                    thrB = PulseOutlierPercent * sigB;

                    valsB = x(idx_clean_before);
                    badB  = abs(valsB - muB) > thrB;

                    valsB(badB) = muB;
                    x(idx_clean_before) = valsB;
                end

                % ---------- AFTER pulse ----------
                if j < num_of_pulses
                    idx_clean_after = (time >= t0) & (time <= (t0 + safety_margin_for_outlier_clean));

                    refIdx_after = (time >= (pulse_times(j) + safety_margin_for_average_between_pulses)) & ...
                        (time <= (pulse_times(j+1) - safety_margin_for_average_between_pulses));

                    refValsA = R_unf{k}(refIdx_after);

                    if numel(refValsA) >= 5
                        muA  = median(refValsA);
                        sigA = 1.4826 * mad(refValsA,1);
                        thrA = PulseOutlierPercent * sigA;

                        valsA = x(idx_clean_after);
                        badA  = abs(valsA - muA) > thrA;

                        valsA(badA) = muA;
                        x(idx_clean_after) = valsA;
                    end
                end

            end % j – pulses

            R_filt{k} = x;
            R_cent{k} = x - mean(x);
        end % k – channels
    end

    % ==========================================
    % 7) INTERVAL AVERAGES — USING R_unf
    % ==========================================
    for j = 1:(num_of_pulses-1)
        start_time = pulse_times(j)   + safety_margin_for_average_between_pulses;
        end_time   = pulse_times(j+1) - safety_margin_for_average_between_pulses;

        idx = time >= start_time & time <= end_time;
        valid_indices_of_all_pulses(idx) = true;

        for k = 1:numCh
            vals = R_unf{k}(idx);
            if isempty(vals)
                intervel_avg_res(j,k) = NaN;
            else
                intervel_avg_res(j,k) = mean(vals,'omitnan');
            end
        end
    end

    % --- last interval ---
    start_time_last = pulse_times(end) + safety_margin_for_average_between_pulses;
    end_time_last   = time(end);
    idx_last = time >= start_time_last & time <= end_time_last;
    valid_indices_of_all_pulses(idx_last) = true;

    for k = 1:numCh
        vals = R_unf{k}(idx_last);
        if isempty(vals)
            intervel_avg_res(end,k) = NaN;
        else
            intervel_avg_res(end,k) = mean(vals,'omitnan');
        end

        % 7b) Centering that ignores the baseline jumps
        for m = 1:numCh
            block_baseline = intervel_avg_res(:,m);
            if numel(block_baseline) > 4
                baseline_clean = mean(block_baseline(2:end-1), 'omitnan');
            else
                baseline_clean = mean(block_baseline, 'omitnan');
            end
            R_cent{m} = R_filt{m} - baseline_clean;
        end
    end

    % =========================================================
    % 7c) UNCERTAINTY:
    %     (1) STD בתוך הפלטו  +  (2) פיזור בין ממוצעי הפלטואים
    %     *בלי* relax_err / non-flatness penalty
    % =========================================================
    sigma_within = zeros(num_of_pulses, numCh);   % STD בתוך חלון הפלטו
    N_mean       = zeros(num_of_pulses, numCh);

    for j = 1:num_of_pulses
        if j < num_of_pulses
            start_time = pulse_times(j)   + safety_margin_for_average_between_pulses;
            end_time   = pulse_times(j+1) - safety_margin_for_average_between_pulses;
        else
            start_time = pulse_times(j) + safety_margin_for_average_between_pulses;
            end_time   = time(end);
        end

        idx = (time >= start_time) & (time <= end_time);

        for k = 1:numCh
            vals = R_unf{k}(idx);
            vals = vals(~isnan(vals));
            N_mean(j,k) = numel(vals);

            if N_mean(j,k) <= 4
                sigma_within(j,k) = NaN;
            else
                sigma_within(j,k) = std(vals,'omitnan');   % STD פשוט
            end
        end
    end

    % (2) pulse-to-pulse scatter of plateau MEANS (same current)
    sigma_between = zeros(1,numCh);
    for k = 1:numCh
        x = intervel_avg_res(:,k);
        x = x(~isnan(x));
        if numel(x) >= 3
            sigma_between(k) = std(x,'omitnan');
        else
            sigma_between(k) = NaN;
        end
    end

    % Combine (quadrature): sigma_total(j,k) = sqrt( sigma_within^2 + sigma_between^2 )
    sigma_total = zeros(num_of_pulses, numCh);
    for k = 1:numCh
        sigma_total(:,k) = sqrt( sigma_within(:,k).^2 );
    end
    % ==========================================
    % 7d) Repeated-pulse block jump metric
    % ==========================================
    numPulses = size(intervel_avg_res,1);

    if mod(numPulses,2) ~= 0
        warning('Odd number of pulses in file %d: cannot split cleanly', i);
    end

    blockSize = floor(numPulses / 2);

    numCh     = size(intervel_avg_res,2);

    if numPulses >= 2*blockSize
        dR_blocks = intervel_avg_res(blockSize+1,:) ...
            - intervel_avg_res(blockSize,:);
        blockJumpMetric = dR_blocks;
    else
        blockJumpMetric = nan(1,numCh);
    end




    % ==========================================
    % 8) NORMALIZATION + P2P stats
    % ==========================================
    refBase_vec = nan(1,numCh);
    if isscalar(Normalize_to) && isnumeric(Normalize_to)
        Normalize_to_vec = repmat(Normalize_to, 1, numCh);
    elseif isnumeric(Normalize_to)
        nNorm = numel(Normalize_to);
        if nNorm > numCh
            Normalize_to_vec = Normalize_to(1:numCh);
        elseif nNorm < numCh
            Normalize_to_vec = [Normalize_to(:).' repmat(Normalize_to(end), 1, numCh - nNorm)];
        else
            Normalize_to_vec = Normalize_to;
        end
    else
        Normalize_to_vec = Normalize_to;
    end

    keysF              = arrayfun(@(p) sprintf('ch%d', p), physIndex, 'UniformOutput', false);
    Normalize_to_local = resolve_norm_indices(Normalize_to_vec, keysF);

    diff_res   = diff(intervel_avg_res,1,1);
    avg_p2p    = zeros(1,numCh);
    std_p2p    = zeros(1,numCh);
    avg_resall = zeros(1,numCh);
    change_pct = zeros(1,numCh);
    p2p_uncert = zeros(1,numCh);   % propagated uncertainty of P2P

    for k = 1:numCh
        p2p_raw = diff_res(:,k);
        p2p_abs = abs(p2p_raw);

        skipFirstSteps = 1;   % number of conditioning steps to exclude (0 to disable)

        % ---- exclude conditioning step(s) BEFORE statistics ----
        if skipFirstSteps > 0 && numel(p2p_abs) >= skipFirstSteps
            p2p_abs(1:skipFirstSteps) = NaN;
        end

        % ---- robust statistics AFTER exclusion ----
        med_p2p = median(p2p_abs,'omitnan');
        mad_p2p = mad(p2p_abs,1);
        thr     = 4 * 1.4826 * mad_p2p;

        % keep only finite + within threshold
        good_idx = isfinite(p2p_abs) & (abs(p2p_abs - med_p2p) <= thr);
        p2p_abs_clean = p2p_abs(good_idx);

        % ---- propagate uncertainty on each step ----
        sigma_dR = zeros(length(p2p_raw),1);
        for jj = 1:length(p2p_raw)
            s1 = sigma_total(jj,   k);
            s2 = sigma_total(jj+1, k);
            sigma_dR(jj) = sqrt(s1^2 + s2^2);
        end

        % exclude same conditioning steps in sigma_dR
        if skipFirstSteps > 0 && numel(sigma_dR) >= skipFirstSteps
            sigma_dR(1:skipFirstSteps) = NaN;
        end

        sigma_dR_clean = sigma_dR(good_idx);
        sigma_P2P      = sqrt(mean(sigma_dR_clean.^2,'omitnan'));  % RMS uncertainty across kept steps
        p2p_uncert(k)  = sigma_P2P;

        % ---- optional sanity check (debug only) ----
        if debugMode
            assert(all(isnan(p2p_abs) == isnan(sigma_dR)), ...
                'Mismatch between excluded P2P steps and sigma_dR');
        end



        % --- choose sign by the 3rd pulse (i.e., ΔR between plateau #2 and #3) ---
        signPulseNumber = 3;                 % 3rd pulse
        signPulseIdx    = signPulseNumber-1; % index in p2p_raw (diff)

        sgn = 1; % default fallback

        if numel(p2p_raw) >= signPulseIdx && signPulseIdx >= 1 && ...
                good_idx(signPulseIdx) && ...
                ~isnan(p2p_raw(signPulseIdx)) && ...
                p2p_raw(signPulseIdx) ~= 0

            sgn = sign(p2p_raw(signPulseIdx));

        else
            s_tmp = nanmean(p2p_raw(good_idx)); % fallback from all "good" steps
            if ~isnan(s_tmp) && s_tmp ~= 0
                sgn = sign(s_tmp);
            else
                sgn = 1; % last-resort fallback
            end
        end


        if isempty(p2p_abs_clean) || all(isnan(p2p_abs_clean))
            avg_p2p(k) = NaN;
            std_p2p(k) = NaN;
        else
            avg_p2p(k) = sgn * mean(p2p_abs_clean,'omitnan');
            std_p2p(k) = std(p2p_abs_clean,'omitnan') ./ mean(p2p_abs_clean,'omitnan') * 100;
        end

        avg_resall(k) = mean(intervel_avg_res(:,k), 'omitnan');

        refIdx_phys  = Normalize_to_vec(k);          % <-- זה מספר פיזי (1..4)
        refIdx_local = phys2local(refIdx_phys);      % convert phys -> local col

        if isnan(refIdx_local)
            refBase = NaN;  % requested reference channel not present in file
        else
            refBase = mean(intervel_avg_res(:,refIdx_local), 'omitnan');
        end
        refBase_vec(k) = refBase;

        refBase_vec(k) = refBase;
        if refBase ~= 0 && ~isnan(refBase)

            if pulseScheme.mode == "repeated"
                % use block-to-block amplitude
                change_pct(k) = (blockJumpMetric(k) / refBase) * 100;
            else
                % alternating: classical P2P
                change_pct(k) = (avg_p2p(k) / refBase) * 100;
            end

        else
            change_pct(k) = NaN;
        end


        if debugMode
            fprintf('DEBUG ch%d: sgn=%+d, avg_p2p=%.4g, std_p2p=%.2f%%, sigma_between=%.4g\n', ...
                k, sgn, avg_p2p(k), std_p2p(k), sigma_between(k));
        end
    end

    % ==========================================
    % 9) Save stored_data (unf / filt / centered)
    % ==========================================
    t_rel = time - min(time);

    data_unf  = t_rel;
    data_filt = t_rel;
    data_cent = t_rel;

    for k = 1:numCh
        data_unf  = [data_unf,  R_unf{k}];
        data_filt = [data_filt, R_filt{k}];
        data_cent = [data_cent, R_cent{k}];
    end

    stored_data{i,1} = data_unf;
    stored_data{i,2} = data_filt;
    stored_data{i,3} = data_cent;
    stored_data{i,4} = valid_indices_of_all_pulses;
    stored_data{i,5} = intervel_avg_res;
    % ==========================================
    % 9b) Pulse-resolved data (for repeated pulses)
    % ==========================================
    % Keep full R vs pulse index information
    stored_data{i,6} = intervel_avg_res;
    % 9c) Physical channel index mapping
    % physIndex(k) = physical channel number (1..4) for column k
    stored_data{i,7} = physIndex;
    stored_data{i,8} = blockJumpMetric;

    % ==========================================
    % 10) tableData לפי הערוצים
    % ==========================================
    sv = sortedValues(i);
    if ~isnumeric(sv)
        sv_val = NaN;
    else
        sv_val = sv;
    end

    rowTemplate = @(k)[ ...
        sv_val, ...
        avg_p2p(k), ...
        avg_resall(k), ...
        change_pct(k), ...
        std_p2p(k), ...
        p2p_uncert(k), ...
        refBase_vec(k) ...
        ];

    for idxCh = 1:numCh
        phys = physIndex(idxCh);
        row  = rowTemplate(idxCh);
        switch phys
            case 1
                tableData.ch1 = [tableData.ch1; row];
            case 2
                tableData.ch2 = [tableData.ch2; row];
            case 3
                tableData.ch3 = [tableData.ch3; row];
            case 4
                tableData.ch4 = [tableData.ch4; row];
        end
    end

    num_of_pulses_with_same_dep = original_num_of_pulses_with_same_dep;
end

end

function assertChannelMappingInvariant_(physIndex, numCh, phys2local)
% Channel mapping contract (materialization-time): physIndex is local->physical; phys2local inverts.
if numCh < 1
    return;
end
if numel(physIndex) ~= numCh
    error('processFilesSwitching:ChannelMappingInvariant', ...
        'physIndex length (%d) must equal numCh (%d).', numel(physIndex), numCh);
end
for kk = 1:numCh
    p = physIndex(kk);
    if ~(isfinite(p) && p == floor(p) && p >= 1 && p <= 4)
        error('processFilesSwitching:ChannelMappingInvariant', ...
            'physIndex(%d) must be an integer in 1..4; got %g.', kk, p);
    end
end
for kk = 1:numCh
    if ~(isfinite(phys2local(physIndex(kk))) && phys2local(physIndex(kk)) == kk)
        error('processFilesSwitching:ChannelMappingInvariant', ...
            'phys2local(physIndex(k)) must equal k for k=%d (inverse mapping failed).', kk);
    end
end
end
