function paths = resolveMatlabCodePaths(callerFile)
%resolveMatlabCodePaths resolves stable roots for any file under matlab_code/.

arguments
    callerFile (1, 1) string
end

currentDir = string(fileparts(callerFile));
matlabRoot = currentDir;

while true
    [parentDir, currentName, ~] = fileparts(char(matlabRoot));
    if strcmpi(currentName, "matlab_code")
        break;
    end
    if strlength(string(parentDir)) == 0 || string(parentDir) == matlabRoot
        error("Could not resolve matlab_code root from %s", callerFile);
    end
    matlabRoot = string(parentDir);
end

projectRoot = string(fileparts(char(matlabRoot)));
workspaceRoot = string(fileparts(char(projectRoot)));

paths = struct( ...
    "callerDir", currentDir, ...
    "matlabRoot", matlabRoot, ...
    "projectRoot", projectRoot, ...
    "workspaceRoot", workspaceRoot);
end
