function r=cap192Runtime(actor,emg,initialQ,enabled)
% saved_actor -> cap opcional -> runtime E2A intacto, solo EMG.
rt=GloveFreePolicyRuntime(emg,initialQ,purpose="inference");
r=struct("q",rt.q,"state",rt.state',"desiredRaw",zeros(0,4),"rawAction",zeros(0,4), ...
    "effectiveAction",zeros(0,4),"pwm",zeros(0,4),"plantManifest",rt.plantManifest);
while ~rt.exhausted
    a=getAction(actor,{rt.state});if iscell(a),a=cell2mat(a);end
    desired=double(a(:));command=cap192Command(desired,enabled);
    [s,~,record]=rt.advance(command);
    assert(isequal(s(49:52),record.effectiveAction),"CAP192:PreviousAction","El estado debe contener la accion aplicada.");
    r.q(end+1,:)=record.q;r.state(end+1,:)=s';
    r.desiredRaw(end+1,:)=desired';r.rawAction(end+1,:)=record.rawAction';
    r.effectiveAction(end+1,:)=record.effectiveAction';r.pwm(end+1,:)=record.pwm';
    assert(rt.c<=100,"CAP192:Horizon","Horizonte fuera del contrato development.");
end
r.commandRaw=r.rawAction;r.capEnabled=enabled;r.termination="EMG_ONLY";
end
