function tests = testPairedReferencePlantHoldOutsideCurve
%testPairedReferencePlantHoldOutsideCurve regresion del fix de planta de E0.
%
%   Antes del fix, cuando la posicion del motor quedaba mas alla del
%   recorrido de la curva de referencia en la direccion comandada, la
%   busqueda de x_0 no encontraba punto, t conservaba su valor por defecto
%   numel(curve) y el motor SALTABA al final de la curva, moviendose en
%   direccion contraria al comando. Medido en E0: 73 de 1176 casos del paso
%   operativo (6.2 %).
%
%   El fix mantiene la posicion en ese caso. Estos tests lo fijan.
%
%   Ejecutar con:
%       runtests("tests/paired_reference/testPairedReferencePlantHoldOutsideCurve")

tests = functiontests({ ...
    @setupOnce, ...
    @teardownOnce, ...
    @testHoldsWhenPositionIsOutsideCurveDomain, ...
    @testOperationalStepIsAlwaysMonotone});
end

%% ------------------------------------------------------------------------
function setupOnce(testCase)
here = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(here));
addpath(genpath(matlabRoot));
testCase.TestData.oldDir = cd(matlabRoot);

try
    clear("functions");
catch
end
clearConfigurablesOverride();

testCase.TestData.configs = configurables();
testCase.TestData.simSpeeds = [0 64 96 128 160 192 224 256];
testCase.TestData.speedsTxt = ["sp_zeroF" "sp_3F" "sp_5F" "sp_7F" "sp_9F" "sp_BF" "sp_DF" "sp_FF"];
testCase.TestData.nMotors = 4;
testCase.TestData.samplingPeriod = 0.14;
testCase.TestData.gridPoints = 21;

simDir = fullfile(matlabRoot, "src", "@SimController");
testCase.TestData.params = load(fullfile(simDir, "fit_C2.mat")).params;
testCase.TestData.patternCurve = load(fullfile(simDir, "pattern_curve.mat"), "avgs").avgs;
end

%% ------------------------------------------------------------------------
function teardownOnce(testCase)
if isfield(testCase.TestData, "oldDir")
    cd(testCase.TestData.oldDir);
end
end

%% ------------------------------------------------------------------------
function testHoldsWhenPositionIsOutsideCurveDomain(testCase)
% Donde la busqueda de x_0 no encuentra punto, el motor debe MANTENER
% posicion. El test localiza esos casos por si mismo, asi que sigue siendo
% valido si cambian las curvas.
cases = localOutsideDomainCases(testCase);
verifyNotEmpty(testCase, cases, ...
    "No se encontro ningun caso fuera del dominio: el test no esta probando nada.");

configs = testCase.TestData.configs;
nMotors = testCase.TestData.nMotors;

for i = 1:numel(cases)
    c = cases(i);
    initial = c.midPositions;
    initial(c.motor) = c.position;
    speeds = zeros(1, nMotors);
    speeds(c.motor) = c.command;

    traj = SimController.prosthesis_simulator(initial, speeds, configs.period, ...
        testCase.TestData.samplingPeriod);

    verifyEqual(testCase, traj(:, c.motor), repmat(c.position, size(traj, 1), 1), ...
        AbsTol=1e-9, ...
        Diagnostic=sprintf(['Motor %d, PWM %d, posicion %.1f esta fuera del ' ...
        'recorrido de la curva: deberia mantener posicion.'], ...
        c.motor, c.command, c.position));
end
end

%% ------------------------------------------------------------------------
function testOperationalStepIsAlwaysMonotone(testCase)
% Gate de E0.1 restringido al regimen que el entorno realmente produce:
% un paso de control = params.period. Debe ser 0 fallos.
configs = testCase.TestData.configs;
nMotors = testCase.TestData.nMotors;
levels = configs.actionCommandLevels(configs.actionCommandLevels > 0);
grids = localGrids(testCase);
mid = localMid(grids);
tol = 1e-9;
failures = 0;

for m = 1:nMotors
    for L = levels(:)'
        for sgn = [1 -1]
            for p = grids{m}
                initial = mid;
                initial(m) = p;
                speeds = zeros(1, nMotors);
                speeds(m) = sgn * L;
                traj = SimController.prosthesis_simulator(initial, speeds, ...
                    configs.period, testCase.TestData.samplingPeriod);
                deltas = diff([p; traj(:, m)]);
                if sgn > 0
                    ok = all(deltas >= -tol);
                else
                    ok = all(deltas <= tol);
                end
                if ~ok
                    failures = failures + 1;
                end
            end
        end
    end
end

verifyEqual(testCase, failures, 0, ...
    sprintf("%d casos del paso operativo se mueven en direccion contraria al comando.", failures));
end

%% ########################################################################
%  helpers locales
%  ########################################################################
function grids = localGrids(testCase)
params = testCase.TestData.params;
speedsTxt = testCase.TestData.speedsTxt;
nMotors = testCase.TestData.nMotors;
n = testCase.TestData.gridPoints;

grids = cell(1, nMotors);
for m = 1:nMotors
    mTxt = sprintf("m_%d", m);
    lo = inf; hi = -inf;
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
    grids{m} = linspace(lo, hi, n);
end
end

%% ------------------------------------------------------------------------
function mid = localMid(grids)
mid = cellfun(@(g) g(ceil(numel(g)/2)), grids);
end

%% ------------------------------------------------------------------------
function cases = localOutsideDomainCases(testCase)
params = testCase.TestData.params;
speedsTxt = testCase.TestData.speedsTxt;
simSpeeds = testCase.TestData.simSpeeds;
configs = testCase.TestData.configs;
nMotors = testCase.TestData.nMotors;
levels = configs.actionCommandLevels(configs.actionCommandLevels > 0);
grids = localGrids(testCase);
mid = localMid(grids);

cases = struct("motor", {}, "command", {}, "position", {}, "midPositions", {});

for m = 1:nMotors
    mTxt = sprintf("m_%d", m);
    for L = levels(:)'
        snapped = localSnapSpeed(L, simSpeeds);
        spTxt = speedsTxt(simSpeeds == snapped);
        for sgn = [1 -1]
            if sgn > 0
                dirName = "closing";
            else
                dirName = "opening";
            end
            entry = params.(spTxt).(dirName).(mTxt);
            curve = testCase.TestData.patternCurve.(spTxt).(dirName).(mTxt).avg;
            curve = curve(:);
            posGrid = linspace(entry.min_lim, entry.max_lim, testCase.TestData.gridPoints);

            for p = posGrid
                y = sat(p, entry.min_lim, entry.max_lim);
                if dirName == "closing"
                    found = any(curve >= y);
                else
                    found = any(y >= curve);
                end
                if ~found
                    cases(end+1) = struct("motor", m, "command", sgn * L, ...
                        "position", p, "midPositions", mid); %#ok<AGROW>
                end
            end
        end
    end
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
