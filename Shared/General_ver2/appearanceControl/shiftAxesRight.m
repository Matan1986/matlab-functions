function shiftAxesRight(dx)
% shiftAxesRight(dx)
% --------------------------------------------
% Shifts ALL axes in the current figure to
% the right by dx (normalized units).
%
% dx > 0  → shift right
% dx < 0  → shift left
%
% Written for multi-subplot figures (tiled
% layout or regular subplot).
% --------------------------------------------

if nargin < 1
    dx = 0.02;   % default shift
end

% Get all axes
ax = findall(gcf, 'Type', 'axes');

% Ensure stable ordering
ax = flipud(ax);

for k = 1:numel(ax)
    pos = ax(k).Position;
    ax(k).Position = [pos(1) + dx, pos(2), pos(3), pos(4)];
end

fprintf('Shifted %d axes by dx = %.3f to the right.\n', numel(ax), dx);
end
