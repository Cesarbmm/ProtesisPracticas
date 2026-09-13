function T=e3cDiagnosticTable(t,label)
N=size(t.pwm,1);rows={};
for k=1:N
    for m=1:4
        c=t.categories(m,k);p=t.probabilities(c,m,k);
        rows{end+1}=struct("policy",string(label),"step",k,"motor",m,"teacher",t.reference(k,m),"h_q",t.prediction(k,m), ...
            "category",c,"PWM",t.pwm(k,m),"effectiveAction",t.effectiveAction(k,m),"selectedProbability",p,"headEntropy",t.headEntropy(m,k), ...
            "q",t.q(k+1,m),"delta_q",t.q(k+1,m)-t.q(k,m)); %#ok<AGROW>
    end
end
T=struct2table([rows{:}]);
end
