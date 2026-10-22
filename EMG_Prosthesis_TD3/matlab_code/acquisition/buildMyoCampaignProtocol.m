function p=buildMyoCampaignProtocol(seed)
if nargin<1,seed=20261008;end
p=buildMyoPilot2Protocol(Seed=seed);
% Sólo la postura operacional/identidad cambia; orden, targets y tiempos intactos.
p.arm_posture_id(:)="P0_FORWARD_EXTENDED";
p.campaign_id=repmat("PILOT2_OPEN_CLOSE_V1",height(p),1);
p.protocol_version=repmat("OPEN_CLOSE_S04_V1",height(p),1);
validateMyoPilot2Protocol(p);
end
