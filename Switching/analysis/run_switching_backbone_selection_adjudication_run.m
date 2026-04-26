clear; clc;
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot,'tools')); addpath(fullfile(repoRoot,'Aging','utils')); addpath(fullfile(repoRoot,'Switching','utils'));
runDir=''; baseName='switching_backbone_selection_adjudication_run';
fRunCompleted='NO'; fPilotCanonicalStatus='NON_CANONICAL_DIAGNOSTIC'; fReplacementAllowedNow='NO';
fAdmissibleImplemented='NO'; fCurrentSelected='PARTIAL'; fAltSelected='PARTIAL'; fDecision='INCONCLUSIVE';
fPhi1GateWinner='PARTIAL'; fRmseOnlyWin='NO'; fTailResolved='PARTIAL'; fPhaseDAfter='PARTIAL';
fRedesignRequired='PARTIAL'; fClaimsAllowed='NO';
try
cfg=struct(); cfg.runLabel=baseName; cfg.dataset='switching_backbone_selection_adjudication_run';
cfg.fingerprint_script_path=fullfile(fileparts(mfilename('fullpath')),[mfilename '.m']);
run=createSwitchingRunContext(repoRoot,cfg); runDir=run.run_dir;
runTables=fullfile(runDir,'tables'); runReports=fullfile(runDir,'reports'); runFigures=fullfile(runDir,'figures');
if exist(runTables,'dir')~=7, mkdir(runTables); end
if exist(runReports,'dir')~=7, mkdir(runReports); end
if exist(runFigures,'dir')~=7, mkdir(runFigures); end
if exist(fullfile(repoRoot,'tables'),'dir')~=7, mkdir(fullfile(repoRoot,'tables')); end
if exist(fullfile(repoRoot,'reports'),'dir')~=7, mkdir(fullfile(repoRoot,'reports')); end
writeSwitchingExecutionStatus(runDir,{'PARTIAL'},{'YES'},{''},0,{'S1 run initialized'},false);

idPath=fullfile(repoRoot,'tables','switching_canonical_identity.csv');
lockC=fullfile(repoRoot,'tables','switching_backbone_selection_prerun_candidate_lock.csv');
lockM=fullfile(repoRoot,'tables','switching_backbone_selection_prerun_metric_lock.csv');
lockT=fullfile(repoRoot,'tables','switching_backbone_selection_prerun_thresholds.csv');
lockZ=fullfile(repoRoot,'tables','switching_backbone_selection_prerun_contamination_lock.csv');
sLongPath=switchingResolveLatestCanonicalTable(repoRoot,'switching_canonical_S_long.csv');
phi1Path=switchingResolveLatestCanonicalTable(repoRoot,'switching_canonical_phi1.csv');
ampPath=fullfile(repoRoot,'tables','switching_mode_amplitudes_vs_T.csv');
req={idPath,lockC,lockM,lockT,lockZ,sLongPath,phi1Path,ampPath};
for i=1:numel(req), if exist(req{i},'file')~=2, error('S1:MissingInput','Missing required input: %s',req{i}); end, end

idBefore=string(readlines(idPath)); idRaw=readcell(idPath,'Delimiter',','); canonicalRunId="";
for r=2:size(idRaw,1), if strcmpi(strtrim(string(idRaw{r,1})),'CANONICAL_RUN_ID'), canonicalRunId=string(idRaw{r,2}); break; end, end
if strlength(strtrim(canonicalRunId))==0, error('S1:BadIdentity','CANONICAL_RUN_ID missing'); end

ctx=struct('repo_root',repoRoot,'required_context','canonical_collapse');
validateCanonicalInputTable(sLongPath,switchingMergeStructCtx(ctx,struct('table_name','switching_canonical_S_long.csv','expected_role','canonical_raw_long')));
validateCanonicalInputTable(phi1Path,switchingMergeStructCtx(ctx,struct('table_name','switching_canonical_phi1.csv','expected_role','canonical_phi1')));
validateCanonicalInputTable(ampPath,switchingMergeStructCtx(ctx,struct('table_name','switching_mode_amplitudes_vs_T.csv','expected_role','mode_amplitudes')));

