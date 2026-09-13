function a = appendMyoPacket(a,b)
for f=string(fieldnames(a))',a.(f)=[a.(f);b.(f)];end
end
