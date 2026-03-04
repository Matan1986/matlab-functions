function plotArrhenius(Tadv)

T = Tadv.Temp_K;
tau = Tadv.tau;

ok = isfinite(T) & isfinite(tau) & tau>0;

T = T(ok);
tau = tau(ok);

figure('Color','w','Name','Arrhenius test');
ax = axes; hold(ax,'on'); box(ax,'on'); grid(ax,'on');

x = 1./T;
y = log(tau);

scatter(ax,x,y,60,'filled');

xlabel(ax,'1/T [1/K]');
ylabel(ax,'log(\tau)');
title(ax,'Arrhenius test');

end