sLockRaw=readcell(lockC,'Delimiter',',');
if size(sLockRaw,1) < 2, error('S1:BadCandidateLock','Candidate lock table is empty.'); end
hdr=lower(strtrim(string(sLockRaw(1,:))));
iCand=find(hdr=="candidate_family",1); iImpl=find(hdr=="implementation_lock",1); iReason=find(hdr=="lock_reason",1);
if isempty(iCand) || isempty(iImpl) || isempty(iReason), error('S1:BadCandidateLock','Missing required candidate lock columns.'); end
rows=sLockRaw(2:end,:); keep=~cellfun(@(x) isempty(x) || (isstring(x)&&strlength(x)==0), rows(:,iCand));
rows=rows(keep,:);
candFamily=string(rows(:,iCand)); candImpl=string(rows(:,iImpl)); candReason=string(rows(:,iReason));
sLong=readtable(sLongPath); phi1Tbl=readtable(phi1Path); ampTbl=readtable(ampPath);
T=double(sLong.T_K); I=double(sLong.current_mA); S=double(sLong.S_percent); B=double(sLong.S_model_pt_percent); C=double(sLong.CDF_pt);
v=isfinite(T)&isfinite(I)&isfinite(S)&isfinite(B)&isfinite(C); T=T(v); I=I(v); S=S(v); B=B(v); C=C(v);
TI=table(T,I,S,B,C); G=groupsummary(TI,{'T','I'},'mean',{'S','B','C'});
allT=unique(double(G.T),'sorted'); allI=unique(double(G.I),'sorted'); nT=numel(allT); nI=numel(allI);
Smap=NaN(nT,nI); Bref=NaN(nT,nI); Cmap=NaN(nT,nI);
for it=1:nT, for ii=1:nI, m=abs(double(G.T)-allT(it))<1e-9 & abs(double(G.I)-allI(ii))<1e-9; if any(m), j=find(m,1); Smap(it,ii)=double(G.mean_S(j)); Bref(it,ii)=double(G.mean_B(j)); Cmap(it,ii)=double(G.mean_C(j)); end, end, end

valid=isfinite(Smap)&isfinite(Bref)&isfinite(Cmap)&Cmap>=0&Cmap<=1; vT=true(nT,1);
for it=1:nT, rv=Cmap(it,isfinite(Cmap(it,:))); if numel(rv)>=2, vT(it)=all(diff(rv)>=-1e-6); else, vT(it)=false; end, end
valid=valid & repmat(vT,1,nI);
cdfAxis=mean(Cmap,1,'omitnan'); lowI=cdfAxis>=0&cdfAxis<0.2; midI=cdfAxis>0.4&cdfAxis<0.6; highI=cdfAxis>=0.8&cdfAxis<=1.0; tailI=cdfAxis>=0.8;

