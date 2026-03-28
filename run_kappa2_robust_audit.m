if true
    repoRoot = 'C:/Dev/matlab-functions';
    alphaPath = fullfile(repoRoot,'tables','alpha_structure.csv');
    columnsDbgPath = fullfile(repoRoot,'kappa2_columns_debug.txt');
    buildStatusPath = fullfile(repoRoot,'kappa2_build_status.txt');
    auditStatusPath = fullfile(repoRoot,'kappa2_audit_status.txt');
    matPath = fullfile(repoRoot,'kappa2_phen_inputs.mat');
    checkCsvPath = fullfile(repoRoot,'tables','kappa2_phen_inputs_check.csv');
    auditCsvPath = fullfile(repoRoot,'tables','kappa2_phenomenological_audit.csv');
    reportPath = fullfile(repoRoot,'reports','kappa2_phenomenological_audit.md');
    errPath = fullfile(repoRoot,'kappa2_error.log');

    T_K = NaN(0,1); kappa2 = NaN(0,1); I_peak = NaN(0,1);
    width_asymmetry = NaN(0,1); slope_asymmetry = NaN(0,1);
    local_curvature = NaN(0,1); antisym_area_res2 = NaN(0,1);
    mapped = strings(0,1); missing = strings(0,1); warns = strings(0,1);
    selectedResidualPath = '';

    try
        % Discover residual file dynamically (most recent)
        files = dir(fullfile(repoRoot,'results','**','residual_rank_structure_vs_T.csv'));
        if isempty(files)
            fb = fullfile(repoRoot,'results','switching','runs','run_2026_03_25_043610_kappa_phi_temperature_structure_test','tables','residual_rank_structure_vs_T.csv');
            if exist(fb,'file')
                selectedResidualPath = fb;
                warns(end+1) = "Dynamic discovery failed; using fallback residual file.";
            else
                error('No residual_rank_structure_vs_T.csv found.');
            end
        else
            [~,ix] = max([files.datenum]);
            selectedResidualPath = fullfile(files(ix).folder, files(ix).name);
        end

        alphaTbl = readtable(alphaPath);
        resTbl = readtable(selectedResidualPath);
        alphaCols = string(alphaTbl.Properties.VariableNames);
        resCols = string(resTbl.Properties.VariableNames);

        % Column discovery log
        fid = fopen(columnsDbgPath,'w');
        fprintf(fid,'alpha file: %s\n',alphaPath);
        fprintf(fid,'residual file: %s\n',selectedResidualPath);
        fprintf(fid,'alpha size: %d x %d\n',height(alphaTbl),width(alphaTbl));
        fprintf(fid,'residual size: %d x %d\n',height(resTbl),width(resTbl));
        fprintf(fid,'\nalpha columns:\n'); fprintf(fid,'%s\n',alphaCols);
        fprintf(fid,'\nresidual columns:\n'); fprintf(fid,'%s\n',resCols);
        fclose(fid);

        % Detect T columns
        aT = ''; rT = '';
        for i=1:numel(alphaCols)
            n = lower(alphaCols(i));
            if contains(n,'t_k') || strcmp(n,'t')
                aT = char(alphaCols(i)); break;
            end
        end
        for i=1:numel(resCols)
            n = lower(resCols(i));
            if contains(n,'t_k') || strcmp(n,'t')
                rT = char(resCols(i)); break;
            end
        end
        if isempty(aT) || isempty(rT), error('Failed to detect T_K columns.'); end

        aTk = double(alphaTbl.(aT)); rTk = double(resTbl.(rT));
        [Tc, ia, ib] = intersect(aTk, rTk);
        T_K = Tc(:);

        % Mapping helpers (inline, no local functions)
        rv = lower(resCols); av = lower(alphaCols);

        idx = find(contains(rv,'kappa2'),1,'first');
        if isempty(idx)
            idx = find(contains(rv,'kappa') & ~contains(rv,'kappa1'),1,'first');
            if ~isempty(idx), warns(end+1)="kappa2 mapped from generic kappa column."; end
        end
        if isempty(idx), missing(end+1)="kappa2"; kappa2=NaN(size(T_K)); else
            kappa2 = double(resTbl.(char(resCols(idx)))); kappa2 = kappa2(ib); mapped(end+1)="kappa2 <- "+resCols(idx);
        end

        cands = find(contains(av,'i_peak') | contains(av,'peak'));
        if isempty(cands), missing(end+1)="I_peak"; I_peak=NaN(size(T_K)); else
            I_peak = double(alphaTbl.(char(alphaCols(cands(1))))); I_peak = I_peak(ia); mapped(end+1)="I_peak <- "+alphaCols(cands(1));
        end

        cands = find(contains(av,'width') & contains(av,'asym'));
        if isempty(cands), missing(end+1)="width_asymmetry"; width_asymmetry=NaN(size(T_K)); else
            width_asymmetry = double(alphaTbl.(char(alphaCols(cands(1))))); width_asymmetry = width_asymmetry(ia); mapped(end+1)="width_asymmetry <- "+alphaCols(cands(1));
        end

        cands = find(contains(av,'slope') & contains(av,'asym'));
        if isempty(cands), missing(end+1)="slope_asymmetry"; slope_asymmetry=NaN(size(T_K)); else
            slope_asymmetry = double(alphaTbl.(char(alphaCols(cands(1))))); slope_asymmetry = slope_asymmetry(ia); mapped(end+1)="slope_asymmetry <- "+alphaCols(cands(1));
        end

        cands = find(contains(av,'curvature'));
        if isempty(cands), missing(end+1)="local_curvature"; local_curvature=NaN(size(T_K)); else
            local_curvature = double(alphaTbl.(char(alphaCols(cands(1))))); local_curvature = local_curvature(ia); mapped(end+1)="local_curvature <- "+alphaCols(cands(1));
        end

        cands = find(contains(rv,'antisym') | (contains(rv,'area') & contains(rv,'res2')));
        if isempty(cands), missing(end+1)="antisym_area_res2"; antisym_area_res2=NaN(size(T_K)); else
            antisym_area_res2 = double(resTbl.(char(resCols(cands(1))))); antisym_area_res2 = antisym_area_res2(ib); mapped(end+1)="antisym_area_res2 <- "+resCols(cands(1));
        end

        % Restrict T<=30
        keep = isfinite(T_K) & (T_K<=30);
        T_K=T_K(keep); kappa2=kappa2(keep); I_peak=I_peak(keep); width_asymmetry=width_asymmetry(keep);
        slope_asymmetry=slope_asymmetry(keep); local_curvature=local_curvature(keep); antisym_area_res2=antisym_area_res2(keep);
        T_K=T_K(:); kappa2=kappa2(:); I_peak=I_peak(:); width_asymmetry=width_asymmetry(:);
        slope_asymmetry=slope_asymmetry(:); local_curvature=local_curvature(:); antisym_area_res2=antisym_area_res2(:);

        % Save build outputs always
        save(matPath,'T_K','kappa2','I_peak','width_asymmetry','slope_asymmetry','local_curvature','antisym_area_res2');
        writetable(table(T_K,kappa2,I_peak,width_asymmetry,slope_asymmetry,local_curvature,antisym_area_res2),checkCsvPath);
        mode = "SUCCESS"; if ~isempty(missing), mode="PARTIAL"; end; if isempty(T_K), mode="FAILED_RECOVERED"; end
        fid=fopen(buildStatusPath,'w'); fprintf(fid,'STATUS: %s\nalpha: %s\nresidual: %s\nalignedRows: %d\n',mode,alphaPath,selectedResidualPath,numel(T_K));
        fprintf(fid,'mapped:\n%s\nmissing:\n%s\n',strjoin(unique(mapped),', '),strjoin(unique(missing),', ')); fclose(fid);

        % Strict model set
        names = ["I_peak","width_asymmetry","slope_asymmetry","local_curvature","antisym_area_res2", ...
                 "I_peak + width_asymmetry","I_peak + local_curvature","slope_asymmetry + antisym_area_res2"]';
        fam = ["single","single","single","single","single","pair","pair","pair"]';
        Xs = {I_peak,width_asymmetry,slope_asymmetry,local_curvature,antisym_area_res2,[I_peak width_asymmetry],[I_peak local_curvature],[slope_asymmetry antisym_area_res2]}';
        status = strings(numel(names),1); n_used = NaN(numel(names),1); rmse = NaN(numel(names),1);
        pear = NaN(numel(names),1); spear = NaN(numel(names),1); ratio = NaN(numel(names),1); delta = NaN(numel(names),1);

        y = kappa2(:); maskB = isfinite(y); yb = y(maskB); b_rmse = NaN;
        if numel(yb)>=4
            yhatb = NaN(size(yb));
            for k=1:numel(yb), tr=true(numel(yb),1); tr(k)=false; yhatb(k)=mean(yb(tr),'omitnan'); end
            b_rmse = sqrt(mean((yb-yhatb).^2,'omitnan'));
        end

        for i=1:numel(names)
            X = Xs{i};
            m = isfinite(y) & all(isfinite(X),2);
            yv = y(m); Xv = X(m,:);
            n_used(i)=numel(yv);
            if n_used(i)<4 || ~isfinite(b_rmse)
                status(i)="SKIPPED_MISSING_DATA"; continue;
            end
            yhat = NaN(n_used(i),1);
            for k=1:n_used(i)
                tr=true(n_used(i),1); tr(k)=false;
                beta = [ones(sum(tr),1) Xv(tr,:)] \ yv(tr);
                yhat(k) = [1 Xv(k,:)]*beta;
            end
            rmse(i)=sqrt(mean((yv-yhat).^2,'omitnan'));
            C=corrcoef(yv,yhat); if numel(C)>=4, pear(i)=C(1,2); end
            R=corrcoef(tiedrank(yv),tiedrank(yhat)); if numel(R)>=4, spear(i)=R(1,2); end
            ratio(i)=rmse(i)/b_rmse; delta(i)=rmse(i)-b_rmse; status(i)="OK";
        end

        resultsTbl = table(fam,names,status,n_used,rmse,pear,spear,ratio,delta, ...
            'VariableNames',{'family','model','status','n_used','loocv_rmse','pearson','spearman','rmse_over_baseline','delta_rmse'});
        writetable(resultsTbl,auditCsvPath);

        valid = strcmp(status,"OK") & isfinite(rmse);
        closure = "NO"; sig = "NO"; bestName="(none)"; bestN=NaN; bestRmse=NaN; bestP=NaN; bestS=NaN; bestD=NaN;
        if any(valid)
            idxv = find(valid); [~,j]=min(rmse(valid)); b=idxv(j);
            bestName=names(b); bestN=n_used(b); bestRmse=rmse(b); bestP=pear(b); bestS=spear(b); bestD=delta(b);
            if isfinite(ratio(b)) && ratio(b)<=0.60 && abs(bestP)>=0.85 && abs(bestS)>=0.85, closure="YES";
            elseif isfinite(ratio(b)) && ratio(b)<=0.90 && (abs(bestP)>=0.65 || abs(bestS)>=0.65), closure="PARTIAL"; end
            if any(abs(spear(valid))>=0.65), sig="YES"; end
        end

        meaning = "4. no stable physical interpretation";
        if closure=="NO" && sig=="YES", meaning="3. non-closed secondary collective coordinate"; end
        if contains(bestName,'I_peak'), meaning="1. deformation of collective response linked to Phi1-like deformation"; end
        if contains(bestName,'antisym_area_res2'), meaning="2. local asymmetry mode near switching peak"; end

        lines = strings(0,1);
        lines(end+1)="# Kappa2 phenomenological audit"; lines(end+1)="";
        lines(end+1)="## Inputs used"; lines(end+1)="- alpha: "+alphaPath; lines(end+1)="- residual: "+selectedResidualPath;
        lines(end+1)=sprintf('- alpha size: %d x %d',height(alphaTbl),width(alphaTbl)); lines(end+1)=sprintf('- residual size: %d x %d',height(resTbl),width(resTbl));
        if ~isempty(T_K), lines(end+1)=sprintf('- T range after alignment: [%.6g, %.6g]',min(T_K),max(T_K)); else, lines(end+1)='- T range after alignment: [NaN, NaN]'; end
        lines(end+1)=""; lines(end+1)="## Column discovery"; lines(end+1)="- alpha columns: "+strjoin(alphaCols,', ');
        lines(end+1)="- residual columns: "+strjoin(resCols,', '); lines(end+1)="- mapping used: "+strjoin(unique(mapped),'; ');
        lines(end+1)="- missing variables: "+strjoin(unique(missing),', ');
        lines(end+1)=""; lines(end+1)="## Observable definitions";
        lines(end+1)='- I_peak: peak-related switching descriptor.';
        lines(end+1)='- width_asymmetry: local left/right width imbalance near switching.';
        lines(end+1)='- slope_asymmetry: asymmetry in local switching slope.';
        lines(end+1)='- local_curvature: local curvature-like geometry near switching peak.';
        lines(end+1)='- antisym_area_res2: antisymmetric residual area proxy for mode-2 structure.';
        lines(end+1)=""; lines(end+1)="## Results"; lines(end+1)=sprintf('- Baseline LOOCV RMSE: %.6g',b_rmse);
        lines(end+1)='- Single-variable and two-variable model results are in tables/kappa2_phenomenological_audit.csv.';
        lines(end+1)=""; lines(end+1)="## Best available model";
        lines(end+1)='- model name: '+bestName; lines(end+1)=sprintf('- n_used: %d',bestN);
        lines(end+1)=sprintf('- LOOCV RMSE: %.6g',bestRmse); lines(end+1)=sprintf('- Pearson: %.4f',bestP);
        lines(end+1)=sprintf('- Spearman: %.4f',bestS); lines(end+1)=sprintf('- delta vs baseline: %.6g',bestD);
        lines(end+1)=""; lines(end+1)="## Recovery notes"; lines(end+1)='- warnings: '+strjoin(warns,'; ');
        skipped = names(~strcmp(status,"OK")); lines(end+1)='- models skipped: '+strjoin(skipped,', ');
        lines(end+1)=""; lines(end+1)="## Operational signature"; lines(end+1)='- KAPPA2_HAS_OPERATIONAL_SIGNATURE: '+sig;
        lines(end+1)=""; lines(end+1)="## Final verdict"; lines(end+1)='- KAPPA2_PHENOMENOLOGICALLY_CLOSED: '+closure;
        lines(end+1)='- KAPPA2_HAS_OPERATIONAL_SIGNATURE: '+sig;
        lines(end+1)=""; lines(end+1)="## Physical meaning of kappa2"; lines(end+1)='- '+meaning;
        fid=fopen(reportPath,'w'); fprintf(fid,'%s\n',strjoin(cellstr(lines),newline)); fclose(fid);

        fid=fopen(auditStatusPath,'w'); fprintf(fid,'STATUS: %s\nCLOSURE: %s\nSIGNATURE: %s\nBEST: %s\n',mode,closure,sig,bestName); fclose(fid);
    catch ME
        fid=fopen(errPath,'w'); if fid>=0, fprintf(fid,'%s\n\n%s\n',ME.message,getReport(ME)); fclose(fid); end
        try, save(matPath,'T_K','kappa2','I_peak','width_asymmetry','slope_asymmetry','local_curvature','antisym_area_res2'); catch, end
        try, writetable(table(T_K,kappa2,I_peak,width_asymmetry,slope_asymmetry,local_curvature,antisym_area_res2),checkCsvPath); catch, end
        try, writetable(table(string.empty(0,1),string.empty(0,1),string.empty(0,1),NaN(0,1),NaN(0,1),NaN(0,1),NaN(0,1),NaN(0,1),NaN(0,1), ...
            'VariableNames',{'family','model','status','n_used','loocv_rmse','pearson','spearman','rmse_over_baseline','delta_rmse'}),auditCsvPath); catch, end
        try, fid=fopen(reportPath,'w'); fprintf(fid,'%s\n','# Kappa2 phenomenological audit'); fprintf(fid,'%s\n','## Final verdict'); fprintf(fid,'%s\n','- KAPPA2_PHENOMENOLOGICALLY_CLOSED: NO'); fprintf(fid,'%s\n','- KAPPA2_HAS_OPERATIONAL_SIGNATURE: NO'); fclose(fid); catch, end
        try, fid=fopen(buildStatusPath,'w'); fprintf(fid,'STATUS: FAILED_RECOVERED\n'); fclose(fid); catch, end
        try, fid=fopen(auditStatusPath,'w'); fprintf(fid,'STATUS: FAILED_RECOVERED\n'); fclose(fid); catch, end
    end
