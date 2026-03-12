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
method_fit = "logistic4";
method_fit_label = "Gompertz";
% method_fit = "pol";
% method_fit_label = "pol";

tail_length = 150;

%% Aux and dependent variables
% libs


%%
avgs = load(f_name,"avgs").avgs;
indx.closing = [1 3 5 7];
indx.opening = [2 4 6 8];

idx = 0;
for f = fieldnames(avgs)'
    idx = idx + 1;
    sp = f{1};

    fig.(sp) = figure("WindowState","maximized");

    for j = 1:2
        ax{j} = subplot(1, 2, j, "Parent", fig.(sp), "FontSize", 17);
        hold(ax{j}, "on")

        if mod(j, 2) == 1
            ylabel(sprintf("Speed %s", sp))
        end

        if j == 1
            title(ax{j}, "closing")
        end

        if j == 2
            title(ax{j}, "opening")
            xlabel(ax{j}, method_fit_label)
        end
        legend(ax{j},"location", "north", "FontSize", 12)
        %xline(ax{j}, 0, 'HandleVisibility', 'off')
    end

    for c = ["closing", "opening"]
        for ic = 1:4
            mot = sprintf("m_%d", ic);
            y = avgs.(sp).(c).(mot).avg;

            % extending signal
            y = [repmat(y(1), 1, tail_length) y];


            L = length(y);
            x = 1:L;
            % adding zeros

            L2 = round(L*0.1);
            x2 = -L2:(1.15*L);
            switch method_fit
                case "pol"
                    ws = polyfit(x, y, 4);
                    y2 = polyval(ws, x2);

                case "logistic4"
                    ws = fit(x', y', "gompertz");
                    y2 = ws(x2');
            end

            if isequal(c, "closing")
                ip = 1;
            else
                ip = 2;
            end
            plot(ax{ip}, x, y, "-", "DisplayName", sprintf("m%d",ic))
            plot(ax{ip}, x2, y2, "--", "DisplayName", sprintf("pred %d", ic))

            params.(sp).(c).(mot).ws = ws;
            params.(sp).(c).(mot).min_lim = min( ...
                avgs.(sp).(c).(mot).data, [],"all");
            params.(sp).(c).(mot).max_lim = max( ...
                avgs.(sp).(c).(mot).data, [],"all");
        end
    end
end
