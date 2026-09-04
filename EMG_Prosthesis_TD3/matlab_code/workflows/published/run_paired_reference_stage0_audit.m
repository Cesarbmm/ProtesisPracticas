function results = run_paired_reference_stage0_audit(options)
%run_paired_reference_stage0_audit ETAPA E0 de la linea paired-reference.
%
%   Auditoria de planta y de dataset. NO entrena, NO crea agentes y NO
%   modifica ningun archivo del repositorio. Solo lee, mide y reporta.
%
%   results = run_paired_reference_stage0_audit()
%   results = run_paired_reference_stage0_audit(part="plant")
%   results = run_paired_reference_stage0_audit(part="dataset")
%
%   Bloques:
%     E0.0  interfaz de la dinamica -> clase y tamano de ws, clamp de idx
%     E0.1  sanity de planta        -> monotonicidad, saltos, cross-talk
%     E0.2  inventario del dataset  -> 12 sujetos, tamanos, desfases, metadata
%     E0.3  rango de lag            -> acota k para el target desplazado
%
%   HIPOTESIS QUE E0.0 EXISTE PARA CONFIRMAR O REFUTAR
%   En fit_C2.mat, params.(sp).(dir).(m).ws es un objeto cfit (Curve Fitting
%   Toolbox), no un vector muestreado. Por tanto numel(ws) == 1 y, en
%   prosthesis_simulator.m (main):
%       ws_len = numel(ws)              -> 1
%       useCurveFallback = ws_len == 0  -> false  (el respaldo es codigo muerto)
%       x_0 = max(1, min(tail_length+t, ws_len))            -> 1 siempre
%       idx = max(1, min(round(x_0 + delta_ms*t), ws_len))  -> 1 siempre
%       t_i(t) = ws(idx) = feval(ws, 1)                     -> constante
%   Si es cierto, cualquier comando no nulo teletransporta el motor a una
%   constante que solo depende de (motor, direccion, velocidad), y la
%   prostesis no tiene dinamica. Esta auditoria lo mide; no lo corrige.
%
%   El contrato de splits (E0.4) no se calcula aqui: se decide por regla en
%   PREREGISTRO_E0.md y se congela al terminar E1.

arguments
    options.part (1,1) string {mustBeMember(options.part, ["all" "plant" "dataset"])} = "all"
    options.resultsRoot (1,1) string = ""
    options.gridPoints (1,1) double {mustBeInteger, mustBePositive} = 21
    options.jumpFactor (1,1) double {mustBePositive} = 1.5
    options.trajectoryDuration (1,1) double {mustBePositive} = 3.0
    options.samplingPeriod (1,1) double {mustBePositive} = 0.14
    options.emgSamplingRate (1,1) double {mustBePositive} = 200
    options.gloveSamplingRate (1,1) double {mustBePositive} = 10
    options.lagRecords (1,1) double {mustBeInteger, mustBePositive} = 400
    options.maxLagSeconds (1,1) double {mustBePositive} = 0.4
    options.seed (1,1) double = 20260904
end

% El simulador cachea fit_C2/pattern_curve en variables persistent y las
% carga con ruta relativa. Con varias copias del repo en disco, una sesion
% previa puede dejar cacheados los params de OTRA copia.
try
    clear("functions");
catch
    warning("No se pudo limpiar el cache persistent; reinicia MATLAB si dudas.");
end

here = fileparts(mfilename("fullpath"));      % .../workflows/published
matlabRoot = fileparts(fileparts(here));      % .../matlab_code
projectRoot = fileparts(matlabRoot);
workspaceRoot = fileparts(projectRoot);

addpath(genpath(matlabRoot));
oldDir = cd(matlabRoot);
restoreDir = onCleanup(@() cd(oldDir)); %#ok<NASGU>
clearConfigurablesOverride();

if strlength(options.resultsRoot) > 0
    resultsRoot = char(options.resultsRoot);
else
    resultsRoot = fullfile(workspaceRoot, "Agentes", "paired_reference", "stage0");
end
ensureDirectoryExists(resultsRoot);

configs = configurables();

