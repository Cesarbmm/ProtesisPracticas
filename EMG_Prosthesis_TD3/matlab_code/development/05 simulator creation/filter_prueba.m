function incluir = filter_prueba(prueba, vel, regreso)
%filter_prueba() returns true for the files to include by speed and prueba.
%
% # OUTPUTS
%  incluir      bool true when incluir
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
    prueba (1, 1) string % int as str
    vel (1, 1) string
    regreso (1, 1) string
end

%%
incluir = true;
switch vel
    case "3F"
        switch prueba
            case {"2", "4"}
                incluir = false;
        end

    case "5F"
        switch prueba
            case "2"
                incluir = false;
        end
    case {"7F", "9F", "DF", "FF"}
    
    case "BF"
        switch prueba
            case "1"
                incluir = false;
            case "3"
                if regreso == ""
                    incluir = false;
                end
        end

    otherwise
        warning("speed %s not defined", vel)
end