function report = validateMyoTrial(trial)
required=["schema_version","participant_id","session_id","placement_id","trial_id","condition_id","arm", ...
 "condition","direction","phase","target_start","target_end","target_aperture","reference_source", ...
 "measured_aperture","measured_aperture_available","rest_intent","time_emg","emg_raw", ...
 "source_time_emg","arrival_time_emg","time_imu","source_time_imu","quat","gyro","accel","pose_aux", ...
 "source_info","quality","status","protocol_index","target_events"];
assert(isstruct(trial)&&isscalar(trial)&&all(isfield(trial,required)),"MyoTrial:Fields","Datos o estado incompatibles con MyoTrial:Fields.");
for f=["participant_id","session_id","placement_id"]
 assert(~isempty(regexp(char(trial.(f)),'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$','once')),"MyoTrial:Identifier","Datos o estado incompatibles con MyoTrial:Identifier.");
end
assert(isscalar(trial.trial_id)&&trial.trial_id>=1&&fix(trial.trial_id)==trial.trial_id,"MyoTrial:ID","Datos o estado incompatibles con MyoTrial:ID.");
assert(any(string(trial.arm)==["right","left"]),"MyoTrial:Arm","Datos o estado incompatibles con MyoTrial:Arm.");
n=size(trial.emg_raw,1);ni=numel(trial.time_imu);
assert(isnumeric(trial.emg_raw)&&size(trial.emg_raw,2)==8&&isreal(trial.emg_raw),"MyoTrial:EMGShape","Datos o estado incompatibles con MyoTrial:EMGShape.");
assert(numel(trial.time_emg)==n&&numel(trial.target_aperture)==n&&numel(trial.phase)==n&&numel(trial.source_time_emg)==n&&numel(trial.arrival_time_emg)==n,"MyoTrial:Length","Datos o estado incompatibles con MyoTrial:Length.");
assert(isequal(size(trial.quat),[ni 4])&&isequal(size(trial.gyro),[ni 3])&&isequal(size(trial.accel),[ni 3])&&numel(trial.pose_aux)==ni&&numel(trial.source_time_imu)==ni,"MyoTrial:IMUShape","Datos o estado incompatibles con MyoTrial:IMUShape.");
assert(string(trial.reference_source)=="VISUAL_TARGET","MyoTrial:ReferenceSource","Datos o estado incompatibles con MyoTrial:ReferenceSource.");
% Medición de apertura excluida de este proyecto: conservar campos vacíos.
assert(~trial.measured_aperture_available && isempty(trial.measured_aperture),"MyoTrial:MeasuredUnavailable","Datos o estado incompatibles con MyoTrial:MeasuredUnavailable.");
if trial.rest_intent
 assert(string(trial.condition)=="REST"&&all(isnan(trial.target_aperture))&&isnan(trial.target_start)&&isnan(trial.target_end),"MyoTrial:Rest","Datos o estado incompatibles con MyoTrial:Rest.");
else
 allowed=(trial.target_aperture>=0 & trial.target_aperture<=1)|isnan(trial.time_emg)|trial.phase=="OUTSIDE_STIMULUS_CLOCK";
 if string(trial.schema_version)=="myo-continuous-v2",allowed=allowed|(trial.phase=="RELEASE"&isnan(trial.target_aperture));end
 assert(all(allowed),"MyoTrial:TargetRange","Datos o estado incompatibles con MyoTrial:TargetRange.");
end
if string(trial.schema_version)=="myo-continuous-v2"
 fields=["movement_level","block_id","randomized_order","randomization_seed","arm_posture_id","campaign","protocol"];
 assert(all(isfield(trial,fields))&&ismember(string(trial.arm_posture_id),["P0_NEUTRAL_90","P0_FORWARD_EXTENDED"]),'MyoTrial:Pilot2Fields','Metadata del piloto 2 incompleta.');
 assert(string(trial.arm_posture_id)==string(trial.protocol.arm_posture_id),'MyoTrial:Posture','Postura inconsistente con protocolo.');
 assert(trial.protocol.is_scientific_trial&&~trial.protocol.block_break,'MyoTrial:BlockBreak','Descanso de bloque no permitido como trial.');
 [target,phase]=myoProtocolTarget(trial.protocol,trial.time_emg);
 outside=trial.phase=="OUTSIDE_STIMULUS_CLOCK";
 assert(isequaln(trial.target_aperture(~outside),target(~outside))&&isequal(string(trial.phase(~outside)),phase(~outside)), ...
  'MyoTrial:Pilot2Phases','Labels/targets no corresponden al protocolo.');
 if ~trial.rest_intent
  level=trial.movement_level;assert(ismember(level,[.25 .5 .75 1]),'MyoTrial:MovementLevel','Nivel inválido.');
  if string(trial.direction)=="opening",start=0;finish=level;else,start=1;finish=1-level;end
  assert(trial.target_start==start&&trial.target_end==finish,'MyoTrial:Pilot2Coordinates','Coordenadas incompatibles con dirección/nivel.');
  assert(~any(trial.phase=="REST"),'MyoTrial:ReleaseRest','RELEASE no puede etiquetarse REST.');
 else,assert(isnan(trial.movement_level),'MyoTrial:MovementLevel','REST no tiene nivel de movimiento.');end
end
assert(isstruct(trial.quality)&&trial.quality.sample_count==n,"MyoTrial:Quality","Datos o estado incompatibles con MyoTrial:Quality.");
report=struct("schema_valid",true,"samples",n,"imu_samples",ni,"quality_warning_count",trial.quality.warning_count);
end
