function tests = testPairedReferencePlantCanonicalSource
%testPairedReferencePlantCanonicalSource gates de la ETAPA E0P.
%
%   Comprueba que la fuente de la dinamica es explicita y que la ruta
%   canonica no puede cambiar segun este instalada Curve Fitting Toolbox.
%
%   Ejecutar con:
%       runtests("tests/paired_reference/testPairedReferencePlantCanonicalSource")

tests = functiontests({ ...
    @setupOnce, ...
    @teardownOnce, ...
    @testCanonicalSourceIsExplicit, ...
    @testSourceOverrideRefreshesWithoutClearingFunctions, ...
    @testRelativePathsFollowWorkingDirectory, ...
    @testCanonicalDoesNotUseFitC2, ...
    @testCanonicalUnchangedAfterLoadingCfit, ...
    @testCanonicalWithoutFitOrCftPath, ...
    @testOutOfDomainHolds, ...
    @testOperationalMonotonicity, ...
    @testE0Regression, ...
    @testLimitsTableMatchesFitC2, ...
    @testManifestHashes, ...
    @testManifestTracksExplicitSourceAndPersists, ...
    @testLegacyRoutePreserved});
end

%% ------------------------------------------------------------------------
function setupOnce(testCase)
here = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(here));
addpath(genpath(matlabRoot));
clearConfigurablesOverride();
testCase.TestData.oldDir = cd(matlabRoot);
try
    clear("functions");
catch
end
testCase.TestData.matlabRoot = matlabRoot;
testCase.TestData.simDir = string(fullfile(matlabRoot, "src", "@SimController"));
testCase.TestData.limitsPath = string(fullfile(testCase.TestData.simDir, "plant_limits_canonical.csv"));
testCase.TestData.casesPath = string(fullfile(matlabRoot, "analysis", "paired_reference", ...
    "plant_e0_regression_cases.csv"));
testCase.TestData.levels = [64 96 128 160 192 224 255];
testCase.TestData.limits = readtable(testCase.TestData.limitsPath, TextType="string");
end

function teardownOnce(testCase)
if isfield(testCase.TestData, "oldDir")
    cd(testCase.TestData.oldDir);
end
end

%% ------------------------------------------------------------------------
function testCanonicalSourceIsExplicit(testCase)
% CANONICAL_SOURCE_EXPLICIT: configurables declara la fuente y es la canonica.
p = configurables();
verifyTrue(testCase, isfield(p, "simPlantSource"), ...
    "configurables no declara simPlantSource");
verifyEqual(testCase, string(p.simPlantSource), "patternCurveCanonical");
end

%% ------------------------------------------------------------------------
function testCanonicalDoesNotUseFitC2(testCase)
% FIT_C2_NOT_USED_BY_CANONICAL_PATH: se pasa una ruta invalida de fit_C2 y la
% ruta canonica debe seguir funcionando y dar EXACTAMENTE lo mismo.
% No se renombra ni se borra ningun archivo real.
bogus = string(fullfile(tempdir, "no_existe_fit_C2_e0p.mat"));
verifyFalse(testCase, isfile(bogus), "la ruta de prueba no debe existir");

initial = localMid(testCase);
speeds = [255 -255 128 -64];
a = SimController.prosthesis_simulator(initial, speeds, 0.2, 0.14, ...
    plantSource="patternCurveCanonical");
b = SimController.prosthesis_simulator(initial, speeds, 0.2, 0.14, ...
    plantSource="patternCurveCanonical", fitC2Path=bogus);
verifyEqual(testCase, b, a, ...
    "la ruta canonica cambia al invalidar fit_C2: lo esta consumiendo");
end

%% ------------------------------------------------------------------------
function testCanonicalUnchangedAfterLoadingCfit(testCase)
% CFT_INDEPENDENT: cargar fit_C2 (instanciando cfit si la toolbox existe) no
% puede alterar la salida de la ruta canonica, ni antes ni despues de vaciar
% las caches persistent.
initial = localMid(testCase);
speeds = [200 -200 96 -128];
before = SimController.prosthesis_simulator(initial, speeds, 0.2, 0.14, ...
    plantSource="patternCurveCanonical");

fitPath = fullfile(testCase.TestData.simDir, "fit_C2.mat");
loaded = load(fitPath); %#ok<NASGU>
after = SimController.prosthesis_simulator(initial, speeds, 0.2, 0.14, ...
    plantSource="patternCurveCanonical");
