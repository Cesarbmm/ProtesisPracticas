function plot_episode2(this)
%plot_episode() plots at the end of the episode.
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

%% Plotting
% to faster training not plot or plot not all episode, skipping any other
if this.episodeCounter > 1
    f = figure(1);

    % just getting vars...
    aux_1 = this.encoderAdjustedLog(1:this.c);
    aux_2 = this.flexConvertedLog(1:this.c);

    prosthesis_position = cat(1, aux_1{:});
    glove_position = cat(1, aux_2{:});
    for i = 1:4
        ax = subplot(4, 1, i, "Parent", f);
        cla(ax);
        hold(ax, "on");

        plot(ax, prosthesis_position(:, i));
        plot(ax, glove_position(:, i));
        legend(ax, sprintf("Prosthesis motor %d", i), "Flexion glove", ...
            "Location","southwest")

        if i == 1
            title(ax, sprintf("Episode %d", this.episodeCounter - 1))
        elseif i ==4
            xlabel(ax, "Step in episode")
        end
    end
    drawnow
end