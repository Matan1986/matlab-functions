base = fileparts(mfilename('fullpath'));
addpath(genpath(fileparts(base)));
reportsDir = fullfile(fileparts(base),'reports');
if ~isfolder(reportsDir), mkdir(reportsDir); end
outFile = fullfile(reportsDir,'engine_apply_probe.txt');

try
	f = figure('Visible','off'); ax = axes('Parent',f); hold(ax,'on');
	x = 1:10;
	plot(ax,x,x,'DisplayName','Data1','LineWidth',1);
	plot(ax,x,x.^0.5,'DisplayName','Data2','LineWidth',1);
	plot(ax,x,2*x,'DisplayName','Fit','LineWidth',1);
	legend(ax,'show');

	a = SmartFigureEngine.buildAppearanceStyleFromUI('parula','medium',false,'','black','2.5','(no change)','8','1.7','(no change)',true,true,false,f,{});
	SmartFigureEngine.applyAppearanceToTargets(a);

	lines = findall(ax,'Type','line');
	lw = [lines.LineWidth];

	fid = fopen(outFile,'w');
	fprintf(fid,'ok=1\n');
	fprintf(fid,'lw=%s\n',mat2str(sort(lw)));
	fclose(fid);
	close(f);
catch ME
	fid = fopen(outFile,'w');
	fprintf(fid,'ok=0\n');
	fprintf(fid,'id=%s\n',ME.identifier);
	fprintf(fid,'msg=%s\n',ME.message);
	for si = 1:numel(ME.stack)
		fprintf(fid,'stack_%d=%s:%d\n', si, ME.stack(si).file, ME.stack(si).line);
	end
	fclose(fid);
end
