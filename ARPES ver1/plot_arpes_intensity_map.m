function [fig, ax] = plot_arpes_intensity_map(Z, ky_axis, energy_axis, K_K_dis)
% plot_arpes_intensity_map
% Generate an ARPES-style intensity map with paper-style K-point guides.
%
% Inputs:
%   Z           - intensity map (size: numel(energy_axis) x numel(ky_axis))
%   ky_axis     - momentum axis values
%   energy_axis - binding-energy axis values
%   K_K_dis     - K-to-K distance in reciprocal space
%
% Outputs:
%   fig, ax     - figure and axes handles

if nargin < 4 || isempty(K_K_dis)
    K_K_dis = 0.7300596424962338;
end

if isempty(Z) || isempty(ky_axis) || isempty(energy_axis)
    error('Z, ky_axis, and energy_axis must be non-empty.');
end

p_low = prctile(Z(:), 1);
p_high = prctile(Z(:), 99);
if p_high > p_low
    Z_plot = (Z - p_low) / (p_high - p_low);
else
    Z_plot = zeros(size(Z));
end
Z_plot = max(0, min(1, Z_plot));

cmap = interp1([0 0.25 0.5 0.75 1], ...
    [0 0 0.5; ...
     0 0.7 0.3; ...
     1 1 0.6; ...
     0.6 0.4 0.3; ...
     1 1 1], ...
    linspace(0,1,256));

fig = figure('Color', 'w');
ax = axes('Parent', fig);

imagesc(ax, ky_axis, energy_axis, Z_plot);
axis(ax, 'xy');
axis(ax, 'tight');

colormap(ax, cmap);
caxis(ax, [0 1]);

xlabel(ax, 'K_y [\AA^{-1}]');
ylabel(ax, 'Binding Energy [eV]');

K_pos = 0.7300596424962338 / 2;
xline(ax, -K_pos, '--k', 'LineWidth', 1.5);
xline(ax,  K_pos, '--k', 'LineWidth', 1.5);

xticks(ax, [-K_pos 0 K_pos]);
xticklabels(ax, {'K','\Gamma','K'});

colorbar(ax, 'eastoutside');

box(ax, 'on');
set(ax, 'FontSize', 12, 'LineWidth', 1.2, 'TickDir', 'out');
end
