function cause=e2cCycleClassify(reproduced,fixedOrbit,overshoot,boundaryCrossesTeacher)
% Regla descriptiva preregistrada; no identifica porcentajes causales exclusivos.
if ~reproduced,cause="UNRESOLVED";
elseif fixedOrbit && overshoot && boundaryCrossesTeacher,cause="QUANTIZATION_OVERSHOOT";
elseif fixedOrbit && overshoot,cause="PLANT_STEP_SIZE";
elseif ~fixedOrbit,cause="MOVING_REFERENCE";
else,cause="MIXED";end
end
