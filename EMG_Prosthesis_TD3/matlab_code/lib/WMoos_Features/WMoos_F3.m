%WMoos Welch
function [Y] = WMoos_F3(X)
xn=X';
tam=size(xn);
ventana=blackmanharris(tam(1,1));
noverlap=round(length(ventana)/4);
[psd1,~]=pwelch(xn,ventana,noverlap,1024,400);
Y1=psd1';
Y=400*(trapz(Y1,2));
end

