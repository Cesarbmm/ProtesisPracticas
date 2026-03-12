% WMoos Zero Crossing
function ZC=WMoos_F11(X,~)
thres=0.21;
N=length(X); ZC=0;
for i=1:N-1
  if ((X(i) > 0 && X(i+1) < 0) || (X(i) < 0 && X(i+1) > 0)) ...
      && (abs(X(i)-X(i+1)) >= thres)
    ZC=ZC+1;
  end
end
end