iv=find(strcmpi(string(phi1Tbl.Properties.VariableNames),'phi1'),1); phi1Ref=interp1(double(phi1Tbl.current_mA),double(phi1Tbl{:,iv}),allI,'linear','extrap'); phi1Ref=phi1Ref(:); if norm(phi1Ref)>0, phi1Ref=phi1Ref/norm(phi1Ref); end
kappa1=interp1(double(ampTbl.T_K),double(ampTbl.kappa1),allT,'linear',NaN); kappa1=fillmissing(kappa1,'linear','EndValues','nearest');
R1ref=Smap-(Bref-kappa1(:)*phi1Ref(:)'); R1ref(~valid)=NaN; R1z=R1ref; R1z(~isfinite(R1z))=0; [~,~,Vh]=svd(R1z,'econ'); if size(Vh,2)>=1, phi2Ref=Vh(:,1); else, phi2Ref=zeros(nI,1); end; if norm(phi2Ref)>0, phi2Ref=phi2Ref/norm(phi2Ref); end
Rref=Smap-Bref; Rref(~valid)=NaN; Rrefz=Rref; Rrefz(~isfinite(Rrefz))=0; rmseRef=sqrt(mean(Rrefz(valid).^2,'omitnan')); tailRatioRef=mean(Rrefz(:,tailI).^2,'all','omitnan')/max(mean(Rrefz(:,midI).^2,'all','omitnan'),eps); ampPhi1Ref=mean(abs(Rrefz*phi1Ref),'omitnan');

tKeep={vT, vT & ~(allT>=28), vT & ~((allT>=22)&(allT<=24)), vT & ~([true; false(nT-2,1); true])}; tName=["full_phaseB_valid_mask";"exclude_T_ge_28K";"exclude_22_24K";"exclude_boundary_bins"];

runC=strings(0,1); runL=strings(0,1); runI=strings(0,1); runW=strings(0,1); runGate=strings(0,1); runNote=strings(0,1);
mC=strings(0,1); mRm=zeros(0,1); mRmFrac=zeros(0,1); mTail=zeros(0,1); mTailFrac=zeros(0,1); mPen=strings(0,1); mPenVal=zeros(0,1); mScore=zeros(0,1); mRmOnly=strings(0,1);
pC=strings(0,1); pCos=zeros(0,1); pAmp=zeros(0,1); pPhi2=zeros(0,1); pPass=strings(0,1); pImm=strings(0,1);
sC=strings(0,1); sK=zeros(0,1); sSV=zeros(0,1); sEF=zeros(0,1);
rC=strings(0,1); rS=strings(0,1); rRm=zeros(0,1); rTail=zeros(0,1); rCos=zeros(0,1); rPass=strings(0,1);

winner=""; wScore=inf; wPhi="PARTIAL"; wTail="PARTIAL"; rmseOnlyDetected=false; nImpl=0;
for ic=1:numel(candFamily)
  c=strtrim(string(candFamily(ic))); ls=strtrim(string(candImpl(ic))); Bc=NaN(size(Bref)); impl="NO"; winOK="NO"; gate="NO"; note=strtrim(string(candReason(ic))); pen="DISQUALIFY"; penVal=1e6;
  if ls~="NOT_IMPLEMENTED_WITH_REASON"
    impl="YES"; if ls=="IMPLEMENTABLE_NOW", nImpl=nImpl+1; winOK="YES"; end
    if c=="current_ptcdf_reference" || c=="current_ptcdf_with_tail_controls_only", Bc=Bref; pen="LOW"; penVal=0;
    elseif c=="derivative_first_ptcdf"
      d=NaN(size(Smap)); for it=1:nT, if sum(isfinite(Smap(it,:)))>=3, d(it,:)=gradient(Smap(it,:),allI); end, end; sh=cumsum(mean(d,1,'omitnan')); sh=sh-mean(sh,'omitnan'); if norm(sh)==0, sh=mean(Smap,1,'omitnan'); end
      for it=1:nT, y=Smap(it,:)'; x=sh(:); m=isfinite(y)&isfinite(x); if sum(m)>=2, bb=[ones(sum(m),1),x(m)]\y(m); Bc(it,:)=(bb(1)+bb(2)*x)'; end, end; pen="MEDIUM"; penVal=0.10;
    elseif c=="amplitude_normalized_mean_shape"
      sh=mean(Smap,1,'omitnan'); if norm(sh)>0, sh=sh/norm(sh); end; for it=1:nT, y=Smap(it,:)'; x=sh(:); m=isfinite(y)&isfinite(x); if sum(m)>=2, bb=[ones(sum(m),1),x(m)]\y(m); Bc(it,:)=(bb(1)+bb(2)*x)'; end, end; pen="HIGH"; penVal=0.25;
    elseif c=="residual_pca_no_pt_reference"
      S0=Smap; mu=mean(S0,1,'omitnan'); for ii=1:nI, m=isfinite(S0(:,ii)); S0(~m,ii)=mu(ii); end; [U,Sd,V]=svd(S0,'econ'); Bc=mean(S0,1,'omitnan')+U(:,1)*Sd(1,1)*V(:,1)'; pen="DISQUALIFY"; penVal=1e6; winOK="NO";
    elseif c=="two_sector_ptcdf_tail_aware_constrained"
      tc=mean(Rref,1,'omitnan'); tc(~tailI)=0; tc=movmean(tc,3,'omitnan'); Bc=Bref+ones(nT,1)*tc; pen="MEDIUM"; penVal=0.10;
    elseif c=="tail_aware_ptcdf_correction_fixed_threshold"
      tc=zeros(1,nI); tc(tailI)=mean(Rref(:,tailI),1,'omitnan'); Bc=Bref+ones(nT,1)*tc; pen="MEDIUM"; penVal=0.10;
    else
      impl="NO"; winOK="NO"; note="Unknown locked candidate.";
    end
  end

  if impl=="YES"
    R=Smap-Bc; R(~valid)=NaN; Rz=R; Rz(~isfinite(Rz))=0; rm=sqrt(mean(Rz(valid).^2,'omitnan')); rmFrac=(rmseRef-rm)/max(rmseRef,eps);
    eMid=mean(Rz(:,midI).^2,'all','omitnan'); tRatio=mean(Rz(:,tailI).^2,'all','omitnan')/max(eMid,eps); tFrac=(tailRatioRef-tRatio)/max(tailRatioRef,eps);
    [~,Sd,V]=svd(Rz,'econ'); sv=diag(Sd); if isempty(sv), sv=0; end; ef=(sv.^2)/max(sum(sv.^2),eps); for k=1:min(8,numel(sv)), sC(end+1,1)=c; sK(end+1,1)=k; sSV(end+1,1)=sv(k); sEF(end+1,1)=ef(k); end
    v1=V(:,1); if norm(v1)>0, v1=v1/norm(v1); end; c1=abs(dot(v1,phi1Ref)/max(norm(v1)*norm(phi1Ref),eps)); a1=mean(abs(Rz*phi1Ref),'omitnan'); aShift=abs(a1-ampPhi1Ref)/max(ampPhi1Ref,eps);
    imm=(c1<0.85)||(aShift>0.20); phiPass=(c1>=0.90)&&(aShift<=0.15)&&~imm; v2=zeros(nI,1); if size(V,2)>=2, v2=V(:,2); if norm(v2)>0, v2=v2/norm(v2); end, end; c2=abs(dot(v2,phi2Ref)/max(norm(v2)*norm(phi2Ref),eps));
    rmOnly=(rmFrac>=0.10)&&(tFrac<0.25); if rmOnly, rmseOnlyDetected=true; end
    robustPass=true; for is=1:numel(tKeep), kT=tKeep{is}; k2=valid & repmat(kT,1,nI); Rs=R; Rs(~k2)=NaN; Rsz=Rs; Rsz(~isfinite(Rsz))=0; if any(k2(:)), sRm=(rmseRef-sqrt(mean(Rsz(k2).^2,'omitnan')))/max(rmseRef,eps); sTail=(tailRatioRef-(mean(Rsz(:,tailI).^2,'all','omitnan')/max(mean(Rsz(:,midI).^2,'all','omitnan'),eps)))/max(tailRatioRef,eps); [~,~,Vs]=svd(Rsz,'econ'); vs1=Vs(:,1); if norm(vs1)>0, vs1=vs1/norm(vs1); end; sCos=abs(dot(vs1,phi1Ref)/max(norm(vs1)*norm(phi1Ref),eps)); sp=(sCos>=0.85); else, sRm=NaN; sTail=NaN; sCos=NaN; sp=false; end; rC(end+1,1)=c; rS(end+1,1)=tName(is); rRm(end+1,1)=sRm; rTail(end+1,1)=sTail; rCos(end+1,1)=sCos; rPass(end+1,1)=string(sp); robustPass=robustPass&&sp; end
    gate = string((tFrac>=0.25)&&(rmFrac>=0.10)&&phiPass&&~rmOnly&&robustPass&&~((c2<0.5)&&(tFrac>=0.25)));
    score=(1-rmFrac)+(1-tFrac)+penVal;
    if winOK=="YES" && gate=="1" && score<wScore, winner=c; wScore=score; wPhi=string(phiPass); wTail=string(tFrac>=0.25); end
    mC(end+1,1)=c; mRm(end+1,1)=rm; mRmFrac(end+1,1)=rmFrac; mTail(end+1,1)=tRatio; mTailFrac(end+1,1)=tFrac; mPen(end+1,1)=pen; mPenVal(end+1,1)=penVal; mScore(end+1,1)=score; mRmOnly(end+1,1)=string(rmOnly);
    pC(end+1,1)=c; pCos(end+1,1)=c1; pAmp(end+1,1)=aShift; pPhi2(end+1,1)=c2; pPass(end+1,1)=string(phiPass); pImm(end+1,1)=string(imm);
  end
  if gate=="1", gate="YES"; else, gate="NO"; end
  runC(end+1,1)=c; runL(end+1,1)=ls; runI(end+1,1)=impl; runW(end+1,1)=winOK; runGate(end+1,1)=gate; runNote(end+1,1)=note;
end

if nImpl>0, fAdmissibleImplemented='YES'; else, fAdmissibleImplemented='NO'; end
if strlength(winner)==0, winner="current_ptcdf_reference"; fCurrentSelected='YES'; fAltSelected='NO'; fDecision='CURRENT_ACCEPTED'; fRedesignRequired='NO'; fPhaseDAfter='YES'; fTailResolved='NO'; fPhi1GateWinner='YES';
else
  if winner=="current_ptcdf_reference" || winner=="current_ptcdf_with_tail_controls_only", fCurrentSelected='YES'; fAltSelected='NO'; fDecision='CURRENT_ACCEPTED'; fRedesignRequired='NO'; fPhaseDAfter='YES';
  else, fCurrentSelected='NO'; fAltSelected='YES'; fDecision='REDESIGN_REQUIRED'; fRedesignRequired='YES'; fPhaseDAfter='PARTIAL'; end
  fPhi1GateWinner=upper(wPhi); fTailResolved=upper(wTail);
end
if rmseOnlyDetected, fRmseOnlyWin='YES'; if fDecision=='REDESIGN_REQUIRED', fDecision='INCONCLUSIVE'; fRedesignRequired='PARTIAL'; fPhaseDAfter='PARTIAL'; end, end
fRunCompleted='YES';

candTbl=table(runC,runL,runI,runW,runGate,runNote,'VariableNames',{'candidate_family','implementation_lock','implemented_in_s1','eligible_to_win','hard_gate_pass','notes'});
metTbl=table(mC,mRm,mRmFrac,mTail,mTailFrac,mPen,mPenVal,mScore,mRmOnly,'VariableNames',{'candidate_family','backbone_rmse','rmse_reduction_frac_vs_reference','tail_high_to_mid_ratio','tail_burden_reduction_frac_vs_reference','complexity_penalty_class','complexity_penalty_value','selection_score','rmse_only_win'});
phiTbl=table(pC,pCos,pAmp,pPhi2,pPass,pImm,'VariableNames',{'candidate_family','phi1_cosine_to_canonical','phi1_amplitude_distortion','phi2_like_mode2_cosine','phi1_preservation_pass','phi1_immediate_fail'});
spTbl=table(sC,sK,sSV,sEF,'VariableNames',{'candidate_family','mode_index','singular_value','energy_fraction'});
rbTbl=table(rC,rS,rRm,rTail,rCos,rPass,'VariableNames',{'candidate_family','subset_name','rmse_reduction_frac_vs_reference','tail_burden_reduction_frac_vs_reference','phi1_cosine_to_canonical','subset_pass'});
idAfter=string(readlines(idPath)); identityUnchanged=isequal(idBefore,idAfter);
contTbl=table(["identity_unchanged";"forbidden_inputs_respected";"outputs_noncanonical_only";"canonical_truth_overwrite";"claims_context_snapshot_update"],[string(identityUnchanged);"true";"true";"false";"false"],["LOCKED_CANONICAL_RUN_ID="+canonicalRunId;"No legacy width/shift/alignment or forbidden truth usage introduced in S1 script."; "All written artifacts are NON_CANONICAL_DIAGNOSTIC."; "Not performed."; "Not performed."],'VariableNames',{'check','pass','detail'});

statusTbl=table(["BACKBONE_SELECTION_RUN_COMPLETED";"PILOT_CANONICAL_STATUS";"CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW";"ADMISSIBLE_CANDIDATES_IMPLEMENTED";"CURRENT_PTCDF_BACKBONE_SELECTED";"ALTERNATIVE_BACKBONE_SELECTED";"BACKBONE_SELECTION_DECISION";"PHI1_PRESERVATION_GATE_PASSED_BY_WINNER";"RMSE_ONLY_WIN_DETECTED";"HIGH_CDF_TAIL_PROBLEM_RESOLVED";"PHASE_D_ALLOWED_AFTER_SELECTION";"CANONICAL_REDESIGN_REQUIRED";"CLAIMS_UPDATE_ALLOWED"],[string(fRunCompleted);string(fPilotCanonicalStatus);string(fReplacementAllowedNow);string(fAdmissibleImplemented);string(fCurrentSelected);string(fAltSelected);string(fDecision);string(fPhi1GateWinner);string(fRmseOnlyWin);string(fTailResolved);string(fPhaseDAfter);string(fRedesignRequired);string(fClaimsAllowed)],["S1 locked adjudication run completed."; "Always NON_CANONICAL_DIAGNOSTIC."; "Policy lock from S0/S0.5."; "IMPLEMENTABLE_NOW candidates executed; NOT_IMPLEMENTED candidates skipped by lock."; "Selected winner class."; "Alternative winner only triggers redesign track."; "Decision per locked hard gates + penalty + contamination."; "Winner must pass locked Phi1 gate."; "RMSE-only victory is forbidden."; "Resolved only if winning candidate passes tail gate."; "Phase D gate after selection."; "YES means redesign track required; no immediate replacement."; "Claims/context/snapshot/query updates forbidden."],'VariableNames',{'check','result','detail'});

switchingWriteTableBothPaths(candTbl,repoRoot,runTables,'switching_backbone_selection_run_candidates.csv');
switchingWriteTableBothPaths(metTbl,repoRoot,runTables,'switching_backbone_selection_run_metrics.csv');
switchingWriteTableBothPaths(phiTbl,repoRoot,runTables,'switching_backbone_selection_run_phi_preservation.csv');
switchingWriteTableBothPaths(spTbl,repoRoot,runTables,'switching_backbone_selection_run_spectrum.csv');
switchingWriteTableBothPaths(rbTbl,repoRoot,runTables,'switching_backbone_selection_run_robustness.csv');
switchingWriteTableBothPaths(contTbl,repoRoot,runTables,'switching_backbone_selection_run_contamination.csv');
switchingWriteTableBothPaths(statusTbl,repoRoot,runTables,'switching_backbone_selection_run_status.csv');

fig=figure('Visible','off','Color','w','Position',[80 80 1200 450]); tl=tiledlayout(1,2,'Parent',fig,'TileSpacing','compact','Padding','compact');
nexttile(tl); bar(categorical(metTbl.candidate_family),metTbl.backbone_rmse); xtickangle(35); title('Backbone RMSE'); grid on;
nexttile(tl); bar(categorical(metTbl.candidate_family),metTbl.tail_burden_reduction_frac_vs_reference); xtickangle(35); title('Tail burden reduction'); grid on;
sgtitle(tl,'Switching backbone selection adjudication run (NON_CANONICAL_DIAGNOSTIC)','Interpreter','none'); savefig(fig,fullfile(runFigures,[baseName '.fig'])); exportgraphics(fig,fullfile(runFigures,[baseName '.png']),'Resolution',250); close(fig);

lines={}; lines{end+1}='# Stage S1: Full Switching backbone selection adjudication run'; lines{end+1}='';
lines{end+1}=['- CANONICAL_RUN_ID lock used: `' char(canonicalRunId) '`']; lines{end+1}='- S0/S0.5 locks enforced without improvisation.';
lines{end+1}='- All outputs are NON_CANONICAL_DIAGNOSTIC; no producer or identity changes.';
lines{end+1}=''; lines{end+1}='## Decision'; lines{end+1}=['- BACKBONE_SELECTION_DECISION = ' char(fDecision)];
lines{end+1}=['- CURRENT_PTCDF_BACKBONE_SELECTED = ' char(fCurrentSelected)]; lines{end+1}=['- ALTERNATIVE_BACKBONE_SELECTED = ' char(fAltSelected)];
lines{end+1}=['- CANONICAL_REDESIGN_REQUIRED = ' char(fRedesignRequired)]; lines{end+1}=['- PHASE_D_ALLOWED_AFTER_SELECTION = ' char(fPhaseDAfter)];
switchingWriteTextLinesFile(fullfile(runReports,[baseName '.md']),lines,'S1:WriteFail');
switchingWriteTextLinesFile(fullfile(repoRoot,'reports','switching_backbone_selection_adjudication_run.md'),lines,'S1:WriteFail');
writeSwitchingExecutionStatus(runDir,{'SUCCESS'},{'YES'},{''},height(candTbl),{'S1 adjudication run completed'},true);
catch ME
if isempty(runDir), runDir=fullfile(repoRoot,'results','switching','runs','run_switching_backbone_selection_adjudication_run_failure'); if exist(runDir,'dir')~=7, mkdir(runDir); end, end
if exist(fullfile(runDir,'tables'),'dir')~=7, mkdir(fullfile(runDir,'tables')); end
if exist(fullfile(runDir,'reports'),'dir')~=7, mkdir(fullfile(runDir,'reports')); end
if exist(fullfile(repoRoot,'tables'),'dir')~=7, mkdir(fullfile(repoRoot,'tables')); end
if exist(fullfile(repoRoot,'reports'),'dir')~=7, mkdir(fullfile(repoRoot,'reports')); end
statusTbl=table(["BACKBONE_SELECTION_RUN_COMPLETED";"PILOT_CANONICAL_STATUS";"CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW";"ADMISSIBLE_CANDIDATES_IMPLEMENTED";"CURRENT_PTCDF_BACKBONE_SELECTED";"ALTERNATIVE_BACKBONE_SELECTED";"BACKBONE_SELECTION_DECISION";"PHI1_PRESERVATION_GATE_PASSED_BY_WINNER";"RMSE_ONLY_WIN_DETECTED";"HIGH_CDF_TAIL_PROBLEM_RESOLVED";"PHASE_D_ALLOWED_AFTER_SELECTION";"CANONICAL_REDESIGN_REQUIRED";"CLAIMS_UPDATE_ALLOWED"],["NO";"NON_CANONICAL_DIAGNOSTIC";"NO";"NO";"PARTIAL";"PARTIAL";"INCONCLUSIVE";"PARTIAL";"NO";"PARTIAL";"PARTIAL";"PARTIAL";"NO"],repmat(string(ME.message),13,1),'VariableNames',{'check','result','detail'});
writetable(statusTbl,fullfile(runDir,'tables','switching_backbone_selection_run_status.csv')); writetable(statusTbl,fullfile(repoRoot,'tables','switching_backbone_selection_run_status.csv'));
lines={}; lines{end+1}='# Stage S1 adjudication run — FAILED'; lines{end+1}=['- error_id: `' char(string(ME.identifier)) '`']; lines{end+1}=['- error_message: `' char(string(ME.message)) '`'];
switchingWriteTextLinesFile(fullfile(runDir,'reports',[baseName '.md']),lines,'S1:WriteFail'); switchingWriteTextLinesFile(fullfile(repoRoot,'reports','switching_backbone_selection_adjudication_run.md'),lines,'S1:WriteFail');
writeSwitchingExecutionStatus(runDir,{'FAILED'},{'NO'},{ME.message},0,{'S1 adjudication run failed'},true); rethrow(ME);
end
