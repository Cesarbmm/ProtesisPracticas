classdef E3DProbeActor < handle
    % Memoria exclusivamente EMG. La mecanica actual nunca se almacena.
    properties (SetAccess=private)
        Network
        Kind
        L=8
        EMGHistory=zeros(40,0)
        Probabilities=zeros(15,4,0)
        Entropies=zeros(4,0)
        Categories=zeros(4,0)
    end
    methods
        function obj=E3DProbeActor(net,kind),obj.Network=resetState(net);obj.Kind=string(kind);end
        function reset(obj)
            obj.EMGHistory=zeros(40,0);obj.Probabilities=zeros(15,4,0);obj.Entropies=zeros(4,0);obj.Categories=zeros(4,0);
        end
        function [action,state]=getAction(obj,observation)
            if iscell(observation),observation=cell2mat(observation);end
            assert(isequal(size(observation),[52,1]) && all(isfinite(observation)));
            obj.EMGHistory=[obj.EMGHistory,double(observation(1:40))];obj.EMGHistory=obj.EMGHistory(:,max(1,end-obj.L+1):end);
            [p,h]=e3dPredict(obj.Network,obj.Kind,obj.EMGHistory,double(observation(41:52)));[~,cats]=max(p,[],1);cats=reshape(cats,4,1);
            obj.Probabilities(:,:,end+1)=p;obj.Entropies(:,end+1)=h;obj.Categories(:,end+1)=cats;
            action={e3bCategoryPWM(cats)/255};state=[];
        end
        function values=getLearnableParameters(obj),values=obj.Network.Learnables.Value;end
    end
end
