function selected=e2dSelectEpsilon(grid,passes)
assert(numel(grid)==numel(passes));
candidates=grid(grid>0 & logical(passes));
if isempty(candidates),selected=NaN;else,selected=min(candidates);end
end
