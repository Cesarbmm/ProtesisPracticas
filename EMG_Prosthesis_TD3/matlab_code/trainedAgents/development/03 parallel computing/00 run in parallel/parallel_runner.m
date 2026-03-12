%%
for i = [10 20 100]
    system(sprintf('matlab -r "p1 %s" &', num2str(i)));
end