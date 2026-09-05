function [emgData, teacherData, provenance] = loadE2ADevelopmentEpisode(subject, repetition, side, options)
%loadE2ADevelopmentEpisode carga una seleccion development para la auditoria E2A.
% La ruta por defecto solo solicita la variable emgs. No usa getDataset,
% no lee gloves y no crea dispositivos. Conserva fila/columna originales:
% side=1 cierre; side=2 apertura. No filtra ni reordena episodios.
%
% El hash EMG corresponde a la matriz seleccionada, no al archivo MAT
% completo: hashear el archivo tambien leeria los bytes del guante en B.
% variableLoader permite comprobar las variables solicitadas con fixtures.

arguments
    subject (1, 1) string
    repetition (1, 1) double {mustBeInteger, mustBePositive}
    side (1, 1) double {mustBeMember(side, [1 2])}
    options.includeTeacher (1, 1) logical = false
    options.datasetFolder (1, 1) string = ""
    options.variableLoader (1, 1) function_handle = @loadSelectedVariable
end

% Este control precede a cualquier lectura o consulta de archivo.
development = ["BLANCA", "CECILIA", "DENIS", "EMILIA", "GABI", ...
    "GABRIEL", "IVANNA", "JOE", "JONATHAN", "KHAROL"];
if ~ismember(subject, development)
    error("ProtesisPracticas:E2ADevelopmentOnly", ...
        "E2A solo admite los diez sujetos DEVELOPMENT ya abiertos.");
end

if options.datasetFolder == ""
    runtimeDir = fileparts(mfilename("fullpath"));
    matlabRoot = fileparts(fileparts(runtimeDir));
    datasetFolder = fullfile(matlabRoot, "data", "datasets", "Denis Dataset");
else
    datasetFolder = options.datasetFolder;
end
datasetPath = string(fullfile(datasetFolder, subject + ".mat"));
loaded = options.variableLoader(datasetPath, "emgs");
if ~isstruct(loaded) || ~isfield(loaded, "emgs") || ~iscell(loaded.emgs)
    error("ProtesisPracticas:E2AInvalidEmgDataset", ...
        "El dataset development debe contener la variable cell emgs.");
end
if repetition > size(loaded.emgs, 1) || side > size(loaded.emgs, 2)
    error("ProtesisPracticas:E2AEpisodeOutOfRange", ...
        "Episodio inexistente: %s, fila %d, lado %d.", subject, repetition, side);
end
emgData = loaded.emgs{repetition, side};
if ~isnumeric(emgData) || ~isreal(emgData) || size(emgData, 2) ~= 8 || ...
        size(emgData, 1) < 2 || ~all(isfinite(emgData), "all")
    error("ProtesisPracticas:E2AInvalidEmgEpisode", ...
        "El episodio EMG debe ser una matriz finita de al menos 2 por 8.");
end

teacherData = [];
provenance = struct( ...
    "subject", subject, ...
    "split", "DEVELOPMENT", ...
    "repetition", repetition, ...
    "side", side, ...
    "datasetPath", datasetPath, ...
    "loadedVariables", "emgs", ...
    "includeTeacher", options.includeTeacher, ...
    "emgSamples", size(emgData, 1), ...
    "emgSHA256", numericSha256(emgData), ...
    "emgHashMethod", "SHA256(class;dimensions;native-endian;raw-column-major-bytes)", ...
    "datasetFileSHA256", "NOT_READ_TO_AVOID_GLOVE_BYTES");

if options.includeTeacher
    teacherLoaded = options.variableLoader(datasetPath, "gloves");
    if ~isstruct(teacherLoaded) || ~isfield(teacherLoaded, "gloves") || ...
            ~iscell(teacherLoaded.gloves) || ...
            repetition > size(teacherLoaded.gloves, 1) || ...
            side > size(teacherLoaded.gloves, 2)
        error("ProtesisPracticas:E2AInvalidTeacherDataset", ...
            "Falta el episodio teacher correspondiente a la seleccion EMG.");
    end
    teacherData = teacherLoaded.gloves{repetition, side};
    if ~isstruct(teacherData) || isempty(teacherData)
        error("ProtesisPracticas:E2AInvalidTeacherEpisode", ...
            "El episodio teacher historico debe ser un struct no vacio.");
    end
    provenance.loadedVariables = ["emgs", "gloves"];
    provenance.teacherSamples = size(teacherData, 1);
    provenance.teacherSHA256 = bytesSha256(unicode2native(jsonencode(teacherData), "UTF-8"));
    provenance.teacherHashMethod = "SHA256(MATLAB-jsonencode-UTF8)";
end
end

function loaded = loadSelectedVariable(datasetPath, variableName)
loaded = load(datasetPath, variableName);
end

function hash = numericSha256(values)
[~, ~, endian] = computer;
descriptor = sprintf("%s;%s;%s;", class(values), mat2str(size(values)), endian);
descriptorBytes = uint8(unicode2native(descriptor, "UTF-8"));
bytes = [descriptorBytes(:); ...
    reshape(typecast(values(:), "uint8"), [], 1)];
hash = bytesSha256(bytes);
end

function hash = bytesSha256(bytes)
digest = java.security.MessageDigest.getInstance("SHA-256");
digest.update(bytes);
hash = string(lower(reshape(dec2hex(typecast(digest.digest(), "uint8"), 2)', 1, [])));
end
