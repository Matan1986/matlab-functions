addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
a = SmartFigureEngine.buildAppearanceStyleFromUI('parula','medium',false,'','black','2.5','(no change)','8','1.7','(no change)',false,false,false,[],{});
reportsDir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'reports');
if ~isfolder(reportsDir), mkdir(reportsDir); end
fid = fopen(fullfile(reportsDir,'engine_parse_probe.txt'),'w');
fprintf(fid,'dw=%.3f fw=%.3f ms=%.3f\n',a.dataWidth,a.fitWidth,a.markerSize);
fclose(fid);
