function normParams = e3eComputeNormalizationParams()
% e3eComputeNormalizationParams: Calcula la mediana y MAD exclusivamente sobre TRAIN
% y genera la matriz de features normalizada para los 200 episodios.
cfg = e3eConfig();
if ~isfolder(cfg.output), mkdir(cfg.output); end

a = load(cfg.dataPath, "D");
D = a.D;
S = D.samples;

% Matriz original de features WMoos (40 x N_total)
N_samples = height(S);
X_orig = zeros(40, N_samples, 'single');
for e = 1:200
    epIx = find(S.episode == e);
    states = D.sequences{e}.state;
    X_orig(:, epIx) = single(states(1:40, :));
end

trainMask = (S.split == "TRAIN");
X_train = X_orig(:, trainMask);

% Mediana y MAD estrictamente sobre TRAIN
med_train = zeros(40, 1, 'single');
mad_train = zeros(40, 1, 'single');
epsilon = single(1e-6);

for f = 1:40
    vals = X_train(f, :);
    m = median(vals);
    med_train(f) = m;
    mad_train(f) = median(abs(vals - m));
end

% Asegurar que MAD no sea cero
mad_train(mad_train < epsilon) = epsilon;

% Normalización: (x - med) / (mad + eps)
X_norm = zeros(size(X_orig), 'single');
for f = 1:40
    X_norm(f, :) = (X_orig(f, :) - med_train(f)) ./ (mad_train(f) + epsilon);
end

normParams = struct(...
    "method", "ROBUST_TRAIN_STANDARDIZATION", ...
    "median_train", med_train, ...
    "mad_train", mad_train, ...
    "epsilon", epsilon, ...
    "train_samples_used", sum(trainMask), ...
    "val_samples_used", 0, ...
    "causal_deployable", true);

save(fullfile(cfg.output, "train_robust_normalization_params.mat"), "normParams", "X_norm", "X_orig", "-v7.3");

paramsTable = table((1:40)', med_train, mad_train, ...
    'VariableNames', ["FeatureIndex", "Median_TRAIN", "MAD_TRAIN"]);
writetable(paramsTable, fullfile(cfg.output, "normalization_parameters.csv"));

fprintf("Parámetros de normalización robusta calculados sobre %d muestras de TRAIN (0 de VAL).\n", sum(trainMask));
end
