h = findobj(gca,'Type','Line');
x = h.XData(:);
y = h.YData(:);

theta0 = 110;           % הציר האפקטיבי
x_tr = mod(theta0 - x, 360);
y_tr = -y;

y_tr = y_tr - mean(y_tr,'omitnan');

[xs,idx] = sort(x_tr);
ys = y_tr(idx);

figure; hold on; grid on;
plot(xs, ys, 'r-o','LineWidth',1.5)

xlabel('Angle [deg]');
ylabel('\Delta\rho/\rho [%]');
title('zfAMR after simplified symmetry transform');
