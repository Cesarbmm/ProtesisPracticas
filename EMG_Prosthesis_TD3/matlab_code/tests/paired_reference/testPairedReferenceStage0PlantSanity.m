function tests = testPairedReferenceStage0PlantSanity
%testPairedReferenceStage0PlantSanity gates bloqueantes de la ETAPA E0.
%
%   Ejecutar con:
%       runtests("tests/paired_reference/testPairedReferenceStage0PlantSanity")
%
%   No entrena, no crea agentes y no escribe nada. Llama al simulador como
%   funcion pura y verifica invariantes fisicas.
%
%   E0P separa el gate operativo (0.2 s) de la caracterizacion de 3.0 s.
%   El fallo global original de E0 permanece en los documentos historicos.
%
%   La lista de tests es explicita a proposito: functiontests(localfunctions)
%   recogeria tambien los helpers locales y los trataria como tests.

tests = functiontests({ ...
    @setupOnce, ...
    @teardownOnce, ...
    @testSimulatorArtifactsArePresent, ...
    @testEveryCommandLevelSnapsToAKnownSpeed, ...
    @testZeroSpeedProducesNoMotion, ...
    @testTrajectoryDependsOnInitialPosition, ...
    @testDirectionMonotonicity, ...
    @testMotor3LongHorizonCharacterization, ...
    @testGlobalLongHorizonCharacterization, ...
    @testNoCrossTalkBetweenMotors, ...
    @testOperationalStepBoundCharacterization});
end

%% ------------------------------------------------------------------------
function setupOnce(testCase)
here = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(here));   % tests/paired_reference -> matlab_code
addpath(genpath(matlabRoot));

testCase.TestData.oldDir = cd(matlabRoot);
testCase.TestData.matlabRoot = matlabRoot;

try
    clear("functions");   % vacia el persistent de prosthesis_simulator
catch
end
clearConfigurablesOverride();

testCase.TestData.configs = configurables();
testCase.TestData.simSpeeds = [0 64 96 128 160 192 224 256];
testCase.TestData.speedsTxt = ["sp_zeroF" "sp_3F" "sp_5F" "sp_7F" "sp_9F" "sp_BF" "sp_DF" "sp_FF"];
testCase.TestData.nMotors = 4;
testCase.TestData.samplingPeriod = 0.14;

simDir = fullfile(matlabRoot, "src", "@SimController");
testCase.TestData.fit = load(fullfile(simDir, "fit_C2.mat"));
testCase.TestData.patternCurve = load(fullfile(simDir, "pattern_curve.mat"), "avgs").avgs;
testCase.TestData.grids = localBuildGrids(testCase);
end

%% ------------------------------------------------------------------------
function teardownOnce(testCase)
if isfield(testCase.TestData, "oldDir")
    cd(testCase.TestData.oldDir);
end
end

%% ------------------------------------------------------------------------
function testSimulatorArtifactsArePresent(testCase)
fit = testCase.TestData.fit;
verifyTrue(testCase, isfield(fit, "params"), "fit_C2.mat sin campo params");
verifyTrue(testCase, isfield(fit, "tail_length"), "fit_C2.mat sin campo tail_length");
verifyNotEmpty(testCase, testCase.TestData.patternCurve);
end

%% ------------------------------------------------------------------------
function testEveryCommandLevelSnapsToAKnownSpeed(testCase)
% Cada nivel PWM configurado debe caer en una entrada de SIM_SPEEDS que
% exista en fit_C2. Si no, el agente puede emitir un comando sin curva.
configs = testCase.TestData.configs;
simSpeeds = testCase.TestData.simSpeeds;
speedsTxt = testCase.TestData.speedsTxt;
levels = configs.actionCommandLevels(configs.actionCommandLevels > 0);

for L = levels(:)'
    snapped = localSnapSpeed(L, simSpeeds);
    verifyGreaterThan(testCase, snapped, 0, ...
        sprintf("El nivel %d se mapea a velocidad cero", L));
    txt = speedsTxt(simSpeeds == snapped);
    verifyTrue(testCase, isfield(testCase.TestData.fit.params, txt), ...
        sprintf("fit_C2 no contiene %s (nivel %d)", txt, L));
end
end

