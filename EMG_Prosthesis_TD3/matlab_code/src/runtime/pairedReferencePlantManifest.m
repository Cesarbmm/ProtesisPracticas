function manifest = pairedReferencePlantManifest(options)
%pairedReferencePlantManifest manifiesto de la fuente de planta (ETAPA E0P).
%
%   Toda corrida de la linea paired-reference debe guardar este manifiesto.
%
%   Campos:
%     simPlantSource              fuente efectiva de la dinamica
%     patternCurvePath            ruta de la curva canonica
%     patternCurveSHA256          hash de la curva canonica
%     limitsPath                  ruta de la tabla de limites canonica
%     limitsSHA256                hash de la tabla de limites
%     fitC2Present                si fit_C2.mat existe en disco
%     curveFittingToolboxPresent  SOLO DIAGNOSTICO
%
%   curveFittingToolboxPresent nunca debe alterar la fisica cuando
%   simPlantSource == "patternCurveCanonical". El test
%   testPairedReferencePlantCanonicalSource lo comprueba. outputPath guarda
%   JSON junto a los resultados. Pasar las mismas opciones que al simulador
%   si se usa una fuente o rutas explicitas. Este helper tampoco abre fit_C2.

arguments
    options.simControllerDir (1, 1) string = ""
    options.plantSource (1, 1) string = ""
    options.canonicalCurvePath (1, 1) string = ""
    options.canonicalLimitsPath (1, 1) string = ""
    options.fitC2Path (1, 1) string = ""
    options.outputPath (1, 1) string = ""
end

if options.simControllerDir == ""
    runtimeDir = fileparts(mfilename("fullpath"));
    srcRoot = fileparts(runtimeDir);
    simDir = string(fullfile(srcRoot, "@SimController"));
else
    simDir = options.simControllerDir;
end

source = resolveSimPlantSource(options.plantSource);
curvePath = fullfile(simDir, "pattern_curve.mat");
limitsPath = fullfile(simDir, "plant_limits_canonical.csv");
fitPath = fullfile(simDir, "fit_C2.mat");
if source == "patternCurveCanonical"
    if options.canonicalCurvePath ~= ""
        curvePath = options.canonicalCurvePath;
    end
    if options.canonicalLimitsPath ~= ""
        limitsPath = options.canonicalLimitsPath;
    end
end
if options.fitC2Path ~= ""
    fitPath = options.fitC2Path;
end
curvePath = resolveSimPlantPath(curvePath);
limitsPath = resolveSimPlantPath(limitsPath);
fitPath = resolveSimPlantPath(fitPath);

manifest = struct();
manifest.timestamp = string(datetime("now", TimeZone="UTC", ...
    Format="yyyy-MM-dd'T'HH:mm:ssXXX"));
manifest.simPlantSource = source;

manifest.patternCurvePath = curvePath;
manifest.patternCurveSHA256 = fileSha256(curvePath);
manifest.limitsPath = limitsPath;
manifest.limitsSHA256 = "";
if source == "patternCurveCanonical"
    manifest.limitsSHA256 = fileSha256(limitsPath);
end

manifest.fitC2Path = fitPath;
manifest.fitC2Present = isfile(fitPath);

% --- solo diagnostico ---
manifest.curveFittingToolboxPresent = ...
    any(contains(string({ver().Name}), "Curve Fitting"));
manifest.matlabVersion = string(version);

if options.outputPath ~= ""
    [fid, message] = fopen(options.outputPath, "w", "n", "UTF-8");
    if fid < 0
        error("ProtesisPracticas:ManifestWriteFailed", "%s", message);
    end
    closeFile = onCleanup(@() fclose(fid));
    fprintf(fid, "%s\n", jsonencode(manifest, PrettyPrint=true));
end

if nargout == 0
    disp(manifest);
end
end

%% ------------------------------------------------------------------------
function h = fileSha256(f)
if ~isfile(f)
    error("ProtesisPracticas:MissingPlantArtifact", "Falta artefacto: %s", f);
end
digest = java.security.MessageDigest.getInstance("SHA-256");
[fid, message] = fopen(f, "rb");
if fid < 0
    error("ProtesisPracticas:PlantArtifactReadFailed", "%s", message);
end
closeFile = onCleanup(@() fclose(fid));
raw = fread(fid, inf, "*uint8");
digest.update(raw);
h = string(lower(reshape(dec2hex(typecast(digest.digest(), "uint8"), 2)', 1, [])));
end
