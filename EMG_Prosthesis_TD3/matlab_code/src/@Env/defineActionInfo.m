function actionInfo = defineActionInfo()
%defineActionInfo() is a static method that retuns the limits and dimension
%of the action space of the environment.
%The action is defined as a vector of speeds (i.e. 4 pwm values, one for
%each motor).
%
% Examples
%   actionInfo = Env.defineActionInfo()
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: ztjona!
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

12 October 2021
Matlab 9.9.0.1718557 (R2020b) Update 6.
%}

%% configs
minAction = configurables('minAction'); % loading predefined values
maxAction = configurables('maxAction'); % loading predefined values

numMotors = definitions('numMotors');

%% creating observation space
actionInfo = rlNumericSpec([numMotors 1]); % col-wise
%, 'DataType', 'int16'

%% defining properties
actionInfo.LowerLimit = minAction;
actionInfo.UpperLimit = maxAction;

actionInfo.Name = 'prosthesis_action_space';
actionInfo.Description = sprintf('Actions defined by %d PWM speeds', ...
    numMotors);
