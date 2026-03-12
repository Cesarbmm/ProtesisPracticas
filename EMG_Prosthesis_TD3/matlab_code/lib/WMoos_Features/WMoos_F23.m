% WMoos Maximum Fractal Length

function MFL=WMoos_F23(X)
N=length(X); Y=0;
for n=1:N-1
  Y=Y+(X(n+1)-X(n))^2;
end
MFL=log(sqrt(Y));
end

