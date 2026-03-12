function [] = p1(max_v)
disp(max_v)
disp(class(max_v))
while true
    disp(randi(str2num(max_v)))
    pause(0.5)
end