function ACHC_plotFits(Angle, Cr_norm, legendStrings, detFold, A_all, phi_all, d_all)

n = numel(Angle);

for i = 1:n
    x = Angle{i};
    y = Cr_norm{i};

    fold_i  = detFold(i);
    A       = A_all(i);
    phi     = phi_all(i);
    d0      = d_all(i);

    figure('Name', sprintf('Fit – %s', legendStrings{i}), 'Color','w');
    plot(x, y, 'ko'); hold on;

    xPlot = linspace(min(x), max(x), 800);
    yPlot = A * sin(fold_i * xPlot*pi/180 + deg2rad(phi)) + d0;

    plot(xPlot, yPlot, 'r-', 'LineWidth', 1.5);

    grid on;
    xlabel('Angle [deg]');
    ylabel('Cr\_norm');

    title(sprintf('%s | fold=%d | A=%.2g | φ=%.1f°', ...
           legendStrings{i}, fold_i, A, phi));
end

end
