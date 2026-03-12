% WMoos Willison Amplitude
function WA=WMoos_F22(X,~)
thres=0.21;
N=length(X); WA=0; 
for k=1:N-1 
  if abs(X(k)-X(k+1)) >= thres
    WA=WA+1; 
  end
end
end
