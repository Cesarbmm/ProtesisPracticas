function T=e3axVerifyHistory
% Verifica el cierre congelado E0P-E2G; nunca recaptura ni escribe históricos.
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(fileparts(here)));
T=readtable(fullfile(fileparts(here),"e3ax_preparation","historical_hashes_before.csv"),TextType="string");
T.currentSHA256=strings(height(T),1);
for k=1:height(T)
    assert(~contains(lower(T.path(k)),"sandbox"),"E3AX:ForbiddenHistory");
    T.currentSHA256(k)=digest(fullfile(root,T.path(k)));
end
T.unchanged=T.sha256==T.currentSHA256;
assert(all(T.unchanged),"E3AX:HistoricalChange","Cambió un archivo del cierre histórico.");
end
function h=digest(file)
f=fopen(file,"rb");assert(f>=0,"E3AX:MissingHistoricalFile","%s",file);c=onCleanup(@() fclose(f)); %#ok<NASGU>
md=java.security.MessageDigest.getInstance("SHA-256");
while ~feof(f)
    b=fread(f,1048576,"*uint8");
    if ~isempty(b),md.update(b);end
end
h=string(lower(reshape(dec2hex(typecast(md.digest(),"uint8"),2)',1,[])));
end
