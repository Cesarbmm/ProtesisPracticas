function checkpointPath = getAgent7250CheckpointPath()
%getAgent7250CheckpointPath resolves the current operating benchmark checkpoint.

benchmark = getAgent7250Benchmark();
checkpointPath = string(benchmark.checkpointPath);
end
