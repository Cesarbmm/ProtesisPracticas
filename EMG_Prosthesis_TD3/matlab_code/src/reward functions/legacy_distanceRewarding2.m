function [reward, action] = legacy_distanceRewarding2(this, action)
%% Configuración y definiciones de recompensas
%opts.regionStop = 0.05; % 5% de tolerancia para la condición de mantener posición%
%opts.distanceThreshold = 0.4; % 10% de tolerancia para la corrección de acción

% Definición de recompensas
rewards.goodMove = 10;
%rewards.mantainAction = 2.5;
rewards.farAway = -5;
rewards.wrongStop = -4;
rewards.dirInverse = -5;
rewards.goalAction = 15; % Recompensa por corrección
%penalizationFactor = -10; % Factor de penalización por la distancia
rewardVector = zeros(1, length(action));

%% Lectura de datos de flexión y posición
if this.c == 1
    flexConv = this.flexJoined_scaler(reduceFlexDimension(this.flexData));
else
    flexConv = this.flexConvertedLog{this.c - 1};
end
pos = this.motorData(end, :);
posFlex = this.flexJoined_scaler(encoder2Flex(pos));

%% --- Evaluación de acciones y cálculo de recompensas
for i = 1:length(action)
    distance = posFlex(i) * 0.1;
    distance2 = posFlex(i) * 0.5;
    %En movimientos
    if posFlex(i)~= flexConv
        if posFlex(i) > flexConv(end, i)
            correctAction = 1; % Debería moverse adelante
        else
            correctAction = -1; % Debería moverse atrás
        end
        %Asignacion de recompensa
        if action(i) == correctAction
            rewardVector(i) = rewards.goodMove;
        else
            rewardVector(i) = rewards.dirInverse;
        end

    else
        correctAction = 0;

        % Recompensa
        if action(i) == correctAction
            rewardVector(i) = rewards.goodMove;
        else
            rewardVector(i) = rewards.wrongStop;
        end

    end

    % Recompensa por alcanzar la posición objetivo
    if (flexConv(end, i)< posFlex(i) + distance) && (flexConv(end, i)> posFlex(i) - distance)
        rewardVector(i) = rewardVector(i) + rewards.goalAction;
    end
    % Penalización proporcional a la distancia
    %rewardVector(i) = rewardVector(i) + penalizationFactor * distance;
    %if (flexConv(end, i)< posFlex(i) + distance2) && (flexConv(end, i)> posFlex(i) - distance2)
    %    rewardVector(i) = rewardVector(i) + rewards.farAway;
    %end
end
% Calcular la recompensa final sumando los valores del vector de recompensa
reward = sum(rewardVector);

end