function seed=myoSessionSeed(uuid)
% UUID reservado e inmutable -> uint32 exacto. No usa reloj ni RNG global.
uuid=lower(string(uuid));
assert(isscalar(uuid)&&~isempty(regexp(char(uuid),'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$','once')), ...
 'MyoSession:UUID','UUID de sesión no válido.');
seed=hex2dec(extractBefore(uuid,9));
end
