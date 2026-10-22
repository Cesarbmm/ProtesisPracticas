function v=myoParticipantInstruction(row,elapsed)
% El mismo contrato matematico del protocolo, expresado para el participante.
if isfield(row,'campaign')&&string(row.campaign)=="MYO_PILOT2_OPEN_CLOSE",v=pilot2(row,elapsed);return;end
[target,phase]=myoProtocolTarget(row,elapsed);
v=struct('target',target,'phase',phase,'instruction',"",'detail',"",'remaining',0,'asset',"");
if row.rest_intent
 v.instruction="RELAJA LA MANO";v.detail="REST no equivale a 0 %";
 v.remaining=max(0,row.duration_s-elapsed);v.asset="Reposo.png";
elseif phase=="PREPARE"
 if row.target_start==0,v.instruction="CIERRA LA MANO";
 elseif row.target_start==1,v.instruction="ABRE LA MANO";
 else,v.instruction=sprintf('COLOCA LA MANO AL %.0f %%',100*row.target_start);end
 v.detail=sprintf('Posición inicial %.0f %%',100*row.target_start);
 v.remaining=max(0,row.prepare_s-elapsed);
 if row.target_start>0,v.asset=compose('Apertura_%.0f.png',100*row.target_start);end
elseif phase=="RAMP"
 if string(row.direction)=="closing",verb="CIERRA";else,verb="ABRE";end
 v.instruction=verb+compose(' PROGRESIVAMENTE HASTA %.0f %%',100*row.target_end);
 v.detail=sprintf('Transición: %.0f %% → %.0f %%',100*row.target_start,100*row.target_end);
 v.remaining=max(0,row.prepare_s+row.ramp_s-elapsed);v.asset="Ramp_transicion.png";
else
 v.instruction=compose('MANTÉN %.0f %%',100*row.target_end);
 v.detail="Mantén la posición indicada hasta el descanso";
 v.remaining=max(0,row.duration_s-elapsed);v.asset=compose('Apertura_%.0f.png',100*row.target_end);
end
v.instruction=string(v.instruction);v.detail=string(v.detail);v.asset=string(v.asset);
end
function v=pilot2(row,elapsed)
[target,phase]=myoProtocolTarget(row,elapsed);
v=struct('target',target,'phase',phase,'instruction',"",'detail',"",'remaining',0,'asset',"",'participant_level',NaN,'participant_direction',"");
if row.block_break
 v.instruction="DESCANSO DE BLOQUE — 60 s";v.detail="Relájate; no es un trial científico";v.remaining=max(0,60-elapsed);return
elseif row.rest_intent
 v.instruction="REPOSO";v.detail="No busques una posición concreta";v.remaining=max(0,row.duration_s-elapsed);return
elseif phase=="RELEASE"
 v.instruction="RELÁJATE";v.detail="VUELVE A TU POSICIÓN NATURAL";v.remaining=max(0,row.duration_s-elapsed);
 v.participant_level=100*row.movement_level;
 if row.direction=="opening",v.participant_direction="APERTURA";else,v.participant_direction="CIERRE";end
 return
end
level=100*row.movement_level;v.participant_level=level;
if row.direction=="opening",v.participant_direction="APERTURA";else,v.participant_direction="CIERRE";end
if phase=="PREPARE"
 v.remaining=max(0,row.prepare_s-elapsed);
 if row.direction=="opening"
  v.instruction="CIERRA LA MANO";v.detail="Prepárate para abrir · cierre cómodo";v.asset="PosicionInicial_ManoCerrada.png";
 else
  v.instruction="ABRE COMPLETAMENTE LA MANO";v.detail="Prepárate para cerrar · apertura cómoda";v.asset="PosicionInicial_ManoAbierta.png";
 end
elseif phase=="MOVE"
 v.remaining=max(0,row.prepare_s+row.move_s-elapsed);
 if row.direction=="opening"
  v.instruction=compose("ABRE PROGRESIVAMENTE HASTA %.0f %%",level);v.asset="Ramp_transicion_apertura.png";
 else
  v.instruction=compose("CIERRA PROGRESIVAMENTE %.0f %%",level);v.asset="Ramp_transicion_cierre.png";
 end
 v.detail="Recorrido voluntario cómodo; no fuerza";
else
 v.remaining=max(0,row.prepare_s+row.move_s+row.hold_s-elapsed);
 if row.direction=="opening",v.instruction=compose("MANTÉN APERTURA %.0f %%",level);v.asset=compose("apertura_%.0f.png",level);
 else,v.instruction=compose("MANTÉN EL CIERRE %.0f %%",level);v.asset=compose("cierre_%.0f.png",level);end
 v.detail="Mantén el nivel instruido";
end
if row.direction=="closing"&&phase~="PREPARE"
 v.detail="NO APRIETES CON FUERZA";
 if row.movement_level==1,v.detail="CIERRE COMPLETO CÓMODO — NO APRIETES CON FUERZA";end
end
end
