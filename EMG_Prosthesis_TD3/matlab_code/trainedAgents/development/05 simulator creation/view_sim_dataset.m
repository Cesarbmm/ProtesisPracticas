%view_sim_dataset

%{
Laboratorio de Inteligencia y Visión Artificial 
ESCUELA POLITÉCNICA
NACIONAL Quito - Ecuador

autor: Laboratorio IA 
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

26 February 2024
%}

cc all
%% Configs


%% Aux and dependent variables
% libs

%
data_folder = "development\05 simulator creation\raw data Cx2";

let = ["x", "y", "z", "w", "x", "y", "z", "w"];

axes_conv = [2 4 6 8 1 3 5 7];
%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 8);

% Specify range and delimiter
opts.DataLines = [2, Inf];
opts.Delimiter = ";";

% Specify column names and types
opts.VariableNames = ["time", "x", "y", "z", "w", "velocidad", "voltaje", "trama"];
opts.VariableTypes = ["string", "double", "double", "double", "double", "double", "double", "categorical"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, "time", "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["time", "trama"], "EmptyFieldRule", "auto");
opts = setvaropts(opts, "velocidad", "TrimNonNumeric", true);
opts = setvaropts(opts, "velocidad", "ThousandsSeparator", ",");

% Import the data


%%
close all
offset = 10;
records = struct();

folders = dir(data_folder)';
f_idx = 0;
for f = folders(3:end)
    f_idx = f_idx + 1;
    % loop by speed
    fig = figure("WindowState","maximized");

    files = dir(fullfile(f.folder, f.name))';

    v_field = sprintf("sp_%s", f.name);

    for j = 1:8
        ax{j} = subplot(4, 2, j, "Parent", fig, "FontSize", 17);
        axs.(v_field){j} = ax{j};
        hold(ax{j}, "on")

        if mod(j, 2) == 1
            ylabel(sprintf("%d", ceil(j/2)))
        end

        if j == 1
            title(ax{j}, sprintf("Speed %s | closing", f.name))
        end

        if j == 2
            title(ax{j}, sprintf("Speed %s | opening", f.name))
        end
        legend(ax{j},"location", "east")
        xline(ax{j}, 0, 'HandleVisibility', 'off')
    end

    for f2 = files(3:end)
        % loop by file
        f_name = fullfile(f2.folder, f2.name);
        dat = readtable(f_name, opts);

        min_index = find_start_point(dat);

        t_stamp_sec = double(regexprep(dat.time, ...
            "\d+:\d+:(\d+):(\d+)", "$1.$2"));
        
        t_stamp = double(regexprep(dat.time, ...
            "\d+:(\d+):\d+:\d+", "$1"));
        
        t_stamp = (t_stamp - min(t_stamp))*60 + t_stamp_sec;
        
        if min_index < offset
            warning("Invalid offset of %d", min_index)
            min_index = offset;
        end



        % min_index = 1; % comment or uncomment to move by offset

        t_stamp = t_stamp(min_index: end);
        % checking diffs
        sampling = diff(t_stamp)*100;
        mn = mean(sampling);
        s = sprintf('t avg: %.2f\t std %.2f \t| min %.2f \t max %.2f\n', ...
            mn, std(sampling), min(sampling), max(sampling));
        a = Print(s);

        % figure, histogram(diff(t_stamp));

        resp = regexp(f_name,"Prueba(\d+).*_(\d+)(Regreso)?.csv",'tokens');
        resp = resp{1};

        if ~filter_prueba(resp{1}, f.name, resp{3})
            a.clear;
            Print(sprintf("%s IGNORED-------------\n", s(1:end -1)));
            continue
        end

        for j = 1:8
            if isempty(resp{3})
                % no es regreso
                if j < 5
                    continue
                end
            else
                if j > 4
                    continue
                end
            end
            v = dat.(let(j));
            plot(ax{axes_conv(j)}, (1:length(v)) - min_index, ...
                v, ":", "DisplayName", resp{1}, ...
                "LineWidth", 4)

            % -- saving
            if ~isfield(records, v_field)
                records.(v_field) = struct();

                for k = 1:8
                    % records.(v_field).(sprintf("ax_org_%i", k)) = {};
                    records.(v_field).(sprintf("ax_%i", k)) = {};
                end
            end
            m_field = sprintf("ax_%i", axes_conv(j));
            % m_field_org = sprintf("ax_org_%i", j);

            records.(v_field).(m_field){end + 1} = v(min_index - 1:end);
            % records.(v_field).(m_field_org){end + 1} = v(min_index - 1:end);
        end
    end

end
drawnow

%% plot avgs
% for sp = 1:size(axs, 1)
for sp_c = fieldnames(axs)'
    sp = sp_c{1};
    for x = 1:8
        ff = sprintf("ax_%d", x);
        poss = records.(sp).(ff);
        min_l = min(cellfun(@(x)length(x), poss));

        poss_level = cellfun(@(x)x(1:min_l), poss, 'UniformOutput', false);
        poss_level = cell2mat(poss_level);
        pos_avg = mean(poss_level, 2)';
        pos_std = std(poss_level, 0, 2)';

        plot(axs.(sp){x}, pos_avg, "Color", [0 0 0], "DisplayName", "avg");
        fillBetweenCurves(axs.(sp){x}, 1:min_l, pos_avg - pos_std, ...
            pos_avg + pos_std, [0 0 0], 0.3);

        % saving

        if mod(x, 2) == 1
            dir = "closing";
        else
            dir = "opening";
        end
        mot = sprintf("m_%d", ceil(x/2));
        % pares, regreso
        avgs.(sp).(dir).(mot).avg = pos_avg;
        avgs.(sp).(dir).(mot).std = pos_std;
        avgs.(sp).(dir).(mot).data = poss_level;
    end
end