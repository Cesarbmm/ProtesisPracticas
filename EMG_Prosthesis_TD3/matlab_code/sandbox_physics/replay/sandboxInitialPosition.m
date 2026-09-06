function [q0, provenance] = sandboxInitialPosition(side, options)
%sandboxInitialPosition posicion inicial de encoder SIN construir guante.
%
%   Reproduce exactamente el protocolo numerico de src/@Env/reset.m para la
%   ruta simulada, usando solo Timing + SimController. No crea RecordedGlove,
%   no lee gloves y no usa el guante como estado de planta.
%
%     side = 1  (Closing)  ->  resetBuffer()  ->  q0 = [0 0 0 0]
%                              (src/@Env/reset.m:133 rama else)
%     side = 2  (Opening)  ->  closeHand(); episodeTic.toc(10000); read(); stop()
%                              (src/@Env/reset.m:127-131)
%
%   HALLAZGO S0 que hay que tener presente: `toc(10000)` NO cierra la mano
%   durante 10000 periodos. Timing.toc fija elapsed_time con ese argumento pero
%   incrementa el contador `c` en 1 (src/@Timing/Timing.m:83-90), y
%   SimController.updatePos avanza por contador, no por elapsed_time
%   (src/@SimController/SimController.m:155-156). El cierre previo de un
%   episodio de apertura dura por tanto UN periodo de 0.2 s a PWM 255.
%   Resultado: la mano de partida en apertura esta PARCIALMENTE cerrada.
%
%   Comprobacion contra E2A (independiente, ya publicada): el estado inicial de
%   los episodios de apertura en e2a_results/execution_traces.csv tiene
%   state_41..44 = [0.421761 0.579580 0.883490 0.697870], que es exactamente
%   este q0 dividido por [26500 11500 8500 9000].
%
%   No se modifica ningun archivo del pipeline historico.

arguments
    side (1, 1) double {mustBeMember(side, [1 2])}
    options.period (1, 1) double {mustBePositive} = 0.2
end

if side == 1
    q0 = zeros(1, 4);
    protocol = "closing: resetBuffer, sin rollout previo";
else
    timing = Timing(false, options.period);
    controller = SimController(timing);
    controller.resetBuffer();
    controller.closeHand();
    timing.toc(10000);
    motorData = controller.read();
    controller.stop();
    q0 = motorData(end, :);
    protocol = "opening: closeHand + toc(10000) + read + stop (un periodo efectivo)";
end

episodeTypes = ["Closing", "Opening"];
provenance = struct( ...
    "side", side, ...
    "episodeType", episodeTypes(side), ...
    "q0Encoder", q0, ...
    "q0Normalized", q0 ./ [26500 11500 8500 9000], ...
    "protocol", protocol, ...
    "source", "src/@Env/reset.m:127-133 reproducido sin guante", ...
    "gloveUsed", false);
end
