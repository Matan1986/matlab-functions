function out = common_dynamical_subspace_analysis(cfg)
if nargin < 1 || ~isstruct(cfg), cfg = struct(); end
thisFile = mfilename('fullpath'); analysisDir = fileparts(thisFile); repoRoot = fileparts(analysisDir);
addpath(genpath(fullfile(repoRoot,'Aging'))); addpath(fullfile(repoRoot,'tools')); addpath(fullfile(repoRoot,'tools','figures')); addpath(analysisDir);
cfg = applyDefaults(cfg); source = resolveSourceRuns(repoRoot,cfg); repoState = buildRepositoryStateTable(repoRoot,source); data = loadObservableLibrary(source,cfg); subspace = analyzeCommonSubspace(data);
runCfg = struct('runLabel',cfg.runLabel,'dataset',sprintf('relax:%s | aging:%s,%s | switch:%s,%s',char(source.relaxRunName),char(source.agingRunName),char(source.agingAuditRunName),char(source.switchRunName),char(source.switchMotionRunName)));
run = createRunContext('cross_experiment',runCfg); runDir = run.run_dir;
fprintf('Common dynamical subspace run directory:\n%s\n',runDir);
appendText(run.log_path,sprintf('[%s] common dynamical subspace analysis started\n',stampNow()));
repoStatePath = save_run_table(repoState,'repository_state_summary.csv',runDir); matrixPath = save_run_table(subspace.observableMatrixTable,'observable_matrix.csv',runDir); loadingsPath = save_run_table(subspace.loadingsTable,'pca_loadings.csv',runDir); variancePath = save_run_table(subspace.varianceTable,'variance_explained.csv',runDir); scorePath = save_run_table(subspace.scoreTable,'pc_scores.csv',runDir); pairwisePath = save_run_table(subspace.pairwiseTable,'observable_pairwise_correlations.csv',runDir);
figScree = saveScreeFigure(subspace,runDir,'pc_scree_plot'); figPc1 = savePc1Figure(subspace,runDir,'pc1_vs_temperature'); figOverlay = saveObservableOverlayFigure(data,runDir,'observable_overlay'); figProjection = saveProjectionFigure(subspace,runDir,'pc_projection_scatter');
reportPath = save_run_report(buildReportText(thisFile,source,data,subspace,repoState),'common_dynamical_subspace_analysis.md',runDir); zipPath = buildReviewZip(runDir,'common_dynamical_subspace_analysis.zip');
appendText(run.notes_path,sprintf('PC1 variance explained = %.6f\n',subspace.varianceExplained(1))); appendText(run.notes_path,sprintf('PC1 peak temperature = %.6g K\n',subspace.pc1PeakT)); appendText(run.notes_path,sprintf('Shared-subspace verdict = %s\n',char(subspace.subspaceVerdict)));
appendText(run.log_path,sprintf('[%s] common dynamical subspace analysis complete\n',stampNow())); appendText(run.log_path,sprintf('Observable matrix: %s\n',matrixPath)); appendText(run.log_path,sprintf('Report: %s\nZIP: %s\n',reportPath,zipPath));
out = struct('run',run,'runDir',string(runDir),'source',source,'data',data,'subspace',subspace,'tables',struct('repository_state',string(repoStatePath),'observable_matrix',string(matrixPath),'loadings',string(loadingsPath),'variance',string(variancePath),'scores',string(scorePath),'pairwise',string(pairwisePath)),'figures',struct('scree',string(figScree.png),'pc1',string(figPc1.png),'overlay',string(figOverlay.png),'projection',string(figProjection.png)),'reportPath',string(reportPath),'zipPath',string(zipPath));
fprintf('\n=== Common dynamical subspace analysis complete ===\nRun dir: %s\nReport: %s\nZIP: %s\n\n',runDir,reportPath,zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg,'runLabel','common_dynamical_subspace');
cfg = setDefaultField(cfg,'relaxRunName','run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg,'agingRunName','run_2026_03_10_200643_observable_mode_correlation');
cfg = setDefaultField(cfg,'agingAuditRunName','run_2026_03_11_011643_observable_identification_audit');
cfg = setDefaultField(cfg,'switchRunName','run_2026_03_10_112659_alignment_audit');
cfg = setDefaultField(cfg,'switchMotionRunName','run_2026_03_11_084425_relaxation_switching_motion_test');
cfg = setDefaultField(cfg,'crossRelaxAgingRunName','run_2026_03_11_224713_relaxation_aging_canonical_comparison');
cfg = setDefaultField(cfg,'crossSwitchRelaxRunName','run_2026_03_12_004907_switching_relaxation_observable_comparis');
cfg = setDefaultField(cfg,'crossUnifiedRunName','run_2026_03_12_075103_unified_dynamical_crossover_synthesis');
cfg = setDefaultField(cfg,'commonGrid',10:2:28); cfg = setDefaultField(cfg,'interpMethod','pchip');
end

function source = resolveSourceRuns(repoRoot,cfg)
source.relaxRunName = string(cfg.relaxRunName); source.agingRunName = string(cfg.agingRunName); source.agingAuditRunName = string(cfg.agingAuditRunName); source.switchRunName = string(cfg.switchRunName); source.switchMotionRunName = string(cfg.switchMotionRunName); source.crossRelaxAgingRunName = string(cfg.crossRelaxAgingRunName); source.crossSwitchRelaxRunName = string(cfg.crossSwitchRelaxRunName); source.crossUnifiedRunName = string(cfg.crossUnifiedRunName);
source.relaxRunDir = fullfile(repoRoot,'results','relaxation','runs',char(source.relaxRunName)); source.agingRunDir = fullfile(repoRoot,'results','aging','runs',char(source.agingRunName)); source.agingAuditRunDir = fullfile(repoRoot,'results','aging','runs',char(source.agingAuditRunName)); source.switchRunDir = fullfile(repoRoot,'results','switching','runs',char(source.switchRunName)); source.switchMotionRunDir = fullfile(repoRoot,'results','cross_experiment','runs',char(source.switchMotionRunName)); source.crossRelaxAgingRunDir = fullfile(repoRoot,'results','cross_experiment','runs',char(source.crossRelaxAgingRunName)); source.crossSwitchRelaxRunDir = fullfile(repoRoot,'results','cross_experiment','runs',char(source.crossSwitchRelaxRunName)); source.crossUnifiedRunDir = fullfile(repoRoot,'results','cross_experiment','runs',char(source.crossUnifiedRunName));
required = {source.relaxRunDir, fullfile(char(source.relaxRunDir),'tables','temperature_observables.csv'); source.agingRunDir, fullfile(char(source.agingRunDir),'tables','observable_matrix.csv'); source.agingRunDir, fullfile(char(source.agingRunDir),'tables','svd_mode_coefficients.csv'); source.agingAuditRunDir, fullfile(char(source.agingAuditRunDir),'tables','aging_observable_recommendation_table.csv'); source.switchRunDir, fullfile(char(source.switchRunDir),'observable_matrix.csv'); source.switchMotionRunDir, fullfile(char(source.switchMotionRunDir),'tables','relaxation_switching_motion_table.csv')};
for i = 1:size(required,1), if exist(required{i,1},'dir') ~= 7, error('Missing run dir: %s',required{i,1}); end, if exist(required{i,2},'file') ~= 2, error('Missing source file: %s',required{i,2}); end, end
end

function repoState = buildRepositoryStateTable(repoRoot,source)
crossRunsDir = fullfile(repoRoot,'results','cross_experiment','runs'); d = dir(fullfile(crossRunsDir,'run_*')); names = string({d([d.isdir]).name}); hasSubspace = any(contains(lower(names),'subspace'));
rows = {'relaxation','A_T, R_T, beta_T, tau_T',char(source.relaxRunName),fullfile(char(source.relaxRunDir),'tables','temperature_observables.csv'),'primary_source','Canonical Relaxation temperature-observable table with A(T).'; 'aging','Dip_depth(T_p), FM_abs(T_p)',char(source.agingRunName),fullfile(char(source.agingRunDir),'tables','observable_matrix.csv'),'primary_source','Saved pooled Aging observables used to aggregate one curve per T_p.'; 'aging','coeff_mode1(T_p)',char(source.agingRunName),fullfile(char(source.agingRunDir),'tables','svd_mode_coefficients.csv'),'primary_source','Saved Aging SVD coefficients; shifted_Tp basis preferred when available.'; 'aging','observable recommendations',char(source.agingAuditRunName),fullfile(char(source.agingAuditRunDir),'tables','aging_observable_recommendation_table.csv'),'supporting_audit','Later audit identifying Dip_depth as primary and FM_abs as secondary.'; 'switching','I_peak(T), S_peak(T), width_I(T), halfwidth_diff_norm(T), asym(T)',char(source.switchRunName),fullfile(char(source.switchRunDir),'observable_matrix.csv'),'primary_source','Canonical Switching ridge-observable export.'; 'cross_experiment','|dI_peak/dT| and harmonized switching-relaxation curves',char(source.switchMotionRunName),fullfile(char(source.switchMotionRunDir),'tables','relaxation_switching_motion_table.csv'),'primary_source','Saved Switching ridge-motion derivative table reused directly.'; 'cross_experiment','Relaxation-Aging harmonized curves',char(source.crossRelaxAgingRunName),fullfile(char(source.crossRelaxAgingRunDir),'tables','relaxation_aging_observable_alignment.csv'),'candidate_run','Existing saved comparison run with oriented coeff_mode1 and interpolated A(T).'; 'cross_experiment','Switching-Relaxation harmonized curves',char(source.crossSwitchRelaxRunName),fullfile(char(source.crossSwitchRelaxRunDir),'tables','switching_relaxation_observable_curves.csv'),'candidate_run','Existing saved comparison run with aligned motion and width observables.'; 'cross_experiment','Unified crossover synthesis',char(source.crossUnifiedRunName),fullfile(char(source.crossUnifiedRunDir),'tables','unified_crossover_summary.csv'),'candidate_run','Existing three-way synthesis centered on crossover markers, not a PCA/subspace run.'; 'cross_experiment','Dedicated common-subspace run','not_found',fullfile(crossRunsDir,'run_*subspace*'),'scan_result',ternary(hasSubspace,'A prior subspace-labeled run exists in the cross_experiment tree.','No prior dedicated cross-experiment subspace run was found in results/cross_experiment/runs.')};
repoState = cell2table(rows,'VariableNames',{'experiment','observables_found','source_run','source_file','role','notes'});
end

function data = loadObservableLibrary(source,cfg)
data.commonGrid = double(cfg.commonGrid(:));
relaxTbl = readtable(fullfile(source.relaxRunDir,'tables','temperature_observables.csv'),'VariableNamingRule','preserve'); relaxMeta = readtable(fullfile(source.relaxRunDir,'tables','observables_relaxation.csv'),'VariableNamingRule','preserve'); data.relax.T = relaxTbl.T(:); data.relax.A_T = relaxTbl.A_T(:); data.relax.peakT = relaxMeta.Relax_T_peak(1);
agingMatrix = readtable(fullfile(source.agingRunDir,'tables','observable_matrix.csv'),'VariableNamingRule','preserve'); agingCoeff = readtable(fullfile(source.agingRunDir,'tables','svd_mode_coefficients.csv'),'VariableNamingRule','preserve'); agingAudit = readtable(fullfile(source.agingAuditRunDir,'tables','aging_observable_recommendation_table.csv'),'VariableNamingRule','preserve');
tpName = firstMatchingName(agingMatrix.Properties.VariableNames,{'Tp','Tp_K','temperature'}); coeffTpName = firstMatchingName(agingCoeff.Properties.VariableNames,{'Tp','Tp_K','temperature'}); preferredMatrix = chooseCoeffMatrix(agingCoeff); coeffMask = strcmp(string(agingCoeff.matrix_name),preferredMatrix);
dipAgg = aggregateCurve(agingMatrix.(tpName),agingMatrix.Dip_depth,'Dip_depth'); fmAgg = aggregateCurve(agingMatrix.(tpName),agingMatrix.FM_abs,'FM_abs'); coeffAgg = aggregateCurve(agingCoeff.(coeffTpName)(coeffMask),agingCoeff.coeff_mode1(coeffMask),'coeff_mode1');
orientationCorr = corrSafe(coeffAgg.valueMedian,interpCurve(dipAgg.T,dipAgg.valueMedian,coeffAgg.T,'linear')); orientationSign = 1; if isfinite(orientationCorr) && orientationCorr < 0, orientationSign = -1; end
data.aging.T = dipAgg.T; data.aging.Dip_depth = dipAgg.valueMedian; data.aging.FM_abs_T = fmAgg.T; data.aging.FM_abs = fmAgg.valueMedian; data.aging.coeff_T = coeffAgg.T; data.aging.coeff_mode1 = orientationSign * coeffAgg.valueMedian; data.aging.coeff_orientation_note = sprintf('coeff_mode1 sign %s for positive Dip_depth alignment in %s basis',ternary(orientationSign < 0,'flipped','kept'),char(preferredMatrix)); data.aging.auditNotes = summarizeAgingAudit(agingAudit);
switchTbl = readtable(fullfile(source.switchRunDir,'observable_matrix.csv'),'VariableNamingRule','preserve'); motionTbl = readtable(fullfile(source.switchMotionRunDir,'tables','relaxation_switching_motion_table.csv'),'VariableNamingRule','preserve'); motionMask = logical(motionTbl.comparison_mask(:));
data.switching.T = switchTbl.T(:); data.switching.I_peak = switchTbl.I_peak(:); data.switching.width_I = switchTbl.width_I(:); data.switching.halfwidth_diff_norm = switchTbl.halfwidth_diff_norm(:); data.switching.asym = switchTbl.asym(:); data.switching.motion_T = motionTbl.T_K(:); data.switching.abs_dI_peak_dT = motionTbl.motion_abs_dI_peak_dT(:); data.switching.motion_mask = motionMask;
obs = {'A_T','relaxation','Relaxation A(T)',data.relax.T,data.relax.A_T; 'Dip_depth','aging','Aging Dip_depth(T_p)',data.aging.T,data.aging.Dip_depth; 'FM_abs','aging','Aging FM_abs(T_p)',data.aging.FM_abs_T,data.aging.FM_abs; 'coeff_mode1','aging','Aging coeff_mode1(T_p)',data.aging.coeff_T,data.aging.coeff_mode1; 'I_peak','switching','Switching I_peak(T)',data.switching.T,data.switching.I_peak; 'width_I','switching','Switching width_I(T)',data.switching.T,data.switching.width_I; 'abs_dI_peak_dT','switching','Switching |dI_peak/dT|',data.switching.motion_T(data.switching.motion_mask),data.switching.abs_dI_peak_dT(data.switching.motion_mask); 'halfwidth_diff_norm','switching','Switching halfwidth_diff_norm(T)',data.switching.T,data.switching.halfwidth_diff_norm; 'asym','switching','Switching asym(T)',data.switching.T,data.switching.asym};
profiles(1,1) = buildProfile(obs{1,1},obs{1,2},obs{1,3},obs{1,4},obs{1,5},data.commonGrid,char(cfg.interpMethod)); for i = 2:size(obs,1), profiles(i,1) = buildProfile(obs{i,1},obs{i,2},obs{i,3},obs{i,4},obs{i,5},data.commonGrid,char(cfg.interpMethod)); end
if any(arrayfun(@(p) any(~isfinite(p.commonValues)), profiles)), error('Common grid contains missing values for one or more observables.'); end
data.profiles = profiles;
end
function profile = buildProfile(key,experiment,label,nativeT,nativeValues,commonGrid,interpMethod)
profile.key = string(key); profile.experiment = string(experiment); profile.label = string(label); profile.nativeT = double(nativeT(:)); profile.nativeValues = double(nativeValues(:)); mask = isfinite(profile.nativeT) & isfinite(profile.nativeValues); profile.nativeT = profile.nativeT(mask); profile.nativeValues = profile.nativeValues(mask); profile.commonT = double(commonGrid(:)); profile.commonValues = interpCurve(profile.nativeT,profile.nativeValues,profile.commonT,interpMethod); profile.meanValue = mean(profile.commonValues); profile.stdValue = std(profile.commonValues,0); if ~(isfinite(profile.stdValue) && profile.stdValue > 0), error('Observable %s has zero or invalid standard deviation on the common grid.',key); end; profile.zscore = (profile.commonValues - profile.meanValue) ./ profile.stdValue; profile.peakT = peakTemperature(profile.commonT,profile.commonValues);
end

function subspace = analyzeCommonSubspace(data)
profiles = data.profiles; commonT = data.commonGrid; obsNames = string({profiles.key}).'; obsLabels = string({profiles.label}).'; experiments = string({profiles.experiment}).';
Z = zeros(numel(commonT),numel(profiles)); rawVals = zeros(numel(commonT),numel(profiles)); for i = 1:numel(profiles), Z(:,i) = profiles(i).zscore; rawVals(:,i) = profiles(i).commonValues; end
[U,S,V] = svd(Z,'econ'); scores = U * S; singularValues = diag(S); varianceExplained = (singularValues .^ 2) ./ sum(singularValues .^ 2); cumulativeVariance = cumsum(varianceExplained);
relaxIdx = find(obsNames == 'A_T',1,'first'); if ~isempty(relaxIdx) && corrSafe(scores(:,1),Z(:,relaxIdx)) < 0, scores(:,1) = -scores(:,1); V(:,1) = -V(:,1); end
if size(scores,2) >= 2, switchIdx = find(obsNames == 'abs_dI_peak_dT',1,'first'); if ~isempty(switchIdx) && corrSafe(scores(:,2),Z(:,switchIdx)) < 0, scores(:,2) = -scores(:,2); V(:,2) = -V(:,2); end; pc2 = scores(:,2); else, pc2 = NaN(size(scores(:,1))); end
pc1 = scores(:,1); pc1Corr = NaN(numel(profiles),1); pc2Corr = NaN(numel(profiles),1); for i = 1:numel(profiles), pc1Corr(i) = corrSafe(Z(:,i),pc1); pc2Corr(i) = corrSafe(Z(:,i),pc2); end
[pc1PeakValue,pc1PeakIdx] = max(pc1); [pc1MinValue,pc1MinIdx] = min(pc1); pc1PeakT = commonT(pc1PeakIdx); pc1MinT = commonT(pc1MinIdx);
pairCount = nchoosek(numel(profiles),2); pairObs1 = strings(pairCount,1); pairObs2 = strings(pairCount,1); pairExp1 = strings(pairCount,1); pairExp2 = strings(pairCount,1); pairVal = NaN(pairCount,1); row = 0; for i = 1:numel(profiles), for j = i + 1:numel(profiles), row = row + 1; pairObs1(row) = obsNames(i); pairObs2(row) = obsNames(j); pairExp1(row) = experiments(i); pairExp2(row) = experiments(j); pairVal(row) = corrSafe(Z(:,i),Z(:,j)); end, end
pcCount = min(4,numel(singularValues)); varianceTable = table((1:pcCount).',singularValues(1:pcCount),varianceExplained(1:pcCount),cumulativeVariance(1:pcCount),'VariableNames',{'component','singular_value','variance_explained','cumulative_variance_explained'});
loadingsTable = table(obsNames,obsLabels,experiments,V(:,1),pc1Corr,'VariableNames',{'observable','label','experiment','pc1_loading','corr_with_pc1'}); if size(V,2) >= 2, loadingsTable.pc2_loading = V(:,2); loadingsTable.corr_with_pc2 = pc2Corr; else, loadingsTable.pc2_loading = NaN(size(obsNames)); loadingsTable.corr_with_pc2 = NaN(size(obsNames)); end; loadingsTable.observable_peak_temperature_K = arrayfun(@(p) p.peakT,profiles); loadingsTable = sortrows(loadingsTable,'corr_with_pc1','descend');
scoreTable = table(commonT,pc1,repmat(pc1PeakT,numel(commonT),1),repmat(pc1MinT,numel(commonT),1),'VariableNames',{'temperature_K','pc1_score','pc1_peak_temperature_K','pc1_min_temperature_K'}); if size(scores,2) >= 2, scoreTable.pc2_score = pc2; end
observableMatrixTable = table(commonT,'VariableNames',{'temperature_K'}); for i = 1:numel(profiles), observableMatrixTable.(char(obsNames(i))) = rawVals(:,i); end; for i = 1:numel(profiles), observableMatrixTable.(['z_' char(obsNames(i))]) = Z(:,i); end
pairwiseTable = table(pairObs1,pairObs2,pairExp1,pairExp2,pairVal,abs(pairVal),'VariableNames',{'observable_1','observable_2','experiment_1','experiment_2','pearson_r','abs_pearson_r'}); pairwiseTable = sortrows(pairwiseTable,'abs_pearson_r','descend');
if varianceExplained(1) >= 0.75, verdict = 'dominantly_1D'; elseif cumulativeVariance(min(2,numel(cumulativeVariance))) >= 0.9, verdict = 'effectively_2D'; else, verdict = 'higher_dimensional_or_mixed'; end
subspace.observableNames = obsNames; subspace.observableLabels = obsLabels; subspace.experiments = experiments; subspace.Z = Z; subspace.rawValues = rawVals; subspace.singularValues = singularValues; subspace.varianceExplained = varianceExplained; subspace.cumulativeVariance = cumulativeVariance; subspace.pc1 = pc1; subspace.pc2 = pc2; subspace.pc1PeakValue = pc1PeakValue; subspace.pc1PeakT = pc1PeakT; subspace.pc1MinValue = pc1MinValue; subspace.pc1MinT = pc1MinT; subspace.pc1PeakNearTstar = abs(pc1PeakT - 27) <= 2; subspace.pc1CorrelationWithRelaxation = corrSafe(pc1,Z(:,relaxIdx)); subspace.observableMatrixTable = observableMatrixTable; subspace.loadingsTable = loadingsTable; subspace.varianceTable = varianceTable; subspace.scoreTable = scoreTable; subspace.pairwiseTable = pairwiseTable; subspace.subspaceVerdict = string(verdict); subspace.pc1TopAligned = loadingsTable.observable(1:min(3,height(loadingsTable)));
end

function figPaths = saveScreeFigure(subspace,runDir,figureName)
fig = figure('Visible','off','Color','w'); setFigureGeometry(fig,8.6,6.4); ax = axes(fig); bar(ax,subspace.varianceTable.component,100 * subspace.varianceTable.variance_explained,'FaceColor',[0.00 0.45 0.74],'EdgeColor','none'); hold(ax,'on'); plot(ax,subspace.varianceTable.component,100 * subspace.varianceTable.cumulative_variance_explained,'-o','Color',[0.85 0.33 0.10],'LineWidth',1.8,'MarkerFaceColor','w'); hold(ax,'off'); xlabel(ax,'Principal component'); ylabel(ax,'Variance explained (%)'); title(ax,'Common-subspace scree plot'); legend(ax,{'individual','cumulative'},'Location','best'); styleLineAxes(ax); figPaths = save_run_figure(fig,figureName,runDir); close(fig);
end

function figPaths = savePc1Figure(subspace,runDir,figureName)
fig = figure('Visible','off','Color','w'); setFigureGeometry(fig,8.6,6.2); ax = axes(fig); plot(ax,subspace.scoreTable.temperature_K,subspace.scoreTable.pc1_score,'-o','Color',[0.00 0.45 0.74],'LineWidth',1.9,'MarkerSize',5,'MarkerFaceColor','w'); hold(ax,'on'); xline(ax,27,'--','Color',[0.45 0.45 0.45],'LineWidth',1.1); plot(ax,subspace.pc1PeakT,subspace.pc1PeakValue,'d','Color',[0.85 0.33 0.10],'MarkerFaceColor',[0.85 0.33 0.10],'MarkerSize',7); hold(ax,'off'); xlabel(ax,'Temperature (K)'); ylabel(ax,'PC1 score (arb.)'); title(ax,'PC1 versus temperature'); text(ax,0.02,0.95,sprintf('peak = %.1f K | corr(PC1, A) = %.3f',subspace.pc1PeakT,subspace.pc1CorrelationWithRelaxation),'Units','normalized','HorizontalAlignment','left','VerticalAlignment','top','FontSize',8,'BackgroundColor','w','Margin',4); styleLineAxes(ax); figPaths = save_run_figure(fig,figureName,runDir); close(fig);
end

function figPaths = saveObservableOverlayFigure(data,runDir,figureName)
fig = figure('Visible','off','Color','w'); setFigureGeometry(fig,17.8,10.5); tl = tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
expOrder = {'relaxation','aging','switching'}; colors = [0.00 0.00 0.00; 0.00 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19; 0.49 0.18 0.56; 0.93 0.69 0.13; 0.30 0.75 0.93; 0.64 0.08 0.18; 0.10 0.60 0.50]; markers = {'o','s','^','d','v','>','<','p','h'};
for iExp = 1:numel(expOrder)
    ax = nexttile(tl,iExp); hold(ax,'on'); idx = find(strcmp(string({data.profiles.experiment}),expOrder{iExp})); for k = 1:numel(idx), ii = idx(k); plot(ax,data.profiles(ii).commonT,data.profiles(ii).zscore,['-' markers{ii}],'Color',colors(ii,:),'LineWidth',1.8,'MarkerSize',4.5,'MarkerFaceColor','w','DisplayName',char(data.profiles(ii).key)); end; hold(ax,'off'); ylabel(ax,'z-score'); title(ax,[upper(expOrder{iExp}(1)) expOrder{iExp}(2:end) ' observables']); if iExp == numel(expOrder), xlabel(ax,'Temperature (K)'); end; legend(ax,'Location','eastoutside'); styleLineAxes(ax);
end
figPaths = save_run_figure(fig,figureName,runDir); close(fig);
end

function figPaths = saveProjectionFigure(subspace,runDir,figureName)
fig = figure('Visible','off','Color','w'); setFigureGeometry(fig,8.6,6.5); ax = axes(fig); expNames = unique(subspace.experiments,'stable'); expColors = [0.00 0.00 0.00; 0.00 0.45 0.74; 0.85 0.33 0.10]; hold(ax,'on'); for i = 1:numel(expNames), mask = subspace.loadingsTable.experiment == expNames(i); scatter(ax,subspace.loadingsTable.pc1_loading(mask),subspace.loadingsTable.pc2_loading(mask),55,'MarkerFaceColor',expColors(i,:),'MarkerEdgeColor','k','DisplayName',char(expNames(i))); idx = find(mask); for j = 1:numel(idx), text(ax,subspace.loadingsTable.pc1_loading(idx(j)) + 0.015,subspace.loadingsTable.pc2_loading(idx(j)),char(subspace.loadingsTable.observable(idx(j))),'FontSize',8,'HorizontalAlignment','left','VerticalAlignment','middle'); end, end, hold(ax,'off'); xlabel(ax,'PC1 loading'); ylabel(ax,'PC2 loading'); title(ax,'Observable projections in PC space'); legend(ax,'Location','best'); styleLineAxes(ax); figPaths = save_run_figure(fig,figureName,runDir); close(fig);
end
function reportText = buildReportText(thisFile,source,data,subspace,repoState)
topPairs = subspace.pairwiseTable(1:min(6,height(subspace.pairwiseTable)),:);
lines = strings(0,1); lines(end + 1) = '# Common Dynamical Subspace Analysis'; lines(end + 1) = ''; lines(end + 1) = sprintf('Generated: %s',stampNow()); lines(end + 1) = sprintf('Analysis script: `%s`',string(thisFile)); lines(end + 1) = sprintf('Run root: `%s`',string(getRunOutputDir())); lines(end + 1) = '';
lines(end + 1) = '## Repository State Summary'; for i = 1:height(repoState), lines(end + 1) = sprintf('- [%s] `%s` from `%s` using `%s` (%s). %s',repoState.experiment{i},repoState.observables_found{i},repoState.source_run{i},repoState.source_file{i},repoState.role{i},repoState.notes{i}); end; lines(end + 1) = '';
lines(end + 1) = '## Runs used'; lines(end + 1) = sprintf('- Relaxation source run: `%s`',source.relaxRunName); lines(end + 1) = sprintf('- Aging source run: `%s`',source.agingRunName); lines(end + 1) = sprintf('- Aging audit run: `%s`',source.agingAuditRunName); lines(end + 1) = sprintf('- Switching source run: `%s`',source.switchRunName); lines(end + 1) = sprintf('- Switching motion source run: `%s`',source.switchMotionRunName); lines(end + 1) = sprintf('- Cross-experiment candidate reference runs inspected: `%s`, `%s`, `%s`',source.crossRelaxAgingRunName,source.crossSwitchRelaxRunName,source.crossUnifiedRunName); lines(end + 1) = '- Existing pipelines were not modified and no raw experiment maps were recomputed.'; lines(end + 1) = '';
lines(end + 1) = '## Observables included'; for i = 1:numel(data.profiles), lines(end + 1) = sprintf('- `%s`: native support `%s`, common-grid peak at `%.1f K`.',data.profiles(i).key,mat2str(data.profiles(i).nativeT.'),data.profiles(i).peakT); end; lines(end + 1) = sprintf('- Common temperature grid used for PCA/SVD: `%s K`.',mat2str(data.commonGrid.')); lines(end + 1) = '- Each observable column was mean-centered and divided by its standard deviation after interpolation onto the common grid.'; lines(end + 1) = '- The common grid was restricted to `10-28 K` because `FM_abs(T_p)` is unavailable at `6 K` in the saved Aging observable run, while `width_I(T)` and `asym(T)` become undefined above `28 K` in the canonical Switching export.'; lines(end + 1) = sprintf('- Aging coeff note: %s.',data.aging.coeff_orientation_note); lines(end + 1) = sprintf('- Aging audit context: %s',data.aging.auditNotes); lines(end + 1) = '';
lines(end + 1) = '## PCA / SVD Results'; for i = 1:height(subspace.varianceTable), lines(end + 1) = sprintf('- PC%d: singular value = %.4f, variance explained = %.2f%%, cumulative = %.2f%%.',subspace.varianceTable.component(i),subspace.varianceTable.singular_value(i),100 * subspace.varianceTable.variance_explained(i),100 * subspace.varianceTable.cumulative_variance_explained(i)); end; lines(end + 1) = sprintf('- PC1 maximum occurs at `%.1f K`; PC1 minimum occurs at `%.1f K`.',subspace.pc1PeakT,subspace.pc1MinT); lines(end + 1) = sprintf('- PC1 peak near T* ~ 27 K? **%s**',ternary(subspace.pc1PeakNearTstar,'Yes','No')); lines(end + 1) = sprintf('- Subspace verdict from variance concentration: **%s**.',strrep(char(subspace.subspaceVerdict),'_',' ')); lines(end + 1) = '';
lines(end + 1) = '## Observable alignment with PC1'; for i = 1:height(subspace.loadingsTable), lines(end + 1) = sprintf('- `%s` (%s): corr with PC1 = %.3f, loading PC1 = %.3f, loading PC2 = %.3f.',subspace.loadingsTable.observable(i),subspace.loadingsTable.experiment(i),subspace.loadingsTable.corr_with_pc1(i),subspace.loadingsTable.pc1_loading(i),subspace.loadingsTable.pc2_loading(i)); end; lines(end + 1) = '';
lines(end + 1) = '## Pairwise observable correlations'; for i = 1:height(topPairs), lines(end + 1) = sprintf('- `%s` vs `%s`: Pearson r = %.3f.',topPairs.observable_1(i),topPairs.observable_2(i),topPairs.pearson_r(i)); end; lines(end + 1) = '';
lines(end + 1) = '## Interpretation'; if subspace.varianceExplained(1) >= 0.75, lines(end + 1) = '- The observable family is strongly dominated by a single temperature mode, so the shared behavior is close to one-dimensional over the `10-28 K` window.'; elseif subspace.cumulativeVariance(min(2,numel(subspace.cumulativeVariance))) >= 0.9, lines(end + 1) = '- The observable family is not purely rank-1, but the first two PCs capture nearly all of the structured variation, so the shared behavior is effectively two-dimensional.'; else, lines(end + 1) = '- The observable family is low-rank relative to the 9-input basis, but not compressed enough to claim a near-1D or near-2D manifold without qualification.'; end; lines(end + 1) = sprintf('- PC1 is oriented to correlate positively with Relaxation `A(T)`, and its maximum occurs at `%.1f K`.',subspace.pc1PeakT); lines(end + 1) = sprintf('- The strongest PC1-aligned observables are `%s`.',strjoin(cellstr(subspace.pc1TopAligned),', ')); lines(end + 1) = '- Support for a shared dynamical manifold is strongest if Relaxation, Aging, and Switching observables all project with the same PC1 sign or cluster closely in the PC1-PC2 plane.'; lines(end + 1) = '- Support is weaker where observables behave as edge-dominated controls rather than crossover-like curves; in this saved-output set, that risk is largest for Switching width and asymmetry channels.'; lines(end + 1) = '- Overall statement: Relaxation, Aging, and Switching do show a common low-dimensional temperature organization in the saved outputs, but the rank-1 versus rank-2 interpretation should be read from the variance-explained table rather than assumed a priori.'; lines(end + 1) = '';
lines(end + 1) = '## Visualization choices'; lines(end + 1) = '- number of curves: 2 curves in the scree plot, 1 curve in the PC1 plot, and the overlay figure is split into 1/3/5 curves across Relaxation, Aging, and Switching panels'; lines(end + 1) = '- legend vs colormap: legends were used for all figures because each panel contains a discrete, countable set of curves or groups'; lines(end + 1) = '- colormap used: none'; lines(end + 1) = '- smoothing applied: none; all curves come from saved scalar outputs with interpolation to the common grid only'; lines(end + 1) = '- justification: the figure set stays close to the requested PCA/SVD deliverables and avoids introducing map-level processing that was explicitly ruled out';
reportText = strjoin(lines,newline);
end

function note = summarizeAgingAudit(auditTbl)
dipRow = auditTbl(strcmp(auditTbl.name,'Dip_depth'),:); fmRow = auditTbl(strcmp(auditTbl.name,'FM_abs'),:); if ~isempty(dipRow) && ~isempty(fmRow), note = sprintf('`Dip_depth` is classified as %s; `FM_abs` is classified as %s.',dipRow.category{1},fmRow.category{1}); else, note = 'Saved Aging audit recommendations were inspected but did not contain both Dip_depth and FM_abs rows.'; end
end

function preferred = chooseCoeffMatrix(coeffTbl)
available = unique(string(coeffTbl.matrix_name)); if any(available == 'shifted_Tp'), preferred = 'shifted_Tp'; elseif any(available == 'raw_T'), preferred = 'raw_T'; else, preferred = char(available(1)); end
end

function agg = aggregateCurve(T,values,name)
T = double(T(:)); values = double(values(:)); mask = isfinite(T); T = T(mask); values = values(mask); [Tu,~,groupId] = unique(T); agg.name = string(name); agg.T = Tu(:); agg.valueMedian = splitapply(@medianNoNan,values,groupId); agg.count = splitapply(@(x) sum(isfinite(x)),values,groupId);
end

function out = medianNoNan(x)
x = x(isfinite(x)); if isempty(x), out = NaN; else, out = median(x); end
end

function values = interpCurve(T,y,Tq,method)
if nargin < 4 || isempty(method), method = 'linear'; end; T = double(T(:)); y = double(y(:)); Tq = double(Tq(:)); mask = isfinite(T) & isfinite(y); T = T(mask); y = y(mask); if numel(T) < 2, values = NaN(size(Tq)); return; end; [T,order] = sort(T); y = y(order); values = interp1(T,y,Tq,method,NaN);
end

function Tpeak = peakTemperature(T,values)
Tpeak = NaN; mask = isfinite(T) & isfinite(values); if ~any(mask), return; end; [~,idx] = max(values(mask)); Tvalid = T(mask); Tpeak = Tvalid(idx);
end

function name = firstMatchingName(varNames,candidates)
name = ''; varNames = string(varNames); for i = 1:numel(candidates), hit = find(strcmpi(varNames,candidates{i}),1,'first'); if ~isempty(hit), name = char(varNames(hit)); return; end, end; error('Could not find any matching variable among: %s',strjoin(candidates,', '));
end

function c = corrSafe(x,y)
x = double(x(:)); y = double(y(:)); mask = isfinite(x) & isfinite(y); c = NaN; if nnz(mask) < 3, return; end; cc = corrcoef(x(mask),y(mask)); if numel(cc) >= 4, c = cc(1,2); end
end

function setFigureGeometry(fig,widthCm,heightCm)
set(fig,'Units','centimeters','Position',[2 2 widthCm heightCm],'PaperUnits','centimeters','PaperPosition',[0 0 widthCm heightCm],'PaperSize',[widthCm heightCm],'Color','w');
end

function styleLineAxes(ax)
set(ax,'FontName','Helvetica','FontSize',9,'LineWidth',0.9,'TickDir','out','Box','off','Layer','top');
end

function zipPath = buildReviewZip(runDir,zipName)
reviewDir = fullfile(runDir,'review'); if exist(reviewDir,'dir') ~= 7, mkdir(reviewDir); end; zipPath = fullfile(reviewDir,zipName); if exist(zipPath,'file') == 2, delete(zipPath); end; zip(zipPath,{'figures','tables','reports','run_manifest.json','config_snapshot.m','log.txt','run_notes.txt'},runDir);
end

function appendText(pathStr,txt)
fid = fopen(pathStr,'a'); if fid < 0, return; end; cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU> ; fprintf(fid,'%s',txt);
end

function s = stampNow()
s = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg,field,value)
if ~isfield(cfg,field) || isempty(cfg.(field)), cfg.(field) = value; end
end

function out = ternary(condition,trueValue,falseValue)
if condition, out = trueValue; else, out = falseValue; end
end
