function figs = plot_from_filename_T_by_B(fileDir, filename_dat, normalizeData, subtractMean, TEMP_TOL, FIELD_TOL, chans_raw, chans_filt, ShowRawVsFiltered, SpanLow, SpanMid, SpanHigh)
% (… your header text …)

    % ---- defaults / NaN handling ----
    if nargin < 5 || isempty(TEMP_TOL)  || (isscalar(TEMP_TOL)  && isnan(TEMP_TOL)),  TEMP_TOL  = 0.25; end
    if nargin < 6 || isempty(FIELD_TOL) || (isscalar(FIELD_TOL) && isnan(FIELD_TOL)), FIELD_TOL = 0.15; end
    if nargin < 9 || isempty(ShowRawVsFiltered), ShowRawVsFiltered = false; end
    if nargin < 10 || isempty(SpanLow)  || isnan(SpanLow),  SpanLow  = 0.18; end
    if nargin < 11 || isempty(SpanMid)  || isnan(SpanMid),  SpanMid  = 0.10; end
    if nargin < 12 || isempty(SpanHigh) || isnan(SpanHigh), SpanHigh = 0.12; end

    % --- Parse temps/fields strictly from filename (your existing code) ---
    tokT = regexp(filename_dat,'temps_([0-9p_]+)K','tokens','once');
    tokB = regexp(filename_dat,'fields_([0-9p_]+)T','tokens','once');
    if isempty(tokT), error('Filename is missing "temps_*K".'); end
    if isempty(tokB), error('Filename is missing "fields_*T".'); end
    allTemps    = parse_number_list(tokT{1});
    fieldValues = parse_number_list(tokB{1});
    if isempty(allTemps) || isempty(fieldValues)
        error('Parsed empty temperatures or fields from filename.');
    end

    % --- Minimal metadata & data load (your existing code) ---
    [growth_num, FIB_num] = extract_growth_FIB(fileDir, filename_dat);
    I = extract_current_I(fileDir, filename_dat, NaN);
    Scaling_factor = getScalingFactor(growth_num, FIB_num);
    preset_name = resolve_preset(filename_dat, false, '');
    [chMap, plotChannels, labels, Normalize_to] = select_preset(preset_name);
    fullpath = fullfile(fileDir, filename_dat + ".dat");
    [~, FieldT, TempK, AngleDeg, LI1_XV, ~, LI2_XV, ~, LI3_XV, ~, LI4_XV, ~] = read_data(fullpath); 
    LI_XV = {LI1_XV, LI2_XV, LI3_XV, LI4_XV}; %#ok<NASGU>

    % Fallback if raw/filtered not provided (back-compat)
    if nargin < 7 || isempty(chans_raw)
        chans_raw = build_channels(chMap, {LI1_XV, LI2_XV, LI3_XV, LI4_XV}, I, Scaling_factor);
    end
    if nargin < 8 || isempty(chans_filt)
        chans_filt = chans_raw;
    end

    % --- Choose normalization channel (prefer "xx2") ---
    norm_chan = find(contains(string(struct2cell(labels)),"xx2",'IgnoreCase',true),1,'first');
    if isempty(norm_chan), norm_chan = 2; end
    norm_key = sprintf('ch%d', norm_chan);

    % --- Plot loop ---
    cmap = parula(numel(fieldValues));
    figs = gobjects(0);

    for tVal = allTemps(:).'
        for k = 1:4
            keyk = sprintf('ch%d',k);
            if ~isfield(plotChannels,keyk) || ~plotChannels.(keyk), continue; end

            drew_any = false; f = [];

            key_plain  = plain_label(labels.(keyk));
            norm_plain = plain_label(labels.(norm_key));
            num_ltx    = latex_from_plain_label(key_plain);
            denom_ltx  = latex_from_plain_label(norm_plain);

            for iF = 1:numel(fieldValues)
                B0 = fieldValues(iF);
                idx = abs(TempK - tVal) <= TEMP_TOL & abs(FieldT - B0) <= FIELD_TOL;
                if ~any(idx), continue; end

                % Angle align
                ang = AngleDeg(idx);
                [angS, si] = sort(ang);
                [angU, ia] = unique(angS,'stable');

                % Extract aligned raw & filtered signals
                d_raw  = chans_raw.(keyk)(idx);  d_raw  = d_raw(si);  d_raw  = d_raw(ia);
                d_filt = chans_filt.(keyk)(idx); d_filt = d_filt(si); d_filt = d_filt(ia);

                % Per-channel normalization mapping
                knorm = normalize_index_for_channel(Normalize_to, k, norm_chan);
                denom_raw  = mean(chans_raw.( sprintf('ch%d',knorm) )(idx),  'omitnan');
                denom_filt = mean(chans_filt.(sprintf('ch%d',knorm) )(idx),  'omitnan');
                if ~isfinite(denom_raw)  || abs(denom_raw)  < eps, denom_raw  = 1; end
                if ~isfinite(denom_filt) || abs(denom_filt) < eps, denom_filt = 1; end

                % De-mean + normalize
                if subtractMean
                    d_raw  = d_raw  - mean(d_raw,  'omitnan');
                    d_filt = d_filt - mean(d_filt, 'omitnan');
                end
                if normalizeData
                    d_raw  = d_raw  ./ denom_raw  * 100;
                    d_filt = d_filt ./ denom_filt * 100;
                end

                % Angle-LOESS on filtered curve using your dedicated smoother
                d_loess = smooth_angle_loess(angU, d_filt, B0, ...
                    'UseFiltering', true, 'SpanLow', SpanLow, 'SpanMid', SpanMid, 'SpanHigh', SpanHigh);

                % Create figure
                if ~drew_any
                    figTitleStr = sprintf('AMR Δ%s/%s[%%] at %.2f[K]', key_plain, norm_plain, tVal);
                    f = figure('Name', figTitleStr, 'NumberTitle','off'); hold on; grid on;
                    xlabel('Angle (deg)','Interpreter','none');
                    if normalizeData
                        ylabel(sprintf('\\Delta %s / %s (\\%%)', num_ltx, denom_ltx), 'Interpreter','latex');
                    else
                        ylabel('\Delta \rho [10^{-6} \Omega\cdot cm]', 'Interpreter','latex');
                    end
                    title(sprintf('%.2f K — %s', tVal, key_plain), 'Interpreter','none');
                end

                col = cmap(iF,:);
                if ShowRawVsFiltered
                    plot(angU, d_raw,   ':', 'LineWidth', 1.4, 'Color', col, 'DisplayName', sprintf('%.2f T (raw)',  B0));
                    plot(angU, d_loess, '-', 'LineWidth', 2.2, 'Color', col, 'DisplayName', sprintf('%.2f T (filt)', B0));
                else
                    plot(angU, d_loess, '-', 'LineWidth', 2.2, 'Color', col, 'DisplayName', sprintf('%.2f T', B0));
                end

                drew_any = true;
            end

            if drew_any
                lgd = legend('show','Location','best');
                if ~isempty(lgd) && isvalid(lgd), set(lgd,'Interpreter','none'); end
                figs(end+1) = f; %#ok<AGROW>
            elseif ~isempty(f) && isvalid(f)
                close(f);
            end
        end
    end
end
