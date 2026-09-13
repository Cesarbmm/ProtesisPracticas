function h=cap192SHA256(file)
f=fopen(file,"rb");assert(f>=0);cleanup=onCleanup(@() fclose(f)); %#ok<NASGU>
md=java.security.MessageDigest.getInstance("SHA-256");
while ~feof(f),b=fread(f,1048576,"*uint8");if ~isempty(b),md.update(b);end,end
h=string(lower(reshape(dec2hex(typecast(md.digest(),"uint8"),2)',1,[])));
end
