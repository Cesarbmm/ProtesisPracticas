% WMoos Slope Sing Change
function SSC=WMoos_F12(X,~)
thres=0.21;
N=length(X); SSC=0;
for i=2:N-1
  if ((X(i) > X(i-1) && X(i) > X(i+1)) || (X(i) < X(i-1) && X(i) < X(i+1))) ...
      && ((abs(X(i)-X(i+1)) >= thres) || (abs(X(i)-X(i-1)) >= thres))
    SSC=SSC+1; 
  end
end
end
