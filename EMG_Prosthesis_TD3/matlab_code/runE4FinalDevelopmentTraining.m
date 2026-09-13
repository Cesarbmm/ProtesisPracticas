function summary = runE4FinalDevelopmentTraining(options)
% runE4FinalDevelopmentTraining entrena el agente final de desarrollo E4
% sobre los 10 sujetos DEVELOPMENT disponibles, con receta y arquitectura E3B,
% exactamente 500,000 pasos de agente y checkpoint final al paso 500,000.
%
% Uso manual en MATLAB Desktop:
%   cd('C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit\EMG_Prosthesis_TD3\matlab_code');
%   summary = runE4FinalDevelopmentTraining();

arguments
    options.mode (1, 1) string {mustBeMember(options.mode, ["long", "smoke"])} = "long";
end

root = string(fileparts(mfilename("fullpath")));
pr = fullfile(root, "analysis", "paired_reference");
e4Dir = fullfile(pr, "e4");

if options.mode == "long"
    assert(usejava('desktop'), "E4:DesktopRequired", "Abrir MATLAB Desktop para la corrida de entrenamiento larga.");
end

oldPath = path; oldDir = pwd; oldRng = rng;
oldOverride = struct();
if isappdata(0, "configurables_override")
    oldOverride = getappdata(0, "configurables_override");
end
cleanup = onCleanup(@() restoreContext(oldPath, oldDir, oldRng, oldOverride)); %#ok<NASGU>

addpath(root, pr, fullfile(pr, "e3ax"), fullfile(pr, "e3b"), e4Dir, fullfile(pr, "cap192"), fullfile(root, "config"));
addpath(genpath(fullfile(root, "src")));
addpath(genpath(fullfile(root, "lib")));
cd(root);

assert(~contains(lower(string(path)), "sandbox"), "E4:SandboxPathForbidden", "No agregar sandbox al path.");

% 1. Configuracion y auditoria E3B
cfg = e4Config(options.mode);
clearConfigurablesOverride();
bc = e3axConfig(options.mode);
bc.seed = cfg.seed;
bc.trainSubjects = cfg.trainSubjects;
o = e3axOverride(bc);
o.dataset = cellstr(cfg.trainSubjects);
setConfigurablesOverride(o);

auditRep = e4AuditAgainstE3B();
fprintf("Auditoria E4 vs E3B superada con exito.\n");

% 2. Crear directorio de salida
stamp = string(datetime('now', Format='yyyyMMdd_HHmmss_SSS'));
id = string(java.util.UUID.randomUUID());
out = fullfile(cfg.outputParent, "run_" + stamp + "_" + extractBefore(id, 9));
assert(~isfolder(out), "E4:OutputFolderExists", "El directorio ya existe.");
mkdir(out);
mkdir(fullfile(out, "checkpoints"));

diary(fullfile(out, "diary.log"));
dc = onCleanup(@() diary('off')); %#ok<NASGU>

save(fullfile(out, "config.mat"), "cfg", "o");
e2cWriteJSON(fullfile(out, "config.json"), cfg);
e2cWriteJSON(fullfile(out, "split.json"), struct( ...
    "TRAIN", cfg.trainSubjects, ...
    "VALIDATION", cfg.validationSubjects, ...
    "SEALED", cfg.sealedSubjects));
writematrix(cfg.seed, fullfile(out, "seed.txt"));
writeText(fullfile(out, "STARTED.txt"), "E4 " + cfg.mode + " iniciado. 10 sujetos DEVELOPMENT en TRAIN. MATEO/SANDRA sellados.");

manifest = pairedReferencePlantManifest(plantSource="patternCurveCanonical", outputPath=fullfile(out, "plant_manifest.json"));
manifest.preregistrationE4SHA256 = cap192SHA256(fullfile(fileparts(root), "docs", "paired_reference", "PREREGISTRO_E4_FINAL_DEVELOPMENT.md"));
manifest.preregistrationSealedTestSHA256 = cap192SHA256(fullfile(fileparts(root), "docs", "paired_reference", "PREREGISTRO_FINAL_SEALED_TEST.md"));
e2cWriteJSON(fullfile(out, "manifest.json"), manifest);

