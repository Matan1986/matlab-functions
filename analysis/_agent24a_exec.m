fidp = fopen('C:/Dev/matlab-functions/_agent24a_exec_started.txt', 'w');
if fidp > 0, fprintf(fidp, 'start\n'); fclose(fidp); end
try
    repo = 'C:/Dev/matlab-functions';
    cd(repo);
    addpath(fullfile(repo, 'analysis'));
    run_A_prediction_from_switching_agent24a();
catch ME
    fid = fopen('C:/Dev/matlab-functions/_agent24a_matlab_err.txt', 'w');
    if fid > 0
        fprintf(fid, '%s\n', getReport(ME));
        fclose(fid);
    end
end
