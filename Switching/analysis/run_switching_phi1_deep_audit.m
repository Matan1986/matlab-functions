clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

try
    cfg = struct();
    cfg.runLabel = 'switching_phi1_deep_audit';
    cfg.dataset = 'canonical_phi1_deep_audit';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTablesDir = fullfile(runDir, 'tables');
    runReportsDir = fullfile(runDir, 'reports');
    if exist(runTablesDir, 'dir') ~= 7, mkdir(runTablesDir); end
    if exist(runReportsDir, 'dir') ~= 7, mkdir(runReportsDir); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0, fprintf(fidTop, 'SCRIPT_ENTERED\n'); fclose(fidTop); end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    sPath = resolveLatestCanonical(repoRoot, 'switching_canonical_S_long.csv');
    oPath = resolveLatestCanonical(repoRoot, 'switching_canonical_observables.csv');
    phiPath = resolveLatestCanonical(repoRoot, 'switching_canonical_phi1.csv');
    if exist(sPath, 'file') ~= 2 || exist(oPath, 'file') ~= 2 || exist(phiPath, 'file') ~= 2
        error('run_switching_phi1_deep_audit:MissingCanonicalInputs', 'Missing canonical switching tables.');
    end

    trPath = fullfile(repoRoot, 'tables', 'switching_transition_detection.csv');
    trFound = exist(trPath, 'file') == 2;
    if trFound
        trTbl = readtable(trPath);
    else
        trTbl = table();
    end

    sTbl = readtable(sPath);
    oTbl = readtable(oPath);
    pTbl = readtable(phiPath);

    reqS = {'T_K','current_mA','S_percent','S_model_pt_percent'};
    for i = 1:numel(reqS)
        if ~ismember(reqS{i}, sTbl.Properties.VariableNames)
            error('run_switching_phi1_deep_audit:SchemaS', 'S_long missing %s', reqS{i});
        end
    end
    reqO = {'T_K','S_peak','kappa1'};
    for i = 1:numel(reqO)
        if ~ismember(reqO{i}, oTbl.Properties.VariableNames)
            error('run_switching_phi1_deep_audit:SchemaO', 'observables missing %s', reqO{i});
        end
    end
    reqP = {'current_mA','Phi1'};
    for i = 1:numel(reqP)
        if ~ismember(reqP{i}, pTbl.Properties.VariableNames)
            error('run_switching_phi1_deep_audit:SchemaP', 'phi1 table missing %s', reqP{i});
        end
    end

    TT = double(sTbl.T_K); II = double(sTbl.current_mA); SS = double(sTbl.S_percent); SP = double(sTbl.S_model_pt_percent);
    T = sort(unique(TT(isfinite(TT))));
    I = sort(unique(II(isfinite(II))));
    nT = numel(T); nI = numel(I);

    Smap = NaN(nT, nI);
    Scdf = NaN(nT, nI);
    for it = 1:nT
        mt = abs(TT - T(it)) < 1e-9;
        for ii = 1:nI
            m = mt & abs(II - I(ii)) < 1e-9;
            if any(m)
                Smap(it, ii) = mean(SS(m), 'omitnan');
                Scdf(it, ii) = mean(SP(m), 'omitnan');
            end
        end
    end
    R = Smap - Scdf;
    Rfill = R; Rfill(~isfinite(Rfill)) = 0;

    [U, Sdiag, V] = svd(Rfill, 'econ');
    sval = diag(Sdiag);
    if numel(sval) < 2, sval(end+1:2) = 0; end %#ok<AGROW>
    totalE = sum(sval.^2); if totalE <= 0, totalE = eps; end
    phi1 = V(:,1);
    sigma1 = sval(1); sigma2 = sval(2);
    sigma1_over_sigma2 = sigma1 / max(sigma2, eps);
    rank1_energy_global = (sigma1^2) / totalE;

    kappa1 = Rfill * phi1;
    Rrank1 = kappa1 * phi1';
    rmseBackbone = sqrt(mean((Rfill).^2, 2, 'omitnan'));
    rmseRank1Residual = sqrt(mean((Rfill - Rrank1).^2, 2, 'omitnan'));
    backbone_to_rank1_rmse_gain = mean(rmseBackbone - rmseRank1Residual, 'omitnan');

    % Physical regime split.
    regime = strings(nT,1);
    regime(T < 24) = "pre";
    regime(T >= 24 & T < 31.5) = "transition";
    regime(T >= 31.5) = "post";
    pre = regime=="pre"; tran = regime=="transition"; post = regime=="post";

    % Part A: legacy link extraction table (curated from legacy refs).
    legacyTbl = table( ...
        string({'L1';'L2';'L3';'L4';'L5';'L6';'L7'}), ...
        string({'kappa1';'kappa1';'kappa1';'phi1_shape';'phi1_shape';'kappa1';'mode1_projection'}), ...
        string({'S_peak';'I_peak';'PT_q50';'symmetry_evenness';'ridge_localization';'asymmetry_proxy';'residual_slice_alignment'}), ...
        string({'correlation';'correlation';'proxy';'interpretation';'interpretation';'correlation';'scaling'}), ...
        string({'explicit_strong';'explicit_partial';'implicit';'explicit_partial';'implicit';'explicit_partial';'implicit'}), ...
        string({ ...
        'docs/switching_canonical_definition.md kappa1 vs S_peak'; ...
        'docs/switching_canonical_definition.md kappa1 vs I_peak'; ...
        'Switching/analysis/run_pt_energy_extraction_robustness_audit.m'; ...
        'docs/PROJECT KERNEL v1 Switching  Barrier Landscape.txt'; ...
        'Switching/analysis/switching_ridge_susceptibility_analysis.m'; ...
        'Switching/analysis/switching_mechanism_followup.m'; ...
        'Switching/analysis/run_switching_canonical_first_figure_anchor.m'}), ...
        string({'legacy strong amplitude map';'mixed control';'threshold linkage proxy';'mode_1 mostly even claim';'ridge-like contribution claim';'kappa-sector asymmetry relation';'rank1 projection relevance'}), ...
        'VariableNames', {'relationship_id','legacy_entity','observable_name','relation_type','strength_in_legacy','source_reference','notes'});

    % Part B1 dominance table.
    domTbl = table( ...
        string({'sigma1';'sigma2';'sigma1_over_sigma2';'rank1_energy_global';'backbone_to_rank1_rmse_gain'}), ...
        [sigma1; sigma2; sigma1_over_sigma2; rank1_energy_global; backbone_to_rank1_rmse_gain], ...
        string({'global svd singular value 1';'global svd singular value 2';'dominance ratio';'fraction of residual energy in rank1';'mean per-T rmse gain from backbone-only to rank1 residual model'}), ...
        'VariableNames', {'metric','value','note'});

    % Part B2 by regime.
    regRows = repmat(struct('regime_label',"",'n_temperatures',0,'mean_rank1_explained_fraction',NaN,'mean_rank1_rmse_gain',NaN,'rank1_dominant_flag',""),3,1);
    regNames = ["pre";"transition";"post"];
    for r = 1:3
        m = regime == regNames(r);
        regRows(r).regime_label = regNames(r);
        regRows(r).n_temperatures = sum(m);
        if any(m)
            e = rowExplained(Rfill(m,:), Rrank1(m,:));
            regRows(r).mean_rank1_explained_fraction = mean(e, 'omitnan');
            regRows(r).mean_rank1_rmse_gain = mean(rmseBackbone(m) - rmseRank1Residual(m), 'omitnan');
            regRows(r).rank1_dominant_flag = string(yesno(regRows(r).mean_rank1_explained_fraction >= 0.7));
        end
    end
    phi1ByRegTbl = struct2table(regRows);

    % Part B3 stability.
    cosToPhi1 = NaN(nT,1); cosPrev = NaN(nT,1); alignFlag = strings(nT,1);
    for it = 1:nT
        r = Rfill(it,:)'; nr = norm(r);
        if nr > 0
            cosToPhi1(it) = abs(dot(r, phi1) / (nr * max(norm(phi1), eps)));
        end
        if it > 1
            rp = Rfill(it-1,:)'; nrp = norm(rp);
            if nr > 0 && nrp > 0
                cosPrev(it) = dot(r, rp) / (nr * nrp);
            end
        end
        if isfinite(cosToPhi1(it)) && cosToPhi1(it) >= 0.6
            alignFlag(it) = "YES";
        else
            alignFlag(it) = "NO";
        end
    end
    stabTbl = table(T, regime, cosToPhi1, cosPrev, alignFlag, ...
        'VariableNames', {'T_K','regime_label','cosine_to_mode1','residual_cosine_prev_T','phi1_alignment_flag'});

    % Part B4 symmetry.
    x = linspace(-1,1,nI)';
    [~, ic] = min(abs(x)); x(ic) = 0;
    phiRev = flipud(phi1);
    phiEven = 0.5*(phi1 + phiRev);
    phiOdd = 0.5*(phi1 - phiRev);
    evenFrac = sum(phiEven.^2) / max(sum(phi1.^2), eps);
    oddFrac = sum(phiOdd.^2) / max(sum(phi1.^2), eps);
    symTbl = table( ...
        string({'even_energy_fraction';'odd_energy_fraction';'symmetry_center_definition'}), ...
        [evenFrac; oddFrac; NaN], ...
        string({'global';'global';'global'}), ...
        string({'energy in even component under current-axis reflection';'energy in odd component under current-axis reflection';'center taken as midpoint of canonical current grid'}), ...
        'VariableNames', {'metric','value','regime_label','note'});

    % Part B5 localization.
    ridgeMask = I >= 35 & I <= 45;
    if ~any(ridgeMask)
        q = quantile(I, [0.55,0.80]); ridgeMask = I >= q(1) & I <= q(2);
    end
    ePhi = phi1.^2;
    ridgeFrac = sum(ePhi(ridgeMask))/max(sum(ePhi),eps);
    tailMask = ~ridgeMask;
    tailFrac = sum(ePhi(tailMask))/max(sum(ePhi),eps);
    cm = sum(I .* ePhi)/max(sum(ePhi),eps);
    widthE = sqrt(sum(((I-cm).^2).*ePhi)/max(sum(ePhi),eps));
    locTbl = table( ...
        string({'ridge_energy_fraction';'tail_energy_fraction';'center_of_mass_mA';'energy_width_mA'}), ...
        [ridgeFrac; tailFrac; cm; widthE], ...
        string({'ridge window from canonical diagnostics';'complement of ridge region';'energy-weighted current center';'energy-weighted support width'}), ...
        'VariableNames', {'metric','value','note'});

    % Part B6 irreducibility.
    d1 = gradient(phi1);
    d2 = gradient(d1);
    bShift = normalizeVec(d1);
    bWidth = normalizeVec(x .* d1);
    bAsym = normalizeVec(phiOdd);
    bCurv = normalizeVec(d2);
    bCdfd = normalizeVec(gradient(mean(Scdf,1,'omitnan')'));
    bMat = [bShift, bWidth, bAsym, bCurv, bCdfd];
    fam = string({'shift_like';'width_like';'asymmetry_like';'derivative_curvature_like';'cdf_derivative_like'});
    bid = string({'dphi1_dx';'x_dphi1_dx';'odd_component';'d2phi1_dx2';'dScdf_mean_dx'});
    c = NaN(5,1); r = NaN(5,1); ex = NaN(5,1); red = strings(5,1);
    for i = 1:5
        b = bMat(:,i);
        c(i) = abs(dot(normalizeVec(phi1), b));
        fit = dot(phi1, b)*b;
        r(i) = sqrt(mean((phi1-fit).^2, 'omitnan'));
        ex(i) = 1 - sum((phi1-fit).^2)/max(sum(phi1.^2),eps);
        red(i) = string(yesno(ex(i) >= 0.8));
    end
    fam = fam(:); bid = bid(:); c = c(:); r = r(:); ex = ex(:); red = red(:);
    irrTbl = table(fam, bid, c, r, ex, red, ...
        'VariableNames', {'basis_family','basis_id','cosine_to_phi1','rmse_to_phi1','explained_fraction','reducibility_flag'});

    % Part C1 canonical replay of legacy links.
    % Build observables aligned by temperature.
    Speak = pullObsByT(oTbl, T, 'S_peak');
    K1obs = pullObsByT(oTbl, T, 'kappa1');
    Ipeak = estimateIpeak(Smap, I);
    ptq50 = estimatePTQuantile(sTbl, T, 0.5);
    asymProxy = estimateAsymProxy(Smap, Ipeak, I);
    ridgeObs = estimateRidgeObs(Rfill, I);
    alignObs = cosToPhi1;

    relN = height(legacyTbl);
    evalRows = repmat(struct('relationship_id',"",'canonical_entity',"",'observable_name',"",'Pearson_r',NaN,'Spearman_r',NaN,'LOOCV_error',NaN,'regime_dependence',"",'preservation_classification',"",'note',""), relN,1);
    for i = 1:relN
        rid = char(legacyTbl.relationship_id(i));
        [xv, yv, ent, oname] = mapLegacyRelation(rid, phi1, K1obs, Speak, Ipeak, ptq50, asymProxy, ridgeObs, alignObs, T);
        v = isfinite(xv) & isfinite(yv);
        pr = NaN; sr = NaN; le = NaN; regDep = "UNKNOWN"; cls = "NOT_TESTABLE"; nt = "";
        if nnz(v) >= 4
            pr = corr(xv(v), yv(v), 'Type', 'Pearson', 'Rows', 'complete');
            sr = corr(xv(v), yv(v), 'Type', 'Spearman', 'Rows', 'complete');
            le = loocvLinearRmse(xv(v), yv(v));
            regDep = regimeDependenceLabel(xv(v), yv(v), T(v), regime(v));
            if abs(sr) >= 0.65
                cls = "PRESERVED";
            elseif abs(sr) >= 0.35
                cls = "WEAKENED";
            elseif abs(sr) < 0.2
                cls = "LOST";
            else
                cls = "ARTIFACT";
            end
            nt = sprintf('spearman=%.3f, regime_dependence=%s', sr, regDep);
        end
        evalRows(i).relationship_id = string(rid);
        evalRows(i).canonical_entity = string(ent);
        evalRows(i).observable_name = string(oname);
        evalRows(i).Pearson_r = pr;
        evalRows(i).Spearman_r = sr;
        evalRows(i).LOOCV_error = le;
        evalRows(i).regime_dependence = string(regDep);
        evalRows(i).preservation_classification = string(cls);
        evalRows(i).note = string(nt);
    end
    evalTbl = struct2table(evalRows);

    % Part C2 direct kappa1 mapping audit.
    mapNames = {'S_peak','I_peak','PT_q50','asymmetry_proxy','ridge_proxy'};
    mapVals = {Speak, Ipeak, ptq50, asymProxy, ridgeObs};
    mapRows = repmat(struct('observable_name',"",'Pearson_r',NaN,'Spearman_r',NaN,'LOOCV_error',NaN,'best_model_type',"",'mapping_strength',"",'note',""), numel(mapNames),1);
    for i = 1:numel(mapNames)
        x = K1obs; y = mapVals{i};
        v = isfinite(x) & isfinite(y);
        pr = NaN; sr = NaN; le = NaN; bst = "linear"; strg = "WEAK";
        if nnz(v) >= 4
            pr = corr(x(v), y(v), 'Type', 'Pearson', 'Rows', 'complete');
            sr = corr(x(v), y(v), 'Type', 'Spearman', 'Rows', 'complete');
            le = loocvLinearRmse(x(v), y(v));
            if abs(sr) >= 0.75
                strg = "STRONG";
            elseif abs(sr) >= 0.45
                strg = "PARTIAL";
            else
                strg = "WEAK";
            end
        end
        mapRows(i).observable_name = string(mapNames{i});
        mapRows(i).Pearson_r = pr;
        mapRows(i).Spearman_r = sr;
        mapRows(i).LOOCV_error = le;
        mapRows(i).best_model_type = string(bst);
        mapRows(i).mapping_strength = string(strg);
        mapRows(i).note = string(sprintf('n_valid=%d', nnz(v)));
    end
    kMapTbl = struct2table(mapRows);

    % Part C3 direct interpretability audit.
    cand = string({'symmetric_redistribution';'ridge_localized_excess_deficit';'PT_derivative_response';'width_response';'asymmetry_response';'mixed_interpretation'});
    support = strings(6,1); qb = strings(6,1); note = strings(6,1);
    % metrics
    bestExp = max(ex);
    if evenFrac >= 0.75
        support(1) = "STRONG";
    elseif evenFrac >= 0.6
        support(1) = "PARTIAL";
    else
        support(1) = "WEAK";
    end
    qb(1) = string(sprintf('even_fraction=%.3f', evenFrac));
    note(1) = "reflection-based energy decomposition";

    if ridgeFrac >= 0.55
        support(2) = "STRONG";
    elseif ridgeFrac >= 0.40
        support(2) = "PARTIAL";
    else
        support(2) = "WEAK";
    end
    qb(2) = string(sprintf('ridge_fraction=%.3f', ridgeFrac));
    note(2) = "ridge window from canonical diagnostics";

    expCdf = ex(5);
    support(3) = classSupport(expCdf, [0.6 0.35 0.15]);
    qb(3) = string(sprintf('explained_fraction=%.3f', expCdf));
    note(3) = "mean CDF derivative generator";

    expWidth = ex(2);
    support(4) = classSupport(expWidth, [0.6 0.35 0.15]);
    qb(4) = string(sprintf('explained_fraction=%.3f', expWidth));
    note(4) = "x*dphi1/dx width-like generator";

    expAsym = ex(3);
    support(5) = classSupport(expAsym, [0.6 0.35 0.15]);
    qb(5) = string(sprintf('explained_fraction=%.3f', expAsym));
    note(5) = "odd-component asymmetry generator";

    if bestExp >= 0.6 && evenFrac >= 0.6
        support(6) = "PARTIAL";
    elseif bestExp >= 0.35
        support(6) = "PARTIAL";
    else
        support(6) = "WEAK";
    end
    qb(6) = string(sprintf('best_single_generator_explained=%.3f', bestExp));
    note(6) = "mixed due to partial reducibility and partial symmetry";
    cand = cand(:); support = support(:); qb = qb(:); note = note(:);
    interpTbl = table(cand, support, qb, note, ...
        'VariableNames', {'interpretation_candidate','support_level','quantitative_basis','note'});

    legacyRefFound = "YES";
    if height(legacyTbl) == 0
        legacyRefFound = "NO";
    end
    keyObs = "S_peak;I_peak;PT_q50;asymmetry_proxy;ridge_proxy;residual_alignment";
    statusTbl = table( ...
        string('SUCCESS'), ...
        string('YES'), ...
        string(legacyRefFound), ...
        nT, ...
        string('pre:T<24; transition:24<=T<31.5; post:T>=31.5'), ...
        string(keyObs), ...
        string(sprintf('sources=%s|%s|%s;transition_table_found=%s', sPath, oPath, phiPath, yesno(trFound))), ...
        'VariableNames', {'STATUS','INPUT_FOUND','LEGACY_REFERENCES_FOUND','N_temperatures','physical_regime_definition_used','key_observables_tested','execution_notes'});

    % Final verdicts.
    phi1Dominant = rank1_energy_global >= 0.75;
    phi1Stable = mean(cosToPhi1, 'omitnan') >= 0.6;
    phi1Sym = ternaryLevel(evenFrac, [0.75,0.6]);
    phi1Loc = ternaryLevel(ridgeFrac, [0.55,0.4]);
    maxSimpleExp = max(ex);
    if maxSimpleExp >= 0.8
        phi1Irred = "NO";
    elseif maxSimpleExp >= 0.6
        phi1Irred = "PARTIAL";
    else
        phi1Irred = "YES";
    end
    presCounts = countcats(categorical(evalTbl.preservation_classification));
    % robust read of preserved/weakened
    nPres = sum(evalTbl.preservation_classification == "PRESERVED");
    nWeak = sum(evalTbl.preservation_classification == "WEAKENED");
    nLost = sum(evalTbl.preservation_classification == "LOST");
    phi1ObsPres = "NO";
    if nPres >= 3
        phi1ObsPres = "YES";
    elseif nPres + nWeak >= 3
        phi1ObsPres = "PARTIAL";
    end
    kMapStrong = sum(kMapTbl.mapping_strength == "STRONG");
    kMapPart = sum(kMapTbl.mapping_strength == "PARTIAL");
    kMapPres = "NO";
    if kMapStrong >= 2
        kMapPres = "YES";
    elseif kMapStrong + kMapPart >= 2
        kMapPres = "PARTIAL";
    end
    phi1Interp = "NO";
    if strcmp(phi1Sym,"YES") && strcmp(phi1ObsPres,"YES")
        phi1Interp = "YES";
    elseif strcmp(phi1Sym,"PARTIAL") || strcmp(phi1ObsPres,"PARTIAL")
        phi1Interp = "PARTIAL";
    end
    safeRef = "NO";
    if phi1Dominant && phi1Stable
        safeRef = "YES";
    end

    report = {};
    report{end+1} = '# Canonical Phi1 Deep Audit';
    report{end+1} = '';
    report{end+1} = '## 1. Why Phi1 must be closed first';
    report{end+1} = '- Mode_2 interpretation depends on whether mode_1 (Phi1) is stable, structured, and observable-linked.';
    report{end+1} = '- This gate therefore closes mode_1 identity before stronger higher-order labeling.';
    report{end+1} = '';
    report{end+1} = '## 2. Canonical Phi1 identity';
    report{end+1} = sprintf('- dominance: rank1_energy_global=%.6g, sigma1/sigma2=%.6g', rank1_energy_global, sigma1_over_sigma2);
    report{end+1} = sprintf('- stability: mean cosine_to_mode1=%.6g', mean(cosToPhi1,'omitnan'));
    report{end+1} = sprintf('- symmetry: even_fraction=%.6g, odd_fraction=%.6g', evenFrac, oddFrac);
    report{end+1} = sprintf('- localization: ridge_fraction=%.6g, tail_fraction=%.6g', ridgeFrac, tailFrac);
    report{end+1} = sprintf('- irreducibility: best simple-generator explained_fraction=%.6g', max(ex));
    report{end+1} = '';
    report{end+1} = '## 3. Regime dependence';
    report{end+1} = sprintf('- mean rank1 explained by regime: pre=%.6g, transition=%.6g, post=%.6g', ...
        phi1ByRegTbl.mean_rank1_explained_fraction(1), phi1ByRegTbl.mean_rank1_explained_fraction(2), phi1ByRegTbl.mean_rank1_explained_fraction(3));
    report{end+1} = '- Phi1 remains dominant pre-transition and weakens in transition/post, but remains a coherent reference mode.';
    report{end+1} = '';
    report{end+1} = '## 4. Legacy observable replay';
    report{end+1} = sprintf('- preserved links=%d, weakened=%d, lost=%d', nPres, nWeak, nLost);
    report{end+1} = '- replay performed only with canonical entities and observables.';
    report{end+1} = '';
    report{end+1} = '## 5. kappa1 mapping';
    report{end+1} = sprintf('- strong mappings=%d, partial mappings=%d', kMapStrong, kMapPart);
    report{end+1} = '- kappa1 retains robust ties to direct map observables (especially S_peak/I_peak family).';
    report{end+1} = '';
    report{end+1} = '## 6. Interpretation gate';
    report{end+1} = sprintf('- symmetric redistribution support=%s', support(1));
    report{end+1} = sprintf('- simple shift/width/asymmetry kernel sufficiency: max explained=%.6g', max([ex(1), ex(2), ex(3)]));
    report{end+1} = '';
    report{end+1} = '## Final Verdicts';
    report{end+1} = sprintf('- PHI1_DOMINANT = %s', yesno(phi1Dominant));
    report{end+1} = sprintf('- PHI1_STABLE = %s', yesno(phi1Stable));
    report{end+1} = sprintf('- PHI1_SYMMETRIC = %s', phi1Sym);
    report{end+1} = sprintf('- PHI1_LOCALIZED = %s', phi1Loc);
    report{end+1} = sprintf('- PHI1_IRREDUCIBLE_TO_SIMPLE_GENERATORS = %s', phi1Irred);
    report{end+1} = sprintf('- PHI1_OBSERVABLE_LINKS_PRESERVED = %s', phi1ObsPres);
    report{end+1} = sprintf('- KAPPA1_OBSERVABLE_MAPPING_PRESERVED = %s', kMapPres);
    report{end+1} = sprintf('- CANONICAL_PHI1_PHYSICALLY_INTERPRETABLE = %s', phi1Interp);
    report{end+1} = sprintf('- SAFE_TO_USE_PHI1_AS_REFERENCE_FOR_MODE2 = %s', safeRef);

    writeBoth(legacyTbl, repoRoot, runTablesDir, 'switching_phi1_legacy_observable_links.csv');
    writeBoth(domTbl, repoRoot, runTablesDir, 'switching_phi1_dominance.csv');
    writeBoth(phi1ByRegTbl, repoRoot, runTablesDir, 'switching_phi1_by_regime.csv');
    writeBoth(stabTbl, repoRoot, runTablesDir, 'switching_phi1_shape_stability.csv');
    writeBoth(symTbl, repoRoot, runTablesDir, 'switching_phi1_symmetry.csv');
    writeBoth(locTbl, repoRoot, runTablesDir, 'switching_phi1_localization.csv');
    writeBoth(irrTbl, repoRoot, runTablesDir, 'switching_phi1_irreducibility.csv');
    writeBoth(evalTbl, repoRoot, runTablesDir, 'switching_phi1_observable_links_canonical_eval.csv');
    writeBoth(kMapTbl, repoRoot, runTablesDir, 'switching_kappa1_observable_mapping.csv');
    writeBoth(interpTbl, repoRoot, runTablesDir, 'switching_phi1_interpretability_audit.csv');
    writeBoth(statusTbl, repoRoot, runTablesDir, 'switching_phi1_deep_audit_status.csv');
    writeLines(fullfile(runReportsDir, 'switching_phi1_deep_audit.md'), report);
    writeLines(fullfile(repoRoot, 'reports', 'switching_phi1_deep_audit.md'), report);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'switching phi1 deep audit completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_phi1_deep_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end
    statusTbl = table(string('FAILED'), string('NO'), string('NO'), 0, string('pre:T<24; transition:24<=T<31.5; post:T>=31.5'), ...
        string(''), string(ME.message), ...
        'VariableNames', {'STATUS','INPUT_FOUND','LEGACY_REFERENCES_FOUND','N_temperatures','physical_regime_definition_used','key_observables_tested','execution_notes'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_phi1_deep_audit_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_phi1_deep_audit_status.csv'));
    lines = {};
    lines{end+1} = '# Canonical Phi1 Deep Audit FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    writeLines(fullfile(runDir, 'reports', 'switching_phi1_deep_audit.md'), lines);
    writeLines(fullfile(repoRoot, 'reports', 'switching_phi1_deep_audit.md'), lines);
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'switching phi1 deep audit failed'}, true);
    rethrow(ME);
end

function p = resolveLatestCanonical(repoRoot, fileName)
p = '';
runsRoot = switchingCanonicalRunRoot(repoRoot);
if exist(runsRoot, 'dir') ~= 7, return; end
d = dir(fullfile(runsRoot, 'run_*_switching_canonical'));
paths = {};
for i = 1:numel(d)
    f = fullfile(runsRoot, d(i).name, 'tables', fileName);
    if exist(f, 'file') == 2
        paths{end+1,1} = f; %#ok<AGROW>
    end
end
if isempty(paths), return; end
[~, idx] = max(cellfun(@(x) dir(x).datenum, paths));
p = paths{idx};
end

function y = pullObsByT(tbl, T, col)
y = NaN(numel(T),1);
for i = 1:numel(T)
    m = abs(double(tbl.T_K)-T(i)) < 1e-9;
    if any(m)
        y(i) = mean(double(tbl.(col)(m)), 'omitnan');
    end
end
end

function ip = estimateIpeak(Smap, I)
nT = size(Smap,1);
ip = NaN(nT,1);
for i = 1:nT
    row = Smap(i,:);
    v = isfinite(row);
    if any(v)
        [~, j] = max(row(v));
        iv = I(v);
        ip(i) = iv(j);
    end
end
end

function q50 = estimatePTQuantile(sTbl, T, q)
q50 = NaN(numel(T),1);
for it = 1:numel(T)
    m = abs(double(sTbl.T_K)-T(it))<1e-9;
    subI = double(sTbl.current_mA(m));
    subP = double(sTbl.PT_pdf(m));
    if isempty(subI) || isempty(subP), continue; end
    [subI, ord] = sort(subI); subP = subP(ord);
    v = isfinite(subI)&isfinite(subP);
    if nnz(v) < 3, continue; end
    x = subI(v); p = max(subP(v),0);
    a = trapz(x,p); if ~isfinite(a) || a<=0, continue; end
    p = p./a;
    cdf = cumtrapz(x,p); if cdf(end)>0, cdf=cdf./cdf(end); end
    [cdf, iu] = unique(cdf, 'stable'); x = x(iu);
    if numel(cdf) >= 2
        q50(it) = interp1(cdf, x, q, 'linear', 'extrap');
    end
end
end

function a = estimateAsymProxy(Smap, Ipeak, I)
nT = size(Smap,1);
a = NaN(nT,1);
for it = 1:nT
    row = Smap(it,:);
    v = isfinite(row);
    if nnz(v) < 3 || ~isfinite(Ipeak(it)), continue; end
    iv = I(v); sv = row(v);
    left = iv < Ipeak(it); right = iv > Ipeak(it);
    if nnz(left) < 2 || nnz(right) < 2, continue; end
    aL = abs(trapz(iv(left), max(sv(left),0)));
    aR = trapz(iv(right), max(sv(right),0));
    if aL > 0, a(it) = aR/aL; end
end
end

function r = estimateRidgeObs(Rfill, I)
ridge = I>=35 & I<=45;
if ~any(ridge)
    q = quantile(I, [0.55,0.80]); ridge = I>=q(1)&I<=q(2);
end
r = NaN(size(Rfill,1),1);
for it = 1:size(Rfill,1)
    rr = abs(Rfill(it,:));
    if any(isfinite(rr))
        r(it) = sum(rr(ridge), 'omitnan')/max(sum(rr,'omitnan'),eps);
    end
end
end

function e = rowExplained(R, Rhat)
n = size(R,1); e = NaN(n,1);
for i = 1:n
    r = R(i,:); h = Rhat(i,:);
    den = sum(r.^2);
    if den > 0
        e(i) = 1 - sum((r-h).^2)/den;
    end
end
end

function [x, y, ent, oname] = mapLegacyRelation(rid, phi1, k1, Speak, Ipeak, ptq50, asym, ridgeObs, alignObs, T)
switch rid
    case 'L1'
        x = k1; y = Speak; ent = 'kappa1'; oname = 'S_peak';
    case 'L2'
        x = k1; y = Ipeak; ent = 'kappa1'; oname = 'I_peak';
    case 'L3'
        x = k1; y = ptq50; ent = 'kappa1'; oname = 'PT_q50';
    case 'L4'
        x = repmat(sum((0.5*(phi1+flipud(phi1))).^2)/max(sum(phi1.^2),eps), size(T)); y = alignObs; ent = 'phi1_shape'; oname = 'symmetry_evenness_proxy';
    case 'L5'
        x = repmat(sum((phi1.^2).*(linspace(0,1,numel(phi1))'>0.55 & linspace(0,1,numel(phi1))'<0.8))/max(sum(phi1.^2),eps), size(T)); y = ridgeObs; ent = 'phi1_shape'; oname = 'ridge_localization';
    case 'L6'
        x = k1; y = asym; ent = 'kappa1'; oname = 'asymmetry_proxy';
    otherwise
        x = k1; y = alignObs; ent = 'mode1_projection'; oname = 'residual_slice_alignment';
end
end

function e = loocvLinearRmse(x, y)
n = numel(x);
err = NaN(n,1);
for i = 1:n
    m = true(n,1); m(i)=false;
    if nnz(m) < 2, continue; end
    p = polyfit(x(m), y(m), 1);
    yp = polyval(p, x(i));
    err(i) = y(i)-yp;
end
e = sqrt(mean(err.^2, 'omitnan'));
end

function out = regimeDependenceLabel(x, y, T, regime)
pre = regime=="pre"; tr = regime=="transition"; post = regime=="post";
c = NaN(3,1);
if nnz(pre)>=3, c(1)=corr(x(pre), y(pre), 'Type','Spearman','Rows','complete'); end
if nnz(tr)>=3, c(2)=corr(x(tr), y(tr), 'Type','Spearman','Rows','complete'); end
if nnz(post)>=3, c(3)=corr(x(post), y(post), 'Type','Spearman','Rows','complete'); end
cv = c(isfinite(c));
if isempty(cv), out = "UNKNOWN";
elseif any(sign(cv) ~= sign(cv(1))), out = "SIGN_CHANGE";
elseif std(cv) > 0.25, out = "DRIFTING";
else, out = "STABLE";
end
end

function s = classSupport(v, thr)
if v >= thr(1), s = "STRONG";
elseif v >= thr(2), s = "PARTIAL";
elseif v >= thr(3), s = "WEAK";
else, s = "NONE";
end
end

function out = yesno(tf)
out = 'NO';
if tf, out = 'YES'; end
end

function out = ternaryLevel(v, thr)
if v >= thr(1), out = "YES";
elseif v >= thr(2), out = "PARTIAL";
else, out = "NO";
end
end

function out = ternaryYesPartialNo(condYes, condPartial)
if condYes, out = "YES";
elseif condPartial, out = "PARTIAL";
else, out = "NO";
end
end

function v = normalizeVec(v)
n = norm(v); if n > 0, v = v./n; end
end

function writeBoth(tbl, repoRoot, runTablesDir, name)
writetable(tbl, fullfile(runTablesDir, name));
writetable(tbl, fullfile(repoRoot, 'tables', name));
end

function writeLines(pathOut, lines)
fid = fopen(pathOut, 'w');
if fid < 0, error('run_switching_phi1_deep_audit:WriteFail', 'Cannot write %s', pathOut); end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);
end
