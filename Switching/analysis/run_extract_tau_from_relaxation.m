% RUN_EXTRACT_TAU_FROM_RELAXATION  tau_eff(T) from relaxation curves (long-format CSV under results/ only).
%
% Contract:
%   tools/run_matlab_safe.bat C:\Dev\matlab-functions\Switching\analysis\run_extract_tau_from_relaxation.m
%   eval(fileread('C:/Dev/matlab-functions/Switching/analysis/run_extract_tau_from_relaxation.m'))
%
% Searches only: C:/Dev/matlab-functions/results/ (recursive *.csv). First eligible long-table wins.
% Manual T_K alignment: group by temperature column (no innerjoin). Pure script — no function keyword.

repoRoot = pwd;
resultsRoot = fullfile(repoRoot, 'results');
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

outCsvPath = 'C:/Dev/matlab-functions/tables/tau_extracted.csv';
outStatusPath = 'C:/Dev/matlab-functions/tables/tau_extracted_status.csv';
outMdPath = 'C:/Dev/matlab-functions/reports/tau_extracted.md';

EXECUTION_STATUS = "FAIL";
INPUT_SOURCE = "NONE";
N_T = 0;
TAU_EXTRACTION_SUCCESS = "NO";
TAU_METHODS_CONSISTENT = "NO";
STRETCHING_PRESENT = "NO";
ERROR_MESSAGE = '';

emptyOut = table('Size', [0, 6], ...
    'VariableTypes', {'double', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'T_K', 'tau_1e', 'tau_integral', 'tau_stretched', 'beta', 'fit_rmse'});

resultTbl = emptyOut;

