function [period,persistentReversals]=e2eFixedOrbit(q,previousApplied,pendingBefore,pwm,motor)
% Diagnostico preregistrado de orbitas fijas con pasos neutros, separado de E2B.
n=size(pwm,1);
validateattributes(motor,{'numeric'},{'scalar','integer','>=',1,'<=',4});
assert(isequal(size(q),[n+1 4]) && isequal(size(pwm),[n 4]) && ...
    isequal(size(previousApplied),[n 4]) && isequal(size(pendingBefore),[n 4]), ...
    "E2E:OrbitShape","La trayectoria y memorias deben tener dimensiones compatibles.");
assert(all(isfinite(q),"all") && all(isfinite(previousApplied),"all") && ...
    all(isfinite(pendingBefore),"all") && all(isfinite(pwm),"all"), ...
    "E2E:OrbitFinite","El diagnostico requiere valores finitos.");
period=0;persistentReversals=false;
if n==0,return;end
tail=pwm(max(1,n-19):n,motor);active=tail(tail~=0);
% Cuatro cambios de signo requieren al menos cinco comandos activos.
persistentReversals=numel(active)>=5 && all(active(1:end-1).*active(2:end)<0);
if n<32,return;end
first=n-31;
positions=q(first:n,motor);
previous=previousApplied(first:n,motor);pending=pendingBefore(first:n,motor);
h=encoder2Flex(q(first:n,:))./[4092 2046 1023 2046];
motion=diff(q(first:n+1,motor));
if max(h(:,motor))-min(h(:,motor))<=.05 || ...
        ~any(motion>1e-9) || ~any(motion< -1e-9)
    return;
end
for candidate=1:8
    repeated=all(abs(positions(1:end-candidate)-positions(1+candidate:end))<=1e-9) && ...
        isequal(previous(1:end-candidate),previous(1+candidate:end)) && ...
        isequal(pending(1:end-candidate),pending(1+candidate:end));
    if repeated,period=candidate;return;end
end
end
