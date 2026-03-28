function setup_repo()
% setup_repo
%   One-command setup so repo MATLAB functions work out-of-the-box.

root = fileparts(mfilename('fullpath'));
addpath(genpath(root));

% Optional: print confirmation
fprintf('Repo paths added successfully.\n');

% Try saving path (safe)
try
    savepath;
catch
    warning('Could not save MATLAB path permanently.');
end

end

