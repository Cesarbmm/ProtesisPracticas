function model = handKinematicModel(options)
%handKinematicModel modelo cinematico de la mano para el visor del sandbox.
%
%   IMPORTANTE — que es evidencia y que es convencion de dibujo:
%
%   EVIDENCIA DEL REPOSITORIO (no inventado aqui):
%     * Orden de motores 1..4 = little, idx, thumb, mid.
%       config/definitions.m:31-36 (motorIdx / fingers "names in order!")
%       prosthesis_code/include/definitions.h:21 ("Motor order: little, idx, thumb, mid")
%     * Limites de encoder por motor = [26500 11500 8500 9000].
%       config/definitions.m:49-52 (breakLimit)
%       prosthesis_code/include/definitions.h:23 (ENCODER_MAX_LIMS)
%       config/configurables.m:277 (encoder2state_scale divide por esos mismos valores)
%     * El canal "little" del guante agrega los sensores de ANULAR y MENIQUE:
%       config/definitions.m:80  flexMapping.little = {ringUp, ringDown, pinkyUp, pinkyDown}
%       => en el visor el motor 1 mueve meñique y anular juntos.
%     * Proporciones RELATIVAS de dedo tomadas de la extension mayor de la caja
%       envolvente de los STL del repositorio (STLS/Fingers/*.stl), medidas en la
%       auditoria S0: middle 101.21, index 94.92, ring 88.44, little 75.13,
%       thumb 81.01 (mm de la pieza). Solo se usa el ORDEN/PROPORCION relativa.
%
%   VISUALIZATION_ONLY (convenciones de dibujo sin base medida):
%     * Escala absoluta de la mano, reparto de longitud entre falanges,
%       ganancias angulares por articulacion, abduccion y pose de oposicion del
%       pulgar, y posiciones de las bases sobre la palma.
%     * Los STL estan modelados en pose curvada y con base de montaje, de modo
%       que su caja envolvente NO da longitudes de falange: por eso solo se usa
%       la proporcion relativa y no una longitud absoluta.
%     * NADA de esto afirma la relacion real motor -> tendon -> articulacion.
%       Mientras no exista cinematica medida, cualquier angulo de este archivo es
%       una convencion de dibujo, no una propiedad de la protesis.
%
%   Uso:
%     model = handKinematicModel();
%     model = handKinematicModel(rangeMode="encoderLimit");
%
%   rangeMode fija el rango de q con el que se normaliza la flexion visual:
%     "plantReachable" (por defecto) usa el recorrido que la planta canonica
%        alcanza realmente segun pattern_curve.mat. Es el rango honesto para
%        animar un replay: la planta NUNCA llega a q normalizada 1.
%     "encoderLimit" usa [26500 11500 8500 9000] del firmware. Con este modo la
%        mano dibujada nunca se cierra del todo, porque la planta no alcanza
%        esos limites.

arguments
    options.rangeMode (1, 1) string {mustBeMember(options.rangeMode, ...
        ["plantReachable", "encoderLimit"])} = "plantReachable"
end

model = struct();
model.rangeMode = options.rangeMode;

% --- evidencia: orden de motores y limites de encoder -------------------
model.motorNames = ["little", "idx", "thumb", "mid"];
model.encoderLimits = [26500 11500 8500 9000];
model.motorNamesSource = "config/definitions.m:31-36; prosthesis_code/include/definitions.h:21";
model.encoderLimitsSource = "config/definitions.m:49-52; prosthesis_code/include/definitions.h:23";

% --- rango de q usado para normalizar la flexion visual -----------------
switch model.rangeMode
    case "encoderLimit"
        model.qRangeEncoder = [zeros(1, 4); model.encoderLimits];
        model.qRangeSource = "ENCODER_MAX_LIMS del firmware";
    otherwise
        model.qRangeEncoder = sandboxPlantReachableRange();
        model.qRangeSource = "recorrido de pattern_curve.mat (planta canonica)";
end

% --- dedos --------------------------------------------------------------
% relativeLength: proporcion tomada de los STL (evidencia, ver cabecera).
% segmentSplit y jointGainDeg: VISUALIZATION_ONLY.
% basePalm: VISUALIZATION_ONLY, posicion de la base sobre la palma [x y z] mm.
% abductionDeg: VISUALIZATION_ONLY, giro de la base alrededor de Z.
model.palm = struct( ...
    "width", 78, "length", 95, "thickness", 20, ...
    "note", "VISUALIZATION_ONLY: caja de palma, sin relacion con el CAD real");
model.middleReferenceLength = 95;   % VISUALIZATION_ONLY, escala absoluta [mm]

fingers = struct("name", {}, "motor", {}, "relativeLength", {}, ...
    "segmentSplit", {}, "jointGainDeg", {}, "basePalm", {}, "abductionDeg", {});

fingers(1) = struct("name", "index", "motor", 2, "relativeLength", 94.92/101.21, ...
    "segmentSplit", [0.45 0.32 0.23], "jointGainDeg", [80 95 60], ...
    "basePalm", [-27 95 0], "abductionDeg", -5);
fingers(2) = struct("name", "middle", "motor", 4, "relativeLength", 1.0, ...
    "segmentSplit", [0.45 0.32 0.23], "jointGainDeg", [80 95 60], ...
    "basePalm", [-9 97 0], "abductionDeg", 0);
fingers(3) = struct("name", "ring", "motor", 1, "relativeLength", 88.44/101.21, ...
    "segmentSplit", [0.45 0.32 0.23], "jointGainDeg", [80 95 60], ...
    "basePalm", [9 95 0], "abductionDeg", 5);
fingers(4) = struct("name", "little", "motor", 1, "relativeLength", 75.13/101.21, ...
    "segmentSplit", [0.45 0.32 0.23], "jointGainDeg", [80 95 60], ...
    "basePalm", [26 90 0], "abductionDeg", 11);
fingers(5) = struct("name", "thumb", "motor", 3, "relativeLength", 81.01/101.21, ...
    "segmentSplit", [0.55 0.45 0], "jointGainDeg", [45 70 0], ...
    "basePalm", [-34 30 -6], "abductionDeg", -50);

model.fingers = fingers;
model.fingerNames = string({fingers.name});
model.motorOfFinger = [fingers.motor];
model.coupledMotors = struct("motor", 1, "fingers", ["ring", "little"], ...
    "evidence", "config/definitions.m:80 flexMapping.little = ringUp/ringDown/pinkyUp/pinkyDown");

model.visualizationOnlyFields = ["palm", "middleReferenceLength", ...
    "segmentSplit", "jointGainDeg", "basePalm", "abductionDeg"];
model.contract = struct( ...
    "input", "q 1x4 en unidades declaradas explicitamente (encoder o normalized)", ...
    "motorOrder", "1=little 2=idx 3=thumb 4=mid", ...
    "gloveRole", "solo overlay de referencia; nunca modifica q ni la pose", ...
    "physicsRole", "ninguno: el visor no integra dinamica ni altera la planta");
end