else
% run_kappa2_robust_audit.m
% Robust single-pipeline audit for kappa2 phenomenological closure.
%
% IMPORTANT:
% This script is intended to be executed via:
%   eval(fileread('C:/Dev/matlab-functions/run_kappa2_robust_audit.m'))
% so it must not define any local functions.

% -----------------------------
% Absolute paths (rooted)
% -----------------------------
repoRoot = 'C:/Dev/matlab-functions';
alphaPath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');
checkMatPath = fullfile(repoRoot, 'kappa2_phen_inputs.mat');
checkCsvPath = fullfile(repoRoot, 'tables', 'kappa2_phen_inputs_check.csv');
colsDebugPath = fullfile(repoRoot, 'kappa2_columns_debug.txt');
buildStatusPath = fullfile(repoRoot, 'kappa2_build_status.txt');
auditStatusPath = fullfile(repoRoot, 'kappa2_audit_status.txt');
auditCsvPath = fullfile(repoRoot, 'tables', 'kappa2_phenomenological_audit.csv');
auditMdPath = fullfile(repoRoot, 'reports', 'kappa2_phenomenological_audit.md');
errPath = fullfile(repoRoot, 'kappa2_error.log');

% -----------------------------
% Initialize fail-safe outputs
% -----------------------------
statusMode = 'FAILED';
statusDetails = strings(0,1);