results = struct();
results.stage = "E0";
results.timestamp = string(datetime("now", Format="yyyy-MM-dd HH:mm:ss"));
results.matlabRoot = string(matlabRoot);
results.resultsRoot = string(resultsRoot);
results.matlabVersion = string(version);
results.options = options;
results.period = configs.period;
results.actionCommandLevels = configs.actionCommandLevels;
results.speeds = configs.speeds;

if options.part == "all" || options.part == "plant"
    fprintf("\n===== E0.0  INTERFAZ DE LA DINAMICA =====\n");
    results.dynamics = auditDynamicsInterface(matlabRoot, configs);

    fprintf("\n===== E0.1  SANITY DE PLANTA =====\n");
    results.plant = auditPlant(results.dynamics, configs, options);
end

if options.part == "all" || options.part == "dataset"
    fprintf("\n===== E0.2  INVENTARIO DEL DATASET =====\n");
    [emg, glove, metadata] = getDataset(configs.dataset, configs.dataset_folder);
    results.dataset = auditDataset(emg, glove, metadata, configs, options);

    fprintf("\n===== E0.3  RANGO DE LAG EMG -> MOVIMIENTO =====\n");
    results.lag = auditLag(emg, glove, configs, options);
end

outFile = fullfile(resultsRoot, "stage0_audit_results.mat");
save(outFile, "results");
fprintf("\nResultados guardados en:\n  %s\n", outFile);
end

%% ########################################################################
%  E0.0  INTERFAZ DE LA DINAMICA
%  ########################################################################
function dyn = auditDynamicsInterface(matlabRoot, configs)

simDir = fullfile(matlabRoot, "src", "@SimController");
fitFile = fullfile(simDir, "fit_C2.mat");
curveFile = fullfile(simDir, "pattern_curve.mat");
assert(isfile(fitFile), "No se encontro %s", fitFile);
assert(isfile(curveFile), "No se encontro %s", curveFile);

fitData = load(fitFile);
dyn = struct();
dyn.simParams = fitData.params;
dyn.tailLength = fitData.tail_length;
dyn.patternCurve = load(curveFile, "avgs").avgs;

% Constantes replicadas de prosthesis_simulator.m (main, lineas 47-48).
dyn.simSpeeds = [0 64 96 128 160 192 224 256];
dyn.speedsTxt = ["sp_zeroF" "sp_3F" "sp_5F" "sp_7F" "sp_9F" "sp_BF" "sp_DF" "sp_FF"];
dyn.dirs = ["closing" "opening"];
dyn.nMotors = 4;

% ------------------------------------------------------ toolbox y ws
% El archivo fit_C2.mat guarda params.(sp).(dir).(m).ws como objeto cfit
% (Curve Fitting Toolbox). Si esa toolbox NO esta disponible, MATLAB no
% puede instanciar la clase y carga ws como [] numerico. Entonces
% numel(ws)==0, se activa el respaldo a pattern_curve y la planta se
% comporta de forma DISTINTA que en una maquina con la toolbox.
% Esto es un problema de reproducibilidad y hay que dejarlo registrado.
dyn.hasCurveFittingToolbox = exist("cfit", "class") == 8;
fprintf("Curve Fitting Toolbox disponible: %d\n", dyn.hasCurveFittingToolbox);

rows = struct("speedTxt", {}, "speedValue", {}, "direction", {}, "motor", {}, ...
    "wsClass", {}, "wsNumel", {}, "wsIsNumeric", {}, "useCurveFallback", {}, ...
    "simulatorWsLen", {}, "idxAlwaysOne", {}, "curveLength", {}, ...
    "curveIsMonotone", {}, "curveFirst", {}, "curveLast", {}, ...
    "minLim", {}, "maxLim", {}, "strokeFractionPerStep", {});

periodMs = configs.period * 1000;

