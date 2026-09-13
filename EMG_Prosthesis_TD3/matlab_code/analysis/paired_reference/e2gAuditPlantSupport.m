function T = e2gAuditPlantSupport()
%e2gAuditPlantSupport reproduce la lectura de soporte original de E2G.
% Solo lee curvas, limites y aristas E2F; no consulta ni ejecuta la planta.
% Escribe exclusivamente e2g_results/plant_support_audit.csv. Ejecutar despues
% e2gAuditPlantSupportRaw.py para anadir las columnas de adquisiciones crudas.

here = string(fileparts(mfilename("fullpath")));
matlabRoot = fileparts(fileparts(here));
savedPath = path;
cleanup = onCleanup(@() path(savedPath)); %#ok<NASGU>
addpath(fullfile(matlabRoot, "src", "preprocess"));
addpath(fullfile(matlabRoot, "config"));

a = load(fullfile(matlabRoot, "src", "@SimController", "pattern_curve.mat"), "avgs");
L = readtable(fullfile(matlabRoot, "src", "@SimController", ...
    "plant_limits_canonical.csv"), TextType="string");
E = readtable(fullfile(here, "e2f_results", "graph_edges.csv"));
T = L;
div = [4092 2046 1023 2046];
for i = 1:height(L)
    m = L.motor(i);
    c = a.avgs.(L.speed_field(i)).(L.direction(i)).(sprintf("m_%d", m));
    q = unique(E.qBefore(E.motor == m));
    v = zeros(numel(q), 4);
    v(:, m) = q;
    h = encoder2Flex(v) ./ div;
    v = zeros(numel(c.avg), 4);
    v(:, m) = c.avg(:);
    ha = encoder2Flex(v) ./ div;
    T.graph_n_states(i) = numel(q);
    T.graph_q_min(i) = min(q);
    T.graph_q_max(i) = max(q);
    T.graph_h_min(i) = min(h(:, m));
    T.graph_h_max(i) = max(h(:, m));
    T.avg_q_min(i) = min(c.avg);
    T.avg_q_max(i) = max(c.avg);
    T.avg_h_min(i) = min(ha(:, m));
    T.avg_h_max(i) = max(ha(:, m));
    T.avg_first(i) = c.avg(1);
    T.avg_last(i) = c.avg(end);
    T.n_curve_samples(i) = numel(c.avg);
    T.n_repetitions(i) = size(c.data, 2);
    T.data_q_min(i) = min(c.data, [], "all");
    T.data_q_max(i) = max(c.data, [], "all");
    T.data_limits_match(i) = T.data_q_min(i) == T.min_lim(i) && ...
        T.data_q_max(i) == T.max_lim(i);
end
assert(height(T) == 56, "E2G:PlantSupportRows");
out = fullfile(here, "e2g_results");
if ~isfolder(out), mkdir(out); end
writetable(T, fullfile(out, "plant_support_audit.csv"));
fprintf("LIMITS_DATA_MATCH=%d/%d\n", nnz(T.data_limits_match), height(T));
end
