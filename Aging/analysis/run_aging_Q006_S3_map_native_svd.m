function run_aging_Q006_S3_map_native_svd()
% Q006-S3 canonical map-native SVD on Q006-S2c exported matrix.
% No mechanism closure, no cross-module analysis, no domain expansion.

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

inMatrix = fullfile(tablesDir, 'aging_Q006_S2c_map_native_matrix.csv');
inRows = fullfile(tablesDir, 'aging_Q006_S2c_map_native_rows.csv');
inTAxis = fullfile(tablesDir, 'aging_Q006_S2c_map_native_T_axis.csv');
inVal = fullfile(tablesDir, 'aging_Q006_S2c_export_validation.csv');
trackAPath = fullfile(tablesDir, 'aging_trackA_replay_dataset.csv');
trackBPath = fullfile(tablesDir, 'aging_observable_dataset.csv');

outSing = fullfile(tablesDir, 'aging_Q006_S3_map_svd_singular_values.csv');
outScores = fullfile(tablesDir, 'aging_Q006_S3_map_svd_row_scores.csv');
outTModes = fullfile(tablesDir, 'aging_Q006_S3_map_svd_T_modes.csv');
outEnergy = fullfile(tablesDir, 'aging_Q006_S3_mode_energy_summary.csv');
outRobust = fullfile(tablesDir, 'aging_Q006_S3_mode_robustness.csv');
outOverlay = fullfile(tablesDir, 'aging_Q006_S3_mode_interpretation_overlays.csv');
outDecision = fullfile(tablesDir, 'aging_Q006_S3_map_svd_decision.csv');
outReport = fullfile(reportsDir, 'aging_Q006_S3_map_native_svd.md');

assert(exist(inMatrix,'file')==2 && exist(inRows,'file')==2 && exist(inTAxis,'file')==2 && exist(inVal,'file')==2, ...
    'Missing S2c input artifacts.');

v = robustReadCsv(inVal);
must = struct('MAP_NATIVE_MATRIX_EXPORTED',"true",'USED_INTERPOLATION',"false",'USED_NORMALIZATION',"false", ...
    'USED_CENTERING',"false",'USED_SMOOTHING',"false",'USED_SIGN_FLIP',"false",'EXCLUDED_T_USED',"false",'TP34_USED',"false");
fns = fieldnames(must);
for i = 1:numel(fns)
    fn = fns{i}; vv = lower(string(v.(fn)(1))); assert(vv == must.(fn), 'Precheck failed: %s=%s', fn, vv);
end
assert(upper(string(v.READY_FOR_MAP_NATIVE_SVD(1))) == "YES", 'Precheck failed: READY_FOR_MAP_NATIVE_SVD');
gridPolicy = string(v.GRID_POLICY_USED(1));

mTbl = robustReadCsv(inMatrix);
rTbl = robustReadCsv(inRows);
tTbl = robustReadCsv(inTAxis);
assert(height(mTbl)==8 && height(rTbl)==8, 'Expected 8 rows in matrix/row table');
assert(all(rTbl.cell_extracted=="YES"), 'Rows table indicates missing extracted cells');

X = double(table2array(mTbl(:, 6:width(mTbl))));
Taxis = extractTAxis(tTbl);
if size(X,2) ~= numel(Taxis)
    Taxis = parseTAxisFromHeaders(string(mTbl.Properties.VariableNames(6:end)));
end
assert(size(X,1)==8 && size(X,2)==numel(Taxis), 'Matrix/T-axis mismatch');
assert(all(isfinite(X),'all') && all(isfinite(Taxis)), 'Non-finite matrix/T-axis');
Tp = mTbl.Tp; tw = mTbl.tw;

variants = ["RAW_UNCENTERED","ROW_CENTERED_DIAGNOSTIC","COLUMN_CENTERED_DIAGNOSTIC"];
Xraw = X; Xrow = X - mean(X,2); Xcol = X - mean(X,1);
Xmap = struct('RAW_UNCENTERED',Xraw,'ROW_CENTERED_DIAGNOSTIC',Xrow,'COLUMN_CENTERED_DIAGNOSTIC',Xcol);

