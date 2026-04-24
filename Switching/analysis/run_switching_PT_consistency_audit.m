clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

outLegacyName = 'switching_legacy_PT_relationships.csv';
outEvalName = 'switching_PT_relationships_canonical_eval.csv';
outClassName = 'switching_PT_relationships_classification.csv';
outStatusName = 'switching_PT_consistency_audit_status.csv';
outReportName = 'switching_PT_consistency_audit.md';

try
    cfg = struct();
    cfg.runLabel = 'switching_PT_consistency_audit';
    cfg.dataset = 'canonical_switching_tables_only';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTablesDir = fullfile(runDir, 'tables');
    runReportsDir = fullfile(runDir, 'reports');
    if exist(runTablesDir, 'dir') ~= 7
        mkdir(runTablesDir);
    end
    if exist(runReportsDir, 'dir') ~= 7
        mkdir(runReportsDir);
    end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'tables'));
    end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'reports'));
    end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0
        fprintf(fidTop, 'SCRIPT_ENTERED\n');
        fclose(fidTop);
    end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    legacyTbl = table( ...
        string({'R1'; 'R2'; 'R3'; 'R4'; 'R5'; 'R6'}), ...
        string({ ...
        'Activation-like local Arrhenius relation using S_peak(T) in low/mid T windows'; ...
        'Residual-amplitude coordinate kappa tracks switching amplitude S_peak'; ...
        'Residual-amplitude coordinate kappa co-varies with structural current scale I_peak'; ...
        'Asymmetry-like descriptors correlate with residual-sector amplitude (kappa sector coupling)'; ...
        'Barrier-distribution spread/asymmetry grows with high-T broadening and mismatch'; ...
        'PT mean-threshold / median-threshold tracks switching ridge position (I_peak)'}), ...
        string({'S_peak'; 'kappa1'; 'kappa1'; 'kappa1'; 'PT_spread_q90_q50'; 'PT_q50'}), ...
        string({'invT'; 'S_peak'; 'I_peak'; 'PT_asymmetry'; 'RMSE_backbone'; 'I_peak'}), ...
        string({'linear_in_log_space'; 'monotonic_positive'; 'monotonic_positive'; 'monotonic_coupling'; 'monotonic_positive'; 'monotonic_positive'}), ...
        string({'4-30 K (windowed)'; 'all T, crossover near 22-24 K'; 'all T, crossover near 22-24 K'; '4-30 K'; 'high T emphasis (~24-30 K)'; 'all T'}), ...
        string({ ...
        'Switching/analysis/switching_mechanism_followup.m (local Arrhenius section)'; ...
        'docs/switching_canonical_definition.md (kappa1 vs S_peak evidence block)'; ...
        'docs/switching_canonical_definition.md (kappa1 vs I_peak evidence block)'; ...
        'docs/PROJECT KERNEL v1 Switching  Barrier Landscape.txt (asymmetry-kappa note)'; ...
        'docs/PROJECT KERNEL v1 Switching  Barrier Landscape.txt (width problem/high-T broadening narrative)'; ...
        'Switching/analysis/run_pt_energy_extraction_robustness_audit.m + switching_energy_mapping_analysis.m (threshold-energy mapping usage)'}), ...
        'VariableNames', {'relationship_id', 'description', 'variable_1', 'variable_2', 'expected_relation', 'T_range', 'source_reference'});

    runsRoot = switchingCanonicalRunRoot(repoRoot);
    sCandidates = {};
    oCandidates = {};
    if exist(runsRoot, 'dir') == 7
        runDirs = dir(fullfile(runsRoot, 'run_*_switching_canonical'));
        for iRun = 1:numel(runDirs)
            tDir = fullfile(runsRoot, runDirs(iRun).name, 'tables');
            sPath = fullfile(tDir, 'switching_canonical_S_long.csv');
            oPath = fullfile(tDir, 'switching_canonical_observables.csv');
            if exist(sPath, 'file') == 2 && exist(oPath, 'file') == 2
                sCandidates{end+1, 1} = sPath; %#ok<AGROW>
                oCandidates{end+1, 1} = oPath; %#ok<AGROW>
            end
        end
    end

    inputFound = ~isempty(sCandidates);
    if inputFound
        [~, idxNewest] = max(cellfun(@(p) dir(p).datenum, sCandidates));
        fileS = sCandidates{idxNewest};
        fileO = oCandidates{idxNewest};
        sourcePath = fileS;
    else
        fileS = '';
        fileO = '';
        sourcePath = '';
    end

    evalTbl = table();
    classTbl = table();
    finalVerdict = struct();

    if inputFound
        tblS = readtable(fileS);
        tblO = readtable(fileO);

        colT = findColumnContains(tblS, {'t_k'});
        colI = findColumnContains(tblS, {'current', 'ma'});
        colS = findColumnContains(tblS, {'s_percent'});
        colScdf = findColumnContains(tblS, {'s_model_pt_percent'});
        colPt = findColumnContains(tblS, {'pt_pdf'});
        if isempty(colT) || isempty(colI) || isempty(colS) || isempty(colScdf) || isempty(colPt)
            error('run_switching_PT_consistency_audit:MissingSLongColumns', 'Required canonical columns were not found in S_long.');
        end

        colOT = findColumnContains(tblO, {'t_k'});
        colOSpeak = findColumnContains(tblO, {'s_peak'});
        colOKappa = findColumnContains(tblO, {'kappa1'});
        if isempty(colOT) || isempty(colOSpeak) || isempty(colOKappa)
            error('run_switching_PT_consistency_audit:MissingObsColumns', 'Required canonical columns were not found in observables.');
        end

        Traw = double(tblS.(colT));
        Iraw = double(tblS.(colI));
        Sraw = double(tblS.(colS));
        ScdfRaw = double(tblS.(colScdf));
        Ptraw = double(tblS.(colPt));

        temps = unique(Traw(isfinite(Traw)));
        temps = sort(temps(:));
        nT = numel(temps);

        q10 = NaN(nT, 1); q25 = NaN(nT, 1); q50 = NaN(nT, 1); q75 = NaN(nT, 1); q90 = NaN(nT, 1);
        ptSpread9050 = NaN(nT, 1); ptSpread7525 = NaN(nT, 1); ptAsym = NaN(nT, 1); meanI = NaN(nT, 1);
        Ipeak = NaN(nT, 1); Speak = NaN(nT, 1); rmseBackbone = NaN(nT, 1); ridgePos = NaN(nT, 1);
        ridgeSlope = NaN(nT, 1); collapseQuality = NaN(nT, 1);
        kappa1 = NaN(nT, 1);

        for it = 1:nT
            t = temps(it);
            m = abs(Traw - t) < 1e-9;
            cur = Iraw(m);
            sig = Sraw(m);
            spt = ScdfRaw(m);
            p = Ptraw(m);

            [cur, idx] = sort(cur);
            sig = sig(idx);
            spt = spt(idx);
            p = p(idx);

            v = isfinite(cur) & isfinite(p);
            curv = cur(v);
            pv = p(v);
            pv = max(pv, 0);
            if numel(curv) >= 3
                a = trapz(curv, pv);
                if isfinite(a) && a > 0
                    pv = pv ./ a;
                    cdf = cumtrapz(curv, pv);
                    if cdf(end) > 0
                        cdf = cdf ./ cdf(end);
                    end
                    q10(it) = interpQuantile(curv, cdf, 0.10);
                    q25(it) = interpQuantile(curv, cdf, 0.25);
                    q50(it) = interpQuantile(curv, cdf, 0.50);
                    q75(it) = interpQuantile(curv, cdf, 0.75);
                    q90(it) = interpQuantile(curv, cdf, 0.90);
                    meanI(it) = trapz(curv, pv .* curv);
                end
            end
            if isfinite(q90(it)) && isfinite(q50(it))
                ptSpread9050(it) = q90(it) - q50(it);
            end
            if isfinite(q75(it)) && isfinite(q25(it))
                ptSpread7525(it) = q75(it) - q25(it);
            end
            if isfinite(q90(it)) && isfinite(q50(it)) && isfinite(q10(it))
                den = max(q90(it) - q10(it), eps);
                ptAsym(it) = ((q90(it) - q50(it)) - (q50(it) - q10(it))) / den;
            end

            vs = isfinite(cur) & isfinite(sig);
            if any(vs)
                [Speak(it), j] = max(sig(vs));
                curS = cur(vs);
                Ipeak(it) = curS(j);
            end
            vb = isfinite(sig) & isfinite(spt);
            if any(vb)
                d = sig(vb) - spt(vb);
                rmseBackbone(it) = sqrt(mean(d.^2, 'omitnan'));
                collapseQuality(it) = rmseBackbone(it);
                [~, j2] = max(abs(d));
                curB = cur(vb);
                ridgePos(it) = curB(j2);
            end

            mo = abs(double(tblO.(colOT)) - t) < 1e-9;
            if any(mo)
                kappa1(it) = mean(double(tblO.(colOKappa)(mo)), 'omitnan');
                if ~isfinite(Speak(it))
                    Speak(it) = mean(double(tblO.(colOSpeak)(mo)), 'omitnan');
                end
            end
        end

        vI = isfinite(temps) & isfinite(Ipeak);
        if nnz(vI) >= 2
            ridgeSlope(vI) = gradient(Ipeak(vI), temps(vI));
        end

        evalRows = repmat(struct('relationship_id', "", 'Pearson_r', NaN, 'Spearman_r', NaN, ...
            'LOOCV_error', NaN, 'stability_flag', "", 'T_dependence_pattern', ""), height(legacyTbl), 1);
        classRows = repmat(struct('relationship_id', "", 'classification', "", 'justification', "", ...
            'sensitivity_to_representation', "", 'linked_to_residual', "", 'linked_to_transition', ""), height(legacyTbl), 1);

        for iR = 1:height(legacyTbl)
            rid = char(legacyTbl.relationship_id(iR));
            [x, y] = mapRelationshipVariables(rid, temps, Speak, kappa1, Ipeak, ptAsym, ptSpread9050, q50, rmseBackbone);
            v = isfinite(x) & isfinite(y);

            pr = NaN; sr = NaN; loo = NaN; stable = "NO"; patt = "INSUFFICIENT";
            cls = "LOST"; sens = "HIGH"; just = "";
            linkedResidual = "NO"; linkedTransition = "NO";

            if nnz(v) >= 4
                xv = x(v); yv = y(v); tv = temps(v);
                pr = corr(xv, yv, 'Type', 'Pearson', 'Rows', 'complete');
                sr = corr(xv, yv, 'Type', 'Spearman', 'Rows', 'complete');
                loo = loocvLinearRmse(xv, yv);

                patt = relationPattern(xv, yv, tv);
                stable = "YES";
                if strcmp(patt, 'SIGN_FLIP') || strcmp(patt, 'UNSTABLE')
                    stable = "NO";
                end

                if abs(sr) >= 0.65 && stable == "YES"
                    cls = "PRESERVED";
                    sens = "LOW";
                    just = sprintf('Strong canonical correlation (Spearman=%.3f) with stable trend.', sr);
                elseif abs(sr) >= 0.35
                    cls = "WEAKENED";
                    sens = "MED";
                    just = sprintf('Signal remains but is reduced/less stable (Spearman=%.3f).', sr);
                elseif abs(sr) < 0.2 && stable == "YES"
                    cls = "LOST";
                    sens = "HIGH";
                    just = sprintf('No robust canonical signal (Spearman=%.3f).', sr);
                else
                    cls = "ARTIFACT";
                    sens = "HIGH";
                    just = sprintf('Inconsistent canonical behavior (%s, Spearman=%.3f).', patt, sr);
                end

                predRes = linearResidualAbs(xv, yv);
                rmseLocal = rmseBackbone(v);
                m2 = isfinite(predRes) & isfinite(rmseLocal);
                if nnz(m2) >= 4
                    cr = corr(predRes(m2), rmseLocal(m2), 'Type', 'Spearman', 'Rows', 'complete');
                    if isfinite(cr) && abs(cr) >= 0.4
                        linkedResidual = "YES";
                    end
                end
                lowM = tv <= 22;
                highM = tv >= 24 & tv <= 30;
                if any(lowM) && any(highM)
                    if mean(predRes(highM), 'omitnan') > 1.25 * mean(predRes(lowM), 'omitnan')
                        linkedTransition = "YES";
                    end
                end
            else
                just = 'Insufficient valid temperature points in canonical data for reliable test.';
                cls = "ARTIFACT";
                sens = "HIGH";
            end

            evalRows(iR).relationship_id = string(rid);
            evalRows(iR).Pearson_r = pr;
            evalRows(iR).Spearman_r = sr;
            evalRows(iR).LOOCV_error = loo;
            evalRows(iR).stability_flag = stable;
            evalRows(iR).T_dependence_pattern = string(patt);

            classRows(iR).relationship_id = string(rid);
            classRows(iR).classification = string(cls);
            classRows(iR).justification = string(just);
            classRows(iR).sensitivity_to_representation = string(sens);
            classRows(iR).linked_to_residual = string(linkedResidual);
            classRows(iR).linked_to_transition = string(linkedTransition);
        end

        evalTbl = struct2table(evalRows);
        classTbl = struct2table(classRows);

        nPres = sum(classTbl.classification == "PRESERVED");
        nWeak = sum(classTbl.classification == "WEAKENED");
        nLost = sum(classTbl.classification == "LOST");
        nArt = sum(classTbl.classification == "ARTIFACT");
        nRel = height(classTbl);

        ptPreserved = "NO";
        if nPres >= max(1, ceil(0.6 * nRel))
            ptPreserved = "YES";
        elseif (nPres + nWeak) >= max(1, ceil(0.5 * nRel))
            ptPreserved = "PARTIAL";
        else
            ptPreserved = "NO";
        end

        losesPhysical = "NO";
        if nLost + nArt >= ceil(0.4 * nRel)
            losesPhysical = "YES";
        end
        lostLikelyArtifacts = "NO";
        if nLost > 0
            lostLinked = sum((classTbl.classification == "LOST" | classTbl.classification == "ARTIFACT") & classTbl.linked_to_residual == "YES");
            if lostLinked < ceil(0.5 * (nLost + nArt))
                lostLikelyArtifacts = "YES";
            end
        else
            lostLikelyArtifacts = "YES";
        end
        ptShouldInformBackbone = "NO";
        if losesPhysical == "YES" && lostLikelyArtifacts == "NO"
            ptShouldInformBackbone = "YES";
        end
        safeProceed = "YES";
        if losesPhysical == "YES" && lostLikelyArtifacts == "NO"
            safeProceed = "NO";
        end

        finalVerdict.PT_RELATIONSHIPS_PRESERVED = ptPreserved;
        finalVerdict.CANONICAL_REPRESENTATION_LOSES_PHYSICAL_INFORMATION = losesPhysical;
        finalVerdict.LOST_RELATIONSHIPS_LIKELY_ARTIFACTS = lostLikelyArtifacts;
        finalVerdict.PT_SHOULD_INFORM_BACKBONE = ptShouldInformBackbone;
        finalVerdict.SAFE_TO_PROCEED_WITH_CURRENT_CANONICAL_MODEL = safeProceed;

        reportLines = {};
        reportLines{end+1} = '# Canonical vs Literature/PT Consistency Audit';
        reportLines{end+1} = '';
        reportLines{end+1} = '## 1. Summary of Legacy PT-Based Interpretations';
        reportLines{end+1} = '';
        for i = 1:height(legacyTbl)
            reportLines{end+1} = sprintf('- %s: %s [%s vs %s, expected=%s, source=%s]', ...
                legacyTbl.relationship_id(i), legacyTbl.description(i), legacyTbl.variable_1(i), legacyTbl.variable_2(i), ...
                legacyTbl.expected_relation(i), legacyTbl.source_reference(i));
        end
        reportLines{end+1} = '';
        reportLines{end+1} = '## 2. Canonical Evaluation';
        reportLines{end+1} = '';
        reportLines{end+1} = sprintf('- PRESERVED count: %d', nPres);
        reportLines{end+1} = sprintf('- WEAKENED count: %d', nWeak);
        reportLines{end+1} = sprintf('- LOST count: %d', nLost);
        reportLines{end+1} = sprintf('- ARTIFACT count: %d', nArt);
        reportLines{end+1} = '';
        reportLines{end+1} = '## 3. Interpretation';
        reportLines{end+1} = '';
        reportLines{end+1} = sprintf('- Lost/inconsistent relations classified as likely artifacts: %s', finalVerdict.LOST_RELATIONSHIPS_LIKELY_ARTIFACTS);
        reportLines{end+1} = '- Canonicalization effect interpreted from relationship-level stability + LOOCV + residual linkage.';
        reportLines{end+1} = '';
        reportLines{end+1} = '## 4. Residual Connection';
        reportLines{end+1} = '';
        reportLines{end+1} = sprintf('- relationships linked_to_residual=YES: %d', sum(classTbl.linked_to_residual == "YES"));
        reportLines{end+1} = sprintf('- relationships linked_to_transition=YES: %d', sum(classTbl.linked_to_transition == "YES"));
        reportLines{end+1} = '';
        reportLines{end+1} = '## Final Verdicts';
        reportLines{end+1} = '';
        reportLines{end+1} = sprintf('- PT_RELATIONSHIPS_PRESERVED = %s', finalVerdict.PT_RELATIONSHIPS_PRESERVED);
        reportLines{end+1} = sprintf('- CANONICAL_REPRESENTATION_LOSES_PHYSICAL_INFORMATION = %s', finalVerdict.CANONICAL_REPRESENTATION_LOSES_PHYSICAL_INFORMATION);
        reportLines{end+1} = sprintf('- LOST_RELATIONSHIPS_LIKELY_ARTIFACTS = %s', finalVerdict.LOST_RELATIONSHIPS_LIKELY_ARTIFACTS);
        reportLines{end+1} = sprintf('- PT_SHOULD_INFORM_BACKBONE = %s', finalVerdict.PT_SHOULD_INFORM_BACKBONE);
        reportLines{end+1} = sprintf('- SAFE_TO_PROCEED_WITH_CURRENT_CANONICAL_MODEL = %s', finalVerdict.SAFE_TO_PROCEED_WITH_CURRENT_CANONICAL_MODEL);
        reportLines{end+1} = '';
        reportLines{end+1} = sprintf('- canonical_source: %s', sourcePath);
    else
        evalTbl = table(string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), string.empty(0,1), string.empty(0,1), ...
            'VariableNames', {'relationship_id', 'Pearson_r', 'Spearman_r', 'LOOCV_error', 'stability_flag', 'T_dependence_pattern'});
        classTbl = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
            'VariableNames', {'relationship_id', 'classification', 'justification', 'sensitivity_to_representation', 'linked_to_residual', 'linked_to_transition'});
        finalVerdict.PT_RELATIONSHIPS_PRESERVED = "NO";
        finalVerdict.CANONICAL_REPRESENTATION_LOSES_PHYSICAL_INFORMATION = "NO";
        finalVerdict.LOST_RELATIONSHIPS_LIKELY_ARTIFACTS = "YES";
        finalVerdict.PT_SHOULD_INFORM_BACKBONE = "NO";
        finalVerdict.SAFE_TO_PROCEED_WITH_CURRENT_CANONICAL_MODEL = "NO";

        reportLines = {};
        reportLines{end+1} = '# Canonical vs Literature/PT Consistency Audit';
        reportLines{end+1} = '';
        reportLines{end+1} = '- Canonical source tables were not found; outputs written in empty/fallback mode.';
        reportLines{end+1} = '';
        reportLines{end+1} = '## Final Verdicts';
        reportLines{end+1} = '- PT_RELATIONSHIPS_PRESERVED = NO';
        reportLines{end+1} = '- CANONICAL_REPRESENTATION_LOSES_PHYSICAL_INFORMATION = NO';
        reportLines{end+1} = '- LOST_RELATIONSHIPS_LIKELY_ARTIFACTS = YES';
        reportLines{end+1} = '- PT_SHOULD_INFORM_BACKBONE = NO';
        reportLines{end+1} = '- SAFE_TO_PROCEED_WITH_CURRENT_CANONICAL_MODEL = NO';
    end

    statusTbl = table( ...
        string('SUCCESS'), ...
        height(legacyTbl), ...
        string(sprintf('INPUT_FOUND=%s;SOURCE=%s', yesno(inputFound), sourcePath)), ...
        'VariableNames', {'STATUS', 'N_relationships', 'data_integrity_checks'});

    writetable(legacyTbl, fullfile(runTablesDir, outLegacyName));
    writetable(evalTbl, fullfile(runTablesDir, outEvalName));
    writetable(classTbl, fullfile(runTablesDir, outClassName));
    writetable(statusTbl, fullfile(runTablesDir, outStatusName));

    writetable(legacyTbl, fullfile(repoRoot, 'tables', outLegacyName));
    writetable(evalTbl, fullfile(repoRoot, 'tables', outEvalName));
    writetable(classTbl, fullfile(repoRoot, 'tables', outClassName));
    writetable(statusTbl, fullfile(repoRoot, 'tables', outStatusName));

    writeLines(fullfile(runReportsDir, outReportName), reportLines);
    writeLines(fullfile(repoRoot, 'reports', outReportName), reportLines);

    inFoundStr = 'NO';
    if inputFound
        inFoundStr = 'YES';
    end
    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {inFoundStr}, {''}, height(evalTbl), {'switching PT consistency audit completed'}, true);

    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0
        fprintf(fidBottom, 'SCRIPT_COMPLETED\n');
        fclose(fidBottom);
    end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_PT_consistency_audit_failure');
        if exist(runDir, 'dir') ~= 7
            mkdir(runDir);
        end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7
        mkdir(fullfile(runDir, 'tables'));
    end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7
        mkdir(fullfile(runDir, 'reports'));
    end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'tables'));
    end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'reports'));
    end

    legacyTbl = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
        'VariableNames', {'relationship_id', 'description', 'variable_1', 'variable_2', 'expected_relation', 'T_range', 'source_reference'});
    evalTbl = table(string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), string.empty(0,1), string.empty(0,1), ...
        'VariableNames', {'relationship_id', 'Pearson_r', 'Spearman_r', 'LOOCV_error', 'stability_flag', 'T_dependence_pattern'});
    classTbl = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
        'VariableNames', {'relationship_id', 'classification', 'justification', 'sensitivity_to_representation', 'linked_to_residual', 'linked_to_transition'});
    statusTbl = table(string('FAILED'), 0, string(ME.message), 'VariableNames', {'STATUS', 'N_relationships', 'data_integrity_checks'});

    writetable(legacyTbl, fullfile(runDir, 'tables', outLegacyName));
    writetable(evalTbl, fullfile(runDir, 'tables', outEvalName));
    writetable(classTbl, fullfile(runDir, 'tables', outClassName));
    writetable(statusTbl, fullfile(runDir, 'tables', outStatusName));
    writetable(legacyTbl, fullfile(repoRoot, 'tables', outLegacyName));
    writetable(evalTbl, fullfile(repoRoot, 'tables', outEvalName));
    writetable(classTbl, fullfile(repoRoot, 'tables', outClassName));
    writetable(statusTbl, fullfile(repoRoot, 'tables', outStatusName));

    failLines = {};
    failLines{end+1} = '# Canonical vs Literature/PT Consistency Audit FAILED';
    failLines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    failLines{end+1} = sprintf('- error_message: `%s`', ME.message);
    failLines{end+1} = '- PT_RELATIONSHIPS_PRESERVED = NO';
    failLines{end+1} = '- CANONICAL_REPRESENTATION_LOSES_PHYSICAL_INFORMATION = NO';
    failLines{end+1} = '- LOST_RELATIONSHIPS_LIKELY_ARTIFACTS = YES';
    failLines{end+1} = '- PT_SHOULD_INFORM_BACKBONE = NO';
    failLines{end+1} = '- SAFE_TO_PROCEED_WITH_CURRENT_CANONICAL_MODEL = NO';
    writeLines(fullfile(runDir, 'reports', outReportName), failLines);
    writeLines(fullfile(repoRoot, 'reports', outReportName), failLines);

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'switching PT consistency audit failed'}, true);
    rethrow(ME);
