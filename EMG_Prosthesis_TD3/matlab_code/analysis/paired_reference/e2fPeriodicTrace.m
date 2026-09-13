function period=e2fPeriodicTrace(q,pwm,motor,isFixed)
% Periodicidad cinemática aumentada; no atribuye autonomía con target móvil.
n=size(pwm,1);previous=[zeros(1,4);pwm(1:end-1,:)];period=0;
for p=2:8
    count=4*p;if isFixed,count=32;end
    if n<count,continue;end
    idx=n-count+1:n;Q=q(idx,motor);P=previous(idx,motor);
    h=encoder2Flex(q(idx,:))./[4092 2046 1023 2046];dq=diff(q(idx(1):n+1,motor));
    if max(h(:,motor))-min(h(:,motor))<=.05 || ~any(dq>1e-9) || ~any(dq< -1e-9),continue;end
    if all(abs(Q(1:end-p)-Q(p+1:end))<=1e-9) && isequal(P(1:end-p),P(p+1:end))
        period=p;return;
    end
end
end
