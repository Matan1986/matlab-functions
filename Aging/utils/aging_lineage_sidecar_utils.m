function u = aging_lineage_sidecar_utils()
% aging_lineage_sidecar_utils Reusable Aging lineage sidecar / manifest helpers (F7A).
% Conservative defaults: audit_only, diagnostic-only model posture, not canonical.
% Does not modify writers or scientific calculations.
%
% Usage:
%   u = aging_lineage_sidecar_utils();
%   T = u.build_default_sidecar(meta);
%   [T2, issues] = u.validate_sidecar(T);
%   u.write_sidecar_csv(path, T2);

u.required_metadata_fields = @required_metadata_fields;
u.default_opts = @default_opts;
u.ensure_opts = @ensure_opts;
u.normalize_metadata = @normalize_metadata;
u.observable_identity_block = @observable_identity_block;
u.writer_identity_block = @writer_identity_block;
u.source_run_identity_block = @source_run_identity_block;
u.formula_scalarization_block = @formula_scalarization_block;
u.tau_r_numerator_denominator_blocks = @tau_r_numerator_denominator_blocks;
u.merge_blocks_into_sidecar = @merge_blocks_into_sidecar;
u.build_default_sidecar = @build_default_sidecar;
u.validate_sidecar = @validate_sidecar;
u.new_issue = @new_issue;
u.write_sidecar_csv = @write_sidecar_csv;
u.write_sidecar_json = @write_sidecar_json;
u.write_compact_table_manifest = @write_compact_table_manifest;
u.struct_to_one_row_table = @struct_to_one_row_table;
u.table_to_issue_struct = @table_to_issue_struct;
end

function flds = required_metadata_fields()
flds = { ...
    'schema_version', ...
    'validation_mode', ...
    'artifact_path', ...
    'artifact_class', ...
    'writer_family_id', ...
    'writer_id', ...
    'formula_id', ...
    'registry_id', ...
    'namespace', ...
    'observable_definition_id', ...
    'observable_semantic_name', ...
    'source_run_id', ...
    'source_dataset_id', ...
    'input_signal_id', ...
    'sign_convention', ...
    'unit_status', ...
    'preprocessing_recipe_id', ...
    'scalarization_recipe_id', ...
    'provenance_status', ...
    'model_readiness', ...
    'canonical_status', ...
    'legacy_quarantine_allowed', ...
    'diagnostic_use_allowed', ...
    'model_use_allowed', ...
    'canonical_use_allowed', ...
    'tau_or_R_flag', ...
    'numerator_observable_id', ...
    'denominator_observable_id', ...
    'authoritative_flag_field', ...
    'notes' ...
    };
end

function opts = default_opts()
opts = struct();
opts.validation_mode = 'audit_only';
opts.strict_mode = false;
opts.na_fields = {};
opts.mark_plain_dip_unresolved = true;
opts.schema_version_default = 'F6T-1.0';
opts.model_readiness_default = 'diagnostic_only';
opts.canonical_status_default = 'not_canonical';
opts.unknown_token = 'UNKNOWN';
opts.na_token = 'NOT_APPLICABLE';
end

function opts = ensure_opts(optsIn)
opts = default_opts();
if nargin < 1 || isempty(optsIn)
    return;
end
if isfield(optsIn, 'validation_mode')
    opts.validation_mode = optsIn.validation_mode;
end
if isfield(optsIn, 'strict_mode')
    opts.strict_mode = logical(optsIn.strict_mode);
end
if isfield(optsIn, 'na_fields') && ~isempty(optsIn.na_fields)
    opts.na_fields = optsIn.na_fields;
end
if isfield(optsIn, 'mark_plain_dip_unresolved')
    opts.mark_plain_dip_unresolved = logical(optsIn.mark_plain_dip_unresolved);
end
if isfield(optsIn, 'schema_version_default')
    opts.schema_version_default = optsIn.schema_version_default;
end
if isfield(optsIn, 'model_readiness_default')
    opts.model_readiness_default = optsIn.model_readiness_default;
