classdef E3BCategoricalActor
    % Adaptador de evaluacion. No es rlDiscreteCategoricalActor ni agente TD3.
    properties
        Network
    end
    methods
        function obj=E3BCategoricalActor(net),obj.Network=net;end
        function [p,h]=distribution(obj,state)
            if iscell(state),state=cell2mat(state);end
            z=e3bLogits(obj.Network,dlarray(single(state),"CB"));
            [~,hd,pd]=e3bCategoricalTerms(z,[]);
            p=double(extractdata(pd));h=double(extractdata(hd));
            assert(all(isfinite(p),"all") && all(isfinite(h),"all"),"E3B:Distribution","Probabilidades no finitas.");
        end
        function [action,state]=getAction(obj,observation)
            [p,~]=obj.distribution(observation);[~,category]=max(p,[],1);category=reshape(category,4,[]);
            pwm=e3bCategoryPWM(category);action={pwm/255};state=[];
        end
        function values=getLearnableParameters(obj),values=obj.Network.Learnables.Value;end
    end
end
