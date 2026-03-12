%WMoos Log Detector
function LD=WMoos_F16(X)
N=length(X); Y=0;
for k=1:N
  Y=Y+log(abs(X(k))); 
end
LD=exp(Y/N);
end