verifyEqual(testCase, after, before);

try
    clear("functions");
catch
end
afterClear = SimController.prosthesis_simulator(initial, speeds, 0.2, 0.14, ...
    plantSource="patternCurveCanonical");
verifyEqual(testCase, afterClear, before, ...
    "la ruta canonica no es estable tras recargar las caches");
end

%% ------------------------------------------------------------------------
function testSourceOverrideRefreshesWithoutClearingFunctions(testCase)
cleanup = onCleanup(@() clearConfigurablesOverride());
initial = localMid(testCase);
commands = [255 -255 128 -64];
for source = ["legacyAuto", "patternCurveCanonical", "legacyAuto"]
    setConfigurablesOverride(struct("simPlantSource", source));
    implicit = SimController.prosthesis_simulator(initial, commands, 0.2, 0.14);
    explicit = SimController.prosthesis_simulator(initial, commands, 0.2, 0.14, ...
        plantSource=source);
    verifyEqual(testCase, implicit, explicit);
    verifyEqual(testCase, pairedReferencePlantManifest().simPlantSource, source);
end
setConfigurablesOverride(struct("simPlantSource", "fuenteInvalida"));
verifyError(testCase, @() SimController.prosthesis_simulator(initial, commands, 0.2, 0.14), ...
    "ProtesisPracticas:InvalidPlantSource");
verifyError(testCase, @() pairedReferencePlantManifest(), "ProtesisPracticas:InvalidPlantSource");
end

%% ------------------------------------------------------------------------
function testCanonicalWithoutFitOrCftPath(testCase)
% Fixture aislada: fuente real copiada y renombrada; solo curva y limites.
% Retirar rutas CFT simula su ausencia para resolucion de funciones. No se
% descarga ninguna clase ni se altera instalacion/archivo real alguno.
temporary = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fixtureDir = string(temporary.Folder);
source = fileread(fullfile(testCase.TestData.simDir, "prosthesis_simulator.m"));
source = strrep(source, "function trajectory = prosthesis_simulator(", ...
    "function trajectory = e0pCanonicalIsolated(");
localWriteText(fullfile(fixtureDir, "e0pCanonicalIsolated.m"), source);
copyfile(fullfile(testCase.TestData.simDir, "pattern_curve.mat"), fixtureDir);
copyfile(testCase.TestData.limitsPath, fixtureDir);
verifyFalse(testCase, isfile(fullfile(fixtureDir, "fit_C2.mat")));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fixtureDir));

C = readtable(testCase.TestData.casesPath);
before = localCaseTrajectories(C, @SimController.prosthesis_simulator, localMid(testCase));
oldPath = path;
restorePath = onCleanup(@() path(oldPath));
entries = string(strsplit(path, pathsep));
toolboxEntries = entries(contains(lower(entries), "curvefit"));
for entry = toolboxEntries
    rmpath(char(entry));
end
rehash;
verifyEmpty(testCase, which("cfit"), "La clase cfit debe quedar fuera del PATH de la fixture.");
profile clear;
profile on;
stopProfile = onCleanup(@() profile("off"));
isolated = localCaseTrajectories(C, @e0pCanonicalIsolated, localMid(testCase));
profile off;
information = profile("info");
names = string({information.FunctionTable.FunctionName});
verifyTrue(testCase, any(contains(names, "predict_1dim_canonical")));
verifyFalse(testCase, any(contains(lower(names), "cfit")));
legacyCalls = endsWith(names, ">predict_1dim") | endsWith(names, "/predict_1dim");
verifyFalse(testCase, any(legacyCalls));
verifyEqual(testCase, isolated, before);
fprintf("  FIT_C2_USED_CANONICAL = NO; CFT_PATH_REMOVED = %d; PROFILE_CFIT_CALLS = 0\n", ...
    numel(toolboxEntries));
end

function testRelativePathsFollowWorkingDirectory(testCase)
% Dos fixtures tienen iguales nombres relativos y datos distintos. La cache
% debe distinguir sus rutas absolutas y coincidir con el hash del manifiesto.
temporary = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
firstDir = fullfile(string(temporary.Folder), "first");
secondDir = fullfile(string(temporary.Folder), "second");
mkdir(firstDir); mkdir(secondDir);
for folder = [firstDir secondDir]
    copyfile(testCase.TestData.limitsPath, folder);
