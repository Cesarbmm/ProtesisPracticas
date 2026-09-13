function inside=e2cM3RegionMembership(q,regions)
% Pertenencia a union con extremos abiertos/cerrados explicitados.
q=q(:);inside=false(size(q));
for k=1:height(regions)
    left=q>regions.lower(k) | (regions.lowerIncluded(k) & q==regions.lower(k));
    right=q<regions.upper(k) | (regions.upperIncluded(k) & q==regions.upper(k));
    inside=inside | (left & right);
end
end
