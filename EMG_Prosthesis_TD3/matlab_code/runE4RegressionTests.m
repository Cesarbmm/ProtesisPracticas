function summary = runE4RegressionTests()
root = string(fileparts(mfilename("fullpath")));
addpath(fullfile(root, "analysis", "paired_reference"));
summary = e4RunAllRegressions();
end