%% ------------------------------------------------------------------------
function testZeroSpeedProducesNoMotion(testCase)
% Comando nulo => la posicion no cambia en ningun motor.
initial = [100 100 100 100];
traj = SimController.prosthesis_simulator(initial, [0 0 0 0], 3.0, ...
    testCase.TestData.samplingPeriod);
verifyEqual(testCase, traj, repmat(initial, size(traj, 1), 1), AbsTol=1e-12);
end

%% ------------------------------------------------------------------------
function testTrajectoryDependsOnInitialPosition(testCase)
% Una planta con dinamica devuelve trayectorias distintas desde posiciones
% iniciales distintas bajo el mismo comando. Si la posicion final es la
% misma para toda posicion inicial, la planta no integra: teletransporta.
grids = testCase.TestData.grids;
nMotors = testCase.TestData.nMotors;
mid = localMidpoints(grids);
tol = 1e-9;

for m = 1:nMotors
    posGrid = grids{m};
    for L = [64 255]
        for sgn = [1 -1]
            finals = zeros(numel(posGrid), 1);
            for iP = 1:numel(posGrid)
                initial = mid;
                initial(m) = posGrid(iP);
                speeds = zeros(1, nMotors);
                speeds(m) = sgn * L;
                traj = SimController.prosthesis_simulator(initial, speeds, 3.0, ...
                    testCase.TestData.samplingPeriod);
                finals(iP) = traj(end, m);
            end
            verifyGreaterThan(testCase, max(finals) - min(finals), tol, ...
                sprintf(['Motor %d, PWM %d: la posicion final es identica desde ' ...
                'las %d posiciones iniciales. La planta no integra.'], ...
                m, sgn*L, numel(posGrid)));
        end
    end
end
end

%% ------------------------------------------------------------------------
function testDirectionMonotonicity(testCase)
% Gate OPERATIVO: closing no decrece; opening no crece en 0.2 s.
grids = testCase.TestData.grids;
nMotors = testCase.TestData.nMotors;
mid = localMidpoints(grids);
levels = localLevels(testCase);
tol = 1e-9;

for m = 1:nMotors
    for L = levels
        for sgn = [1 -1]
            for p = grids{m}
                initial = mid;
                initial(m) = p;
                speeds = zeros(1, nMotors);
                speeds(m) = sgn * L;

                traj = SimController.prosthesis_simulator(initial, speeds, 0.2, ...
                    testCase.TestData.samplingPeriod);
                deltas = diff([initial(m); traj(:, m)]);

                if sgn > 0
                    verifyGreaterThanOrEqual(testCase, min(deltas), -tol, ...
                        sprintf("closing no monotono: motor %d, PWM %d, pos %.1f", m, L, p));
                else
                    verifyLessThanOrEqual(testCase, max(deltas), tol, ...
                        sprintf("opening no monotono: motor %d, PWM %d, pos %.1f", m, L, p));
                end
            end
        end
    end
end
end

%% ------------------------------------------------------------------------
function testMotor3LongHorizonCharacterization(testCase)
% MOTOR3_LONG_HORIZON_NONMONOTONIC_CHARACTERIZATION.
% La rejilla POR COMBINACION de 21 posiciones reproduce 28 casos E0.
% El test exige conservar y localizar el defecto, no corregir las curvas.
grids = testCase.TestData.grids;
mid = localMidpoints(grids);
failures = zeros(0, 3);
for m = 1:4
    for L = localLevels(testCase)
        for sgn = [1 -1]
            sp = testCase.TestData.speedsTxt(testCase.TestData.simSpeeds == ...
                localSnapSpeed(L, testCase.TestData.simSpeeds));
            direction = "closing";
            if sgn < 0, direction = "opening"; end
            entry = testCase.TestData.fit.params.(sp).(direction).(sprintf("m_%d", m));
            grid = linspace(entry.min_lim, entry.max_lim, 21);
            for p = grid
                initial = mid;
                initial(m) = p;
                speeds = zeros(1, 4);
                speeds(m) = sgn * L;
                trajectory = SimController.prosthesis_simulator(initial, speeds, 3.0, ...
                    testCase.TestData.samplingPeriod, plantSource="patternCurveCanonical");
                % Se inspecciona TODA la trayectoria; first/last/sum no bastan.
                if any(sgn * diff([p; trajectory(:, m)]) < -1e-9)
                    failures(end+1, :) = [m, sgn * L, p]; %#ok<AGROW>
                end
            end
        end
    end
