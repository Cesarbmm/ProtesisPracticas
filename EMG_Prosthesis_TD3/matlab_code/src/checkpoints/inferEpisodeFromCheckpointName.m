function episode = inferEpisodeFromCheckpointName(checkpointPath)
%inferEpisodeFromCheckpointName extracts the episode number from Agent*.mat.

arguments
    checkpointPath
end

[~, checkpointName] = fileparts(string(checkpointPath));
tokens = regexp(checkpointName, 'Agent(\d+)$', 'tokens', 'once');
if isempty(tokens)
    episode = NaN;
else
    episode = str2double(tokens{1});
end
end
