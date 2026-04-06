function ensureDirectoryExists(dirPath)
%ensureDirectoryExists creates a directory only when it does not exist.

arguments
    dirPath
end

dirPath = char(string(dirPath));
if ~exist(dirPath, "dir")
    mkdir(dirPath);
end
end
