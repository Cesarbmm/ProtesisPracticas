% WMoos V-Order
function V = WMoos_F6(X,~)
ex=3;
mat=size(X);
X=X';
times=mat(1,1);
V=0;
    for i=1:times
        R=X(i,:).^ex;
        V=R+V;
    end
V=real((V/times).^(1/ex));
end