end
if isfield(optsIn, 'canonical_status_default')
    opts.canonical_status_default = optsIn.canonical_status_default;
end
if isfield(optsIn, 'unknown_token')
    opts.unknown_token = optsIn.unknown_token;
end
if isfield(optsIn, 'na_token')
    opts.na_token = optsIn.na_token;
end
end

function out = normalize_metadata(meta, opts)
if nargin < 2
    opts = [];
end
opts = ensure_opts(opts);
if ~isstruct(meta)
    meta = struct();
end
unk = opts.unknown_token;
naTok = opts.na_token;
flds = required_metadata_fields();
out = struct();
for i = 1:numel(flds)
    k = flds{i};
    useNa = ismember(k, opts.na_fields);
    if isfield(meta, k) && ~is_emptyish(meta.(k))
        v = meta.(k);
        if ischar(v) || isstring(v)
            s = strtrim(char(string(v)));
            if isempty(s)
                out.(k) = pick_na_or_unk(useNa, naTok, unk);
            else
                out.(k) = s;
            end
        elseif isnumeric(v) && isscalar(v)
            out.(k) = char(string(v));
        else
            out.(k) = char(string(v));
        end
    else
        out.(k) = pick_na_or_unk(useNa, naTok, unk);
    end
end
out.validation_mode = strtrim(char(string(opts.validation_mode)));
if is_emptyish(out.validation_mode)
    out.validation_mode = 'audit_only';
end
if ~isfield(meta, 'schema_version') || is_emptyish(out.schema_version)
    out.schema_version = opts.schema_version_default;
end
if ismember('model_readiness', opts.na_fields)
    out.model_readiness = naTok;
else
    if ~isfield(meta, 'model_readiness') || is_emptyish(meta.model_readiness)
        out.model_readiness = opts.model_readiness_default;
    end
end
if ismember('canonical_status', opts.na_fields)
    out.canonical_status = naTok;
else
    if ~isfield(meta, 'canonical_status') || is_emptyish(meta.canonical_status)
        out.canonical_status = opts.canonical_status_default;
    end
end
end

function t = pick_na_or_unk(useNa, naTok, unk)
if useNa
    t = naTok;
else
    t = unk;
end
end

function e = is_emptyish(v)
if isempty(v)
    e = true;
    return;
end
if (ischar(v) || isstring(v)) && strtrim(char(string(v))) == ""
    e = true;
    return;
end
e = false;
end

function blk = observable_identity_block(observable_definition_id, observable_semantic_name, namespace, registry_id)
blk = struct( ...
    'observable_definition_id', resolve_val(observable_definition_id), ...
    'observable_semantic_name', resolve_val(observable_semantic_name), ...
    'namespace', resolve_val(namespace), ...
    'registry_id', resolve_val(registry_id) ...
    );
end

function blk = writer_identity_block(writer_family_id, writer_id, formula_id)
blk = struct( ...
    'writer_family_id', resolve_val(writer_family_id), ...
    'writer_id', resolve_val(writer_id), ...
    'formula_id', resolve_val(formula_id) ...
    );
end

function blk = source_run_identity_block(source_run_id, source_dataset_id, input_signal_id)
blk = struct( ...
    'source_run_id', resolve_val(source_run_id), ...
    'source_dataset_id', resolve_val(source_dataset_id), ...
    'input_signal_id', resolve_val(input_signal_id) ...
    );
end

function blk = formula_scalarization_block(formula_id, scalarization_recipe_id, preprocessing_recipe_id, unit_status, sign_convention, provenance_status)
blk = struct( ...
    'formula_id', resolve_val(formula_id), ...
    'scalarization_recipe_id', resolve_val(scalarization_recipe_id), ...
    'preprocessing_recipe_id', resolve_val(preprocessing_recipe_id), ...
    'unit_status', resolve_val(unit_status), ...
    'sign_convention', resolve_val(sign_convention), ...
    'provenance_status', resolve_val(provenance_status) ...
    );
