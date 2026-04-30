function tblOut = appendF7GTauRMetadataColumns(tblIn, meta)
%APPENDF7GTAURMETADATACOLUMNS Append-only F7G semantic metadata columns (ASCII).
%
% Does not remove or rename legacy numeric columns. Does not change formulas.

if nargin < 2 || isempty(meta)
    meta = struct();
end
if ~istable(tblIn)
    error('appendF7GTauRMetadataColumns:RequiresTableInput');
end

reqNames = {'writer_family_id','tau_or_R_flag','tau_domain','tau_input_observable_identities', ...
    'tau_input_observable_family','source_writer_script','source_artifact_basename', ...
    'source_artifact_path','canonical_status','model_use_allowed','semantic_status','lineage_status'};
for k = 1:numel(reqNames)
    if ismember(reqNames{k}, tblIn.Properties.VariableNames)
        error('appendF7GTauRMetadataColumns:ColumnAlreadyExists:%s', reqNames{k});
    end
end

n = height(tblIn);
writer_family_id = local_get(meta, 'writer_family_id', '');
tau_or_R_flag = local_get(meta, 'tau_or_R_flag', 'NONE');
tau_domain = local_get(meta, 'tau_domain', 'UNSPECIFIED');
tau_input_observable_identities = local_get(meta, 'tau_input_observable_identities', '{}');
tau_input_observable_family = local_get(meta, 'tau_input_observable_family', 'UNRESOLVED');
source_writer_script = local_get(meta, 'source_writer_script', '');
source_artifact_basename = local_get(meta, 'source_artifact_basename', '');
source_artifact_path = local_get(meta, 'source_artifact_path', '');
canonical_status = local_get(meta, 'canonical_status', 'non_canonical_pending_lineage');
model_use_allowed = local_get(meta, 'model_use_allowed', 'NO_UNLESS_LINEAGE_RESOLVED');
semantic_status = local_get(meta, 'semantic_status', 'F7G_METADATA_APPENDED');
lineage_status = local_get(meta, 'lineage_status', 'UNKNOWN');

tblOut = tblIn;
tblOut.writer_family_id = repmat(string(writer_family_id), n, 1);
tblOut.tau_or_R_flag = repmat(string(tau_or_R_flag), n, 1);
tblOut.tau_domain = repmat(string(tau_domain), n, 1);
tblOut.tau_input_observable_identities = repmat(string(tau_input_observable_identities), n, 1);
tblOut.tau_input_observable_family = repmat(string(tau_input_observable_family), n, 1);
tblOut.source_writer_script = repmat(string(source_writer_script), n, 1);
tblOut.source_artifact_basename = repmat(string(source_artifact_basename), n, 1);
tblOut.source_artifact_path = repmat(string(source_artifact_path), n, 1);
tblOut.canonical_status = repmat(string(canonical_status), n, 1);
tblOut.model_use_allowed = repmat(string(model_use_allowed), n, 1);
tblOut.semantic_status = repmat(string(semantic_status), n, 1);
tblOut.lineage_status = repmat(string(lineage_status), n, 1);
end

function out = local_get(meta, field, defaultStr)
if isstruct(meta) && isfield(meta, field)
    v = meta.(field);
    if isempty(v)
        out = defaultStr;
        return;
    end
    out = char(string(v));
else
    out = defaultStr;
end
end