singRows = table(); scoreRows = table(); tmodeRows = table(); energyRows = table(); svdCache = struct();
for vi = 1:numel(variants)
    vn = variants(vi); Xi = Xmap.(char(vn)); [U,S,V] = svd(Xi,'econ');
    s = diag(S); e = s.^2; ef = e/max(sum(e),eps); cf = cumsum(ef);
    r1 = ef(1); r2cum = cf(min(2,numel(cf))); rank1Dominant = r1 >= 0.70; rank2Meaningful = numel(ef)>=2 && ef(2)>=0.10;
    svdCache.(char(vn)) = struct('U',U,'S',S,'V',V,'s',s,'ef',ef);
    for k = 1:numel(s)
        singRows = [singRows; table(vn,k,s(k),ef(k),cf(k),'VariableNames',{'variant','mode_index','singular_value','energy_fraction','cumulative_energy_fraction'})]; %#ok<AGROW>
    end
    for i = 1:size(U,1)
        sc = U(i,:).*s.'; m1 = getMode(sc,1); m2 = getMode(sc,2); m3 = getMode(sc,3);
        scoreRows = [scoreRows; table(vn,i,Tp(i),tw(i),m1,m2,m3,sign(m1),sign(m2),sign(m3), ...
            'VariableNames',{'variant','row_index','Tp','tw','mode1_score','mode2_score','mode3_score','mode1_sign','mode2_sign','mode3_sign'})]; %#ok<AGROW>
    end
    for k = 1:min(3,size(V,2))
        for j = 1:numel(Taxis)
            tmodeRows = [tmodeRows; table(vn,k,Taxis(j),V(j,k),'VariableNames',{'variant','mode_index','T_K','mode_amplitude'})]; %#ok<AGROW>
        end
    end
    energyRows = [energyRows; table(vn,size(Xi,1),size(Xi,2),r1,r2cum,rank1Dominant,rank2Meaningful, ...
        'VariableNames',{'variant','n_rows','n_tscan_columns','rank1_energy_fraction','rank2_cumulative_energy','rank1_dominant','rank2_meaningful'})]; %#ok<AGROW>
end

robRows = table(); rawV = svdCache.RAW_UNCENTERED.V; nLead = min(3,size(rawV,2));
for vn = ["ROW_CENTERED_DIAGNOSTIC","COLUMN_CENTERED_DIAGNOSTIC"]
    Vb = svdCache.(char(vn)).V;
    for k = 1:nLead
        [c,sf] = signedCorr(rawV(:,k),Vb(:,k));
        robRows = [robRows; table("RAW_vs_"+vn,k,c,sf,'VariableNames',{'test_name','mode_index','mode_vector_corr','sign_flip_for_alignment'})]; %#ok<AGROW>
    end
end
tps = unique(Tp,'stable');
for i = 1:numel(tps)
    keep = Tp ~= tps(i); [~,~,Vsub] = svd(Xraw(keep,:),'econ');
    for k = 1:min([nLead,size(Vsub,2)])
        [c,sf] = signedCorr(rawV(:,k),Vsub(:,k));
        robRows = [robRows; table("LEAVE_ONE_TP_"+string(tps(i)),k,c,sf,'VariableNames',{'test_name','mode_index','mode_vector_corr','sign_flip_for_alignment'})]; %#ok<AGROW>
    end
end
tws = unique(tw,'stable');
for i = 1:numel(tws)
    keep = tw ~= tws(i); [~,~,Vsub] = svd(Xraw(keep,:),'econ');
    for k = 1:min([nLead,size(Vsub,2)])
        [c,sf] = signedCorr(rawV(:,k),Vsub(:,k));
        robRows = [robRows; table("LEAVE_ONE_TW_"+string(tws(i)),k,c,sf,'VariableNames',{'test_name','mode_index','mode_vector_corr','sign_flip_for_alignment'})]; %#ok<AGROW>
    end
end

rawScores = scoreRows(scoreRows.variant=="RAW_UNCENTERED",:);
joinTbl = table(rawScores.Tp,rawScores.tw,rawScores.mode1_score,rawScores.mode2_score,rawScores.mode3_score, ...
    'VariableNames',{'Tp','tw','mode1_score','mode2_score','mode3_score'});
