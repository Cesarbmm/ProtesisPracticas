function protocol = buildMyoContinuousProtocol(o)
% Estimulos visuales configurables. No equivalen a una apertura medida.
arguments
 o.repetitions (1,1) double {mustBeInteger,mustBePositive} = 5
 o.holdLevels (1,:) double = [.25 .50 .75 1]
 o.rampLevels (1,:) double = [0 .25 .50 .75 1]
 o.speeds (1,:) string = ["slow","normal"]
 o.prepareSeconds (1,1) double {mustBeNonnegative} = 2
 o.holdSeconds (1,1) double {mustBePositive} = 4
 o.restSeconds (1,1) double {mustBePositive} = 6
 o.slowSeconds (1,1) double {mustBePositive} = 4
 o.normalSeconds (1,1) double {mustBePositive} = 2
 o.fastSeconds (1,1) double {mustBePositive} = 1
 o.includeRamps (1,1) logical = true
end
assert(all(o.holdLevels>0 & o.holdLevels<=1) && all(o.rampLevels>=0 & o.rampLevels<=1) && all(diff(o.rampLevels)>0),"MyoProtocol:Levels","Datos o estado incompatibles con MyoProtocol:Levels.");
assert(all(ismember(o.speeds,["slow","normal","fast"])),"MyoProtocol:Speed","Datos o estado incompatibles con MyoProtocol:Speed.");
rows={}; push("REST","rest","rest",0,NaN,NaN,0,0,o.restSeconds);
for rep=1:o.repetitions
 for level=o.holdLevels
  push("HOLD","opening","normal",rep,0,level,o.prepareSeconds,o.normalSeconds,o.holdSeconds);
  push("REST","rest","rest",rep,NaN,NaN,0,0,o.restSeconds);
 end
 if o.includeRamps
  for speed=o.speeds
   ramp=o.(char(speed+"Seconds"));
   for direction=["opening","closing"]
    levels=o.rampLevels;if direction=="closing",levels=fliplr(levels);end
    for k=1:numel(levels)-1
     push("RAMP",direction,speed,rep,levels(k),levels(k+1),o.prepareSeconds,ramp,o.holdSeconds);
     push("REST","rest","rest",rep,NaN,NaN,0,0,o.restSeconds);
    end
   end
  end
 end
end
protocol=struct2table([rows{:}]);
 function push(condition,direction,speed,rep,a,b,prepare,ramp,hold)
  index=numel(rows)+1;
  rows{index}=struct("protocol_index",index,"condition_id",condition+"_"+direction+"_"+speed+"_"+compose("%g_%g",a,b), ...
   "condition",condition,"direction",direction,"speed",speed,"repetition",rep,"target_start",a,"target_end",b, ...
   "prepare_s",prepare,"ramp_s",ramp,"hold_s",hold,"duration_s",prepare+ramp+hold,"rest_intent",condition=="REST");
 end
end