T_K = NaN(0,1);
kappa2 = NaN(0,1);
I_peak = NaN(0,1);
width_asymmetry = NaN(0,1);
slope_asymmetry = NaN(0,1);
local_curvature = NaN(0,1);
antisym_area_res2 = NaN(0,1);

alignedTmask = false(0,1);

% Results placeholders
resultsRows = {};
resultsHeader = {'family','model','status','n_used','loocv_rmse','pearson','spearman','rmse_over_baseline','delta_rmse'};
baselineRow = struct('n_used',0,'loocv_rmse',NaN,'pearson',NaN,'spearman',NaN,'rmse_over_baseline',1,'delta_rmse',0);

bestModelName = '';
bestN = 0;
bestRmse = NaN;
bestPear = NaN;
bestSpear = NaN;
bestRmseOverBaseline = NaN;

signatureHas = 'NO';
signatureSpearMax = NaN;

closureVerdict = 'NO';
physicalMeaning = 'no stable physical interpretation';

% For debug/reporting
selectedResidualPath = '';
alphaSize = [NaN NaN];
resSize = [NaN NaN];
TRangeAfterAlignment = [NaN NaN];

dbgAlphaCols = strings(0,1);
dbgResCols = strings(0,1);
dbgMappedCols = strings(0,1);
dbgMissingVars = strings(0,1);
dbgWarnings = strings(0,1);