if exist(trackAPath,'file')==2
    A = robustReadCsv(trackAPath);
    A = A(ismember(A.tw,[360 3600]) & ismember(A.Tp,[18 22 26 30]),:);
    if ~isempty(A)
        joinTbl = outerjoin(joinTbl, unique(A(:,{'Tp','tw','Dip_area_selected','AFM_like','FM_like','FM_E'}),'rows'), ...
            'Keys',{'Tp','tw'},'MergeKeys',true,'Type','left');
    end
end
if exist(trackBPath,'file')==2
    B = robustReadCsv(trackBPath);
    B = B(ismember(B.tw,[360 3600]) & ismember(B.Tp,[18 22 26 30]),:);
    if ~isempty(B)
        joinTbl = outerjoin(joinTbl, unique(B(:,{'Tp','tw','Dip_depth','FM_abs'}),'rows'), ...
            'Keys',{'Tp','tw'},'MergeKeys',true,'Type','left');
    end
end
overlayRows = table();
obsList = ["Dip_area_selected","Dip_depth","AFM_like","FM_like","FM_E","FM_abs"];
for oi = 1:numel(obsList)
    on = obsList(oi);
    if ~ismember(on, string(joinTbl.Properties.VariableNames)), continue; end
    y = double(joinTbl.(char(on)));
    for k = 1:3
        x = double(joinTbl.(sprintf('mode%d_score',k))); mask = isfinite(x) & isfinite(y);
        if nnz(mask)>=3, r = corr(x(mask),y(mask),'Type','Pearson'); else, r = NaN; end
        overlayRows = [overlayRows; table(on,k,nnz(mask),r,sign(r), ...
            'VariableNames',{'observable','mode_index','n_pairs','pearson_r','sign_agreement'})]; %#ok<AGROW>
    end
end

assign = strings(3,1); dipFound = false; fmFound = false; mixedFound = false;
for k = 1:3
    rk = overlayRows(overlayRows.mode_index==k,:);
    rdip = pickCorr(rk,"Dip_area_selected",0.35); rdepth = pickCorr(rk,"Dip_depth",0.35); rafm = pickCorr(rk,"AFM_like",0.35);
    rfm = max(abs([pickCorr(rk,"FM_like",0.35),pickCorr(rk,"FM_E",0.35),pickCorr(rk,"FM_abs",0.35)]),[],'omitnan');
    if isfinite(max([rdip,rdepth,rafm],[],'omitnan')) && max([rdip,rdepth,rafm],[],'omitnan') >= 0.45 && ~(isfinite(rfm)&&rfm>=0.45)
        assign(k) = "DIP_AFM_LIKE"; dipFound = true;
    elseif isfinite(rfm) && rfm >= 0.45 && ~(isfinite(max([rdip,rdepth,rafm],[],'omitnan')) && max([rdip,rdepth,rafm],[],'omitnan')>=0.45)
        assign(k) = "FM_LIKE"; fmFound = true;
    elseif (isfinite(max([rdip,rdepth,rafm],[],'omitnan')) && max([rdip,rdepth,rafm],[],'omitnan')>=0.40) && (isfinite(rfm) && rfm>=0.40)
        assign(k) = "MIXED"; mixedFound = true;
    else
        assign(k) = "NOISE_OR_UNINTERPRETABLE";
    end
end

meanComp = @(testPrefix) mean(abs(robRows.mode_vector_corr(startsWith(robRows.test_name,testPrefix) & robRows.mode_index<=3)),'omitnan');
stableRawDiag = mean(abs(robRows.mode_vector_corr(startsWith(robRows.test_name,"RAW_vs_") & robRows.mode_index<=3)),'omitnan');
stableLooTp = meanComp("LEAVE_ONE_TP_"); stableLooTw = meanComp("LEAVE_ONE_TW_");
modeStable = stableRawDiag >= 0.60 && stableLooTp >= 0.50 && stableLooTw >= 0.50;

