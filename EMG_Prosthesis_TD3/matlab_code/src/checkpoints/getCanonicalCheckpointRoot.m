function checkpointsRoot = getCanonicalCheckpointRoot()
%getCanonicalCheckpointRoot returns the tracked canonical checkpoint folder.

srcDir = fileparts(mfilename("fullpath"));
srcRoot = fileparts(srcDir);
matlabRoot = fileparts(srcRoot);
checkpointsRoot = string(fullfile(matlabRoot, "checkpoints", "canonical"));
end
