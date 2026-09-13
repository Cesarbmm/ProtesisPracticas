function [target,phase] = myoProtocolTarget(row,time)
% Tiempo relativo al trial; prefijos/rampas causales sin sensor de apertura.
time=double(time(:));target=repmat(row.target_start,size(time));phase=repmat("PREPARE",size(time));
if row.rest_intent,target(:)=NaN;phase(:)="REST";return;end
r=time>=row.prepare_s & time<row.prepare_s+row.ramp_s;
if row.ramp_s>0,target(r)=row.target_start+(row.target_end-row.target_start)*(time(r)-row.prepare_s)/row.ramp_s;end
phase(r)="RAMP";h=time>=row.prepare_s+row.ramp_s;target(h)=row.target_end;phase(h)="HOLD";
end
