function [applied,pendingNext,event]=e2eReversalGuard(desired,previousApplied,pendingSign,enabled)
% Confirmacion experimental de signo: entradas exclusivas de acciones y memoria.
validateattributes(desired,{'numeric'},{'real','finite','row','nonempty'});
validateattributes(previousApplied,{'numeric'},{'real','finite','size',size(desired)});
validateattributes(pendingSign,{'numeric'},{'real','finite','size',size(desired)});
validateattributes(enabled,{'logical','numeric'},{'scalar','real','finite'});
assert(enabled==0 || enabled==1,"E2E:InvalidEnabled","enabled debe ser booleano.");
assert(all(ismember(pendingSign,[-1 0 1]),"all"),"E2E:InvalidPendingSign", ...
    "El signo pendiente debe ser -1, 0 o 1.");
assert(~any(pendingSign~=0 & previousApplied~=0,"all"),"E2E:InvalidPendingState", ...
    "Un estado pendiente requiere que la aplicacion anterior sea cero.");
request=desired~=0 & previousApplied~=0 & sign(desired)~=sign(previousApplied);
event=struct("request",request,"neutralized",false(size(desired)), ...
    "confirmed",false(size(desired)),"cancelled",false(size(desired)));
applied=desired;pendingNext=zeros(size(desired));
if ~enabled,return;end
pending=pendingSign~=0;
event.confirmed=pending & sign(desired)==pendingSign;
event.cancelled=pending & ~event.confirmed;
event.neutralized=~pending & request;
applied(event.neutralized)=0;
pendingNext(event.neutralized)=sign(desired(event.neutralized));
end