end
fprintf("  MOTOR3_LONG_HORIZON_NONMONOTONIC_CHARACTERIZATION = %d (por combinacion, 21)\n", ...
    size(failures, 1));
verifyEqual(testCase, size(failures, 1), 28);
verifyTrue(testCase, all(failures(:, 1) == 3 & failures(:, 2) > 0));
end

function testGlobalLongHorizonCharacterization(testCase)
% La rejilla global no tiene los mismos casos que la historica: 27 cierre
% M3 y uno apertura M3 -192, q=1295.5, con un retroceso interno de 0.25.
grids = testCase.TestData.grids;
mid = localMidpoints(grids);
failures = zeros(0, 4);
for m = 1:4
    for L = localLevels(testCase)
        for sgn = [1 -1]
            for p = linspace(grids{m}(1), grids{m}(end), 21)
                initial = mid; initial(m) = p;
                speeds = zeros(1, 4); speeds(m) = sgn * L;
                trajectory = SimController.prosthesis_simulator(initial, speeds, 3.0, ...
                    testCase.TestData.samplingPeriod, plantSource="patternCurveCanonical");
                worst = min(sgn * diff([p; trajectory(:, m)]));
                if worst < -1e-9
                    failures(end+1, :) = [m, sgn * L, p, worst]; %#ok<AGROW>
                end
            end
        end
    end
end
verifyEqual(testCase, nnz(failures(:, 2) > 0), 27);
verifyTrue(testCase, all(failures(:, 1) == 3));
verifyEqual(testCase, failures(failures(:, 2) < 0, :), ...
    [3 -192 1295.5 -0.25], AbsTol=1e-9);
end

%% ------------------------------------------------------------------------
function testNoCrossTalkBetweenMotors(testCase)
% Comandar un motor no debe mover a los otros tres. Es una regresion: el
% simulador trata cada motor por separado, asi que este test protege contra
% un acoplamiento introducido por error mas adelante.
grids = testCase.TestData.grids;
nMotors = testCase.TestData.nMotors;
mid = localMidpoints(grids);
levels = localLevels(testCase);
tol = 1e-9;

for m = 1:nMotors
    others = setdiff(1:nMotors, m);
    for L = levels([1 end])
        for sgn = [1 -1]
            initial = mid;
            speeds = zeros(1, nMotors);
            speeds(m) = sgn * L;
            traj = SimController.prosthesis_simulator(initial, speeds, 3.0, ...
                testCase.TestData.samplingPeriod);
            drift = max(abs(traj(:, others) - initial(others)), [], "all");
            verifyLessThanOrEqual(testCase, drift, tol, ...
                sprintf("El motor %d movio a otros motores con PWM %d", m, sgn*L));
        end
    end
end
end

%% ------------------------------------------------------------------------
function testOperationalStepBoundCharacterization(testCase)
% El bound heuristico E0 (1.5 * avance maximo sobre la curva) omite la
% distancia desde q inicial hasta el primer punto de la curva. No es un
% bound valido si q esta antes del inicio del recorrido empirico. Se
% conservan visibles sus excesos: cuatro global11 y dos por combinacion21.
configs = testCase.TestData.configs;
grids = testCase.TestData.grids;
nMotors = testCase.TestData.nMotors;
mid = localMidpoints(grids);
levels = localLevels(testCase);
simSpeeds = testCase.TestData.simSpeeds;
speedsTxt = testCase.TestData.speedsTxt;
samplingPeriod = testCase.TestData.samplingPeriod;
jumpFactor = 1.5;

nPoints = round(configs.period / samplingPeriod);
assumeGreaterThanOrEqual(testCase, nPoints, 1, ...
    "period/samplingPeriod < 1: el simulador no produce muestras.");
deltaMs = configs.period * 1000 / nPoints;
globalFailures = zeros(0, 4);
combinationFailures = zeros(0, 3);

