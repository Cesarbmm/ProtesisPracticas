function checkpointsRoot = getCanonicalCheckpointRoot()
%getCanonicalCheckpointRoot returns the tracked canonical checkpoint folder.

srcDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(srcDir);
checkpointsRoot = string(fullfile(matlabRoot, "checkpoints", "canonical"));
end
