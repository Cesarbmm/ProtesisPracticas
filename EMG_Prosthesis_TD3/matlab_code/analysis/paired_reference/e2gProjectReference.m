function [projected,lo,hi]=e2gProjectReference(reference,graphs)
% Proyección diagnóstica en envolvente del grafo E2F. No calibra ángulos.
assert(isnumeric(reference) && size(reference,2)==4 && all(isfinite(reference),"all"));
lo=cellfun(@(g) min(g.h),graphs);hi=cellfun(@(g) max(g.h),graphs);
assert(numel(lo)==4 && all(hi>lo));
projected=min(max(reference,lo),hi);
end