try
    if exist(resultsRoot, 'dir') ~= 7
        ERROR_MESSAGE = sprintf('Missing results directory: %s', resultsRoot);
        writetable(emptyOut, outCsvPath);
    else
        csvList = {};
        pathParts = strsplit(genpath(resultsRoot), pathsep);
        for ip = 1:numel(pathParts)
            folder = pathParts{ip};
            if isempty(folder)
                continue;
            end
            d = dir(fullfile(folder, '*.csv'));
            for k = 1:numel(d)
                if d(k).isdir
                    continue;
                end
                fn = lower(d(k).name);
                likelyRelax = contains(fn, 'relax') || contains(fn, 'timelaw') ...
                    || contains(fn, 'delta_m') || contains(fn, 'deltam') ...
                    || contains(fn, 'time_grid') || contains(fn, 'mode_profile') ...
                    || contains(fn, 'time_fit') || contains(fn, 'observables_relax');
                if ~likelyRelax
                    continue;
                end
                csvList{end + 1} = fullfile(folder, d(k).name); %#ok<AGROW>
            end
        end
        csvList = sort(csvList);
        nRelaxCsv = numel(csvList);

        pickedPath = "";
        rawTbl = table();

        for ic = 1:nRelaxCsv
            p = csvList{ic};
            try
                tmp = readtable(p, 'VariableNamingRule', 'preserve');
            catch
                continue;
            end
            if isempty(tmp) || height(tmp) < 4
                continue;
            end
            vn = tmp.Properties.VariableNames;
            nNames = numel(vn);
            colT = 0;
            colTime = 0;
            colSig = 0;
            for jc = 1:nNames
                low = lower(vn{jc});
                if colT == 0
                    if contains(low, 't_k') || strcmp(low, 'tp') || contains(low, 'temperature')
                        colT = jc;
                    end
                end
            end
            for jc = 1:nNames
                low = lower(vn{jc});
                isTemp = contains(low, 't_k') || strcmp(low, 'tp') ...
                    || (contains(low, 'temperature') && contains(low, 'k'));
                if isTemp
                    continue;
                end
                if contains(low, 'tau') && contains(low, 'second')
                    continue;
                end
                if colTime == 0
                    if (contains(low, 'time') && ~contains(low, 'temperature')) ...
                            || strcmp(low, 't') ...
                            || (contains(low, 'second') && ~contains(low, 'tau'))
                        colTime = jc;
                        break;
                    end
                end
            end
            for jc = 1:nNames
                if jc == colT || jc == colTime
                    continue;
                end
                low = lower(vn{jc});
                if colSig == 0
                    if contains(low, 'signal') || contains(low, 'relaxation') ...
                            || strcmp(low, 's') ...
                            || (contains(low, 'normalized') && contains(low, 'signal'))
                        colSig = jc;
                        break;
                    end
                end
            end

            if colT > 0 && colTime > 0 && colSig > 0 ...
                    && colT ~= colTime && colT ~= colSig && colTime ~= colSig
                rawTbl = tmp;
                pickedPath = p;
                break;
            end
        end

        if isempty(pickedPath) || isempty(rawTbl) || height(rawTbl) < 4
            writetable(emptyOut, outCsvPath);
            if isempty(ERROR_MESSAGE)
                if nRelaxCsv == 0
                    ERROR_MESSAGE = ['No CSV under results/ matched relaxation filename hints ', ...
                        '(relax, timelaw, delta_m, time_grid, mode_profile, time_fit, observables_relax).'];
                else
                    ERROR_MESSAGE = 'Relaxation-named CSV(s) found but none passed T_K + time + signal column detection.';
                end
            end
        else
            INPUT_SOURCE = pickedPath;
            vn = rawTbl.Properties.VariableNames;
            colT = 0;
            colTime = 0;
            colSig = 0;
            for jc = 1:numel(vn)
                low = lower(vn{jc});
                if colT == 0
                    if contains(low, 't_k') || strcmp(low, 'tp') || contains(low, 'temperature')
                        colT = jc;
                    end
                end
            end
            for jc = 1:numel(vn)
                low = lower(vn{jc});
                isTemp = contains(low, 't_k') || strcmp(low, 'tp') ...
                    || (contains(low, 'temperature') && contains(low, 'k'));
                if isTemp
                    continue;
                end
                if contains(low, 'tau') && contains(low, 'second')
                    continue;
                end
                if colTime == 0
                    if (contains(low, 'time') && ~contains(low, 'temperature')) ...
                            || strcmp(low, 't') ...
                            || (contains(low, 'second') && ~contains(low, 'tau'))
                        colTime = jc;
                        break;
                    end
                end
            end
            for jc = 1:numel(vn)
                if jc == colT || jc == colTime
                    continue;
                end
                low = lower(vn{jc});
                if colSig == 0
                    if contains(low, 'signal') || contains(low, 'relaxation') ...
                            || strcmp(low, 's') ...
                            || (contains(low, 'normalized') && contains(low, 'signal'))
                        colSig = jc;
                        break;
                    end
                end
            end

            T_all = double(rawTbl{:, colT});
            t_all = double(rawTbl{:, colTime});
            S_all = double(rawTbl{:, colSig});
            ok = isfinite(T_all) & isfinite(t_all) & isfinite(S_all);
            T_all = T_all(ok);
            t_all = t_all(ok);
            S_all = S_all(ok);

            T_list = unique(T_all);
            T_list = sort(T_list(:));
            nT = numel(T_list);

            T_K = nan(nT, 1);
            tau_1e = nan(nT, 1);
            tau_integral = nan(nT, 1);
            tau_stretched = nan(nT, 1);
            beta = nan(nT, 1);
            fit_rmse = nan(nT, 1);

            for it = 1:nT
                TK = T_list(it);
                msk = abs(T_all - TK) < 1e-9;
                t = t_all(msk);
                S = S_all(msk);
                [t, ord] = sort(t);
                S = S(ord);
                if numel(t) >= 2
                    [tu, ~, icg] = unique(t);
                    Su = accumarray(icg, S, [], @mean);
                    t = tu;
                    S = Su;
                end
                if numel(t) < 4
                    continue;
                end
                if S(1) < S(end)
                    S0 = max(S);
                    Sn = S ./ max(S0, eps);
                else
                    S0 = S(1);
                    Sn = S ./ max(S0, eps);
                end
                Sn = max(Sn, 1e-15);
                if Sn(end) > Sn(1)
                    Sn = Sn(end:-1:1);
                    t = t(end:-1:1);
                    Sn = Sn ./ max(Sn(1), eps);
                end

                target = 1 / exp(1);
                Snm = Sn(:);
                tau1 = NaN;
                below = Snm <= target;
                if any(below)
                    i1 = find(below, 1, 'first');
                    if i1 == 1
                        tau1 = t(1);
                    else
                        i0 = i1 - 1;
                        tau1 = t(i0) + (target - Snm(i0)) / (Snm(i1) - Snm(i0) + eps) * (t(i1) - t(i0));
                    end
                end

                tauInt = trapz(t, Sn);

                y = Sn(:);
                tt = t(:);
                tau0 = tau1;
                if ~isfinite(tau0) || tau0 <= 0
                    tau0 = median(tt);
                end
                sseFun = @(p) sum((y - exp(-(tt ./ max(p(1), 1e-12)) .^ max(p(2), 1e-12))) .^ 2);
                fmsOpts = optimset('Display', 'off', 'MaxIter', 250, 'MaxFunEvals', 2000);
                pBest = fminsearch(sseFun, [tau0, 1], fmsOpts);
                tauS = abs(pBest(1));
                bFit = abs(pBest(2));
                yhat = exp(-(tt ./ max(tauS, 1e-12)) .^ max(bFit, 1e-12));
                rmse = sqrt(mean((y - yhat) .^ 2));

                T_K(it) = TK;
                tau_1e(it) = tau1;
                tau_integral(it) = tauInt;
                tau_stretched(it) = tauS;
                beta(it) = bFit;
                fit_rmse(it) = rmse;
            end

            finM = isfinite(T_K) & isfinite(tau_1e) & isfinite(tau_integral) ...
                & isfinite(tau_stretched) & isfinite(beta) & isfinite(fit_rmse);
            resultTbl = table(T_K(finM), tau_1e(finM), tau_integral(finM), tau_stretched(finM), beta(finM), fit_rmse(finM), ...
                'VariableNames', {'T_K', 'tau_1e', 'tau_integral', 'tau_stretched', 'beta', 'fit_rmse'});
            N_T = height(resultTbl);

            if N_T >= 1
                TAU_EXTRACTION_SUCCESS = "YES";
                mean_b = mean(resultTbl.beta, 'omitnan');
                std_b = std(resultTbl.beta, 0, 'omitnan');
                if mean_b < 0.97 || mean_b > 1.03 || std_b > 0.06
                    STRETCHING_PRESENT = "YES";
                end
                ratios = [];
                for ir = 1:N_T
                    a = [resultTbl.tau_1e(ir), resultTbl.tau_integral(ir), resultTbl.tau_stretched(ir)];
                    for a1 = 1:3
                        for a2 = a1 + 1:3
                            ratios(end + 1) = max(a(a1), a(a2)) / max(min(a(a1), a(a2)), eps); %#ok<AGROW>
                        end
                    end
                end
                med_lr = median(abs(log(ratios)));
                if N_T >= 3
                    l1 = log(resultTbl.tau_1e);
                    l2 = log(resultTbl.tau_integral);
                    l3 = log(resultTbl.tau_stretched);
                    s12 = corr(l1, l2, 'type', 'Spearman', 'rows', 'complete');
                    s13 = corr(l1, l3, 'type', 'Spearman', 'rows', 'complete');
                    s23 = corr(l2, l3, 'type', 'Spearman', 'rows', 'complete');
                    if med_lr < log(8) && min([s12, s13, s23]) > 0.75
                        TAU_METHODS_CONSISTENT = "YES";
                    end
                elseif N_T == 2 && med_lr < log(8)
                    TAU_METHODS_CONSISTENT = "YES";
                end
            end

            writetable(resultTbl, outCsvPath);
        end
    end

    EXECUTION_STATUS = "SUCCESS";
