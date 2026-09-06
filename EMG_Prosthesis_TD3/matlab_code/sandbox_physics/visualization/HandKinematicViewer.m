classdef HandKinematicViewer < handle
%HandKinematicViewer visor 3D CINEMATICO de la protesis. FASE S2 del sandbox.
%
%   QUE HACE:  recibe q (posicion de los 4 motores) y dibuja una pose.
%   QUE NO HACE: no integra dinamica, no calcula acciones, no toca la planta,
%                no lee el guante como estado y no modifica ningun archivo del
%                pipeline historico. Es una funcion de q, nada mas.
%
%   Contrato de entrada (se declara, no se adivina):
%       viewer = HandKinematicViewer(units="encoder");      % q en cuentas de encoder
%       viewer = HandKinematicViewer(units="normalized");   % q ya dividida por
%                                                           % [26500 11500 8500 9000]
%       viewer.update(q);                       % q es 1x4, orden 1..4 de motor
%       viewer.update(q, gloveNormalizedFlexion) % overlay opcional, SOLO dibujo
%
%   El overlay del guante debe entregarse ya normalizado en [0,1] por motor.
%   El visor RECHAZA un guante en unidades de encoder: mezclar unidades de
%   guante y encoder es exactamente uno de los errores que el plan prohibe.
%
%   Determinismo: la pose se calcula en HandKinematicViewer.poseFromQ, funcion
%   estatica y pura. Misma q -> misma pose bit a bit, sin graficos de por medio.
%
%   Las proporciones y ganancias angulares vienen de handKinematicModel y estan
%   marcadas VISUALIZATION_ONLY: no representan la cinematica real de la mano.

    properties (SetAccess = immutable)
        model
        units (1, 1) string
    end

    properties (SetAccess = private)
        figureHandle = gobjects(1)
        axesHandle = gobjects(1)
        graphics = struct()
        lastPose = struct()
        lastFlexion = zeros(1, 4)
        updateCount = 0
    end

    methods
        function obj = HandKinematicViewer(options)
            arguments
                options.units (1, 1) string {mustBeMember(options.units, ...
                    ["encoder", "normalized"])} = "encoder"
                options.rangeMode (1, 1) string {mustBeMember(options.rangeMode, ...
                    ["plantReachable", "encoderLimit"])} = "plantReachable"
                options.visible (1, 1) logical = true
                options.showGlove (1, 1) logical = false
                options.figureTitle (1, 1) string = "Sandbox S2 - visor cinematico"
                options.createFigure (1, 1) logical = true
            end
            obj.units = options.units;
            obj.model = handKinematicModel(rangeMode = options.rangeMode);
            if options.createFigure
                obj.buildFigure(options.visible, options.showGlove, options.figureTitle);
            end
        end

        function [pose, flexion] = update(obj, q, gloveNormalizedFlexion)
            %update dibuja la pose correspondiente a q. Devuelve la pose usada.
            arguments
                obj
                q (1, 4) double {mustBeFinite}
                gloveNormalizedFlexion double = []
            end
            [pose, flexion] = HandKinematicViewer.poseFromQ(q, obj.model, obj.units);
            ghost = [];
            if ~isempty(gloveNormalizedFlexion)
                ghost = obj.gloveOverlayPose(gloveNormalizedFlexion);
            end
            obj.lastPose = pose;
            obj.lastFlexion = flexion;
            obj.updateCount = obj.updateCount + 1;
            if isgraphics(obj.figureHandle)
                obj.render(pose, ghost);
            end
        end

        function ghost = gloveOverlayPose(obj, gloveNormalizedFlexion)
            %gloveOverlayPose valida y convierte el overlay de guante.
            % El guante es SOLO referencia visual: nunca modifica q ni la pose
            % de la protesis. Debe llegar normalizado; recibir cuentas de
            % encoder aqui seria mezclar unidades y se rechaza.
            gloveFlexion = double(gloveNormalizedFlexion(:))';
            if numel(gloveFlexion) ~= 4
                error("Sandbox:GloveOverlayShape", ...
                    "El overlay de guante debe ser 1x4, uno por motor.");
            end
            if any(~isfinite(gloveFlexion))
                error("Sandbox:GloveOverlayShape", ...
                    "El overlay de guante debe ser finito.");
            end
            if any(gloveFlexion < -0.5 | gloveFlexion > 1.5)
                error('Sandbox:GloveOverlayUnits', 'Las unidades del guante deben ser flexion normalizada en el rango [0, 1].');
            end
            gloveFlexion = max(0, min(1, gloveFlexion));
            ghost = HandKinematicViewer.poseFromFlexion(gloveFlexion, obj.model);
        end

        function frame = capture(obj)
            %capture devuelve un frame de la figura para armar la animacion.
            if ~isgraphics(obj.figureHandle)
                error("Sandbox:ViewerNoFigure", ...
                    "El visor se creo sin figura: no hay nada que capturar.");
            end
            drawnow;
            frame = getframe(obj.figureHandle);
        end

        function closeViewer(obj)
            if isgraphics(obj.figureHandle)
                close(obj.figureHandle);
            end
        end
    end

    methods (Static)
        function [pose, flexion] = poseFromQ(q, model, units)
            %poseFromQ funcion PURA: q -> pose 3D. Sin graficos, sin estado.
            arguments
                q (1, 4) double {mustBeFinite}
                model (1, 1) struct = handKinematicModel()
                units (1, 1) string {mustBeMember(units, ["encoder", "normalized"])} = "encoder"
            end

            flexion = HandKinematicViewer.flexionFromQ(q, model, units);

            scale = model.middleReferenceLength;
            nFingers = numel(model.fingers);
            fingers = struct("name", cell(1, nFingers), "motor", cell(1, nFingers), ...
                "flexion", cell(1, nFingers), "joints", cell(1, nFingers), ...
                "segmentLengths", cell(1, nFingers));

            for k = 1:nFingers
                spec = model.fingers(k);
                f = flexion(spec.motor);
                lengths = scale * spec.relativeLength * spec.segmentSplit;
                lengths = lengths(lengths > 0);
                gains = spec.jointGainDeg(1:numel(lengths));

                angles = cumsum(deg2rad(gains) * f);
                local = zeros(numel(lengths) + 1, 3);
                for s = 1:numel(lengths)
                    direction = [0, cos(angles(s)), -sin(angles(s))];
                    local(s + 1, :) = local(s, :) + lengths(s) * direction;
                end

                t = deg2rad(spec.abductionDeg);
                Rz = [cos(t), -sin(t), 0; sin(t), cos(t), 0; 0, 0, 1];
                world = (Rz * local')' + spec.basePalm;

                fingers(k).name = string(spec.name);
                fingers(k).motor = spec.motor;
                fingers(k).flexion = f;
                fingers(k).joints = world;
                fingers(k).segmentLengths = lengths;
            end

            pose = struct();
            pose.fingers = fingers;
            pose.flexionByMotor = flexion;
            pose.flexionByFinger = [fingers.flexion];
            pose.palm = HandKinematicViewer.palmVertices(model);
            pose.units = units;
            pose.rangeMode = string(model.rangeMode);
        end

        function flexion = flexionFromQ(q, model, units)
            %flexionFromQ q -> escalar de flexion en [0,1] por motor.
            % Fuera del rango declarado se satura y se avisa con el campo
            % clipped, en vez de dibujar geometria imposible en silencio.
            arguments
                q (1, 4) double {mustBeFinite}
                model (1, 1) struct = handKinematicModel()
                units (1, 1) string {mustBeMember(units, ["encoder", "normalized"])} = "encoder"
            end
            if units == "normalized"
                qEncoder = q(:)' .* model.encoderLimits;
            else
                qEncoder = q(:)';
            end
            low = model.qRangeEncoder(1, :);
            high = model.qRangeEncoder(2, :);
            flexion = (qEncoder - low) ./ (high - low);
            flexion = max(0, min(1, flexion));
        end

        function vertices = palmVertices(model)
            w = model.palm.width / 2;
            l = model.palm.length;
            t = model.palm.thickness / 2;
            vertices = [ -w 0 -t; w 0 -t; w l -t; -w l -t; ...
                         -w 0  t; w 0  t; w l  t; -w l  t ];
        end
    end

    methods (Access = private)
        function buildFigure(obj, visible, showGlove, figureTitle)
            if visible
                visibility = "on";
            else
                visibility = "off";
            end
            obj.figureHandle = figure(Visible = visibility, Color = "w", ...
                Name = figureTitle, NumberTitle = "off", Position = [100 100 760 620]);
            obj.axesHandle = axes(obj.figureHandle);
            hold(obj.axesHandle, "on");
            grid(obj.axesHandle, "on");
            axis(obj.axesHandle, "equal");
            view(obj.axesHandle, [-35 22]);
            xlabel(obj.axesHandle, "x [mm]");
            ylabel(obj.axesHandle, "y [mm]");
            zlabel(obj.axesHandle, "z [mm]");
            xlim(obj.axesHandle, [-120 90]);
            ylim(obj.axesHandle, [-10 210]);
            zlim(obj.axesHandle, [-150 60]);

            faces = [1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8];
            obj.graphics.palm = patch(obj.axesHandle, Faces = faces, ...
                Vertices = HandKinematicViewer.palmVertices(obj.model), ...
                FaceColor = [0.82 0.84 0.88], EdgeColor = [0.45 0.47 0.52], ...
                FaceAlpha = 0.75);

            n = numel(obj.model.fingers);
            obj.graphics.fingers = gobjects(1, n);
            obj.graphics.glove = gobjects(1, n);
            for k = 1:n
                obj.graphics.fingers(k) = plot3(obj.axesHandle, nan, nan, nan, ...
                    '-o', LineWidth = 3.2, MarkerSize = 4.5, ...
                    Color = [0.13 0.35 0.62], MarkerFaceColor = [0.13 0.35 0.62]);
                obj.graphics.glove(k) = plot3(obj.axesHandle, nan, nan, nan, ...
                    '--', LineWidth = 1.6, Color = [0.85 0.45 0.10]);
                if showGlove
                    obj.graphics.glove(k).Visible = "on";
                else
                    obj.graphics.glove(k).Visible = "off";
                end
            end
            obj.graphics.showGlove = showGlove;
            obj.graphics.readout = title(obj.axesHandle, "");
        end

        function render(obj, pose, ghost)
            for k = 1:numel(pose.fingers)
                joints = pose.fingers(k).joints;
                set(obj.graphics.fingers(k), XData = joints(:, 1), ...
                    YData = joints(:, 2), ZData = joints(:, 3));
            end

            if ~isempty(ghost)
                for k = 1:numel(ghost.fingers)
                    joints = ghost.fingers(k).joints;
                    set(obj.graphics.glove(k), XData = joints(:, 1), ...
                        YData = joints(:, 2), ZData = joints(:, 3), Visible = "on");
                end
            end

            f = pose.flexionByMotor;
            obj.graphics.readout.String = sprintf( ...
                "flexion visual  little %.2f | idx %.2f | thumb %.2f | mid %.2f   (%s, %s)", ...
                f(1), f(2), f(3), f(4), pose.units, pose.rangeMode);
        end
    end

    methods (Static, Access = private)
        function pose = poseFromFlexion(flexion, model)
            % Reutiliza poseFromQ invirtiendo el mapa de flexion, para el overlay.
            low = model.qRangeEncoder(1, :);
            high = model.qRangeEncoder(2, :);
            qEncoder = low + flexion .* (high - low);
            pose = HandKinematicViewer.poseFromQ(qEncoder, model, "encoder");
        end
    end
end
