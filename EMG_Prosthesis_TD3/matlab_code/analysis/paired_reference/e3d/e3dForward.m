function [z,d,p,h]=e3dForward(net,X,M)
net=resetState(net);inputs={X,M};
if string(net.InputNames(1))=="mechanical_current",inputs={M,X};end
[a,b,c,e,d,p,h]=forward(net,inputs{:},Outputs=["head1","head2","head3","head4","direction","phase_direction","latent"]);
z=cat(2,reshape(stripdims(a),15,1,[]),reshape(stripdims(b),15,1,[]),reshape(stripdims(c),15,1,[]),reshape(stripdims(e),15,1,[]));
d=stripdims(d);p=stripdims(p);h=stripdims(h);
end
