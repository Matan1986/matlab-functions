function result = query_system(query_name)
% query_system
%   Main entrypoint for simple human/agent queries over existing run evidence.
%
% Supported queries (initial simple version):
%   - 'coordinate_selection'
%   - 'residual_validity'
%   - 'PT_vs_relaxation'
%   - 'list_all_runs'
%
% Notes:
%   - This function never recomputes metrics; it only loads existing CSVs.
%   - Snapshot evidence edges are used as a seed when available.

if nargin < 1 || isempty(query_name)
    error('query_system requires query_name.');
end

query_name = string(query_name);
q = lower(strtrim(query_name));

switch q
    case "list_all_runs"
        out = list_all_runs();
        result = struct();
        result.query_name = query_name;
        result.all_runs = out;
        return;
end

repoRoot = resolveRepoRoot();

% Load registry (for fallback and for listing experiments/paths)
registryPath = fullfile(repoRoot, 'analysis', 'knowledge', 'run_registry.csv');
regTable = readtable(registryPath, 'Delimiter', ',', 'TextType', 'string');
regTable.run_id = string(regTable.run_id);
regTable.experiment = string(regTable.experiment);
regTable.run_rel_path = string(regTable.run_rel_path);

% Load context bundle (for claim intent / textual summary)
externalContextPath = 'C:\Dev\matlab-functions_context\context_bundle.json';
repoContextPath     = fullfile(repoRoot, 'docs', 'context_bundle.json');

if isfile(externalContextPath)
    contextPath = externalContextPath;
    contextSource = 'EXTERNAL';
elseif isfile(repoContextPath)
    contextPath = repoContextPath;
    contextSource = 'REPO_FALLBACK';
else
    error('No context file found');
end

fprintf('Context source: %s\n', contextSource);
ctx = read_json_file(contextPath);

% Load snapshot indexes (control-plane mapping)
snapshotClaimEdgesPath = fullfile(repoRoot, 'snapshot_scientific_v3', '70_evidence_index', 'evidence_edges_claim_to_run.jsonl');
snapshotAnalysisRegistryPath = fullfile(repoRoot, 'snapshot_scientific_v3', '40_analysis_catalog', 'analysis_registry.json');
snapshotClaimIndexPath = fullfile(repoRoot, 'snapshot_scientific_v3', '60_claims_surveys', 'claim_index.json');

claimIndex = read_json_file(snapshotClaimIndexPath);
analysisRegistry = read_json_file(snapshotAnalysisRegistryPath);
claimEdges = load_jsonl_struct(snapshotClaimEdgesPath);

% Interpret query_name -> seed claims
seedClaimIds = strings(0);
switch q
    case "coordinate_selection"
        seedClaimIds = strings({'X_canonical_coordinate','X_peak_alignment','X_adversarial_robustness'});
    case "residual_validity"
        seedClaimIds = strings({'X_scaling_relation','X_pareto_nondominated','X_broad_basin'});
    case "pt_vs_relaxation"
        seedClaimIds = strings({'X_not_temperature_reparameterization'});
    otherwise
        error('Unsupported query_name: %s', query_name);
end

seedClaimIds = seedClaimIds(seedClaimIds ~= "");
seedClaimIds = intersect(seedClaimIds, strings({ctx.claims.claim_id}));

% Seed run IDs using snapshot claim->run edges
seedRunIds = strings(0);
edgeClaimIds = strings({claimEdges.claim_id});
edgeRunIds = strings({claimEdges.run_id});
for i = 1:numel(seedClaimIds)
    cid = seedClaimIds(i);
    mask = edgeClaimIds == cid;
    seedRunIds = union(seedRunIds, edgeRunIds(mask));
end

% Fallback selection from registry (keyword-based, still grounded in query intent)
fallbackPatterns = strings(0);
switch q
    case "coordinate_selection"
        fallbackPatterns = strings({'coordinate','alternative_coordinate','phi_physical_identification','phi_even_deformation','phi_pt_independence'});
    case "residual_validity"
        fallbackPatterns = strings({'residual','residual_decomposition','residual_sector','reconstruction_quality','decomposition_quality'});
    case "pt_vs_relaxation"
        fallbackPatterns = strings({'pt_to_phi_prediction','pt_energy','pt_deformation_mode','pt_energy_robustness','barrier_to_relaxation_mechanism','pt_width_spread_observable'});
end

mask = false(height(regTable), 1);
for i = 1:numel(fallbackPatterns)
    mask = mask | contains(lower(regTable.run_id), lower(fallbackPatterns(i)));
