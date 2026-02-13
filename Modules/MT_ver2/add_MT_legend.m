function add_MT_legend(figHandle, legendData)

if nargin < 1 || isempty(figHandle)
    figHandle = gcf;
end

sortedFields = legendData.sortedFields;
fieldRank    = legendData.fieldRank;
colorsZFC    = legendData.colorsZFC;
colorsFCW    = legendData.colorsFCW;
fontsize     = legendData.fontsize;
lw           = legendData.lw;
dy           = legendData.dy;


%% --- Fields in Tesla ---
fields_T = sortedFields(:).' / 10000;
fieldsUni = sort(fields_T,'descend');
nU = numel(fieldsUni);

%% --- Collect Colors ---
colZ = zeros(nU,3);
colF = zeros(nU,3);

for k = 1:nU
    idx = find(abs(fields_T - fieldsUni(k)) < 1e-9, 1);
   r  = fieldRank(idx);
    colZ(k,:) = colorsZFC(r,:);
    colF(k,:) = colorsFCW(r,:);
end

%% --- Remove existing legends ---
delete(findobj(figHandle,'Type','legend'));

%% --- Legend axes ---
axLeg = axes('Parent',figHandle, 'Position',[0.68 0.29 0.15 0.60]);
set(axLeg,'Visible','off','XLim',[0 1],'YLim',[0 nU+2],'YDir','reverse');
set(axLeg,'Tag','MT_Legend_Axes');
set(axLeg,'Color',[1 1 1 0]); % transparent

%% --- Parameters for drawing ---
dy      = 0.55;
lineLen = 0.35;
yHeader =0.35;
fs_header = fontsize + 0;
fs_rows   = fontsize -2;

xZ1 = 0.00;  xZ2 = xZ1 + lineLen;
xF1 = 0.55;  xF2 = xF1 + lineLen;
xText = 0.83;

%% --- Headers ---
text(axLeg,(xZ1+xZ2)/2, yHeader, '$\mathrm{ZFC}$', ...
     'Interpreter','latex', ...
     'HorizontalAlignment','center', ...
     'FontSize',fs_header);

text(axLeg,(xF1+xF2)/2, yHeader, '$\mathrm{FCW}$', ...
     'Interpreter','latex', ...
     'HorizontalAlignment','center', ...
     'FontSize',fs_header);

%% --- Rows ---
y0 = 0.5;

for k = 1:nU
    y = y0 + k*dy;
    fstr = sprintf('$%.1f\\,\\mathrm{T}$', fieldsUni(k));


    line(axLeg,[xZ1 xZ2],[y y],'Color',colZ(k,:),'LineWidth',lw);
    line(axLeg,[xF1 xF2],[y y],'Color',colF(k,:),'LineWidth',lw);

   text(axLeg, xText, y, fstr, ...
     'Interpreter','latex', ...
     'HorizontalAlignment','left', ...
     'FontSize',fs_rows);
end
end
