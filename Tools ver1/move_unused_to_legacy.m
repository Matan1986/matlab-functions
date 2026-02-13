function move_unused_to_legacy(report, rootFolder)

    if nargin < 2
        rootFolder = pwd;
    end

    timestamp = datestr(now,'yyyy-mm-dd_HHMMSS');
    legacyFolder = fullfile(rootFolder, ['Legacy_unused_' timestamp]);

    if ~exist(legacyFolder,'dir')
        mkdir(legacyFolder);
    end

    unused = report.unused;

    fprintf('\nMoving %d unused functions to: %s\n\n', ...
            numel(unused), legacyFolder);

    for i = 1:numel(unused)

        % Convert string → char
        src = char(unused{i});

        [~, name, ext] = fileparts(src);

        % Convert destination to char as well
        dst = char(fullfile(legacyFolder, [name ext]));

        try
            copyfile(src, dst);
            fprintf('Moved: %s\n', src);
        catch ME
            fprintf('FAILED to move: %s\nReason: %s\n', src, ME.message);
        end
    end

    fprintf('\n==== DONE moving unused files ====\n');
end
