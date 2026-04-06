function agent = loadSavedAgent(checkpointPath)
%loadSavedAgent loads a saved agent or saved_agent variable from disk.

arguments
    checkpointPath (1, 1) string
end

vars = who('-file', checkpointPath);
if any(strcmp(vars, "agent"))
    aux = load(checkpointPath, "agent");
    agent = aux.agent;
elseif any(strcmp(vars, "saved_agent"))
    aux = load(checkpointPath, "saved_agent");
    agent = aux.saved_agent;
else
    error("Checkpoint %s does not contain 'agent' or 'saved_agent'.", checkpointPath);
end
end