for iSp = 2:numel(dyn.simSpeeds)
    spTxt = dyn.speedsTxt(iSp);
    if ~isfield(dyn.simParams, spTxt)
        warning("fit_C2 no contiene el campo %s", spTxt);
        continue
    end
    for dirName = dyn.dirs
        for m = 1:dyn.nMotors
            mTxt = sprintf("m_%d", m);
            entry = dyn.simParams.(spTxt).(dirName).(mTxt);
            ws = entry.ws;
            curve = dyn.patternCurve.(spTxt).(dirName).(mTxt).avg;
            curve = curve(:);

            wsNumel = numel(ws);
            usesFallback = wsNumel == 0;
            if usesFallback
                simWsLen = numel(curve);   % el simulador hace ws = curve
            else
                simWsLen = wsNumel;
            end

            dy = diff(curve);
            if dirName == "closing"
                curveMonotone = all(dy >= -1e-9);
            else
                curveMonotone = all(dy <= 1e-9);
            end

            rows(end+1) = struct( ...
                "speedTxt", spTxt, ...
                "speedValue", dyn.simSpeeds(iSp), ...
                "direction", dirName, ...
                "motor", m, ...
                "wsClass", string(class(ws)), ...
                "wsNumel", wsNumel, ...
                "wsIsNumeric", isnumeric(ws), ...
                "useCurveFallback", usesFallback, ...
                "simulatorWsLen", simWsLen, ...
                "idxAlwaysOne", simWsLen <= 1, ...
                "curveLength", numel(curve), ...
                "curveIsMonotone", curveMonotone, ...
                "curveFirst", curve(1), ...
                "curveLast", curve(end), ...
                "minLim", entry.min_lim, ...
                "maxLim", entry.max_lim, ...
                "strokeFractionPerStep", periodMs / numel(curve)); %#ok<AGROW>
        end
    end
end

dyn.map = struct2table(rows);
dyn.nCombinations = height(dyn.map);
dyn.nNumericWs = sum(dyn.map.wsIsNumeric);
dyn.nCurveFallback = sum(dyn.map.useCurveFallback);
dyn.nIdxCollapsed = sum(dyn.map.idxAlwaysOne);
dyn.nCurveNonMonotone = sum(~dyn.map.curveIsMonotone);
dyn.wsClasses = unique(dyn.map.wsClass);