end

function c = findColumnContains(tbl, keys)
names = string(tbl.Properties.VariableNames);
c = '';
for i = 1:numel(names)
    n = lower(char(names(i)));
    ok = true;
    for k = 1:numel(keys)
        if ~contains(n, lower(keys{k}))
            ok = false;
            break;
        end
    end
    if ok
        c = char(names(i));
        return;
    end
end
end

function q = interpQuantile(x, cdf, p)
q = NaN;
if numel(x) < 2
    return;
end
v = isfinite(x) & isfinite(cdf);
if nnz(v) < 2
    return;
end
xv = x(v);
cv = cdf(v);
[cv, iu] = unique(cv, 'stable');
xv = xv(iu);
if numel(cv) < 2
    return;
end
q = interp1(cv, xv, p, 'linear', 'extrap');
end

function [x, y] = mapRelationshipVariables(rid, temps, Speak, kappa1, Ipeak, ptAsym, ptSpread9050, q50, rmseBackbone)
switch rid
    case 'R1'
        x = 1 ./ temps;
        y = log(max(Speak, eps));
    case 'R2'
        x = Speak;
        y = kappa1;
    case 'R3'
        x = Ipeak;
        y = kappa1;
    case 'R4'
        x = ptAsym;
        y = kappa1;
    case 'R5'
        x = ptSpread9050;
        y = rmseBackbone;
    case 'R6'
        x = q50;
        y = Ipeak;
    otherwise
        x = NaN(size(temps));
        y = NaN(size(temps));
