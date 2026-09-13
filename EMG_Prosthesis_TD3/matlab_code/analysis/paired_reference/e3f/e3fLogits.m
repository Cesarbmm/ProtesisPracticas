function [logits,latent]=e3fLogits(actor,states)
if ~isa(states,"dlarray"),states=dlarray(single(states),"CB");end
emg=states(1:40,:);
mech=states(41:52,:);
[latent,a,b,c,d]=forward(actor,emg,mech,Outputs=["emg_latent","head1","head2","head3","head4"]);
logits=reshape(stripdims(cat(1,a,b,c,d)),15,4,[]);
end
