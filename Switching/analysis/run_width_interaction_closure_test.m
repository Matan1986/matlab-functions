clear; clc;
sp='C:\Dev\matlab-functions\Switching\analysis\run_width_interaction_closure_test.m';
oc='C:\Dev\matlab-functions\tables\width_interaction_closure_test.csv';
sc='C:\Dev\matlab-functions\tables\width_interaction_closure_test_status.csv';
rm='C:\Dev\matlab-functions\reports\width_interaction_closure_test.md';
if exist(fileparts(oc),'dir')~=7, mkdir(fileparts(oc)); end
if exist(fileparts(sc),'dir')~=7, mkdir(fileparts(sc)); end
if exist(fileparts(rm),'dir')~=7, mkdir(fileparts(rm)); end
srcp='C:\Dev\matlab-functions\results\switching\runs\_extract_run_2026_03_24_220314_residual_decomposition\run_2026_03_24_220314_residual_decomposition\tables\residual_decomposition_sources.csv';
phip='C:\Dev\matlab-functions\results\switching\runs\_extract_run_2026_03_24_220314_residual_decomposition\run_2026_03_24_220314_residual_decomposition\tables\phi_shape.csv';
kpp='C:\Dev\matlab-functions\results\switching\runs\_extract_run_2026_03_24_220314_residual_decomposition\run_2026_03_24_220314_residual_decomposition\tables\kappa_vs_T.csv';
wp='C:\Dev\matlab-functions\tables\alpha_structure.csv';
pp='C:\Dev\matlab-functions\tables\alpha_from_PT.csv';
EXECUTION_STATUS="FAIL"; INPUT_FOUND="NO"; ERROR_MESSAGE=""; N_T=0; MAIN_RESULT_SUMMARY="NOT_RUN";
WIDTH_RECONSTRUCTED_FROM_CANONICAL_PROFILE="NO"; WIDTH_INTERACTION_BETTER_THAN_ADDITIVE="NO"; WIDTH_IS_EMERGENT_FUNCTIONAL="NO";
PT_ONLY_INSUFFICIENT_FOR_WIDTH="NO"; KAPPA1_ONLY_INSUFFICIENT_FOR_WIDTH="NO";
wd='Width = FWHM at 50 percent peak by linear crossing interpolation on current axis.';
fu=strings(0,1); Ta=[]; y=[]; yobs=[]; ypt=[]; yr=[]; k1=[]; PTX=[]; PTN=strings(0,1);
rmseR=NaN; pr=NaN; sr=NaN; br=NaN; rmseP=NaN; ppP=NaN; spP=NaN; bp=NaN; rmseC=NaN; rmseA=NaN;
rows=table(strings(0,1),strings(0,1),strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),strings(0,1),...
'VariableNames',{'analysis_block','model_id','model_formula','n_rows','n_predicted','rmse','pearson','spearman','bias','delta_rmse_vs_const','notes'});
rep={'# Width interaction closure test';'';['Run script: `',sp,'`'];['Date: ',datestr(now,31)];''};
try
  need={srcp,phip,kpp,wp,pp};
  miss=strings(0,1); for i=1:numel(need), if exist(need{i},'file')~=2, miss(end+1,1)=string(need{i}); end, end
  if ~isempty(miss), error('Missing input files: %s',strjoin(miss,' | ')); end
  INPUT_FOUND="YES";
  st=readtable(srcp,'VariableNamingRule','preserve'); sv=string(st.Properties.VariableNames); sl=lower(sv);
  ir=find(contains(sl,'source_role'),1); ifl=find(contains(sl,'source_file'),1); if isempty(ir)||isempty(ifl), error('Bad source table'); end
  rr=lower(string(st{:,ir})); rf=string(st{:,ifl});
  ap=rf(find(contains(rr,'alignment'),1)); fp=rf(find(contains(rr,'full_scal'),1)); ptm=rf(find(contains(rr,'pt_matrix')|contains(rr,'pt'),1));
  if strlength(ap)==0, ap="C:\Dev\matlab-functions\results\switching\runs\run_2026_03_10_112659_alignment_audit\switching_alignment_core_data.mat"; end
  if strlength(fp)==0, fp="C:\Dev\matlab-functions\results\switching\runs\run_2026_03_12_234016_switching_full_scaling_collapse\tables\switching_full_scaling_parameters.csv"; end
  if strlength(ptm)==0, ptm="C:\Dev\matlab-functions\results\switching\runs\run_2026_03_24_212033_switching_barrier_distribution_from_map\tables\PT_matrix.csv"; end
  if exist(char(ap),'file')~=2||exist(char(fp),'file')~=2||exist(char(ptm),'file')~=2, error('Missing canonical source file'); end
  fu=[string(wp);string(pp);string(kpp);string(phip);string(srcp);string(ap);string(fp);string(ptm)];
  wt=readtable(wp,'VariableNamingRule','preserve'); pt=readtable(pp,'VariableNamingRule','preserve'); kt=readtable(kpp,'VariableNamingRule','preserve');
  ph=readtable(phip,'VariableNamingRule','preserve'); ft=readtable(char(fp),'VariableNamingRule','preserve'); pm=readtable(char(ptm),'VariableNamingRule','preserve');
  core=load(char(ap),'Smap','temps','currents');
  vw=string(wt.Properties.VariableNames); lw=lower(vw);
  iTw=find(contains(lw,'t_k')|contains(lw,'temp'),1); if isempty(iTw), iTw=find(contains(lw,'t')&strlength(lw)<=2,1); end
  iW=find(contains(lw,'width')&contains(lw,'ma'),1); if isempty(iW), iW=find(contains(lw,'width'),1); end
  vp=string(pt.Properties.VariableNames); lp=lower(vp);
  iTp=find(contains(lp,'t_k')|contains(lp,'temp'),1); if isempty(iTp), iTp=find(contains(lp,'t')&strlength(lp)<=2,1); end
  iWp=find(contains(lp,'std')&contains(lp,'pt'),1); if isempty(iWp), iWp=find(contains(lp,'width')&contains(lp,'pt'),1); end
  if isempty(iWp), iWp=find(contains(lp,'width'),1); end
  vk=string(kt.Properties.VariableNames); lk=lower(vk);
  iTk=find(contains(lk,'t_k')|contains(lk,'temp'),1); if isempty(iTk), iTk=find(contains(lk,'t')&strlength(lk)<=2,1); end
  iK=find(contains(lk,'kappa'),1);
  vf=string(ft.Properties.VariableNames); lf=lower(vf);
  iTf=find(contains(lf,'t_k')|contains(lf,'temp'),1); if isempty(iTf), iTf=find(contains(lf,'t')&strlength(lf)<=2,1); end
  iI=find(contains(lf,'ipeak')|contains(lf,'i_peak'),1); iS=find(contains(lf,'s_peak')|contains(lf,'speak'),1);
  iWf=find(contains(lf,'width_chosen'),1); if isempty(iWf), iWf=find(contains(lf,'width_fwhm'),1); end; if isempty(iWf), iWf=find(contains(lf,'width'),1); end
  vph=string(ph.Properties.VariableNames); lph=lower(vph); iX=find(contains(lph,'x'),1); iPh=find(contains(lph,'phi'),1);
  if isempty(iTw)||isempty(iW)||isempty(iTp)||isempty(iWp)||isempty(iTk)||isempty(iK)||isempty(iTf)||isempty(iI)||isempty(iS)||isempty(iWf)||isempty(iX)||isempty(iPh), error('Column detection failed'); end
  Tw=double(string(wt.(vw(iTw)))); W=double(string(wt.(vw(iW))));
  Tp=double(string(pt.(vp(iTp)))); Wp=double(string(pt.(vp(iWp))));
  Tk=double(string(kt.(vk(iTk)))); K=double(string(kt.(vk(iK))));
  Tf=double(string(ft.(vf(iTf)))); Ip=double(string(ft.(vf(iI)))); Sp=double(string(ft.(vf(iS)))); Wf=double(string(ft.(vf(iWf))));
  Xphi=double(string(ph.(vph(iX)))); Pphi=double(string(ph.(vph(iPh)))); m=isfinite(Xphi)&isfinite(Pphi); Xphi=Xphi(m); Pphi=Pphi(m); [Xphi,ox]=sort(Xphi); Pphi=Pphi(ox);
  PTN=strings(0,1); PTC=cell(0,1);
  for j=1:numel(vp)
    n=lp(j); if contains(n,'t_k')||(contains(n,'t')&&strlength(n)<=2)||contains(n,'alpha')||contains(n,'residual')||contains(n,'hat')||contains(n,'kappa')||(contains(n,'width_ma')&&~contains(n,'pt')), continue; end
    c=double(string(pt.(vp(j)))); if all(~isfinite(c)), continue; end; PTN(end+1,1)=vp(j); PTC{end+1,1}=c;
  end
  if isempty(PTN), PTN="std_threshold_mA_PT"; PTC={Wp}; end
  Smap=double(core.Smap); Tc=double(core.temps(:)); Ic=double(core.currents(:));
  if size(Smap,1)==numel(Ic)&&size(Smap,2)==numel(Tc), Smap=Smap.'; elseif ~(size(Smap,1)==numel(Tc)&&size(Smap,2)==numel(Ic)), error('Bad Smap size'); end
  [Tc,otc]=sort(Tc); [Ic,oic]=sort(Ic); Smap=Smap(otc,oic);
  vpm=string(pm.Properties.VariableNames); lpm=lower(vpm); iTm=find(contains(lpm,'t_k')|contains(lpm,'temp'),1); if isempty(iTm), iTm=find(contains(lpm,'t')&strlength(lpm)<=2,1); end; if isempty(iTm), iTm=1; end
  Tm=double(string(pm.(vpm(iTm)))); cm=true(numel(vpm),1); cm(iTm)=false; cns=vpm(cm); Ipt=NaN(numel(cns),1);
  for j=1:numel(cns)
    s=char(cns(j)); s=regexprep(s,'^Ith_','','ignorecase'); s=regexprep(s,'_mA$','','ignorecase'); s=strrep(s,'_','.'); v=str2double(s); if ~isfinite(v), mm=regexp(s,'[-+]?\d*\.?\d+','match','once'); if isempty(mm), v=NaN; else, v=str2double(mm); end, end; Ipt(j)=v;
  end
  km=isfinite(Ipt); Ipt=Ipt(km); cns=cns(km); PT=double(table2array(pm(:,cns))); [Ipt,oi]=sort(Ipt); PT=PT(:,oi);
  m=isfinite(Tw)&isfinite(W); Tw=Tw(m); W=W(m); [Tw,o]=sort(Tw); W=W(o);
  m=isfinite(Tp); Tp=Tp(m); Wp=Wp(m); [Tp,o]=sort(Tp); Wp=Wp(o); for j=1:numel(PTC), c=PTC{j}; c=c(m); c=c(o); PTC{j}=c; end
  m=isfinite(Tk)&isfinite(K); Tk=Tk(m); K=K(m); [Tk,o]=sort(Tk); K=K(o);
  m=isfinite(Tf)&isfinite(Ip)&isfinite(Sp)&isfinite(Wf); Tf=Tf(m); Ip=Ip(m); Sp=Sp(m); Wf=Wf(m); [Tf,o]=sort(Tf); Ip=Ip(o); Sp=Sp(o); Wf=Wf(o);
  m=isfinite(Tm); Tm=Tm(m); PT=PT(m,:); [Tm,o]=sort(Tm); PT=PT(o,:);
  tol=1e-9;
  for i=1:numel(Tw)
    T=Tw(i);
    ipt=find(abs(Tp-T)<=tol,1); ik=find(abs(Tk-T)<=tol,1); ifs=find(abs(Tf-T)<=tol,1); ic=find(abs(Tc-T)<=tol,1);
    if isempty(ipt)||isempty(ik)||isempty(ifs)||isempty(ic), continue; end
    wi=W(i); ki=K(ik); wpi=Wp(ipt); ii=Ip(ifs); si=Sp(ifs); wfi=Wf(ifs); ro=double(Smap(ic,:));
    if ~(isfinite(wi)&&isfinite(ki)&&isfinite(ii)&&isfinite(si)), continue; end
    p=NaN(numel(Ipt),1);
    for j=1:numel(Ipt)
      col=PT(:,j); mf=isfinite(Tm)&isfinite(col); if nnz(mf)<2, continue; end; p(j)=interp1(Tm(mf),col(mf),T,'linear',NaN);
    end
    if all(~isfinite(p)), continue; end
    p(~isfinite(p))=0; p=max(p,0); a=trapz(Ipt,p); if ~(isfinite(a)&&a>0), continue; end; p=p./a;
    pc=interp1(Ipt,p,Ic,'linear',0); pc=max(pc,0); a=trapz(Ic,pc); if ~(isfinite(a)&&a>0), continue; end; pc=pc./a;
    cdf=cumtrapz(Ic,pc); if ~(isfinite(cdf(end))&&cdf(end)>0), continue; end; cdf=cdf./cdf(end); cdf=min(max(cdf,0),1);
    rpt=si.*cdf(:)';
    wr=wpi; if ~(isfinite(wr)&&wr>0), wr=wfi; end; if ~(isfinite(wr)&&wr>0), continue; end
    xr=(Ic(:)-ii)./wr; phrow=interp1(Xphi,Pphi,xr,'linear',0); rr=rpt(:)+ki.*phrow(:);
    P=[ro(:),rpt(:),rr(:)]; ww=NaN(1,3);
    for q=1:3
      yy=P(:,q); mf=isfinite(Ic)&isfinite(yy); if nnz(mf)<4, continue; end; I=Ic(mf); S=yy(mf); [I,oi]=sort(I); S=S(oi);
      [pk,im]=max(S); if ~(isfinite(pk)&&pk>0), continue; end; h=0.5*pk; l=NaN; r=NaN;
      for j=im:-1:2
        y1=S(j-1); y2=S(j); if isfinite(y1)&&isfinite(y2)&&((y1-h)*(y2-h)<=0)&&(y2~=y1), l=I(j-1)+(h-y1)*(I(j)-I(j-1))/(y2-y1); break; end
      end
      for j=im:(numel(S)-1)
        y1=S(j); y2=S(j+1); if isfinite(y1)&&isfinite(y2)&&((y1-h)*(y2-h)<=0)&&(y2~=y1), r=I(j)+(h-y1)*(I(j+1)-I(j))/(y2-y1); break; end
      end
      if isfinite(l)&&isfinite(r)&&(r>=l), ww(q)=r-l; end
    end
    if any(~isfinite(ww)), continue; end
    px=NaN(1,numel(PTN)); for j=1:numel(PTN), c=PTC{j}; px(j)=c(ipt); end
    Ta(end+1,1)=T; y(end+1,1)=wi; yobs(end+1,1)=ww(1); ypt(end+1,1)=ww(2); yr(end+1,1)=ww(3); k1(end+1,1)=ki; PTX(end+1,:)=px;
  end
  N_T=numel(Ta); if N_T<5, error('Too few aligned rows: %d',N_T); end
  rmse_obs_profile=sqrt(mean((y-yobs).^2,'omitnan')); corr_obs_profile=corr(y,yobs,'rows','complete');
  rmseR=sqrt(mean((yr-y).^2,'omitnan')); pr=corr(y,yr,'rows','complete'); sr=corr(y,yr,'type','Spearman','rows','complete'); br=mean(yr-y,'omitnan');
  rmseP=sqrt(mean((ypt-y).^2,'omitnan')); ppP=corr(y,ypt,'rows','complete'); spP=corr(y,ypt,'type','Spearman','rows','complete'); bp=mean(ypt-y,'omitnan');
  yc=mean(y,'omitnan').*ones(size(y)); rmseC=sqrt(mean((yc-y).^2,'omitnan'));
  yhA=NaN(N_T,1); XA=[ypt,k1];
  for i=1:N_T
    tr=true(N_T,1); tr(i)=false; Xt=XA(tr,:); yt=y(tr); m=isfinite(yt)&all(isfinite(Xt),2); Xt=Xt(m,:); yt=yt(m); if numel(yt)<3, continue; end
    Z=[ones(numel(yt),1),Xt]; if rank(Z)<size(Z,2), b=pinv(Z)*yt; else, b=Z\yt; end; x=XA(i,:); if any(~isfinite(x)), continue; end; yhA(i)=[1,x]*b;
  end
  rmseA=sqrt(mean((yhA-y).^2,'omitnan')); pA=corr(y,yhA,'rows','complete'); sA=corr(y,yhA,'type','Spearman','rows','complete'); bA=mean(yhA-y,'omitnan');
  rs=NaN(numel(PTN),1);
  for j=1:numel(PTN)
    xj=PTX(:,j); yh=NaN(N_T,1);
    for i=1:N_T
      tr=true(N_T,1); tr(i)=false; xt=xj(tr); yt=y(tr); m=isfinite(xt)&isfinite(yt); xt=xt(m); yt=yt(m); if numel(yt)<2, continue; end
      Z=[ones(numel(yt),1),xt]; if rank(Z)<size(Z,2), b=pinv(Z)*yt; else, b=Z\yt; end; if ~isfinite(xj(i)), continue; end; yh(i)=[1,xj(i)]*b;
    end
    rs(j)=sqrt(mean((yh-y).^2,'omitnan'));
  end
  [~,ord]=sort(rs,'ascend'); ord=ord(isfinite(rs(ord))); if isempty(ord), ord=1; PTN="std_threshold_mA_PT"; PTX=ypt; end
  ib=ord(1); xb=PTX(:,ib); n1=PTN(ib); if numel(ord)>=2, i2=ord(2); x2=PTX(:,i2); n2=PTN(i2); else, x2=NaN(size(xb)); n2="none"; end
  x1=xb; npt2=any(isfinite(x2));
  mids=["M1_CONST";"M2_PT_BEST_SINGLE";"M3_KAPPA1";"M4_PT_BEST_PLUS_KAPPA1";"M5_PT_BEST_PLUS_KAPPA1_INTERACTION";"M6_PT1_PT2";"M7_PT1_KAPPA1_INTERACTION";"M8_PT1_PT2_KAPPA1_INTERACTIONS"];
  mfm=["w ~ const";"w ~ PT_best_single";"w ~ kappa1";"w ~ PT_best_single + kappa1";"w ~ PT_best_single + kappa1 + PT_best_single*kappa1";"w ~ PT1 + PT2";"w ~ PT1 + kappa1 + PT1*kappa1";"w ~ PT1 + PT2 + kappa1 + PT1*kappa1 + PT2*kappa1 + PT1*PT2"];
  XL=cell(8,1); XL{1}=zeros(N_T,0); XL{2}=xb; XL{3}=k1; XL{4}=[xb,k1]; XL{5}=[xb,k1,xb.*k1]; XL{6}=[x1,x2]; XL{7}=[x1,k1,x1.*k1]; XL{8}=[x1,x2,k1,x1.*k1,x2.*k1,x1.*x2];
  mr=NaN(8,1); mp=NaN(8,1); ms=NaN(8,1); mb=NaN(8,1); mn=NaN(8,1); md=NaN(8,1); nt=strings(8,1);
  for m=1:8
    X=XL{m}; p=size(X,2); if (m==6||m==8)&&~npt2, nt(m)="Skipped: PT2 unavailable"; continue; end
    yh=NaN(N_T,1);
    for i=1:N_T
      tr=true(N_T,1); tr(i)=false; yt=y(tr);
      if p>0, Xt=X(tr,:); mm=isfinite(yt)&all(isfinite(Xt),2); Xt=Xt(mm,:); yt=yt(mm); else, mm=isfinite(yt); yt=yt(mm); Xt=zeros(numel(yt),0); end
      if p==0, if ~isempty(yt), yh(i)=mean(yt,'omitnan'); end; continue; end
      if numel(yt)<p+1, continue; end; Z=[ones(numel(yt),1),Xt]; if rank(Z)<size(Z,2), b=pinv(Z)*yt; else, b=Z\yt; end
      xt=X(i,:); if any(~isfinite(xt)), continue; end; yh(i)=[1,xt]*b;
    end
    mn(m)=nnz(isfinite(yh)); mr(m)=sqrt(mean((yh-y).^2,'omitnan')); mp(m)=corr(y,yh,'rows','complete'); ms(m)=corr(y,yh,'type','Spearman','rows','complete'); mb(m)=mean(yh-y,'omitnan'); if isfinite(rmseC)&&isfinite(mr(m)), md(m)=mr(m)-rmseC; end; if strlength(nt(m))==0, nt(m)="OK"; end
  end
  rm1=mr(1); rm2=mr(2); rm3=mr(3); rm4=mr(4); rm5=mr(5);
  ptPartial="NO"; kPartial="NO"; if isfinite(rm2)&&isfinite(rm1)&&(rm2<rm1), ptPartial="YES"; end; if isfinite(rm3)&&isfinite(rm1)&&(rm3<rm1), kPartial="YES"; end
  if isfinite(rmseR)&&isfinite(rmseC)&&isfinite(pr)
    if (rmseR<=0.90*rmseC)&&(pr>=0.60), WIDTH_RECONSTRUCTED_FROM_CANONICAL_PROFILE="YES";
    elseif (rmseR<rmseC)&&(pr>=0.30), WIDTH_RECONSTRUCTED_FROM_CANONICAL_PROFILE="PARTIAL";
    else, WIDTH_RECONSTRUCTED_FROM_CANONICAL_PROFILE="NO"; end
  else, WIDTH_RECONSTRUCTED_FROM_CANONICAL_PROFILE="PARTIAL"; end
  if isfinite(rm4)&&isfinite(rm5)
    di=rm4-rm5; if di>max(0.05*rm4,1e-6), WIDTH_INTERACTION_BETTER_THAN_ADDITIVE="YES"; elseif di>1e-6, WIDTH_INTERACTION_BETTER_THAN_ADDITIVE="PARTIAL"; else, WIDTH_INTERACTION_BETTER_THAN_ADDITIVE="NO"; end
  else, WIDTH_INTERACTION_BETTER_THAN_ADDITIVE="PARTIAL"; end
  bc=min([rm4,rm5],[],'omitnan'); if ~isfinite(bc), bc=rmseA; end
  if isfinite(rmseP)&&isfinite(rmseR)&&isfinite(rm2)&&isfinite(bc)
    g1=rmseP-rmseR; g2=rm2-bc;
    if (g1>max(0.05*max(rmseR,eps),1e-6))&&(g2>max(0.05*max(bc,eps),1e-6)), PT_ONLY_INSUFFICIENT_FOR_WIDTH="YES";
    elseif (g1>1e-6)||(g2>1e-6), PT_ONLY_INSUFFICIENT_FOR_WIDTH="PARTIAL";
    else, PT_ONLY_INSUFFICIENT_FOR_WIDTH="NO"; end
  else, PT_ONLY_INSUFFICIENT_FOR_WIDTH="PARTIAL"; end
  if isfinite(rm3)&&isfinite(bc)
    g=rm3-bc; if g>max(0.05*max(bc,eps),1e-6), KAPPA1_ONLY_INSUFFICIENT_FOR_WIDTH="YES"; elseif g>1e-6, KAPPA1_ONLY_INSUFFICIENT_FOR_WIDTH="PARTIAL"; else, KAPPA1_ONLY_INSUFFICIENT_FOR_WIDTH="NO"; end
  else, KAPPA1_ONLY_INSUFFICIENT_FOR_WIDTH="PARTIAL"; end
  bs=min([rmseA,rm4,rm5],[],'omitnan');
  if isfinite(rmseR)&&isfinite(bs)
    if (rmseR<0.98*bs)&&(WIDTH_INTERACTION_BETTER_THAN_ADDITIVE=="YES")&&(PT_ONLY_INSUFFICIENT_FOR_WIDTH=="YES")&&(KAPPA1_ONLY_INSUFFICIENT_FOR_WIDTH=="YES"), WIDTH_IS_EMERGENT_FUNCTIONAL="YES";
    elseif (rmseR<=1.02*bs)&&((WIDTH_INTERACTION_BETTER_THAN_ADDITIVE=="YES")||(WIDTH_INTERACTION_BETTER_THAN_ADDITIVE=="PARTIAL")), WIDTH_IS_EMERGENT_FUNCTIONAL="PARTIAL";
    else, WIDTH_IS_EMERGENT_FUNCTIONAL="NO"; end
  else, WIDTH_IS_EMERGENT_FUNCTIONAL="PARTIAL"; end
  rows=[rows;table("direct_profile","D1_CANONICAL_PROFILE_RECON","w_recon_from_SPT_plus_kappa1_Phi1",N_T,nnz(isfinite(yr)),rmseR,pr,sr,br,rmseR-rmseC,"Compared to observed width_mA",'VariableNames',rows.Properties.VariableNames)];
  rows=[rows;table("direct_profile","D2_PT_ONLY_PROFILE","w_PT_from_SPT_profile_only",N_T,nnz(isfinite(ypt)),rmseP,ppP,spP,bp,rmseP-rmseC,"PT-only profile baseline",'VariableNames',rows.Properties.VariableNames)];
  rows=[rows;table("direct_profile","D3_CONSTANT_MEAN","w_const_mean",N_T,nnz(isfinite(yc)),rmseC,NaN,NaN,mean(yc-y,'omitnan'),0,"Constant baseline",'VariableNames',rows.Properties.VariableNames)];
  rows=[rows;table("direct_profile","D4_SCALAR_ADDITIVE_BASELINE","LOOCV: w ~ w_PT_profile + kappa1",N_T,nnz(isfinite(yhA)),rmseA,pA,sA,bA,rmseA-rmseC,"Additive scalar baseline",'VariableNames',rows.Properties.VariableNames)];
  for m=1:8
    note=nt(m); if m==2, note=note+" | PT_best_single="+n1; elseif m==6, note=note+" | PT1="+n1+" PT2="+n2; elseif m==7, note=note+" | PT1="+n1; elseif m==8, note=note+" | PT1="+n1+" PT2="+n2; end
    rows=[rows;table("loocv_regression",mids(m),mfm(m),N_T,mn(m),mr(m),mp(m),ms(m),mb(m),md(m),note,'VariableNames',rows.Properties.VariableNames)];
  end
  MAIN_RESULT_SUMMARY=sprintf('n=%d | RMSE_recon=%.6g | RMSE_const=%.6g | RMSE_PT_profile=%.6g | RMSE_M4=%.6g | RMSE_M5=%.6g',N_T,rmseR,rmseC,rmseP,rm4,rm5);
  EXECUTION_STATUS="SUCCESS";
