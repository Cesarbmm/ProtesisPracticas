function masks=e2dCycleScan(q,pwm)
% Detector E2B literal aplicado a cada prefijo. El gate usa solo la ultima fila.
n=size(pwm,1);assert(isequal(size(q),[n+1 4]));masks=false(n,4);
h=encoder2Flex(q)./[4092 2046 1023 2046];
for k=4:n
    for motor=1:4
        last=q(k-3:k+1,motor);lastH=h(k-3:k+1,motor);commands=pwm(k-3:k,motor);
        masks(k,motor)=all(abs(last([1 3])-last(5))<=1e-9) && ...
            abs(last(2)-last(4))<=1e-9 && abs(lastH(1)-lastH(2))>0.05 && ...
            all(commands(1:3).*commands(2:4)<0);
    end
end
end
