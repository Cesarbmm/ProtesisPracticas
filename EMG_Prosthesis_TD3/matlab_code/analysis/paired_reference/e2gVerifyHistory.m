function T=e2gVerifyHistory
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));out=fullfile(here,"e2g_results");
T=readtable(fullfile(out,"historical_hashes_before.csv"),TextType="string");
T.currentSHA256=strings(height(T),1);
for k=1:height(T),assert(~contains(lower(T.path(k)),"sandbox"));T.currentSHA256(k)=digest(fullfile(root,T.path(k)));end
T.unchanged=T.sha256==T.currentSHA256;assert(all(T.unchanged),"E2G:HistoricalChange");
assert(digest(fullfile(fileparts(root),"docs","paired_reference","PREREGISTRO_E2G.md"))==strtrim(string(fileread(fullfile(out,"preregistration.sha256")))),"E2G:PreregistrationChanged");
end
function h=digest(p)
f=fopen(p,"rb");assert(f>=0);c=onCleanup(@() fclose(f)); %#ok<NASGU>
b=fread(f,Inf,"*uint8");md=java.security.MessageDigest.getInstance("SHA-256");md.update(b);
h=string(lower(reshape(dec2hex(typecast(md.digest(),"uint8"),2)',1,[])));
end