end
end

function e = loocvLinearRmse(x, y)
n = numel(x);
errs = NaN(n, 1);
for i = 1:n
    tr = true(n, 1);
    tr(i) = false;
    if nnz(tr) < 2
        continue;
    end
    p = polyfit(x(tr), y(tr), 1);
    yp = polyval(p, x(i));
    errs(i) = y(i) - yp;
end
e = sqrt(mean(errs.^2, 'omitnan'));
end

function patt = relationPattern(x, y, t)
patt = 'CONSISTENT';
low = t <= 22;
mid = t > 22 & t < 26;
high = t >= 26;
s = NaN(3, 1);
if nnz(low) >= 3
    s(1) = corr(x(low), y(low), 'Type', 'Spearman', 'Rows', 'complete');
end
if nnz(mid) >= 3
    s(2) = corr(x(mid), y(mid), 'Type', 'Spearman', 'Rows', 'complete');
end
if nnz(high) >= 3
    s(3) = corr(x(high), y(high), 'Type', 'Spearman', 'Rows', 'complete');
end
sv = s(isfinite(s));
if isempty(sv)
    patt = 'INSUFFICIENT';
    return;
end
if any(sign(sv) ~= sign(sv(1)))
    patt = 'SIGN_FLIP';
elseif std(sv) > 0.35
    patt = 'UNSTABLE';
elseif abs(mean(sv)) < 0.2
    patt = 'WEAK';
else
    patt = 'CONSISTENT';
end
end

function r = linearResidualAbs(x, y)
r = NaN(size(x));
if numel(x) < 3
    return;
end
p = polyfit(x, y, 1);
yh = polyval(p, x);
r = abs(y - yh);
end

function s = yesno(tf)
s = 'NO';
if tf
    s = 'YES';
end
end

function writeLines(pathOut, lines)
fid = fopen(pathOut, 'w');
if fid < 0
    error('run_switching_PT_consistency_audit:WriteFail', 'Cannot write file: %s', pathOut);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);
end
