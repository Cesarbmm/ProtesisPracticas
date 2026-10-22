function protocol=buildMyoPilot2Protocol(o)
% Piloto 2 congelado: 48 movimientos, tres bloques, velocidad nominal .25/s.
arguments
 o.Seed (1,1) double {mustBeInteger,mustBeNonnegative} = 20261008
end
assert(o.Seed<=2^32-1,'MyoPilot2:Seed','Seed fuera del rango uint32.');
stream=RandStream('mt19937ar','Seed',o.Seed);rows={};order=0;reps=zeros(1,8);past=[];
add("REST",1,NaN,"rest",NaN,NaN,NaN,0,0,0,0,5);
for block=1:3
 % Rechazo determinista: dos instancias de cada condición por bloque.
 accepted=false;
 for attempt=1:10000
  ids=repmat(1:8,1,2);ids=ids(randperm(stream,16));
  signs=1+(ids>4);allSigns=[past signs];
  if ~any(allSigns(1:end-2)==allSigns(2:end-1)&allSigns(2:end-1)==allSigns(3:end))
   accepted=true;break
  end
 end
 assert(accepted,'MyoPilot2:Randomization','No se encontró un orden legal.');past=signs(end-1:end);
 for id=ids
  level=(mod(id-1,4)+1)/4;reps(id)=reps(id)+1;order=order+1;
  if id<=4,direction="opening";a=0;b=level;else,direction="closing";a=1;b=1-level;end
  add("MOVEMENT",block,order,direction,level,a,b,reps(id),2,level/.25,2,2);
  add("REST",block,NaN,"rest",NaN,NaN,NaN,0,0,0,0,5);
 end
 add("BLOCK_BREAK",block,NaN,"rest",NaN,NaN,NaN,0,0,0,0,60);
end
protocol=struct2table([rows{:}]);validateMyoPilot2Protocol(protocol);
 function add(condition,block,randomizedOrder,direction,level,a,b,rep,prepare,move,hold,last)
  scientific=condition~="BLOCK_BREAK";rest=condition=="REST";
  release=0;if condition=="MOVEMENT",release=last;duration=prepare+move+hold+release;else,duration=last;hold=last;end
  conditionID=condition;if condition=="MOVEMENT",conditionID=upper(direction)+compose("_L%.0f",level*100);end
  rows{end+1}=struct('protocol_index',numel(rows)+1,'condition_id',conditionID,'condition',condition, ...
   'direction',direction,'speed',"CONSTANT_NOMINAL_0.25_PER_SECOND",'repetition',rep, ...
   'target_start',a,'target_end',b,'prepare_s',prepare,'ramp_s',move,'move_s',move,'hold_s',hold, ...
   'release_s',release,'duration_s',duration,'rest_intent',rest,'block_break',~scientific, ...
   'is_scientific_trial',scientific,'movement_level',level,'block_id',block,'randomized_order',randomizedOrder, ...
   'randomization_seed',o.Seed,'campaign',"MYO_PILOT2_OPEN_CLOSE",'arm_posture_id',"P0_NEUTRAL_90");
 end
end