for m = 1:nMotors
    mTxt = sprintf("m_%d", m);
    for L = levels
        snapped = localSnapSpeed(L, simSpeeds);
        spTxt = speedsTxt(simSpeeds == snapped);
        for sgn = [1 -1]
            if sgn > 0
                dirName = "closing";
            else
                dirName = "opening";
            end
            % La referencia de avance es SIEMPRE pattern_curve: ws puede ser
            % un objeto cfit, sobre el que diff() no tiene sentido.
            curve = testCase.TestData.patternCurve.(spTxt).(dirName).(mTxt).avg;
            refStep = localReferenceStep(curve, deltaMs);
            verifyGreaterThan(testCase, refStep, 0, ...
                sprintf("Curva de referencia degenerada en %s/%s/%s", spTxt, dirName, mTxt));

            entry = testCase.TestData.fit.params.(spTxt).(dirName).(mTxt);
            positions = [linspace(entry.min_lim, entry.max_lim, 21), grids{m}];
            for iPosition = 1:numel(positions)
                p = positions(iPosition);
                initial = mid;
                initial(m) = p;
                speeds = zeros(1, nMotors);
                speeds(m) = sgn * L;
                traj = SimController.prosthesis_simulator(initial, speeds, ...
                    configs.period, samplingPeriod);
                jump = max(abs(diff([initial(m); traj(:, m)])));
                beforeCurve = (sgn < 0 && p > max(curve)) || (sgn > 0 && p < min(curve));
                if iPosition <= 21
                    if jump > jumpFactor * refStep
                        combinationFailures(end+1, :) = [m, sgn*L, p]; %#ok<AGROW>
                        verifyTrue(testCase, beforeCurve);
                    end
                elseif jump > jumpFactor * refStep
                    globalFailures(end+1, :) = [m, sgn*L, p, ...
                        beforeCurve]; %#ok<AGROW>
                end
            end
        end
    end
end
verifyEqual(testCase, globalFailures(:, 1:3), ...
    [2 -64 5361.4; 2 -64 6091.2; 2 -64 6821; 3 -64 7912], AbsTol=1e-9);
verifyTrue(testCase, all(globalFailures(:, 4) == 1));
verifyEqual(testCase, combinationFailures, [2 -64 5271.3; 2 -64 5550], AbsTol=1e-9);
fprintf("  GLOBAL_11_POINT_BOUND_CHARACTERIZATION = %d (antes del recorrido empirico)\n", ...
    size(globalFailures, 1));
end

%% ########################################################################
%  helpers locales (no son tests: la lista de arriba es explicita)
%  ########################################################################
function grids = localBuildGrids(testCase)
params = testCase.TestData.fit.params;
speedsTxt = testCase.TestData.speedsTxt;
nMotors = testCase.TestData.nMotors;

grids = cell(1, nMotors);
for m = 1:nMotors
    mTxt = sprintf("m_%d", m);
    lo = inf;
    hi = -inf;
    for iSp = 2:numel(speedsTxt)
        spTxt = speedsTxt(iSp);
        if ~isfield(params, spTxt)
            continue
        end
        for dirName = ["closing" "opening"]
            entry = params.(spTxt).(dirName).(mTxt);
            lo = min(lo, entry.min_lim);
            hi = max(hi, entry.max_lim);
        end
    end
    grids{m} = linspace(lo, hi, 11);
end
end

%% ------------------------------------------------------------------------
function mid = localMidpoints(grids)
mid = cellfun(@(g) g(ceil(numel(g)/2)), grids);
end

%% ------------------------------------------------------------------------
function levels = localLevels(testCase)
configs = testCase.TestData.configs;
levels = configs.actionCommandLevels(configs.actionCommandLevels > 0);
levels = levels(:)';
end

%% ------------------------------------------------------------------------
function refStep = localReferenceStep(curve, deltaMs)
curve = curve(:);
step = max(1, round(deltaMs));
if numel(curve) > step
    refStep = max(abs(curve(1+step:end) - curve(1:end-step)));
else
    refStep = max(curve) - min(curve);
end
end

%% ------------------------------------------------------------------------
function spSnapped = localSnapSpeed(sp, simSpeeds)
sp = abs(sp);
spSnapped = simSpeeds(end);
for i2 = 2:numel(simSpeeds)
    b = simSpeeds(i2);
    a = simSpeeds(i2 - 1);
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