end
avgs = load(fullfile(testCase.TestData.simDir, "pattern_curve.mat"), "avgs").avgs;
save(fullfile(firstDir, "pattern_curve.mat"), "avgs");
% Solo esta copia temporal: la curva del primer motor queda desplazada.
avgs.sp_3F.closing.m_1.avg = avgs.sp_3F.closing.m_1.avg + 1000;
save(fullfile(secondDir, "pattern_curve.mat"), "avgs");
oldDir = pwd;
restoreDir = onCleanup(@() cd(oldDir));
initial = [0 0 0 0]; speeds = [64 0 0 0];
cd(firstDir);
first = SimController.prosthesis_simulator(initial, speeds, 0.2, 0.14, ...
    plantSource="patternCurveCanonical", canonicalCurvePath="pattern_curve.mat", ...
    canonicalLimitsPath="plant_limits_canonical.csv");
firstManifest = pairedReferencePlantManifest(plantSource="patternCurveCanonical", ...
    canonicalCurvePath="pattern_curve.mat", canonicalLimitsPath="plant_limits_canonical.csv");
cd(secondDir);
second = SimController.prosthesis_simulator(initial, speeds, 0.2, 0.14, ...
    plantSource="patternCurveCanonical", canonicalCurvePath="pattern_curve.mat", ...
    canonicalLimitsPath="plant_limits_canonical.csv");
explicit = SimController.prosthesis_simulator(initial, speeds, 0.2, 0.14, ...
    plantSource="patternCurveCanonical", canonicalCurvePath=fullfile(secondDir, "pattern_curve.mat"), ...
    canonicalLimitsPath=fullfile(secondDir, "plant_limits_canonical.csv"));
secondManifest = pairedReferencePlantManifest(plantSource="patternCurveCanonical", ...
    canonicalCurvePath="pattern_curve.mat", canonicalLimitsPath="plant_limits_canonical.csv");
verifyNotEqual(testCase, first, second);
verifyEqual(testCase, second, explicit);
verifyNotEqual(testCase, firstManifest.patternCurveSHA256, secondManifest.patternCurveSHA256);
verifyEqual(testCase, secondManifest.patternCurveSHA256, localSha256(fullfile(secondDir, "pattern_curve.mat")));
end

%% ------------------------------------------------------------------------
function testOutOfDomainHolds(testCase)
% OUT_OF_DOMAIN_HOLD: si la posicion queda fuera del recorrido de la curva en
% la direccion pedida, el motor MANTIENE posicion. Nunca salta al extremo.
cases = localOutOfDomainCases(testCase);
verifyNotEmpty(testCase, cases, "no se hallo ningun caso fuera de dominio");
mid = localMid(testCase);
for c = cases
    initial = mid;
    initial(c.motor) = c.position;
    speeds = zeros(1, 4);
    speeds(c.motor) = c.command;
    traj = SimController.prosthesis_simulator(initial, speeds, 0.2, 0.14, ...
        plantSource="patternCurveCanonical");
    verifyEqual(testCase, traj(:, c.motor), repmat(c.position, size(traj, 1), 1), ...
        sprintf("motor %d, PWM %d, pos %.1f deberia mantener", ...
        c.motor, c.command, c.position), AbsTol=1e-9);
end
end

%% ------------------------------------------------------------------------
function testOperationalMonotonicity(testCase)
% OPERATIONAL_MONOTONICITY_FAILURES = 0 en el regimen operativo (0.2 s).
% Las posiciones se recorren en UNIDADES REALES de encoder, tomadas de los
% limites de cada combinacion, no en [0,1] normalizado.
T = testCase.TestData.limits;
mid = localMid(testCase);
tol = 1e-9;
failures = 0;
for m = 1:4
    for L = testCase.TestData.levels
        for sgn = [1 -1]
            if sgn > 0
                dirName = "closing";
            else
                dirName = "opening";
            end
            row = T(T.motor == m & T.direction == dirName & ...
                T.speed_value == localSnap(L), :);
            grid = linspace(row.min_lim(1), row.max_lim(1), 21);
            for p = grid
                initial = mid;
                initial(m) = p;
                speeds = zeros(1, 4);
                speeds(m) = sgn * L;
                traj = SimController.prosthesis_simulator(initial, speeds, 0.2, 0.14, ...
                    plantSource="patternCurveCanonical");
                d = diff([p; traj(:, m)]);
                if sgn > 0
                    ok = all(d >= -tol);
                else
                    ok = all(d <= tol);
                end
                if ~ok
                    failures = failures + 1;
                end
            end
        end
    end
