function result = e2bTeacherAvailability(nEmg, nGlove)
%e2bTeacherAvailability contrato historico de disponibilidad, sin leer datos.
% Longitudes en muestras a 200 Hz EMG / 10 Hz teacher, periodo fijo 0.2 s.
% Los lectores marcan exhausted si j>=n: puede quedar una ultima muestra.
% Reset consume un bloque; Env siempre realiza al menos un step antes de
% checkEndEpisode, mientras GloveFreePolicyRuntime puede agotarse en reset.
% No modifica esa semantica. Longitudes invalidas permanecen visibles.

result = struct("valid", false, "invalidReason", "", ...
    "nEmg", scalarOrNan(nEmg), "nGlove", scalarOrNan(nGlove), ...
    "emgNominalSeconds", NaN, "teacherNominalSeconds", NaN, ...
    "emgResetConsumed", NaN, "teacherResetConsumed", NaN, ...
    "emgExhaustedAtReset", false, "teacherExhaustedAtReset", false, ...
    "hEmg", NaN, "hTeacher", NaN, "hHistorical", NaN, ...
    "emgOnlySeconds", NaN, "historicalSeconds", NaN, ...
    "emgConsumedHistorical", NaN, "teacherConsumedHistorical", NaN, ...
    "emgConsumedRuntime", NaN, ...
    "emgExhaustedHistorical", false, "teacherExhaustedHistorical", false, ...
    "terminationCause", "INVALID_LENGTH", ...
    "unusedEmgSamples", NaN, "unusedEmgFraction", NaN, ...
    "teacherDiscardedEmgSamples", NaN, "teacherDiscardedEmgFraction", NaN, ...
    "emgReaderResidualSamples", NaN, "earlyTeacherTermination", false, ...
    "bootstrapFactorDifference", NaN, "reachesHistoricalMaxSteps50", false);
if ~validLength(nEmg) || ~validLength(nGlove)
    result.invalidReason = "Las longitudes deben ser escalares enteros positivos finitos.";
    return
end
nEmg = double(nEmg);
nGlove = double(nGlove);
result.valid = true;
result.emgNominalSeconds = nEmg / 200;
result.teacherNominalSeconds = nGlove / 10;
result.emgResetConsumed = min(nEmg, 40);
result.teacherResetConsumed = min(nGlove, 2);
result.emgExhaustedAtReset = result.emgResetConsumed >= nEmg - 1;
result.teacherExhaustedAtReset = result.teacherResetConsumed >= nGlove - 1;
result.hEmg = max(0, ceil((nEmg - 1) / 40) - 1);
result.hTeacher = max(0, ceil((nGlove - 1) / 2) - 1);
result.hHistorical = max(1, min(result.hEmg, result.hTeacher));
result.emgOnlySeconds = 0.2 * result.hEmg;
result.historicalSeconds = 0.2 * result.hHistorical;
result.emgConsumedHistorical = min(nEmg, 40 * (1 + result.hHistorical));
result.teacherConsumedHistorical = min(nGlove, 2 * (1 + result.hHistorical));
result.emgConsumedRuntime = min(nEmg, 40 * (1 + result.hEmg));
result.emgExhaustedHistorical = result.emgConsumedHistorical >= nEmg - 1;
result.teacherExhaustedHistorical = result.teacherConsumedHistorical >= nGlove - 1;
if result.emgExhaustedHistorical && result.teacherExhaustedHistorical
    result.terminationCause = "EMG_AND_TEACHER";
elseif result.emgExhaustedHistorical
    result.terminationCause = "EMG_ONLY";
else
    result.terminationCause = "TEACHER_ONLY";
end
result.unusedEmgSamples = nEmg - result.emgConsumedHistorical;
result.unusedEmgFraction = result.unusedEmgSamples / nEmg;
result.teacherDiscardedEmgSamples = max(0, ...
    result.emgConsumedRuntime - result.emgConsumedHistorical);
result.teacherDiscardedEmgFraction = result.teacherDiscardedEmgSamples / nEmg;
result.emgReaderResidualSamples = nEmg - result.emgConsumedRuntime;
result.earlyTeacherTermination = result.teacherExhaustedHistorical && ...
    ~result.emgExhaustedHistorical;
% Diferencia (EMG-only menos historico) en gamma*(1-done), NO un target Q.
result.bootstrapFactorDifference = 0.95 * double(result.earlyTeacherTermination);
result.reachesHistoricalMaxSteps50 = result.hHistorical >= 50;
end

function yes = validLength(value)
yes = isnumeric(value) && isreal(value) && isscalar(value) && ...
    isfinite(value) && value > 0 && value == fix(value);
end

function value = scalarOrNan(value)
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value)
    value = NaN;
else
    value = double(value);
end
end
