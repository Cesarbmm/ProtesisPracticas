function myoWriteTableAtomic(file,value)
% CSV con validación completa antes de la promoción existente de V1.
temp=string(file)+"."+string(java.util.UUID.randomUUID())+".tmp.csv";
writetable(value,temp);
loaded=readtable(temp,TextType='string',VariableNamingRule='preserve',ReadVariableNames=true,Delimiter=',',Format=repmat('%q',1,width(value)));
assert(isequal(string(loaded.Properties.VariableNames),string(value.Properties.VariableNames))&&height(loaded)==height(value), ...
 'MyoRegistry:RoundTrip','CSV incompleto; temporal conservado.');
for f=string(value.Properties.VariableNames)
 a=value.(f);b=loaded.(f);
 if isstring(a)
  missing=ismissing(b);b=string(b);b(missing)="";a(ismissing(a))="";
  assert(isequal(a,b),'MyoRegistry:RoundTrip','Texto CSV alterado: %s.',f);
 else
  assert(isequaln(double(a),str2double(b)),'MyoRegistry:RoundTrip','Valor CSV alterado: %s.',f);
 end
end
myoAtomicPromote(temp,file,true);
end
