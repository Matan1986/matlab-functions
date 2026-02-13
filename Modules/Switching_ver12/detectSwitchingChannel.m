function switchInfo = detectSwitchingChannel(stability)
% detectSwitchingChannel
% Automatic detection of switching channel(s) from stability struct
%
% OUTPUT:
%   switchInfo.globalChannel
%   switchInfo.perDepValue(i).switchingChannel

% ---- thresholds ----
minDprime   = 3;
minGapSigma = 3;

T = stability.summaryTable;

[G, depU] = findgroups(T.depValue);

switchInfo = struct();
switchInfo.perDepValue = repmat(struct( ...
    'depValue',NaN, ...
    'switchingChannel',NaN, ...
    'switchScore',NaN, ...
    'numCandidates',0), numel(depU), 1);

for i = 1:numel(depU)
    Ti = T(G == i, :);

    valid = ...
        isfinite(Ti.stateSeparationD) & ...
        isfinite(Ti.stateGapAbs) & ...
        isfinite(Ti.withinRMS) & ...
        (Ti.withinRMS > 0);

    Ti = Ti(valid,:);
    if isempty(Ti), continue; end

    score = ...
    Ti.switchAmpMedian ./ Ti.withinRMS;

    isCandidate = ...
        (Ti.stateSeparationD > minDprime) & ...
        (Ti.stateGapAbs > minGapSigma * Ti.withinRMS);

    idxCand = find(isCandidate);

    switchInfo.perDepValue(i).depValue = depU(i);
    switchInfo.perDepValue(i).numCandidates = numel(idxCand);

    if isempty(idxCand), continue; end

    [~, bestRel] = max(score(idxCand));
    bestIdx = idxCand(bestRel);

    switchInfo.perDepValue(i).switchingChannel = Ti.channel(bestIdx);
    switchInfo.perDepValue(i).switchScore = score(bestIdx);
end

allCh = [switchInfo.perDepValue.switchingChannel];
allCh = allCh(isfinite(allCh));

if isempty(allCh)
    switchInfo.globalChannel = NaN;
else
    switchInfo.globalChannel = mode(allCh);
end

end
