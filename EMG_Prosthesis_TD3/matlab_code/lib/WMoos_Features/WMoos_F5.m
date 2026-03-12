% WMoos Energy
function Y = WMoos_F5(X)
matrix=X;
mat=size(matrix);
rows=mat(1,1);
columns=mat(1,2);
zeromat=zeros(rows,1);
z=0;
zz=0;
for j=1:rows
    for i=1:columns-1        
         z= abs( matrix(j,i+1)*matrix(j,i+1) - matrix(j,i)*matrix(j,i) ); 
         zz=zz+z;   
         zeromat(j)=zz/2;
    end
 zz=0; 
end
Y=zeromat;
end