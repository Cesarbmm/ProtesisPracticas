%comp_avg_speeds plots comparisson of speeds

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: Laboratorio IA
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

06 March 2024
%}

cc all
%% Configs

f_name = "development\05 simulator creation\avg_data.mat";
formats = {"--", ".:","--", ".", "-", ".-", "--"};
%% Aux and dependent variables
% libs


%%
avgs = load(f_name,"avgs").avgs;
fig = figure("WindowState","maximized");

for j = 1:8
    ax{j} = subplot(4, 2, j, "Parent", fig, "FontSize", 17);
    hold(ax{j}, "on")

    if mod(j, 2) == 1
        ylabel(sprintf("mot %d", ceil(j/2)))
    end

    if j == 1
        title(ax{j}, "closing")
    end

    if j == 2
        title(ax{j}, "opening")
    end
    legend(ax{j},"location", "east", "FontSize", 12)
    %xline(ax{j}, 0, 'HandleVisibility', 'off')
end

close = [1 3 5 7];
open = [2 4 6 8];

idx = 0;
for f = fieldnames(avgs)'
    idx = idx + 1;
    sp = f{1};

    for ic = 1:4
        mot = sprintf("m_%d", ic);
        plot(ax{close(ic)}, avgs.(sp).closing.(mot).avg, formats{idx}, ...
            "DisplayName", sp)
        plot(ax{open(ic)}, avgs.(sp).opening.(mot).avg, formats{idx}, ...
            "DisplayName", sp)
    end
end

