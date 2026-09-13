function e2cWriteJSON(file,value)
fid=fopen(file,"w","n","UTF-8");assert(fid>=0);c=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
