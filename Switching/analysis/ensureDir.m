function ensureDir(dirPath)
    if exist(dirPath, 'dir') ~= 7
        mkdir(dirPath);
    end
end

