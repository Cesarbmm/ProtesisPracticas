function cfg = e4DocumentationConfig()
% Receta E4 intacta; presupuesto y semilla exclusivamente documentales.
root = string(fileparts(mfilename("fullpath")));
oldPath = path; cleanup = onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(fullfile(root,"analysis","paired_reference","e4"));
cfg = e4Config("long");
cfg = rmfield(cfg, ["finalAgentStep","scientificSeed","smokeSeed"]);
cfg.seed = 20261001;
cfg.documentationSeed = cfg.seed;
cfg.maxAgentSteps = 1000000;
cfg.checkpointSteps = [250000 500000 750000 1000000];
cfg.outputParent = fullfile(root,"results","e4_documentation_1m");
cfg.documentationOnly = true;
cfg.scientificFinalModel = false;
cfg.sealedTestReuse = "FORBIDDEN";
cfg.mateoSandraAllowed = false;
cfg.checkpointSelection = "NONE";
cfg.scientificFinalAgentSHA256 = "2aa39fdf166c62fb6da057f1ddecb6455fbaa142f476718dd4e2725dfde08c90";
end
