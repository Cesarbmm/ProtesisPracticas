function c=cap192Counts(q,pwm,desired,command)
% Conteos por motor; limites exactos en PWM, no saturationFraction historica.
n=size(pwm,1);assert(isequal(size(q),[n+1 4]));
c=struct("commands",n*ones(1,4),"boundHits",sum(abs(pwm)==192,1), ...
    "clipped",sum(desired~=command,1),"positiveReversals",sum(pwm>0 & diff(q)<0,1), ...
    "zeroMotionFailures",sum(pwm==0 & abs(diff(q))>1e-9,1));
masks=e2dCycleScan(q,pwm);c.finalCycles=masks(end,:);c.cycleWindows=sum(masks,1);
c.period=zeros(1,4);
for m=1:4,c.period(m)=e2fPeriodicTrace(q,pwm,m,false);end
end