fprintf("=== E4 Final Development Training (%s) ===\n", cfg.mode);
fprintf("Salida: %s\n", out);
fprintf("Semilla: %d | Max agent steps: %d\n", cfg.seed, cfg.maxAgentSteps);

% 3. Monitor de progreso (sin ValidationMSE artificial)
monitor = [];
if usejava('desktop')
    monitor = trainingProgressMonitor( ...
        Metrics=["EpisodeReward", "AverageReward", "ActorLoss", "CriticLoss"], ...
        Info=["Episode", "AgentSteps"], ...
        XLabel="Agent steps");
    setappdata(0, "E4TrainingMonitor_" + extractBefore(id, 9), monitor);
end

try
    % 4. Cargar datos (10 sujetos DEVELOPMENT, MATEO/SANDRA no abiertos)
    data = e4LoadData(cfg, out);
    rng(cfg.seed, 'twister');

    [actor, critic] = e3bNetworks(cfg);
    initialActor = actor;
    initialCritic = critic;
    save(fullfile(out, "initial_networks.mat"), "initialActor", "initialCritic");

    opt = struct("iteration", 0, "actorAverage", [], "actorSquared", [], ...
                 "criticAverage", [], "criticSquared", []);

    env = E3BTrainingEnv(data.emgs, data.gloves);
    state = reset(env);

    episode = 1;
    completed = 0;
    steps = 0;
    episodeSteps = 0;
    episodeReward = 0;
    episodeV0 = value(critic, state);

    logs = {};
    updates = {};
    buffer = emptyBuffer();
    episodeDone = false;
    headGradientMax = zeros(1, 4);
    recentRewards = [];
    recentLengths = [];
    samplingRecords = {};

    while true
        if ~isempty(monitor) && monitor.Stop
            error("E4:UserStopped", "Interrupcion manual solicitada; checkpoints guardados se conservan.");
        end

        if episodeDone
            state = reset(env);
            episode = episode + 1;
            episodeSteps = 0;
            episodeReward = 0;
            episodeV0 = value(critic, state);
            episodeDone = false;
        end

        v = value(critic, state);
        [category, lp, entropy] = e3bSample(actor, state);
        [next, reward, done, record] = step(env, category);
        nv = value(critic, next);

        steps = steps + 1;
        episodeSteps = episodeSteps + 1;
        episodeReward = episodeReward + reward;

        k = numel(buffer.reward) + 1;
        buffer.state(:, k) = state;
        buffer.nextState(:, k) = next;
        buffer.category(:, k) = category;
        buffer.logp(k) = lp;
        buffer.value(k) = v;
        buffer.nextValue(k) = nv;
        buffer.reward(k) = reward;
        buffer.done(k) = done;
        buffer.pwm(:, k) = record.pwm;
        buffer.previousEffective(:, k) = record.previousEffective;
        buffer.reference(:, k) = record.reference';
        buffer.prediction(:, k) = record.prediction';
        buffer.qBefore(:, k) = record.qBefore';
        buffer.qAfter(:, k) = record.q';
        buffer.headEntropy(:, k) = entropy;
        buffer.step(k) = steps;
        buffer.episode(k) = episode;
        buffer.policyVersion(k) = opt.iteration;

        state = next;
        episodeDone = done;
        assert(episodeSteps <= cfg.maxSteps, "E4:Horizon", "Teacher excede horizonte maximo.");

        if done
            completed = completed + 1;
            repId = env.Historical.repetitionId;
            if repId >= 1 && repId <= height(data.trainingInventory)
                activeSubj = string(data.trainingInventory.subject(repId));
                activeSide = double(data.trainingInventory.side(repId));
            else
                activeSubj = cfg.trainSubjects(mod(completed - 1, numel(cfg.trainSubjects)) + 1);
                activeSide = 1 + mod(completed, 2);
            end
            samplingRecords{end+1} = struct("subject", activeSubj, "side", activeSide, "steps", episodeSteps); %#ok<AGROW>
        end

        sched = e4Schedule(cfg, steps, completed, done, k);
        stop = sched.stop;
        checkpoint = sched.checkpoint;

        if done || stop
            recentRewards = [recentRewards episodeReward]; %#ok<AGROW>
            recentLengths = [recentLengths episodeSteps]; %#ok<AGROW>
            keep = max(1, numel(recentRewards) - 99):numel(recentRewards);
            recentRewards = recentRewards(keep);
            recentLengths = recentLengths(keep);

            row = struct("EpisodeIndex", episode, "EpisodeReward", episodeReward, ...
                "AverageReward", mean(recentRewards), "EpisodeSteps", episodeSteps, ...
                "AverageSteps", mean(recentLengths), "EpisodeV0", episodeV0, ...
                "TotalAgentSteps", steps, "TeacherDone", done, "BudgetTruncated", stop && ~done);
            logs{end+1} = row; %#ok<AGROW>
            appendTable(fullfile(out, "training_incremental.csv"), struct2table(row));

            if cfg.mode == "smoke" || mod(episode, 100) == 0
                fprintf("Episodio %d | pasos %d | reward %.4f | total pasos %d\n", episode, episodeSteps, episodeReward, steps);
            end
        end

        if sched.update
            assert(numel(unique(buffer.policyVersion)) == 1, "E4:OnPolicy", "El actor cambio durante el rollout.");
            [actor, critic, opt, info] = e3bUpdate(actor, critic, opt, buffer, cfg);
            headGradientMax = max(headGradientMax, info.headGradientMax);
            info.firstStep = buffer.step(1);
            info.lastStep = steps;
            info.episode = episode;
            updates{end+1} = info; %#ok<AGROW>
            appendTable(fullfile(out, "update_stats.csv"), struct2table(info));

            lastRollout = buffer;
            save(fullfile(out, "last_rollout.mat"), "lastRollout", "-v7.3");

            if ~isempty(monitor)
                recordMetrics(monitor, steps, ...
                    EpisodeReward=episodeReward, ...
                    AverageReward=mean(recentRewards), ...
                    ActorLoss=info.actorLoss, ...
                    CriticLoss=info.criticLoss);
                updateInfo(monitor, Episode=episode, AgentSteps=steps);
                if cfg.mode == "smoke"
                    monitor.Progress = 100 * completed / cfg.smokeEpisodes;
                else
                    monitor.Progress = 100 * steps / cfg.maxAgentSteps;
                end
            end

            if checkpoint
                cpFile = fullfile(out, "checkpoints", compose("CategoricalStep%09d.mat", steps));
                saved_actor = E3BCategoricalActor(actor);
                saved_critic = critic;
                saved_config = cfg;
                save(cpFile, "saved_actor", "saved_critic", "saved_config", "steps", "episode", "opt");
                fprintf("Checkpoint guardado: %s\n", cpFile);
            end

            buffer = emptyBuffer();
        end

        if stop, break; end
    end

    % 5. Consolidar entrenamiento
    trainingStats = struct2table([logs{:}]);
    updateStats = struct2table([updates{:}]);
    save(fullfile(out, "trainingStats.mat"), "trainingStats", "updateStats", "-v7.3");
    save(fullfile(out, "updateStats.mat"), "updateStats", "-v7.3");

    learning = struct( ...
        "actorChanged", ~isequaln(initialActor.Learnables.Value, actor.Learnables.Value), ...
        "criticChanged", ~isequaln(initialCritic.Learnables.Value, critic.Learnables.Value), ...
        "headGradientMax", headGradientMax, ...
        "allHeadsReceivedGradient", all(headGradientMax > 0), ...
        "updates", opt.iteration);
    e2cWriteJSON(fullfile(out, "learning_check.json"), learning);
    assert(learning.actorChanged && learning.criticChanged && learning.allHeadsReceivedGradient, ...
        "E4:NoLearning", "El actor, critic y las 4 cabezas deben recibir gradientes.");

    % 6. Auditoria de muestreo por sujeto
    samplingTable = e4AuditSampling([samplingRecords{:}], out);

    % 7. Congelar FINAL_AGENT (checkpoint al paso 500,000)
    finalAgentFile = fullfile(out, "checkpoints", compose("CategoricalStep%09d.mat", cfg.finalAgentStep));
    if ~isfile(finalAgentFile)
        % Guardar el estado final al paso final
        saved_actor = E3BCategoricalActor(actor);
        saved_critic = critic;
        saved_config = cfg;
        save(finalAgentFile, "saved_actor", "saved_critic", "saved_config", "steps", "episode", "opt");
    end
    finalAgentSHA = cap192SHA256(finalAgentFile);

    % Copiar a FINAL_AGENT.mat
    finalMasterFile = fullfile(out, "FINAL_AGENT.mat");
    copyfile(finalAgentFile, finalMasterFile);

    writeText(fullfile(out, "FINAL_AGENT_SHA256.txt"), finalAgentSHA);
    writeText(fullfile(out, "TRAINING_COMPLETED.txt"), "Training E4 completado exitosamente.");

    summary = struct( ...
        "status", "COMPLETED", ...
        "mode", cfg.mode, ...
        "outputDirectory", out, ...
        "episodes", episode, ...
        "completedEpisodes", completed, ...
        "agentSteps", steps, ...
        "finalAgentStep", cfg.finalAgentStep, ...
        "finalAgentFile", finalAgentFile, ...
        "finalAgentSHA256", finalAgentSHA, ...
        "checkpointSelection", "NONE", ...
        "learning", learning, ...
        "auditE3B", auditRep, ...
        "sealedSubjectsUntouched", true, ...
        "longTrainingStartedByAI", false, ...
        "referenceContractValidated", false, ...
        "hardwareAuthorized", false);

    e2cWriteJSON(fullfile(out, "summary.json"), summary);
    save(fullfile(out, "summary.mat"), "summary");
    writeText(fullfile(out, "COMPLETED.txt"), "E4 final development completado exitosamente.");

    if cfg.mode == "smoke"
        writeText(fullfile(pr, "e4_results", "smoke_path.txt"), out);
    end

    fprintf("E4 (%s) finalizado exitosamente. Salida: %s\n", cfg.mode, out);

