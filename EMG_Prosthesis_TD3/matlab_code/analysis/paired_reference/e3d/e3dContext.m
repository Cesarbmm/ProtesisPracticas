function [emg,mechanical,indices]=e3dContext(states,k,shuffled,episode)
arguments,states;k;shuffled logical=false;episode double=1;end
% Delegar SOLO la seleccion causal a E3C, luego exponer entradas 40/12 separadas.
assert(size(states,1)==52 && k>=1 && k<=size(states,2));
[context,indices]=e3cContext(states,k,8,shuffled,episode);
emg=context(1:40,:);mechanical=states(41:52,k);
end
