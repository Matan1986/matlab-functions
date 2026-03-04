function pauseRuns = filterAgingMemory(pauseRuns, method, order, frame)
% filterAgingMemory
% Professional post-analysis filtering of ΔM(T) curves.
%
% Applied ONLY to:
%   - pauseRuns(i).DeltaM
%   - pauseRuns(i).DeltaM_aligned (if exists)
%
% Intended to suppress high-frequency noise without
% affecting dip position or amplitude.

arguments
    pauseRuns
    method (1,:) char {mustBeMember(method,{'sgolay','movmean','movmedian'})}
    order  (1,1) double {mustBeNonnegative} = 2
    frame  (1,1) double {mustBePositive}    = 7
end

if mod(frame,2) == 0
    error('filterAgingMemory: frame length must be odd.');
end

for i = 1:numel(pauseRuns)

    % -------- raw ΔM --------
    if isfield(pauseRuns(i),'DeltaM') && ...
       numel(pauseRuns(i).DeltaM) >= frame

        pauseRuns(i).DeltaM = applyFilter( ...
            pauseRuns(i).DeltaM, method, order, frame);
    end

    % -------- aligned ΔM --------
    if isfield(pauseRuns(i),'DeltaM_aligned') && ...
       numel(pauseRuns(i).DeltaM_aligned) >= frame

        pauseRuns(i).DeltaM_aligned = applyFilter( ...
            pauseRuns(i).DeltaM_aligned, method, order, frame);
    end

end
end

% ==================================================
function y = applyFilter(x, method, order, frame)

x = x(:);                       % column
n = numel(x);
if n < frame
    y = x; 
    return;
end
if mod(frame,2)==0
    error('applyFilter: frame must be odd');
end

% ---- edge protection by padding ----
half = (frame-1)/2;

% Mirror padding (reflect around edges)
xpad = [flipud(x(1:half)); x; flipud(x(end-half+1:end))];

% ---- filter on padded signal ----
switch lower(method)
    case 'sgolay'
        ypad = sgolayfilt(xpad, order, frame);

    case 'movmean'
        ypad = smoothdata(xpad, 'movmean', frame);

    case 'movmedian'
        ypad = smoothdata(xpad, 'movmedian', frame);
end

% ---- crop back to original length ----
y = ypad(half+1 : half+n);
end