catch ME
    ERROR_MESSAGE = getReport(ME);
    EXECUTION_STATUS = "FAIL";
    writetable(emptyOut, outCsvPath);
end

statusTbl = table( ...
    string(EXECUTION_STATUS), string(INPUT_SOURCE), N_T, ...
    string(TAU_EXTRACTION_SUCCESS), string(TAU_METHODS_CONSISTENT), string(STRETCHING_PRESENT), ...
    string(ERROR_MESSAGE), ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_SOURCE', 'N_T', ...
    'TAU_EXTRACTION_SUCCESS', 'TAU_METHODS_CONSISTENT', 'STRETCHING_PRESENT', 'ERROR_MESSAGE'});

writetable(statusTbl, outStatusPath);

lines = {};
lines{end + 1} = '# Tau extraction (relaxation curves)';
lines{end + 1} = '';
lines{end + 1} = sprintf('**EXECUTION_STATUS:** %s', EXECUTION_STATUS);
lines{end + 1} = sprintf('**INPUT_SOURCE:** %s', INPUT_SOURCE);
lines{end + 1} = sprintf('**N_T:** %d', N_T);
lines{end + 1} = sprintf('**TAU_EXTRACTION_SUCCESS:** %s', TAU_EXTRACTION_SUCCESS);
lines{end + 1} = sprintf('**TAU_METHODS_CONSISTENT:** %s', TAU_METHODS_CONSISTENT);
lines{end + 1} = sprintf('**STRETCHING_PRESENT:** %s', STRETCHING_PRESENT);
lines{end + 1} = '';
lines{end + 1} = sprintf('**Outputs:** `%s`, `%s`, `%s`', ...
    strrep(outCsvPath, '\', '/'), strrep(outStatusPath, '\', '/'), strrep(outMdPath, '\', '/'));
lines{end + 1} = '';
if strlength(string(ERROR_MESSAGE)) > 0
    lines{end + 1} = '## ERROR_MESSAGE';
    lines{end + 1} = '```';
    lines{end + 1} = char(ERROR_MESSAGE);
    lines{end + 1} = '```';
end
lines{end + 1} = '';
if N_T > 0 && height(resultTbl) > 0
    lines{end + 1} = '## tau(T)';
    lines{end + 1} = '| T_K | tau_1e | tau_integral | tau_stretched | beta | fit_rmse |';
    lines{end + 1} = '|---:|---:|---:|---:|---:|---:|';
    for ir = 1:height(resultTbl)
        lines{end + 1} = sprintf('| %.6g | %.6g | %.6g | %.6g | %.6g | %.6g |', ...
            resultTbl.T_K(ir), resultTbl.tau_1e(ir), resultTbl.tau_integral(ir), ...
            resultTbl.tau_stretched(ir), resultTbl.beta(ir), resultTbl.fit_rmse(ir));
    end
else
    lines{end + 1} = '_No tau rows (empty or no eligible input)._';
end

fid = fopen(outMdPath, 'w');
if fid > 0
    for z = 1:numel(lines)
        fprintf(fid, '%s\n', lines{z});
    end
    fclose(fid);
end