catch ex
    writeText(fullfile(out, "FAILED.txt"), string(getReport(ex, 'extended', 'hyperlinks', 'off')));
    rethrow(ex);
end
end

function b = emptyBuffer()
b = struct("state", zeros(52, 0), "nextState", zeros(52, 0), "category", zeros(4, 0), ...
    "logp", zeros(1, 0), "value", zeros(1, 0), "nextValue", zeros(1, 0), ...
    "reward", zeros(1, 0), "done", false(1, 0), "pwm", zeros(4, 0), ...
    "previousEffective", zeros(4, 0), "reference", zeros(4, 0), "prediction", zeros(4, 0), ...
    "qBefore", zeros(4, 0), "qAfter", zeros(4, 0), "headEntropy", zeros(4, 0), ...
    "step", zeros(1, 0), "episode", zeros(1, 0), "policyVersion", zeros(1, 0));
end

function v = value(net, s)
v = double(extractdata(forward(net, dlarray(single(s), "CB"))));
assert(isfinite(v), "E4:ValueNonFinite", "Valor no finito.");
end

function appendTable(file, T)
if isfile(file)
    writetable(T, file, WriteMode="append", WriteVariableNames=false);
else
    writetable(T, file);
end
end

function writeText(file, str)
f = fopen(file, 'w', 'n', 'UTF-8');
assert(f >= 0, "E4:FileWrite", "No se pudo abrir %s", file);
c = onCleanup(@() fclose(f));
fprintf(f, '%s', str);
end

function restoreContext(p, d, r, o)
setConfigurablesOverride(o);
rng(r);
cd(d);
path(p);
end
