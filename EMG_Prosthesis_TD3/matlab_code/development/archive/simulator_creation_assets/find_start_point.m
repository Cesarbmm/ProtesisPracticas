function min_index = find_start_point(dat)
%find_start_point() returns the index from where the data probably started
%to move.
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: Laboratorio IA
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

26 February 2024
%}

%% Input Validation
arguments
    dat % table with x, y, z, w cols
end

%% 
dif_table = diff(dat(:, ["x", "y", "z", "w"]), 1);
min_index = find(all(table2array(dif_table), 2), 1);

% letters = ["x", "y", "z", "w"];
% index = [];
% for l = letters
%     index(end + 1) = find(dif_table.(l), 1, "first");
% end
% figure, plot(dif_table.x), hold on, plot(dif_table.y), plot(dif_table.z),plot(dif_table.w)
% min_index = round(median(index));