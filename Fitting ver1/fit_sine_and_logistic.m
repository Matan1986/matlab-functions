%% fit_sine_and_step_variable_duty.m
% Fits each .fig curve with:
%   f(x) = a1*sin(fold1*b*pi/180*x + c1)
%        + a2* square wave of variable duty cycle
% The square wave repeats every 180°, with duty cycle d in percent.
% Plots data+fit, sine component, and step component, then shows summary table.

clear; close all;

%% 1) PARAMETERS
baseDir = 'I:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 131\MG131 FIB3 In Plane Rotator full vs partially in series zfAMR and high res 5 deg\zfAMR at 11T high res 5deg inc 4K 3\fitting';
fixedB = 1;
fold1  = 2;
period = 180;

%% 2) LOAD FIG
figList = dir(fullfile(baseDir,'*.fig'));
if isempty(figList)
    error('No .fig files found in %s', baseDir);
end
open(fullfile(baseDir,figList(1).name));

%% 3) EXTRACT CURVES
axAll    = findobj(gcf,'Type','axes');
ax       = axAll(1);
curves   = flip(findobj(ax,'Type','line'));
xlab     = ax.XLabel.String;
ylab     = ax.YLabel.String;
lg       = legend(ax);
useNames = ~isempty(lg) && ~isempty(lg.String);
if useNames, names = lg.String(:); names = names(1:numel(curves)); end
n = numel(curves);
coeffs = zeros(n,5);  % [a1,c1,a2,c2,d]
gofs   = zeros(n,4);

%% 4) DEFINE MODEL
modelStr = [ ...
  'a1*sin(' num2str(fold1) '*b*pi/180*x + c1)' ...
  ' + a2*square(2*pi*(x - c2)/' num2str(period) ', d)' ];
ft = fittype(modelStr, ...
    'independent','x', ...
    'coefficients',{'a1','c1','a2','c2','d'}, ...
    'problem','b');

%% 5) FIT AND PLOT
for i=1:n
    x = double(curves(i).XData(:));
    y = double(curves(i).YData(:));
    % Extend over missing NaNs
    if any(isnan(y))
        ok = ~isnan(y); x0=x(ok); y0=y(ok); per=max(x0)-min(x0);
        x=[x0; x0+per]; y=[y0; y0];
    end
    % Extend one period
    if max(x)<=period
        per = max(x)-min(x);
        x=[x; x(2:end)+per]; y=[y; y(2:end)];
    end
    % Initial guesses
    amp     = (max(y)-min(y))/2;
    c2g     = mean(x);
    dg      = 50;
    sp      = [amp,0,amp,c2g,dg];
    opts = fitoptions('Method','NonlinearLeastSquares', ...
        'Lower',[-Inf,-Inf,0,-Inf,0], ...
        'Upper',[ Inf, Inf,Inf, Inf,100], ...
        'StartPoint',sp);
    % Fit
    [f,g] = fit(x,y,ft,opts,'problem',fixedB);
    coeffs(i,:)=[f.a1,f.c1,f.a2,f.c2,f.d];
    gofs(i,:)  =[g.sse,g.rsquare,g.adjrsquare,g.rmse];
    % Compute components
    xFit = linspace(min(x),max(x),400)';
    yFit = feval(f,xFit);
    y1 = f.a1*sin(fold1*fixedB*pi/180*xFit + f.c1);
    y2 = f.a2*square(2*pi*(xFit - f.c2)/period, f.d);
    % Plot
    if useNames, figName=names{i}; else figName=sprintf('Curve_%d',i); end
    hF=figure('Name',figName,'NumberTitle','off');
    t=tiledlayout(3,1,'Padding','compact','TileSpacing','compact');
    % Data+fit
    nexttile; plot(x,y,'o','MarkerFaceColor','auto'); hold on;
               plot(xFit,yFit,'-','LineWidth',1.5);
               grid on; legend('data','fit');
               xlabel(xlab); ylabel(ylab); title('Data & Fit');
    % Sine
    nexttile; plot(xFit,y1,'-','LineWidth',1.5);
               grid on; legend('sine');
               xlabel(xlab); ylabel(ylab); title('Sine Component');
    % Step
    nexttile; plot(xFit,y2,'-','LineWidth',1.5);
               grid on; legend('step');
               xlabel(xlab); ylabel(ylab); title('Step Component');
    title(t,figName,'Interpreter','none');
end

%% 6) SUMMARY TABLE
varNames={'a1','c1','a2','c2','d','SSE','R2','AdjR2','RMSE'};
T=array2table([coeffs,gofs],'VariableNames',varNames);
if useNames, T.Properties.RowNames=names; end
fT=figure('Name','Summary','NumberTitle','off','Units','normalized','Position',[0.2 0.2 0.6 0.6]);
utable('Data',T{:,:},'ColumnName',T.Properties.VariableNames,'RowName',T.Properties.RowNames,'Units','normalized','Position',[0 0 1 1],'ColumnWidth','auto');
