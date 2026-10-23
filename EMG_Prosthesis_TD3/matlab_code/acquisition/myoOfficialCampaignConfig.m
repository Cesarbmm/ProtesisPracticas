function c=myoOfficialCampaignConfig
% Nueva campaña; los descriptores piloto y los RAW anteriores no se migran.
c=myoCampaignConfig();
c.campaign_id="MYO_OPEN_CLOSE_OFFICIAL_V1";
c.protocol_version="OPEN_CLOSE_OFFICIAL_V1";
c.arm_posture_id="P0_SEATED_ARMREST";
c.posture_description="Participante sentado; espalda apoyada y postura cómoda; brazo relajado; codo apoyado sobre el reposabrazos; antebrazo descansando naturalmente; muñeca neutra; mano libre; no levantar el brazo ni cambiar deliberadamente la posición durante los trials.";
% Archivo que el operador sustituyó: conservar nombre y ubicación, sin conversión.
c.posture_reference_asset="references/Referencia.jpg";
c.protocol_builder=@buildMyoOfficialProtocol;
c.session_randomization=true;c.official_placement_checklist=true;
c.placement_description="P1: aproximadamente dos dedos distal al codo, sobre piel; puerto/tapa hacia el exterior; ajuste con clips sin compresión excesiva; ocho sensores en contacto firme; no rotar ni reajustar durante la sesión.";
end
