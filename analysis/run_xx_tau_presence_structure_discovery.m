fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('TauPresence:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'xx_tau_presence_structure_discovery';

run = struct();

try
    run = createRunContext('analysis', cfg);

    inputPath = fullfile(repoRoot, 'tables', 'xx_relaxation_event_level_full_config2.csv');
    mapPath = fullfile(repoRoot, 'tables', 'xx_tau_presence_map.csv');
    tempPath = fullfile(repoRoot, 'tables', 'xx_tau_vs_temperature.csv');
    reportPath = fullfile(repoRoot, 'reports', 'xx_tau_presence_analysis.md');

    if exist(inputPath, 'file') ~= 2
        error('TauPresence:InputMissing', 'Input table not found: %s', inputPath);
    end

    T = readtable(inputPath);
    requiredCols = {'temperature', 'config_id', 'tau_relax', 'DeltaV'};
    for k = 1:numel(requiredCols)
        if ~ismember(requiredCols{k}, T.Properties.VariableNames)
            error('TauPresence:MissingColumn', 'Missing required column: %s', requiredCols{k});
        end
    end

    nRows = height(T);
    current_mA = nan(nRows, 1);
    tau_relax = T.tau_relax;
    temperature = T.temperature;
    deltaV = T.DeltaV;
    tau_measurable = false(nRows, 1);

    for i = 1:nRows
        cfgId = string(T.config_id(i));
        tok = regexp(cfgId, '([0-9]+(?:\.[0-9]+)?)mA', 'tokens', 'once');
        if ~isempty(tok)
            current_mA(i) = str2double(tok{1});
        end

        if ~isnan(tau_relax(i)) && tau_relax(i) > 0
            tau_measurable(i) = true;
        end
    end

    G = findgroups(temperature, current_mA);
    groupCount = max(G);
    map_temperature = nan(groupCount, 1);
    map_current = nan(groupCount, 1);
    map_total = zeros(groupCount, 1);
    map_measurable = zeros(groupCount, 1);
    map_fraction = nan(groupCount, 1);
    map_median_tau = nan(groupCount, 1);
    map_median_deltaV = nan(groupCount, 1);

    for g = 1:groupCount
        idx = (G == g);
        map_temperature(g) = temperature(find(idx, 1, 'first'));
        map_current(g) = current_mA(find(idx, 1, 'first'));
        map_total(g) = sum(idx);
        map_measurable(g) = sum(tau_measurable(idx));
        map_fraction(g) = map_measurable(g) / map_total(g);

        tauSubset = tau_relax(idx & tau_measurable);
        if ~isempty(tauSubset)
            map_median_tau(g) = median(tauSubset);
        end

        dvSubset = deltaV(idx);
        map_median_deltaV(g) = median(dvSubset, 'omitnan');
    end

    mapTbl = table(map_temperature, map_current, map_total, map_measurable, ...
        map_fraction, map_median_tau, map_median_deltaV, ...
        'VariableNames', {'temperature', 'current', 'total_events', ...
        'measurable_events', 'fraction_measurable', 'median_tau', 'median_DeltaV'});
    mapTbl = sortrows(mapTbl, {'temperature', 'current'});
    writetable(mapTbl, mapPath);

    [GT, temps] = findgroups(temperature);
    tCount = numel(temps);
    t_total = zeros(tCount, 1);
    t_measurable = zeros(tCount, 1);
    t_fraction = nan(tCount, 1);
    t_median_tau = nan(tCount, 1);

    for g = 1:tCount
        idx = (GT == g);
        t_total(g) = sum(idx);
        t_measurable(g) = sum(tau_measurable(idx));
        t_fraction(g) = t_measurable(g) / t_total(g);

        tauSubset = tau_relax(idx & tau_measurable);
        if ~isempty(tauSubset)
            t_median_tau(g) = median(tauSubset);
        end
    end

    tempTbl = table(temps, t_total, t_fraction, t_median_tau, ...
        'VariableNames', {'temperature', 'total_events', 'fraction_measurable', 'median_tau'});
    tempTbl = sortrows(tempTbl, 'temperature');
    writetable(tempTbl, tempPath);

    eps = 0.05;
    regime = strings(height(tempTbl), 1);
    for i = 1:height(tempTbl)
        f = tempTbl.fraction_measurable(i);
        if f <= eps
            regime(i) = "no_relaxation";
        elseif f >= (1 - eps)
            regime(i) = "full_relaxation";
        else
            regime(i) = "mixed";
        end
    end

    transitionLines = strings(0, 1);
    for i = 2:height(tempTbl)
        if regime(i) ~= regime(i - 1)
            transitionLines(end + 1, 1) = sprintf('- %s at T=%.4g (f=%.3f) -> %s at T=%.4g (f=%.3f)', ...
                regime(i - 1), tempTbl.temperature(i - 1), tempTbl.fraction_measurable(i - 1), ...
                regime(i), tempTbl.temperature(i), tempTbl.fraction_measurable(i));
        end
    end

    uniqueTemps = unique(mapTbl.temperature);
    maxCurrentSpread = 0;
    for i = 1:numel(uniqueTemps)
        tidx = (mapTbl.temperature == uniqueTemps(i));
        vals = mapTbl.fraction_measurable(tidx);
        if numel(vals) > 1
            spread = max(vals) - min(vals);
            if spread > maxCurrentSpread
                maxCurrentSpread = spread;
            end
        end
    end

    TAU_PRESENT_REGIME_IDENTIFIED = any(regime == "full_relaxation");
    TAU_ABSENT_REGIME_IDENTIFIED = any(regime == "no_relaxation");
    TRANSITION_TEMPERATURES_FOUND = ~isempty(transitionLines);
    CURRENT_DEPENDENCE_PRESENT = (maxCurrentSpread > 0.10);

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('TauPresence:ReportWriteFailed', 'Unable to write report: %s', reportPath);
    end

    fprintf(fid, '# Tau Presence Analysis\\n\\n');
    fprintf(fid, 'Input: `tables/xx_relaxation_event_level_full_config2.csv`\\n\\n');
    fprintf(fid, 'Definition: `tau_measurable = (tau_relax > 0)`; tau=0 and tau=NaN are treated as non-measurable for counting and excluded from `median_tau`.\\n\\n');
    fprintf(fid, '## Where tau exists\\n\\n');
    fprintf(fid, '- Total events analyzed: %d\\n', nRows);
    fprintf(fid, '- Temperature bins: %d\\n', height(tempTbl));
    fprintf(fid, '- Current bins: %d\\n', numel(unique(mapTbl.current)));
    fprintf(fid, '- Measurable tau events: %d\\n', sum(tau_measurable));
    fprintf(fid, '- Non-measurable events: %d\\n\\n', nRows - sum(tau_measurable));

    fprintf(fid, '## Regime classification\\n\\n');
    fprintf(fid, '- Rule: no relaxation if fraction_measurable <= %.2f; full relaxation if >= %.2f; otherwise mixed.\\n', eps, 1 - eps);
    fprintf(fid, '- no_relaxation temperatures: %d\\n', sum(regime == "no_relaxation"));
    fprintf(fid, '- mixed temperatures: %d\\n', sum(regime == "mixed"));
    fprintf(fid, '- full_relaxation temperatures: %d\\n\\n', sum(regime == "full_relaxation"));

    fprintf(fid, '## Transition temperatures\\n\\n');
    if isempty(transitionLines)
        fprintf(fid, '- None detected in sorted temperature sequence.\\n\\n');
    else
        for i = 1:numel(transitionLines)
            fprintf(fid, '%s\\n', transitionLines(i));
        end
        fprintf(fid, '\\n');
    end

    fprintf(fid, '## Current dependence\\n\\n');
    fprintf(fid, '- Max within-temperature spread in fraction_measurable across currents: %.3f\\n', maxCurrentSpread);
    fprintf(fid, '- Criterion: current dependence present if spread > 0.10 at any temperature.\\n\\n');

    fprintf(fid, '## Final verdicts\\n\\n');
    if TAU_PRESENT_REGIME_IDENTIFIED
        fprintf(fid, 'TAU_PRESENT_REGIME_IDENTIFIED = YES\\n');
    else
        fprintf(fid, 'TAU_PRESENT_REGIME_IDENTIFIED = NO\\n');
    end
    if TAU_ABSENT_REGIME_IDENTIFIED
        fprintf(fid, 'TAU_ABSENT_REGIME_IDENTIFIED = YES\\n');
    else
        fprintf(fid, 'TAU_ABSENT_REGIME_IDENTIFIED = NO\\n');
    end
    if TRANSITION_TEMPERATURES_FOUND
        fprintf(fid, 'TRANSITION_TEMPERATURES_FOUND = YES\\n');
    else
        fprintf(fid, 'TRANSITION_TEMPERATURES_FOUND = NO\\n');
    end
    if CURRENT_DEPENDENCE_PRESENT
        fprintf(fid, 'CURRENT_DEPENDENCE_PRESENT = YES\\n');
    else
        fprintf(fid, 'CURRENT_DEPENDENCE_PRESENT = NO\\n');
    end
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(tempTbl), {'tau presence map generated'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_tau_presence_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end

    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'tau presence map failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