rawE = energyRows(energyRows.variant=="RAW_UNCENTERED",:);
r1 = rawE.rank1_energy_fraction(1); r2cum = rawE.rank2_cumulative_energy(1);
r1Dom = rawE.rank1_dominant(1); r2Mean = rawE.rank2_meaningful(1);
smallN = true;

if ~modeStable
    finalDecision = "MAP_NATIVE_SVD_INCONCLUSIVE_SMALL_N";
elseif ~(dipFound || fmFound || mixedFound)
    finalDecision = "MAP_NATIVE_SVD_NO_INTERPRETABLE_MODES";
elseif smallN
    finalDecision = "MAP_NATIVE_SVD_PARTIAL_SUPPORT";
else
    finalDecision = "MAP_NATIVE_SVD_REVALIDATED";
end

readyForMechanism = "NO";
if modeStable && (dipFound || fmFound) && ~smallN
    readyForMechanism = "YES";
end

decision = table( ...
    "YES","RAW_UNCENTERED",size(X,1),size(X,2),gridPolicy,r1,r2cum,r1Dom,r2Mean,modeStable, ...
    dipFound,fmFound,mixedFound,smallN,true,false,false,false,false,upper(readyForMechanism),finalDecision, ...
    'VariableNames', {'MAP_NATIVE_SVD_COMPLETED','PRIMARY_VARIANT','N_ROWS','N_TSCAN_COLUMNS','GRID_POLICY_USED', ...
    'RANK1_ENERGY_FRACTION','RANK2_CUMULATIVE_ENERGY','RANK1_DOMINANT','RANK2_MEANINGFUL','MODE_ASSIGNMENTS_STABLE', ...
    'DIP_AFM_MODE_FOUND','FM_MODE_FOUND','MIXED_MODE_FOUND','SMALL_N_LIMITATION', ...
    'OBSERVABLE_OVERLAYS_USED_ONLY_FOR_INTERPRETATION','EXCLUDED_T_USED_AS_CORE_EVIDENCE','TP34_USED_AS_CORE_EVIDENCE', ...
    'MECHANISM_VALIDATION_PERFORMED','CROSS_MODULE_ANALYSIS_PERFORMED','READY_FOR_Q006_MECHANISM_TEST','FINAL_DECISION'});

for k = 1:3
    robRows = [robRows; table("MODE_ASSIGNMENT",k,NaN,assign(k), ...
        'VariableNames',{'test_name','mode_index','mode_vector_corr','sign_flip_for_alignment'})]; %#ok<AGROW>
end

writetable(singRows,outSing); writetable(scoreRows,outScores); writetable(tmodeRows,outTModes);
writetable(energyRows,outEnergy); writetable(robRows,outRobust); writetable(overlayRows,outOverlay); writetable(decision,outDecision);
writeReport(outReport, decision, rawE, assign, overlayRows, variants);
disp('Q006-S3 complete: map-native SVD outputs written.');
end

function v = getMode(sc,k)
if numel(sc) >= k, v = sc(k); else, v = NaN; end
end

function [c, signFlip] = signedCorr(a,b)
a = double(a(:)); b = double(b(:)); m = isfinite(a) & isfinite(b);
if nnz(m) < 3, c = NaN; signFlip = "NA"; return; end
c0 = corr(a(m),b(m),'Type','Pearson');
c1 = corr(a(m),-b(m),'Type','Pearson');
if abs(c1) > abs(c0), c = c1; signFlip = "YES"; else, c = c0; signFlip = "NO"; end
end

function r = pickCorr(rk, obs, minPairs)
r = NaN; k = rk(strcmp(string(rk.observable), obs),:); if isempty(k), return; end
i = k.n_pairs >= 3 & isfinite(k.pearson_r) & abs(k.pearson_r) >= minPairs;
if any(i), r = max(abs(k.pearson_r(i))); end
end

