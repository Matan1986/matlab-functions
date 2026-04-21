function stability = analyzeSwitchingStability( ...
    stored_data, sortedValues, delay_between_pulses_ms, safety_margin_percent, opts)
% analyzeSwitchingStability
% Computes multiple stability metrics for switching traces, with optional debug plots.
%
% Supports conditioning-skip sweeps: opts.skipFirstPlateaus can be scalar or vector.
%
% INPUTS
%   stored_data: cell(Nfiles,>=7) from processFilesSwitching:
%       {i,1} data_unf  = [t_rel, Rch...]
%       {i,2} data_filt = [t_rel, Rch...]
%       {i,3} data_cent = [t_rel, Rch...]
%       {i,4} valid_indices_of_all_pulses (logical)
%       {i,5} intervel_avg_res (numPulses x numCh) plateau means (from UNFILTERED in your pipeline)
%       {i,6} (optional) pulse-resolved copy for repeated pulses
%       {i,7} physIndex row: physical = physIndex(local) for columns 1..numCh (required if numCh>0)
%   sortedValues: vector of the sweep variable for each file (T or B or config index)
%   delay_between_pulses_ms: scalar (ms)
%   safety_margin_percent: scalar (%) used to exclude regions near pulses
%   opts: struct optional fields:
%       .debugMode (false)
%       .debugEveryN (1)
%       .useFiltered (true) -> use stored_data{:,2}; if false use {:,1} (unfiltered)
%       .useCentered (false) -> if true use stored_data{:,3}
%       .stateMethod ("cluster" | "alternating")
%       .minPtsFit (10)
%       .settleFrac (0.9)
%       .skipFirstPlateaus (1)  % scalar OR vector (e.g. [0 1 2])
%       .skipLastPlateaus  (0)
%       .debugPanels (["trace","plateau","states","drift","slope","within","settle","compareSkips"])
%       .debugChannels ([] -> all)
%       .debugFiles ([] -> all)
%       .switchDetect.minDprime (3)
%       .switchDetect.minGapSigma (3)
%
% OUTPUT
%   stability: struct with fields:
%       .opts
%       .summaryTable
%       .perFile(i).metrics(ch)
%       .switching             % auto-detected switching channel info (default skip)
%       .bySkip(s).skipFirstPlateaus, .summaryTable, .perFile, .switching
%
% Metrics (per file & channel, included plateaus only):
%   - plateauStdMean
%   - stateStdHigh/stateStdLow
%   - driftStd
%   - driftSlopeAbs
%   - driftPerPulseAbs
%   - driftSlopeRelToGap
%   - driftPerPulseRelToGap
%   - driftFitR2
%   - driftRangeRelToGap              % NEW
%   - driftEndToStartRelToGap         % NEW
%   - slopeRMS
%   - withinRMS
%   - settleTimeMean
%   - stateGapAbs/stateGapRel
%   - stateSeparationD
%   - flipErrorRate

% ---------------- Defaults ----------------
if nargin < 5 || isempty(opts), opts = struct(); end
if ~isfield(opts,'stateMethod')
    opts.stateMethod = "alternating";
end
if ~isfield(opts,'stabilityThreshold')
    opts.stabilityThreshold = 5;
end
opts.stateMethod = strip(string(opts.stateMethod));
if string(opts.stateMethod)=="repeated"
    if ~isfield(opts,'pulseScheme')
        error('stateMethod="repeated" requires opts.pulseScheme');
    end
end
if ~isfield(opts,'debugMode'),          opts.debugMode = false; end
if ~isfield(opts,'debugEveryN'),        opts.debugEveryN = 1; end
if ~isfield(opts,'useFiltered'),        opts.useFiltered = true; end
if ~isfield(opts,'useCentered'),        opts.useCentered = false; end
if ~isfield(opts,'minPtsFit'),          opts.minPtsFit = 10; end
if ~isfield(opts,'settleFrac'),         opts.settleFrac = 0.9; end
if ~isfield(opts,'skipFirstPlateaus'),  opts.skipFirstPlateaus = 1; end
if ~isfield(opts,'skipLastPlateaus'),   opts.skipLastPlateaus = 0; end
if ~isfield(opts,'debugPanels')
    opts.debugPanels = ["trace","plateau","states","drift","slope","within","settle","compareSkips"];