end

function blk = tau_r_numerator_denominator_blocks(tau_or_R_flag, numerator_observable_id, denominator_observable_id, authoritative_flag_field)
blk = struct( ...
    'tau_or_R_flag', resolve_val(tau_or_R_flag), ...
    'numerator_observable_id', resolve_val(numerator_observable_id), ...
    'denominator_observable_id', resolve_val(denominator_observable_id), ...
    'authoritative_flag_field', resolve_val(authoritative_flag_field) ...
    );
end

function v = resolve_val(x)
d = default_opts();
if nargin < 1 || is_emptyish(x)
    v = d.unknown_token;
    return;
end
v = strtrim(char(string(x)));
if isempty(v)
    v = d.unknown_token;
end
end

function sidecar = merge_blocks_into_sidecar(base_meta, blocks, opts)
if nargin < 2 || isempty(blocks)
    blocks = struct();
end
opts = ensure_opts(opts);
sidecar = normalize_metadata(base_meta, opts);
if isfield(blocks, 'observable')
    b = blocks.observable;
    ks = fieldnames(b);
    for i = 1:numel(ks)
        sidecar.(ks{i}) = b.(ks{i});
    end
end
if isfield(blocks, 'writer')
    b = blocks.writer;
    ks = fieldnames(b);
    for i = 1:numel(ks)
        sidecar.(ks{i}) = b.(ks{i});
    end
end
if isfield(blocks, 'source_run')
    b = blocks.source_run;
    ks = fieldnames(b);
    for i = 1:numel(ks)
        sidecar.(ks{i}) = b.(ks{i});
    end
end
if isfield(blocks, 'formula_scalarization')
    b = blocks.formula_scalarization;
    ks = fieldnames(b);
    for i = 1:numel(ks)
        sidecar.(ks{i}) = b.(ks{i});
    end
end
if isfield(blocks, 'tau_r')
    b = blocks.tau_r;
    ks = fieldnames(b);
    for i = 1:numel(ks)
        sidecar.(ks{i}) = b.(ks{i});
    end
end
end

function [T, issues] = build_default_sidecar(meta, opts)
if nargin < 2
    opts = [];
end
opts = ensure_opts(opts);
plainDipPolicy = true;
if isfield(opts, 'mark_plain_dip_unresolved')
    plainDipPolicy = logical(opts.mark_plain_dip_unresolved);
end
merged = normalize_metadata(meta, opts);
if plainDipPolicy
    sn = merged.observable_semantic_name;
    if strcmpi(strtrim(char(string(sn))), 'Dip_depth')
        merged.notes = append_text(merged.notes, 'plain_Dip_depth_semantic_name_unresolved_by_convention');
    end
end
T = struct_to_one_row_table(merged);
issues = validate_sidecar(T, opts);
end

function tx = append_text(base, add)
d = default_opts();
unk = d.unknown_token;
if is_emptyish(base) || strcmp(strtrim(char(string(base))), unk)
    tx = add;
    return;
end
b = strtrim(char(string(base)));
if contains(b, add)
    tx = b;
    return;
end
tx = [b, '; ', add];
end

function T = struct_to_one_row_table(s)
flds = required_metadata_fields();
cols = cell(1, numel(flds));
unk = default_opts().unknown_token;
for i = 1:numel(flds)
    k = flds{i};
    if isfield(s, k)
        cols{i} = char(string(s.(k)));
    else
        cols{i} = unk;
    end
end
% Use cell2table: table(cols{:},'VariableNames',...) mis-parses tokens like F6T-1.0 as name-value args.
T = cell2table(cols, 'VariableNames', flds);
end

function iss = new_issue(issue_id, severity, fieldName, what_failed, why_it_matters, suggested_fix, blocks_execution)
iss = { issue_id, severity, fieldName, what_failed, why_it_matters, suggested_fix, logical(blocks_execution) };
end

