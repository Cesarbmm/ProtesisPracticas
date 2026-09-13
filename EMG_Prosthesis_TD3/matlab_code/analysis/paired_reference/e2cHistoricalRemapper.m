function [remap,cleanup]=e2cHistoricalRemapper(root)
% Ejecuta el cuerpo historico intacto en una fixture sin construir Env/guante.
oldPath=path;folder=string(tempname);mkdir(folder);
source=fileread(fullfile(root,"src","@Env","remapActionForActuator.m"));
renamed=replace(source,"= remapActionForActuator(","= e2cOriginalRemap(");
assert(~strcmp(source,renamed));
fid=fopen(fullfile(folder,"e2cOriginalRemap.m"),"w");assert(fid>=0);
fwrite(fid,renamed,"char");fclose(fid);addpath(folder,"-begin");
p=configurables();
assert(p.period==.2 && p.actionInterfaceVariant=="baselineQuantized" && ...
    isequal(p.actionCommandLevels,[0 64 96 128 160 192 224 255]) && ...
    p.actionCommandActivationThreshold==.05 && all(p.speeds==255));
remap=@(raw) e2cOriginalRemap(p,raw);
cleanup=onCleanup(@() path(oldPath));
end
