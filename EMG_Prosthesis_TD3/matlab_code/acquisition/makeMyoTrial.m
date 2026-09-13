function trial = makeMyoTrial(metadata,row,packet,trialID,startTime,status,events,duration)
% Conservar el RAW recibido. La conversion temporal conserva tambien el original.
trial=metadata;trial.schema_version="myo-continuous-v1";trial.trial_id=trialID;
for f=["condition_id","condition","direction","target_start","target_end","rest_intent","protocol_index","speed","repetition"]
 trial.(f)=row.(f);
end
trial.protocol=row;trial.status=string(status);trial.reference_source="VISUAL_TARGET";
trial.measured_aperture=[];trial.measured_aperture_available=false;
trial.source_time_emg=packet.time_emg;trial.time_emg=packet.time_emg-startTime;
trial.emg_raw=packet.emg_raw;trial.arrival_time_emg=packet.arrival_emg;
trial.source_time_imu=packet.time_imu;trial.time_imu=packet.time_imu-startTime;
trial.quat=packet.quat;trial.gyro=packet.gyro;trial.accel=packet.accel;trial.pose_aux=packet.pose;
trial.arrival_time_imu=packet.arrival_imu;trial.trial_start_source_time=startTime;
[trial.target_aperture,trial.phase]=myoProtocolTarget(row,trial.time_emg);
outside=~isfinite(trial.time_emg) | trial.time_emg < -1e-9 | trial.time_emg > duration+1e-9;
trial.target_aperture(outside)=NaN;trial.phase(outside)="OUTSIDE_STIMULUS_CLOCK";
trial.outside_stimulus_clock_samples=nnz(outside);
trial.target_events=events; % Instantes de presentacion solicitada a la GUI, reloj fuente.
trial.duration=duration;trial.sample_count=size(trial.emg_raw,1);
trial.quality=computeMyoQualityMetrics(trial.time_emg,trial.emg_raw,duration);
trial.actual_emg_fs=trial.quality.actual_emg_fs;trial.actual_imu_fs=NaN;
if numel(trial.time_imu)>=2 && trial.time_imu(end)>trial.time_imu(1)
 trial.actual_imu_fs=(numel(trial.time_imu)-1)/(trial.time_imu(end)-trial.time_imu(1));
end
end
