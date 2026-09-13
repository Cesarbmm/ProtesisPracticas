function sha = myoFileSHA256(file)
f=fopen(file,'rb');assert(f>=0,"MyoSave:HashOpen","Datos o estado incompatibles con MyoSave:HashOpen.");c=onCleanup(@() fclose(f)); %#ok<NASGU>
md=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(f),md.update(fread(f,1048576,'*uint8'));end
sha=string(lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[])));
end
