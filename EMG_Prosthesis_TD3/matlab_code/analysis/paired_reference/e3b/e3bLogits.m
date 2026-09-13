function logits=e3bLogits(net,states)
[a,b,c,d]=forward(net,states,Outputs=["head1","head2","head3","head4"]);
logits=reshape(stripdims(cat(1,a,b,c,d)),15,4,[]);
end
