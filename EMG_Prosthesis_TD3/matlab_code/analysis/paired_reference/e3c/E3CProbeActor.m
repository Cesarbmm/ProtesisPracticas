classdef E3CProbeActor < handle
    % Actor causal de ventana corta. Ninguna interfaz recibe teacher/reward.
    properties (SetAccess=private)
        Network
        Kind
        L
        History=zeros(52,0)
        Probabilities=zeros(15,4,0)
        Entropies=zeros(4,0)
        Categories=zeros(4,0)
    end
    methods
        function obj=E3CProbeActor(net,kind,L),obj.Network=resetState(net);obj.Kind=string(kind);obj.L=L;end
        function reset(obj)
            obj.History=zeros(52,0);obj.Probabilities=zeros(15,4,0);obj.Entropies=zeros(4,0);obj.Categories=zeros(4,0);
        end
        function [action,state]=getAction(obj,observation)
            if iscell(observation),observation=cell2mat(observation);end
            assert(isequal(size(observation),[52,1]) && all(isfinite(observation)));
            obj.History=[obj.History,double(observation)];obj.History=obj.History(:,max(1,end-obj.L+1):end);
            [p,h]=e3cPredict(obj.Network,obj.Kind,obj.History);[~,c]=max(p,[],1);c=reshape(c,4,1);
            obj.Probabilities(:,:,end+1)=p;obj.Entropies(:,end+1)=h;obj.Categories(:,end+1)=c;
            action={e3bCategoryPWM(c)/255};state=[];
        end
        function values=getLearnableParameters(obj),values=obj.Network.Learnables.Value;end
    end
end
