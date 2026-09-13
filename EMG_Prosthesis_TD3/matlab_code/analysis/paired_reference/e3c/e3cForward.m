function [z,latent]=e3cForward(net,X)
net=resetState(net); % Cada ventana causal empieza en hidden0; nunca pasado>L.
[a,b,c,d,latent]=forward(net,X,Outputs=["head1","head2","head3","head4","latent"]);
z=reshape(cat(1,stripdims(a),stripdims(b),stripdims(c),stripdims(d)),15,4,[]);
end
