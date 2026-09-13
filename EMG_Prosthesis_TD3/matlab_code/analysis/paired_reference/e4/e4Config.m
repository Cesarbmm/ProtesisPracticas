function cfg = e4Config(mode)
arguments
    mode (1, 1) string {mustBeMember(mode, ["long", "smoke"])} = "long";
end

root = string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
cfg = struct();
cfg.mode = mode;
cfg.root = root;
cfg.algorithm = "FACTORIZED_MULTICATEGORICAL_PPO";
cfg.architecture = "E3B_FEED_FORWARD";
cfg.actionRepresentation = "4x15_categorical";
cfg.categories = [0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];

% 10 Sujetos DEVELOPMENT en TRAIN; NINGUNO en VALIDATION
cfg.trainSubjects = ["BLANCA", "CECILIA", "DENIS", "EMILIA", "GABI", "GABRIEL", "IVANNA", "JOE", "JONATHAN", "KHAROL"];
cfg.validationSubjects = strings(1, 0);
cfg.sealedSubjects = ["MATEO", "SANDRA"];

% Semillas preregistradas
cfg.scientificSeed = 20260920;
cfg.smokeSeed = 20260921;
if mode == "smoke"
    cfg.seed = cfg.smokeSeed;
    cfg.smokeEpisodes = 6;
    cfg.smokeCheckpointEpisodes = [3 6];
else
    cfg.seed = cfg.scientificSeed;
end

% Presupuesto fijo exacto: 500,000 pasos de agente
cfg.maxAgentSteps = 500000;
cfg.checkpointSteps = [50000 100000 250000 500000];
cfg.checkpointSelection = "NONE";
cfg.finalAgentStep = 500000;

% Arquitectura y optimizador identicos a E3B
cfg.hidden = 64;
cfg.gamma = 0.99;
cfg.gaeLambda = 0.95;
cfg.rolloutLength = 1024;
cfg.epochs = 4;
cfg.minibatch = 64;
cfg.clip = 0.2;
cfg.entropyWeight = 0.01;
cfg.actorLR = 3e-4;
cfg.criticLR = 1e-3;
cfg.adamBeta1 = 0.9;
cfg.adamBeta2 = 0.999;
cfg.adamEpsilon = 1e-8;
cfg.gradientLimit = 0.5;
cfg.advantageNormalization = true;
cfg.observationNormalization = "HISTORICAL_ONLY";
cfg.rewardNormalization = false;
cfg.maxSteps = 50;

% Directorio de salida
cfg.outputParent = fullfile(root, "results", "e4_final_development");
cfg.monitorType = "trainingProgressMonitor";
cfg.plots = "custom-training-progress-monitor";
cfg.fullTrainingResumeAvailable = false;
cfg.referenceContractValidated = false;
cfg.hardwareAuthorized = false;
end
