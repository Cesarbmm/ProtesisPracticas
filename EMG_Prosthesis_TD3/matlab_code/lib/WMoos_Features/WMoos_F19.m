% WMoos MyoPulse Percentage Rate
function MYOP=WMoos_F19(X,~)
thres=0.21;
N=length(X); Y=0; 
for i=1:N
  if abs(X(i)) >= thres
    Y=Y+1;
  end
end
MYOP=Y/N;
end
