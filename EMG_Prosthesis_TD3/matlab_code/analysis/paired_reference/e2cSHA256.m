function hash=e2cSHA256(file)
fid=fopen(file,"rb");assert(fid>=0);c=onCleanup(@() fclose(fid)); %#ok<NASGU>
d=java.security.MessageDigest.getInstance("SHA-256");d.update(fread(fid,inf,"*uint8"));
hash=string(lower(reshape(dec2hex(typecast(d.digest(),"uint8"),2)',1,[])));
end