end
verifyEqual(testCase, failures, 0, ...
    sprintf("%d casos operativos se mueven en direccion contraria", failures));
end

%% ------------------------------------------------------------------------
function testE0Regression(testCase)
% E0_REGRESSION: la ruta canonica reproduce la fisica que E0 midio SIN Curve
% Fitting Toolbox. Los casos estan congelados en un CSV versionado.
C = readtable(testCase.TestData.casesPath);
verifyEqual(testCase, height(C), 784);
verifyEqual(testCase, C.Properties.VariableNames, ...
    {'motor', 'pwm', 'pos', 'duration', 'n_points', 'first', 'last', 'sum'});
verifyEqual(testCase, sum(C.duration == 0.2), 392);
verifyEqual(testCase, sum(C.duration == 3.0), 392);
verifyEqual(testCase, height(unique(C(:, {'motor', 'pwm', 'pos', 'duration'}))), 784);
verifyEqual(testCase, localSha256(testCase.TestData.casesPath), ...
    "203847041ebc00e83c1785b6a2a92ad2eaf33c8c730c2f95ec3f3da7a0d9da3e");
for m = 1:4
    for level = testCase.TestData.levels
        for signValue = [-1 1]
            for duration = [0.2 3.0]
                selection = C.motor == m & C.pwm == signValue * level & C.duration == duration;
                verifyEqual(testCase, sum(selection), 7);
            end
        end
    end
end
mid = localMid(testCase);
maxErr = 0;
for r = 1:height(C)
    initial = mid;
    initial(C.motor(r)) = C.pos(r);
    speeds = zeros(1, 4);
    speeds(C.motor(r)) = C.pwm(r);
    traj = SimController.prosthesis_simulator(initial, speeds, C.duration(r), 0.14, ...
        plantSource="patternCurveCanonical");
    s = traj(:, C.motor(r));
    verifyEqual(testCase, numel(s), C.n_points(r));
    maxErr = max([maxErr, abs(s(1) - C.first(r)), abs(s(end) - C.last(r)), ...
        abs(sum(s) - C.sum(r))]);
end
fprintf("  E0_REGRESSION_MAX_ERROR = %.3e sobre %d casos\n", maxErr, height(C));
verifyLessThan(testCase, maxErr, 1e-9);
end

%% ------------------------------------------------------------------------
function testLimitsTableMatchesFitC2(testCase)
% La tabla canonica se EXTRAJO de los campos numericos de fit_C2. Cuando
% fit_C2 se puede leer, debe coincidir exactamente. No se reinterpreta ni se
% reajusta ningun objeto cfit: solo se comparan min_lim y max_lim.
fitPath = fullfile(testCase.TestData.simDir, "fit_C2.mat");
assumeTrue(testCase, isfile(fitPath), "fit_C2.mat no disponible");
f = load(fitPath);
T = testCase.TestData.limits;
for r = 1:height(T)
    e = f.params.(T.speed_field(r)).(T.direction(r)).(sprintf("m_%d", T.motor(r)));
    verifyEqual(testCase, double(e.min_lim), T.min_lim(r), AbsTol=1e-9);
    verifyEqual(testCase, double(e.max_lim), T.max_lim(r), AbsTol=1e-9);
end
end

%% ------------------------------------------------------------------------
function testManifestHashes(testCase)
% SOURCE_MANIFEST: el manifiesto reporta la fuente y los hashes esperados.
mf = pairedReferencePlantManifest();
verifyEqual(testCase, mf.simPlantSource, "patternCurveCanonical");
verifyEqual(testCase, mf.patternCurveSHA256, ...
    "a519555bcfcbbc7b140843d6fc1240118738cd3a6ca69f6f5517617372073590");
verifyEqual(testCase, mf.limitsSHA256, ...
    "dc643b5a656e5e9e21de6b61f0d2a614aafcfbca452c3e15acc14cbe448e9dc2");
fprintf("  curveFittingToolboxPresent = %d (solo diagnostico)\n", ...
    mf.curveFittingToolboxPresent);
