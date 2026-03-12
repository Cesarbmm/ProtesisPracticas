% WMoos Difference Absolute Standar Deviation Value

function DASDV=WMoos_F15(X)
N=length(X); Y=0;
for i=1:N-1
  Y=Y+(X(i+1)-X(i))^2;
end
DASDV=sqrt(Y/(N-1));
end

