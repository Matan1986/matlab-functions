base = fileparts(mfilename('fullpath'));
addpath(genpath(fileparts(base)));
reportsDir = fullfile(fileparts(base),'reports');
if ~isfolder(reportsDir), mkdir(reportsDir); end
outFile = fullfile(reportsDir,'phase21_validation_runner_report.txt');

try
    results = phase21_validation();
    fid = fopen(outFile,'w');
    fprintf(fid,'passed=%d\n', results.passed);
    if isfield(results,'failures') && ~isempty(results.failures)
        for i = 1:numel(results.failures)
            fprintf(fid,'failure_%d=%s\n', i, results.failures{i});
        end
    end
    fclose(fid);
catch ME
    fid = fopen(outFile,'w');
    fprintf(fid,'passed=0\n');
    fprintf(fid,'id=%s\n', ME.identifier);
    fprintf(fid,'msg=%s\n', ME.message);
    for si = 1:numel(ME.stack)
        fprintf(fid,'stack_%d=%s:%d\n', si, ME.stack(si).file, ME.stack(si).line);
    end
    fclose(fid);
end
