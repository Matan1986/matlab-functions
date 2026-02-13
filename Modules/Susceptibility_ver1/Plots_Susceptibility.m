function Plots_Susceptibility(Temp_table, chiP_table, chiPP_table, freq_table, ...
                                 colors, normalizeByMass, sample_name, fontsize)
% Plots_Susceptibility — Plot χ′(T) and χ″(T) curves for all frequencies
%
% Inputs:
%   Temp_table, chiP_table, chiPP_table — data arrays
%   freq_table — frequency values per dataset
%   colors — colormap matrix
%   normalizeByMass — logical flag for y-axis units
%   sample_name — label for title
%   fontsize — font size for labels
%
% ---------------------------------------------------------------

if normalizeByMass
    yUnits = 'emu·g^{-1}·Oe^{-1}';
else
    yUnits = 'emu·Oe^{-1}';
end

nFiles = numel(Temp_table);
freqVals = zeros(nFiles,1);
for i = 1:nFiles
    f = freq_table{i};
    if isempty(f), freqVals(i)=NaN; else, freqVals(i)=round(mean(f),3); end
end

% --- make sure colormap is long enough ---
if size(colors,1) < nFiles
    colors = interp1(linspace(0,1,size(colors,1)), colors, linspace(0,1,nFiles));
end

% ---------- χ'(T) ----------
figure('Name',[sample_name ', χ′(T)'],'Color','w'); hold on;
for i = 1:nFiles
    plot(Temp_table{i}, chiP_table{i}, 'LineWidth', 1.8, ...
         'Color', colors(i,:), ...
         'DisplayName', sprintf('%.3g[Hz]', freqVals(i)));
end
xlabel('Temperature[K]');
ylabel(['\chi'' [' yUnits ']'],'Interpreter','tex');
legend('show','Location','best');
title([sample_name ', In-phase susceptibility']);
grid on; set(gca,'FontSize',fontsize); box on;

% ---------- χ''(T) ----------
figure('Name',[sample_name ', χ″(T)'],'Color','w'); hold on;
for i = 1:nFiles
    plot(Temp_table{i}, chiPP_table{i}, 'LineWidth', 1.8, ...
         'Color', colors(i,:), ...
         'DisplayName', sprintf('%.3g[Hz]', freqVals(i)));
end
xlabel('Temperature[K]');
ylabel(['\chi'''' [' yUnits ']'],'Interpreter','tex');
legend('show','Location','best');
title([sample_name ', Out-of-phase susceptibility']);
grid on; set(gca,'FontSize',fontsize); box on;
end
