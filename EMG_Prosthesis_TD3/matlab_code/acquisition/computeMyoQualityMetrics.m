function q = computeMyoQualityMetrics(time,raw,wallDuration)
% Umbrales v1 congelados: avisos, nunca filtrado/correccion del RAW.
if nargin<3,wallDuration=NaN;end
time=double(time(:));n=size(raw,1);q=struct("sample_count",n,"channels",size(raw,2), ...
 "actual_emg_fs",NaN,"wall_sample_rate",NaN,"timestamps_monotonic",all(isfinite(time))&&all(diff(time)>0), ...
 "finite_raw",all(isfinite(raw),"all"),"estimated_dropped_samples_timestamp",NaN,"dropout_certified",false);
if n>=2 && numel(time)==n && time(end)>time(1)
 q.actual_emg_fs=(n-1)/(time(end)-time(1));
 q.estimated_dropped_samples_timestamp=sum(max(0,round(diff(time)*200)-1));
end
if wallDuration>0,q.wall_sample_rate=n/wallDuration;end
q.flat_channels=find(n>=2 & (max(raw,[],1)-min(raw,[],1))<=1e-12);
q.clipping_fraction=mean(raw<=-1 | raw>=127/128,1);
q.rms=sqrt(mean(raw.^2,1));q.mav=mean(abs(raw),1);
q.identical_consecutive_row_fraction=mean(all(diff(raw,1,1)==0,2));
q.warnings=strings(0,1);
if n<2,q.warnings(end+1)="INSUFFICIENT_SAMPLES";end
if q.channels~=8,q.warnings(end+1)="CHANNEL_COUNT";end
if ~q.finite_raw,q.warnings(end+1)="NONFINITE_RAW";end
if ~q.timestamps_monotonic,q.warnings(end+1)="TIMESTAMP_ORDER";end
if ~(q.actual_emg_fs>=180 && q.actual_emg_fs<=220),q.warnings(end+1)="NOMINAL_FS_OUTSIDE_180_220";end
if isfinite(q.wall_sample_rate) && (q.wall_sample_rate<180 || q.wall_sample_rate>220),q.warnings(end+1)="WALL_RATE_OUTSIDE_180_220";end
if ~isempty(q.flat_channels),q.warnings(end+1)="FLAT_CHANNEL";end
if any(q.clipping_fraction>.01),q.warnings(end+1)="CLIPPING_OVER_1_PERCENT";end
if q.identical_consecutive_row_fraction>.05,q.warnings(end+1)="REPEATED_ROWS_OVER_5_PERCENT_NOT_PROOF_OF_DROPOUT";end
q.warning_count=numel(q.warnings);
end
