function results = run_paired_reference_stage1_export_dataset(options)
%run_paired_reference_stage1_export_dataset B.3 de la ETAPA E1.
%
%   Construye el dataset offline (phi_t, y_t) reproduciendo el timing real
%   del pipeline, y lo exporta por sujeto para el analisis posterior.
%
%   NO entrena. NO construye Env. NO toca planta, reward ni TD3.
%
%   Componentes usados, todos los del pipeline historico:
%     RecordedMyo        200 Hz, ventana = floor(200 * period) muestras
%     RecordedGlove       10 Hz, ventana = floor(10  * period) muestras
%     configs.fGetFeatures  -> getWmoosFeatures(emg, C, S)     40x1
%     reduceFlexDimension   -> 9 flex  -> 4 dedos
%     configs.flexJoined_scale
%     configs.period = 0.2 s
%
%   El desplazamiento k NO se aplica aqui: se exporta la serie completa por
%   episodio con su indice de paso, y k se barre en el analisis. Asi un solo
%   export sirve para todo k en [-2, +2].
%
%   results = run_paired_reference_stage1_export_dataset()

arguments
    options.outputRoot (1,1) string = ""
    options.subjects (1,:) string = string([])
    options.maxRowsPerSubject (1,1) double {mustBeInteger, mustBePositive} = 40000
end

here = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(here));
projectRoot = fileparts(matlabRoot);
workspaceRoot = fileparts(projectRoot);
addpath(genpath(matlabRoot));
oldDir = cd(matlabRoot);
restoreDir = onCleanup(@() cd(oldDir)); %#ok<NASGU>
clearConfigurablesOverride();

configs = configurables();
period = configs.period;
fGetFeatures = configs.fGetFeatures;
flexScaler = configs.flexJoined_scale;

subjects = string(configs.dataset(:))';
if ~isempty(options.subjects)
    subjects = options.subjects;
end

if strlength(options.outputRoot) > 0
    outRoot = char(options.outputRoot);
else
    outRoot = fullfile(workspaceRoot, "Agentes", "paired_reference", "stage1", "export");
end
ensureDirectoryExists(outRoot);

results = struct();
results.timestamp = string(datetime("now", Format="yyyy-MM-dd HH:mm:ss"));
results.period = period;
results.emgWindowSamples = floor(200 * period);
results.gloveWindowSamples = floor(10 * period);
results.subjects = subjects;
results.outRoot = string(outRoot);
results.normC = configs.norm.C(:)';
results.normS = configs.norm.S(:)';

fprintf("Ventana EMG   : %d muestras (200 Hz x %.2f s)\n", results.emgWindowSamples, period);
fprintf("Ventana guante: %d muestras ( 10 Hz x %.2f s)\n\n", results.gloveWindowSamples, period);

perSubject = struct("subject", {}, "nPairs", {}, "nSteps", {}, "file", {});

for s = subjects
    fprintf("--- %s ", s);
    [emg, glove, ~] = getDataset({char(s)}, configs.dataset_folder);

    nMax = options.maxRowsPerSubject;
    X = zeros(nMax, 40);
    Y = zeros(nMax, 4);
    recordIdx = zeros(nMax, 1);
    columnIdx = zeros(nMax, 1);   % 1 = closing, 2 = opening
    stepIdx = zeros(nMax, 1);
    stepsInEpisode = zeros(nMax, 1);
    k = 0;
    nPairs = 0;

    for r = 1:size(emg, 1)
        for c = 1:size(emg, 2)
            e = emg{r, c};
            g = glove{r, c};
            if isempty(e) || isempty(g)
                continue
            end
            nPairs = nPairs + 1;

            myo = RecordedMyo(e);
            gl = RecordedGlove(g);
            step = 0;
            firstRow = k + 1;

            while true
                emgWin = myo.readEmg(period);
                flexWin = gl.read(period);

                if size(emgWin, 1) < 2 || isempty(flexWin)
                    break
                end

                phi = fGetFeatures(emgWin);
                yWin = flexScaler(reduceFlexDimension(flexWin));

                step = step + 1;
                k = k + 1;
                if k > nMax
                    error("maxRowsPerSubject insuficiente para %s", s);
                end
                X(k, :) = phi(:)';
                Y(k, :) = yWin(end, :);
                recordIdx(k) = r;
                columnIdx(k) = c;
                stepIdx(k) = step;

                if myo.exhausted || gl.exhausted
                    break
                end
            end

            if step > 0
                stepsInEpisode(firstRow:k) = step;
            end
        end
    end

    X = X(1:k, :);
    Y = Y(1:k, :);
    recordIdx = recordIdx(1:k);
    columnIdx = columnIdx(1:k);
    stepIdx = stepIdx(1:k);
    stepsInEpisode = stepsInEpisode(1:k);
    subject = s; %#ok<NASGU>

    outFile = fullfile(outRoot, sprintf("%s_stage1.mat", s));
    save(outFile, "X", "Y", "recordIdx", "columnIdx", "stepIdx", ...
        "stepsInEpisode", "subject", "-v7");

    fprintf(": %d pares, %d pasos -> %s\n", nPairs, k, outFile);
    perSubject(end+1) = struct("subject", s, "nPairs", nPairs, ...
        "nSteps", k, "file", string(outFile)); %#ok<AGROW>
end

results.perSubject = struct2table(perSubject);
results.totalPairs = sum(results.perSubject.nPairs);
results.totalSteps = sum(results.perSubject.nSteps);

fprintf("\nTotal: %d pares, %d pasos\n", results.totalPairs, results.totalSteps);

save(fullfile(outRoot, "stage1_export_manifest.mat"), "results");
fprintf("Manifiesto: %s\n", fullfile(outRoot, "stage1_export_manifest.mat"));
end
