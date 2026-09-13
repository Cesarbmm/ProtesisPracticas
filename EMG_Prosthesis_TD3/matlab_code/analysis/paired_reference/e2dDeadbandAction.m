function [raw,rawHistorical,inside]=e2dDeadbandAction(errorBefore,epsilon)
% Unica intervencion E2D. Usa error h(q)/teacher, nunca encoder normalizado.
arguments
    errorBefore double {mustBeReal,mustBeFinite}
    epsilon (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
end
rawHistorical=max(-1,min(1,2*errorBefore));
inside=abs(errorBefore)<=epsilon;
raw=rawHistorical;raw(inside)=0;
end
