% Wmoos Absolute Envelope
function Y = WMoos_F2(X)

        envol=hilbert(X);
        out_partial=abs(envol);
        %% Filter  Savitzky-Golay 
        aux = sgolayfilt(out_partial,1,7);
        Y=trapz(aux,2);        
        
end