end
fallbackRunIds = regTable.run_id(mask);
% Keep fallback bounded to avoid excessive CSV loading
fallbackRunIds = unique(fallbackRunIds, 'stable');
fallbackRunIds = fallbackRunIds(1:min(numel(fallbackRunIds), 40));

candidateRunIds = unique([seedRunIds; fallbackRunIds], 'stable');

% Load metrics (no recomputation)
run_id_list = strings(0);
exp_list = strings(0);
path_list = strings(0);
metric_source_list = strings(0);
rmse_list = nan(0,1);
corr_list = nan(0,1);
spearman_list = nan(0,1);
rank1_energy_fraction_list = nan(0,1);
score_list = nan(0,1);

for i = 1:numel(candidateRunIds)
    rid = candidateRunIds(i);
    if rid == "" || rid == missing
        continue;
    end

    evidence = load_run_evidence(rid);
    if strlength(evidence.path) == 0
        continue;
    end

    metrics = extract_metrics_from_evidence(evidence, q);
    if isempty(metrics)
        continue;
    end

    run_id_list(end+1, 1) = rid; %#ok<AGROW>
    exp_list(end+1, 1) = string(regTable.experiment(regTable.run_id == rid)); %#ok<AGROW>
    path_list(end+1, 1) = string(evidence.path); %#ok<AGROW>
    metric_source_list(end+1, 1) = string(metrics.metric_source); %#ok<AGROW>
    rmse_list(end+1, 1) = metrics.rmse; %#ok<AGROW>
    corr_list(end+1, 1) = metrics.corr; %#ok<AGROW>
    if isfield(metrics, 'spearman') && ~isempty(metrics.spearman)
        spearman_list(end+1, 1) = metrics.spearman; %#ok<AGROW>
    else
        spearman_list(end+1, 1) = NaN; %#ok<AGROW>
    end
    if isfield(metrics, 'rank1_energy_fraction') && ~isempty(metrics.rank1_energy_fraction)
        rank1_energy_fraction_list(end+1, 1) = metrics.rank1_energy_fraction; %#ok<AGROW>
    else
        rank1_energy_fraction_list(end+1, 1) = NaN; %#ok<AGROW>
    end
    score_list(end+1, 1) = metrics.score; %#ok<AGROW>
end

if isempty(run_id_list)
    result = struct();
    result.query_name = query_name;
    result.seed_claim_ids = seedClaimIds;
    result.seed_run_ids = seedRunIds;
    result.found_runs = table();
    result.summary = sprintf('No local metrics found for query: %s', query_name);
    return;
end

runRows = table();
runRows.run_id = run_id_list;
runRows.experiment = exp_list;
runRows.run_path = path_list;
runRows.metric_source = metric_source_list;
runRows.rmse = rmse_list;
runRows.corr = corr_list;
runRows.spearman = spearman_list;
runRows.rank1_energy_fraction = rank1_energy_fraction_list;
runRows.score = score_list;

% Rank
runRows = sortrows(runRows, 'score', 'descend');
runRows.rank = (1:height(runRows)).';

% Build textual summary
summaryParts = strings(0);
for i = 1:numel(seedClaimIds)
    cid = seedClaimIds(i);
    ctxMask = strings({ctx.claims.claim_id}) == cid;
    if any(ctxMask)
        c = ctx.claims(find(ctxMask, 1, 'first'));
        summaryParts(end+1) = sprintf('%s (%s, %s): %s', c.claim_id, c.status, c.confidence, c.statement); %#ok<AGROW>
    else
        summaryParts(end+1) = sprintf('%s: (no statement in context bundle)', cid); %#ok<AGROW>
    end
end
summaryText = strjoin(summaryParts, ' | ');

best = runRows(1, :);
bestPart = sprintf('Best local evidence: %s (rmse=%g, corr=%g).', best.run_id, best.rmse, best.corr);

result = struct();
result.query_name = query_name;
result.seed_claim_ids = seedClaimIds;
result.seed_run_ids = seedRunIds;
result.found_runs = runRows;
result.summary = strtrim(summaryText + " " + bestPart);

% Enrich with snapshot metadata (analysis membership + claim paths)
seedClaimPaths = strings(0);
for i = 1:numel(seedClaimIds)
    cid = seedClaimIds(i);
    cids = strings({claimIndex.claims.claim_id});
    cpaths = strings({claimIndex.claims.claim_path});
    hit = find(cids == cid, 1, 'first');
    if ~isempty(hit)
        seedClaimPaths(end+1) = cpaths(hit); %#ok<AGROW>
    else
        seedClaimPaths(end+1) = ""; %#ok<AGROW>
    end
