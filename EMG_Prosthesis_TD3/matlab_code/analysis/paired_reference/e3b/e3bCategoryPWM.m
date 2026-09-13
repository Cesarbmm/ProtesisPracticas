function pwm=e3bCategoryPWM(category)
levels=[0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];
assert(size(category,1)==4 && all(isfinite(category),"all") && all(category==fix(category) & category>=1 & category<=15,"all"), ...
    "E3B:Category","Se requieren cuatro indices de categoria validos.");
pwm=reshape(levels(category),size(category));
end
