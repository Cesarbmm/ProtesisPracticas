function traceFiles = e3fExportEpisodeTraces(trace, rTrace, tracesDir, split)
% e3fExportEpisodeTraces exporta evidencia numerica completa por episodio:
% CSV y MAT con: step, teacher por motor, h(q) por motor, error por motor,
% q, delta_q, categoryIndex, PWM, effectiveAction, selectedProbability, headEntropy, rewardStep.

arguments
    trace struct
    rTrace struct
    tracesDir string
    split string = "VALIDATION"
end

splitDir = fullfile(tracesDir, split);
if ~isfolder(splitDir), mkdir(splitDir); end

md = trace.metadata;
if isfield(md, "repetition")
    row = double(md.repetition);
elseif isfield(md, "row")
    row = double(md.row);
else
    error("E3F:ExportTraceMetadata", "Falta repetition o row en metadata.");
end
subject = string(md.subject);
safeSubject = regexprep(subject, "[^A-Za-z0-9_-]", "_");
directions = ["closing", "opening"];
dirStr = directions(md.side);

stem = safeSubject + compose("_row%04d_", row) + dirStr;
csvFile = fullfile(splitDir, stem + ".csv");
matFile = fullfile(splitDir, stem + ".mat");

ref = trace.reference;
pred = trace.prediction;
err = ref - pred;
pwm = trace.pwm;
eff = trace.effectiveAction;
q = trace.q(2:end, :);
dq = [trace.q(2, :) - trace.q(1, :); diff(trace.q(2:end, :))];
n = size(ref, 1);

levels = [0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];
catIdx = zeros(n, 4);
for m = 1:4
    for k = 1:n
        c = find(levels == pwm(k, m), 1);
        if isempty(c), c = 1; end
        catIdx(k, m) = c;
    end
end

prob = zeros(n, 4);
if isfield(trace, "selectedProbability")
    prob = trace.selectedProbability;
end
ent = zeros(n, 4);
if isfield(trace, "headEntropy")
    ent = trace.headEntropy;
end
rw = trace.reward;
if numel(rw) == 1, rw = repmat(rw, n, 1); end

T = table((1:n)', ...
    ref(:, 1), ref(:, 2), ref(:, 3), ref(:, 4), ...
    pred(:, 1), pred(:, 2), pred(:, 3), pred(:, 4), ...
    err(:, 1), err(:, 2), err(:, 3), err(:, 4), ...
    q(:, 1), q(:, 2), q(:, 3), q(:, 4), ...
    dq(:, 1), dq(:, 2), dq(:, 3), dq(:, 4), ...
    catIdx(:, 1), catIdx(:, 2), catIdx(:, 3), catIdx(:, 4), ...
    pwm(:, 1), pwm(:, 2), pwm(:, 3), pwm(:, 4), ...
    eff(:, 1), eff(:, 2), eff(:, 3), eff(:, 4), ...
    prob(:, 1), prob(:, 2), prob(:, 3), prob(:, 4), ...
    ent(:, 1), ent(:, 2), ent(:, 3), ent(:, 4), ...
    rw, ...
    'VariableNames', {'step', ...
    'teacher_m1', 'teacher_m2', 'teacher_m3', 'teacher_m4', ...
    'hq_m1', 'hq_m2', 'hq_m3', 'hq_m4', ...
    'error_m1', 'error_m2', 'error_m3', 'error_m4', ...
    'q_m1', 'q_m2', 'q_m3', 'q_m4', ...
    'delta_q_m1', 'delta_q_m2', 'delta_q_m3', 'delta_q_m4', ...
    'categoryIndex_m1', 'categoryIndex_m2', 'categoryIndex_m3', 'categoryIndex_m4', ...
    'pwm_m1', 'pwm_m2', 'pwm_m3', 'pwm_m4', ...
    'effectiveAction_m1', 'effectiveAction_m2', 'effectiveAction_m3', 'effectiveAction_m4', ...
    'selectedProbability_m1', 'selectedProbability_m2', 'selectedProbability_m3', 'selectedProbability_m4', ...
    'headEntropy_m1', 'headEntropy_m2', 'headEntropy_m3', 'headEntropy_m4', ...
    'rewardStep'});

writetable(T, csvFile);
episodeData = struct("trace", trace, "runtimeTrace", rTrace, "table", T);
save(matFile, "episodeData");

traceFiles = struct("csv", string(csvFile), "mat", string(matFile));
end
