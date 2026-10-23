function p=buildMyoOfficialProtocol(seed)
% Misma familia OPEN/CLOSE, con otra identidad/postura y orden según seed.
if nargin<1,seed=20261008;end % Sólo preview/práctica, no seed de captura oficial.
p=buildMyoCampaignProtocol(seed);
p.arm_posture_id(:)="P0_SEATED_ARMREST";
p.campaign_id(:)="MYO_OPEN_CLOSE_OFFICIAL_V1";
p.protocol_version(:)="OPEN_CLOSE_OFFICIAL_V1";
validateMyoPilot2Protocol(p);
end