% -----------------------------
% Outer try/catch
% -----------------------------
try
    % -----------------------------
    % Validate required alpha source
    % -----------------------------
    if ~exist(alphaPath,'file')
        error('Missing required alpha table: %s', alphaPath);
    end

    % -----------------------------
    % Dynamic discovery of residual file
    % -----------------------------
    resRoot = fullfile(repoRoot, 'results');
    targetName = 'residual_rank_structure_vs_T.csv';
    found = struct('path',{},'time',{});
    stack = {resRoot};
    while ~isempty(stack)
        curDir = stack{1};
        stack(1) = [];
        d = dir(curDir);
        for ii = 1:numel(d)
            item = d(ii);
            if item.isdir
                if strcmp(item.name,'.') || strcmp(item.name,'..')
                    continue;
                end
                stack{end+1} = fullfile(curDir, item.name); %#ok<AGROW>
            else
                if strcmp(item.name, targetName)
                    idx = numel(found) + 1;
                    found(idx).path = fullfile(curDir, item.name); %#ok<SAGROW>
                    found(idx).time = item.datenum; %#ok<SAGROW>
                end
            end
        end
    end

    if ~isempty(found)
        [~, iBest] = max([found.time]);
        selectedResidualPath = found(iBest).path;
    else
        % Fallback to known canonical file if one exists
        fallback1 = fullfile(repoRoot, 'results', 'switching', 'runs', ...
            'run_2026_03_25_043610_kappa_phi_temperature_structure_test', 'tables', ...
            'residual_rank_structure_vs_T.csv');
        if exist(fallback1,'file')
            selectedResidualPath = fallback1;
            dbgWarnings(end+1) = "Residual discovery failed; using fallback canonical file.";
        else
            error('Could not discover residual_rank_structure_vs_T.csv under %s and no fallback exists.', resRoot);
        end
    end

    % -----------------------------
    % Load tables
    % -----------------------------
    alphaTbl = readtable(alphaPath);
    resTbl = readtable(selectedResidualPath);

    alphaSize = [height(alphaTbl), width(alphaTbl)];
    resSize = [height(resTbl), width(resTbl)];

    dbgAlphaCols = string(alphaTbl.Properties.VariableNames);
    dbgResCols = string(resTbl.Properties.VariableNames);

    % First few T_K values if present (alpha)
    alphaTpreview = strings(0,1);
    resTpreview = strings(0,1);

    % -----------------------------
    % Full column discovery debug output (MANDATORY)
    % -----------------------------
    fidDbg = fopen(colsDebugPath,'w');
    fprintf(fidDbg, 'alpha file: %s\n', alphaPath);
    fprintf(fidDbg, 'alpha table size: %d rows x %d cols\n', alphaSize(1), alphaSize(2));
    fprintf(fidDbg, '\nalpha variable names:\n');
    fprintf(fidDbg, '%s\n', dbgAlphaCols);

    fprintf(fidDbg, '\nresidual file: %s\n', selectedResidualPath);
    fprintf(fidDbg, 'residual table size: %d rows x %d cols\n', resSize(1), resSize(2));
    fprintf(fidDbg, '\nresidual variable names:\n');
    fprintf(fidDbg, '%s\n', dbgResCols);

    fclose(fidDbg);

    % -----------------------------
    % Detect T_K columns robustly (contains-based)
    % -----------------------------
    alphaTcol = '';
    bestScore = -inf;
    for ci = 1:numel(dbgAlphaCols)
        nm = char(dbgAlphaCols(ci));
        low = lower(nm);
        score = -inf;
        if contains(low,'t_k')
            score = 100;
        elseif contains(low,'tk')
            score = 95;
        elseif strcmpi(nm,'T_K')
            score = 110;
        elseif strcmpi(nm,'T')
            score = 25;
        elseif contains(low,'temp') && contains(low,'t')
            score = 5;
        end
        if score > bestScore
            bestScore = score;
            alphaTcol = nm;
        end
    end

    resTcol = '';
    bestScore = -inf;
    for ci = 1:numel(dbgResCols)
        nm = char(dbgResCols(ci));
        low = lower(nm);
        score = -inf;
        if contains(low,'t_k')
            score = 100;
        elseif contains(low,'tk')
            score = 95;
        elseif strcmpi(nm,'T_K')
            score = 110;
        elseif strcmpi(nm,'T')
            score = 25;
        elseif contains(low,'temp') && contains(low,'t')
            score = 5;
        end
        if score > bestScore
            bestScore = score;
            resTcol = nm;
        end
    end

    if isempty(alphaTcol) || isempty(resTcol)
        error('Could not detect T_K column(s). alphaTcol=%s resTcol=%s', alphaTcol, resTcol);
    end

    % Extract and cast to double
    alphaTbl.(alphaTcol) = double(alphaTbl.(alphaTcol));
    resTbl.(resTcol) = double(resTbl.(resTcol));

    alphaT = alphaTbl.(alphaTcol);
    resT = resTbl.(resTcol);

    if ~isempty(alphaT)
        alphaTpreview = string(alphaT(1:min(5,numel(alphaT))));
    end
    if ~isempty(resT)
        resTpreview = string(resT(1:min(5,numel(resT))));
    end

    % Append previews + selected files + sizes to debug file
    fidDbg = fopen(colsDebugPath,'a');
    fprintf(fidDbg, '\n\nPreview first T_K values (alpha):\n');
    fprintf(fidDbg, '%s\n', alphaTpreview);
    fprintf(fidDbg, '\nPreview first T_K values (residual):\n');
    fprintf(fidDbg, '%s\n', resTpreview);
    fclose(fidDbg);

    % -----------------------------
    % Manual alignment by T_K intersect
    % -----------------------------
    [T_Kcommon, ia, ib] = intersect(alphaT, resT);
    T_K = T_Kcommon(:);
    if ~isempty(T_K)
        kappa2 = NaN(numel(T_K),1);
        I_peak = NaN(numel(T_K),1);
        width_asymmetry = NaN(numel(T_K),1);
        slope_asymmetry = NaN(numel(T_K),1);
        local_curvature = NaN(numel(T_K),1);
        antisym_area_res2 = NaN(numel(T_K),1);
    else
        dbgWarnings(end+1) = "No common T_K values found; aligned dataset will be empty.";
    end

    % -----------------------------
    % Canonical variable mapping (contains-based + safe fallbacks)
    % -----------------------------
    % kappa2 from residual
    rVars = dbgResCols;
    idxK2 = find(contains(lower(rVars), 'kappa2'), 1, 'first');
    if isempty(idxK2)
        idxK2 = find(contains(lower(rVars), 'kappa') & ~contains(lower(rVars), 'kappa1'), 1, 'first');
        if ~isempty(idxK2)
            dbgWarnings(end+1) = "kappa2 mapped from kappa* (not kappa2 literal) in residual table.";
        end
    end
    if ~isempty(idxK2)
        kappa2 = double(resTbl.(char(rVars(idxK2))));
        kappa2 = kappa2(ib);
        dbgMappedCols(end+1) = "kappa2 <- " + rVars(idxK2);
    else
        dbgMissingVars(end+1) = "kappa2";
    end

    % I_peak from alpha
    aVars = dbgAlphaCols;
    idxIp = find(contains(lower(aVars), 'i_peak'), 1, 'first');
    if isempty(idxIp)
        idxIp = find(contains(lower(aVars), 'peak'), 1, 'first');
    end
    if ~isempty(idxIp)
        I_peak = double(alphaTbl.(char(aVars(idxIp))));
        I_peak = I_peak(ia);
        dbgMappedCols(end+1) = "I_peak <- " + aVars(idxIp);
    else
        dbgMissingVars(end+1) = "I_peak";
    end

    % width_asymmetry from alpha
    idxW = find(contains(lower(aVars), 'width') & contains(lower(aVars), 'asym'), 1, 'first');
    if isempty(idxW)
        idxW = find(contains(lower(aVars), 'asymmetry') & contains(lower(aVars), 'spread'), 1, 'first');
    end
    if isempty(idxW)
        idxW = find(contains(lower(aVars), 'width_asymmetry'), 1, 'first');
    end
    if isempty(idxW)
        dbgMissingVars(end+1) = "width_asymmetry";
    else
        width_asymmetry = double(alphaTbl.(char(aVars(idxW))));
        width_asymmetry = width_asymmetry(ia);
        dbgMappedCols(end+1) = "width_asymmetry <- " + aVars(idxW);
    end

    % slope_asymmetry from alpha
    idxS = find(contains(lower(aVars), 'slope') & contains(lower(aVars), 'asym'), 1, 'first');
    if isempty(idxS)
        idxS = find(contains(lower(aVars), 'skew') & contains(lower(aVars), 'weighted'), 1, 'first');
    end
    if isempty(idxS)
        idxS = find(contains(lower(aVars), 'slope_asymmetry'), 1, 'first');
    end
    if isempty(idxS)
        dbgMissingVars(end+1) = "slope_asymmetry";
    else
        slope_asymmetry = double(alphaTbl.(char(aVars(idxS))));
        slope_asymmetry = slope_asymmetry(ia);
        dbgMappedCols(end+1) = "slope_asymmetry <- " + aVars(idxS);
    end

    % local_curvature from alpha (direct 'curvature' or constructed from q90_minus_q50 and q75_minus_q25)
    idxCurv = find(contains(lower(aVars), 'curvature') | contains(lower(aVars),'local_curvature'), 1, 'first');
    if isempty(idxCurv)
        idxQ90 = find(contains(lower(aVars), 'q90_minus_q50'), 1, 'first');
        idxQ75 = find(contains(lower(aVars), 'q75_minus_q25'), 1, 'first');
        if ~isempty(idxQ90) && ~isempty(idxQ75)
            local_curvature = double(alphaTbl.(char(aVars(idxQ90)))) - double(alphaTbl.(char(aVars(idxQ75))));
            local_curvature = local_curvature(ia);
            dbgMappedCols(end+1) = "local_curvature <- q90_minus_q50 - q75_minus_q25 (constructed)";
        else
            dbgMissingVars(end+1) = "local_curvature";
        end
    else
        local_curvature = double(alphaTbl.(char(aVars(idxCurv))));
        local_curvature = local_curvature(ia);
        dbgMappedCols(end+1) = "local_curvature <- " + aVars(idxCurv);
    end

    % antisym_area_res2 from residual (direct antisym/residual proxy or constructed from leftover_norm)
    idxAnti = find(contains(lower(rVars), 'antisym'), 1, 'first');
    if isempty(idxAnti)
        idxAnti = find(contains(lower(rVars), 'area') & contains(lower(rVars),'res2'), 1, 'first');
    end
    if isempty(idxAnti)
        idxAnti = find(contains(lower(rVars), 'rel_orth_leftover_norm') | contains(lower(rVars),'rel_orth_leftover'), 1, 'first');
    end
    if isempty(idxAnti)
        dbgMissingVars(end+1) = "antisym_area_res2";
    else
        antisym_area_res2 = double(resTbl.(char(rVars(idxAnti))));
        antisym_area_res2 = antisym_area_res2(ib);
        dbgMappedCols(end+1) = "antisym_area_res2 <- " + rVars(idxAnti);
    end

    % -----------------------------
    % Restrict to T <= 30 and finite
    % -----------------------------
    alignedTmask = isfinite(T_K) & (T_K <= 30);
    T_K = T_K(alignedTmask);
    kappa2 = kappa2(alignedTmask);
    I_peak = I_peak(alignedTmask);
    width_asymmetry = width_asymmetry(alignedTmask);
    slope_asymmetry = slope_asymmetry(alignedTmask);
    local_curvature = local_curvature(alignedTmask);
    antisym_area_res2 = antisym_area_res2(alignedTmask);

    % Normalize shape to column vectors for robust concatenation/modeling.
    T_K = T_K(:);
    kappa2 = kappa2(:);
    I_peak = I_peak(:);
    width_asymmetry = width_asymmetry(:);
    slope_asymmetry = slope_asymmetry(:);
    local_curvature = local_curvature(:);
    antisym_area_res2 = antisym_area_res2(:);

    if ~isempty(T_K) && any(isfinite(T_K))
        TRangeAfterAlignment = [min(T_K(isfinite(T_K))), max(T_K(isfinite(T_K)))];
    end

    % -----------------------------
    % Save build outputs always
    % -----------------------------
    verifyTbl = table(T_K, kappa2, I_peak, width_asymmetry, slope_asymmetry, local_curvature, antisym_area_res2, ...
        'VariableNames', {'T_K','kappa2','I_peak','width_asymmetry','slope_asymmetry','local_curvature','antisym_area_res2'});
    save(checkMatPath, 'T_K','kappa2','I_peak','width_asymmetry','slope_asymmetry','local_curvature','antisym_area_res2');
    try
        writetable(verifyTbl, checkCsvPath);
    catch
        % non-fatal
    end

    % Build status
    nAligned = numel(T_K);
    if isempty(nAligned) || nAligned==0
        statusMode = 'FAILED_RECOVERED';
        statusDetails(end+1) = "Aligned dataset empty after T_K restriction.";
    else
        missingUnique = unique(dbgMissingVars);
        if isempty(missingUnique)
            statusMode = 'SUCCESS';
        else
            statusMode = 'PARTIAL';
            statusDetails(end+1) = "Some mapped variables were missing; related models may be skipped.";
        end
    end

    fid = fopen(buildStatusPath,'w');
    fprintf(fid, 'SUCCESS_MODE: %s\n', statusMode);
    fprintf(fid, 'alphaPath: %s\n', alphaPath);
    fprintf(fid, 'residualPath: %s\n', selectedResidualPath);
    fprintf(fid, 'alphaSize: %d x %d\n', alphaSize(1), alphaSize(2));
    fprintf(fid, 'residualSize: %d x %d\n', resSize(1), resSize(2));
    fprintf(fid, 'mappedColumns:\n');
    fprintf(fid, '%s\n', unique(dbgMappedCols));
    fprintf(fid, 'missingVariables:\n');
    fprintf(fid, '%s\n', unique(dbgMissingVars));
    fprintf(fid, 'alignedRows: %d\n', nAligned);
    fprintf(fid, 'T_range_after_alignment: [%.6g, %.6g]\n', TRangeAfterAlignment(1), TRangeAfterAlignment(2));
    fclose(fid);

    % -----------------------------
    % Modeling (LOOCV linear regression)
    % -----------------------------
    y = kappa2;
    nAll = numel(y);
    haveY = isfinite(y);

    % Constant baseline LOOCV
    Xbaseline = [];
    yvBase = y(haveY);
    nBase = numel(yvBase);
    if nBase >= 4
        yhatBase = zeros(nBase,1);
        for k = 1:nBase
            tr = true(nBase,1);
            tr(k) = false;
            mu = mean(yvBase(tr), 'omitnan');
            yhatBase(k) = mu;
        end
        baselineRow.n_used = nBase;
        baselineRow.loocv_rmse = sqrt(mean((yvBase - yhatBase).^2, 'omitnan'));
        baselineRow.pearson = corr(yvBase, yhatBase, 'type','Pearson','rows','complete');
        baselineRow.spearman = corr(tiedrank(yvBase), tiedrank(yhatBase), 'rows','complete');
        if ~isfinite(baselineRow.pearson); baselineRow.pearson = NaN; end
        if ~isfinite(baselineRow.spearman); baselineRow.spearman = NaN; end
    else
        baselineRow.n_used = nBase;
        baselineRow.loocv_rmse = NaN;
    end

    % Helper to append result rows without functions: use local inline logic (copy patterns)
    closureModels = { ...
        'single','I_peak', I_peak; ...
        'single','width_asymmetry', width_asymmetry; ...
        'single','slope_asymmetry', slope_asymmetry; ...
        'single','local_curvature', local_curvature; ...
        'single','antisym_area_res2', antisym_area_res2; ...
        'pair','I_peak + width_asymmetry', [I_peak, width_asymmetry]; ...
        'pair','I_peak + local_curvature', [I_peak, local_curvature]; ...
        'pair','slope_asymmetry + antisym_area_res2', [slope_asymmetry, antisym_area_res2] ...
        };

    bestCandidate = struct('loocv_rmse',NaN,'pearson',NaN,'spearman',NaN,'rmse_over_baseline',NaN,'name','');
    maxAbsSpear = -inf;
    maxAbsSpearName = '';
    maxAbsSpearValue = NaN;

    for mi = 1:size(closureModels,1)
        fam = closureModels{mi,1};
        name = closureModels{mi,2};
        X = closureModels{mi,3};
        mask = isfinite(y);
        if ~isempty(X)
            if isvector(X)
                mask = mask & isfinite(X);
                Xv = X(mask);
                Xv = Xv(:);
                yv = y(mask);
            else
                mask = mask & all(isfinite(X),2);
                yv = y(mask);
                Xv = X(mask,:);
            end
        else
            yv = y(mask);
            Xv = [];
        end
        nUsed = numel(yv);

        rmse = NaN; pear = NaN; spear = NaN; ratio = NaN; delta = NaN;
        modelStatus = '';

        if nUsed < 4
            modelStatus = 'SKIPPED_TOO_FEW_ROWS';
        elseif nAll ~= 0 && ~isfinite(baselineRow.loocv_rmse)
            modelStatus = 'SKIPPED_BASELINE_NA';
        else
            if isvector(Xv)
                Xmat = Xv(:);
            else
                Xmat = Xv;
            end
            try
                yhat = zeros(nUsed,1);
                for k = 1:nUsed
                    tr = true(nUsed,1);
                    tr(k) = false;
                    beta = [ones(sum(tr),1), Xmat(tr,:)] \ yv(tr);
                    yhat(k) = [1, Xmat(k,:)] * beta;
                end
                rmse = sqrt(mean((yv - yhat).^2, 'omitnan'));
                if isfinite(baselineRow.loocv_rmse) && baselineRow.loocv_rmse ~= 0
                    ratio = rmse / baselineRow.loocv_rmse;
                    delta = rmse - baselineRow.loocv_rmse;
                end
                C = corrcoef(yv, yhat);
                if numel(C) >= 4
                    pear = C(1,2);
                end
                spear = corr(tiedrank(yv), tiedrank(yhat), 'rows','complete');

                modelStatus = 'OK';
            catch
                modelStatus = 'SKIPPED_FIT_ERROR';
            end
        end

        resultsRows(end+1,:) = {fam, name, modelStatus, nUsed, rmse, pear, spear, ratio, delta}; %#ok<SAGROW>

        % Track best model among valid ones
        if strcmp(modelStatus,'OK') && isfinite(rmse)
            if ~isfinite(bestCandidate.loocv_rmse) || rmse < bestCandidate.loocv_rmse
                bestCandidate.loocv_rmse = rmse;
                bestCandidate.pearson = pear;
                bestCandidate.spearman = spear;
                bestCandidate.rmse_over_baseline = ratio;
                bestCandidate.name = name;
            end
        end

        if strcmp(modelStatus,'OK') && isfinite(spear)
            if abs(spear) > maxAbsSpear
                maxAbsSpear = abs(spear);
                maxAbsSpearName = name;
                maxAbsSpearValue = spear;
            end
        end
    end

    % Build results table
    if ~isempty(resultsRows)
        resultsTbl = cell2table(resultsRows, 'VariableNames', resultsHeader);
        % Normalize text columns to string to avoid char-size comparison errors.
        resultsTbl.family = string(resultsTbl.family);
        resultsTbl.model = string(resultsTbl.model);
        resultsTbl.status = string(resultsTbl.status);
        % Ensure numeric columns are numeric where possible
        try
            resultsTbl.n_used = cell2mat(resultsRows(:,4));
        catch
        end
    else
        resultsTbl = cell2table(cell(0,numel(resultsHeader)), 'VariableNames', resultsHeader);
    end

    % Write audit CSV
    try
        writetable(resultsTbl, auditCsvPath);
    catch
        % non-fatal
    end

    % Determine signature existence
    if isfinite(maxAbsSpear) && maxAbsSpear >= 0.65
        signatureHas = 'YES';
        signatureSpearMax = maxAbsSpearValue;
    else
        signatureHas = 'NO';
        signatureSpearMax = maxAbsSpearValue;
    end

    % Best available model
    if ~isempty(bestCandidate.name)
        bestModelName = bestCandidate.name;
        bestN = numel(y(~isnan(y) & isfinite(y)));
        bestRmse = bestCandidate.loocv_rmse;
        bestPear = bestCandidate.pearson;
        bestSpear = bestCandidate.spearman;
        bestRmseOverBaseline = bestCandidate.rmse_over_baseline;
    end

    % Closure verdict (use baseline comparison)
    if isfinite(bestRmseOverBaseline)
        if bestRmseOverBaseline <= 0.60 && abs(bestPear) >= 0.85 && abs(bestSpear) >= 0.85
            closureVerdict = 'YES';
        elseif bestRmseOverBaseline <= 0.90 && (abs(bestPear) >= 0.65 || abs(bestSpear) >= 0.65)
            closureVerdict = 'PARTIAL';
        else
            closureVerdict = 'NO';
        end
    else
        closureVerdict = 'NO';
    end

    % Physical meaning of kappa2 (choose exactly one)
    if strcmp(closureVerdict,'NO') && strcmp(signatureHas,'NO')
        physicalMeaning = 'no stable physical interpretation (no runnable model achieved a stable monotonic signature in the tested observable set).';
    else
        if contains(bestModelName, 'antisym_area_res2', 'IgnoreCase', true)
            physicalMeaning = 'local asymmetry mode near switching peak (best available model uses antisym_area_res2 and yields the strongest monotonic trend).';
        elseif contains(bestModelName, 'I_peak', 'IgnoreCase', true)
            physicalMeaning = 'deformation of collective response linked to Phi1-like deformation (best available model tracks I_peak most strongly).';
        elseif strcmp(signatureHas,'YES')
            physicalMeaning = 'non-closed secondary collective coordinate (operational signature exists but closure is not fully achieved).';
        else
            physicalMeaning = 'local asymmetry mode near switching peak (fallback based on the strongest descriptor available).';
        end
    end

    % -----------------------------
    % Final report markdown (MANDATORY)
    % -----------------------------
    lines = strings(0,1);
    lines(end+1) = '# Kappa2 phenomenological audit';
    lines(end+1) = '';
    lines(end+1) = '## Inputs used';
    lines(end+1) = '- alpha_structure.csv: ' + alphaPath;
    lines(end+1) = '- residual_rank_structure_vs_T.csv: ' + selectedResidualPath;
    lines(end+1) = sprintf('- alpha size: %d rows x %d cols', alphaSize(1), alphaSize(2));
    lines(end+1) = sprintf('- residual size: %d rows x %d cols', resSize(1), resSize(2));
    lines(end+1) = sprintf('- T range after alignment (finite, T<=30): [%.6g, %.6g]', TRangeAfterAlignment(1), TRangeAfterAlignment(2));
    lines(end+1) = '';

    % Column discovery section
    lines(end+1) = '## Column discovery';
    lines(end+1) = 'alpha_structure.csv original columns (as recorded):';
    lines(end+1) = '```';
    if ~isempty(dbgAlphaCols)
        lines(end+1) = strjoin(cellstr(dbgAlphaCols), newline);
    else
        lines(end+1) = '(none)';
    end
    lines(end+1) = '```';
    lines(end+1) = 'residual_rank_structure_vs_T.csv original columns (as recorded):';
    lines(end+1) = '```';
    if ~isempty(dbgResCols)
        lines(end+1) = strjoin(cellstr(dbgResCols), newline);
    else
        lines(end+1) = '(none)';
    end
    lines(end+1) = '```';
    lines(end+1) = 'Mapping used:';
    if ~isempty(dbgMappedCols)
        mappedUnique = unique(dbgMappedCols);
        for j = 1:numel(mappedUnique)
            lines(end+1) = '- ' + mappedUnique(j);
        end
    else
        lines(end+1) = '- (none)';
    end
    lines(end+1) = 'Missing variables:';
    if ~isempty(dbgMissingVars)
        missingUnique = unique(dbgMissingVars);
        for j = 1:numel(missingUnique)
            lines(end+1) = '- ' + missingUnique(j);
        end
    else
        lines(end+1) = '- (none)';
    end
    lines(end+1) = '';

    % Observable definitions
    lines(end+1) = '## Observable definitions';
    lines(end+1) = '- `I_peak`: ridge peak location descriptor (peak amplitude/position on the switching ridge).';
    lines(end+1) = '- `width_asymmetry`: local left/right width imbalance proxy (e.g. `asymmetry_q_spread`).';
    lines(end+1) = '- `slope_asymmetry`: local slope/shape asymmetry proxy (e.g. `skew_I_weighted`).';
    lines(end+1) = '- `local_curvature`: peak-neighborhood curvature/shoulder proxy (constructed as `q90_minus_q50 - q75_minus_q25` if direct curvature is unavailable).';
    lines(end+1) = '- `antisym_area_res2`: residual-strip antisymmetric strength proxy (e.g. `rel_orth_leftover_norm`).';
    lines(end+1) = '';

    % Results section
    lines(end+1) = '## Results';
    lines(end+1) = sprintf('- Constant baseline LOOCV RMSE: %.6g (n_used=%d)', baselineRow.loocv_rmse, baselineRow.n_used);
    lines(end+1) = '';
    lines(end+1) = 'Single-variable models:';
    try
        for j = 1:height(resultsTbl)
            if resultsTbl.family(j) == "single"
                lines(end+1) = sprintf('- %s: n_used=%d LOOCV_RMSE=%.6g Pearson=%.4f Spearman=%.4f status=%s', ...
                    resultsTbl.model(j), resultsTbl.n_used(j), resultsTbl.loocv_rmse(j), resultsTbl.pearson(j), resultsTbl.spearman(j), resultsTbl.status(j));
            end
        end
    catch
        lines(end+1) = '- (could not render singles)';
    end
    lines(end+1) = '';
    lines(end+1) = 'Two-variable models:';
    try
        for j = 1:height(resultsTbl)
            if resultsTbl.family(j) == "pair"
                lines(end+1) = sprintf('- %s: n_used=%d LOOCV_RMSE=%.6g Pearson=%.4f Spearman=%.4f status=%s', ...
                    resultsTbl.model(j), resultsTbl.n_used(j), resultsTbl.loocv_rmse(j), resultsTbl.pearson(j), resultsTbl.spearman(j), resultsTbl.status(j));
            end
        end
    catch
        lines(end+1) = '- (could not render pairs)';
    end
    lines(end+1) = '';

    % Best model
    lines(end+1) = '## Best available model';
    if isempty(bestModelName)
        lines(end+1) = '- (none)';
    else
        lines(end+1) = '- name: `' + bestModelName + '`';
        lines(end+1) = sprintf('- n_used (approx): %d', bestN);
        lines(end+1) = sprintf('- LOOCV RMSE: %.6g', bestRmse);
        lines(end+1) = sprintf('- Pearson: %.4f', bestPear);
        lines(end+1) = sprintf('- Spearman: %.4f', bestSpear);
        lines(end+1) = sprintf('- delta vs baseline (RMSE): %.6g', bestRmse - baselineRow.loocv_rmse);
    end
    lines(end+1) = '';

    % Recovery notes
    lines(end+1) = '## Recovery notes';
    if ~isempty(statusDetails)
        for j = 1:numel(statusDetails)
            lines(end+1) = '- ' + statusDetails(j);
        end
    else
        lines(end+1) = '- (none)';
    end
    if ~isempty(dbgWarnings)
        for j = 1:numel(dbgWarnings)
            lines(end+1) = '- ' + dbgWarnings(j);
        end
    end
    % Explicit skipped model summary
    try
        skippedMask = startsWith(string(resultsTbl.status), 'SKIPPED_');
        if any(skippedMask)
            lines(end+1) = '- Skipped models: ' + strjoin(string(resultsTbl.model(skippedMask)), ', ');
        else
            lines(end+1) = '- Skipped models: (none)';
        end
    catch
        lines(end+1) = '- Skipped models: (unavailable)';
    end
    lines(end+1) = '';

    % Operational signature
    lines(end+1) = '## Operational signature';
    lines(end+1) = '- Operational signature exists even if closure fails: ' + signatureHas;
    if strcmp(signatureHas,'YES') && isfinite(signatureSpearMax)
        lines(end+1) = sprintf('- strongest |Spearman| achieved: %.4f', signatureSpearMax);
    end
    lines(end+1) = '';

    % Final verdict
    lines(end+1) = '## Final verdict';
    if strcmp(closureVerdict,'YES')
        lines(end+1) = '- KAPPA2_PHENOMENOLOGICALLY_CLOSED: YES';
    elseif strcmp(closureVerdict,'PARTIAL')
        lines(end+1) = '- KAPPA2_PHENOMENOLOGICALLY_CLOSED: PARTIAL';
    else
        lines(end+1) = '- KAPPA2_PHENOMENOLOGICALLY_CLOSED: NO';
    end
    lines(end+1) = '- KAPPA2_HAS_OPERATIONAL_SIGNATURE: ' + signatureHas;

    lines(end+1) = '';

    % Physical meaning
    lines(end+1) = '## Physical meaning of kappa2';
    lines(end+1) = '- ' + physicalMeaning;

    reportText = strjoin(cellstr(lines), newline);
    fid = fopen(auditMdPath,'w');
    fprintf(fid, '%s\n', reportText);
    fclose(fid);

    % Audit status file
    fid = fopen(auditStatusPath,'w');
    fprintf(fid, 'audit_mode: %s\n', statusMode);
    fprintf(fid, 'closureVerdict: %s\n', closureVerdict);
    fprintf(fid, 'signatureHas: %s\n', signatureHas);
    fprintf(fid, 'bestModelName: %s\n', bestModelName);
    fprintf(fid, 'bestRmseOverBaseline: %.6g\n', bestRmseOverBaseline);
    fclose(fid);