end

%% ------------------------------------------------------------------------
function testManifestTracksExplicitSourceAndPersists(testCase)
temporary = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fixtureDir = string(temporary.Folder);
curvePath = fullfile(fixtureDir, "fixture_pattern.mat");
limitsPath = fullfile(fixtureDir, "fixture_limits.csv");
fitPath = fullfile(fixtureDir, "fit_inexistente.mat");
outputPath = fullfile(fixtureDir, "plant_manifest.json");
copyfile(fullfile(testCase.TestData.simDir, "pattern_curve.mat"), curvePath);
copyfile(testCase.TestData.limitsPath, limitsPath);
mf = pairedReferencePlantManifest(plantSource="patternCurveCanonical", ...
    canonicalCurvePath=curvePath, canonicalLimitsPath=limitsPath, ...
    fitC2Path=fitPath, outputPath=outputPath);
verifyEqual(testCase, mf.simPlantSource, "patternCurveCanonical");
verifyEqual(testCase, mf.patternCurvePath, string(java.io.File(char(curvePath)).getCanonicalPath()));
verifyEqual(testCase, mf.patternCurveSHA256, localSha256(curvePath));
verifyEqual(testCase, mf.limitsSHA256, localSha256(limitsPath));
verifyFalse(testCase, mf.fitC2Present);
saved = jsondecode(fileread(outputPath));
verifyEqual(testCase, string(saved.simPlantSource), mf.simPlantSource);
verifyEqual(testCase, string(saved.patternCurvePath), mf.patternCurvePath);
verifyEqual(testCase, string(saved.patternCurveSHA256), mf.patternCurveSHA256);
verifyEqual(testCase, saved.fitC2Present, mf.fitC2Present);
verifyEqual(testCase, saved.curveFittingToolboxPresent, mf.curveFittingToolboxPresent);
legacy = pairedReferencePlantManifest(plantSource="legacyAuto", ...
    canonicalCurvePath=curvePath, canonicalLimitsPath=limitsPath);
verifyEqual(testCase, legacy.simPlantSource, "legacyAuto");
verifyNotEqual(testCase, legacy.patternCurvePath, mf.patternCurvePath);
verifyEqual(testCase, legacy.limitsSHA256, "");
verifyError(testCase, @() pairedReferencePlantManifest(plantSource="patternCurveCanonical", ...
    canonicalCurvePath=fullfile(fixtureDir, "curva_ausente.mat")), ...
    "ProtesisPracticas:MissingPlantArtifact");
end

%% ------------------------------------------------------------------------
function testLegacyRoutePreserved(testCase)
% Compara TODA la trayectoria con el codigo f597 congelado: fit real y el
% escenario E0 ws=[] materializado SOLO en un MAT temporal de fixture.
temporary = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
fixtureDir = string(temporary.Folder);
here = fileparts(mfilename("fullpath"));
copyfile(fullfile(here, "fixtures", "plantE0HistoricalReference.m"), fixtureDir);
copyfile(fullfile(testCase.TestData.simDir, "pattern_curve.mat"), fixtureDir);
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fixtureDir));
realFitPath = fullfile(testCase.TestData.simDir, "fit_C2.mat");
emptyFit = load(realFitPath);
T = testCase.TestData.limits;
for row = 1:height(T)
    m = sprintf("m_%d", T.motor(row));
    emptyFit.params.(T.speed_field(row)).(T.direction(row)).(m).ws = [];
end
emptyFitPath = fullfile(fixtureDir, "fit_empty.mat");
save(emptyFitPath, "-struct", "emptyFit");
C = readtable(testCase.TestData.casesPath);
mid = localMid(testCase);
for fitPath = [realFitPath, emptyFitPath]
    copyfile(fitPath, fullfile(fixtureDir, "fit_C2.mat"));
    clear plantE0HistoricalReference;
    for row = 1:height(C)
        initial = mid;
        initial(C.motor(row)) = C.pos(row);
        speeds = zeros(1, 4);
        speeds(C.motor(row)) = C.pwm(row);
        reference = plantE0HistoricalReference(initial, speeds, C.duration(row), 0.14);
        actual = SimController.prosthesis_simulator(initial, speeds, C.duration(row), 0.14, ...
            plantSource="legacyAuto", fitC2Path=fitPath);
        verifyEqual(testCase, actual, reference);
        if fitPath == emptyFitPath
            canonical = SimController.prosthesis_simulator(initial, speeds, C.duration(row), 0.14, ...
                plantSource="patternCurveCanonical");
            verifyEqual(testCase, canonical, reference);
        end
    end