function [issuesTable, mode_used] = validate_sidecar(T, opts)
opts = ensure_opts(opts);
issues = {};
cols = { ...
    'issue_id', 'severity', 'field', 'what_failed', 'why_it_matters', 'suggested_fix', 'blocks_execution' ...
    };
mode_used = opts.validation_mode;
if istable(T)
    if height(T) < 1
        issues{end+1} = new_issue('F7A_EMPTY_SIDECAR', 'ERROR', '', 'sidecar table empty', 'nothing to validate', 'populate sidecar', block_exec(opts, true)); %#ok<AGROW>
        issuesTable = cell2table(cell(0, 7), 'VariableNames', cols);
        issuesTable = append_issues(issuesTable, issues);
        return;
    end
    r = table2struct(T(1, :));
else
    r = T;
end
unk = opts.unknown_token;
naTok = opts.na_token;
flds = required_metadata_fields();
for i = 1:numel(flds)
    k = flds{i};
    if isfield(r, k)
        val = r.(k);
        if isstring(val) || ischar(val)
            sval = strtrim(char(string(val)));
        else
            sval = char(string(val));
        end
        if isempty(sval)
            issues{end+1} = new_issue('F7A_BLANK_REQUIRED_FIELD', 'ERROR', k, 'required field is blank', 'blank fields break lineage contracts', 'use UNKNOWN or NOT_APPLICABLE via normalize_metadata', block_exec(opts, true)); %#ok<AGROW>
        end
    else
        issues{end+1} = new_issue('F7A_MISSING_REQUIRED_FIELD', 'ERROR', k, 'required field missing from struct/table', 'validators cannot trace identity', 'add field or normalize_metadata', block_exec(opts, true)); %#ok<AGROW>
    end
end
sem = '';
if isfield(r, 'observable_semantic_name')
    sem = strtrim(char(string(r.observable_semantic_name)));
end
if strcmpi(sem, 'Dip_depth')
    issues{end+1} = new_issue('F7A_PLAIN_DIP_DEPTH_UNRESOLVED', 'WARNING', 'observable_semantic_name', 'plain Dip_depth without S4A/S4B resolution', 'tau/R claims require dip lineage', 'rename column/sidecar to resolved dip definition per writer contract', block_exec(opts, false)); %#ok<AGROW>
end
notesTxt = '';
if isfield(r, 'notes')
    notesTxt = char(string(r.notes));
end
hay = lower([sem, ' ', notesTxt]);
if contains(hay, 'tau_dip_canonical')
    auth = '';
    if isfield(r, 'authoritative_flag_field')
        auth = strtrim(char(string(r.authoritative_flag_field)));
    end
    if isempty(auth) || strcmpi(auth, unk) || strcmpi(auth, naTok)
        issues{end+1} = new_issue('F7A_TAU_DIP_CANONICAL_WITHOUT_AUTH_FLAG', 'WARNING', 'authoritative_flag_field', 'tau_dip_canonical referenced without resolved authoritative flag field', 'canonical tau path requires explicit flag linkage', 'set authoritative_flag_field when tau_dip_canonical applies', block_exec(opts, false)); %#ok<AGROW>
    end
end
if isfield(r, 'model_readiness') && isfield(r, 'canonical_status')
    mr = strtrim(char(string(r.model_readiness)));
    cs = strtrim(char(string(r.canonical_status)));
    if strcmpi(mr, 'model_ready') || strcmpi(mr, 'production')
        issues{end+1} = new_issue('F7A_MODEL_READINESS_PREMIUM', 'WARNING', 'model_readiness', 'model_readiness implies elevated claims', 'helper never upgrades readiness implicitly', 'confirm registry evidence before marking model_ready', block_exec(opts, false)); %#ok<AGROW>
    end
    if strcmpi(cs, 'canonical') || strcmpi(cs, 'candidate')
        issues{end+1} = new_issue('F7A_CANONICAL_STATUS_PREMIUM', 'WARNING', 'canonical_status', 'canonical or candidate status present', 'helper scaffolding does not promote artifacts', 'promote only via governance process', block_exec(opts, false)); %#ok<AGROW>
    end
