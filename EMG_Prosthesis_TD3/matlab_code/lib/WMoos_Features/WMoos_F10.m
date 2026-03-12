% WMoos Wavelength
function WL=WMoos_F10(X)
N=length(X); WL=0;
for i=2:N
    WL=WL+abs(X(i)-X(i-1));
end
end