function writeReport(path, decision, rawE, assign, overlayRows, variants)
fid = fopen(path, 'w'); assert(fid>0, 'Cannot write report');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# Q006-S3 Canonical Map-Native SVD\n\n');
fprintf(fid, 'Primary variant: `%s`\n\n', decision.PRIMARY_VARIANT(1));
fprintf(fid, 'Final decision: `%s`\n\n', decision.FINAL_DECISION(1));
fprintf(fid, '## Precheck and scope constraints\n');
fprintf(fid, '- Map-native precheck passed from Q006-S2c export validation.\n');
fprintf(fid, '- No interpolation/normalization/centering/smoothing/sign flip in primary input.\n');
fprintf(fid, '- Domain fixed to Q005b: Tp={18,22,26,30}, tw={360,3600}.\n');
fprintf(fid, '- No mechanism closure and no cross-module analysis performed.\n\n');
fprintf(fid, '## SVD variants\n');
for i = 1:numel(variants), fprintf(fid, '- `%s`\n', variants(i)); end
fprintf(fid, '\n');
fprintf(fid, '## Singular spectrum (raw primary)\n');
fprintf(fid, '- Rank-1 energy fraction: %.6f\n', rawE.rank1_energy_fraction(1));
fprintf(fid, '- Rank-2 cumulative energy: %.6f\n', rawE.rank2_cumulative_energy(1));
fprintf(fid, '- Rank-1 dominant: %s\n', tf(decision.RANK1_DOMINANT(1)));
fprintf(fid, '- Rank-2 meaningful: %s\n\n', tf(decision.RANK2_MEANINGFUL(1)));
fprintf(fid, '## Leading mode assignments (conservative)\n');
for k = 1:numel(assign), fprintf(fid, '- Mode %d: `%s`\n', k, assign(k)); end
fprintf(fid, '\n');
fprintf(fid, '## Overlay interpretation (not used as SVD input)\n');
if isempty(overlayRows)
    fprintf(fid, '- Overlay observables unavailable.\n');
else
    fprintf(fid, '- Correlations reported between raw row scores and Dip/AFM/FM overlay observables.\n');
end
fprintf(fid, '\n## Robustness and limitations\n');
fprintf(fid, '- Mode assignment stability: %s\n', tf(decision.MODE_ASSIGNMENTS_STABLE(1)));
fprintf(fid, '- Small-N limitation: %s (n_rows=%d)\n', tf(decision.SMALL_N_LIMITATION(1)), decision.N_ROWS(1));
fprintf(fid, '- Ready for Q006 mechanism test: `%s`\n', decision.READY_FOR_Q006_MECHANISM_TEST(1));
end

function s = tf(x)
if islogical(x), s = string(x); elseif isnumeric(x), s = string(logical(x)); else, s = string(x); end
end

function T = robustReadCsv(path)
try
    T = readtable(path, 'TextType','string', 'VariableNamingRule','preserve');
catch
    T = table();
end
if isempty(T) || (width(T) >= 1 && startsWith(string(T.Properties.VariableNames{1}), "Var"))
    C = readcell(path, 'Delimiter', ',');
    hdr = string(C(1,:));
    data = C(2:end,:);
    vars = cell(1, numel(hdr));
    for j = 1:numel(hdr)
        col = data(:,j);
        nums = nan(size(col));
        ok = false(size(col));
        for i = 1:numel(col)
            if isnumeric(col{i}) && isscalar(col{i})
                nums(i) = col{i}; ok(i) = true;
            elseif isstring(col{i}) || ischar(col{i})
                vv = str2double(string(col{i}));
                if ~isnan(vv), nums(i) = vv; ok(i) = true; end
            end
        end
        if all(ok | cellfun(@isempty,col))
            vars{j} = nums;
        else
            vars{j} = string(col);
        end
    end
    T = table(vars{:}, 'VariableNames', cellstr(hdr));
end
end

function t = extractTAxis(tTbl)
if ismember("T_K", string(tTbl.Properties.VariableNames))
    t = double(tTbl.T_K);
    return;
end
t = [];
for i = 1:width(tTbl)
    v = tTbl{:,i};
    if isnumeric(v)
        t = double(v(:));
        if all(isfinite(t)) && ~isempty(t)
            return;
        end
    end
end
t = [];
end

function t = parseTAxisFromHeaders(h)
t = nan(numel(h),1);
for i = 1:numel(h)
    x = regexprep(h(i), '^T_', '');
    x = regexprep(x, 'K$', '');
    x = strrep(x, '_', '.');
    t(i) = str2double(x);
end
end
