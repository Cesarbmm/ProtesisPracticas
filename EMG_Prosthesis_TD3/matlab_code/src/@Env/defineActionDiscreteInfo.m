function actionInfo = defineActionDiscreteInfo()
% defineActionDiscreteInfo() defines discrete actions, currently, only 3
% actions for each motor of the agent
%
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: ztjona
jonathan.a.zea@ieee.org
Cuando escribí este código, solo dios y yo sabíamos como funcionaba.
Ahora solo lo sabe dios.

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

31 January 2022

Mod 2024/jan/3
%}

%% configs
% each motor forward, stop or backward.
%
if configurables('unifyActions')
    actionInfo = rlFiniteSetSpec([-1 0 1]);
else
    % % Generates 81 actions, the
    % % combinations of the 4 motors and 3 actions
    actions = combvec([-1 0 1], [-1 0 1], [-1 0 1], [-1 0 1])';
    actionInfo = rlFiniteSetSpec(num2cell(actions, 2)');
end
%% defining properties

actionInfo.Name = 'prosthesis_action_space';
actionInfo.Description = ...
    'Actions defined as forward, stop and backward for all motors.';