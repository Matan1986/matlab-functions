function guard = enforce_canonical_phi1_source(sourceRunIds, pipelineLabel)
% enforce_canonical_phi1_source
% Lightweight guard for canonical phi1 usage in active pipelines.

if nargin < 1
    sourceRunIds = {};
end
if nargin < 2 || isempty(pipelineLabel)
    pipelineLabel = 'unknown_pipeline';
end

if ischar(sourceRunIds) || isstring(sourceRunIds)
    sourceRunIds = cellstr(string(sourceRunIds));
end

if ~iscell(sourceRunIds)
    error('NON_CANONICAL_PHI1_USAGE_DETECTED: invalid phi1 source id container for %s', pipelineLabel);
end

canonicalRunId = "run_2026_03_14_161801_switching_dynamic_shape_mode";

rawIds = strings(0, 1);
for i = 1:numel(sourceRunIds)
    id = string(sourceRunIds{i});
    if strlength(strtrim(id)) == 0
        continue;
    end
    rawIds(end+1, 1) = strtrim(id); %#ok<AGROW>
end

if isempty(rawIds)
    fprintf('NON_CANONICAL_PHI1_USAGE_DETECTED\n');
    error('NON_CANONICAL_PHI1_USAGE_DETECTED: no phi1 source run id provided (%s)', pipelineLabel);
end

uniqueIds = unique(rawIds, 'stable');

guard = struct();
guard.pipeline = string(pipelineLabel);
guard.canonical_phi1_run_id = canonicalRunId;
guard.detected_phi1_sources = uniqueIds;
guard.NON_CANONICAL_PHI1 = any(uniqueIds ~= canonicalRunId);
guard.PHI1_MIXING_BLOCKED = numel(uniqueIds) > 1;

if guard.PHI1_MIXING_BLOCKED
    fprintf('PHI1_MIXING_BLOCKED = YES\n');
    error('PHI1_MIXING_BLOCKED = YES: %s uses multiple phi1 sources (%s)', ...
        pipelineLabel, strjoin(cellstr(uniqueIds), ', '));
end

if guard.NON_CANONICAL_PHI1
    fprintf('NON_CANONICAL_PHI1_USAGE_DETECTED\n');
    error('NON_CANONICAL_PHI1_USAGE_DETECTED: %s uses non-canonical phi1 source (%s); NON_CANONICAL_PHI1 = TRUE', ...
        pipelineLabel, char(uniqueIds(1)));
end
end
