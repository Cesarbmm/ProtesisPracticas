function Y = clipActionToUnitRange(X)
%clipActionToUnitRange clips actor outputs to [-1, 1] elementwise.

Y = min(max(X, -1), 1);
end
