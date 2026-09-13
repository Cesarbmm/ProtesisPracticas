function myoWriteJSONAtomic(file,value)
temp=string(file)+"."+string(java.util.UUID.randomUUID())+".tmp";
f=fopen(temp,'w','n','UTF-8');assert(f>=0,"MyoSave:Open","Datos o estado incompatibles con MyoSave:Open.");
try,fprintf(f,'%s',jsonencode(value,PrettyPrint=true));fclose(f);catch ex,fclose(f);rethrow(ex);end
jsondecode(fileread(temp));myoAtomicPromote(temp,file,true);
end