end
result.seed_claim_paths = seedClaimPaths;

analysisIdsCol = strings(height(runRows), 1);
for i = 1:height(runRows)
    rid = runRows.run_id(i);
    aids = strings(0);
    for a = 1:numel(analysisRegistry.analyses)
        ar = analysisRegistry.analyses(a);
        if isfield(ar, 'run_ids') && any(string(ar.run_ids) == rid)
            aids(end+1) = string(ar.analysis_id); %#ok<AGROW>
        end
    end
    if ~isempty(aids)
        analysisIdsCol(i) = strjoin(aids, ';');
    else
        analysisIdsCol(i) = "";
    end
end
result.found_runs.analysis_ids = analysisIdsCol;

end

function edges = load_jsonl_struct(jsonlPath)
if exist(jsonlPath, 'file') ~= 2
    edges = struct('run_id',{},'claim_id',{});
    return;
end
fid = fopen(jsonlPath, 'r');
if fid < 0
    edges = struct('run_id',{},'claim_id',{});
    return;
end

edges = struct('run_id', {}, 'claim_id', {});
while true
    tline = fgetl(fid);
    if ~ischar(tline)
        break;
    end
    % Some files may begin with UTF-8 BOM or zero-width markers.
    tline = sanitize_leading_invisible(tline);
    tline = strtrim(tline);
    if tline == ""
        continue;
    end
    s = jsondecode(tline);
    % Force fields we care about to exist
    if ~isfield(s,'run_id'); continue; end
    if ~isfield(s,'claim_id'); s.claim_id = ""; end
    edges(end+1) = s; %#ok<AGROW>
end
fclose(fid);
end

function metrics = extract_metrics_from_evidence(evidence, queryMode)
% Return [] when no known metric artifacts were found for this query.
metrics = [];

tables = evidence.tables;
if isempty(tables)
    return;
end

% Normalize query mode
qm = queryMode;

% Helper for reading numeric columns by variable name
getNumericVar = @(T, targetName) numericVarFromTable(T, targetName);

