function shiftTilesRight(dx)
% shiftTilesRight(dx)
% --------------------------------------------
% Shifts an entire tiledlayout to the right
% by dx (normalized units).
% Works ONLY when using tiledlayout.
% --------------------------------------------

if nargin < 1
    dx = 0.02;
end

% Find layout
t = findall(gcf,'Type','tiledlayout');
if isempty(t)
    warning('No tiledlayout found in current figure.');
    return;
end

t = t(1);  % just in case more than one exists

outerPos = t.OuterPosition;
t.OuterPosition = [outerPos(1)+dx, outerPos(2), outerPos(3), outerPos(4)];

fprintf('Tiled layout shifted right by dx = %.3f.\n', dx);
end