catch ME
    statusMode = 'FAILED_RECOVERED';
    statusDetails(end+1) = 'Unexpected error: ' + ME.message;

    % Try to write error log
    try
        fidErr = fopen(errPath,'w');
        fprintf(fidErr, '%s\n\n', datestr(now));
        fprintf(fidErr, 'identifier: %s\n', string(ME.identifier));
        fprintf(fidErr, 'message: %s\n\n', ME.message);
        fprintf(fidErr, '%s\n', getReport(ME));
        fclose(fidErr);
    catch
    end

    % Normalize placeholders to consistent sizes for fail-safe writes.
    T_K = NaN(0,1);
    kappa2 = NaN(0,1);
    I_peak = NaN(0,1);
    width_asymmetry = NaN(0,1);
    slope_asymmetry = NaN(0,1);
    local_curvature = NaN(0,1);
    antisym_area_res2 = NaN(0,1);

    % Best-effort build output writes already need to be attempted
    try
        verifyTbl = table(T_K, kappa2, I_peak, width_asymmetry, slope_asymmetry, local_curvature, antisym_area_res2, ...
            'VariableNames', {'T_K','kappa2','I_peak','width_asymmetry','slope_asymmetry','local_curvature','antisym_area_res2'});
        save(checkMatPath, 'T_K','kappa2','I_peak','width_asymmetry','slope_asymmetry','local_curvature','antisym_area_res2');
        writetable(verifyTbl, checkCsvPath);
    catch
    end

    try
        fid = fopen(buildStatusPath,'w');
        fprintf(fid, 'SUCCESS_MODE: %s\n', statusMode);
        fprintf(fid, 'error: %s\n', ME.message);
        fprintf(fid, 'alphaPath: %s\n', alphaPath);
        fprintf(fid, 'residualPath: %s\n', selectedResidualPath);
        fclose(fid);
    catch
    end

    % Always write audit placeholders
    try
        resultsTbl = cell2table(cell(0,numel(resultsHeader)), 'VariableNames', resultsHeader);
        writetable(resultsTbl, auditCsvPath);
    catch
    end
    try
        lines = strings(0,1);
        lines(end+1) = '# Kappa2 phenomenological audit';
        lines(end+1) = '';
        lines(end+1) = '## Inputs used';
        lines(end+1) = '- alpha_structure.csv: ' + alphaPath;
        lines(end+1) = '- residual_rank_structure_vs_T.csv: ' + selectedResidualPath;
        lines(end+1) = '';
        lines(end+1) = '## Final verdict';
        lines(end+1) = '- KAPPA2_PHENOMENOLOGICALLY_CLOSED: NO';
        lines(end+1) = '- KAPPA2_HAS_OPERATIONAL_SIGNATURE: NO';
        lines(end+1) = '';
        lines(end+1) = '## Physical meaning of kappa2';
        lines(end+1) = '- no stable physical interpretation';
        fid = fopen(auditMdPath,'w');
        fprintf(fid, '%s\n', strjoin(cellstr(lines), newline));
        fclose(fid);
    catch
    end

    try
        fid = fopen(auditStatusPath,'w');
        fprintf(fid, 'audit_mode: %s\n', statusMode);
        fprintf(fid, 'closureVerdict: %s\n', closureVerdict);
        fprintf(fid, 'signatureHas: %s\n', signatureHas);
        fclose(fid);
    catch
    end
end

end

