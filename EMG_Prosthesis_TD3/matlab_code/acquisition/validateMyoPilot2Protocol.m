function validateMyoPilot2Protocol(p)
% Contrato exclusivo de esta campaña; rechazar deriva antes de crear sesión.
required=["campaign","block_id","randomized_order","randomization_seed","movement_level","move_s", ...
 "release_s","block_break","is_scientific_trial","arm_posture_id","condition","direction", ...
 "target_start","target_end","prepare_s","ramp_s","hold_s","duration_s","rest_intent","repetition"];
assert(istable(p)&&all(ismember(required,string(p.Properties.VariableNames))),'MyoPilot2:Fields','Protocolo incompleto.');
assert(height(p)==100&&all(p.campaign=="MYO_PILOT2_OPEN_CLOSE"),'MyoPilot2:Count','Se esperan 100 filas de protocolo.');
assert(numel(unique(p.arm_posture_id))==1&&all(ismember(p.arm_posture_id,["P0_NEUTRAL_90","P0_FORWARD_EXTENDED","P0_SEATED_ARMREST"]))&&numel(unique(p.randomization_seed))==1,'MyoPilot2:Metadata','Postura/seed no válidas.');
a=p.condition=="MOVEMENT";r=p.condition=="REST";b=p.condition=="BLOCK_BREAK";
assert(sum(a)==48&&sum(r)==49&&sum(b)==3&&all(a|r|b),'MyoPilot2:Count','Se esperan 48 movimientos, 49 REST y 3 descansos.');
assert(isequal(p.is_scientific_trial,~b)&&isequal(p.block_break,b)&&isequal(p.rest_intent,r),'MyoPilot2:EventType','Tipo de evento inconsistente.');
assert(all(p.prepare_s(a)==2&p.move_s(a)==4*p.movement_level(a)&p.ramp_s(a)==p.move_s(a)&p.hold_s(a)==2&p.release_s(a)==2), ...
 'MyoPilot2:Timing','Tiempos del piloto modificados.');
assert(all(p.duration_s(a)==p.prepare_s(a)+p.move_s(a)+p.hold_s(a)+p.release_s(a))&&all(p.duration_s(r)==5)&&all(p.duration_s(b)==60), ...
 'MyoPilot2:Timing','Duraciones no válidas.');
assert(all(isnan(p.target_start(~a))&isnan(p.target_end(~a))&isnan(p.movement_level(~a))),'MyoPilot2:RestTarget','REST/descanso no prescribe apertura.');
o=a&p.direction=="opening";c=a&p.direction=="closing";
assert(sum(o)==24&&sum(c)==24&&all(p.target_start(o)==0&p.target_end(o)==p.movement_level(o))&& ...
 all(p.target_start(c)==1&p.target_end(c)==1-p.movement_level(c)),'MyoPilot2:Coordinates','Contrato apertura/cierre incorrecto.');
for block=1:3
 q=p(a&p.block_id==block,:);assert(height(q)==16,'MyoPilot2:Block','Bloque incompleto.');
 for direction=["opening","closing"]
  for level=[.25 .5 .75 1]
   selected=q.direction==direction&q.movement_level==level;
   assert(sum(selected)==2&&isequal(sort(q.repetition(selected)),[2*block-1;2*block]),'MyoPilot2:Balance','Condición perdida o duplicada.');
  end
 end
end
assert(isequal(p.randomized_order(a),(1:48)'),'MyoPilot2:Order','Orden no único/consecutivo.');
d=p.direction(a);assert(~any(d(1:end-2)==d(2:end-1)&d(2:end-1)==d(3:end)),'MyoPilot2:DirectionRun','Más de dos direcciones consecutivas.');
idx=find(a);assert(all(p.condition(idx+1)=="REST"),'MyoPilot2:RestOrder','Cada movimiento requiere REST posterior.');
end