end
if ~isfield(opts,'debugChannels'),      opts.debugChannels = []; end
if ~isfield(opts,'debugFiles'),         opts.debugFiles = []; end

if ~isfield(opts,'switchDetect') || isempty(opts.switchDetect)
    opts.switchDetect = struct();
end
if ~isfield(opts.switchDetect,'minDprime'),   opts.switchDetect.minDprime = 3; end
if ~isfield(opts.switchDetect,'minGapSigma'), opts.switchDetect.minGapSigma = 3; end

safety_margin_ms = delay_between_pulses_ms * (safety_margin_percent/100);

skipList = opts.skipFirstPlateaus;
if isempty(skipList), skipList = 0; end
skipList = unique(skipList(:).','stable');
opts.stateMethod = strip(string(opts.stateMethod));
% ---------- run for each skip (conditioning sweep) ----------
stability = struct();
stability.opts = opts;
stability.bySkip = repmat(struct( ...
    'skipFirstPlateaus',NaN,'opts',[],'perFile',[],'summaryTable',[],'switching',[]), ...
    numel(skipList), 1);

for s = 1:numel(skipList)
    optsS = opts;
    optsS.skipFirstPlateaus = skipList(s);

    tmp = runOneSkip(stored_data, sortedValues, delay_between_pulses_ms, safety_margin_ms, optsS);

    stability.bySkip(s).skipFirstPlateaus = tmp.skipFirstPlateaus;
    stability.bySkip(s).opts              = tmp.opts;
    stability.bySkip(s).perFile           = tmp.perFile;
    stability.bySkip(s).summaryTable      = tmp.summaryTable;

    % Auto-detect switching channel(s) for THIS skip (once)
    stability.bySkip(s).switching = detectSwitchingFromSummaryTable( ...
        stability.bySkip(s).summaryTable, optsS.switchDetect);
end

% "default" outputs = first skip in list
stability.perFile      = stability.bySkip(1).perFile;
stability.summaryTable = stability.bySkip(1).summaryTable;
stability.switching    = stability.bySkip(1).switching;

% ---------- debug compareSkips (overlay) ----------
if opts.debugMode && any(string(opts.debugPanels)=="compareSkips")
    doCompareSkipsDebug(stability.bySkip, skipList, opts);
end

if opts.debugMode
    printStabilitySummaryCMD(stability);
end

end % main


% =======================================================================
function out = runOneSkip(stored_data, sortedValues, delay_between_pulses_ms, safety_margin_ms, opts)

Nfiles = size(stored_data,1);
rows = {};

out = struct();
out.skipFirstPlateaus = opts.skipFirstPlateaus;
out.opts = opts;
out.perFile = repmat(struct('sortedValue',NaN,'metrics',[]), Nfiles, 1);

for i = 1:Nfiles

    sv = sortedValues(i);
    out.perFile(i).sortedValue = sv;

    % choose signal
    if opts.useCentered
        data = stored_data{i,3};
    elseif opts.useFiltered
        data = stored_data{i,2};
    else
        data = stored_data{i,1};
    end

    if isempty(data) || size(data,2) < 2
        continue;
    end

    t = data(:,1);
    R = data(:,2:end);
    numCh = size(R,2);

    plateauMeans = stored_data{i,5};
    if isempty(plateauMeans)
        continue;
    end
    numPulses = size(plateauMeans,1);
    if size(plateauMeans, 2) ~= numCh
        error('analyzeSwitchingStability:ChannelMapping', ...
            'plateauMeans has %d columns but trace has numCh=%d (file index %d).', ...
            size(plateauMeans, 2), numCh, i);
    end

    physIdxRow = [];
    if size(stored_data, 2) >= 7 && ~isempty(stored_data{i, 7})
        physIdxRow = stored_data{i, 7}(:).';
    end
    assertPhysIndexRowContract_(physIdxRow, numCh, i);

    % pulse times (relative)
    pulse_times = t(1) + (0:numPulses-1) * delay_between_pulses_ms;

    % plateau windows
    plateauWin = cell(numPulses,1);
    for j = 1:numPulses
        if j < numPulses
            t1 = pulse_times(j)   + safety_margin_ms;
            t2 = pulse_times(j+1) - safety_margin_ms;
        else
            t1 = pulse_times(j) + safety_margin_ms;
            t2 = t(end);
        end
        plateauWin{j} = (t >= t1) & (t <= t2);
    end

    metricsCh = repmat(struct( ...
        'plateauStdMean',NaN, ...
        'stateStdHigh',NaN,'stateStdLow',NaN, ...
        'driftStd',NaN, ...
        'driftSlopeAbs',NaN, ...
        'driftPerPulseAbs',NaN, ...
        'driftSlopeRelToGap',NaN, ...
        'driftPerPulseRelToGap',NaN, ...
        'driftFitR2',NaN, ...
        'driftRangeRelToGap',NaN, ...
        'driftEndToStartRelToGap',NaN, ...
        'slopeRMS',NaN, ...
        'withinRMS',NaN, ...
        'settleTimeMean',NaN, ...
        'stateGapAbs',NaN, ...
        'stateGapRel',NaN, ...
        'stateSeparationD',NaN, ...
        'flipErrorRate',NaN, ...
        'switchAmp',[], ...
        'stateMethod',string(opts.stateMethod), ...
        'skipFirstPlateaus',opts.skipFirstPlateaus, ...
        'skipLastPlateaus',opts.skipLastPlateaus), ...
        1, numCh);

    for k = 1:numCh
        pm = plateauMeans(:,k);
        pm = pm(:);

        % included plateaus
        j0 = 1 + max(0, opts.skipFirstPlateaus);
        j1 = numPulses - max(0, opts.skipLastPlateaus);

        useJ = false(numPulses,1);
        if j0 <= j1
            useJ(j0:j1) = true;
        end
        useJ = useJ & ~isnan(pm);

        % ----- classify states -----
        stateLabel = nan(numPulses,1); % 1=A(low), 2=B(high)
        validPm = ~isnan(pm);

        if sum(validPm) >= 2

            switch string(opts.stateMethod)

                case "repeated"
                    % --- use pulseScheme, not constants ---
                    ps = opts.pulseScheme;

                    if ~isfield(ps,'pulsesPerBlock') || isempty(ps.pulsesPerBlock)
                        error('Repeated stateMethod requires pulseScheme.pulsesPerBlock');
                    end

                    pulsesPerBlock = ps.pulsesPerBlock;

                    % block index for each pulse
                    blockIdx = floor((0:numPulses-1)' / pulsesPerBlock);

                    % alternate A/B by block
                    % block 0 -> A(1), 1 -> B(2), 2 -> A(1), ...
                    stateLabel = 1 + mod(blockIdx, 2);

                case "alternating"
                    idx = find(validPm);
                    for jj = 1:numel(idx)
                        stateLabel(idx(jj)) = 1 + mod(jj-1,2);
                    end

                otherwise % "cluster"
                    x = pm(validPm);
                    if numel(x) >= 4
                        try
                            [cIdx, cC] = kmeans(x,2,'Replicates',5,'MaxIter',200);
                            [~, ord] = sort(cC);
                            lowCluster  = ord(1);
                            highCluster = ord(2);

                            tmp = nan(numel(x),1);
                            tmp(cIdx==lowCluster)  = 1;
                            tmp(cIdx==highCluster) = 2;
                            stateLabel(validPm) = tmp;
                        catch
                            medx = median(x,'omitnan');
                            stateLabel(validPm & pm<=medx) = 1;
                            stateLabel(validPm & pm> medx) = 2;
                        end
                    end
            end
        end

        % ----- plateau stats (included) -----
        metricsCh(k).plateauStdMean = std(pm(useJ), 'omitnan');

        pmLow  = pm(useJ & stateLabel==1);
        pmHigh = pm(useJ & stateLabel==2);

        if numel(pmLow)  >= 2, metricsCh(k).stateStdLow  = std(pmLow,'omitnan');  end
        if numel(pmHigh) >= 2, metricsCh(k).stateStdHigh = std(pmHigh,'omitnan'); end

        % state gaps + separation d'
        if ~isempty(pmLow) && ~isempty(pmHigh)
            muL = mean(pmLow,'omitnan');
            muH = mean(pmHigh,'omitnan');
            gap = abs(muH - muL);
            metricsCh(k).stateGapAbs = gap;

            denom = mean(abs(pm(useJ)),'omitnan');
            if isfinite(denom) && denom ~= 0
                metricsCh(k).stateGapRel = gap / denom;
            end

            vL = var(pmLow,'omitnan');
            vH = var(pmHigh,'omitnan');
            sigP = sqrt(0.5*(vL+vH));
            if isfinite(sigP) && sigP > 0
                metricsCh(k).stateSeparationD = gap / sigP; % d'
            end
        end


        % ===== Switching amplitude (Repeated, state-resolved, late/early) =====
        switchAmp = struct('values',[],'median',NaN,'mean',NaN,'std',NaN,'N',0);

        if sum(useJ & ~isnan(stateLabel)) >= 4

            lateFrac  = 0.2;
            earlyFrac = 0.2;

            deltas = [];
            idxUse = find(useJ & ~isnan(stateLabel));

            for jj = 1:numel(idxUse)-1
                j1 = idxUse(jj);
                j2 = idxUse(jj+1);

                % only A <-> B transitions
                if stateLabel(j1) == stateLabel(j2)
                    continue;
                end

                idxP1 = find(plateauWin{j1});
                idxP2 = find(plateauWin{j2});

                if numel(idxP1) < 5 || numel(idxP2) < 5
                    continue;
                end

                n1 = numel(idxP1);
                n2 = numel(idxP2);

                idxLate  = idxP1( ceil((1-lateFrac)*n1) : end );
                idxEarly = idxP2( 1 : ceil(earlyFrac*n2) );

                R1 = mean(R(idxLate,k),'omitnan');
                R2 = mean(R(idxEarly,k),'omitnan');

                if isfinite(R1) && isfinite(R2)
                    deltas(end+1) = abs(R2 - R1); %#ok<AGROW>
                end
            end

            if ~isempty(deltas)
                switchAmp.values = deltas(:);
                switchAmp.N      = numel(deltas);
                switchAmp.median = median(deltas,'omitnan');
                switchAmp.mean   = mean(deltas,'omitnan');
                switchAmp.std    = std(deltas,'omitnan');
            end
        end

        metricsCh(k).switchAmp = switchAmp;

        % ===== DEBUG / SANITY CHECKS (OPTIONAL BUT IMPORTANT) =====
        if opts.debugMode && switchAmp.N < 2
            warning('SwitchAmp: file %d ch %d — only %d A<->B transitions', ...
                i, k, switchAmp.N);
        end

        gapAbs = metricsCh(k).stateGapAbs;
        if opts.debugMode && isfinite(gapAbs) && isfinite(switchAmp.median)
            ratio = switchAmp.median / gapAbs;
            if ratio < 0.3 || ratio > 1.5
                warning('SwitchAmp sanity: file %d ch %d — switchAmp/gap = %.2f', ...
                    i, k, ratio);
            end
        end
        % ---------- NON-LINEAR DRIFT METRICS (ROBUST) ----------
        gapAbs = metricsCh(k).stateGapAbs;
        idxU   = find(useJ & isfinite(pm));

        if numel(idxU) >= 2 && isfinite(gapAbs) && gapAbs > 0
            pmUse = pm(idxU);

            % (1) full excursion of the state during the sequence
            metricsCh(k).driftRangeRelToGap = (max(pmUse) - min(pmUse)) / gapAbs;

            % (2) net change between first and last plateau
            metricsCh(k).driftEndToStartRelToGap = abs(pmUse(end) - pmUse(1)) / gapAbs;
        end

        % ----- drift: linear rate of plateau means vs time -----
        idxU = find(useJ & isfinite(pm));
        if numel(idxU) >= 3
            tPlate = (idxU - 1) * delay_between_pulses_ms;  % ms
            yPlate = pm(idxU);

            pfit = polyfit(tPlate, yPlate, 1);
            b = pfit(1);  % slope R/ms

            yHat = polyval(pfit, tPlate);
            SSres = sum((yPlate - yHat).^2);
            SStot = sum((yPlate - mean(yPlate)).^2);
            if SStot > 0
                R2 = 1 - SSres/SStot;
            else
                R2 = NaN;
            end

            metricsCh(k).driftSlopeAbs    = abs(b);                           % R/ms
            metricsCh(k).driftPerPulseAbs = abs(b) * delay_between_pulses_ms; % R per pulse
            metricsCh(k).driftFitR2       = R2;

            firstIdx = idxU(1);
            drift = pm - pm(firstIdx);
            metricsCh(k).driftStd = std(drift(idxU), 'omitnan');

            gapAbs = metricsCh(k).stateGapAbs;
            if isfinite(gapAbs) && gapAbs > 0
                metricsCh(k).driftSlopeRelToGap    = abs(b) / gapAbs; % 1/ms
                metricsCh(k).driftPerPulseRelToGap = (abs(b) * delay_between_pulses_ms) / gapAbs;
            end
        end

        % within-plateau metrics + settle
        slopes    = nan(numPulses,1);
        withinStd = nan(numPulses,1);
        settleT   = nan(numPulses-1,1);

        for j = 1:numPulses
            if ~useJ(j), continue; end

            idx = plateauWin{j};
            vals = R(idx,k);
            tt   = t(idx);

            if numel(vals) >= opts.minPtsFit
                p = polyfit(tt, vals, 1);
                slopes(j)    = p(1);
                withinStd(j) = std(vals,'omitnan');
            end

            if j < numPulses && useJ(j) && useJ(j+1)
                tPulse = pulse_times(j);
                tStop  = pulse_times(j+1) - safety_margin_ms;
                idxA   = (t >= tPulse) & (t <= tStop);

                if any(idxA) && ~isnan(pm(j)) && ~isnan(pm(j+1))
                    y  = R(idxA,k);
                    ttA = t(idxA);

                    y0 = pm(j);
                    y1 = pm(j+1);
                    dy = y1 - y0;

                    if dy ~= 0
                        frac = opts.settleFrac;
                        yTarget = y0 + frac*dy;

                        if dy > 0
                            idxCross = find(y >= yTarget, 1, 'first');
                        else
                            idxCross = find(y <= yTarget, 1, 'first');
                        end

                        if ~isempty(idxCross)
                            settleT(j) = ttA(idxCross) - tPulse;
                        end
                    end
                end
            end
        end

        metricsCh(k).slopeRMS       = sqrt(mean(slopes(useJ).^2, 'omitnan'));
        metricsCh(k).withinRMS      = sqrt(mean(withinStd(useJ).^2, 'omitnan'));
        metricsCh(k).settleTimeMean = mean(settleT, 'omitnan');

        if isfinite(metricsCh(k).withinRMS) && metricsCh(k).withinRMS > 0 ...
                && isfinite(metricsCh(k).stateGapAbs)

            metricsCh(k).stabilityIndex = ...
                metricsCh(k).stateGapAbs / metricsCh(k).withinRMS;

            metricsCh(k).isStable = ...
                metricsCh(k).stabilityIndex >= opts.stabilityThreshold;
        else
            metricsCh(k).stabilityIndex = NaN;
            metricsCh(k).isStable = false;
        end

        % flipErrorRate (only makes sense for alternating)
        if string(opts.stateMethod)=="alternating"
            idxUU = find(useJ & ~isnan(stateLabel));
            if numel(idxUU) >= 3
                flips = abs(diff(stateLabel(idxUU)));
                metricsCh(k).flipErrorRate = mean(flips==0,'omitnan'); % didn't flip -> error
            end
        end

        % ----- debug figure (per file+channel) -----
        if opts.debugMode && (mod(i-1, opts.debugEveryN)==0)
            if isempty(opts.debugFiles) || ismember(i, opts.debugFiles)
                if isempty(opts.debugChannels) || ismember(k, opts.debugChannels)
                    doDebugPanels(t, R(:,k), pm, stateLabel, useJ, plateauWin, pulse_times, sv, i, k, opts, slopes, withinStd, settleT);
                end
            end
        end
        if isfinite(metricsCh(k).stateGapAbs)
            % ----- append summary row (canonical channel fields: local k + physical physIndex(k)) -----
            chPhys = physIdxRow(k);
            if ~(isfinite(chPhys) && chPhys >= 1 && chPhys <= 4 && chPhys == floor(chPhys))
                error('analyzeSwitchingStability:ChannelMappingContract', ...
                    'switching_channel_physical invalid at file index %d, local k=%d.', i, k);
            end
            rows(end+1,:) = {sv, k, chPhys, ...
                metricsCh(k).plateauStdMean, metricsCh(k).stateStdLow, metricsCh(k).stateStdHigh, ...
                metricsCh(k).driftStd, metricsCh(k).driftSlopeAbs, metricsCh(k).driftPerPulseAbs, ...
                metricsCh(k).driftSlopeRelToGap, metricsCh(k).driftPerPulseRelToGap, metricsCh(k).driftFitR2, ...
                metricsCh(k).driftRangeRelToGap, metricsCh(k).driftEndToStartRelToGap, ...
                metricsCh(k).slopeRMS, metricsCh(k).withinRMS, metricsCh(k).settleTimeMean, ...
                metricsCh(k).stateGapAbs, metricsCh(k).stateGapRel, metricsCh(k).stateSeparationD, metricsCh(k).flipErrorRate,...
                metricsCh(k).switchAmp.median, metricsCh(k).switchAmp.N, ...
                metricsCh(k).stabilityIndex, ...
                metricsCh(k).isStable};
        end
    end

    out.perFile(i).metrics = metricsCh;
end

out.summaryTable = cell2table(rows, 'VariableNames', {
    'depValue','switching_channel_local','switching_channel_physical', ...
    'plateauStdMean','stateStdLow','stateStdHigh', ...
    'driftStd','driftSlopeAbs','driftPerPulseAbs', ...
    'driftSlopeRelToGap','driftPerPulseRelToGap','driftFitR2', ...
    'driftRangeRelToGap','driftEndToStartRelToGap', ...
    'slopeRMS','withinRMS','settleTimeMean', ...
    'stateGapAbs','stateGapRel','stateSeparationD','flipErrorRate',...
    'switchAmpMedian','switchAmpN','stabilityIndex','isStable'});

end


% =======================================================================
function doDebugPanels(t, y, pm, stateLabel, useJ, plateauWin, pulse_times, sv, iFile, ch, opts, slopes, withinStd, settleT)

panels = string(opts.debugPanels);

nPanels = 0;
order = ["trace","plateau","states","drift","slope","within","settle"];
for p = order
    if any(panels==p), nPanels = nPanels + 1; end
end
if nPanels==0, return; end

figure('Name',sprintf('Stability debug | file %d | sv=%.6g | ch=%d | skipFirst=%d', iFile, sv, ch, opts.skipFirstPlateaus));
tl = tiledlayout(nPanels,1,'TileSpacing','compact','Padding','compact');

numPulses = numel(pm);
xPulse = pulse_times(:);

if any(panels=="trace")
    nexttile;
    plot(t, y, '-'); hold on; grid on;
    ylabel(physLabel('symbol','R'));
    title(sprintf('sv=%.6g | ch=%d', sv, ch));
    for j = 1:numel(xPulse)
        xline(xPulse(j),'--');
    end
end

if any(panels=="plateau")
    nexttile;
    plot(t, y, '-'); hold on; grid on;
    yl = ylim;
    for j = 1:numPulses
        idx = plateauWin{j};
        if any(idx)
            x1 = t(find(idx,1,'first'));
            x2 = t(find(idx,1,'last'));
            fa = 0.06; if ~useJ(j), fa = 0.02; end
            patch([x1 x2 x2 x1],[yl(1) yl(1) yl(2) yl(2)],'k','FaceAlpha',fa,'EdgeColor','none');
            plot(mean([x1 x2]), pm(j), 'o', 'MarkerFaceColor','k','MarkerEdgeColor','k');
        end
    end
    ylabel('R + plateaus');
end

if any(panels=="states")
    nexttile;
    plot(t, y, '-'); hold on; grid on;
    yl = ylim; %#ok<NASGU>

    pmLow  = pm(useJ & stateLabel==1);
    pmHigh = pm(useJ & stateLabel==2);

    for j = 1:numPulses
        idx = plateauWin{j};
        if any(idx)
            x1 = t(find(idx,1,'first'));
            x2 = t(find(idx,1,'last'));
            fa = 0.06; if ~useJ(j), fa = 0.02; end
            patch([x1 x2 x2 x1],[min(ylim) min(ylim) max(ylim) max(ylim)],'k','FaceAlpha',fa,'EdgeColor','none');

            if ~isnan(pm(j))
                xm = mean([x1 x2]);
                if ~useJ(j)
                    mk = [0.55 0.55 0.55];
                else
                    if stateLabel(j)==2, mk='r';
                    elseif stateLabel(j)==1, mk='b';
                    else, mk='k';
                    end
                end
                plot(xm, pm(j), 'o', 'MarkerFaceColor',mk,'MarkerEdgeColor',mk);
            end
        end
    end

    if ~isempty(pmLow),  yline(mean(pmLow,'omitnan'),'b-'); end
    if ~isempty(pmHigh), yline(mean(pmHigh,'omitnan'),'r-'); end
    ylabel('states');
end

if any(panels=="drift")
    nexttile;
    idxU = find(useJ);
    if ~isempty(idxU)
        firstIdx = idxU(1);
        drift = pm - pm(firstIdx);
        plot(idxU, drift(idxU), 'o-'); grid on;
        yline(0,'--');
        ylabel('\DeltaR drift');
        xlabel('plateau index');
    else
        text(0.1,0.5,'No included plateaus','Units','normalized');
    end
end

if any(panels=="slope")
    nexttile;
    idxU = find(useJ);
    stem(idxU, slopes(idxU), 'filled'); grid on;
    yline(0,'--');
    ylabel('dR/dt');
    xlabel('plateau index');
end

if any(panels=="within")
    nexttile;
    idxU = find(useJ);
    bar(idxU, withinStd(idxU)); grid on;
    ylabel('STD within');
    xlabel('plateau index');
end

if any(panels=="settle")
    nexttile;
    histogram(settleT(isfinite(settleT)));
    grid on;
    xlabel('settle time (ms)');
    ylabel('count');
end

title(tl, sprintf('stateMethod=%s | settleFrac=%.2f | minPtsFit=%d', ...
    string(opts.stateMethod), opts.settleFrac, opts.minPtsFit));

end


% =======================================================================
function doCompareSkipsDebug(bySkip, skipList, opts)
if isempty(bySkip) || numel(bySkip)<2, return; end

allT = table();
for s = 1:numel(bySkip)
    T = bySkip(s).summaryTable;
    if isempty(T), continue; end
    T.skipFirst = repmat(skipList(s), height(T), 1);
    allT = [allT; T]; %#ok<AGROW>
end
if isempty(allT), return; end

metricsToShow = ["plateauStdMean","driftStd","stateSeparationD","slopeRMS","withinRMS"];
metricsToShow = metricsToShow(ismember(metricsToShow, string(allT.Properties.VariableNames)));

figure('Name','compareSkips | stability summary');
tl = tiledlayout(numel(metricsToShow),1,'TileSpacing','compact','Padding','compact');

for m = 1:numel(metricsToShow)
    nexttile;
    met = metricsToShow(m);

    hold on; grid on;
    for s = 1:numel(skipList)
        Ts = allT(allT.skipFirst==skipList(s),:);
        if isempty(Ts), continue; end

        chans = unique(Ts.switching_channel_physical);
        for ch = chans(:).'
            Tsc = Ts(Ts.switching_channel_physical == ch, :);
            plot(Tsc.depValue, Tsc.(met), 'o-', 'DisplayName', sprintf('skip=%d ch=%d', skipList(s), ch));
        end
    end
    xlabel('depValue');
    ylabel(met);
    if m==1, legend('Location','best'); end
end

title(tl, 'Sensitivity to conditioning skip (skipFirstPlateaus)');
end


% =======================================================================
function printStabilitySummaryCMD(stability)

T = stability.summaryTable;
if isempty(T)
    fprintf('No stability data available.\n');
    return;
end

fprintf('\n================ Switching Stability Summary ================\n');
fprintf('skipFirstPlateaus = %d\n', stability.opts.skipFirstPlateaus);
fprintf('stateMethod       = %s\n\n', stability.opts.stateMethod);

[G, depU, chU] = findgroups(T.depValue, T.switching_channel_physical);

S = splitapply(@(d,gap,wr,drRel,drRange,drEnd,R2) [ ...
    mean(d,'omitnan'), ...
    mean(gap,'omitnan'), ...
    mean(wr,'omitnan'), ...
    mean(drRel,'omitnan'), ...
    mean(drRange,'omitnan'), ...
    mean(drEnd,'omitnan'), ...
    mean(R2,'omitnan')], ...
    T.stateSeparationD, ...
    T.stateGapAbs, ...
    T.withinRMS, ...
    T.driftPerPulseRelToGap, ...
    T.driftRangeRelToGap, ...
    T.driftEndToStartRelToGap, ...
    T.driftFitR2, ...
    G);

U = table(depU, chU, 'VariableNames', {'depValue','switching_channel_physical'});

fprintf('%8s %4s | %6s %8s %8s %10s %10s %10s %6s\n', ...
    'depVal','ch','d''','gap','within','driftRel/p','range/gap','end2start','R2');
fprintf('-------------------------------------------------------------\n');

for i = 1:height(U)
    fprintf('%8.3g %4d | %6.2f %8.3g %8.3g %10.3g %10.3g %10.3g %6.3g\n', ...
        U.depValue(i), U.switching_channel_physical(i), ...
        S(i,1), S(i,2), S(i,3), ...
        S(i,4), S(i,5), S(i,6), S(i,7));
end

fprintf('=============================================================\n\n');

if isfield(stability,'switching') && ~isempty(stability.switching)
    fprintf('---- Auto switching-channel detection ----\n');
    if isfinite(stability.switching.globalChannel)
        fprintf('globalChannel = %d\n', stability.switching.globalChannel);
    else
        fprintf('globalChannel = NaN (no consistent switching channel)\n');
    end
    fprintf('-----------------------------------------\n\n');
end

end


% =======================================================================
function switchInfo = detectSwitchingFromSummaryTable(T, sdOpts)
% Returns switching channel decision per depValue using summaryTable only.

switchInfo = struct();
switchInfo.perDepValue = struct('depValue',{},'switchingChannel',{},'switchScore',{},'numCandidates',{});
switchInfo.globalChannel = NaN;

if isempty(T) || height(T)==0
    return;
end

minDprime   = sdOpts.minDprime;
minGapSigma = sdOpts.minGapSigma;

[GD, depU] = findgroups(T.depValue);

switchInfo.perDepValue = repmat(struct( ...
    'depValue',NaN, ...
    'switchingChannel',NaN, ...
    'switchScore',NaN, ...
    'numCandidates',0), numel(depU), 1);

for ii = 1:numel(depU)
    Ti = T(GD==ii,:);

    valid = isfinite(Ti.stateSeparationD) & isfinite(Ti.stateGapAbs) & ...
        isfinite(Ti.withinRMS) & (Ti.withinRMS>0);

    Ti = Ti(valid,:);
    switchInfo.perDepValue(ii).depValue = depU(ii);

    if isempty(Ti)
        continue;
    end

    score = Ti.stateSeparationD .* (Ti.stateGapAbs ./ Ti.withinRMS);

    isCand = (Ti.stateSeparationD > minDprime) & ...
        (Ti.stateGapAbs > minGapSigma * Ti.withinRMS);

    idxCand = find(isCand);
    switchInfo.perDepValue(ii).numCandidates = numel(idxCand);

    if isempty(idxCand)
        continue;
    end

    [~, bestRel] = max(score(idxCand));
    bestIdx = idxCand(bestRel);

    switchInfo.perDepValue(ii).switchingChannel = Ti.switching_channel_physical(bestIdx);
    switchInfo.perDepValue(ii).switchScore      = score(bestIdx);
end

allCh = [switchInfo.perDepValue.switchingChannel];
allCh = allCh(isfinite(allCh));
if ~isempty(allCh)
    switchInfo.globalChannel = mode(allCh);
end

end


function assertPhysIndexRowContract_(physIdxRow, numCh, fileIdx)
% Enforces the same physIndex contract as processFilesSwitching for downstream materialization.
if numCh < 1
    return;
end
if isempty(physIdxRow) || numel(physIdxRow) ~= numCh
    error('analyzeSwitchingStability:ChannelMapping', ...
        ['Channel mapping enforcement: stored_data{%d,7} must contain physIndex with numel==numCh (%d). ' ...
        'Upstream must call processFilesSwitching so column 7 is populated.'], fileIdx, numCh);
end
phys2loc = nan(1, 4);
for kk = 1:numCh
    p = physIdxRow(kk);
    if ~(isfinite(p) && p == floor(p) && p >= 1 && p <= 4)
        error('analyzeSwitchingStability:ChannelMapping', ...
            'stored_data{%d,7}(%d) must be integer 1..4; got %g.', fileIdx, kk, p);
    end
    phys2loc(p) = kk;
end
for kk = 1:numCh
    if ~(isfinite(phys2loc(physIdxRow(kk))) && phys2loc(physIdxRow(kk)) == kk)
        error('analyzeSwitchingStability:ChannelMapping', ...
            'physIndex inverse mapping failed for file index %d at local k=%d.', fileIdx, kk);
    end
end
end
