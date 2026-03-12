% WMoos Variance of EMG
function VAR=WMoos_F21(X)
N=length(X); VAR=(1/(N-1))*sum(X.^2);
end