fprintf("Combinaciones (velocidad x direccion x motor): %d\n", dyn.nCombinations);
fprintf("Clases de ws segun MATLAB: %s\n", strjoin(dyn.wsClasses(:)', ", "));
fprintf("ws vacio -> respaldo a pattern_curve : %d de %d\n", ...
    dyn.nCurveFallback, dyn.nCombinations);
fprintf("ws_len efectivo <= 1 (idx colapsa)   : %d\n", dyn.nIdxCollapsed);
fprintf("curvas de referencia NO monotonas    : %d\n", dyn.nCurveNonMonotone);

if dyn.nCurveFallback == dyn.nCombinations && ~dyn.hasCurveFittingToolbox
    fprintf("\n*** AVISO DE REPRODUCIBILIDAD ***\n");
    fprintf("Las 56 entradas cargan ws como vacio y esta MATLAB no tiene\n");
    fprintf("Curve Fitting Toolbox. En una maquina que si la tenga, ws seria\n");
    fprintf("un objeto cfit con numel(ws)=1, el respaldo NO se activaria y el\n");
    fprintf("clamp min(idx, ws_len) dejaria la trayectoria constante.\n");
    fprintf("La fisica de la planta depende de las toolboxes instaladas.\n");
    fprintf("Registrar la configuracion de toolboxes junto a cada resultado.\n");
end

% ------------------------------------- resolucion del paso de control
fprintf("\nFraccion del recorrido que cubre un paso de control (%.2f s):\n", configs.period);
for dirName = dyn.dirs
    sel = dyn.map.direction == dirName & dyn.map.motor == 1;
    sub = sortrows(dyn.map(sel, ["speedValue" "curveLength" "strokeFractionPerStep"]), "speedValue");
    for i = 1:height(sub)
        fprintf("  %s PWM~%3d : curva %4d ms -> %5.1f %% del recorrido\n", ...
            dirName, sub.speedValue(i), sub.curveLength(i), 100*sub.strokeFractionPerStep(i));
    end
end
dyn.maxStrokeFractionPerStep = max(dyn.map.strokeFractionPerStep);
fprintf("Peor caso: un solo paso cubre el %.1f %% del recorrido completo.\n", ...
    100*dyn.maxStrokeFractionPerStep);
end

%% ########################################################################
%  E0.1  PLANTA
%  ########################################################################
function plant = auditPlant(dyn, configs, options)

levels = configs.actionCommandLevels(configs.actionCommandLevels > 0);
levels = levels(:)';
midPos = midPositions(dyn, dyn.nMotors);
nMotors = dyn.nMotors;
tol = 1e-9;

% ------------------------------------------------ snapping de comandos
snapRows = struct("level", {}, "snapped", {}, "exact", {}, "fieldExists", {});
for L = levels
    s = snapSpeed(L, dyn.simSpeeds);
    txt = dyn.speedsTxt(dyn.simSpeeds == s);
    snapRows(end+1) = struct("level", L, "snapped", s, "exact", s == L, ...
        "fieldExists", isfield(dyn.simParams, txt)); %#ok<AGROW>
end
plant.speedSnapping = struct2table(snapRows);
plant.nInexactLevels = sum(~plant.speedSnapping.exact);
plant.nMissingSpeedFields = sum(~plant.speedSnapping.fieldExists);
fprintf("Niveles PWM que no caen exactos en SIM_SPEEDS: %d\n", plant.nInexactLevels);
fprintf("Niveles PWM sin curva en fit_C2              : %d\n", plant.nMissingSpeedFields);
disp(plant.speedSnapping);

% ---------------------------------------------------- barrido de sanidad
% Para cada motor x nivel x signo x posicion inicial x duracion:
%   closing => q no decrece   |   opening => q no crece
%   los otros tres motores no se mueven
%   ningun paso supera jumpFactor x el mayor avance que la curva de
%   referencia hace en el mismo numero de milisegundos
durations = [configs.period, options.trajectoryDuration];
nCases = nMotors * numel(levels) * 2 * options.gridPoints * numel(durations);

template = struct("motor", 0, "level", 0, "sign", 0, "position", 0, ...
    "duration", 0, "monotonic", false, "crossTalk", false, "maxStep", 0, ...
    "refStep", 0, "jumpFlag", false, "netDisplacement", 0, ...
    "finalPosition", 0, "constantTrajectory", false);
rows = repmat(template, nCases, 1);
k = 0;

for m = 1:nMotors
    mTxt = sprintf("m_%d", m);
    for L = levels
        snapped = snapSpeed(L, dyn.simSpeeds);
        spTxt = dyn.speedsTxt(dyn.simSpeeds == snapped);
        for sgn = [1 -1]
            if sgn > 0
                dirName = "closing";
            else
                dirName = "opening";
            end
            entry = dyn.simParams.(spTxt).(dirName).(mTxt);
            curve = dyn.patternCurve.(spTxt).(dirName).(mTxt).avg;
            posGrid = linspace(entry.min_lim, entry.max_lim, options.gridPoints);

            for d = durations
                nPoints = round(d / options.samplingPeriod);
                assert(nPoints >= 1, ...
                    "duration/samplingPeriod < 1: el simulador no produciria muestras.");
                deltaMs = d * 1000 / nPoints;
                refStep = referenceStep(curve, deltaMs);

                for p = posGrid
                    initial = midPos;
                    initial(m) = p;
                    speedVector = zeros(1, nMotors);
                    speedVector(m) = sgn * L;

                    traj = SimController.prosthesis_simulator( ...
                        initial, speedVector, d, options.samplingPeriod);

                    series = traj(:, m);
                    deltas = diff([initial(m); series]);
                    if sgn > 0
                        monotonic = all(deltas >= -tol);
                    else
                        monotonic = all(deltas <= tol);
                    end

                    others = setdiff(1:nMotors, m);
                    crossTalk = any(abs(traj(:, others) - initial(others)) > tol, "all");

                    maxStep = max(abs(deltas));
                    jumpFlag = refStep > 0 && maxStep > options.jumpFactor * refStep;

                    k = k + 1;
                    rows(k) = struct("motor", m, "level", L, "sign", sgn, ...
                        "position", p, "duration", d, "monotonic", monotonic, ...
                        "crossTalk", crossTalk, "maxStep", maxStep, ...
                        "refStep", refStep, "jumpFlag", jumpFlag, ...
                        "netDisplacement", series(end) - initial(m), ...
                        "finalPosition", series(end), ...
                        "constantTrajectory", all(abs(diff(series)) <= tol));
                end
            end
        end
    end
end

plant.sweep = struct2table(rows(1:k));
plant.nSweep = k;
plant.nMonotonicityFailures = sum(~plant.sweep.monotonic);
plant.nCrossTalk = sum(plant.sweep.crossTalk);
plant.nJumpFlags = sum(plant.sweep.jumpFlag);
plant.nConstantTrajectories = sum(plant.sweep.constantTrajectory);
plant.nZeroDisplacement = sum(abs(plant.sweep.netDisplacement) < tol);

fprintf("\nBarrido de sanidad: %d casos\n", plant.nSweep);
fprintf("  fallos de monotonicidad  : %d\n", plant.nMonotonicityFailures);
fprintf("  movimiento cruzado       : %d\n", plant.nCrossTalk);
fprintf("  saltos > %.2f x referencia: %d\n", options.jumpFactor, plant.nJumpFlags);
fprintf("  trayectorias constantes  : %d\n", plant.nConstantTrajectories);
fprintf("  desplazamiento nulo      : %d\n", plant.nZeroDisplacement);

% La prueba decisiva de "la planta no tiene dinamica": la posicion final
% no debe depender de la posicion inicial.
finalSpread = groupSpread(plant.sweep);
plant.finalPositionSpread = finalSpread;
plant.nInvariantFinalPosition = sum(finalSpread.spread <= tol);
fprintf("\nGrupos (motor, nivel, signo, duracion): %d\n", height(finalSpread));
fprintf("  con posicion final independiente de la inicial: %d\n", ...
    plant.nInvariantFinalPosition);
if plant.nInvariantFinalPosition == height(finalSpread)
    fprintf("  => la planta NO integra: teletransporta a un valor fijo.\n");
end

plant.gatePassed = plant.nMonotonicityFailures == 0 && plant.nCrossTalk == 0 && ...
    plant.nJumpFlags == 0;
if plant.gatePassed
    fprintf("\nGATE E0.1: PASA. La planta de main es consistente en el barrido.\n");
else
    fprintf("\nGATE E0.1: FALLA. Ver plant.sweep. No se pasa a E1 sin corregir.\n");
end
end

%% ------------------------------------------------------------------------
function mid = midPositions(dyn, nMotors)
%midPositions punto medio del recorrido de cada motor (union de limites).
mid = zeros(1, nMotors);
for m = 1:nMotors
    sel = dyn.map.motor == m;
    mid(m) = (min(dyn.map.minLim(sel)) + max(dyn.map.maxLim(sel))) / 2;
end
end

%% ------------------------------------------------------------------------
function refStep = referenceStep(curve, deltaMs)
%referenceStep mayor avance de la curva de referencia en deltaMs muestras.
% pattern_curve esta muestreada a 1 ms, asi que deltaMs indices equivalen al
% avance que el simulador pretende hacer en un paso.
curve = curve(:);
step = max(1, round(deltaMs));
if numel(curve) > step
    refStep = max(abs(curve(1+step:end) - curve(1:end-step)));
else
    refStep = max(curve) - min(curve);
end
end

%% ------------------------------------------------------------------------
function out = groupSpread(sweep)
%groupSpread dispersion de la posicion final dentro de cada grupo
% (motor, nivel, signo, duracion). Si es cero, la posicion inicial no
% influye en el resultado: la planta no integra.
keys = unique(sweep(:, ["motor" "level" "sign" "duration"]));
spread = zeros(height(keys), 1);
for i = 1:height(keys)
    sel = sweep.motor == keys.motor(i) & sweep.level == keys.level(i) & ...
        sweep.sign == keys.sign(i) & sweep.duration == keys.duration(i);
    v = sweep.finalPosition(sel);
    spread(i) = max(v) - min(v);
end
out = keys;
out.spread = spread;
end

%% ------------------------------------------------------------------------
function spSnapped = snapSpeed(sp, SIM_SPEEDS)
%snapSpeed replica el bloque de seleccion de velocidad del simulador.
sp = abs(sp);
spSnapped = SIM_SPEEDS(end);
for i2 = 2:numel(SIM_SPEEDS)
    b = SIM_SPEEDS(i2);
    a = SIM_SPEEDS(i2 - 1);
    if sp <= b
        if sp >= a
            r = (sp - a)/(b - a);
            if r >= 0.5
                spSnapped = b;
            else
                spSnapped = a;
            end
        else
            spSnapped = 0;
        end
        return
    end
end
end

%% ########################################################################
%  E0.2  DATASET
%  ########################################################################
function ds = auditDataset(emg, glove, metadata, configs, options)

ds = struct();
ds.subjects = string(configs.dataset(:))';
ds.nSubjects = numel(ds.subjects);
ds.emgSize = size(emg);
ds.gloveSize = size(glove);

fprintf("Sujetos: %d  ->  %s\n", ds.nSubjects, strjoin(ds.subjects, ", "));
fprintf("emg   : %d x %d cell\n", ds.emgSize(1), ds.emgSize(2));
fprintf("glove : %d x %d cell\n", ds.gloveSize(1), ds.gloveSize(2));
assert(isequal(size(emg), size(glove)), ...
    "emg y glove tienen tamanos distintos: el contrato del dataset no se cumple.");

nTotal = numel(emg);
template = struct("record", 0, "column", 0, "emgSamples", 0, "emgChannels", 0, ...
    "gloveSamples", 0, "emgSeconds", 0, "gloveSeconds", 0, "deltaSeconds", 0);
rows = repmat(template, nTotal, 1);
k = 0;

for r = 1:size(emg, 1)
    for c = 1:size(emg, 2)
        e = emg{r, c};
        if isempty(e)
            continue
        end
        nE = size(e, 1);
        nG = countRows(glove{r, c});
        k = k + 1;
        rows(k) = struct("record", r, "column", c, "emgSamples", nE, ...
            "emgChannels", size(e, 2), "gloveSamples", nG, ...
            "emgSeconds", nE / options.emgSamplingRate, ...
            "gloveSeconds", nG / options.gloveSamplingRate, ...
            "deltaSeconds", nE / options.emgSamplingRate - nG / options.gloveSamplingRate);
    end
end

ds.records = struct2table(rows(1:k));
ds.nPairs = k;

fprintf("\nPares gesto/lado inventariados: %d\n", ds.nPairs);
fprintf("Muestras EMG    min/med/max: %d / %d / %d\n", ...
    min(ds.records.emgSamples), round(median(ds.records.emgSamples)), max(ds.records.emgSamples));
fprintf("Canales EMG     unicos     : %s\n", mat2str(unique(ds.records.emgChannels)'));
fprintf("Muestras guante min/med/max: %d / %d / %d\n", ...
    min(ds.records.gloveSamples), round(median(ds.records.gloveSamples)), max(ds.records.gloveSamples));
fprintf("Desfase EMG-guante [s] med/max: %.4f / %.4f\n", ...
    median(ds.records.deltaSeconds), max(ds.records.deltaSeconds));
fprintf("Registros con guante mas corto: %d de %d\n", ...
    sum(ds.records.deltaSeconds > 0), ds.nPairs);

% ------------------------------------------------------ metadata real
% getDataset hace metadata.(nombre) = vars.metadata, y el .mat ya guarda
% metadata como struct con un campo homonimo: queda doblemente anidado.
metaFields = string([]);
for s = string(fieldnames(metadata))'
    inner = metadata.(s);
    if isstruct(inner) && numel(fieldnames(inner)) == 1 && isfield(inner, s) ...
            && isstruct(inner.(s))
        inner = inner.(s);
    end
    metaFields = unique([metaFields, string(fieldnames(inner))']);
end
ds.metadataFields = metaFields;
fprintf("\nCampos reales de metadata: %s\n", strjoin(metaFields, ", "));

forbidden = ["rest" "reposo" "idle" "mvc" "p95" "calib" "baseline" "oppos"];
hits = metaFields(arrayfun(@(f) any(contains(lower(f), forbidden)), metaFields));
ds.restRelatedFields = hits;
ds.hasLabelledRest = ~isempty(hits);

if ds.hasLabelledRest
    fprintf("ATENCION: campos que podrian indicar reposo/calibracion: %s\n", ...
        strjoin(hits, ", "));
else
    fprintf("CONFIRMADO: metadata no contiene reposo etiquetado, MVC/P95 ni\n");
    fprintf("            calibracion por sesion. Solo pares closing/opening.\n");
end
end

%% ------------------------------------------------------------------------
function n = countRows(x)
if isempty(x)
    n = 0;
elseif isstruct(x)
    n = numel(x);
else
    n = size(x, 1);
end
end

%% ########################################################################
%  E0.3  LAG
%  ########################################################################
function lag = auditLag(emg, glove, configs, options)

scaler = configurables("flexJoined_scale");
ratio = round(options.emgSamplingRate / options.gloveSamplingRate);
maxLagSamples = max(1, round(options.maxLagSeconds * options.gloveSamplingRate));
minSamples = 4 * maxLagSamples;

rng(options.seed, "twister");
[rIdx, cIdx] = ndgrid(1:size(emg, 1), 1:size(emg, 2));
allIdx = [rIdx(:), cIdx(:)];
pick = allIdx(randperm(size(allIdx, 1), min(options.lagRecords, size(allIdx, 1))), :);

lagSamples = nan(size(pick, 1), 1);
usable = false(size(pick, 1), 1);

for k = 1:size(pick, 1)
    e = emg{pick(k, 1), pick(k, 2)};
    g = glove{pick(k, 1), pick(k, 2)};
    if isempty(e) || countRows(g) < 4
        continue
    end

    envelope = mean(abs(double(e)), 2);
    envelopeR = resample(envelope, 1, ratio);
    % El guante da velocidad por diferencias: centramos la envolvente en el
    % mismo instante para no introducir medio paso de sesgo sistematico.
    if numel(envelopeR) < 2
        continue
    end
    envMid = (envelopeR(1:end-1) + envelopeR(2:end)) / 2;

    flex = scaler(reduceFlexDimension(g));
    speed = sum(abs(diff(flex, 1, 1)), 2);

    n = min(numel(envMid), numel(speed));
    if n < minSamples
        continue
    end
    a = envMid(1:n) - mean(envMid(1:n));
    b = speed(1:n) - mean(speed(1:n));
    if std(a) < eps || std(b) < eps
        continue
    end

    lagSamples(k) = finddelay(a, b, maxLagSamples);
    usable(k) = true;
end

lag = struct();
lag.nAttempted = size(pick, 1);
lag.nUsable = sum(usable);
lag.minSamplesRequired = minSamples;
lag.maxLagSamples = maxLagSamples;
lag.samples = lagSamples(usable);
lag.seconds = lag.samples / options.gloveSamplingRate;
lag.controlSteps = lag.seconds / configs.period;
lag.percentilesControlSteps = nan(1, 5);
lag.kRange = [NaN NaN];

fprintf("Registros usables: %d de %d (minimo %d muestras, lag maximo +-%d)\n", ...
    lag.nUsable, lag.nAttempted, minSamples, maxLagSamples);

if lag.nUsable < 30
    fprintf("Muestra insuficiente para acotar k con confianza.\n");
    fprintf("Los registros duran ~2 s; la resolucion del guante es 0.1 s.\n");
    fprintf("Recomendacion: fijar el rango de k por barrido en E1, no aqui.\n");
    return
end

q = localPercentiles(lag.controlSteps, [10 25 50 75 90]);
lag.percentilesControlSteps = q;
lag.kRange = [floor(q(1)), ceil(q(5))];

fprintf("Lag [s]   mediana : %+.3f\n", median(lag.seconds));
fprintf("Lag [pasos de control de %.2f s]\n", configs.period);
fprintf("  p10 %+.2f | p25 %+.2f | p50 %+.2f | p75 %+.2f | p90 %+.2f\n", q);
fprintf("\nRango propuesto para el barrido de k en E1: [%d, %d]\n", ...
    lag.kRange(1), lag.kRange(2));
fprintf("Es una cota, no una estimacion fina: %d registros de ~2 s a 10 Hz.\n", lag.nUsable);
end

%% ------------------------------------------------------------------------
function p = localPercentiles(x, pcts)
%localPercentiles percentiles sin depender de Statistics Toolbox.
x = sort(x(:));
n = numel(x);
if n == 0
    p = nan(size(pcts));
    return
end
pos = (pcts(:)' / 100) * (n - 1) + 1;
lo = floor(pos);
hi = ceil(pos);
w = pos - lo;
p = reshape(x(lo)' .* (1 - w) + x(hi)' .* w, size(pcts));
end
