fprintf('[RUN] run_phi2_shape_physics_test\n');
clearvars;
repoRoot = 'C:/Dev/matlab-functions';
analysisDir = fullfile(repoRoot, 'Switching', 'analysis');
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
errorLogPath = fullfile(repoRoot, 'matlab_error.log');
metricsPath = fullfile(tablesDir, 'phi2_structure_metrics.csv');
kernelPath = fullfile(tablesDir, 'phi2_kernel_comparison.csv');
regimePath = fullfile(tablesDir, 'phi2_regime_stability.csv');
reportPath = fullfile(reportsDir, 'run_phi2_shape_physics_test.md');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end
metricsTbl = table(NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, {'NA'}, 'VariableNames', {'phi2_even_energy_fraction','phi2_odd_energy_fraction','phi2_center_energy_frac_abs_x_le_cut','phi2_center_energy_frac_abs_x_le_tight','phi2_rms_x_weighted','phi2_cusp_ratio_center_d2','phi2_shoulder_tail_ratio_R_over_L','phi2_zero_crossings','phi2_osc_score','phi2_loo_cosine_min','phi2_loo_cosine_mean','phi2_loo_cosine_std','phi2_best_kernel_abs_corr','phi2_best_kernel_name'});
kernTbl = table({'NA'}, NaN, NaN, 'VariableNames', {'kernel','pearson_corr_vs_phi2','rmse_vs_phi2'});
regimeTbl = table({'NA'}, NaN, 'VariableNames', {'temperature_regime','cosine_to_full_phi2'});
try
addpath(genpath(fullfile(repoRoot, 'Aging'))); addpath(fullfile(repoRoot, 'tools')); addpath(fullfile(repoRoot, 'tools', 'figures')); addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin'); addpath(analysisDir, '-begin');
cfg = phi2_shape_helpers('apply_defaults', struct());
decCfg = struct('runLabel',cfg.runLabel,'alignmentRunId',cfg.alignmentRunId,'fullScalingRunId',cfg.fullScalingRunId,'ptRunId',cfg.ptRunId,'canonicalMaxTemperatureK',cfg.canonicalMaxTemperatureK,'nXGrid',cfg.nXGrid,'fallbackSmoothWindow',cfg.fallbackSmoothWindow,'skipFigures',true);
outDec = switching_residual_decomposition_analysis(decCfg);
xGrid = outDec.xGrid(:); phi1 = outDec.phi(:); phi2 = outDec.phi2; if isempty(phi2), error('run_phi2_shape_physics_test:Phi2Missing','Phi2 missing.'); end; phi2 = phi2(:); Rlow = outDec.Rall(outDec.lowTemperatureMask,:); tempsLow = outDec.temperaturesK(outDec.lowTemperatureMask);
[evenFrac,~] = phi2_shape_helpers('even_part',xGrid,phi2); oddVec = phi2_shape_helpers('odd_part',xGrid,phi2); oddFrac = phi2_shape_helpers('odd_fraction',phi2,oddVec);
centerMask = abs(xGrid) <= cfg.localizationRadiusX; centerMaskTight = abs(xGrid) <= cfg.localizationRadiusTightX; eTot = sum(phi2.^2,'omitnan'); eCenter = sum((phi2(centerMask & isfinite(phi2))).^2,'omitnan'); eCenterTight = sum((phi2(centerMaskTight & isfinite(phi2))).^2,'omitnan'); centerEnergyFrac = eCenter/max(eTot,eps); centerEnergyFracTight = eCenterTight/max(eTot,eps); sx2 = sum((xGrid.^2).*(phi2.^2),'omitnan')/max(eTot,eps); rmsX = sqrt(max(sx2,0));
d2phi2 = gradient(gradient(phi2(:),xGrid(:)),xGrid(:)); absd2 = abs(d2phi2); [~,i0] = min(abs(xGrid)); cuspRatio = absd2(i0)/max(mean(absd2,'omitnan'),eps); denL = phi2_shape_helpers('mean_abs',phi2,xGrid < -cfg.tailRadiusX); denR = phi2_shape_helpers('mean_abs',phi2,xGrid > cfg.tailRadiusX); if ~(isfinite(denL) && denL > eps), shoulderRatio = NaN; else, shoulderRatio = denR/denL; end; nCross = phi2_shape_helpers('zero_crossings',phi2(:),xGrid(:)); oscScore = nCross/max(numel(xGrid)/10,1);
phi2n = phi2_shape_helpers('zero_mean_unit_l2',phi2); dPhi1 = gradient(phi1(:),xGrid(:)); sigmaG = cfg.gaussianSigmaX; kernelNames = {'dPhi1_dx';'gaussian_bump';'antisymmetric_bump';'width_modulation_x_phi1'}; kernels = {phi2_shape_helpers('zero_mean_unit_l2',dPhi1); phi2_shape_helpers('zero_mean_unit_l2',exp(-0.5*(xGrid./sigmaG).^2)); phi2_shape_helpers('zero_mean_unit_l2',xGrid.*exp(-0.5*(xGrid./sigmaG).^2)); phi2_shape_helpers('zero_mean_unit_l2',xGrid.*phi1(:))}; corrK = NaN(1,numel(kernels)); rmseK = NaN(1,numel(kernels)); for j=1:numel(kernels), corrK(j)=phi2_shape_helpers('safe_corr',phi2n,kernels{j}); rmseK(j)=phi2_shape_helpers('rmse',phi2n,kernels{j}); end; [~,jBest] = max(abs(corrK),[],'omitnan');
looCos = phi2_shape_helpers('loo_phi2_cosine',Rlow,phi2); looMin = min(looCos,[],'omitnan'); looMean = mean(looCos,'omitnan'); looStd = std(looCos,'omitnan'); regimeNames = {'T_le_20K';'T_14_to_26K';'T_ge_22K'}; regimeMasks = {tempsLow <= 20; tempsLow >= 14 & tempsLow <= 26; tempsLow >= 22}; regimeCos = NaN(numel(regimeNames),1); for ri=1:numel(regimeNames), if nnz(regimeMasks{ri}) >= cfg.minRowsForPhi2, v2 = phi2_shape_helpers('phi2_from_r',Rlow(regimeMasks{ri},:)); if ~isempty(v2), regimeCos(ri) = phi2_shape_helpers('cosine_sim',phi2_shape_helpers('zero_mean_unit_l2',v2),phi2n); end; end; end
metricsTbl = table(evenFrac,oddFrac,centerEnergyFrac,centerEnergyFracTight,rmsX,cuspRatio,shoulderRatio,nCross,oscScore,looMin,looMean,looStd,abs(corrK(jBest)),{char(kernelNames{jBest})},'VariableNames',metricsTbl.Properties.VariableNames); kernTbl = table(kernelNames(:),corrK(:),rmseK(:),'VariableNames',{'kernel','pearson_corr_vs_phi2','rmse_vs_phi2'}); regimeTbl = table(regimeNames(:),regimeCos,'VariableNames',{'temperature_regime','cosine_to_full_phi2'});
writetable(metricsTbl,metricsPath); writetable(kernTbl,kernelPath); writetable(regimeTbl,regimePath); fid=fopen(reportPath,'w'); fprintf(fid,'SUCCESS\n'); fclose(fid);
catch ME
fid=fopen(errorLogPath,'a'); if fid ~= -1, fprintf(fid,'%s\n',getReport(ME)); fclose(fid); end
try, writetable(metricsTbl,metricsPath); writetable(kernTbl,kernelPath); writetable(regimeTbl,regimePath); catch, end
fid=fopen(reportPath,'w'); if fid ~= -1, fprintf(fid,'FAIL\n'); fclose(fid); end
end
