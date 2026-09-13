function commandRaw=cap192Command(desiredRaw,enabled)
% Unica intervencion: recorte antes del remapeo historico; sin teacher.
arguments
    desiredRaw double {mustBeFinite}
    enabled (1,1) logical
end
commandRaw=double(desiredRaw);
if enabled,commandRaw=max(-192/255,min(192/255,commandRaw));end
end
