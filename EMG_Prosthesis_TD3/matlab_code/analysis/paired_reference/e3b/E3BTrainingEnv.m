classdef E3BTrainingEnv < handle
    % Adaptador de categorias sobre Env INTACTO. Teacher/done originales.
    properties (SetAccess=private)
        Historical
    end
    methods
        function obj=E3BTrainingEnv(emgs,gloves),obj.Historical=Env("",true,emgs,gloves);end
        function state=reset(obj),state=reset(obj.Historical);end
        function [state,reward,done,record]=step(obj,category)
            pwm=e3bCategoryPWM(category);assert(size(pwm,2)==1,"E3B:ActionShape","Una accion por paso.");
            before=obj.Historical.motorData(end,:);previous=obj.Historical.prevAction;
            [state,reward,done]=step(obj.Historical,pwm/255);
            k=obj.Historical.c;applied=obj.Historical.actionPwmLog(k,:)';effective=obj.Historical.actionSatLog(k,:)';
            assert(isequal(applied,pwm) && isequal(effective,pwm/255) && isequal(state(49:52),effective),"E3B:TransitionContract","El puerto historico debe preservar el PWM categórico.");
            record=struct("pwm",applied,"effectiveAction",effective,"previousEffective",previous,"qBefore",before, ...
                "q",obj.Historical.motorData(end,:),"reference",obj.Historical.flexConverted(end,:), ...
                "prediction",obj.Historical.adjustEnc(end,:),"teacherDone",done);
            expected=mean(-(record.prediction-record.reference).^2-.01*effective'.^2-.05*(effective-previous)'.^2);
            assert(abs(expected-reward)<=1e-12,"E3B:RewardContract","Reward distinto al historico.");
        end
    end
end