end
fprintf("  LEGACY_REFERENCE_CASES = 1568; E0_FULL_TRAJECTORY_CASES = 784\n");
% Los excesos del bound heuristico tampoco son regresiones introducidas por
% E0P: se comparan con la misma referencia E0 ws=[] que sigue en la fixture.
extra = [2 -64 5361.4; 2 -64 6091.2; 2 -64 6821; 3 -64 7912; ...
    2 -64 5271.3; 2 -64 5550];
for row = 1:size(extra, 1)
    initial = mid; initial(extra(row, 1)) = extra(row, 3);
    speeds = zeros(1, 4); speeds(extra(row, 1)) = extra(row, 2);
    reference = plantE0HistoricalReference(initial, speeds, 0.2, 0.14);
    actual = SimController.prosthesis_simulator(initial, speeds, 0.2, 0.14, ...
        plantSource="patternCurveCanonical");
    verifyEqual(testCase, actual, reference);
end
fprintf("  HISTORICAL_BOUND_EXCESS_CASES = 6 (trayectorias identicas)\n");
end

%% ########################################################################
%  helpers locales
%  ########################################################################
function trajectories = localCaseTrajectories(C, simulator, mid)
trajectories = cell(height(C), 1);
for row = 1:height(C)
    initial = mid;
    initial(C.motor(row)) = C.pos(row);
    speeds = zeros(1, 4);
    speeds(C.motor(row)) = C.pwm(row);
    trajectories{row} = simulator(initial, speeds, C.duration(row), 0.14, ...
        plantSource="patternCurveCanonical");
end
end

function localWriteText(filePath, content)
fid = fopen(filePath, "w", "n", "UTF-8");
assert(fid >= 0, "No se pudo escribir la fixture temporal");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s", content);
end

function hash = localSha256(filePath)
fid = fopen(filePath, "rb");
assert(fid >= 0, "No se pudo leer el artefacto");
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, "*uint8");
digest = java.security.MessageDigest.getInstance("SHA-256");
digest.update(bytes);
hash = string(lower(reshape(dec2hex(typecast(digest.digest(), "uint8"), 2)', 1, [])));
end

function mid = localMid(testCase)
T = testCase.TestData.limits;
mid = zeros(1, 4);
for m = 1:4
    sel = T.motor == m;
    mid(m) = (min(T.min_lim(sel)) + max(T.max_lim(sel))) / 2;
end
end

%% ------------------------------------------------------------------------
function s = localSnap(L)
SIM = [0 64 96 128 160 192 224 256];
L = abs(L);
s = SIM(end);
for i = 2:numel(SIM)
    b = SIM(i);
    a = SIM(i - 1);
    if L <= b
        if L >= a
            r = (L - a)/(b - a);
            if r >= 0.5
                s = b;
            else
                s = a;
            end
        else
            s = 0;
        end
        return
    end
end
end

%% ------------------------------------------------------------------------
function cases = localOutOfDomainCases(testCase)
T = testCase.TestData.limits;
simDir = testCase.TestData.simDir;
avgs = load(fullfile(simDir, "pattern_curve.mat"), "avgs").avgs;
cases = struct("motor", {}, "command", {}, "position", {});
for m = 1:4
    for L = testCase.TestData.levels
        for sgn = [1 -1]
            if sgn > 0
                dirName = "closing";
            else
                dirName = "opening";
            end
            row = T(T.motor == m & T.direction == dirName & ...
                T.speed_value == localSnap(L), :);
            curve = avgs.(row.speed_field(1)).(dirName).(sprintf("m_%d", m)).avg;
            curve = curve(:);
            for p = linspace(row.min_lim(1), row.max_lim(1), 21)
                y = sat(p, row.min_lim(1), row.max_lim(1));
                if dirName == "closing"
                    found = any(curve >= y);
                else
                    found = any(y >= curve);
                end
                if ~found
                    cases(end+1) = struct("motor", m, "command", sgn * L, ...
                        "position", p); %#ok<AGROW>
                end
            end
        end
    end
end
end