for i = 1:numel(tables)
    filePath = tables{i};
    if strlength(filePath) == 0
        continue;
    end
    fileLower = lower(string(filePath));

    try
        if qm == "coordinate_selection" && endsWith(fileLower, 'coordinate_candidate_metrics.csv')
            T = readtable(filePath, 'Delimiter', ',', 'TextType', 'string');
            vars = lower(string(T.Properties.VariableNames));
            rmseVar = find(vars == "loocv_rmse", 1, 'first');
            pearVar = find(vars == "pearson_loocv", 1, 'first');
            spVar = find(vars == "spearman_loocv", 1, 'first');
            rmse = NaN; corr = NaN; spearman = NaN;
            if ~isempty(rmseVar)
                rmseCol = T{:, rmseVar};
                [rmse, idxMin] = min(rmseCol);
                if ~isempty(pearVar); corr = T{idxMin, pearVar}; end
                if ~isempty(spVar); spearman = T{idxMin, spVar}; end
            elseif ~isempty(pearVar)
                corrCol = T{:, pearVar};
                [corr, idxMax] = max(corrCol);
                if ~isempty( rmseVar); rmse = T{idxMax, rmseVar}; end
                if ~isempty(spVar); spearman = T{idxMax, spVar}; end
            end
            metrics = struct('rmse', rmse, 'corr', corr, 'spearman', spearman, ...
                'rank1_energy_fraction', NaN, 'metric_source', string(filePath));
            metrics.score = corr;
            if isnan(metrics.score) || metrics.score == 0
                if ~isnan(metrics.rmse); metrics.score = -metrics.rmse; else metrics.score = 0; end
            end
            return;
        end

        if qm == "residual_validity" && endsWith(fileLower, 'residual_decomposition_quality.csv')
            T = readtable(filePath, 'Delimiter', ',', 'TextType', 'string');
            vars = lower(string(T.Properties.VariableNames));
            rmseVar = find(vars == "low_window_rmse", 1, 'first');
            corrVar = find(vars == "low_window_median_curve_corr", 1, 'first');
            rmse = NaN; corr = NaN;
            if ~isempty(rmseVar); rmse = T{1, rmseVar}; end
            if ~isempty(corrVar); corr = T{1, corrVar}; end
            metrics = struct('rmse', rmse, 'corr', corr, 'spearman', NaN, ...
                'rank1_energy_fraction', NaN, 'metric_source', string(filePath));
            metrics.score = corr;
            if isnan(metrics.score) || metrics.score == 0
                if ~isnan(metrics.rmse); metrics.score = -metrics.rmse; else metrics.score = 0; end
            end
            return;
        end

        if qm == "residual_validity" && endsWith(fileLower, 'reconstruction_quality_vs_variant.csv')
            T = readtable(filePath, 'Delimiter', ',', 'TextType', 'string');
            vars = lower(string(T.Properties.VariableNames));
            corrVar = find(vars == "rank1_curve_correlation", 1, 'first');
            rmse = NaN; corr = NaN;
            if ~isempty(corrVar)
                corrCol = T{:, corrVar};
                [corr, ~] = max(corrCol);
            end
            metrics = struct('rmse', rmse, 'corr', corr, 'spearman', NaN, ...
                'rank1_energy_fraction', NaN, 'metric_source', string(filePath));
            metrics.score = corr;
            if isnan(metrics.score) || metrics.score == 0
                metrics.score = 0;
            end
            return;
        end

        if qm == "pt_vs_relaxation" && endsWith(fileLower, 'pt_to_phi_link_summary.csv')
            T = readtable(filePath, 'Delimiter', ',', 'TextType', 'string');
            qty = string(T.quantity);
            val = T.value;
            rmse = NaN; corr = NaN;
            want = ["loocv_rmse_best_PT2", "stability_no22K_best_PT2_loocv_rmse"];
            for k = 1:numel(want)
                m = qty == want(k);
                if any(m)
                    rmse = val(find(m, 1, 'first'));
                    break;
                end
            end
            metrics = struct('rmse', rmse, 'corr', corr, 'spearman', NaN, ...
                'rank1_energy_fraction', NaN, 'metric_source', string(filePath));
            metrics.score = -rmse;
            return;
        end

        if qm == "pt_vs_relaxation" && endsWith(fileLower, 'pt_deformation_reconstruction_metrics.csv')
            T = readtable(filePath, 'Delimiter', ',', 'TextType', 'string');
            vars = lower(string(T.Properties.VariableNames));
            rmseVar = find(vars == "rmse_kappa_phi_reconstruction", 1, 'first');
            fracVar = find(vars == "rank1_energy_fraction", 1, 'first');
            rmse = NaN; frac = NaN; corr = NaN;
            if ~isempty(rmseVar)
                rmseCol = T{:, rmseVar};
                rmse = min(rmseCol, [], 'omitnan');
            end
            if ~isempty(fracVar)
                fracCol = T{:, fracVar};
                frac = max(fracCol, [], 'omitnan');
            end
            metrics = struct('rmse', rmse, 'corr', corr, 'spearman', NaN, ...
                'rank1_energy_fraction', frac, 'metric_source', string(filePath));
            metrics.score = -rmse;
            return;
        end
    catch
        % Ignore parse failures for a single artifact
    end
end

end

function x = numericVarFromTable(T, varName)
% Utility: not currently used, kept for potential extension.
if ~any(lower(string(T.Properties.VariableNames)) == lower(string(varName)))
    x = NaN;
    return;
end
idx = find(lower(string(T.Properties.VariableNames)) == lower(string(varName)), 1, 'first');
x = T{:, idx};
end

function data = read_json_file(jsonPath)
% read_json_file
%   jsondecode helper that removes UTF-8 BOM / invisible prefix.
if exist(jsonPath, 'file') ~= 2
    error('read_json_file: file not found: %s', jsonPath);
end
raw = fileread(jsonPath);
raw = sanitize_leading_invisible(raw);
raw = strtrim(raw);
data = jsondecode(raw);
end

function s = sanitize_leading_invisible(s)
% Remove UTF-8 BOM (U+FEFF) and zero-width space (U+200B) from the start.
if ~ischar(s) && ~isstring(s)
    s = char(s);
end
s = char(s);
while ~isempty(s) && (double(s(1)) == 65279 || double(s(1)) == 8203)
    s = s(2:end);
end
end

function repoRoot = resolveRepoRoot()
thisFile = mfilename('fullpath');
toolsDir = fileparts(thisFile);   % analysis/query
repoRoot = fileparts(toolsDir);   % analysis
repoRoot = fileparts(repoRoot); % repo root
end