end
issuesTable = issues_cell_to_table(issues, cols);
if strcmpi(opts.validation_mode, 'audit_only')
    if height(issuesTable) > 0
        issuesTable.blocks_execution = false(height(issuesTable), 1);
    end
end
end

function b = block_exec(opts, would_block_strict)
b = false;
if isfield(opts, 'strict_mode') && opts.strict_mode && strcmpi(opts.validation_mode, 'strict')
    b = logical(would_block_strict);
else
    b = false;
end
end

function Tb = append_issues(Tb, cellIssues)
if isempty(cellIssues)
    return;
end
addT = issues_cell_to_table(cellIssues, Tb.Properties.VariableNames);
Tb = [Tb; addT];
end

function Tb = issues_cell_to_table(cellIssues, colNames)
if isempty(cellIssues)
    Tb = cell2table(cell(0, numel(colNames)), 'VariableNames', colNames);
    return;
end
n = numel(cellIssues);
m = numel(colNames);
rows = cell(n, m);
for i = 1:n
    row = cellIssues{i};
    rows(i, :) = row;
end
Tb = cell2table(rows, 'VariableNames', colNames);
end

function S = table_to_issue_struct(Tb)
S = struct();
if isempty(Tb) || height(Tb) < 1
    return;
end
for i = 1:height(Tb)
    row = table2struct(Tb(i, :));
    S(i) = row; %#ok<AGROW>
end
end

function write_sidecar_csv(outPath, T)
if istable(T)
    writetable(T, outPath);
else
    writetable(struct_to_one_row_table(T), outPath);
end
end

function write_sidecar_json(outPath, T)
if istable(T)
    if height(T) > 1
        s = table2struct(T);
    else
        s = table2struct(T(1, :));
    end
else
    s = T;
end
txt = jsonencode(s, 'PrettyPrint', true);
fid = fopen(outPath, 'w');
if fid < 0
    error('aging_lineage_sidecar_utils:JsonOpenFailed', 'cannot write %s', outPath);
end
fprintf(fid, '%s', txt);
fclose(fid);
end

function write_compact_table_manifest(outPath, artifact_path, sidecarSummary, opts)
if nargin < 4
    opts = [];
end
opts = ensure_opts(opts);
manifest_version = 'F7A-1.0';
unk = opts.unknown_token;
rowC = unk;
colC = unk;
if isstruct(sidecarSummary)
    sv = unk;
    if isfield(sidecarSummary, 'schema_version')
        sv = char(string(sidecarSummary.schema_version));
    end
    vm = opts.validation_mode;
    if isfield(sidecarSummary, 'validation_mode')
        vm = char(string(sidecarSummary.validation_mode));
    end
    wid = unk;
    if isfield(sidecarSummary, 'writer_id')
        wid = char(string(sidecarSummary.writer_id));
    end
    if isfield(sidecarSummary, 'table_row_count')
        rowC = char(string(sidecarSummary.table_row_count));
    end
    if isfield(sidecarSummary, 'table_column_count')
        colC = char(string(sidecarSummary.table_column_count));
    end
    M = table( ...
        {manifest_version}, {char(string(artifact_path))}, {sv}, {vm}, {wid}, {rowC}, {colC}, ...
        'VariableNames', { ...
        'manifest_schema_version', 'artifact_path', 'sidecar_schema_version', 'validation_mode', ...
        'writer_id', 'table_row_count', 'table_column_count' ...
        } ...
        );
else
    M = table( ...
        {manifest_version}, {char(string(artifact_path))}, {unk}, {opts.validation_mode}, {unk}, {rowC}, {colC}, ...
        'VariableNames', { ...
        'manifest_schema_version', 'artifact_path', 'sidecar_schema_version', 'validation_mode', ...
        'writer_id', 'table_row_count', 'table_column_count' ...
        } ...
        );
end
writetable(M, outPath);
end