catch ME
  EXECUTION_STATUS="FAIL"; if INPUT_FOUND=="NO", INPUT_FOUND="PARTIAL"; end; ERROR_MESSAGE=string(getReport(ME,'extended','hyperlinks','off'));
  if strlength(MAIN_RESULT_SUMMARY)==0||MAIN_RESULT_SUMMARY=="NOT_RUN", MAIN_RESULT_SUMMARY="Execution failed before full analysis. See ERROR_MESSAGE."; end
end
if height(rows)==0
  rows=[rows;table("run_status","S0_NO_RESULTS","No model rows produced",double(N_T),0,NaN,NaN,NaN,NaN,NaN,"No results generated",'VariableNames',rows.Properties.VariableNames)];
end
st=table(string(EXECUTION_STATUS),string(INPUT_FOUND),string(ERROR_MESSAGE),double(N_T),string(MAIN_RESULT_SUMMARY),...
  string(WIDTH_RECONSTRUCTED_FROM_CANONICAL_PROFILE),string(WIDTH_INTERACTION_BETTER_THAN_ADDITIVE),string(WIDTH_IS_EMERGENT_FUNCTIONAL),...
  string(PT_ONLY_INSUFFICIENT_FOR_WIDTH),string(KAPPA1_ONLY_INSUFFICIENT_FOR_WIDTH),string(wd),string(mat2str(Ta(:)',8)),string(strjoin(fu,' | ')),...
  rmseR,pr,sr,br,rmseP,ppP,spP,bp,rmseC,rmseA,rmse_obs_profile,corr_obs_profile,...
  string(ptPartial),string(kPartial),...
  'VariableNames',{'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY','WIDTH_RECONSTRUCTED_FROM_CANONICAL_PROFILE','WIDTH_INTERACTION_BETTER_THAN_ADDITIVE','WIDTH_IS_EMERGENT_FUNCTIONAL','PT_ONLY_INSUFFICIENT_FOR_WIDTH','KAPPA1_ONLY_INSUFFICIENT_FOR_WIDTH','WIDTH_DEFINITION','ALIGNED_TEMPERATURES_K','FILES_USED','RMSE_RECON','PEARSON_RECON','SPEARMAN_RECON','BIAS_RECON','RMSE_PT_PROFILE','PEARSON_PT_PROFILE','SPEARMAN_PT_PROFILE','BIAS_PT_PROFILE','RMSE_CONST','RMSE_ADDITIVE_WPT_KAPPA1','RMSE_OBSLOADED_VS_OBSPROFILE','PEARSON_OBSLOADED_VS_OBSPROFILE','PT_CARRIES_PARTIAL_INFORMATION','KAPPA1_CARRIES_PARTIAL_INFORMATION'});
try, writetable(rows,oc); catch MEw, ERROR_MESSAGE=string(ERROR_MESSAGE)+" | summary write fail: "+string(MEw.message); end
try, writetable(st,sc); catch MEw, ERROR_MESSAGE=string(ERROR_MESSAGE)+" | status write fail: "+string(MEw.message); end
rep=[rep;{'## Exact files used'}]; if isempty(fu), rep=[rep;{'- None'}]; else, for i=1:numel(fu), rep=[rep;{['- `',char(fu(i)),'`']}]; end, end; rep=[rep;{''}];
rep=[rep;{'## Alignment';['- Aligned finite rows: ',num2str(N_T)];['- Temperatures used (K): `',char(mat2str(Ta(:)',8)),'`'];''}];
rep=[rep;{'## Width definition used';['- ',wd];'- Observed target width: `width_mA` from `alpha_structure.csv`.';''}];
rep=[rep;{'## Direct reconstruction metrics';'| Quantity | RMSE | Pearson | Spearman | Bias |';'|---|---:|---:|---:|---:|';sprintf('| w_recon from S_PT + kappa1*Phi1 | %.6g | %.6g | %.6g | %.6g |',rmseR,pr,sr,br);sprintf('| w_PT from S_PT only | %.6g | %.6g | %.6g | %.6g |',rmseP,ppP,spP,bp);sprintf('| w_const mean baseline | %.6g | NaN | NaN | %.6g |',rmseC,mean(yc-y,'omitnan'));sprintf('| Scalar additive baseline (LOOCV w~w_PT+kappa1) | %.6g | %.6g | %.6g | %.6g |',rmseA,pA,sA,bA);''}];
rep=[rep;{'## Summary table of tested models';'| Model ID | Formula | RMSE | Pearson | Spearman | Delta RMSE vs const | Notes |';'|---|---|---:|---:|---:|---:|---|'}];
for i=1:height(rows), if rows.analysis_block(i)=="loocv_regression", rep=[rep;{sprintf('| %s | %s | %.6g | %.6g | %.6g | %.6g | %s |',char(rows.model_id(i)),char(rows.model_formula(i)),rows.rmse(i),rows.pearson(i),rows.spearman(i),rows.delta_rmse_vs_const(i),char(rows.notes(i)))}]; end, end
rep=[rep;{'';'## Nonlinearity and emergence diagnostics';sprintf('- Direct profile reconstruction vs scalar additive baseline: RMSE_recon=%.6g, RMSE_scalar_additive=%.6g.',rmseR,rmseA);sprintf('- Interaction model test (M5 vs M4): RMSE_M5=%.6g, RMSE_M4=%.6g.',rm5,rm4);['- PT-only carries partial information: ',char(ptPartial),'.'];['- kappa1-only carries partial information: ',char(kPartial),'.'];''}];
rep=[rep;{'## Final verdicts';['- WIDTH_RECONSTRUCTED_FROM_CANONICAL_PROFILE: **',char(WIDTH_RECONSTRUCTED_FROM_CANONICAL_PROFILE),'**'];['- WIDTH_INTERACTION_BETTER_THAN_ADDITIVE: **',char(WIDTH_INTERACTION_BETTER_THAN_ADDITIVE),'**'];['- WIDTH_IS_EMERGENT_FUNCTIONAL: **',char(WIDTH_IS_EMERGENT_FUNCTIONAL),'**'];['- PT_ONLY_INSUFFICIENT_FOR_WIDTH: **',char(PT_ONLY_INSUFFICIENT_FOR_WIDTH),'**'];['- KAPPA1_ONLY_INSUFFICIENT_FOR_WIDTH: **',char(KAPPA1_ONLY_INSUFFICIENT_FOR_WIDTH),'**'];''}];
rep=[rep;{'## Short physical interpretation';'Width is tested as a profile-level consequence of PT backbone plus a kappa1-scaled collective mode.';'If interaction and profile reconstruction outperform additive scalar baselines, width is better treated as emergent rather than separable.';'';['## Execution status: ',char(EXECUTION_STATUS)];['- Main summary: ',char(MAIN_RESULT_SUMMARY)]}];
if strlength(ERROR_MESSAGE)>0, rep=[rep;{'';'### Error message';char(ERROR_MESSAGE)}]; end
try
  fid=fopen(rm,'w'); if fid==-1, error('Cannot open report'); end
  for i=1:numel(rep), fprintf(fid,'%s\n',rep{i}); end
  fclose(fid);
catch
  if exist('fid','var')&&isnumeric(fid)&&fid>0, fclose(fid); end
end
fprintf('Wrote summary CSV: %s\n',oc); fprintf('Wrote status CSV: %s\n',sc); fprintf('Wrote report MD: %s\n',rm);
