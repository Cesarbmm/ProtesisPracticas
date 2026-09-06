function raw = e2bProportionalAction(qBefore, teacherAlreadyRead, kp)
%e2bProportionalAction P causal privilegiado, solo para diagnostico E2B.
% qBefore usa encoder real, no encoder normalizado de markov52.
% teacherAlreadyRead contiene exclusivamente registros ya leidos por Env.
% Se toma su ultima referencia; no se consulta el lector ni el dataset.
% La cuantizacion y la aplicacion de PWM corresponden al step historico.
arguments
    qBefore (1,4) double {mustBeReal, mustBeFinite}
    teacherAlreadyRead struct
    kp (1,1) double {mustBeReal, mustBeFinite, mustBeNonnegative}
end
if isempty(teacherAlreadyRead)
    error("E2B:TeacherUnavailable", ...
        "El diagnostico P requiere una referencia teacher ya leida.");
end
p = configurables();
reference = p.flexJoined_scale(reduceFlexDimension(teacherAlreadyRead));
prediction = p.flexJoined_scale(encoder2Flex(qBefore));
errorBefore = reference(end,:) - prediction(end,:);
if any(~isfinite(errorBefore))
    error("E2B:InvalidTeacher", "La referencia teacher debe ser finita.");
end
raw = max(-1, min(1, kp * errorBefore(:)));
end
